from sqlalchemy import Column, Integer, String, Text, Boolean, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from datetime import datetime
from app.db.base_class import Base

class Notification(Base):
    __tablename__ = "notificaciones"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False)
    
    # 🔥 NUEVO: Contexto estricto del negocio
    negocio_id = Column(Integer, ForeignKey("negocios.id", ondelete="CASCADE"), nullable=False)
    
    titulo = Column(String(200), nullable=False)
    mensaje = Column(Text, nullable=False)
    tipo = Column(String(50), default="info") # info, alerta, exito
    leida = Column(Boolean, default=False)
    fecha_creacion = Column(DateTime, default=datetime.utcnow)

    # --- CAMPOS DE DEEP LINKING (Navegación Flutter) ---
    prioridad = Column(String(50), default="Media") # Alta, Media, Baja
    objeto_relacionado_tipo = Column(String(100), nullable=True) # "venta", "cotizacion", "factura_carga"
    objeto_relacionado_id = Column(Integer, nullable=True) # ID para abrir la pantalla correcta

    # Relaciones
    usuario = relationship("User", back_populates="notificaciones")
    negocio = relationship("Business")