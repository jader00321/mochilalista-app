from typing import Optional
from pydantic import BaseModel

class BrandBase(BaseModel):
    nombre: str
    imagen_url: Optional[str] = None
    activo: bool = True

class BrandCreate(BrandBase):
    pass

class BrandUpdate(BaseModel):
    nombre: Optional[str] = None
    imagen_url: Optional[str] = None
    activo: Optional[bool] = None

class BrandResponse(BrandBase):
    id: int
    products_count: int = 0 # <--- NUEVO CAMPO

    class Config:
        from_attributes = True