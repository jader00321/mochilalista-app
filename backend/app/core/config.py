import os
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    PROJECT_NAME: str = "MochilaLista API"
    API_V1_STR: str = "/api/v1"
    
    # --- SEGURIDAD Y JWT ---
    SECRET_KEY: str = os.getenv("SECRET_KEY", "ESTA_ES_UNA_CLAVE_SUPER_SECRETA_CAMBIALA_EN_PRODUCCION")
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7 # 7 Días

    # --- BASE DE DATOS (DINÁMICA) ---
    POSTGRES_USER: str = os.getenv("DB_USER", "postgres")
    POSTGRES_PASSWORD: str = os.getenv("DB_PASSWORD", "")
    POSTGRES_DB: str = os.getenv("DB_NAME", "mochilalista_bd")
    POSTGRES_HOST: str = os.getenv("DB_HOST", "db") 

    @property
    def DATABASE_URL(self) -> str:
        return f"postgresql://{self.POSTGRES_USER}:{self.POSTGRES_PASSWORD}@{self.POSTGRES_HOST}:5432/{self.POSTGRES_DB}"
    
    # --- GOOGLE AI ---
    GOOGLE_API_KEY: str = os.getenv("GOOGLE_API_KEY", "")

    # --- CLOUDINARY (NUEVO) ---
    CLOUDINARY_CLOUD_NAME: str = os.getenv("CLOUDINARY_CLOUD_NAME", "")
    CLOUDINARY_API_KEY: str = os.getenv("CLOUDINARY_API_KEY", "")
    CLOUDINARY_API_SECRET: str = os.getenv("CLOUDINARY_API_SECRET", "")

    class Config:
        case_sensitive = True
        env_file = ".env"

settings = Settings()