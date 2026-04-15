from decimal import Decimal
from typing import List, Dict, Any
from sqlalchemy.orm import Session, joinedload
from fastapi import HTTPException
from datetime import datetime 

from app.models.smart_quotation import SmartQuotation, SmartQuotationItem
from app.models.product_presentation import ProductPresentation
from app.models.cliente import Cliente
from app.models.business import Business
from app.models.notification import Notification 
from app.models.negocio_usuario import NegocioUsuario 
from app.schemas.smart_quotation import SmartQuotationCreate, SmartQuotationUpdate

class SmartQuotationService:
    
    def _get_strict_negocio_id(self, negocio_id: int = None) -> int:
        if not negocio_id:
            raise HTTPException(status_code=403, detail="Contexto de negocio estrictamente requerido por seguridad.")
        return negocio_id

    def create_quotation(self, db: Session, user_id: int, data: SmartQuotationCreate, force_negocio_id: int = None) -> SmartQuotation:
        n_id = self._get_strict_negocio_id(force_negocio_id)
        
        vinculo = db.query(NegocioUsuario).filter(
            NegocioUsuario.usuario_id == user_id, 
            NegocioUsuario.negocio_id == n_id
        ).first()
        
        is_client_role = vinculo and vinculo.rol_en_negocio == "cliente_comunidad"
        
        if is_client_role:
            cliente_crm = db.query(Cliente).filter(
                Cliente.usuario_vinculado_id == user_id, 
                Cliente.negocio_id == n_id
            ).first()
            
            if cliente_crm:
                data.client_id = cliente_crm.id
                if not data.client_name or data.client_name.startswith("Mi Pedido") or data.client_name.startswith("Cotización"):
                    codigo = data.client_name.split("#")[-1] if "#" in (data.client_name or "") else datetime.utcnow().strftime("%H%M")
                    tipo_str = "IA" if data.type == "ai_scan" else "Manual"
                    data.client_name = f"{cliente_crm.nombre_completo} - Pedido {tipo_str} #{codigo}"

        db_quotation = SmartQuotation(
            negocio_id=n_id,
            creado_por_usuario_id=user_id,
            client_name=data.client_name,
            institution_name=data.institution_name,
            grade_level=data.grade_level,
            notas=data.notas,            
            total_amount=data.total_amount,
            total_savings=data.total_savings,
            status=data.status,
            source_image_url=data.source_image_url,
            original_text_dump=getattr(data, 'original_text_dump', None), 
            client_id=data.client_id, 
            type=data.type,
            is_template=data.is_template,
            clone_source_id=getattr(data, 'clone_source_id', None)
        )
        db.add(db_quotation)
        db.flush()

        for item_data in data.items:
            db_item = SmartQuotationItem(
                quotation_id=db_quotation.id,
                product_id=item_data.product_id,
                presentation_id=item_data.presentation_id,
                quantity=item_data.quantity,
                unit_price_applied=item_data.unit_price_applied,
                original_unit_price=item_data.original_unit_price,
                product_name=item_data.product_name,
                brand_name=item_data.brand_name,
                specific_name=item_data.specific_name,
                sales_unit=item_data.sales_unit,
                original_text=getattr(item_data, 'original_text', None),
                is_manual_price=item_data.is_manual_price,
                is_available=getattr(item_data, 'is_available', True)
            )
            db.add(db_item)
            
        if is_client_role:
            negocio = db.query(Business).filter(Business.id == n_id).first()
            if negocio:
                nombre_cliente_notif = data.client_name.split("-")[0].strip() if "-" in (data.client_name or "") else "VIP"
                db.add(Notification(
                    user_id=negocio.id_dueno,
                    negocio_id=n_id,
                    titulo="¡Nuevo Pedido Entrante!",
                    mensaje=f"El cliente {nombre_cliente_notif} ha enviado un pedido por revisar.",
                    tipo="info", prioridad="Alta",
                    objeto_relacionado_tipo="cotizacion",
                    objeto_relacionado_id=db_quotation.id
                ))

        db.commit()
        db.refresh(db_quotation)
        return self.get_quotation_by_id(db, db_quotation.id, user_id, n_id)
    
    def get_quotations_by_user(self, db: Session, user_id: int, skip: int = 0, limit: int = 100, force_negocio_id: int = None):
        n_id = self._get_strict_negocio_id(force_negocio_id)
        
        vinculo = db.query(NegocioUsuario).filter(
            NegocioUsuario.usuario_id == user_id, 
            NegocioUsuario.negocio_id == n_id
        ).first()

        query = db.query(SmartQuotation).options(joinedload(SmartQuotation.items)).filter(SmartQuotation.negocio_id == n_id)
        
        if vinculo and vinculo.rol_en_negocio == "cliente_comunidad":
            query = query.filter(SmartQuotation.creado_por_usuario_id == user_id)
            
        return query.order_by(SmartQuotation.created_at.desc()).offset(skip).limit(limit).all()

    def get_quotation_by_id(self, db: Session, quotation_id: int, user_id: int, force_negocio_id: int = None):
        n_id = self._get_strict_negocio_id(force_negocio_id)
        
        vinculo = db.query(NegocioUsuario).filter(
            NegocioUsuario.usuario_id == user_id, 
            NegocioUsuario.negocio_id == n_id
        ).first()

        query = db.query(SmartQuotation).options(joinedload(SmartQuotation.items)).filter(
            SmartQuotation.id == quotation_id, 
            SmartQuotation.negocio_id == n_id
        )
        
        if vinculo and vinculo.rol_en_negocio == "cliente_comunidad":
            query = query.filter(SmartQuotation.creado_por_usuario_id == user_id)
            
        return query.first()

    def update_quotation(self, db: Session, quotation_id: int, user_id: int, update_data: SmartQuotationUpdate, force_negocio_id: int = None):
        n_id = self._get_strict_negocio_id(force_negocio_id)
        quotation = self.get_quotation_by_id(db, quotation_id, user_id, force_negocio_id)
        if not quotation: return None
        
        old_status = quotation.status 
        
        if update_data.client_id is not None:
            quotation.client_id = update_data.client_id
            cliente = db.query(Cliente).filter(Cliente.id == update_data.client_id).first()
            if cliente:
                if update_data.real_client_name is not None: cliente.nombre_completo = update_data.real_client_name
                if update_data.real_client_phone is not None: cliente.telefono = update_data.real_client_phone
                if update_data.real_client_dni is not None: cliente.dni_ruc = update_data.real_client_dni
                if update_data.real_client_address is not None: cliente.direccion = update_data.real_client_address
                if update_data.real_client_email is not None: cliente.correo = update_data.real_client_email
                if update_data.real_client_notes is not None: cliente.notas = update_data.real_client_notes
                db.add(cliente)
        
        update_dict = update_data.model_dump(exclude_unset=True)
        for key, value in update_dict.items():
            if key != 'items' and not key.startswith('real_client_') and key != 'client_id': 
                setattr(quotation, key, value)
        
        if 'items' in update_dict and update_data.items is not None:
            quotation.items.clear() 
            for item_data in update_data.items:
                new_item = SmartQuotationItem(
                    product_id=item_data.product_id, presentation_id=item_data.presentation_id, quantity=item_data.quantity,
                    unit_price_applied=item_data.unit_price_applied, original_unit_price=item_data.original_unit_price,
                    product_name=item_data.product_name, brand_name=item_data.brand_name, specific_name=item_data.specific_name,
                    sales_unit=item_data.sales_unit, 
                    original_text=getattr(item_data, 'original_text', None), is_manual_price=item_data.is_manual_price, is_available=getattr(item_data, 'is_available', True)
                )
                quotation.items.append(new_item)
        
        if 'status' in update_dict and old_status != update_data.status and quotation.client_id:
            cliente = db.query(Cliente).filter(Cliente.id == quotation.client_id).first()
            if cliente and cliente.usuario_vinculado_id:
                mensajes_cliente = {
                    "READY": "Tu pedido ha sido revisado y está listo.",
                    "ARCHIVED": "Tu pedido ha sido rechazado o cancelado.",
                }
                
                if update_data.status in mensajes_cliente:
                    db.add(Notification(
                        user_id=cliente.usuario_vinculado_id,
                        negocio_id=n_id,
                        titulo="Actualización de Pedido",
                        mensaje=mensajes_cliente[update_data.status],
                        tipo="info" if update_data.status == "READY" else "alerta", 
                        prioridad="Alta",
                        objeto_relacionado_tipo="cotizacion",
                        objeto_relacionado_id=quotation.id
                    ))

        db.add(quotation)
        db.commit()
        db.refresh(quotation)
        return quotation

    def delete_quotation(self, db: Session, quotation_id: int, user_id: int, force_negocio_id: int = None) -> bool:
        quotation = self.get_quotation_by_id(db, quotation_id, user_id, force_negocio_id)
        if not quotation: return False
        db.delete(quotation)
        db.commit()
        return True

    # 🔥 CORRECCIÓN CLONE: Inyección de negocio_id
    def clone_quotation(self, db: Session, quotation_id: int, user_id: int, negocio_id: int, target_client_id: int = None) -> SmartQuotation:
        original = self.get_quotation_by_id(db, quotation_id, user_id, force_negocio_id=negocio_id)
        if not original:
            raise HTTPException(status_code=404, detail="Cotización no encontrada")
        
        unique_code = datetime.utcnow().strftime("%H%M%S")
        generic_name = f"Cotización Genérica #{unique_code}"
        
        new_quotation = SmartQuotation(
            negocio_id=negocio_id,
            creado_por_usuario_id=user_id,
            client_id=target_client_id if target_client_id else None,
            type="cloned", # 🔥 Strings planos seguros en lugar de Enum
            status="PENDING",
            clone_source_id=original.id,
            is_template=False,
            client_name=None if target_client_id else generic_name, 
            institution_name=original.institution_name,
            grade_level=original.grade_level,
            notas=original.notas, 
            total_amount=original.total_amount,
            total_savings=original.total_savings,
            source_image_url=original.source_image_url 
        )
        db.add(new_quotation)
        db.flush()
        
        for item in original.items:
            new_item = SmartQuotationItem(
                quotation_id=new_quotation.id,
                product_id=item.product_id,
                presentation_id=item.presentation_id,
                quantity=item.quantity,
                unit_price_applied=item.unit_price_applied,
                original_unit_price=item.original_unit_price,
                product_name=item.product_name,
                brand_name=item.brand_name,
                specific_name=item.specific_name,
                sales_unit=item.sales_unit,
                original_text=item.original_text,
                is_manual_price=item.is_manual_price,
                is_available=item.is_available 
            )
            db.add(new_item)
            
        db.commit()
        db.refresh(new_quotation)
        return self.get_quotation_by_id(db, new_quotation.id, user_id, force_negocio_id=negocio_id)

    # 🔥 CORRECCIÓN TO_PACK: Inyección de negocio_id
    def convert_to_pack(self, db: Session, quotation_id: int, user_id: int, negocio_id: int) -> SmartQuotation:
        original = self.get_quotation_by_id(db, quotation_id, user_id, force_negocio_id=negocio_id)
        if not original:
            raise HTTPException(status_code=404, detail="Cotización no encontrada")

        unique_code = datetime.utcnow().strftime("%d%H%M")
        
        client_identifier = "Genérico"
        if original.cliente and original.cliente.nombre_completo:
            client_identifier = original.cliente.nombre_completo
        elif original.client_name and "Cliente General" not in original.client_name and "Cotización" not in original.client_name:
            client_identifier = original.client_name

        grade_str = original.grade_level if original.grade_level else 'Escolar'
        pack_name = f"Pack #{unique_code} | {grade_str} ({client_identifier})"
        
        new_pack = SmartQuotation(
            negocio_id=negocio_id,
            creado_por_usuario_id=user_id,
            client_name=pack_name, 
            institution_name=original.institution_name,
            grade_level=original.grade_level,
            notas=original.notas, 
            total_amount=original.total_amount,
            total_savings=original.total_savings,
            status="PENDING", 
            type="pack", # 🔥 Strings planos seguros
            is_template=True,                   
            source_image_url=None,              
            client_id=None,
            clone_source_id=original.id
        )
        db.add(new_pack)
        db.flush()

        for item in original.items:
            new_item = SmartQuotationItem(
                quotation_id=new_pack.id,
                product_id=item.product_id,
                presentation_id=item.presentation_id,
                quantity=item.quantity,
                unit_price_applied=item.unit_price_applied,
                original_unit_price=item.original_unit_price,
                product_name=item.product_name,
                brand_name=item.brand_name,
                specific_name=item.specific_name,
                sales_unit=item.sales_unit,
                original_text=None, 
                is_manual_price=item.is_manual_price,
                is_available=item.is_available
            )
            db.add(new_item)

        db.commit()
        db.refresh(new_pack)
        return new_pack

    # 🔥 CORRECCIÓN REFRESH: Inyección de negocio_id
    def refresh_quotation_values(self, db: Session, quotation_id: int, user_id: int, negocio_id: int, fix_prices: bool = True, fix_stock: bool = False):
        quotation = self.get_quotation_by_id(db, quotation_id, user_id, force_negocio_id=negocio_id)
        if not quotation:
            raise HTTPException(status_code=404, detail="Cotización no encontrada")

        total_accum = Decimal('0.00')
        items_to_delete = []
        
        for item in quotation.items:
            item_price = Decimal(str(item.unit_price_applied)) if item.unit_price_applied is not None else Decimal('0.00')
            quantity = Decimal(item.quantity)

            if not item.presentation_id:
                item.is_available = True
                total_accum += item_price * quantity
                continue 

            real_product = db.query(ProductPresentation).filter(ProductPresentation.id == item.presentation_id).first()
            
            is_stock_ok = True
            if not real_product or real_product.stock_actual < item.quantity:
                is_stock_ok = False
            
            item.is_available = is_stock_ok

            if fix_stock and not is_stock_ok:
                items_to_delete.append(item)
                continue 

            if not real_product:
                total_accum += item_price * quantity
                continue

            if fix_prices:
                new_base_price = Decimal(str(real_product.precio_venta_final))
                
                if not item.is_manual_price:
                    current_effective_price = real_product.precio_oferta if (real_product.precio_oferta and real_product.precio_oferta > 0) else real_product.precio_venta_final
                    new_applied_price = Decimal(str(current_effective_price))
                    
                    if abs(new_applied_price - item_price) > Decimal('0.01') or abs(new_base_price - Decimal(str(item.original_unit_price))) > Decimal('0.01'):
                        item.unit_price_applied = new_applied_price
                        item.original_unit_price = new_base_price
                        item_price = new_applied_price
                else:
                    if abs(new_base_price - Decimal(str(item.original_unit_price))) > Decimal('0.01'):
                        item.original_unit_price = new_base_price
            
            total_accum += item_price * quantity

        for item in items_to_delete:
            db.delete(item)

        quotation.total_amount = float(total_accum.quantize(Decimal('0.01')))
        db.add(quotation)
        db.commit()
        db.refresh(quotation)
        return self.get_quotation_by_id(db, quotation_id, user_id, force_negocio_id=negocio_id)

    # 🔥 CORRECCIÓN VALIDATE: Inyección de negocio_id
    def validate_quotation_integrity(self, db: Session, quotation_id: int, user_id: int, negocio_id: int) -> Dict[str, Any]:
        quotation = self.get_quotation_by_id(db, quotation_id, user_id, force_negocio_id=negocio_id)
        if not quotation:
            raise HTTPException(status_code=404, detail="Cotización no encontrada")

        stock_warnings = []
        price_changes = []
        has_stock_issues = False
        has_price_changes = False

        for item in quotation.items:
            if not item.presentation_id: continue

            real_product = db.query(ProductPresentation).filter(ProductPresentation.id == item.presentation_id).first()
            p_name = item.product_name or "Producto"

            current_stock = real_product.stock_actual if real_product else 0
            
            if not real_product or current_stock < item.quantity:
                has_stock_issues = True
                msg = f"Agotado (0 disponibles)." if current_stock <= 0 else f"Pides {item.quantity}, pero solo quedan {current_stock}."
                stock_warnings.append({
                    "item_id": item.id,
                    "product_name": p_name,
                    "stock_status": "no_stock",
                    "available_stock": current_stock,
                    "requested_qty": item.quantity,
                    "message": msg
                })

            if real_product:
                db_base_price = Decimal(str(real_product.precio_venta_final))
                db_effective_price = Decimal(str(real_product.precio_oferta)) if (real_product.precio_oferta and real_product.precio_oferta > 0) else db_base_price
                
                quote_base_price = Decimal(str(item.original_unit_price))
                quote_applied_price = Decimal(str(item.unit_price_applied)) if item.unit_price_applied is not None else Decimal('0.00')

                had_discount = quote_base_price > quote_applied_price + Decimal('0.01')
                has_discount_now = db_base_price > db_effective_price + Decimal('0.01')

                base_price_changed = abs(db_base_price - quote_base_price) > Decimal('0.01')
                applied_price_changed = abs(db_effective_price - quote_applied_price) > Decimal('0.01')

                if item.is_manual_price:
                    if base_price_changed:
                        has_price_changes = True
                        price_changes.append({
                            "item_id": item.id, "product_name": p_name, "price_status": "changed",
                            "old_price": float(quote_applied_price), "new_price": float(quote_applied_price), 
                            "new_base_price": float(db_base_price), 
                            "message": f"El precio del inventario subió. Tu descuento manual sigue protegido."
                        })
                else:
                    if applied_price_changed or base_price_changed:
                        has_price_changes = True
                        msg = "El precio ha cambiado."
                        
                        if had_discount and not has_discount_now:
                            msg = "La oferta expiró o fue removida en tienda."
                        elif not had_discount and has_discount_now:
                            msg = "¡Hay una nueva oferta disponible en tienda!"
                        elif had_discount and has_discount_now and applied_price_changed:
                            msg = "El valor del descuento ha sido modificado."
                        elif base_price_changed:
                            msg = "El precio normal del producto ha subido o bajado."

                        price_changes.append({
                            "item_id": item.id, "product_name": p_name, "price_status": "changed",
                            "old_price": float(quote_applied_price), "new_price": float(db_effective_price),
                            "new_base_price": float(db_base_price),
                            "message": msg
                        })

        status_result = "ok"
        if has_stock_issues: status_result = "critical"
        elif has_price_changes: status_result = "warning"

        return {
            "has_issues": has_stock_issues or has_price_changes,
            "can_sell": not has_stock_issues,
            "status": status_result,
            "stock_warnings": stock_warnings,
            "price_changes": price_changes
        }

smart_quotation_service = SmartQuotationService()