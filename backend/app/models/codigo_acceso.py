from sqlalchemy import Column, Integer, String, ForeignKey, DateTime
from sqlalchemy.orm import relationship
from datetime import datetime
from app.db.base_class import Base

class CodigoAccesoNegocio(Base):
    __tablename__ = "codigos_acceso_negocio"

    id = Column(Integer, primary_key=True, index=True)
    codigo = Column(String(50), unique=True, index=True, nullable=False) # Ej: JOIN-WORK-44X
    
    negocio_id = Column(Integer, ForeignKey("negocios.id", ondelete="CASCADE"), nullable=False)
    creado_por_usuario_id = Column(Integer, ForeignKey("usuarios.id", ondelete="CASCADE"), nullable=False)
    
    rol_a_otorgar = Column(String(50), nullable=False) # 'trabajador' o 'cliente_comunidad'
    
    usos_maximos = Column(Integer, default=1)
    usos_actuales = Column(Integer, default=0)
    
    fecha_creacion = Column(DateTime, default=datetime.utcnow)
    fecha_expiracion = Column(DateTime, nullable=True)

    # Relaciones
    negocio = relationship("Business")
    creador = relationship("User")