import os
import asyncio
import random # 🔥 NUEVO: Importado para el Jitter
from PIL import Image
from google import genai
from google.genai import types
from pydantic import ValidationError

from app.schemas.school_list import SchoolListAnalysisResponse

class AIListService:
    def __init__(self):
        self.api_key = os.getenv("GOOGLE_API_KEY")
        if not self.api_key:
            print("⚠️ ADVERTENCIA: GOOGLE_API_KEY no encontrada.")

    async def analyze_image(self, image: Image.Image) -> SchoolListAnalysisResponse:
        """
        Analiza una imagen de lista escolar usando Gemini con sistema de reintentos (Retries)
        y un Prompt Maestro detallado para máxima precisión.
        """
        if not self.api_key:
            raise ValueError("API Key de Google no configurada en el servidor.")

        # 🔥 CONFIGURACIÓN DE REINTENTOS EXPONENCIALES
        max_retries = 5 # Aumentado para mayor tolerancia a fallos
        attempt = 0
        last_error = None

        while attempt < max_retries:
            try:
                client = genai.Client(api_key=self.api_key)

                # Prompt Maestro
                prompt = """
                Actúa como un experto en digitalización de listas de útiles escolares.
                Analiza la imagen proporcionada y extrae la información siguiendo ESTRICTAMENTE el esquema JSON solicitado.

                INSTRUCCIONES DE EXTRACCIÓN DETALLADA:
                
                1. METADATA (Encabezado):
                   - Busca nombre del colegio, nombre del alumno y grado/sección.
                   
                2. ÍTEMS (Lista de Productos):
                   Recorre línea por línea y para cada producto extrae:
                   
                   - "id": Genera un número secuencial (1, 2, 3...).
                   - "original_text": Transcribe el texto exacto que ves en la línea para referencia.
                   
                   - "full_name": El nombre completo y DESCRIPTIVO del producto. 
                     * Corrige ortografía (ej: "Cdorno" -> "Cuaderno").
                     * Si la marca está integrada (ej: "Colores Faber"), extráela al campo marca y deja aquí solo "Colores".
                     * Sé específico: "Cuaderno A4 cuadriculado" es mejor que solo "Cuaderno".
                     
                   - "brand": Si se especifica una marca explícita (ej: Faber-Castell, Artesco, Stanford), ponla aquí. Si no, null.
                   
                   - "quantity": Extrae el número. Conviértelo a entero (ej: "un ciento" -> 100, "docena" -> 12). Si no hay, asume 1.
                   
                   - "unit": Expande abreviaturas:
                     * "c/u" -> "unidad"
                     * "pqte" -> "paquete"
                     * "jgo" -> "juego"
                     * "mill" -> "millar"
                     * "caja" -> "caja"
                   
                   - "notes": Detalles visuales, colores o instrucciones adicionales.
                     Ejemplo: "forrado de rojo", "punta gruesa", "tamaño oficio", "con stickers".

                REGLAS CRÍTICAS DE CALIDAD:
                - NO inventes productos que no estén visibles en la imagen.
                - Si una línea está tachada, IGNÓRALA.
                - Si hay dudas sobre un texto borroso, usa el contexto para inferir el producto escolar más probable.
                """

                response = await client.aio.models.generate_content(
                    model='gemini-3-flash-preview', 
                    contents=[prompt, image],
                    config=types.GenerateContentConfig(
                        response_mime_type='application/json',
                        response_schema=SchoolListAnalysisResponse
                    )
                )

                if response.parsed:
                    return response.parsed
                else:
                    raise ValueError("La IA devolvió una respuesta vacía o no parseable.")

            except ValidationError as e:
                print(f"⚠️ Intento {attempt + 1}: Error de validación JSON en la lista escolar.")
                last_error = f"Error de formato de datos: {e}"
                
            except Exception as e:
                error_msg = str(e)
                print(f"⚠️ Intento {attempt + 1}: Error de API ({error_msg}).")
                last_error = error_msg

            attempt += 1
            if attempt < max_retries:
                # 🔥 Retroceso exponencial con Jitter
                wait_time = (2 ** (attempt - 1)) + random.uniform(0.5, 1.5)
                print(f"⏳ Esperando {wait_time:.2f}s antes de reintentar análisis de lista...")
                await asyncio.sleep(wait_time) 

        print(f"❌ Error Crítico AI Service después de {max_retries} intentos: {last_error}")
        raise ValueError(f"No se pudo procesar la imagen debido a la alta demanda del servidor. Por favor, intenta de nuevo en un momento.")

# Instancia global
ai_school_list_service = AIListService()