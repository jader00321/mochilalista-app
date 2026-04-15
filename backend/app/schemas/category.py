from typing import Optional
from pydantic import BaseModel

class CategoryBase(BaseModel):
    nombre: str
    descripcion: Optional[str] = None
    activo: bool = True

class CategoryCreate(CategoryBase):
    pass

class CategoryUpdate(BaseModel):
    nombre: Optional[str] = None
    descripcion: Optional[str] = None
    activo: Optional[bool] = None

class CategoryResponse(CategoryBase):
    id: int
    products_count: int = 0 # <--- NUEVO CAMPO

    class Config:
        from_attributes = True