from pydantic import BaseModel
from typing import Optional, Dict, Any

class Token(BaseModel):
    access_token: str
    token_type: str

class TokenPayload(BaseModel):
    sub: Optional[str] = None
    negocio_id: Optional[int] = None # 🔥 FASE 1: Token Contextual
    rol_en_negocio: Optional[str] = None
    permisos: Optional[Dict[str, Any]] = None