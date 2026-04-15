from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.api import deps
from app.schemas.inventory_matcher import BatchMatchRequest, BatchMatchResponse
from app.services.inventory_matcher_service import inventory_matcher_service

router = APIRouter()

@router.post("/match-batch", response_model=BatchMatchResponse)
def match_inventory_batch(
    data: BatchMatchRequest,
    db: Session = Depends(deps.get_db),
    negocio_id: int = Depends(deps.get_current_business_id) 
):
    try:
        results = inventory_matcher_service.match_batch(
            db=db,
            negocio_id=negocio_id, 
            data=data
        )
        return results
    except Exception as e:
        print(f"Error en matching: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Error interno al procesar las coincidencias: {str(e)}"
        )