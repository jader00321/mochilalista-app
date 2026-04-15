from sqlalchemy import Column, Integer, String, ForeignKey, DateTime, Numeric, Text
from sqlalchemy.orm import relationship
from datetime import datetime
from app.db.base_class import Base

class Pago(Base):
    __tablename__ = "pagos"

    id = Column(Integer, primary_key=True, index=True)
    
    # 🔥 FASE 1: Aislamiento y Auditoría
    negocio_id = Column(Integer, ForeignKey("negocios.id", ondelete="CASCADE"), nullable=False)
    creado_por_usuario_id = Column(Integer, ForeignKey("usuarios.id"), nullable=False)
    
    cliente_id = Column(Integer, ForeignKey("clientes.id"), nullable=True)
    venta_id = Column(Integer, ForeignKey("ventas.id", ondelete="SET NULL"), nullable=True)
    cuota_id = Column(Integer, ForeignKey("cuotas.id", ondelete="SET NULL"), nullable=True)
    
    monto = Column(Numeric(12, 2), nullable=False)
    metodo_pago = Column(String(50), nullable=False)
    nota = Column(Text, nullable=True)
    fecha_pago = Column(DateTime, default=datetime.utcnow)

    # Relaciones
    negocio = relationship("Business", back_populates="pagos")
    creador = relationship("User", foreign_keys=[creado_por_usuario_id])
    cliente = relationship("Cliente", back_populates="pagos")
    venta_asociada = relationship("Venta", back_populates="pagos_directos")
    cuota_asociada = relationship("Cuota", back_populates="pagos_aplicados")