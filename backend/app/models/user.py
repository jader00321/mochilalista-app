from sqlalchemy import Column, Integer, String, Boolean, DateTime
from sqlalchemy.orm import relationship
from datetime import datetime
from app.db.base_class import Base

class User(Base):
    __tablename__ = "usuarios"

    id = Column(Integer, primary_key=True, index=True)
    
    # 🔥 FASE 1: Código único inmutable para el Radar
    codigo_unico_usuario = Column(String(20), unique=True, index=True, nullable=True)
    
    nombre_completo = Column(String(100))
    email = Column(String(100), unique=True, index=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    telefono = Column(String(20))
    activo = Column(Boolean(), default=True)
    fecha_creacion = Column(DateTime, default=datetime.utcnow)

    # ==========================================
    # RELACIONES MULTI-TENANT (SaaS)
    # ==========================================
    # Negocios que yo creé (Dueño original)
    negocios_creados = relationship("Business", back_populates="dueno", foreign_keys="Business.id_dueno")
    
    # Negocios a los que pertenezco (Dueño, Trabajador o Cliente Comunidad)
    negocios_asociados = relationship("NegocioUsuario", back_populates="usuario", cascade="all, delete-orphan")

    # Si un negocio me registra como cliente en su CRM local (Puente de Identidad)
    perfiles_cliente_crm = relationship("Cliente", back_populates="usuario_vinculado", foreign_keys="Cliente.usuario_vinculado_id")

    notificaciones = relationship("Notification", back_populates="usuario", cascade="all, delete-orphan")