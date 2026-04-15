from pydantic import BaseModel
from typing import List, Optional

# --- INPUT: Lo que viene de la App (Items extraídos) ---
class MatchItemInput(BaseModel):
    id: int  # ID temporal del frontend (1, 2...)
    full_name: str
    brand: Optional[str] = None
    quantity: int = 1

class BatchMatchRequest(BaseModel):
    items: List[MatchItemInput]

# --- OUTPUT: Lo que devolvemos (Productos sugeridos) ---
class MatchedProductInfo(BaseModel):
    product_id: int
    presentation_id: int
    
    # 🔥 FASE 1: DESGLOSE ESTRUCTURAL
    full_name: str          
    product_name: str
    specific_name: Optional[str] = None
    brand: Optional[str] = None
    
    price: float
    offer_price: Optional[float] = None
    unit: Optional[str] = "Unidad"
    conversion_factor: Optional[int] = 1
    stock: int
    image_url: Optional[str]

class MatchResult(BaseModel):
    item_id: int            
    match_type: str         # "AUTO" (Verde), "SUGGESTION" (Ámbar), "NONE" (Rojo)
    score: int              # Puntaje de confianza (0-100)
    suggested_product: Optional[MatchedProductInfo] = None

class BatchMatchResponse(BaseModel):
    results: List[MatchResult]