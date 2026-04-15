from sqlalchemy import Column, Integer, String, Text, DateTime, Numeric, JSON, ForeignKey
from sqlalchemy.orm import relationship
from datetime import datetime
from app.db.base_class import Base

class Cliente(Base):
    __tablename__ = "clientes"

    id = Column(Integer, primary_key=True, index=True)

    # 🔥 FASE 1: Aislamiento por Negocio
    negocio_id = Column(Integer, ForeignKey("negocios.id", ondelete="CASCADE"), nullable=False)
    
    # 🔥 FASE 1: Auditoría (Quién registró a este cliente a mano)
    creado_por_usuario_id = Column(Integer, ForeignKey("usuarios.id"), nullable=False) 
    
    # 🔥 FASE 1: PUENTE DE IDENTIDAD (Si el cliente usa la app, se vincula aquí)
    usuario_vinculado_id = Column(Integer, ForeignKey("usuarios.id"), nullable=True)
    
    nombre_completo = Column(String(200), nullable=False, index=True)
    telefono = Column(String(50), nullable=False, index=True) 
    dni_ruc = Column(String(20), nullable=True)
    direccion = Column(String(255), nullable=True)
    correo = Column(String(150), nullable=True)
    
    notas = Column(Text, nullable=True) 
    nivel_confianza = Column(String(50), default="bueno") 
    etiquetas = Column(JSON, default=list) 
    
    deuda_total = Column(Numeric(12, 2), default=0.00) 
    saldo_a_favor = Column(Numeric(12, 2), default=0.00)
    entregas_pendientes = Column(Integer, default=0)
    
    fecha_registro = Column(DateTime, default=datetime.utcnow)
    
    # Relaciones
    negocio = relationship("Business", back_populates="clientes")
    creador = relationship("User", foreign_keys=[creado_por_usuario_id])
    usuario_vinculado = relationship("User", back_populates="perfiles_cliente_crm", foreign_keys=[usuario_vinculado_id])
    
    cotizaciones = relationship("SmartQuotation", back_populates="cliente")
    ventas = relationship("Venta", back_populates="cliente")
    pagos = relationship("Pago", back_populates="cliente", cascade="all, delete-orphan")