from decimal import Decimal
from datetime import datetime
from sqlalchemy.orm import Session
from sqlalchemy import or_, desc
from fastapi import HTTPException

from app.models.cliente import Cliente
from app.models.venta import Venta, Cuota
from app.models.pago import Pago
from app.models.smart_quotation import SmartQuotation 
from app.models.business import Business 
from app.models.notification import Notification 
from app.schemas.cliente import ClienteCreate, ClienteUpdate

class ClientService:

    def _resolve_negocio_id(self, db: Session, user_id: int, negocio_id: int = None) -> int:
        if negocio_id: return negocio_id
        from app.models.negocio_usuario import NegocioUsuario
        vinculo = db.query(NegocioUsuario).filter(NegocioUsuario.usuario_id == user_id, NegocioUsuario.estado_acceso == 'activo').first()
        if vinculo: return vinculo.negocio_id
        biz = db.query(Business).filter(Business.id_dueno == user_id).first()
        if biz: return biz.id
        raise HTTPException(status_code=403, detail="Contexto de negocio requerido.")

    def create_client(self, db: Session, client_in: ClienteCreate, user_id: int, negocio_id: int = None):
        n_id = self._resolve_negocio_id(db, user_id, negocio_id)
        
        nuevo_cliente = Cliente(
            negocio_id=n_id, 
            creado_por_usuario_id=user_id, 
            nombre_completo=client_in.nombre_completo,
            telefono=client_in.telefono,
            dni_ruc=client_in.dni_ruc,
            direccion=client_in.direccion,
            correo=client_in.correo,
            notas=client_in.notas,
            nivel_confianza="bueno",
            etiquetas=[]
        )
        db.add(nuevo_cliente)
        db.commit()
        db.refresh(nuevo_cliente)
        return self._enrich_client_response(nuevo_cliente)

    def update_client(self, db: Session, client_id: int, client_in: ClienteUpdate):
        cliente = db.query(Cliente).filter(Cliente.id == client_id).first()
        if not cliente: return None
        
        update_data = client_in.model_dump(exclude_unset=True)
        for field, value in update_data.items():
            setattr(cliente, field, value)
            
        db.commit()
        db.refresh(cliente)
        return cliente

    def search_clients(self, db: Session, user_id: int, query: str, negocio_id: int = None):
        n_id = self._resolve_negocio_id(db, user_id, negocio_id)
        clientes = db.query(Cliente).filter(
            Cliente.negocio_id == n_id, 
            or_(
                Cliente.nombre_completo.ilike(f"%{query}%"),
                Cliente.telefono.ilike(f"%{query}%"),
                Cliente.dni_ruc.ilike(f"%{query}%")
            )
        ).limit(20).all()
        return [self._enrich_client_response(c) for c in clientes]

    def get_tracking_clients(self, db: Session, user_id: int, con_deuda: bool = False, negocio_id: int = None):
        n_id = self._resolve_negocio_id(db, user_id, negocio_id)
        query = db.query(Cliente).filter(Cliente.negocio_id == n_id) 
        if con_deuda:
            query = query.filter(Cliente.deuda_total > 0)
        clientes = query.order_by(desc(Cliente.deuda_total), Cliente.nombre_completo).all()
        return [self._enrich_client_response(c) for c in clientes]

    def get_deudas_cliente(self, db: Session, client_id: int):
        ventas_pendientes = db.query(Venta).filter(
            Venta.cliente_id == client_id,
            Venta.estado_pago.in_(["pendiente", "parcial"])
        ).order_by(Venta.fecha_venta.asc()).all()
        return ventas_pendientes
        
    def get_cotizaciones_pendientes(self, db: Session, client_id: int):
        cotizaciones = db.query(SmartQuotation).filter(
            SmartQuotation.client_id == client_id,
            SmartQuotation.status != "SOLD"
        ).order_by(desc(SmartQuotation.created_at)).all()
        return cotizaciones

    def _enrich_client_response(self, cliente: Cliente):
        ultimas_ventas = sorted(cliente.ventas, key=lambda x: x.fecha_venta, reverse=True)[:10]
        ultimos_pagos = sorted(cliente.pagos, key=lambda x: x.fecha_pago, reverse=True)[:5]
        
        return {
            "id": cliente.id,
            "negocio_id": cliente.negocio_id,
            "creado_por_usuario_id": cliente.creado_por_usuario_id,
            "usuario_vinculado_id": cliente.usuario_vinculado_id,
            "nombre_completo": cliente.nombre_completo,
            "telefono": cliente.telefono,
            "dni_ruc": cliente.dni_ruc,
            "direccion": cliente.direccion,
            "correo": cliente.correo,
            "notas": cliente.notas,
            "nivel_confianza": cliente.nivel_confianza,
            "etiquetas": cliente.etiquetas,
            "deuda_total": float(cliente.deuda_total) if cliente.deuda_total else 0.0,
            "saldo_a_favor": float(cliente.saldo_a_favor) if cliente.saldo_a_favor else 0.0,
            "entregas_pendientes": cliente.entregas_pendientes or 0,
            "fecha_registro": cliente.fecha_registro,
            "ultimas_ventas": [
                {
                    "id": v.id, "monto_total": float(v.monto_total), "monto_pagado": float(v.monto_pagado), 
                    "fecha_venta": v.fecha_venta, "estado_entrega": v.estado_entrega, "origen_venta": v.origen_venta,
                    "items_count": sum(item.quantity for item in v.cotizacion.items) if v.cotizacion else 0
                } for v in ultimas_ventas
            ],
            "ultimos_pagos": [
                {
                    # 🔥 SOLUCIÓN DEL CRASHEO 500 (Se añaden los campos faltantes)
                    "id": p.id, 
                    "negocio_id": p.negocio_id,
                    "creado_por_usuario_id": p.creado_por_usuario_id,
                    "monto": float(p.monto), 
                    "metodo_pago": p.metodo_pago, 
                    "nota": p.nota,
                    "venta_id": p.venta_id,
                    "cuota_id": p.cuota_id,
                    "fecha_pago": p.fecha_pago
                } for p in ultimos_pagos
            ]
        }

    def registrar_abono(self, db: Session, client_id: int, pago_in, user_id: int = None, negocio_id: int = None):
        n_id = self._resolve_negocio_id(db, user_id, negocio_id) if user_id else None
        
        cliente = db.query(Cliente).filter(Cliente.id == client_id).first()
        if not cliente: raise HTTPException(status_code=404, detail="Cliente no encontrado")

        if pago_in.metodo_pago == "saldo_a_favor":
            current_saldo = Decimal(str(cliente.saldo_a_favor)) if cliente.saldo_a_favor else Decimal('0.00')
            if current_saldo < Decimal(str(pago_in.monto)):
                raise HTTPException(status_code=400, detail="Saldo a favor insuficiente")
            cliente.saldo_a_favor = float(current_saldo - Decimal(str(pago_in.monto)))

        nuevo_pago = Pago(
            negocio_id=n_id or cliente.negocio_id, 
            creado_por_usuario_id=user_id or cliente.creado_por_usuario_id, 
            cliente_id=client_id, monto=pago_in.monto, metodo_pago=pago_in.metodo_pago,
            nota=pago_in.nota, venta_id=pago_in.venta_id, cuota_id=pago_in.cuota_id
        )
        db.add(nuevo_pago)

        monto_restante = Decimal(str(pago_in.monto))

        # 1. PAGO A CUOTA ESPECÍFICA
        if pago_in.cuota_id:
            cuota = db.query(Cuota).filter(Cuota.id == pago_in.cuota_id).first()
            if cuota:
                falta_cuota = Decimal(str(cuota.monto)) - Decimal(str(cuota.monto_pagado))
                pagado_a_cuota = min(monto_restante, falta_cuota)
                
                cuota.monto_pagado = float(Decimal(str(cuota.monto_pagado)) + pagado_a_cuota)
                cuota.estado = "pagado" if cuota.monto_pagado >= cuota.monto else "parcial"
                
                venta = cuota.venta
                venta.monto_pagado = float(Decimal(str(venta.monto_pagado)) + pagado_a_cuota)
                
                if venta.monto_pagado >= venta.monto_total: 
                    venta.estado_pago = "pagado"
                    if venta.estado_entrega == "retenido_por_pago":
                        venta.estado_entrega = "pendiente_recojo"
                elif venta.monto_pagado > 0: 
                    venta.estado_pago = "parcial"
                    
                monto_restante -= pagado_a_cuota

        # 2. PAGO A VENTA ESPECÍFICA
        elif pago_in.venta_id:
            venta = db.query(Venta).filter(Venta.id == pago_in.venta_id).first()
            if venta:
                falta_venta = Decimal(str(venta.monto_total)) - Decimal(str(venta.monto_pagado))
                pagado_a_venta = min(monto_restante, falta_venta)
                
                venta.monto_pagado = float(Decimal(str(venta.monto_pagado)) + pagado_a_venta)
                
                if venta.monto_pagado >= venta.monto_total: 
                    venta.estado_pago = "pagado"
                    if venta.estado_entrega == "retenido_por_pago":
                        venta.estado_entrega = "pendiente_recojo"
                elif venta.monto_pagado > 0: 
                    venta.estado_pago = "parcial"
                
                monto_para_cuotas = pagado_a_venta
                for cuota in sorted(venta.cuotas, key=lambda x: x.fecha_vencimiento):
                    if monto_para_cuotas <= 0: break
                    if cuota.estado != "pagado":
                        c_falta = Decimal(str(cuota.monto)) - Decimal(str(cuota.monto_pagado))
                        c_pago = min(monto_para_cuotas, c_falta)
                        cuota.monto_pagado = float(Decimal(str(cuota.monto_pagado)) + c_pago)
                        cuota.estado = "pagado" if cuota.monto_pagado >= cuota.monto else "parcial"
                        monto_para_cuotas -= c_pago

                monto_restante -= pagado_a_venta

        # 3. PAGO GLOBAL
        if monto_restante > 0:
            ventas_pendientes = db.query(Venta).filter(
                Venta.cliente_id == client_id,
                Venta.estado_pago.in_(["pendiente", "parcial"])
            ).order_by(Venta.fecha_venta.asc()).all()

            for venta in ventas_pendientes:
                if monto_restante <= 0: break
                falta = Decimal(str(venta.monto_total)) - Decimal(str(venta.monto_pagado))
                pago_aplicado = min(monto_restante, falta)
                
                venta.monto_pagado = float(Decimal(str(venta.monto_pagado)) + pago_aplicado)
                
                if venta.monto_pagado >= venta.monto_total: 
                    venta.estado_pago = "pagado"
                    if venta.estado_entrega == "retenido_por_pago":
                        venta.estado_entrega = "pendiente_recojo"
                else: 
                    venta.estado_pago = "parcial"
                
                monto_para_cuotas = pago_aplicado
                for cuota in sorted(venta.cuotas, key=lambda x: x.fecha_vencimiento):
                    if monto_para_cuotas <= 0: break
                    if cuota.estado != "pagado":
                        c_falta = Decimal(str(cuota.monto)) - Decimal(str(cuota.monto_pagado))
                        c_pago = min(monto_para_cuotas, c_falta)
                        cuota.monto_pagado = float(Decimal(str(cuota.monto_pagado)) + c_pago)
                        cuota.estado = "pagado" if cuota.monto_pagado >= cuota.monto else "parcial"
                        monto_para_cuotas -= c_pago

                monto_restante -= pago_aplicado

        # 4. Gestionar Sobrante y Deuda Global
        if monto_restante > 0 and pago_in.guardar_vuelto:
            current_saldo = Decimal(str(cliente.saldo_a_favor)) if cliente.saldo_a_favor else Decimal('0.00')
            cliente.saldo_a_favor = float(current_saldo + monto_restante)

        monto_consumido = Decimal(str(pago_in.monto)) - monto_restante if not pago_in.guardar_vuelto else Decimal(str(pago_in.monto))
        nueva_deuda = float(max(Decimal('0.00'), Decimal(str(cliente.deuda_total)) - monto_consumido))
        
        cliente.deuda_total = nueva_deuda
        if nueva_deuda == 0: cliente.nivel_confianza = "excelente"

        # 🔥 LÓGICA DE NOTIFICACIONES DE PAGOS Y DEUDAS
        negocio = db.query(Business).filter(Business.id == (n_id or cliente.negocio_id)).first()
        
        if negocio:
            # 4.1 Notificar al Cliente (Si usa la App)
            if cliente.usuario_vinculado_id:
                db.add(Notification(
                    user_id=cliente.usuario_vinculado_id,
                    negocio_id=negocio.id,
                    titulo="¡Pago Registrado!",
                    mensaje=f"Se ha registrado un abono de S/{pago_in.monto:.2f} a tu cuenta en {negocio.nombre_comercial}.",
                    tipo="exito", prioridad="Alta"
                ))
                
                # Si el pago saldó toda la cuenta
                if nueva_deuda == 0 and Decimal(str(pago_in.monto)) > 0:
                    db.add(Notification(
                        user_id=cliente.usuario_vinculado_id,
                        negocio_id=negocio.id,
                        titulo="¡Cuenta al Día!",
                        mensaje=f"Has cancelado el total de tu deuda en {negocio.nombre_comercial}. ¡Muchas gracias!",
                        tipo="exito", prioridad="Media"
                    ))

            # 4.2 Notificar al Dueño (Opcional, si quien cobró fue un trabajador u otro medio)
            dueño_id = negocio.id_dueno
            if dueño_id and user_id != dueño_id:
                 db.add(Notification(
                    user_id=dueño_id,
                    negocio_id=negocio.id,
                    titulo="Nuevo Abono Registrado",
                    mensaje=f"Se registró un abono de S/{pago_in.monto:.2f} del cliente {cliente.nombre_completo}.",
                    tipo="info", prioridad="Media"
                ))

        db.commit()
        return True

    def get_estado_cuenta(self, db: Session, client_id: int):
        ventas = db.query(Venta).filter(Venta.cliente_id == client_id, Venta.monto_total > 0).all()
        pagos = db.query(Pago).filter(Pago.cliente_id == client_id).all()
        timeline = []
        for v in ventas:
            timeline.append({
                "id_ref": v.id, "tipo": "cargo", "fecha": v.fecha_venta, "monto": float(v.monto_total),
                "detalle": f"Venta #{v.id} ({'Caja Rápida' if v.origen_venta == 'pos_rapido' else 'Lista Cotizada'})"
            })
        for p in pagos:
            origen = "Abono de Deuda"
            if p.venta_id: origen = f"Abono a Venta #{p.venta_id}"
            if p.cuota_id: origen = f"Abono a Cuota de Venta #{p.venta_id}"
            if "Pago inicial" in (p.nota or ""): origen = f"Pago al Instante (Venta #{p.venta_id})"
            timeline.append({
                "id_ref": p.id, "tipo": "abono", "fecha": p.fecha_pago, "monto": float(p.monto),
                "detalle": f"{origen} - {p.metodo_pago.upper()}"
            })
        
        timeline.sort(key=lambda x: x["fecha"])
        saldo = 0.0
        for item in timeline:
            if item["tipo"] == "cargo": saldo += item["monto"]
            else: saldo -= item["monto"]
            item["saldo_resultante"] = saldo 
            
        return list(reversed(timeline))

client_service = ClientService()