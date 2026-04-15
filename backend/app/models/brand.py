from sqlalchemy import Column, Integer, String, Boolean, ForeignKey
from sqlalchemy.orm import relationship
from app.db.base_class import Base

class Brand(Base):
    __tablename__ = "marcas"

    id = Column(Integer, primary_key=True, index=True)
    negocio_id = Column(Integer, ForeignKey("negocios.id", ondelete="CASCADE"), nullable=False) # 🔥 Aislamiento
    
    nombre = Column(String(100), nullable=False)
    imagen_url = Column(String, nullable=True) 
    activo = Column(Boolean, default=True)

    # Relaciones
    negocio = relationship("Business", back_populates="marcas")
    productos = relationship("Product", back_populates="marca")