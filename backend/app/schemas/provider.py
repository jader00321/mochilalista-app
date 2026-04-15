from typing import Optional
from datetime import datetime
from pydantic import BaseModel

class ProviderBase(BaseModel):
    nombre_empresa: str
    ruc: Optional[str] = None
    contacto_nombre: Optional[str] = None
    telefono: Optional[str] = None
    email: Optional[str] = None
    activo: bool = True

class ProviderCreate(ProviderBase):
    pass

class ProviderUpdate(BaseModel):
    nombre_empresa: Optional[str] = None
    ruc: Optional[str] = None
    contacto_nombre: Optional[str] = None
    telefono: Optional[str] = None
    email: Optional[str] = None
    activo: Optional[bool] = None

class ProviderResponse(ProviderBase):
    id: int
    negocio_id: int
    fecha_creacion: Optional[datetime] = None
    products_count: int = 0 # <--- NUEVO CAMPO

    class Config:
        from_attributes = True