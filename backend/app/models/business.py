from sqlalchemy import Column, Integer, String, Text, ForeignKey, DateTime, Numeric 
from sqlalchemy.orm import relationship
from datetime import datetime
from app.db.base_class import Base

class Business(Base):
    __tablename__ = "negocios"

    id = Column(Integer, primary_key=True, index=True)
    nombre_comercial = Column(String(150), nullable=False)
    ruc = Column(String(20))
    direccion = Column(Text)
    logo_url = Column(Text)
    
    configuracion_impresora = Column(Text, nullable=True) 
    informacion_pago = Column(Text, nullable=True)

    latitud = Column(Numeric(12, 8), nullable=True)
    longitud = Column(Numeric(12, 8), nullable=True)

    id_dueno = Column(Integer, ForeignKey("usuarios.id"))
    fecha_creacion = Column(DateTime, default=datetime.utcnow)

    # ==========================================
    # RELACIONES AISLADAS (Data Isolation)
    # ==========================================
    dueno = relationship("User", back_populates="negocios_creados", foreign_keys=[id_dueno])
    usuarios_asociados = relationship("NegocioUsuario", back_populates="negocio", cascade="all, delete-orphan")
    
    productos = relationship("Product", back_populates="negocio")
    proveedores = relationship("Provider", back_populates="negocio", cascade="all, delete-orphan")
    clientes = relationship("Cliente", back_populates="negocio", cascade="all, delete-orphan")
    ventas = relationship("Venta", back_populates="negocio", cascade="all, delete-orphan")
    cotizaciones = relationship("SmartQuotation", back_populates="negocio", cascade="all, delete-orphan")
    pagos = relationship("Pago", back_populates="negocio", cascade="all, delete-orphan")
    categorias = relationship("Category", back_populates="negocio")
    marcas = relationship("Brand", back_populates="negocio")
    facturas = relationship("Invoice", back_populates="negocio")