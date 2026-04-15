import os
from fastapi import APIRouter, UploadFile, File, HTTPException, status, Depends
from PIL import Image
import io

# Importamos las dependencias de seguridad
from app.api import deps
from app.models.user import User

# Importamos el servicio actualizado
from app.services.ai_school_list_service import ai_school_list_service
from app.schemas.school_list import SchoolListAnalysisResponse

router = APIRouter()

@router.post("/analyze", response_model=SchoolListAnalysisResponse)
async def analyze_school_list(
    file: UploadFile = File(...),
    current_user: User = Depends(deps.get_current_user) # <--- SEGURIDAD APLICADA AQUÍ
):
    """
    Recibe una imagen de lista de útiles,
    la procesa con Google Gemini y devuelve JSON estructurado.
    Solo usuarios autenticados pueden acceder a este endpoint.
    """
    
    # 1. Leer archivo en memoria (Sin validar content-type estricto para evitar error 400)
    try:
        contents = await file.read()
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No se pudo leer el archivo subido."
        )

    # 2. Validar que sea una imagen real usando Pillow
    try:
        image = Image.open(io.BytesIO(contents))
        image.verify() # Verifica integridad sin cargarla toda
        image = Image.open(io.BytesIO(contents)) # Reabrir para procesar
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, 
            detail="El archivo no es una imagen válida o está corrupto."
        )

    # 3. Procesar con el Servicio IA
    try:
        # Pasamos el objeto Image de PIL directamente
        result = await ai_school_list_service.analyze_image(image)
        return result

    except Exception as e:
        print(f"❌ Error en endpoint school-lists: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(e)
        )