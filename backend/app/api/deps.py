from typing import Generator, Dict, Any, Optional
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import jwt, JWTError
from sqlalchemy.orm import Session

from app.core.config import settings
from app.db.session import SessionLocal
from app.models.user import User
from app.models.business import Business
from app.models.negocio_usuario import NegocioUsuario, EstadoAcceso

oauth2_scheme = OAuth2PasswordBearer(tokenUrl=f"{settings.API_V1_STR}/login/access-token")

def get_db() -> Generator:
    try:
        db = SessionLocal()
        yield db
    finally:
        db.close()

# 1. VALIDADOR BASE: ¿Quién eres? (Solo lee la identidad general)
async def get_current_user(
    db: Session = Depends(get_db), token: str = Depends(oauth2_scheme)
) -> User:
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="No se pudo validar las credenciales",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        sub_data: str = payload.get("sub") 
        if sub_data is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    user = None
    try:
        user_id = int(sub_data)
        user = db.query(User).filter(User.id == user_id).first()
    except ValueError:
        user = db.query(User).filter(User.email == sub_data).first()

    if user is None or not user.activo:
        raise credentials_exception

    return user

# 2. 🔥 FASE 2 y 6: LECTOR DEL CONTEXTO JWT CON VALIDACIÓN EN TIEMPO REAL
async def get_token_payload(token: str = Depends(oauth2_scheme)) -> dict:
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        return payload
    except JWTError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token inválido o expirado.")

async def get_current_business_id(
    payload: dict = Depends(get_token_payload),
    db: Session = Depends(get_db) # 🔥 Inyectamos la BD para validación en tiempo real
) -> int:
    negocio_id = payload.get("negocio_id")
    user_id = payload.get("sub")
    
    if not negocio_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN, 
            detail="BUSINESS_CONTEXT_REQUIRED" # Código exacto para que Flutter regrese al 'Lobby'
        )
        
    # 🔥 FASE 6: PROTECCIÓN CONTRA TRABAJADORES SUSPENDIDOS
    # Consultamos rápidamente si el usuario sigue teniendo acceso activo al negocio
    if user_id:
        vinculo = db.query(NegocioUsuario).filter(
            NegocioUsuario.usuario_id == int(user_id),
            NegocioUsuario.negocio_id == negocio_id
        ).first()
        
        if not vinculo or str(vinculo.estado_acceso).lower() != "activo":
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Tu acceso a este negocio ha sido suspendido o revocado por el administrador."
            )

    return negocio_id

async def get_current_role_in_business(payload: dict = Depends(get_token_payload)) -> str:
    role = payload.get("rol_en_negocio")
    if not role: raise HTTPException(status_code=403, detail="No role found in context.")
    return role

async def get_current_permissions(payload: dict = Depends(get_token_payload)) -> Dict[str, Any]:
    return payload.get("permisos", {})