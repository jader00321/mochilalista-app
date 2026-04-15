from sqlalchemy import Column, Integer, String, ForeignKey, DateTime, Enum, Numeric, Boolean
from sqlalchemy.orm import relationship
from datetime import datetime
import enum
from app.db.base_class import Base

class MetodoPago(str, enum.Enum):
    EFECTIVO = "efectivo"
    YAPE = "yape"
    PLIN = "plin"
    TARJETA = "tarjeta"
    CREDITO = "credito"

class EstadoPago(str, enum.Enum):
    PAGADO = "pagado"
    PARCIAL = "parcial"
    PENDIENTE = "pendiente"

class EstadoEntrega(str, enum.Enum):
    ENTREGADO = "entregado"
    PENDIENTE_RECOJO = "pendiente_recojo"
    EN_CAMINO = "en_camino"
    RETENIDO_POR_PAGO = "retenido_por_pago"

class Cuota(Base):
    __tablename__ = "cuotas"
    id = Column(Integer, primary_key=True, index=True)
    venta_id = Column(Integer, ForeignKey("ventas.id", ondelete="CASCADE"), nullable=False)
    numero_cuota = Column(Integer, nullable=False)
    monto = Column(Numeric(12, 2), nullable=False)
    monto_pagado = Column(Numeric(12, 2), default=0.00)
    fecha_vencimiento = Column(DateTime, nullable=False)
    estado = Column(String(50), default="pendiente")
    venta = relationship("Venta", back_populates="cuotas")
    pagos_aplicados = relationship("Pago", back_populates="cuota_asociada")

class Venta(Base):
    __tablename__ = "ventas"

    id = Column(Integer, primary_key=True, index=True)
    
    # 🔥 FASE 1: Aislamiento y Auditoría
    negocio_id = Column(Integer, ForeignKey("negocios.id", ondelete="CASCADE"), nullable=False)
    creado_por_usuario_id = Column(Integer, ForeignKey("usuarios.id"), nullable=False)
    
    cotizacion_id = Column(Integer, ForeignKey("smart_quotations.id"), nullable=True, unique=True) 
    
    # 🔥 SOLUCIÓN AQUÍ: nullable=True para permitir ventas rápidas a clientes anónimos
    cliente_id = Column(Integer, ForeignKey("clientes.id"), nullable=True)
    
    origen_venta = Column(String(50), default="smart_quotation") 
    is_archived = Column(Boolean, default=False)
    metodo_pago = Column(String(50), nullable=False) 
    estado_pago = Column(String(50), default=EstadoPago.PAGADO.value)
    estado_entrega = Column(String(50), default=EstadoEntrega.ENTREGADO.value)
    fecha_entrega = Column(DateTime, nullable=True) 
    
    monto_total = Column(Numeric(12, 2), nullable=False)
    monto_pagado = Column(Numeric(12, 2), nullable=False) 
    descuento_aplicado = Column(Numeric(12, 2), default=0.00)
    fecha_venta = Column(DateTime, default=datetime.utcnow)
    
    # Relaciones
    negocio = relationship("Business", back_populates="ventas")
    creador = relationship("User", foreign_keys=[creado_por_usuario_id])
    cotizacion = relationship("SmartQuotation", back_populates="venta")
    cliente = relationship("Cliente", back_populates="ventas")
    cuotas = relationship("Cuota", back_populates="venta", cascade="all, delete-orphan")
    pagos_directos = relationship("Pago", back_populates="venta_asociada")