from sqlalchemy import Column, Integer, String, Boolean, ForeignKey
from sqlalchemy.orm import relationship
from app.db.base_class import Base

class Category(Base):
    __tablename__ = "categorias"

    id = Column(Integer, primary_key=True, index=True)
    negocio_id = Column(Integer, ForeignKey("negocios.id", ondelete="CASCADE"), nullable=False) # 🔥 Aislamiento
    
    nombre = Column(String(50), nullable=False) 
    descripcion = Column(String, nullable=True) 
    activo = Column(Boolean, default=True)      

    # Relaciones
    negocio = relationship("Business", back_populates="categorias")
    productos = relationship("Product", back_populates="categoria")