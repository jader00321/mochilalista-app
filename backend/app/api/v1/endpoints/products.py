from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import or_
from app.api import deps
from pydantic import BaseModel

from app.models.product import Product
from app.models.product_presentation import ProductPresentation
from app.models.category import Category
from app.models.brand import Brand

from app.schemas.product import (
    ProductResponse, 
    ProductCreateFull, 
    ProductUpdate, 
    ProductPresentationUpdate, 
    ProductPresentationCreate,
    ProductPresentationResponse
)

router = APIRouter()

class CategoryResponse(BaseModel):
    id: int
    nombre: str
    class Config:
        from_attributes = True

class InventoryFlatResponse(BaseModel):
    product: ProductResponse
    presentation: ProductPresentationResponse

@router.get("/categories", response_model=List[CategoryResponse])
def read_categories(db: Session = Depends(deps.get_db), solo_activos: bool = True):
    query = db.query(Category)
    if solo_activos:
        query = query.filter(Category.activo == True)
    return query.order_by(Category.nombre.asc()).all()

@router.get("/", response_model=List[InventoryFlatResponse])
def read_inventory(
    db: Session = Depends(deps.get_db),
    skip: int = 0,
    limit: int = 20, 
    q: Optional[str] = None,
    category_ids: Optional[List[int]] = Query(None),
    brand_ids: Optional[List[int]] = Query(None),
    provider_ids: Optional[List[int]] = Query(None),
    min_price: Optional[float] = None,
    max_price: Optional[float] = None,
    min_stock: Optional[int] = None,
    max_stock: Optional[int] = None,
    estado: Optional[str] = None,       
    has_offer: Optional[bool] = None,   
    only_defaults: Optional[bool] = None,
    negocio_id: int = Depends(deps.get_current_business_id) 
):
    query = db.query(ProductPresentation)\
        .join(Product, ProductPresentation.producto_id == Product.id)\
        .outerjoin(Brand, Product.marca_id == Brand.id)\
        .filter(Product.negocio_id == negocio_id)
    
    if q:
        search_term = f"%{q}%"
        query = query.filter(
            or_(
                Product.nombre.ilike(search_term),
                Brand.nombre.ilike(search_term),
                ProductPresentation.ump_compra.ilike(search_term),
                ProductPresentation.nombre_especifico.ilike(search_term),
                Product.codigo_barras.ilike(search_term),
                ProductPresentation.codigo_barras.ilike(search_term)
            )
        )

    if category_ids: query = query.filter(Product.categoria_id.in_(category_ids))
    if brand_ids: query = query.filter(Product.marca_id.in_(brand_ids))
    if provider_ids:
        query = query.filter(or_(ProductPresentation.proveedor_id.in_(provider_ids)))
    if min_price is not None: query = query.filter(ProductPresentation.precio_venta_final >= min_price)
    if max_price is not None: query = query.filter(ProductPresentation.precio_venta_final <= max_price)
    if min_stock is not None: query = query.filter(ProductPresentation.stock_actual >= min_stock)
    if max_stock is not None: query = query.filter(ProductPresentation.stock_actual <= max_stock)
    if estado: query = query.filter(ProductPresentation.estado == estado)
    if has_offer: query = query.filter(ProductPresentation.precio_oferta.isnot(None), ProductPresentation.precio_oferta > 0)
    if only_defaults: query = query.filter(ProductPresentation.es_default == True)

    presentations = query.order_by(ProductPresentation.id.desc()).offset(skip).limit(limit).all()
    
    results = []
    for pres in presentations:
        results.append({"product": pres.producto, "presentation": pres})
    return results

@router.post("/full", response_model=bool)
def create_product_full(
    *,
    db: Session = Depends(deps.get_db),
    product_in: ProductCreateFull,
    negocio_id: int = Depends(deps.get_current_business_id)
):
    # 🔥 PROTECCIÓN DE CÓDIGO DE BARRAS PADRE
    if product_in.codigo_barras:
        existente = db.query(Product).filter(Product.codigo_barras == product_in.codigo_barras, Product.negocio_id == negocio_id).first()
        if existente: raise HTTPException(status_code=400, detail="El código de barras ya existe en otro producto.")

    product_data = product_in.model_dump()
    presentaciones_data = product_data.pop("presentaciones", [])
    
    valid_columns = Product.__table__.columns.keys()
    filtered_product_data = {key: value for key, value in product_data.items() if key in valid_columns}

    db_product = Product(**filtered_product_data, negocio_id=negocio_id)
    db.add(db_product)
    db.flush() 

    if not presentaciones_data:
        # 🔥 Aseguramos una presentación por defecto
        default_pres = ProductPresentation(
            producto_id=db_product.id,
            unidad_venta="Unidad",
            unidades_por_venta=1,
            precio_venta_final=0.0,
            es_default=True,
            stock_actual=0,
            estado='privado'
        )
        db.add(default_pres)
    else:
        # 🔥 Forzamos al menos a que una sea default si el usuario no lo envió
        tiene_default = any(p.get('es_default') for p in presentaciones_data)
        valid_pres_keys = ProductPresentation.__table__.columns.keys()
        
        for i, pres_data in enumerate(presentaciones_data):
            if i == 0 and not tiene_default: pres_data['es_default'] = True
            
            filtered_pres_data = {k: v for k, v in pres_data.items() if k in valid_pres_keys and k != 'id'}
            nueva_pres = ProductPresentation(**filtered_pres_data, producto_id=db_product.id)
            db.add(nueva_pres)

    db.commit()
    return True

@router.patch("/{product_id}", response_model=ProductResponse)
def update_product(
    product_id: int,
    product_in: ProductUpdate,
    db: Session = Depends(deps.get_db),
    negocio_id: int = Depends(deps.get_current_business_id)
):
    product = db.query(Product).filter(Product.id == product_id, Product.negocio_id == negocio_id).first()
    if not product: raise HTTPException(status_code=404, detail="Producto no encontrado")

    update_data = product_in.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        if hasattr(product, field): setattr(product, field, value)

    db.add(product)
    db.commit()
    db.refresh(product)
    return product

@router.patch("/presentations/{presentation_id}", response_model=bool)
def update_presentation(
    presentation_id: int,
    presentation_in: ProductPresentationUpdate,
    db: Session = Depends(deps.get_db),
    negocio_id: int = Depends(deps.get_current_business_id)
):
    presentation = db.query(ProductPresentation).join(Product).filter(
        ProductPresentation.id == presentation_id,
        Product.negocio_id == negocio_id
    ).first()

    if not presentation: raise HTTPException(status_code=404, detail="Presentación no encontrada")

    update_data = presentation_in.model_dump(exclude_unset=True)
    
    # 🔥 MOTOR MATEMÁTICO DE PRECIOS
    costo = update_data.get('costo_unitario_calculado', float(presentation.costo_unitario_calculado or 0))
    margen = update_data.get('factor_ganancia_venta', float(presentation.factor_ganancia_venta or 1))
    
    if 'costo_unitario_calculado' in update_data or 'factor_ganancia_venta' in update_data:
        update_data['precio_venta_final'] = round(costo * margen, 2)

    # Protección de Ofertas
    if 'precio_oferta' in update_data:
        valor = update_data['precio_oferta']
        precio_real = update_data.get('precio_venta_final', float(presentation.precio_venta_final))
        if valor is None or valor <= 0 or valor >= precio_real:
            presentation.precio_oferta = None
            presentation.tipo_descuento = None
            presentation.valor_descuento = None
            update_data.pop('precio_oferta', None)
    
    for field, value in update_data.items():
        if hasattr(presentation, field): setattr(presentation, field, value)
    
    db.add(presentation)
    db.commit()
    return True

@router.post("/{product_id}/presentations", response_model=bool)
def create_presentation_for_product(
    product_id: int,
    presentation_in: ProductPresentationCreate,
    db: Session = Depends(deps.get_db),
    negocio_id: int = Depends(deps.get_current_business_id)
):
    product = db.query(Product).filter(Product.id == product_id, Product.negocio_id == negocio_id).first()
    if not product: raise HTTPException(status_code=404, detail="Producto no encontrado")

    pres_data = presentation_in.model_dump()
    valid_pres_keys = ProductPresentation.__table__.columns.keys()
    filtered_pres_data = {k: v for k, v in pres_data.items() if k in valid_pres_keys and k != 'id'}

    new_pres = ProductPresentation(**filtered_pres_data, producto_id=product.id)
    db.add(new_pres)
    db.commit()
    return True

@router.delete("/presentations/{presentation_id}", response_model=bool)
def delete_presentation(
    presentation_id: int,
    db: Session = Depends(deps.get_db),
    negocio_id: int = Depends(deps.get_current_business_id)
):
    presentation = db.query(ProductPresentation).join(Product).filter(
        ProductPresentation.id == presentation_id,
        Product.negocio_id == negocio_id
    ).first()

    if not presentation: raise HTTPException(status_code=404, detail="Presentación no encontrada")
    
    pid = presentation.producto_id
    count = db.query(ProductPresentation).filter(ProductPresentation.producto_id == pid).count()
    if count <= 1: raise HTTPException(status_code=400, detail="No puedes eliminar la única presentación.")

    db.delete(presentation)
    db.commit()
    return True

@router.get("/{product_id}", response_model=ProductResponse)
def read_product_detail(
    product_id: int,
    db: Session = Depends(deps.get_db),
    negocio_id: int = Depends(deps.get_current_business_id)
):
    product = db.query(Product).filter(
        Product.id == product_id, 
        Product.negocio_id == negocio_id
    ).first()

    if not product:
        raise HTTPException(status_code=404, detail="Producto no encontrado")
    
    return product