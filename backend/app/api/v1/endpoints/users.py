from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import Any, List
import random
import string

from app.api import deps 
from app.models.user import User
from app.models.business import Business
from app.models.codigo_acceso import CodigoAccesoNegocio
from app.models.negocio_usuario import NegocioUsuario
from app.models.cliente import Cliente
from app.core.security import get_password_hash, verify_password 
from app.schemas.user import UserCreate, UserResponse, UserUpdate, UserChangePassword, WorkspaceResponse

router = APIRouter()

# 🔥 Definición de Permisos Estándar
PERMISOS_TRABAJADOR_DEFAULT = {
    "can_sell": True,
    "can_view_inventory": True,
    "can_manage_clients": True,
    "can_edit_inventory": False,
    "can_view_reports": False,
    "is_admin": False
}

PERMISOS_CLIENTE_COMUNIDAD = {
    "can_create_quotes": True,
    "view_my_purchases": True,
    "is_community_member": True
}

def generar_codigo_unico_usuario(db: Session) -> str:
    while True:
        random_chars = ''.join(random.choices(string.ascii_uppercase + string.digits, k=6))
        codigo = f"ML-{random_chars}"
        if not db.query(User).filter(User.codigo_unico_usuario == codigo).first():
            return codigo

@router.post("/register", response_model=UserResponse)
def create_user(user_in: UserCreate, db: Session = Depends(deps.get_db)) -> Any:
    user = db.query(User).filter(User.email == user_in.email).first()
    if user:
        raise HTTPException(status_code=400, detail="El email ya está registrado.")
    
    user = User(
        codigo_unico_usuario=generar_codigo_unico_usuario(db),
        email=user_in.email,
        password_hash=get_password_hash(user_in.password),
        nombre_completo=user_in.nombre_completo,
        telefono=user_in.telefono
    )
    db.add(user)
    db.flush() 

    if user_in.nombre_negocio:
        negocio_creado = Business(
            nombre_comercial=user_in.nombre_negocio, 
            id_dueno=user.id, 
            ruc="Sin RUC", 
            direccion="Sin dirección"
        )
        db.add(negocio_creado)
        db.flush() 

        vinculo = NegocioUsuario(
            usuario_id=user.id,
            negocio_id=negocio_creado.id,
            rol_en_negocio="dueno",
            permisos={"is_owner": True},
            estado_acceso="activo"
        )
        db.add(vinculo)

    db.commit()
    db.refresh(user)
    return user

@router.post("/join-business")
def join_business(codigo_invitacion: str, db: Session = Depends(deps.get_db), current_user: User = Depends(deps.get_current_user)) -> Any:
    codigo_db = db.query(CodigoAccesoNegocio).filter(CodigoAccesoNegocio.codigo == codigo_invitacion).first()
    if not codigo_db: raise HTTPException(status_code=404, detail="Código inválido.")
    
    if codigo_db.usos_actuales >= codigo_db.usos_maximos:
        raise HTTPException(status_code=400, detail="Este código ya ha sido usado su número máximo de veces.")

    existente = db.query(NegocioUsuario).filter(NegocioUsuario.usuario_id == current_user.id, NegocioUsuario.negocio_id == codigo_db.negocio_id).first()
    if existente: raise HTTPException(status_code=400, detail="Ya perteneces a este negocio.")

    permisos_asignar = PERMISOS_TRABAJADOR_DEFAULT if codigo_db.rol_a_otorgar == "trabajador" else PERMISOS_CLIENTE_COMUNIDAD

    nuevo_vinculo = NegocioUsuario(
        usuario_id=current_user.id,
        negocio_id=codigo_db.negocio_id,
        rol_en_negocio=codigo_db.rol_a_otorgar,
        permisos=permisos_asignar,
        estado_acceso="activo"
    )
    db.add(nuevo_vinculo)

    # 🔥 MAGIA: CREACIÓN GARANTIZADA DEL PERFIL CRM PARA EL DUEÑO
    if codigo_db.rol_a_otorgar == "cliente_comunidad":
        cliente_crm = db.query(Cliente).filter(
            Cliente.usuario_vinculado_id == current_user.id, 
            Cliente.negocio_id == codigo_db.negocio_id
        ).first()
        
        if not cliente_crm:
            # Identificamos quién es el responsable de esta creación
            negocio = db.query(Business).filter(Business.id == codigo_db.negocio_id).first()
            creador_id = codigo_db.creado_por_usuario_id or negocio.id_dueno

            nuevo_cliente_crm = Cliente(
                negocio_id=codigo_db.negocio_id, 
                creado_por_usuario_id=creador_id,
                usuario_vinculado_id=current_user.id, 
                nombre_completo=current_user.nombre_completo or f"Cliente VIP {current_user.codigo_unico_usuario}", 
                telefono=current_user.telefono or "Sin teléfono registrado",
                nivel_confianza="bueno"
            )
            db.add(nuevo_cliente_crm)

    codigo_db.usos_actuales += 1
    db.commit()
    return {"message": f"Te has unido exitosamente como {codigo_db.rol_a_otorgar}"}

@router.get("/me", response_model=UserResponse)
def read_user_me(current_user: User = Depends(deps.get_current_user)) -> Any:
    return current_user

@router.put("/me", response_model=UserResponse)
def update_user_me(user_in: UserUpdate, db: Session = Depends(deps.get_db), current_user: User = Depends(deps.get_current_user)) -> Any:
    if user_in.nombre_completo: current_user.nombre_completo = user_in.nombre_completo
    if user_in.telefono: current_user.telefono = user_in.telefono
    db.commit()
    db.refresh(current_user)
    return current_user

@router.post("/change-password")
def change_password(pass_in: UserChangePassword, db: Session = Depends(deps.get_db), current_user: User = Depends(deps.get_current_user)) -> Any:
    if not verify_password(pass_in.current_password, current_user.password_hash):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="La contraseña actual es incorrecta.")
    current_user.password_hash = get_password_hash(pass_in.new_password)
    db.commit()
    return {"message": "Contraseña actualizada correctamente"}

@router.get("/me/workspaces", response_model=List[WorkspaceResponse])
def get_my_workspaces(db: Session = Depends(deps.get_db), current_user: User = Depends(deps.get_current_user)) -> Any:
    negocios_huerfanos = db.query(Business).filter(Business.id_dueno == current_user.id).all()
    for neg in negocios_huerfanos:
        existe_puente = db.query(NegocioUsuario).filter(NegocioUsuario.usuario_id == current_user.id, NegocioUsuario.negocio_id == neg.id).first()
        if not existe_puente:
            nuevo_vinculo = NegocioUsuario(
                usuario_id=current_user.id,
                negocio_id=neg.id,
                rol_en_negocio="dueno",
                permisos={"is_owner": True},
                estado_acceso="activo"
            )
            db.add(nuevo_vinculo)
    db.commit() 

    workspaces = []
    vinculos = db.query(NegocioUsuario).filter(NegocioUsuario.usuario_id == current_user.id).all()
    
    for vinculo in vinculos:
        if vinculo.negocio:
            workspaces.append({
                "negocio_id": vinculo.negocio_id,
                "nombre_negocio": vinculo.negocio.nombre_comercial,
                "rol": vinculo.rol_en_negocio,
                "logo_url": vinculo.negocio.logo_url,
                "estado_acceso": vinculo.estado_acceso
            })
            
    return workspaces