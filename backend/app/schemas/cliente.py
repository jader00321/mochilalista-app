from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
from app.schemas.pago import PagoResponse 

class VentaSummary(BaseModel):
    id: int
    monto_total: float
    monto_pagado: float = 0.0 
    fecha_venta: datetime
    estado_entrega: str
    origen_venta: str        
    items_count: int         

    class Config:
        from_attributes = True

class ClienteBase(BaseModel):
    nombre_completo: str
    telefono: str
    dni_ruc: Optional[str] = None
    direccion: Optional[str] = None
    correo: Optional[str] = None
    notas: Optional[str] = None
    nivel_confianza: str = "bueno"     
    etiquetas: List[str] = []          

class ClienteCreate(ClienteBase):
    pass 

class ClienteUpdate(BaseModel):
    nombre_completo: Optional[str] = None
    telefono: Optional[str] = None
    dni_ruc: Optional[str] = None
    direccion: Optional[str] = None
    correo: Optional[str] = None
    notas: Optional[str] = None
    nivel_confianza: Optional[str] = None
    etiquetas: Optional[List[str]] = None

class ClienteResponse(ClienteBase):
    id: int
    negocio_id: int # 🔥 FASE 1
    creado_por_usuario_id: int # 🔥 FASE 1
    usuario_vinculado_id: Optional[int] = None # 🔥 FASE 1: Puente de Identidad
    
    deuda_total: float = 0.0
    saldo_a_favor: float = 0.0 
    entregas_pendientes_count: int = Field(default=0, validation_alias='entregas_pendientes')
    fecha_registro: datetime
    
    ultimas_ventas: List[VentaSummary] = [] 
    ultimos_pagos: List[PagoResponse] = [] 

    class Config:
        from_attributes = True
        
class LedgerItem(BaseModel):
    id_ref: int
    tipo: str 
    fecha: datetime
    monto: float
    detalle: str
    saldo_resultante: float