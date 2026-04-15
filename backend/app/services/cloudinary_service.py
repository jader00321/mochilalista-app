import cloudinary
import cloudinary.uploader
from app.core.config import settings

# 1. Configuración Global (Se ejecuta al importar)
cloudinary.config( 
  cloud_name = settings.CLOUDINARY_CLOUD_NAME, 
  api_key = settings.CLOUDINARY_API_KEY, 
  api_secret = settings.CLOUDINARY_API_SECRET,
  secure = True
)

def upload_image_to_cloudinary(file_file, folder: str = "mochila_lista/productos") -> str:
    """
    Sube una imagen a Cloudinary y retorna la URL segura (https).
    
    :param file_file: El objeto archivo (bytes o file-like object).
    :param folder: Carpeta en Cloudinary donde se guardará.
    :return: URL pública de la imagen.
    """
    try:
        # Cloudinary sube directo el archivo en memoria (sin guardarlo en disco)
        response = cloudinary.uploader.upload(
            file_file, 
            folder=folder,
            resource_type="image"
        )
        return response.get("secure_url")
    except Exception as e:
        print(f"❌ Error subiendo a Cloudinary: {str(e)}")
        raise e