from fastapi import APIRouter, UploadFile, File, HTTPException, Depends
from pydantic import BaseModel
from app.api import deps
from app.services.cloudinary_service import upload_image_to_cloudinary

router = APIRouter()

class ImageUploadResponse(BaseModel):
    url: str
    message: str

@router.post("/", response_model=ImageUploadResponse)
async def upload_image(
    file: UploadFile = File(...),
    folder: str = "mochila_lista/productos", # Carpeta por defecto
    current_user = Depends(deps.get_current_user) # Solo usuarios logueados pueden subir
):
    """
    Recibe una imagen, la sube a Cloudinary y devuelve la URL.
    """
    # 1. Validar tipo de archivo
    if file.content_type not in ["image/jpeg", "image/png", "image/jpg", "image/webp"]:
        raise HTTPException(status_code=400, detail="Solo se permiten imágenes (JPEG, PNG, WEBP)")

    try:
        # 2. Leer archivo en memoria
        contents = await file.read()
        
        # 3. Llamar al servicio
        url = upload_image_to_cloudinary(contents, folder=folder)
        
        return ImageUploadResponse(
            url=url,
            message="Imagen subida correctamente"
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error al subir imagen: {str(e)}")