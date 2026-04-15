from pydantic import BaseModel
from typing import List, Optional, Any, Dict

class AIItemExtracted(BaseModel):
    descripcion_detectada: str
    producto_padre_estimado: Optional[str] = None 
    variante_detectada: Optional[str] = None      
    marca_detectada: Optional[str] = None
    codigo_detectado: Optional[str] = None
    
    ump_compra: Optional[str] = "UND"
    unidades_por_lote: Optional[int] = 1
    cantidad_ump_comprada: Optional[float] = 1.0
    precio_ump_proveedor: Optional[float] = 0.0
    total_pago_lote: Optional[float] = 0.0
    
    # 🔥 SOLUCIÓN 1: Ahora FastAPI acepta y lee la Unidad de Venta que mandas desde la App
    unidad_venta: Optional[str] = None

class AIInvoiceResponse(BaseModel):
    invoice_id: Optional[int] = None
    proveedor_detectado: str
    ruc_detectado: Optional[str] = None
    fecha_detectada: Optional[str] = None
    monto_total_factura: Optional[float] = None 
    items: List[AIItemExtracted]

class MatchData(BaseModel):
    id: int
    nombre: str
    stock_actual: Optional[int] = 0
    marca_nombre: Optional[str] = "Genérica"
    categoria_nombre: Optional[str] = "General"
    precio_venta_actual: Optional[float] = 0.0
    costo_unitario_actual: Optional[float] = 0.0 
    factor: Optional[int] = 1
    unidad: Optional[str] = "Unidad"
    available_presentations: Optional[List[Dict[str, Any]]] = []

class MatchResult(BaseModel):
    estado: str  
    confianza: int
    datos: Optional[MatchData] = None 

class StagingVariant(BaseModel):
    uuid_temporal: str 
    nombre_especifico: str 
    
    ump_compra: str
    cantidad_ump_comprada: float
    precio_ump_proveedor: float
    total_pago_lote: float
    unidades_por_lote: int
    
    unidad_venta: str
    unidades_por_venta: int
    costo_unitario_sugerido: float
    factor_ganancia_venta_sugerido: float
    precio_venta_sugerido: float
    
    codigo_barras: Optional[str] = None
    match_presentacion: MatchResult 
    confirmado: bool = True

class StagingProductGroup(BaseModel):
    nombre_padre: str
    marca_texto: str
    match_producto: MatchResult
    match_marca: MatchResult
    categoria_sugerida_id: Optional[int] = None
    categoria_texto_sugerida: Optional[str] = None 
    variantes: List[StagingVariant]

class StagingResponse(BaseModel):
    invoice_id: Optional[int] = None
    proveedor_match: MatchResult
    proveedor_texto: str 
    ruc_detectado: Optional[str] = None
    fecha_factura: Optional[str] = None
    monto_total_factura: Optional[float] = None
    productos_agrupados: List[StagingProductGroup]

class BrandBatchInput(BaseModel):
    modo: str 
    id_existente: Optional[int] = None
    nombre_nuevo: Optional[str] = None
    ruc: Optional[str] = None

class BatchVariantInput(BaseModel):
    id_presentacion_existente: Optional[int] = None
    nombre_especifico: Optional[str] = ""
    codigo_barras: Optional[str] = None
    
    ump_compra: Optional[str] = "UND"
    precio_ump_proveedor: Optional[float] = 0.0
    cantidad_ump_comprada: Optional[float] = 1.0
    total_pago_lote: Optional[float] = 0.0
    unidades_por_lote: Optional[int] = 1
    factura_carga_id: Optional[int] = None
    
    unidad_venta: str = "Unidad"
    unidades_por_venta: int = 1
    factor_ganancia_venta: Optional[float] = 1.35
    
    cantidad_a_sumar: Optional[int] = 0
    actualizar_costo: Optional[bool] = True
    actualizar_precio_venta: Optional[bool] = False
    actualizar_nombre: Optional[bool] = False 

class BatchProductInput(BaseModel):
    accion: str 
    id_producto_existente: Optional[int] = None
    nombre_nuevo: Optional[str] = None
    marca: Optional[BrandBatchInput] = None
    categoria_id: Optional[int] = None 
    variantes: List[BatchVariantInput]

class BatchExecutionRequest(BaseModel):
    factura_carga_id: Optional[int] = None 
    fecha_emision: Optional[str] = None 
    proveedor: BrandBatchInput 
    items: List[BatchProductInput]