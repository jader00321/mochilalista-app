from sqlalchemy import Column, Integer, String, Float, ForeignKey, DateTime, Boolean, Text, Date, Numeric
from sqlalchemy.orm import relationship
from datetime import datetime
import enum
from app.db.base_class import Base

class QuotationStatus(str, enum.Enum):
    DRAFT = "DRAFT"
    PENDING = "PENDING"
    PENDING_APPROVAL = "PENDING_APPROVAL" # 🔥 FASE 1: Nuevo estado para clientes de comunidad
    READY_TO_SELL = "READY"
    SOLD = "SOLD"
    ARCHIVED = "ARCHIVED"

class QuotationType(str, enum.Enum):
    MANUAL = "manual"
    AI_SCAN = "ai_scan"
    PACK = "pack"
    CLIENT_WEB = "client_web"
    CLONED = "cloned"

class SmartQuotation(Base):
    __tablename__ = "smart_quotations"

    id = Column(Integer, primary_key=True, index=True)
    
    # 🔥 FASE 1: Aislamiento y Auditoría
    negocio_id = Column(Integer, ForeignKey("negocios.id", ondelete="CASCADE"), nullable=False)
    creado_por_usuario_id = Column(Integer, ForeignKey("usuarios.id"), nullable=False)
    
    client_id = Column(Integer, ForeignKey("clientes.id"), nullable=True)
    client_name = Column(String(150), nullable=True) 
    institution_name = Column(String(200), nullable=True)
    grade_level = Column(String(100), nullable=True)
    notas = Column(Text, nullable=True)
    
    total_amount = Column(Float, default=0.0)
    total_savings = Column(Float, default=0.0)
    
    status = Column(String(50), default=QuotationStatus.PENDING.value)
    type = Column(String(50), default=QuotationType.MANUAL.value)
    is_template = Column(Boolean, default=False)
    clone_source_id = Column(Integer, nullable=True)
    valid_until = Column(Date, nullable=True)
    
    source_image_url = Column(Text, nullable=True)
    original_text_dump = Column(Text, nullable=True)

    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relaciones
    negocio = relationship("Business", back_populates="cotizaciones")
    creador = relationship("User", foreign_keys=[creado_por_usuario_id])
    items = relationship("SmartQuotationItem", back_populates="quotation", cascade="all, delete-orphan")
    cliente = relationship("Cliente", back_populates="cotizaciones")
    venta = relationship("Venta", back_populates="cotizacion", uselist=False)

class SmartQuotationItem(Base):
    __tablename__ = "smart_quotation_items"
    id = Column(Integer, primary_key=True, index=True)
    quotation_id = Column(Integer, ForeignKey("smart_quotations.id"), nullable=False)
    product_id = Column(Integer, ForeignKey("productos.id"), nullable=True)
    presentation_id = Column(Integer, ForeignKey("presentaciones_producto.id"), nullable=True)
    
    quantity = Column(Integer, default=1)
    unit_price_applied = Column(Numeric(10, 2), nullable=False) 
    original_unit_price = Column(Numeric(10, 2), nullable=False) 
    
    product_name = Column(String(255), nullable=True)
    brand_name = Column(String(100), nullable=True)
    specific_name = Column(String(150), nullable=True)
    sales_unit = Column(String(50), nullable=True)
    
    original_text = Column(String(255), nullable=True)
    is_manual_price = Column(Boolean, default=False)
    is_available = Column(Boolean, default=True)

    quotation = relationship("SmartQuotation", back_populates="items")
    product = relationship("Product")
    presentation = relationship("ProductPresentation")

    @property
    def image_url(self):
        if self.presentation and self.presentation.image_url:
            return self.presentation.image_url
        if self.product and self.product.imagen_url:
            return self.product.imagen_url
        return None