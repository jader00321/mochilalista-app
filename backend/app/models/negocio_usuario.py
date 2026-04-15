from sqlalchemy import Column, Integer, String, ForeignKey
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import relationship
import enum
from app.db.base_class import Base

class RolNegocio(str, enum.Enum):
    DUENO = "dueno"
    TRABAJADOR = "trabajador"
    CLIENTE_COMUNIDAD = "cliente_comunidad"

class EstadoAcceso(str, enum.Enum):
    ACTIVO = "activo"
    SUSPENDIDO = "suspendido"

class NegocioUsuario(Base):
    __tablename__ = "negocio_usuario"

    id = Column(Integer, primary_key=True, index=True)
    usuario_id = Column(Integer, ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False)
    negocio_id = Column(Integer, ForeignKey("negocios.id", ondelete="CASCADE"), nullable=False)
    
    rol_en_negocio = Column(String(50), default=RolNegocio.TRABAJADOR.value, nullable=False)
    
    # Matriz estricta de permisos. Ej: {"can_sell": true, "can_edit_inventory": false}
    permisos = Column(JSONB, nullable=True) 
    
    estado_acceso = Column(String(50), default=EstadoAcceso.ACTIVO.value, nullable=False)

    # Relaciones
    usuario = relationship("User", back_populates="negocios_asociados")
    negocio = relationship("Business", back_populates="usuarios_asociados")