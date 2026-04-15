from sqlalchemy import Column, Integer, String, Boolean, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.db.base_class import Base

class Provider(Base):
    __tablename__ = "proveedores"

    id = Column(Integer, primary_key=True, index=True)
    negocio_id = Column(Integer, ForeignKey("negocios.id", ondelete="CASCADE"), nullable=False) 
    
    nombre_empresa = Column(String(150), nullable=False)
    
    contacto_nombre = Column(String(100), nullable=True)
    telefono = Column(String(20), nullable=True)
    email = Column(String(100), nullable=True)
    ruc = Column(String(20), nullable=True)
    
    fecha_creacion = Column(DateTime(timezone=True), server_default=func.now())
    activo = Column(Boolean, default=True)

    # 🔥 CORRECCIÓN: ELIMINADA LA REFERENCIA ANTIGUA A 'productos'.
    # AHORA SOLO SE RELACIONA CON LAS 'presentaciones' Y EL 'negocio'.
    presentaciones = relationship("ProductPresentation", back_populates="proveedor")
    negocio = relationship("Business", back_populates="proveedores")