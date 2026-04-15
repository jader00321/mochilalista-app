from pydantic import BaseModel
from typing import Optional, Dict, Any

class NegocioUsuarioBase(BaseModel):
    rol_en_negocio: str
    permisos: Optional[Dict[str, Any]] = None
    estado_acceso: str = "activo"

class NegocioUsuarioCreate(NegocioUsuarioBase):
    usuario_id: int
    negocio_id: int

class NegocioUsuarioUpdate(BaseModel):
    rol_en_negocio: Optional[str] = None
    permisos: Optional[Dict[str, Any]] = None
    estado_acceso: Optional[str] = None

class NegocioUsuarioResponse(NegocioUsuarioBase):
    id: int
    usuario_id: int
    negocio_id: int

    class Config:
        from_attributes = True