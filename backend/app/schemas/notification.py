from pydantic import BaseModel
from datetime import datetime
from typing import Optional

class NotificationBase(BaseModel):
    titulo: str
    mensaje: str
    tipo: Optional[str] = "info"
    
    # --- CAMPOS DE DEEP LINKING ---
    prioridad: str = "Media" 
    objeto_relacionado_tipo: Optional[str] = None # Ej: "venta", "factura"
    objeto_relacionado_id: Optional[int] = None

class NotificationCreate(NotificationBase):
    user_id: int
    negocio_id: int # 🔥 REQUERIDO

class NotificationResponse(NotificationBase):
    id: int
    user_id: int
    negocio_id: int # 🔥 EXPUESTO
    leida: bool
    fecha_creacion: datetime

    class Config:
        from_attributes = True