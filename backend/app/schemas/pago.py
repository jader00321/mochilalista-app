from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class PagoCreate(BaseModel):
    monto: float
    metodo_pago: str
    nota: Optional[str] = None
    venta_id: Optional[int] = None
    cuota_id: Optional[int] = None
    guardar_vuelto: Optional[bool] = False 

class PagoResponse(PagoCreate):
    id: int
    negocio_id: int # 🔥 FASE 1
    creado_por_usuario_id: int # 🔥 FASE 1
    fecha_pago: datetime

    class Config:
        from_attributes = True