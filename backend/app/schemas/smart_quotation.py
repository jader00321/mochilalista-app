from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime, date

class SmartQuotationItemCreate(BaseModel):
    product_id: Optional[int] = None
    presentation_id: Optional[int] = None
    quantity: int
    unit_price_applied: float
    original_unit_price: float
    
    product_name: Optional[str] = None
    brand_name: Optional[str] = None
    specific_name: Optional[str] = None
    sales_unit: Optional[str] = "Unidad"
    
    original_text: Optional[str] = None
    is_manual_price: bool = False
    is_available: bool = True

class SmartQuotationItemResponse(SmartQuotationItemCreate):
    id: int
    quotation_id: int
    image_url: Optional[str] = None
    class Config:
        from_attributes = True

class SmartQuotationBase(BaseModel):
    client_id: Optional[int] = None
    client_name: Optional[str] = None
    institution_name: Optional[str] = None
    grade_level: Optional[str] = None
    notas: Optional[str] = None
    total_amount: float = 0.0
    total_savings: float = 0.0
    status: str = "DRAFT" # DRAFT, PENDING, PENDING_APPROVAL, READY, SOLD, ARCHIVED
    type: str = "manual"  # manual, pack, ai_scan, pos_rapido, client_web
    is_template: bool = False
    valid_until: Optional[date] = None
    source_image_url: Optional[str] = None
    original_text_dump: Optional[str] = None

class SmartQuotationCreate(SmartQuotationBase):
    clone_source_id: Optional[int] = None
    items: List[SmartQuotationItemCreate] = []

class SmartQuotationUpdate(BaseModel):
    client_id: Optional[int] = None
    client_name: Optional[str] = None 
    
    real_client_name: Optional[str] = None 
    real_client_phone: Optional[str] = None
    real_client_dni: Optional[str] = None
    real_client_address: Optional[str] = None
    real_client_email: Optional[str] = None
    real_client_notes: Optional[str] = None
    
    institution_name: Optional[str] = None
    grade_level: Optional[str] = None
    notas: Optional[str] = None
    status: Optional[str] = None
    total_amount: Optional[float] = None
    total_savings: Optional[float] = None
    items: Optional[List[SmartQuotationItemCreate]] = None 

class SmartQuotationResponse(SmartQuotationBase):
    id: int
    negocio_id: int
    creado_por_usuario_id: int
    created_at: datetime
    updated_at: datetime
    items: List[SmartQuotationItemResponse] = []
    class Config:
        from_attributes = True

class StockWarningItem(BaseModel):
    item_id: int
    product_name: str
    requested_qty: int
    available_stock: int

class PriceChangeItem(BaseModel):
    item_id: int
    product_name: str
    old_price: float
    new_price: float

class ValidationResult(BaseModel):
    has_issues: bool
    can_sell: bool
    status: str 
    stock_warnings: List[StockWarningItem] = []
    price_changes: List[PriceChangeItem] = []