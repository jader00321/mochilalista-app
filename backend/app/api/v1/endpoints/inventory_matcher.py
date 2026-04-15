import uuid
from fastapi import APIRouter, Depends, Query, HTTPException
from sqlalchemy.orm import Session
from typing import Dict
from thefuzz import process

from app.api import deps
from app.schemas.inventory_matcher import BatchMatchRequest, BatchMatchResponse
from app.schemas.scanner import AIInvoiceResponse, StagingResponse, StagingProductGroup, StagingVariant, MatchResult as ScannerMatchResult, MatchData
from app.models.product import Product
from app.models.brand import Brand
from app.models.provider import Provider
from app.models.negocio_usuario import NegocioUsuario 
from app.models.user import User 
from app.services.inventory_matcher_service import inventory_matcher_service 

router = APIRouter()

# 🔥 ENDPOINT ACTUALIZADO PARA RECIBIR EL ROL DESDE FLUTTER
@router.post("/match-batch", response_model=BatchMatchResponse)
def match_batch(
    data: BatchMatchRequest,
    is_client: bool = Query(False, description="Flag que indica si la petición la hace un cliente para restringir stock"),
    db: Session = Depends(deps.get_db),
    negocio_id: int = Depends(deps.get_current_business_id),
):
    print(f"\n=== 🧠 INICIANDO BATCH MATCHING INTELIGENTE (is_client={is_client}) ===")
    return inventory_matcher_service.match_batch(db, negocio_id, data, is_client=is_client)

@router.post("/match", response_model=StagingResponse)
def match_invoice_data(
    data_cruda: AIInvoiceResponse,
    db: Session = Depends(deps.get_db),
    negocio_id: int = Depends(deps.get_current_business_id),
    current_user: User = Depends(deps.get_current_user) 
):
    print("\n=== 🧾 INICIANDO MATCHING DE FACTURA / LISTA ===")
    
    vinculo = db.query(NegocioUsuario).filter(
        NegocioUsuario.usuario_id == current_user.id,
        NegocioUsuario.negocio_id == negocio_id
    ).first()
    
    is_client = False
    if vinculo and vinculo.rol_en_negocio == "cliente_comunidad":
        is_client = True

    db_provs = {p.nombre_empresa: p for p in db.query(Provider).filter(Provider.negocio_id == negocio_id).all()}
    prov_match_res = ScannerMatchResult(estado="NUEVO", confianza=0)
    
    if data_cruda.proveedor_detectado:
        match_p = process.extractOne(data_cruda.proveedor_detectado, list(db_provs.keys()))
        if match_p and match_p[1] >= 85:
            obj_p = db_provs[match_p[0]]
            prov_match_res = ScannerMatchResult(estado="MATCH_EXACTO", confianza=match_p[1], datos=MatchData(id=obj_p.id, nombre=obj_p.nombre_empresa))

    all_products = db.query(Product).filter(Product.negocio_id == negocio_id).all()
    db_brands = {b.nombre: b for b in db.query(Brand).filter(Brand.negocio_id == negocio_id).all()}
    grouped_items: Dict[str, StagingProductGroup] = {}

    for item in data_cruda.items:
        base_name = (item.producto_padre_estimado or item.descripcion_detectada).strip()
        brand_detected = (item.marca_detectada or "").strip()
        group_key = f"{inventory_matcher_service._normalize_text(base_name)}|{inventory_matcher_service._normalize_text(brand_detected)}"
        
        if group_key not in grouped_items:
            match_brand, brand_id = inventory_matcher_service.get_brand_match(brand_detected, db_brands)
            match_prod = inventory_matcher_service.get_product_match_strict(base_name, brand_id, all_products, bool(brand_id), is_client=is_client)
            
            grouped_items[group_key] = StagingProductGroup(
                nombre_padre=base_name, marca_texto=brand_detected or "Genérica",
                match_producto=match_prod, match_marca=match_brand, variantes=[]
            )
        
        group = grouped_items[group_key]
        
        match_variant = ScannerMatchResult(estado="NUEVO", confianza=0)
        if group.match_producto.estado != "NUEVO" and group.match_producto.datos:
            match_variant = inventory_matcher_service.get_presentation_match(group.match_producto.datos.id, item.variante_detectada or "Unidad", db, is_client=is_client)

        unidad_v = item.unidad_venta if item.unidad_venta else (item.ump_compra or "Unidad")
        
        factor_v = 1
        uv_lower = unidad_v.lower().strip()
        if uv_lower in ['docena', 'doc']: factor_v = 12
        elif uv_lower == 'decena': factor_v = 10
        elif uv_lower in ['ciento', 'cto']: factor_v = 100
        elif uv_lower in ['millar', 'mll']: factor_v = 1000
        elif uv_lower in ['gruesa', 'grz']: factor_v = 144
        else: factor_v = 1  

        costo_unit_base = 0.0
        if item.cantidad_ump_comprada > 0 and item.unidades_por_lote > 0:
            costo_unit_base = item.total_pago_lote / (item.cantidad_ump_comprada * item.unidades_por_lote)
        
        costo_presentacion = costo_unit_base * factor_v
        margen_sugerido = 1.35 
        precio_venta_calc = costo_presentacion * margen_sugerido

        variant_obj = StagingVariant(
            uuid_temporal=str(uuid.uuid4()),
            nombre_especifico=item.variante_detectada or "Estándar",
            
            ump_compra=item.ump_compra or "UND",
            cantidad_ump_comprada=item.cantidad_ump_comprada,
            precio_ump_proveedor=item.precio_ump_proveedor,
            total_pago_lote=item.total_pago_lote,
            unidades_por_lote=item.unidades_por_lote,
            
            unidad_venta=unidad_v,
            unidades_por_venta=factor_v,
            
            costo_unitario_sugerido=round(costo_presentacion, 4),
            factor_ganancia_venta_sugerido=margen_sugerido,
            precio_venta_sugerido=round(precio_venta_calc, 2),
            
            codigo_barras=item.codigo_detectado,
            match_presentacion=match_variant
        )
        group.variantes.append(variant_obj)

    return StagingResponse(
        invoice_id=data_cruda.invoice_id,
        proveedor_match=prov_match_res, proveedor_texto=data_cruda.proveedor_detectado,
        ruc_detectado=data_cruda.ruc_detectado, monto_total_factura=data_cruda.monto_total_factura,
        fecha_factura=data_cruda.fecha_detectada,
        productos_agrupados=list(grouped_items.values())
    )