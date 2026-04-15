from typing import List, Optional
from pydantic import BaseModel

# 1. Metadatos del Encabezado
class ExtractedMetadata(BaseModel):
    institution_name: Optional[str] = None
    student_name: Optional[str] = None
    grade_level: Optional[str] = None

# 2. Ítem Individual de la Lista
class ExtractedItem(BaseModel):
    id: int # ID temporal para el frontend (1, 2, 3...)
    original_text: str # Texto original para referencia y depuración
    full_name: str # Nombre descriptivo completo corregido
    brand: Optional[str] = None # Marca detectada o null
    quantity: int = 1
    unit: Optional[str] = "unidad"
    notes: Optional[str] = None # Detalles extra (colores, tamaño, forrado)

# 3. Respuesta Principal (El contrato con el Frontend)
class SchoolListAnalysisResponse(BaseModel):
    metadata: ExtractedMetadata
    items: List[ExtractedItem]