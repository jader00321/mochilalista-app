from typing import List, Any
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.api import deps
from app.models.category import Category
from app.models.product import Product 
from app.schemas.category import CategoryCreate, CategoryUpdate, CategoryResponse

router = APIRouter()

@router.get("/", response_model=List[CategoryResponse])
def read_categories(
    db: Session = Depends(deps.get_db),
    skip: int = 0, limit: int = 100, solo_activos: bool = False,
    negocio_id: int = Depends(deps.get_current_business_id) # 🔥 Aislamiento
):
    query = db.query(Category).filter(Category.negocio_id == negocio_id)
    if solo_activos: query = query.filter(Category.activo == True)
    
    categories = query.order_by(Category.nombre.asc()).offset(skip).limit(limit).all()
    
    for cat in categories:
        count = db.query(Product).filter(Product.categoria_id == cat.id, Product.negocio_id == negocio_id).count()
        setattr(cat, 'products_count', count)
        
    return categories

@router.post("/", response_model=CategoryResponse)
def create_category(
    category_in: CategoryCreate,
    db: Session = Depends(deps.get_db),
    negocio_id: int = Depends(deps.get_current_business_id) # 🔥 Aislamiento
):
    category = Category(**category_in.model_dump(), negocio_id=negocio_id)
    db.add(category)
    db.commit()
    db.refresh(category)
    return category

@router.patch("/{category_id}", response_model=CategoryResponse)
def update_category(
    category_id: int, category_in: CategoryUpdate,
    db: Session = Depends(deps.get_db),
    negocio_id: int = Depends(deps.get_current_business_id) # 🔥 Aislamiento
):
    category = db.query(Category).filter(Category.id == category_id, Category.negocio_id == negocio_id).first()
    if not category: raise HTTPException(status_code=404, detail="Categoría no encontrada")
    
    update_data = category_in.model_dump(exclude_unset=True)
    for field, value in update_data.items(): setattr(category, field, value)
        
    db.commit()
    db.refresh(category)
    return category

@router.delete("/{category_id}", response_model=bool)
def delete_category(
    category_id: int,
    db: Session = Depends(deps.get_db),
    negocio_id: int = Depends(deps.get_current_business_id) # 🔥 Aislamiento
):
    category = db.query(Category).filter(Category.id == category_id, Category.negocio_id == negocio_id).first()
    if not category: raise HTTPException(status_code=404, detail="Categoría no encontrada")
    
    products_count = db.query(Product).filter(Product.categoria_id == category_id).count()
    if products_count > 0:
        raise HTTPException(
            status_code=400, 
            detail=f"No se puede eliminar: Esta categoría está asociada a {products_count} productos. Suspéndala."
        )

    db.delete(category)
    db.commit()
    return True