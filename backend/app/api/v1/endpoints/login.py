from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from datetime import timedelta

from app.db.session import SessionLocal
from app.core import security
from app.models.user import User
from app.schemas.token import Token

router = APIRouter()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@router.post("/access-token", response_model=Token)
def login_access_token(
    db: Session = Depends(get_db), 
    form_data: OAuth2PasswordRequestForm = Depends()
):
    """
    OAuth2 compatible token login, get an access token for future requests.
    """
    # 1. Buscar usuario
    user = db.query(User).filter(User.email == form_data.username).first()
    
    # --- 🔥 NUEVA LÓGICA DE MANEJO DE ERRORES SEPARADOS ---
    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")
        
    if not security.verify_password(form_data.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Contraseña incorrecta")
    
    if not user.activo:
        raise HTTPException(status_code=403, detail="Usuario inactivo")

    # 3. Generar Token
    access_token_expires = timedelta(minutes=60 * 24 * 7) # 7 días
    return {
        "access_token": security.create_access_token(
            subject=user.id, expires_delta=access_token_expires
        ),
        "token_type": "bearer",
    }