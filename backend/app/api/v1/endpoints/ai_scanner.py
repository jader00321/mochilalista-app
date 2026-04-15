import os
import json
import asyncio
import random # 🔥 NUEVO: Importado para el Jitter
from datetime import datetime
from fastapi import APIRouter, UploadFile, File, HTTPException, Depends
from sqlalchemy.orm import Session
from PIL import Image
import io
from pydantic import ValidationError

from google import genai
from google.genai import types

from app.api import deps
from app.models.invoice import Invoice
from app.models.user import User
from app.schemas.scanner import AIInvoiceResponse
from app.services.cloudinary_service import upload_image_to_cloudinary 

router = APIRouter()
API_KEY = os.getenv("GOOGLE_API_KEY")

@router.post("/analyze_invoice", response_model=AIInvoiceResponse)
async def analyze_invoice_with_gemini(
    file: UploadFile = File(...),
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_user),
    negocio_id: int = Depends(deps.get_current_business_id)
):
    if not API_KEY:
        raise HTTPException(status_code=500, detail="Google API Key no configurada.")

    try:
        contents = await file.read()
        image = Image.open(io.BytesIO(contents))
    except Exception:
        raise HTTPException(status_code=400, detail="Archivo de imagen inválido.")

    # 🔥 1. SUBIR IMAGEN Y CREAR FACTURA EN BD (Estado Inicial)
    try:
        img_url = upload_image_to_cloudinary(contents, folder="mochila_lista/invoices")
        nueva_factura = Invoice(
            negocio_id=negocio_id,
            imagen_url=img_url,
            estado='procesando',
            fecha_carga=datetime.utcnow()
        )
        db.add(nueva_factura)
        db.commit()
        db.refresh(nueva_factura)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error creando factura inicial: {str(e)}")


    # 🔥 2. ANÁLISIS DE INTELIGENCIA ARTIFICIAL CON EXPONENTIAL BACKOFF
    client = genai.Client(api_key=API_KEY)
    prompt = """
    Actúa como un experto contable y analista de inventarios de papelería en Perú.
    Tu misión es digitalizar esta factura física/electrónica con PRECISIÓN ABSOLUTA.
    
    COMPLEJIDAD DEL NEGOCIO Y FLEXIBILIDAD:
    Los proveedores venden productos en Lotes (Millares, Cientos, Docenas, Cajas).
    A menudo, el cliente compra FRACCIONES de ese lote (Ej: "0.25 MLL" significa 1/4 de millar).
    Debes deducir la matemática de la factura incluso si faltan datos implícitos.

    REGLAS ESTRICTAS DE EXTRACCIÓN DE ÍTEMS:
    1. 'ump_compra': La unidad de empaque del proveedor. (Ej: "DOC", "MLL", "CTO", "UND", "PAQ", "CJA"). Si no se especifica, usa "UND".
    2. 'unidades_por_lote': Deduce cuántas unidades individuales vienen en ese 'ump_compra'. (MLL=1000, CTO=100, DOC=12, GRZ=144, UND=1. Si dice 'Caja x 50', es 50).
    3. 'cantidad_ump_comprada': El número exacto en la columna "Cantidad". (Ej: si dice 0.25 MLL, pon 0.25. Si dice 3 DOC, pon 3.0).
    4. 'total_pago_lote': El importe TOTAL pagado por esa línea específica (Subtotal o Importe de Venta).
    5. 'precio_ump_proveedor': El precio unitario del lote. Si no está claro en la foto, INFIÉRELO DIVIDIENDO: (total_pago_lote / cantidad_ump_comprada).

    REGLAS DE DESCRIPCIÓN:
    - 'producto_padre_estimado': El nombre general limpio (Ej: "Cuaderno Stanford", "Lápiz Chequeador").
    - 'variante_detectada': Características específicas, colores, tamaños (Ej: "A4 Cuadriculado", "Color Rojo").
    - 'marca_detectada': Solo si se menciona explícitamente (Faber Castell, Artesco, etc).

    Extrae el monto total de toda la factura en 'monto_total_factura'.
    Extrae los datos respetando estrictamente el esquema JSON solicitado.
    """

    max_retries = 5 # 🔥 Aumentado a 5 intentos
    attempt = 0
    last_error = None
    ai_result = None

    while attempt < max_retries:
        try:
            response = await client.aio.models.generate_content(
                model='gemini-2.5-flash',
                contents=[prompt, image],
                config=types.GenerateContentConfig(
                    response_mime_type='application/json',
                    response_schema=AIInvoiceResponse
                )
            )

            if response.parsed:
                ai_result = response.parsed
                break
            else:
                clean_text = response.text.replace("```json", "").replace("```", "").strip()
                ai_result = AIInvoiceResponse(**json.loads(clean_text))
                break

        except ValidationError as e:
            print(f"⚠️ Intento {attempt + 1}: Error de validación JSON.")
            last_error = f"Datos inválidos de IA: {e}"
        except Exception as e:
            error_msg = str(e)
            print(f"⚠️ Intento {attempt + 1}: Error de API ({error_msg}).")
            last_error = error_msg

        attempt += 1
        if attempt < max_retries:
            # 🔥 Lógica robusta de retroceso exponencial con Jitter
            wait_time = (2 ** (attempt - 1)) + random.uniform(0.5, 1.5)
            print(f"⏳ Servidor ocupado. Esperando {wait_time:.2f}s antes de reintentar...")
            await asyncio.sleep(wait_time)

    if not ai_result:
        # Si falla la IA tras 5 intentos, actualizamos la factura a error
        nueva_factura.estado = 'error'
        db.commit()
        raise HTTPException(status_code=500, detail=f"No se pudo procesar la factura tras {max_retries} intentos. Por favor, intenta de nuevo más tarde.")

    # 🔥 3. GUARDAMOS AUDITORÍA Y VINCULAMOS ID
    try:
        nueva_factura.datos_crudos_ia_json = ai_result.model_dump()
        nueva_factura.cantidad_items_extraidos = len(ai_result.items)
        nueva_factura.monto_total_factura = ai_result.monto_total_factura
        nueva_factura.estado = 'revision' 
        db.commit()
        
        ai_result.invoice_id = nueva_factura.id 
        return ai_result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error guardando auditoría: {str(e)}")