from decimal import Decimal
from sqlalchemy.orm import Session
from sqlalchemy import func, desc, asc
from datetime import datetime
from fastapi import HTTPException

from app.models.venta import Venta, EstadoPago, EstadoEntrega, Cuota
from app.models.smart_quotation import SmartQuotation, QuotationStatus, SmartQuotationItem, QuotationType 
from app.models.cliente import Cliente
from app.models.product import Product 
from app.models.product_presentation import ProductPresentation
from app.models.pago import Pago
from app.models.notification import Notification 
from app.models.negocio_usuario import NegocioUsuario
from app.schemas.venta import VentaCreate

class SalesService:

    def _get_strict_negocio_id(self, negocio_id: int = None) -> int:
        if not negocio_id: 
            raise HTTPException(status_code=403, detail="Contexto de negocio estrictamente requerido por seguridad.")
        return negocio_id
    
    def create_sale(self, db: Session, user_id: int, data: VentaCreate, negocio_id: int = None) -> Venta:
        n_id = self._get_strict_negocio_id(negocio_id)
        
        vinculo = db.query(NegocioUsuario).filter(
            NegocioUsuario.usuario_id == user_id, 
            NegocioUsuario.negocio_id == n_id
        ).first()
        
        is_client_role = vinculo and vinculo.rol_en_negocio == "cliente_comunidad"
        
        if is_client_role and not data.cliente_id:
            cliente_crm = db.query(Cliente).filter(
                Cliente.usuario_vinculado_id == user_id, 
                Cliente.negocio_id == n_id
            ).first()
            
            if cliente_crm:
                data.cliente_id = cliente_crm.id
                if not data.client_name_override or data.client_name_override.startswith("Mi Pedido"):
                    data.client_name_override = f"{cliente_crm.nombre_completo} - {data.client_name_override or 'Pedido Nuevo'}"

        cotizacion_final_id = None
        alertas_stock = []

        if data.cotizacion_id:
            quotation = db.query(SmartQuotation).filter(
                SmartQuotation.id == data.cotizacion_id, 
                SmartQuotation.negocio_id == n_id 
            ).first()
            
            if not quotation: raise HTTPException(status_code=404, detail="Cotización no encontrada")
            if quotation.status == QuotationStatus.SOLD.value: raise HTTPException(status_code=400, detail="Esta cotización ya fue vendida")

            if is_client_role and not quotation.client_id and data.cliente_id:
                quotation.client_id = data.cliente_id
                if quotation.client_name and quotation.client_name.startswith("Mi Pedido"):
                    quotation.client_name = data.client_name_override

            if data.notas is not None:
                quotation.notas = data.notas

            for item in quotation.items:
                if item.presentation_id:
                    product = db.query(ProductPresentation).filter(ProductPresentation.id == item.presentation_id).with_for_update().first()
                    
                    unidades_a_descontar = item.quantity
                    
                    if not product or product.stock_actual < unidades_a_descontar:
                        db.rollback()
                        nombre_mostrar = item.product_name or "Producto desconocido"
                        stock_disp = product.stock_actual if product else 0
                        raise HTTPException(status_code=400, detail=f"Stock insuficiente para '{nombre_mostrar}'. Intentaste vender {unidades_a_descontar}, pero quedan {stock_disp} disp.") 
                    
                    product.stock_actual -= unidades_a_descontar
                    
                    if product.stock_actual <= product.stock_alerta: alertas_stock.append(product)
                    db.add(product)

            quotation.status = QuotationStatus.SOLD.value
            db.add(quotation)
            cotizacion_final_id = quotation.id
            
        else:
            if not data.detalle_venta or len(data.detalle_venta) == 0:
                raise HTTPException(status_code=400, detail="La venta rápida debe contener al menos un producto.")
            
            nueva_cotizacion = SmartQuotation(
                negocio_id=n_id,
                creado_por_usuario_id=user_id,
                client_id=data.cliente_id, 
                client_name=data.client_name_override or "Venta Rápida POS",
                notas=data.notas,
                total_amount=data.monto_total,
                total_savings=data.descuento_aplicado, 
                status=QuotationStatus.SOLD.value,
                type="pos_rapido", 
                is_template=False, 
                institution_name="Venta al Paso POS"
            )
            db.add(nueva_cotizacion)
            db.flush() 

            for item in data.detalle_venta:
                product_pres = db.query(ProductPresentation).filter(ProductPresentation.id == item.presentation_id).with_for_update().first()
                unidades_a_descontar = item.quantity

                if not product_pres or product_pres.stock_actual < unidades_a_descontar:
                    db.rollback()
                    nombre_p = "Producto Desconocido"
                    stock_disp = 0
                    if product_pres:
                        stock_disp = product_pres.stock_actual
                        parent = db.query(Product).filter(Product.id == product_pres.producto_id).first()
                        if parent: nombre_p = f"{parent.nombre} {product_pres.nombre_especifico or ''}".strip()

                    raise HTTPException(status_code=400, detail=f"Stock insuficiente para '{nombre_p}'. Intentaste vender {unidades_a_descontar}, pero quedan {stock_disp} disp.")
                
                parent_product = db.query(Product).filter(Product.id == product_pres.producto_id).first()
                p_name = parent_product.nombre if parent_product else "Producto Desconocido"
                b_name = parent_product.marca.nombre if (parent_product and parent_product.marca) else ""
                s_name = product_pres.nombre_especifico or ""
                u_venta = product_pres.unidad_venta or "Unidad"

                nuevo_item = SmartQuotationItem(
                    quotation_id=nueva_cotizacion.id, product_id=product_pres.producto_id, presentation_id=product_pres.id,
                    product_name=p_name, brand_name=b_name, specific_name=s_name, sales_unit=u_venta,
                    original_text="Producto de Venta Rápida", 
                    quantity=item.quantity, unit_price_applied=item.unit_price, original_unit_price=product_pres.precio_venta_final, 
                    is_manual_price=False, is_available=True
                )
                db.add(nuevo_item)
                product_pres.stock_actual -= unidades_a_descontar
                
                if product_pres.stock_actual <= product_pres.stock_alerta: alertas_stock.append(product_pres)
                db.add(product_pres)
            
            cotizacion_final_id = nueva_cotizacion.id

        new_sale = Venta(
            negocio_id=n_id,
            creado_por_usuario_id=user_id,
            cotizacion_id=cotizacion_final_id, cliente_id=data.cliente_id, origen_venta=data.origen_venta,   
            metodo_pago=data.metodo_pago, estado_pago=data.estado_pago, estado_entrega=data.estado_entrega,
            fecha_entrega=data.fecha_entrega, monto_total=data.monto_total, monto_pagado=data.monto_pagado,
            descuento_aplicado=data.descuento_aplicado, fecha_venta=datetime.utcnow()
        )
        db.add(new_sale)
        db.flush()

        if data.monto_pagado > 0:
            pago_inicial = Pago(
                negocio_id=n_id, creado_por_usuario_id=user_id, cliente_id=data.cliente_id, 
                venta_id=new_sale.id, monto=data.monto_pagado, metodo_pago=data.metodo_pago, nota="Abono inmediato en caja"
            )
            db.add(pago_inicial)

        if data.cuotas and len(data.cuotas) > 0:
            for cuota_in in data.cuotas:
                nueva_cuota = Cuota(
                    venta_id=new_sale.id, numero_cuota=cuota_in.numero_cuota, monto=cuota_in.monto,
                    monto_pagado=0.00, fecha_vencimiento=cuota_in.fecha_vencimiento, estado="pendiente"
                )
                db.add(nueva_cuota)

        cliente_obj = None
        if data.cliente_id:
            cliente_obj = db.query(Cliente).filter(Cliente.id == data.cliente_id).first()
            if cliente_obj:
                monto_total_dec = Decimal(str(data.monto_total))
                monto_pagado_dec = Decimal(str(data.monto_pagado))
                
                if data.metodo_pago == "saldo_a_favor":
                    current_saldo = Decimal(str(cliente_obj.saldo_a_favor)) if cliente_obj.saldo_a_favor else Decimal('0.00')
                    if current_saldo < monto_pagado_dec:
                        db.rollback()
                        raise HTTPException(status_code=400, detail="Saldo a favor insuficiente para cubrir este pago.")
                    cliente_obj.saldo_a_favor = float(current_saldo - monto_pagado_dec)

                deuda_nueva = monto_total_dec - monto_pagado_dec
                if deuda_nueva > 0:
                    current_deuda = Decimal(str(cliente_obj.deuda_total)) if cliente_obj.deuda_total is not None else Decimal('0.00')
                    cliente_obj.deuda_total = current_deuda + deuda_nueva
                    cliente_obj.nivel_confianza = "regular" 
                
                estados_pendientes = [EstadoEntrega.PENDIENTE_RECOJO.value, EstadoEntrega.RETENIDO_POR_PAGO.value]
                if data.estado_entrega in estados_pendientes:
                    cliente_obj.entregas_pendientes = (cliente_obj.entregas_pendientes or 0) + 1
                db.add(cliente_obj)

        db.add(Notification(
            user_id=user_id, negocio_id=n_id,
            titulo="¡Lista Vendida!" if data.cotizacion_id else "¡Venta de Caja Rápida!",
            mensaje=f"Se ha registrado una venta por S/{data.monto_total:.2f}.",
            tipo="exito", prioridad="Media",
            objeto_relacionado_tipo="venta_admin", objeto_relacionado_id=new_sale.id
        ))

        if cliente_obj and cliente_obj.usuario_vinculado_id:
            db.add(Notification(
                user_id=cliente_obj.usuario_vinculado_id, negocio_id=n_id, 
                titulo="¡Tu compra fue un éxito!",
                mensaje=f"Hemos registrado tu compra en {cliente_obj.negocio.nombre_comercial} por S/{data.monto_total:.2f}.",
                tipo="info", prioridad="Alta",
                objeto_relacionado_tipo="venta_cliente", objeto_relacionado_id=new_sale.id
            ))
        
        for pres in alertas_stock:
            db.add(Notification(
                user_id=user_id, negocio_id=n_id, 
                titulo="¡Stock Bajo!",
                mensaje=f"El producto '{pres.nombre_especifico or pres.unidad_venta}' acaba de bajar a {pres.stock_actual} disp.",
                tipo="alerta", prioridad="Alta",
                objeto_relacionado_tipo="producto", objeto_relacionado_id=pres.producto_id
            ))

        db.commit()
        db.refresh(new_sale)
        return new_sale

    # 🔥 SOLUCIÓN AL HISTORIAL VACÍO: Ahora filtramos por cliente_id si es cliente B2C
    def get_sales_history_filtered(self, db: Session, user_id: int, skip: int, limit: int, start_date: datetime = None, end_date: datetime = None, search_query: str = None, is_archived: bool = False, origen_venta: str = None, sort_by: str = "fecha_venta", order: str = "desc", negocio_id: int = None):
        n_id = self._get_strict_negocio_id(negocio_id) 
        
        vinculo = db.query(NegocioUsuario).filter(
            NegocioUsuario.usuario_id == user_id, 
            NegocioUsuario.negocio_id == n_id
        ).first()

        query = db.query(Venta).filter(Venta.negocio_id == n_id, Venta.is_archived == is_archived)
        
        if vinculo and vinculo.rol_en_negocio == "cliente_comunidad":
            cliente_crm = db.query(Cliente).filter(Cliente.usuario_vinculado_id == user_id, Cliente.negocio_id == n_id).first()
            if cliente_crm:
                query = query.filter(Venta.cliente_id == cliente_crm.id)
            else:
                return [] # Si el cliente aún no existe en el CRM, no tiene historial
            
        if origen_venta: query = query.filter(Venta.origen_venta == origen_venta)
        if start_date: query = query.filter(Venta.fecha_venta >= start_date)
        if end_date: query = query.filter(Venta.fecha_venta <= end_date)
        if search_query:
            query = query.join(Cliente, Venta.cliente_id == Cliente.id).filter(Cliente.nombre_completo.ilike(f"%{search_query}%"))
            
        sort_column = getattr(Venta, sort_by, Venta.fecha_venta)
        if order == "asc": query = query.order_by(asc(sort_column))
        else: query = query.order_by(desc(sort_column))
        return query.offset(skip).limit(limit).all()

    # 🔥 SOLUCIÓN A ESTADÍSTICAS VACÍAS
    def get_sales_stats(self, db: Session, user_id: int, start_date: datetime = None, end_date: datetime = None, is_archived: bool = False, origen_venta: str = None, negocio_id: int = None):
        n_id = self._get_strict_negocio_id(negocio_id) 
        
        vinculo = db.query(NegocioUsuario).filter(
            NegocioUsuario.usuario_id == user_id, 
            NegocioUsuario.negocio_id == n_id
        ).first()

        query = db.query(func.sum(Venta.monto_pagado).label('total_ingresos'), func.sum(Venta.monto_total - Venta.monto_pagado).label('total_deuda'), func.count(Venta.id).label('cantidad_ventas')).filter(Venta.negocio_id == n_id, Venta.is_archived == is_archived)
        
        if vinculo and vinculo.rol_en_negocio == "cliente_comunidad":
            cliente_crm = db.query(Cliente).filter(Cliente.usuario_vinculado_id == user_id, Cliente.negocio_id == n_id).first()
            if cliente_crm:
                query = query.filter(Venta.cliente_id == cliente_crm.id)
            else:
                return {"total_ingresos": 0.0, "total_deuda": 0.0, "cantidad_ventas": 0}
            
        if origen_venta: query = query.filter(Venta.origen_venta == origen_venta)
        if start_date: query = query.filter(Venta.fecha_venta >= start_date)
        if end_date: query = query.filter(Venta.fecha_venta <= end_date)
        result = query.first()
        return {
            "total_ingresos": float(result.total_ingresos or 0.0),
            "total_deuda": float(result.total_deuda or 0.0),
            "cantidad_ventas": result.cantidad_ventas or 0
        }
    
    # 🔥 SOLUCIÓN A DETALLE VACÍO
    def get_sale_detail(self, db: Session, sale_id: int, user_id: int, negocio_id: int = None):
        n_id = self._get_strict_negocio_id(negocio_id) 
        
        vinculo = db.query(NegocioUsuario).filter(
            NegocioUsuario.usuario_id == user_id, 
            NegocioUsuario.negocio_id == n_id
        ).first()

        query = db.query(Venta).filter(Venta.id == sale_id, Venta.negocio_id == n_id)
        
        if vinculo and vinculo.rol_en_negocio == "cliente_comunidad":
            cliente_crm = db.query(Cliente).filter(Cliente.usuario_vinculado_id == user_id, Cliente.negocio_id == n_id).first()
            if cliente_crm:
                query = query.filter(Venta.cliente_id == cliente_crm.id)
            else:
                raise HTTPException(status_code=403, detail="Venta no encontrada en tu historial.")
            
        venta = query.first()
        
        if not venta: raise HTTPException(status_code=404, detail="Venta no encontrada")
        cliente = db.query(Cliente).filter(Cliente.id == venta.cliente_id).first()
        return {
            "id": venta.id, "negocio_id": venta.negocio_id, "creado_por_usuario_id": venta.creado_por_usuario_id,
            "cotizacion_id": venta.cotizacion_id, "cliente_id": venta.cliente_id, "origen_venta": venta.origen_venta, "is_archived": venta.is_archived,
            "metodo_pago": venta.metodo_pago, "estado_pago": venta.estado_pago, "estado_entrega": venta.estado_entrega, "fecha_entrega": venta.fecha_entrega,
            "monto_total": venta.monto_total, "monto_pagado": venta.monto_pagado, "descuento_aplicado": venta.descuento_aplicado, "fecha_venta": venta.fecha_venta,
            "cuotas": venta.cuotas, "cotizacion": venta.cotizacion, "cliente_nombre": cliente.nombre_completo if cliente else "Cliente Desconocido", "cliente_telefono": cliente.telefono if cliente else None
        }

    def toggle_archive_sale(self, db: Session, sale_id: int, user_id: int, negocio_id: int = None) -> bool:
        n_id = self._get_strict_negocio_id(negocio_id) 
        
        vinculo = db.query(NegocioUsuario).filter(
            NegocioUsuario.usuario_id == user_id, 
            NegocioUsuario.negocio_id == n_id
        ).first()
        
        if vinculo and vinculo.rol_en_negocio == "cliente_comunidad":
            raise HTTPException(status_code=403, detail="No tienes permisos para archivar ventas.")
        
        sale = db.query(Venta).filter(Venta.id == sale_id, Venta.negocio_id == n_id).first()
        if not sale: raise HTTPException(status_code=404, detail="Venta no encontrada")
        sale.is_archived = not sale.is_archived
        db.commit()
        return sale.is_archived

    def update_delivery_status(self, db: Session, sale_id: int, new_status: str, user_id: int, negocio_id: int = None) -> Venta:
        n_id = self._get_strict_negocio_id(negocio_id) 
        
        vinculo = db.query(NegocioUsuario).filter(
            NegocioUsuario.usuario_id == user_id, 
            NegocioUsuario.negocio_id == n_id
        ).first()
        
        if vinculo and vinculo.rol_en_negocio == "cliente_comunidad":
            raise HTTPException(status_code=403, detail="No tienes permisos para actualizar el estado logístico.")
            
        sale = db.query(Venta).filter(Venta.id == sale_id, Venta.negocio_id == n_id).first()
        if not sale: raise HTTPException(status_code=404, detail="Venta no encontrada")
            
        cliente = db.query(Cliente).filter(Cliente.id == sale.cliente_id).first()
        old_status = sale.estado_entrega
        sale.estado_entrega = new_status
        
        pendientes_states = ["pendiente_recojo", "retenido_por_pago", "en_camino"]
        was_pending = old_status in pendientes_states
        is_pending = new_status in pendientes_states
        
        if was_pending and not is_pending:
            if cliente: cliente.entregas_pendientes = max(0, (cliente.entregas_pendientes or 0) - 1)
        elif not was_pending and is_pending:
            if cliente: cliente.entregas_pendientes = (cliente.entregas_pendientes or 0) + 1
            
        if cliente: db.add(cliente)
        db.commit()
        db.refresh(sale)
        return sale

sales_service = SalesService()