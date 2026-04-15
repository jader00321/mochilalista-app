# app/services/inventory_matcher_service.py
import unicodedata
import re
from sqlalchemy.orm import Session
from sqlalchemy import or_
from typing import List, Set, Optional, Tuple
from thefuzz import fuzz

from app.models.product import Product
from app.models.product_presentation import ProductPresentation
from app.models.brand import Brand

from app.schemas.inventory_matcher import (
    BatchMatchRequest, BatchMatchResponse, 
    MatchResult as EngineMatchResult, MatchedProductInfo, MatchItemInput
)
from app.schemas.scanner import MatchResult as ScannerMatchResult, MatchData 

class InventoryMatcherService:
    
    # 🔥 AHORA RECIBE EL ROL (is_client)
    def match_batch(self, db: Session, negocio_id: int, data: BatchMatchRequest, is_client: bool = False) -> BatchMatchResponse:
        
        all_search_terms = set()
        for item in data.items:
            words = self._normalize_text(item.full_name).split()
            all_search_terms.update(words)
            if item.brand:
                all_search_terms.update(self._normalize_text(item.brand).split())
                
        if not all_search_terms:
            return BatchMatchResponse(results=[EngineMatchResult(item_id=item.id, match_type="NONE", score=0) for item in data.items])

        search_filters = []
        for term in all_search_terms:
            if len(term) > 3: 
                search_filters.append(Product.nombre.ilike(f"%{term}%"))
                search_filters.append(ProductPresentation.nombre_especifico.ilike(f"%{term}%"))
                search_filters.append(Brand.nombre.ilike(f"%{term}%"))
        
        inventory_query_base = (
            db.query(ProductPresentation, Product)
            .join(Product, ProductPresentation.producto_id == Product.id)
            .outerjoin(Brand, Product.marca_id == Brand.id)
            .filter(Product.negocio_id == negocio_id)
        )

        # 🔥 FILTRO ESTRICTO SOLO PARA CLIENTES
        if is_client:
            inventory_query_base = inventory_query_base.filter(ProductPresentation.stock_actual > 0)

        inventory_query = []
        if search_filters:
            inventory_query = inventory_query_base.filter(or_(*search_filters)).all()

        if not inventory_query:
            fallback_query = (
                db.query(ProductPresentation, Product)
                .join(Product, ProductPresentation.producto_id == Product.id)
                .filter(Product.negocio_id == negocio_id)
            )
            if is_client:
                fallback_query = fallback_query.filter(ProductPresentation.stock_actual > 0)
                
            inventory_query = fallback_query.limit(500).all()

        if not inventory_query:
            return BatchMatchResponse(results=[EngineMatchResult(item_id=item.id, match_type="NONE", score=0) for item in data.items])

        candidates_data = []
        for presentation, product in inventory_query:
            search_parts = [product.nombre]
            if product.marca: 
                try: search_parts.append(product.marca.nombre) 
                except: search_parts.append(str(product.marca))
            
            if presentation.nombre_especifico: search_parts.append(presentation.nombre_especifico)
            if presentation.unidad_venta: search_parts.append(presentation.unidad_venta)
            
            raw_text = " ".join(part for part in search_parts if part)
            normalized_text = self._normalize_text(raw_text)
            
            brand_norm = None
            if product.marca:
                try: b_name = product.marca.nombre
                except: b_name = str(product.marca)
                brand_norm = self._normalize_text(b_name)

            candidates_data.append({
                "product": product, "presentation": presentation, "normalized_text": normalized_text,
                "tokens": set(normalized_text.split()), "brand_normalized": brand_norm, "raw_text": raw_text 
            })

        results = []
        for item in data.items:
            results.append(self._process_single_item(item, candidates_data, is_client))
        return BatchMatchResponse(results=results)

    def _process_single_item(self, item: MatchItemInput, candidates: List[dict], is_client: bool) -> EngineMatchResult:
        input_norm = self._normalize_text(item.full_name)
        input_tokens = list(set(input_norm.split()))
        ranked_candidates = []

        for cand in candidates:
            score = 0.0
            tokens_satisfied = sum(1 for token in input_tokens if not self._generate_search_variations(token).isdisjoint(cand["tokens"]))
            if tokens_satisfied > 0: score += (tokens_satisfied / len(input_tokens)) * 50
            if score == 0 and len(input_norm) > 4: continue

            fuzz_score = fuzz.token_set_ratio(input_norm, cand["normalized_text"])
            if fuzz_score > 50: score += (fuzz_score * 0.3) 

            has_brand_penalty = False
            if item.brand and item.brand.lower() not in ["generico", "genérica", "sin marca"]:
                if cand["brand_normalized"]:
                    brand_sim = fuzz.ratio(self._normalize_text(item.brand), cand["brand_normalized"])
                    if brand_sim >= 85: 
                        score += 20 
                    elif brand_sim < 50: 
                        score -= 25 
                        has_brand_penalty = True
                else:
                    score -= 15 
                    has_brand_penalty = True

            if cand["presentation"].stock_actual > 0: score += 5

            final_score = int(min(100, max(0, score)))
            if final_score > 35: 
                ranked_candidates.append({"candidate": cand, "score": final_score, "has_brand_penalty": has_brand_penalty})

        if not ranked_candidates: return EngineMatchResult(item_id=item.id, match_type="NONE", score=0)

        ranked_candidates.sort(key=lambda x: x["score"], reverse=True)
        winner = ranked_candidates[0]
        winner_prod = winner["candidate"]["product"]
        winner_pres = winner["candidate"]["presentation"]

        match_type = "NONE"
        if winner["score"] >= 80 and not winner["has_brand_penalty"]:
            match_type = "AUTO"
        elif winner["score"] >= 45:
            match_type = "SUGGESTION"
            
        if match_type == "NONE": 
            return EngineMatchResult(item_id=item.id, match_type="NONE", score=winner["score"])

        base_name = winner_prod.nombre
        full_name_builder = base_name
        if winner_pres.nombre_especifico:
            full_name_builder += f" {winner_pres.nombre_especifico}"

        brand_str = ""
        if winner_prod.marca:
             try: brand_str = winner_prod.marca.nombre
             except: brand_str = str(winner_prod.marca)

        # 🔥 LÓGICA DE STOCK MÁXIMO SEGÚN ROL
        sug_quantity = item.quantity
        if is_client and sug_quantity > winner_pres.stock_actual:
            sug_quantity = winner_pres.stock_actual if winner_pres.stock_actual > 0 else 1

        suggested = MatchedProductInfo(
            product_id=winner_prod.id, 
            presentation_id=winner_pres.id,
            full_name=full_name_builder, 
            product_name=base_name,
            specific_name=winner_pres.nombre_especifico,
            brand=brand_str,
            price=float(winner_pres.precio_venta_final), 
            stock=winner_pres.stock_actual,
            image_url=winner_pres.imagen_url or winner_prod.imagen_url,
            offer_price=float(winner_pres.precio_oferta) if winner_pres.precio_oferta else None,
            unit=winner_pres.unidad_venta or "Unidad", 
            conversion_factor=winner_pres.unidades_por_venta,
        )

        return EngineMatchResult(item_id=item.id, match_type=match_type, score=winner["score"], suggested_product=suggested, suggested_quantity=sug_quantity)

    def get_brand_match(self, text: str, brands_dict: dict) -> Tuple[ScannerMatchResult, Optional[int]]:
        if not text: return ScannerMatchResult(estado="NUEVO", confianza=0), None
        text_norm = self._normalize_text(text)
        best_score = 0; best_brand = None
        for b_name, b_obj in brands_dict.items():
            score = fuzz.ratio(text_norm, self._normalize_text(b_name))
            if score > best_score: best_score = score; best_brand = b_obj
        if best_brand and best_score >= 85: return ScannerMatchResult(estado="MATCH_EXACTO", confianza=best_score, datos=MatchData(id=best_brand.id, nombre=best_brand.nombre)), best_brand.id
        return ScannerMatchResult(estado="NUEVO", confianza=0), None

    def get_product_match_strict(self, query_name: str, target_brand_id: Optional[int], products_pool: List[Product], strict_brand_mode: bool, is_client: bool = False) -> ScannerMatchResult:
        if not query_name: return ScannerMatchResult(estado="NUEVO", confianza=0)
        candidates = [p for p in products_pool if p.marca_id == target_brand_id] if strict_brand_mode and target_brand_id else products_pool
        
        # 🔥 Aplicar filtro si es cliente
        if is_client:
            # Solo filtramos los que tienen al menos una presentación con stock
            candidates = [p for p in candidates if any(pres.stock_actual > 0 for pres in p.presentaciones)]

        if not candidates: return ScannerMatchResult(estado="NUEVO", confianza=0)
        
        best_score = 0; best_prod = None
        for prod in candidates:
            score = min(100, self._calculate_score(query_name, prod.nombre) + (10 if target_brand_id and prod.marca_id == target_brand_id else 0))
            if score > best_score: best_score = score; best_prod = prod
        
        if best_prod and best_score > 40:
            estado = "MATCH_EXACTO" if best_score >= 85 else "MATCH_SUGERIDO"
            return ScannerMatchResult(estado=estado, confianza=best_score, datos=MatchData(id=best_prod.id, nombre=best_prod.nombre, stock_actual=best_prod.stock_total_unidades, marca_nombre=best_prod.marca.nombre if best_prod.marca else "Genérica", categoria_nombre=best_prod.categoria.nombre if hasattr(best_prod, 'categoria') and best_prod.categoria else "General"))
        return ScannerMatchResult(estado="NUEVO", confianza=0)

    def get_presentation_match(self, prod_id: int, variant_name: str, db: Session, is_client: bool = False) -> ScannerMatchResult:
        query = db.query(ProductPresentation).filter(ProductPresentation.producto_id == prod_id)
        if is_client:
            query = query.filter(ProductPresentation.stock_actual > 0)
            
        presentations = query.all()
        siblings_list = []
        best_score = 0; best_pres = None

        for p in presentations:
            u_venta = p.unidad_venta or "Unidad"
            especifico = p.nombre_especifico or ""
            nombre_limpio = especifico if especifico else "Estándar"

            siblings_list.append({
                "id": p.id,
                "nombre_presentacion": u_venta, 
                "nombre_especifico": nombre_limpio,
                "nombre_completo": nombre_limpio, 
                "stock_actual": p.stock_actual,
                "precio_venta": float(p.precio_venta_final), 
                "precio_costo": float(p.costo_unitario_calculado or 0), 
                "factor_conversion": p.unidades_por_venta,
                "unidad": u_venta
            })
            
            score = self._calculate_score(variant_name, f"{u_venta} {especifico}".strip())
            if score > best_score: best_score = score; best_pres = p

        if not siblings_list: return ScannerMatchResult(estado="NUEVO_EN_PADRE", confianza=0, datos=MatchData(id=-1, nombre="Nueva", available_presentations=[]))

        if best_pres and best_score >= 60:
            return ScannerMatchResult(
                estado="MATCH_EXACTO", confianza=best_score,
                datos=MatchData(
                    id=best_pres.id, nombre=(best_pres.nombre_especifico or "Estándar").strip(),
                    stock_actual=best_pres.stock_actual, precio_venta_actual=float(best_pres.precio_venta_final),
                    costo_unitario_actual=float(best_pres.costo_unitario_calculado or 0), factor=best_pres.unidades_por_venta,
                    unidad=best_pres.unidad_venta or "Unidad", available_presentations=siblings_list
                )
            )
        
        return ScannerMatchResult(estado="NUEVO_EN_PADRE", confianza=0, datos=MatchData(id=-1, nombre="Nueva Variante", available_presentations=siblings_list))

    def _normalize_text(self, text: str) -> str:
        if not text: return ""
        text = str(text).lower()
        text = ''.join(c for c in unicodedata.normalize('NFD', text) if unicodedata.category(c) != 'Mn')
        return re.sub(r'\s+', ' ', re.sub(r'[^a-z0-9\s]', '', text)).strip()

    def _generate_search_variations(self, text: str) -> Set[str]:
        v = {text}
        if text.endswith('es') and len(text) > 3: v.add(text[:-2]) 
        elif text.endswith('s') and len(text) > 3 and not text.endswith('ss'): v.add(text[:-1]) 
        return v

    def _calculate_score(self, input_text: str, candidate_text: str) -> int:
        input_norm = self._normalize_text(input_text); cand_norm = self._normalize_text(candidate_text)
        input_tokens = list(set(input_norm.split())); cand_tokens = set(cand_norm.split())
        score = 0.0
        tokens_satisfied = sum(1 for t in input_tokens if not self._generate_search_variations(t).isdisjoint(cand_tokens))
        if tokens_satisfied > 0: score += (tokens_satisfied / len(input_tokens)) * 60
        fuzz_score = fuzz.token_set_ratio(input_norm, cand_norm)
        if fuzz_score > 50: score += (fuzz_score * 0.4) 
        return int(min(100, max(0, score)))

inventory_matcher_service = InventoryMatcherService()