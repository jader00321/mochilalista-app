from pydantic import BaseModel
from typing import Optional, Dict, Any
from datetime import datetime

# --- Esquemas para el Equipo (Team) ---
class TeamMemberUpdate(BaseModel):
    estado_acceso: str
    permisos: Dict[str, Any]
    rol_en_negocio: str

class TeamMemberResponse(BaseModel):
    usuario_id: int
    nombre: str
    rol: str
    estado: str
    permisos: Dict[str, Any]

    class Config:
        from_attributes = True

# --- Esquemas para los Códigos de Acceso ---
class AccessCodeCreate(BaseModel):
    rol_a_otorgar: str
    usos_maximos: int = 1
    fecha_expiracion: Optional[datetime] = None

class AccessCodeResponse(BaseModel):
    id: int
    codigo: str
    rol_a_otorgar: str
    usos_maximos: int
    usos_actuales: int
    fecha_creacion: datetime
    fecha_expiracion: Optional[datetime] = None

    class Config:
        from_attributes = True