from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status, Body
from sqlalchemy.orm import Session
from app.api import deps
from app.models.user import User
from app.schemas.smart_quotation import SmartQuotationCreate, SmartQuotationResponse, SmartQuotationUpdate
from app.services.smart_quotation_service import smart_quotation_service

router = APIRouter()

@router.post("/", response_model=SmartQuotationResponse, status_code=status.HTTP_201_CREATED)
def create_smart_quotation(
    quotation_in: SmartQuotationCreate,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user),
    negocio_id: int = Depends(deps.get_current_business_id) 
):
    try:
        return smart_quotation_service.create_quotation(
            db=db, 
            user_id=current_user.id, 
            data=quotation_in,
            force_negocio_id=negocio_id
        )
    except Exception as e:
        print(f"Error guardando cotización: {e}")
        raise HTTPException(status_code=500, detail=f"Error interno: {str(e)}")

@router.get("/", response_model=List[SmartQuotationResponse])
def read_smart_quotations(
    skip: int = 0, limit: int = 100,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user),
    negocio_id: int = Depends(deps.get_current_business_id) 
):
    return smart_quotation_service.get_quotations_by_user(
        db=db, user_id=current_user.id, skip=skip, limit=limit, force_negocio_id=negocio_id
    )

@router.get("/{quotation_id}", response_model=SmartQuotationResponse)
def read_smart_quotation_detail(
    quotation_id: int,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user),
    negocio_id: int = Depends(deps.get_current_business_id) 
):
    quotation = smart_quotation_service.get_quotation_by_id(db, quotation_id, current_user.id, force_negocio_id=negocio_id)
    if not quotation:
        raise HTTPException(status_code=404, detail="Cotización no encontrada")
    return quotation

@router.put("/{quotation_id}", response_model=SmartQuotationResponse)
@router.patch("/{quotation_id}", response_model=SmartQuotationResponse)
def update_quotation(
    quotation_id: int,
    quotation_update: SmartQuotationUpdate,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user),
    negocio_id: int = Depends(deps.get_current_business_id) 
):
    updated = smart_quotation_service.update_quotation(
        db=db, quotation_id=quotation_id, user_id=current_user.id, update_data=quotation_update, force_negocio_id=negocio_id
    )
    if not updated:
        raise HTTPException(status_code=404, detail="Cotización no encontrada")
    return updated

@router.delete("/{quotation_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_quotation(
    quotation_id: int,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user),
    negocio_id: int = Depends(deps.get_current_business_id) 
):
    success = smart_quotation_service.delete_quotation(db, quotation_id, current_user.id, force_negocio_id=negocio_id)
    if not success:
        raise HTTPException(status_code=404, detail="Cotización no encontrada o no se puede eliminar")
    return None

@router.post("/{quotation_id}/clone", response_model=SmartQuotationResponse)
def clone_quotation(
    quotation_id: int,
    target_client_id: Optional[int] = Body(None, embed=True),
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user),
    negocio_id: int = Depends(deps.get_current_business_id) 
):
    # 🔥 CORRECCIÓN CLONE: Inyectamos negocio_id
    return smart_quotation_service.clone_quotation(
        db=db, quotation_id=quotation_id, user_id=current_user.id, negocio_id=negocio_id, target_client_id=target_client_id
    )

@router.post("/{quotation_id}/refresh", response_model=SmartQuotationResponse)
def refresh_quotation_values(
    quotation_id: int,
    fix_prices: bool = True,
    fix_stock: bool = False,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user),
    negocio_id: int = Depends(deps.get_current_business_id) 
):
    try:
        # 🔥 CORRECCIÓN REFRESH: Inyectamos negocio_id
        return smart_quotation_service.refresh_quotation_values(
            db=db, quotation_id=quotation_id, user_id=current_user.id,
            negocio_id=negocio_id, fix_prices=fix_prices, fix_stock=fix_stock
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error al refrescar: {str(e)}")

@router.get("/{quotation_id}/validate")
def validate_quotation(
    quotation_id: int,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user),
    negocio_id: int = Depends(deps.get_current_business_id) 
):
    # 🔥 CORRECCIÓN VALIDATE: Inyectamos negocio_id para que el servicio no devuelva 403
    return smart_quotation_service.validate_quotation_integrity(
        db=db, quotation_id=quotation_id, user_id=current_user.id, negocio_id=negocio_id
    )

@router.post("/{quotation_id}/to-pack", response_model=SmartQuotationResponse)
def convert_to_pack(
    quotation_id: int,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user),
    negocio_id: int = Depends(deps.get_current_business_id) 
):
    try:
        # 🔥 CORRECCIÓN TO_PACK: Inyectamos negocio_id para que no devuelva 403 ni 500
        return smart_quotation_service.convert_to_pack(db=db, quotation_id=quotation_id, user_id=current_user.id, negocio_id=negocio_id)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error al crear pack: {str(e)}")