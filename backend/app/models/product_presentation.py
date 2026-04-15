from sqlalchemy import Column, Integer, String, Numeric, Boolean, ForeignKey
from sqlalchemy.orm import relationship
from datetime import datetime
from app.db.base_class import Base

class ProductPresentation(Base):
    __tablename__ = "presentaciones_producto"

    id = Column(Integer, primary_key=True, index=True)
    producto_id = Column(Integer, ForeignKey("productos.id", ondelete="CASCADE"), nullable=False)
    proveedor_id = Column(Integer, ForeignKey("proveedores.id"), nullable=True)

    # --- IDENTIFICACIÓN ---
    nombre_especifico = Column(String(100), nullable=True)
    descripcion = Column(String(200), nullable=True)
    imagen_url = Column(String(200), nullable=True)
    codigo_barras = Column(String(50), nullable=True)
    
    # --- MOTOR MATEMÁTICO: CÓMO SE COMPRA (FACTURA) ---
    ump_compra = Column(String(50), nullable=True) 
    precio_ump_proveedor = Column(Numeric(12, 2), nullable=True) 
    cantidad_ump_comprada = Column(Numeric(12, 4), nullable=True)
    total_pago_lote = Column(Numeric(12, 2), nullable=True) 
    unidades_por_lote = Column(Integer, default=1, nullable=False) 
    factura_carga_id = Column(Integer, ForeignKey("facturas_carga.id", ondelete="SET NULL"), nullable=True)
    
    # --- MOTOR MATEMÁTICO: CÓMO SE VENDE (INVENTARIO) ---
    unidad_venta = Column(String(100), default="Unidad") # Reemplaza a nombre_presentacion
    unidades_por_venta = Column(Integer, default=1, nullable=False) # Ej: 12 si se vende por docena
    
    costo_unitario_calculado = Column(Numeric(12, 4), nullable=True) # Lo que cuesta la unidad_venta real
    factor_ganancia_venta = Column(Numeric(10, 2), nullable=True)
    precio_venta_final = Column(Numeric(12, 2), default=0.00, nullable=False)
    
    # Ofertas y Descuentos
    precio_oferta = Column(Numeric(12, 2), nullable=True)
    tipo_descuento = Column(String(20), nullable=True)
    valor_descuento = Column(Numeric(12, 2), nullable=True)

    # Estado y Control
    stock_actual = Column(Integer, default=0) # Siempre en UNIDADES BASE
    estado = Column(String(20), default='publico')
    stock_alerta = Column(Integer, default=5)
    es_default = Column(Boolean, default=False)
    activo = Column(Boolean, default=True)

    # Relaciones
    producto = relationship("Product", back_populates="presentaciones")
    proveedor = relationship("Provider", back_populates="presentaciones")
    factura_carga = relationship("Invoice", back_populates="presentaciones")