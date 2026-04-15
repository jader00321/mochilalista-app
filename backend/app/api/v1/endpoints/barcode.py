from typing import Optional
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session, joinedload
from app.api import deps
from app.models.product import Product
from app.models.product_presentation import ProductPresentation
from app.schemas.product import ProductResponse, ProductPresentationResponse
from pydantic import BaseModel

router = APIRouter()

class BarcodeSearchResult(BaseModel):
    found: bool
    product: Optional[ProductResponse] = None
    presentation: Optional[ProductPresentationResponse] = None

@router.get("/search", response_model=BarcodeSearchResult)
def search_by_barcode(
    code: str,
    db: Session = Depends(deps.get_db),
    negocio_id: int = Depends(deps.get_current_business_id)
):
    """
    Busca un producto por código de barras.
    Prioridad 1: Código exacto en una Presentación (Hijo).
    Prioridad 2: Código exacto en el Producto (Padre).
    """
    
    # 1. Búsqueda en Presentaciones (Hijo)
    # Usamos joinedload para traer los datos del Padre en la misma consulta (Optimización SQL)
    pres_match = db.query(ProductPresentation)\
        .options(joinedload(ProductPresentation.producto))\
        .join(Product)\
        .filter(
            Product.negocio_id == negocio_id,
            ProductPresentation.codigo_barras == code
        ).first()

    if pres_match:
        return BarcodeSearchResult(
            found=True,
            product=pres_match.producto,
            presentation=pres_match
        )

    # 2. Búsqueda en Producto Padre
    # Si escanean el código del empaque master, devolvemos la presentación por defecto (generalmente la Unidad)
    prod_match = db.query(Product)\
        .options(joinedload(Product.presentaciones))\
        .filter(
            Product.negocio_id == negocio_id,
            Product.codigo_barras == code
        ).first()

    if prod_match:
        # Buscamos la presentación default en memoria (ya la trajimos con joinedload)
        default_pres = next((p for p in prod_match.presentaciones if p.es_default), None)
        
        # Si no tiene default (raro), devolvemos la primera que encuentre
        if not default_pres and prod_match.presentaciones:
            default_pres = prod_match.presentaciones[0]

        return BarcodeSearchResult(
            found=True,
            product=prod_match,
            presentation=default_pres
        )

    # 3. No encontrado
    return BarcodeSearchResult(found=False)