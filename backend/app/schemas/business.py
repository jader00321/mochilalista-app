from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class BusinessBase(BaseModel):
    nombre_comercial: str
    ruc: Optional[str] = None
    direccion: Optional[str] = None # Se usará como dirección manual o referencia
    logo_url: Optional[str] = None
    configuracion_impresora: Optional[str] = None
    informacion_pago: Optional[str] = None
    latitud: Optional[float] = None   # <--- NUEVO
    longitud: Optional[float] = None  # <--- NUEVO

class BusinessCreate(BusinessBase):
    pass

class BusinessUpdate(BaseModel):
    nombre_comercial: Optional[str] = None
    ruc: Optional[str] = None
    direccion: Optional[str] = None
    logo_url: Optional[str] = None 
    configuracion_impresora: Optional[str] = None
    informacion_pago: Optional[str] = None
    latitud: Optional[float] = None   # <--- NUEVO
    longitud: Optional[float] = None  # <--- NUEVO

class BusinessResponse(BusinessBase):
    id: int
    id_dueno: int
    fecha_creacion: datetime

    class Config:
        from_attributes = True