from typing import List, Any, Optional
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.api import deps
from app.models.provider import Provider
from app.models.product import Product
from app.models.product_presentation import ProductPresentation
from app.schemas.provider import ProviderCreate, ProviderUpdate, ProviderResponse

router = APIRouter()

@router.get("/", response_model=List[ProviderResponse])
def read_providers(
    db: Session = Depends(deps.get_db),
    skip: int = 0,
    limit: int = 100,
    solo_activos: bool = False,
    q: Optional[str] = None, 
    negocio_id: int = Depends(deps.get_current_business_id)
):
    query = db.query(Provider).filter(Provider.negocio_id == negocio_id)
    
    if q:
        query = query.filter(Provider.nombre_empresa.ilike(f"%{q}%"))

    if solo_activos:
        query = query.filter(Provider.activo == True)
    
    providers = query.order_by(Provider.nombre_empresa.asc()).offset(skip).limit(limit).all()

    # 🔥 CORRECCIÓN DEL ERROR 500 🔥
    # Los proveedores ahora están vinculados EXCLUSIVAMENTE a las presentaciones.
    for prov in providers:
        # Contamos cuántas presentaciones tienen este proveedor
        count_presentaciones = db.query(ProductPresentation).filter(ProductPresentation.proveedor_id == prov.id).count()
        # Asignamos el valor al esquema de respuesta
        setattr(prov, 'products_count', count_presentaciones)

    return providers

@router.post("/", response_model=ProviderResponse)
def create_provider(
    *,
    db: Session = Depends(deps.get_db),
    provider_in: ProviderCreate,
    negocio_id: int = Depends(deps.get_current_business_id)
):
    data = provider_in.model_dump()
    provider = Provider(
        **data,
        negocio_id=negocio_id,
        fecha_creacion=datetime.now()
    )
    db.add(provider)
    db.commit()
    db.refresh(provider)
    return provider

@router.patch("/{provider_id}", response_model=ProviderResponse)
def update_provider(
    *,
    db: Session = Depends(deps.get_db),
    provider_id: int,
    provider_in: ProviderUpdate,
    negocio_id: int = Depends(deps.get_current_business_id)
):
    provider = db.query(Provider).filter(Provider.id == provider_id, Provider.negocio_id == negocio_id).first()
    if not provider:
        raise HTTPException(status_code=404, detail="Proveedor no encontrado")
    
    update_data = provider_in.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(provider, field, value)
        
    db.add(provider)
    db.commit()
    db.refresh(provider)
    return provider

@router.delete("/{provider_id}", response_model=bool)
def delete_provider(
    *,
    db: Session = Depends(deps.get_db),
    provider_id: int,
    negocio_id: int = Depends(deps.get_current_business_id)
):
    provider = db.query(Provider).filter(Provider.id == provider_id, Provider.negocio_id == negocio_id).first()
    if not provider:
        raise HTTPException(status_code=404, detail="Proveedor no encontrado")
    
    variant_count = db.query(ProductPresentation).filter(ProductPresentation.proveedor_id == provider_id).count()
    
    if variant_count > 0:
        raise HTTPException(
            status_code=400, 
            detail=f"No se puede eliminar: El proveedor tiene {variant_count} items asociados. Suspéndalo en su lugar."
        )
    
    db.delete(provider)
    db.commit()
    return True