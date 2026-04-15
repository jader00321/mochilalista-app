# backend/app/db/session.py
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.core.config import settings

# Creamos el motor de conexión
engine = create_engine(settings.DATABASE_URL)

# Creamos la fábrica de sesiones. Cada petición del usuario tendrá su propia sesión.
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)