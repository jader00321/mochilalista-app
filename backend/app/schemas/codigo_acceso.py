from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class CodigoAccesoBase(BaseModel):
    rol_a_otorgar: str
    usos_maximos: int = 1
    fecha_expiracion: Optional[datetime] = None

class CodigoAccesoCreate(CodigoAccesoBase):
    pass

class CodigoAccesoResponse(CodigoAccesoBase):
    id: int
    codigo: str
    negocio_id: int
    creado_por_usuario_id: int
    usos_actuales: int
    fecha_creacion: datetime

    class Config:
        from_attributes = True