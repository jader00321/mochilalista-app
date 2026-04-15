from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Numeric, Date
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import relationship
from datetime import datetime
from app.db.base_class import Base

class Invoice(Base):
    __tablename__ = "facturas_carga"

    id = Column(Integer, primary_key=True, index=True)
    negocio_id = Column(Integer, ForeignKey("negocios.id", ondelete="CASCADE"), nullable=False)
    imagen_url = Column(String, nullable=False)
    estado = Column(String(20), default='procesando') # procesando, revision, completado
    fecha_carga = Column(DateTime, default=datetime.utcnow)

    # --- NUEVOS CAMPOS DE AUDITORÍA IA ---
    proveedor_id = Column(Integer, ForeignKey("proveedores.id", ondelete="SET NULL"), nullable=True)
    monto_total_factura = Column(Numeric(12, 2), nullable=True)
    fecha_emision = Column(Date, nullable=True)
    
    # Campo para la "Auditoría de IA" en Flutter
    cantidad_items_extraidos = Column(Integer, nullable=True)
    datos_crudos_ia_json = Column(JSONB, nullable=True) 

    # La relación apunta a presentaciones (el lote ingresado), no al producto general
    presentaciones = relationship("ProductPresentation", back_populates="factura_carga")
    negocio = relationship("Business", back_populates="facturas")