from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import datetime

from app.api import deps
from app.models.product import Product
from app.models.product_presentation import ProductPresentation
from app.models.brand import Brand
from app.models.provider import Provider
from app.models.invoice import Invoice
from app.models.notification import Notification
from app.models.user import User
from app.schemas.scanner import BatchExecutionRequest

router = APIRouter()

@router.post("/execute", response_model=bool)
def execute_batch_inventory(
    batch_data: BatchExecutionRequest,
    db: Session = Depends(deps.get_db),
    negocio_id: int = Depends(deps.get_current_business_id),
    current_user: User = Depends(deps.get_current_user) 
):
    try:
        provider_id = None
        if batch_data.proveedor.modo == "existente": provider_id = batch_data.proveedor.id_existente
        elif batch_data.proveedor.nombre_nuevo:
            existing_prov = db.query(Provider).filter(Provider.nombre_empresa.ilike(batch_data.proveedor.nombre_nuevo), Provider.negocio_id == negocio_id).first()
            if existing_prov: provider_id = existing_prov.id
            else:
                new_prov = Provider(nombre_empresa=batch_data.proveedor.nombre_nuevo, ruc=getattr(batch_data.proveedor, 'ruc', None), negocio_id=negocio_id, fecha_creacion=datetime.utcnow(), activo=True)
                db.add(new_prov)
                db.flush()
                provider_id = new_prov.id

        factura_carga_id_global = batch_data.factura_carga_id
        total_factura_acumulado = 0.0

        for prod_input in batch_data.items:
            marca_id = None
            if prod_input.marca:
                if prod_input.marca.modo == "existente": marca_id = prod_input.marca.id_existente
                elif prod_input.marca.nombre_nuevo:
                    existing_brand = db.query(Brand).filter(Brand.nombre.ilike(prod_input.marca.nombre_nuevo), Brand.negocio_id == negocio_id).first()
                    if existing_brand: marca_id = existing_brand.id
                    else:
                        new_brand = Brand(nombre=prod_input.marca.nombre_nuevo, activo=True, negocio_id=negocio_id)
                        db.add(new_brand)
                        db.flush()
                        marca_id = new_brand.id

            product_id = None
            if prod_input.accion == "vincular_existente": product_id = prod_input.id_producto_existente
            elif prod_input.accion == "crear_nuevo":
                new_product = Product(nombre=prod_input.nombre_nuevo, marca_id=marca_id, categoria_id=prod_input.categoria_id, negocio_id=negocio_id, estado="publico")
                db.add(new_product)
                db.flush()
                product_id = new_product.id

            if product_id:
                for variant in prod_input.variantes:
                    total_factura_acumulado += float(variant.total_pago_lote)
                    
                    costo_base_individual = 0.0
                    if variant.cantidad_ump_comprada > 0 and variant.unidades_por_lote > 0:
                        costo_base_individual = float(variant.total_pago_lote) / float(variant.cantidad_ump_comprada * variant.unidades_por_lote)
                    
                    costo_presentacion_venta = costo_base_individual * float(variant.unidades_por_venta)
                    precio_venta_calculado = costo_presentacion_venta * float(variant.factor_ganancia_venta)

                    if variant.id_presentacion_existente:
                        presentation = db.query(ProductPresentation).filter(ProductPresentation.id == variant.id_presentacion_existente).first()
                        if presentation:
                            presentation.stock_actual += variant.cantidad_a_sumar
                            presentation.factura_carga_id = factura_carga_id_global 
                            
                            if variant.actualizar_costo:
                                presentation.ump_compra = variant.ump_compra
                                presentation.precio_ump_proveedor = variant.precio_ump_proveedor
                                presentation.cantidad_ump_comprada = variant.cantidad_ump_comprada
                                presentation.total_pago_lote = variant.total_pago_lote
                                presentation.unidades_por_lote = variant.unidades_por_lote
                                presentation.costo_unitario_calculado = costo_presentacion_venta
                                
                            if variant.actualizar_precio_venta:
                                presentation.unidad_venta = variant.unidad_venta
                                presentation.unidades_por_venta = variant.unidades_por_venta
                                presentation.factor_ganancia_venta = variant.factor_ganancia_venta
                                presentation.precio_venta_final = precio_venta_calculado
                                
                            if variant.actualizar_nombre:
                                presentation.nombre_especifico = variant.nombre_especifico
                            db.add(presentation)
                            
                    else:
                        new_pres = ProductPresentation(
                            producto_id=product_id, proveedor_id=provider_id,
                            ump_compra=variant.ump_compra, precio_ump_proveedor=variant.precio_ump_proveedor,
                            cantidad_ump_comprada=variant.cantidad_ump_comprada, total_pago_lote=variant.total_pago_lote,
                            unidades_por_lote=variant.unidades_por_lote,
                            unidad_venta=variant.unidad_venta, unidades_por_venta=variant.unidades_por_venta,
                            costo_unitario_calculado=costo_presentacion_venta, factor_ganancia_venta=variant.factor_ganancia_venta,
                            precio_venta_final=precio_venta_calculado, nombre_especifico=variant.nombre_especifico,
                            stock_actual=variant.cantidad_a_sumar, codigo_barras=variant.codigo_barras,
                            factura_carga_id=factura_carga_id_global, 
                            estado="publico", es_default=False 
                        )
                        db.add(new_pres)

        # 🔥 ACTUALIZACIÓN DE FACTURA Y NOTIFICACIÓN
        if factura_carga_id_global:
            invoice = db.query(Invoice).filter(Invoice.id == factura_carga_id_global).first()
            if invoice:
                invoice.estado = "completado"
                
                if batch_data.fecha_emision:
                    try:
                        if "/" in batch_data.fecha_emision:
                            invoice.fecha_emision = datetime.strptime(batch_data.fecha_emision, "%d/%m/%Y").date()
                        else:
                            invoice.fecha_emision = datetime.strptime(batch_data.fecha_emision, "%Y-%m-%d").date()
                    except Exception as e:
                        print(f"Error formateando fecha: {e}")

                if provider_id: 
                    invoice.proveedor_id = provider_id
                db.add(invoice)
                
                # 🔥 AQUÍ ESTÁ LA INYECCIÓN DEL negocio_id
                notif = Notification(
                    user_id=current_user.id,
                    negocio_id=negocio_id, 
                    titulo="¡Factura Registrada con Éxito!",
                    mensaje=f"Inventario actualizado. Procesaste la factura del {batch_data.fecha_emision or 'día'}.",
                    tipo="exito",
                    prioridad="Alta",
                    objeto_relacionado_tipo="factura_carga", 
                    objeto_relacionado_id=invoice.id,
                    fecha_creacion=datetime.utcnow()
                )
                db.add(notif)

        db.commit()
        return True

    except Exception as e:
        db.rollback()
        print(f"Error crítico en Batch: {str(e)}") 
        raise HTTPException(status_code=500, detail=f"Error procesando lote: {str(e)}")