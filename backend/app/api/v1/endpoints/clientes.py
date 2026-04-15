from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.api import deps
from app.models.user import User
from app.models.cliente import Cliente

from app.schemas.cliente import ClienteCreate, ClienteUpdate, ClienteResponse, LedgerItem
from app.schemas.pago import PagoCreate 
from app.schemas.venta import VentaResponse 
from app.schemas.smart_quotation import SmartQuotationResponse 
from app.services.client_service import client_service

router = APIRouter()

@router.post("/", response_model=ClienteResponse)
def create_client(
    client_in: ClienteCreate, 
    db: Session = Depends(deps.get_db), 
    current_user: User = Depends(deps.get_current_user),
    negocio_id: int = Depends(deps.get_current_business_id) # 🔥 INYECTADO
):
    return client_service.create_client(db, client_in, current_user.id, negocio_id) 

@router.put("/{client_id}", response_model=ClienteResponse)
def update_client(
    client_id: int, 
    client_in: ClienteUpdate, 
    db: Session = Depends(deps.get_db), 
    current_user: User = Depends(deps.get_current_user),
    negocio_id: int = Depends(deps.get_current_business_id) # 🔥 INYECTADO PARA SEGURIDAD
):
    cliente = client_service.update_client(db, client_id, client_in)
    if not cliente: raise HTTPException(status_code=404, detail="Cliente no encontrado")
    return client_service._enrich_client_response(cliente)

@router.post("/{client_id}/pagos")
def registrar_abono(
    client_id: int, 
    pago_in: PagoCreate, 
    db: Session = Depends(deps.get_db), 
    current_user: User = Depends(deps.get_current_user),
    negocio_id: int = Depends(deps.get_current_business_id) # 🔥 INYECTADO
):
    success = client_service.registrar_abono(db, client_id, pago_in, current_user.id, negocio_id)
    if not success: raise HTTPException(status_code=400, detail="No se pudo registrar el pago. Verifica los montos.")
    return {"message": "Pago registrado exitosamente"}

@router.get("/{client_id}/ledger", response_model=List[LedgerItem])
def get_estado_cuenta(
    client_id: int, 
    db: Session = Depends(deps.get_db), 
    current_user: User = Depends(deps.get_current_user),
    negocio_id: int = Depends(deps.get_current_business_id) # 🔥 INYECTADO PARA SEGURIDAD
):
    return client_service.get_estado_cuenta(db, client_id)

@router.get("/{client_id}/deudas", response_model=List[VentaResponse])
def get_deudas_cliente(
    client_id: int, 
    db: Session = Depends(deps.get_db), 
    current_user: User = Depends(deps.get_current_user),
    negocio_id: int = Depends(deps.get_current_business_id) # 🔥 INYECTADO PARA SEGURIDAD
):
    return client_service.get_deudas_cliente(db, client_id)

@router.get("/{client_id}/cotizaciones_pendientes", response_model=List[SmartQuotationResponse])
def get_cotizaciones_cliente(
    client_id: int, 
    db: Session = Depends(deps.get_db), 
    current_user: User = Depends(deps.get_current_user),
    negocio_id: int = Depends(deps.get_current_business_id) # 🔥 INYECTADO PARA SEGURIDAD
):
    return client_service.get_cotizaciones_pendientes(db, client_id)

@router.get("/tracking", response_model=List[ClienteResponse])
def get_clients_tracking(
    con_deuda: bool = False, 
    db: Session = Depends(deps.get_db), 
    current_user: User = Depends(deps.get_current_user),
    negocio_id: int = Depends(deps.get_current_business_id) # 🔥 INYECTADO
):
    return client_service.get_tracking_clients(db, current_user.id, con_deuda, negocio_id) 

@router.get("/", response_model=List[ClienteResponse])
def search_clients(
    q: Optional[str] = None, 
    db: Session = Depends(deps.get_db), 
    current_user: User = Depends(deps.get_current_user),
    negocio_id: int = Depends(deps.get_current_business_id) # 🔥 INYECTADO
):
    if not q: return []
    return client_service.search_clients(db, current_user.id, q, negocio_id) 

@router.get("/{client_id}", response_model=ClienteResponse)
def read_client(
    client_id: int, 
    db: Session = Depends(deps.get_db), 
    current_user: User = Depends(deps.get_current_user),
    negocio_id: int = Depends(deps.get_current_business_id) # 🔥 INYECTADO
):
    # Buscamos asegurando el aislamiento del negocio
    cliente = db.query(Cliente).filter(Cliente.id == client_id, Cliente.negocio_id == negocio_id).first()
    if not cliente: raise HTTPException(status_code=404, detail="Cliente no encontrado")
    return client_service._enrich_client_response(cliente)