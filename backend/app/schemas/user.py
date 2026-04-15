from pydantic import BaseModel, EmailStr
from typing import Optional
from app.schemas.business import BusinessResponse 

class UserBase(BaseModel):
    email: EmailStr
    nombre_completo: Optional[str] = None
    telefono: Optional[str] = None

class UserCreate(UserBase):
    password: str
    nombre_negocio: Optional[str] = None 

class UserUpdate(BaseModel):
    nombre_completo: Optional[str] = None
    telefono: Optional[str] = None

class UserChangePassword(BaseModel):
    current_password: str
    new_password: str

class UserResponse(UserBase):
    id: int
    codigo_unico_usuario: Optional[str] = None # 🔥 FASE 1
    activo: bool
    # Se elimina 'rol' porque ahora depende del contexto del negocio
    negocio_data: Optional[BusinessResponse] = None 

    class Config:
        from_attributes = True

# --- NUEVO: Schema para el "Lobby" (Selector de Negocios en Flutter) ---
class WorkspaceResponse(BaseModel):
    negocio_id: int
    nombre_negocio: str
    rol: str
    logo_url: Optional[str] = None
    estado_acceso: str = "activo"