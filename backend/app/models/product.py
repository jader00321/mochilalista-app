from sqlalchemy import Column, Integer, String, Text, Boolean, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from datetime import datetime
from app.db.base_class import Base

class Product(Base):
    __tablename__ = "productos"

    id = Column(Integer, primary_key=True, index=True)
    negocio_id = Column(Integer, ForeignKey("negocios.id"), nullable=False)
    
    # RELACIONES CLAVE
    categoria_id = Column(Integer, ForeignKey("categorias.id"))
    marca_id = Column(Integer, ForeignKey("marcas.id"), nullable=True)
    
    # Campos normales
    codigo_barras = Column(String(50))
    nombre = Column(String(150), index=True)
    descripcion = Column(Text)
    imagen_url = Column(Text)
    estado = Column(String(20), default='privado')
    fecha_actualizacion = Column(DateTime, default=datetime.utcnow)

    # Definición de relaciones
    negocio = relationship("Business", back_populates="productos")
    presentaciones = relationship("ProductPresentation", back_populates="producto", cascade="all, delete-orphan")
    categoria = relationship("Category", back_populates="productos")
    marca = relationship("Brand", back_populates="productos")

    # --- EL TRUCO DEL STOCK DINÁMICO ---
    @property
    def stock_total_unidades(self):
        # Suma el stock_actual de todas sus presentaciones
        if self.presentaciones:
            return sum(p.stock_actual for p in self.presentaciones)
        return 0
        
    @property
    def stock_total_calculado(self):
        # Alias exacto para que el Schema (Pydantic) lo lea sin problemas
        return self.stock_total_unidades
    