from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List, Any
import uuid
from datetime import datetime, timedelta

from app.api import deps
from app.models.user import User
from app.models.business import Business
from app.models.negocio_usuario import NegocioUsuario, RolNegocio, EstadoAcceso
from app.models.codigo_acceso import CodigoAccesoNegocio
from app.schemas.codigo_acceso import CodigoAccesoCreate, CodigoAccesoResponse
from app.schemas.negocio_usuario import NegocioUsuarioUpdate

router = APIRouter()

# 🔥 Permisos por Defecto
PERMISOS_TRABAJADOR_DEFAULT = {
    "can_sell": True, "can_view_inventory": True, "can_manage_clients": True,
    "can_edit_inventory": False, "can_view_reports": False, "is_admin": False
}

# ==============================================================================
# GESTIÓN DE CÓDIGOS DE INVITACIÓN
# ==============================================================================

@router.post("/{business_id}/access-codes", response_model=CodigoAccesoResponse)
def generate_access_code(
    business_id: int,
    codigo_in: CodigoAccesoCreate,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    business = db.query(Business).filter(Business.id == business_id, Business.id_dueno == current_user.id).first()
    if not business:
        raise HTTPException(status_code=403, detail="Solo el dueño puede generar códigos.")

    prefijo = "WORK" if codigo_in.rol_a_otorgar == RolNegocio.TRABAJADOR.value else "VIP"
    codigo_str = f"ML-{prefijo}-{str(uuid.uuid4().hex)[:6].upper()}"

    nuevo_codigo = CodigoAccesoNegocio(
        codigo=codigo_str,
        negocio_id=business_id,
        creado_por_usuario_id=current_user.id,
        rol_a_otorgar=codigo_in.rol_a_otorgar,
        usos_maximos=codigo_in.usos_maximos,
        fecha_expiracion=codigo_in.fecha_expiracion
    )
    db.add(nuevo_codigo)
    db.commit()
    db.refresh(nuevo_codigo)
    return nuevo_codigo

@router.get("/{business_id}/access-codes", response_model=List[CodigoAccesoResponse])
def get_access_codes(
    business_id: int,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    business = db.query(Business).filter(Business.id == business_id, Business.id_dueno == current_user.id).first()
    if not business:
        raise HTTPException(status_code=403, detail="Solo el dueño puede ver los códigos.")

    codigos = db.query(CodigoAccesoNegocio).filter(
        CodigoAccesoNegocio.negocio_id == business_id
    ).order_by(CodigoAccesoNegocio.fecha_creacion.desc()).all()
    
    return codigos

@router.delete("/{business_id}/access-codes/{code_id}")
def delete_access_code(
    business_id: int,
    code_id: int,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    business = db.query(Business).filter(Business.id == business_id, Business.id_dueno == current_user.id).first()
    if not business:
        raise HTTPException(status_code=403, detail="Solo el dueño puede eliminar códigos.")

    codigo = db.query(CodigoAccesoNegocio).filter(
        CodigoAccesoNegocio.id == code_id,
        CodigoAccesoNegocio.negocio_id == business_id
    ).first()
    
    if not codigo:
        raise HTTPException(status_code=404, detail="Código no encontrado.")
        
    db.delete(codigo)
    db.commit()
    return {"message": "Código eliminado exitosamente."}

# ==============================================================================
# GESTIÓN DE EQUIPO Y RADAR
# ==============================================================================

@router.post("/{business_id}/add-user-directly")
def add_user_directly(
    business_id: int,
    codigo_usuario: str,
    rol_asignar: str,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    business = db.query(Business).filter(Business.id == business_id, Business.id_dueno == current_user.id).first()
    if not business: raise HTTPException(status_code=403, detail="No autorizado.")

    target_user = db.query(User).filter(User.codigo_unico_usuario == codigo_usuario).first()
    if not target_user: raise HTTPException(status_code=404, detail="Usuario no encontrado en el Radar.")

    existente = db.query(NegocioUsuario).filter(NegocioUsuario.usuario_id == target_user.id, NegocioUsuario.negocio_id == business_id).first()
    if existente: raise HTTPException(status_code=400, detail="El usuario ya pertenece a tu negocio.")

    # 🔥 ASIGNACIÓN AUTOMÁTICA DE PERMISOS
    permisos_auto = PERMISOS_TRABAJADOR_DEFAULT if rol_asignar == "trabajador" else {}

    nuevo_miembro = NegocioUsuario(
        usuario_id=target_user.id,
        negocio_id=business_id,
        rol_en_negocio=rol_asignar,
        permisos=permisos_auto, 
        estado_acceso="activo"
    )
    db.add(nuevo_miembro)
    db.commit()
    return {"message": "Usuario añadido exitosamente al equipo."}

@router.get("/{business_id}/team")
def get_business_team(
    business_id: int,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    business = db.query(Business).filter(Business.id == business_id, Business.id_dueno == current_user.id).first()
    if not business: raise HTTPException(status_code=403, detail="No autorizado.")

    equipo = db.query(NegocioUsuario).filter(NegocioUsuario.negocio_id == business_id).all()
    
    resultado = []
    for miembro in equipo:
        resultado.append({
            "usuario_id": miembro.usuario_id,
            "nombre": miembro.usuario.nombre_completo,
            "rol": miembro.rol_en_negocio,
            "estado": miembro.estado_acceso,
            "permisos": miembro.permisos or {}
        })
    return resultado

@router.put("/{business_id}/team/{user_id}")
def update_team_member(
    business_id: int,
    user_id: int,
    update_data: NegocioUsuarioUpdate,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user)
) -> Any:
    business = db.query(Business).filter(Business.id == business_id, Business.id_dueno == current_user.id).first()
    if not business: raise HTTPException(status_code=403, detail="No autorizado.")

    miembro = db.query(NegocioUsuario).filter(NegocioUsuario.negocio_id == business_id, NegocioUsuario.usuario_id == user_id).first()
    if not miembro: raise HTTPException(status_code=404, detail="Miembro no encontrado.")

    if update_data.estado_acceso: miembro.estado_acceso = update_data.estado_acceso
    if update_data.permisos is not None: miembro.permisos = update_data.permisos
    if update_data.rol_en_negocio: miembro.rol_en_negocio = update_data.rol_en_negocio

    db.commit()
    return {"message": "Miembro actualizado correctamente."}