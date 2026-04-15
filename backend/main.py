import os
import time
from fastapi import FastAPI
from sqlalchemy.exc import OperationalError # 🔥 Importamos el error para atraparlo
from app.api.api import api_router
from app.core.config import settings
from app.db import base 
from app.db.session import engine 

# 🔥 BARRERA 2: Lógica de reintentos para la conexión a la Base de Datos
MAX_RETRIES = 5
RETRY_DELAY = 3

for attempt in range(MAX_RETRIES):
    try:
        print(f"Intentando conectar a la base de datos... (Intento {attempt + 1}/{MAX_RETRIES})")
        base.Base.metadata.create_all(bind=engine)
        print("¡Conexión a la base de datos establecida y tablas creadas!")
        break
    except OperationalError as e:
        if attempt < MAX_RETRIES - 1:
            print(f"La base de datos aún no está lista. Reintentando en {RETRY_DELAY} segundos...")
            time.sleep(RETRY_DELAY)
        else:
            print("Error: No se pudo conectar a la base de datos después de varios intentos.")
            raise e

app = FastAPI(
    title=settings.PROJECT_NAME,
    description="API Backend para MochilaLista - Gestión de útiles escolares (Multi-Tenant)",
    version="2.0.0"
)

from fastapi.middleware.cors import CORSMiddleware

cors_origins_str = os.getenv("CORS_ORIGINS", "http://localhost,http://localhost:8080")
origins = [origin.strip() for origin in cors_origins_str.split(",") if origin.strip()]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins, 
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router, prefix=settings.API_V1_STR)

@app.get("/")
def root():
    return {"message": "Bienvenido a la API de MochilaLista SaaS"}