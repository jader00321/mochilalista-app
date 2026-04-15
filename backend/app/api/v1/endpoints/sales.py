from typing import List, Optional
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from app.api import deps
from app.models.user import User
from pydantic import BaseModel

from app.schemas.venta import VentaCreate, VentaResponse, SalesStatsResponse, VentaDetailResponse
from app.services.sales_service import sales_service

class DeliveryStatusUpdate(BaseModel):
    estado_entrega: str

router = APIRouter()

@router.post("/create", response_model=VentaResponse)
def create_sale(
    sale_in: VentaCreate, 
    db: Session = Depends(deps.get_db), 
    current_user: User = Depends(deps.get_current_user),
    negocio_id: int = Depends(deps.get_current_business_id) # 🔥 INYECTADO
):
    return sales_service.create_sale(db=db, user_id=current_user.id, data=sale_in, negocio_id=negocio_id)

@router.get("/history", response_model=List[VentaResponse])
def get_sales_history(
    skip: int = 0, limit: int = 50, start_date: Optional[datetime] = None, end_date: Optional[datetime] = None,
    search_query: Optional[str] = None, is_archived: bool = False, origen_venta: Optional[str] = None,
    sort_by: str = "fecha_venta", order: str = "desc", 
    db: Session = Depends(deps.get_db), 
    current_user: User = Depends(deps.get_current_user),
    negocio_id: int = Depends(deps.get_current_business_id) # 🔥 INYECTADO
):
    return sales_service.get_sales_history_filtered(
        db=db, user_id=current_user.id, skip=skip, limit=limit, start_date=start_date, end_date=end_date, 
        search_query=search_query, is_archived=is_archived, origen_venta=origen_venta, sort_by=sort_by, order=order, 
        negocio_id=negocio_id
    )

@router.get("/stats", response_model=SalesStatsResponse)
def get_sales_stats(
    start_date: Optional[datetime] = None, end_date: Optional[datetime] = None, is_archived: bool = False,
    origen_venta: Optional[str] = None, 
    db: Session = Depends(deps.get_db), 
    current_user: User = Depends(deps.get_current_user),
    negocio_id: int = Depends(deps.get_current_business_id) # 🔥 INYECTADO
):
    return sales_service.get_sales_stats(
        db=db, user_id=current_user.id, start_date=start_date, end_date=end_date,
        is_archived=is_archived, origen_venta=origen_venta, negocio_id=negocio_id
    )

@router.get("/{sale_id}/detail", response_model=VentaDetailResponse)
def get_sale_detail(
    sale_id: int, 
    db: Session = Depends(deps.get_db), 
    current_user: User = Depends(deps.get_current_user),
    negocio_id: int = Depends(deps.get_current_business_id) # 🔥 INYECTADO
):
    return sales_service.get_sale_detail(db=db, sale_id=sale_id, user_id=current_user.id, negocio_id=negocio_id)

@router.patch("/{sale_id}/archive")
def archive_sale(
    sale_id: int, 
    db: Session = Depends(deps.get_db), 
    current_user: User = Depends(deps.get_current_user),
    negocio_id: int = Depends(deps.get_current_business_id) # 🔥 INYECTADO
):
    new_status = sales_service.toggle_archive_sale(db=db, sale_id=sale_id, user_id=current_user.id, negocio_id=negocio_id)
    return {"message": "Venta archivada" if new_status else "Venta restaurada", "is_archived": new_status}

@router.patch("/{sale_id}/delivery")
def update_delivery_status(
    sale_id: int, 
    status_in: DeliveryStatusUpdate, 
    db: Session = Depends(deps.get_db), 
    current_user: User = Depends(deps.get_current_user),
    negocio_id: int = Depends(deps.get_current_business_id) # 🔥 INYECTADO
):
    updated_sale = sales_service.update_delivery_status(
        db=db, sale_id=sale_id, new_status=status_in.estado_entrega, user_id=current_user.id, negocio_id=negocio_id
    )
    return {"message": "Estado actualizado", "estado_entrega": updated_sale.estado_entrega}