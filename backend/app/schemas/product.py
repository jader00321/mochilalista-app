from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime

class ProductPresentationBase(BaseModel):
    nombre_especifico: Optional[str] = None
    descripcion: Optional[str] = None
    imagen_url: Optional[str] = None
    estado: str = 'privado'
    codigo_barras: Optional[str] = None
    proveedor_id: Optional[int] = None
    
    # --- COMPRA ---
    ump_compra: Optional[str] = None
    precio_ump_proveedor: Optional[float] = None
    cantidad_ump_comprada: Optional[float] = None
    total_pago_lote: Optional[float] = None
    unidades_por_lote: int = 1
    factura_carga_id: Optional[int] = None
    
    # --- VENTA Y CÁLCULOS 🔥 AHORA SÍ ESTÁN AQUÍ ---
    unidad_venta: str = "Unidad"
    unidades_por_venta: int = 1
    costo_unitario_calculado: Optional[float] = 0.0 # Permitimos guardarlo
    factor_ganancia_venta: Optional[float] = 1.35
    precio_venta_final: float = 0.0 # Permitimos guardarlo
    
    precio_oferta: Optional[float] = None
    tipo_descuento: Optional[str] = None      
    valor_descuento: Optional[float] = None   
    
    stock_actual: int = 0
    stock_alerta: int = 5
    es_default: bool = False

class ProductPresentationCreate(ProductPresentationBase):
    pass

class ProductPresentationUpdate(BaseModel):
    nombre_especifico: Optional[str] = None
    descripcion: Optional[str] = None
    imagen_url: Optional[str] = None
    codigo_barras: Optional[str] = None
    proveedor_id: Optional[int] = None
    
    ump_compra: Optional[str] = None
    precio_ump_proveedor: Optional[float] = None
    cantidad_ump_comprada: Optional[float] = None
    total_pago_lote: Optional[float] = None
    unidades_por_lote: Optional[int] = None
    factura_carga_id: Optional[int] = None
    
    unidad_venta: Optional[str] = None
    unidades_por_venta: Optional[int] = None
    costo_unitario_calculado: Optional[float] = None # 🔥 Agregado para el PATCH
    factor_ganancia_venta: Optional[float] = None
    precio_venta_final: Optional[float] = None       # 🔥 Agregado para el PATCH
    
    precio_oferta: Optional[float] = None 
    tipo_descuento: Optional[str] = None      
    valor_descuento: Optional[float] = None
    
    stock_actual: Optional[int] = None
    estado: Optional[str] = None
    stock_alerta: Optional[int] = None
    es_default: Optional[bool] = None
    activo: Optional[bool] = None

class ProductPresentationResponse(ProductPresentationBase):
    id: int
    producto_id: int
    activo: bool
    
    class Config:
        from_attributes = True

class ProductBase(BaseModel):
    nombre: str
    descripcion: Optional[str] = None
    marca_id: Optional[int] = None
    categoria_id: int
    imagen_url: Optional[str] = None
    estado: str = 'privado'
    codigo_barras: Optional[str] = None

class ProductCreate(ProductBase):
    pass

class ProductCreateFull(ProductBase):
    presentaciones: List[ProductPresentationCreate] = []

class ProductUpdate(BaseModel):
    nombre: Optional[str] = None
    descripcion: Optional[str] = None
    marca_id: Optional[int] = None
    categoria_id: Optional[int] = None
    estado: Optional[str] = None
    imagen_url: Optional[str] = None
    codigo_barras: Optional[str] = None

class ProductResponse(ProductBase):
    id: int
    negocio_id: int
    stock_total_calculado: int = 0 
    fecha_actualizacion: Optional[datetime] = None
    presentaciones: List[ProductPresentationResponse] = []
    
    class Config:
        from_attributes = True