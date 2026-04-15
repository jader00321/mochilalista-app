from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import Any
from datetime import timedelta

from app.api import deps
from app.core import security
from app.models.user import User
from app.models.business import Business
from app.models.negocio_usuario import NegocioUsuario, EstadoAcceso
from app.schemas.token import Token

router = APIRouter()

@router.post("/switch-context/{negocio_id}", response_model=Token)
def switch_business_context(
    negocio_id: int,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    """
    Recibe el ID del negocio al que el usuario quiere entrar.
    Verifica si tiene permisos y devuelve un NUEVO TOKEN con los poderes inyectados.
    """
    rol_asignado = None
    permisos_asignados = {}

    # 1. ¿Es el dueño original?
    negocio_propio = db.query(Business).filter(Business.id == negocio_id, Business.id_dueno == current_user.id).first()
    
    if negocio_propio:
        rol_asignado = "dueno"
        permisos_asignados = {"is_owner": True} # Poder absoluto
    else:
        # 2. ¿Es un trabajador o cliente invitado?
        vinculo = db.query(NegocioUsuario).filter(
            NegocioUsuario.usuario_id == current_user.id, 
            NegocioUsuario.negocio_id == negocio_id
        ).first()
        
        if not vinculo:
            raise HTTPException(status_code=403, detail="No perteneces a este negocio.")
        
        # 🔥 ROBUSTEZ APLICADA: Aseguramos que compare strings en minúsculas por seguridad.
        if vinculo.estado_acceso and str(vinculo.estado_acceso).lower() == str(EstadoAcceso.SUSPENDIDO.value).lower():
            raise HTTPException(status_code=403, detail="Tu acceso a este negocio está suspendido por el administrador.")
            
        rol_asignado = vinculo.rol_en_negocio
        permisos_asignados = vinculo.permisos or {}

    # 3. Generar el nuevo Token Contextual
    access_token_expires = timedelta(minutes=60 * 24 * 7) # 7 días
    
    # Inyectamos el contexto en el payload del JWT
    custom_payload = {
        "sub": str(current_user.id),
        "negocio_id": negocio_id,
        "rol_en_negocio": rol_asignado,
        "permisos": permisos_asignados
    }

    token_string = security.create_access_token_custom_payload(
        payload=custom_payload, expires_delta=access_token_expires
    )

    return {
        "access_token": token_string,
        "token_type": "bearer",
    }