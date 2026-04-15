from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from app.schemas.smart_quotation import SmartQuotationResponse 

class VentaDetalleCreate(BaseModel):
    presentation_id: int
    quantity: int
    unit_price: float

class CuotaCreate(BaseModel):
    numero_cuota: int
    monto: float
    fecha_vencimiento: datetime

class CuotaResponse(CuotaCreate):
    id: int
    estado: str
    monto_pagado: float
    class Config:
        from_attributes = True

class VentaCreate(BaseModel):
    cotizacion_id: Optional[int] = None
    cliente_id: Optional[int] = None 
    client_name_override: Optional[str] = None 
    notas: Optional[str] = None 
    origen_venta: Optional[str] = "smart_quotation"
    metodo_pago: str 
    estado_pago: str 
    estado_entrega: str 
    fecha_entrega: Optional[datetime] = None 
    monto_total: float
    monto_pagado: float 
    descuento_aplicado: float = 0.0
    
    cuotas: Optional[List[CuotaCreate]] = [] 
    detalle_venta: Optional[List[VentaDetalleCreate]] = [] 

class VentaResponse(BaseModel):
    id: int
    negocio_id: int # 🔥 FASE 1
    creado_por_usuario_id: int # 🔥 FASE 1
    cotizacion_id: Optional[int]
    cliente_id: Optional[int] 
    origen_venta: str
    is_archived: bool
    metodo_pago: str 
    estado_pago: str 
    estado_entrega: str 
    fecha_entrega: Optional[datetime]
    monto_total: float
    monto_pagado: float 
    descuento_aplicado: float
    fecha_venta: datetime
    cuotas: List[CuotaResponse] = []
    
    class Config:
        from_attributes = True

class VentaDetailResponse(VentaResponse):
    cotizacion: Optional[SmartQuotationResponse] = None 
    cliente_nombre: Optional[str] = None
    cliente_telefono: Optional[str] = None

class SalesStatsResponse(BaseModel):
    total_ingresos: float  
    total_deuda: float     
    cantidad_ventas: int