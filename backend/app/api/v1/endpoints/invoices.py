from typing import List, Any
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.api import deps
from app.models.invoice import Invoice
from app.schemas.invoice import InvoiceResponse, InvoiceUpdate

router = APIRouter()

@router.get("/", response_model=List[InvoiceResponse])
def get_invoices(
    skip: int = 0, limit: int = 50,
    db: Session = Depends(deps.get_db),
    negocio_id: int = Depends(deps.get_current_business_id)
) -> Any:
    """Obtiene el historial de facturas cargadas del negocio."""
    return db.query(Invoice).filter(Invoice.negocio_id == negocio_id).order_by(Invoice.fecha_carga.desc()).offset(skip).limit(limit).all()

@router.get("/{invoice_id}", response_model=InvoiceResponse)
def get_invoice_detail(
    invoice_id: int, db: Session = Depends(deps.get_db), negocio_id: int = Depends(deps.get_current_business_id)
) -> Any:
    invoice = db.query(Invoice).filter(Invoice.id == invoice_id, Invoice.negocio_id == negocio_id).first()
    if not invoice: raise HTTPException(status_code=404, detail="Factura no encontrada")
    return invoice

@router.patch("/{invoice_id}", response_model=InvoiceResponse)
def update_invoice(
    invoice_id: int, invoice_in: InvoiceUpdate, db: Session = Depends(deps.get_db), negocio_id: int = Depends(deps.get_current_business_id)
) -> Any:
    """Actualiza imagen, estado o proveedor de una factura."""
    invoice = db.query(Invoice).filter(Invoice.id == invoice_id, Invoice.negocio_id == negocio_id).first()
    if not invoice: raise HTTPException(status_code=404, detail="Factura no encontrada")

    update_data = invoice_in.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(invoice, field, value)

    db.add(invoice)
    db.commit()
    db.refresh(invoice)
    return invoice