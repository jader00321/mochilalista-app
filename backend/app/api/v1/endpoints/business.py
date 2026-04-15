from typing import Any
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.orm import Session

from app.api import deps
from app.models.user import User
from app.models.business import Business
from app.models.negocio_usuario import NegocioUsuario 
from app.schemas.business import BusinessResponse, BusinessUpdate
from app.services.cloudinary_service import upload_image_to_cloudinary

router = APIRouter()

@router.get("/current", response_model=BusinessResponse)
def get_current_business(
    db: Session = Depends(deps.get_db),
    negocio_id: int = Depends(deps.get_current_business_id)
) -> Any:
    negocio = db.query(Business).filter(Business.id == negocio_id).first()
    if not negocio:
        raise HTTPException(status_code=404, detail="Negocio no encontrado en el contexto actual.")
    return negocio

# 🔥 CREAR UN NEGOCIO NUEVO
@router.post("/", response_model=BusinessResponse)
def create_business(
    business_in: BusinessUpdate,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    # 1. Crea el negocio SIEMPRE (nunca sobreescribe)
    negocio = Business(**business_in.model_dump(exclude_unset=True), id_dueno=current_user.id)
    db.add(negocio)
    db.flush() 
    
    # 2. Crea la relación obligatoria en el puente
    vinculo = NegocioUsuario(
        usuario_id=current_user.id,
        negocio_id=negocio.id,
        rol_en_negocio="dueno",
        permisos={"is_owner": True},
        estado_acceso="activo"
    )
    db.add(vinculo)
    db.commit()
    db.refresh(negocio)
    return negocio

# 🔥 ACTUALIZAR EL NEGOCIO ACTUAL
@router.put("/current", response_model=BusinessResponse)
def update_current_business(
    business_in: BusinessUpdate,
    db: Session = Depends(deps.get_db),
    negocio_id: int = Depends(deps.get_current_business_id), # Asegura que edita en el que está parado
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    # Verifica que el usuario sea el dueño original del negocio en el que está parado
    negocio = db.query(Business).filter(Business.id == negocio_id, Business.id_dueno == current_user.id).first()
    
    if not negocio:
        raise HTTPException(status_code=403, detail="No autorizado para editar este negocio.")
        
    update_data = business_in.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(negocio, field, value)
    
    db.commit()
    db.refresh(negocio)
    return negocio

@router.post("/upload-logo", response_model=BusinessResponse)
async def upload_business_logo(
    file: UploadFile = File(...),
    db: Session = Depends(deps.get_db),
    negocio_id: int = Depends(deps.get_current_business_id),
    current_user: User = Depends(deps.get_current_user),
) -> Any:
    negocio = db.query(Business).filter(Business.id == negocio_id, Business.id_dueno == current_user.id).first()
    if not negocio:
        raise HTTPException(status_code=403, detail="No autorizado para subir logo a este negocio.")

    if file.content_type not in ["image/jpeg", "image/png", "image/jpg", "image/webp"]:
        raise HTTPException(status_code=400, detail="Solo se permiten imágenes (JPEG, PNG, WEBP)")

    try:
        contents = await file.read()
        logo_url_cloud = upload_image_to_cloudinary(contents, folder="mochila_lista/logos")
        negocio.logo_url = logo_url_cloud
        db.commit()
        db.refresh(negocio)
        return negocio

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error al procesar el logo: {str(e)}")