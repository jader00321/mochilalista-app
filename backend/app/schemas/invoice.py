from pydantic import BaseModel
from typing import Optional, Any
from datetime import datetime, date

class InvoiceBase(BaseModel):
    imagen_url: str
    estado: str = 'procesando' # procesando, revision, completado
    proveedor_id: Optional[int] = None
    monto_total_factura: Optional[float] = None
    fecha_emision: Optional[date] = None
    cantidad_items_extraidos: Optional[int] = None
    datos_crudos_ia_json: Optional[Any] = None

class InvoiceCreate(InvoiceBase):
    pass

# 🔥 ACTUALIZACIÓN SOLICITADA POR TI
class InvoiceUpdate(BaseModel):
    imagen_url: Optional[str] = None
    estado: Optional[str] = None
    proveedor_id: Optional[int] = None

class InvoiceResponse(InvoiceBase):
    id: int
    negocio_id: int
    fecha_carga: datetime

    class Config:
        from_attributes = True