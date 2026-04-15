from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Any
from datetime import datetime

from app.api import deps
from app.models.user import User
from app.models.smart_quotation import SmartQuotation, QuotationStatus, QuotationType
from app.schemas.smart_quotation import SmartQuotationResponse, SmartQuotationCreate
from app.services.smart_quotation_service import smart_quotation_service

router = APIRouter()

# 1. EL CLIENTE ENVÍA SU CARRITO
@router.post("/create", response_model=SmartQuotationResponse)
def submit_community_cart(
    cart_in: SmartQuotationCreate,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user),
    negocio_id: int = Depends(deps.get_current_business_id) # Obtenido del Token Contextual
) -> Any:
    # Forzamos el estado a Pendiente de Aprobación
    # Usamos .value de forma segura para evitar errores en PostgreSQL
    cart_in.status = str(QuotationStatus.PENDING_APPROVAL.value)
    cart_in.type = str(QuotationType.CLIENT_WEB.value)

    # Usamos el servicio existente pero con la bandera comunitaria
    return smart_quotation_service.create_quotation(
        db=db, 
        user_id=current_user.id, 
        data=cart_in,
        force_negocio_id=negocio_id # Inyectamos el negocio del token
    )

# 2. EL DUEÑO/TRABAJADOR VE LA BANDEJA DE ENTRADA
@router.get("/pending-requests", response_model=List[SmartQuotationResponse])
def get_pending_community_requests(
    db: Session = Depends(deps.get_db),
    negocio_id: int = Depends(deps.get_current_business_id)
) -> Any:
    # Lista todas las cotizaciones del negocio que están esperando aprobación
    return db.query(SmartQuotation).filter(
        SmartQuotation.negocio_id == negocio_id,
        SmartQuotation.status == str(QuotationStatus.PENDING_APPROVAL.value)
    ).order_by(SmartQuotation.created_at.desc()).all()