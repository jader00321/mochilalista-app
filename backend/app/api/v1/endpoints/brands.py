from typing import List, Any
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.api import deps
from app.models.brand import Brand
from app.models.product import Product
from app.schemas.brand import BrandCreate, BrandUpdate, BrandResponse

router = APIRouter()

@router.get("/", response_model=List[BrandResponse])
def read_brands(
    db: Session = Depends(deps.get_db),
    skip: int = 0, limit: int = 100, solo_activos: bool = False,
    negocio_id: int = Depends(deps.get_current_business_id) # 🔥 Aislamiento
):
    query = db.query(Brand).filter(Brand.negocio_id == negocio_id)
    if solo_activos: query = query.filter(Brand.activo == True)
    
    brands = query.order_by(Brand.nombre.asc()).offset(skip).limit(limit).all()

    for brand in brands:
        count = db.query(Product).filter(Product.marca_id == brand.id, Product.negocio_id == negocio_id).count()
        setattr(brand, 'products_count', count)

    return brands

@router.post("/", response_model=BrandResponse)
def create_brand(
    brand_in: BrandCreate,
    db: Session = Depends(deps.get_db),
    negocio_id: int = Depends(deps.get_current_business_id) # 🔥 Aislamiento
):
    brand = Brand(**brand_in.model_dump(), negocio_id=negocio_id)
    db.add(brand)
    db.commit()
    db.refresh(brand)
    return brand

@router.patch("/{brand_id}", response_model=BrandResponse)
def update_brand(
    brand_id: int, brand_in: BrandUpdate,
    db: Session = Depends(deps.get_db),
    negocio_id: int = Depends(deps.get_current_business_id) # 🔥 Aislamiento
):
    brand = db.query(Brand).filter(Brand.id == brand_id, Brand.negocio_id == negocio_id).first()
    if not brand: raise HTTPException(status_code=404, detail="Marca no encontrada")
    
    update_data = brand_in.model_dump(exclude_unset=True)
    for field, value in update_data.items(): setattr(brand, field, value)
        
    db.commit()
    db.refresh(brand)
    return brand

@router.delete("/{brand_id}", response_model=bool)
def delete_brand(
    brand_id: int,
    db: Session = Depends(deps.get_db),
    negocio_id: int = Depends(deps.get_current_business_id) # 🔥 Aislamiento
):
    brand = db.query(Brand).filter(Brand.id == brand_id, Brand.negocio_id == negocio_id).first()
    if not brand: raise HTTPException(status_code=404, detail="Marca no encontrada")
    
    products_count = db.query(Product).filter(Product.marca_id == brand_id).count()
    if products_count > 0:
        raise HTTPException(
            status_code=400, 
            detail=f"No se puede eliminar: Esta marca está asociada a {products_count} productos. Suspéndala."
        )
    
    db.delete(brand)
    db.commit()
    return True