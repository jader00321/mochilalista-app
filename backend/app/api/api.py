from fastapi import APIRouter
from app.api.v1.endpoints import (
    products, 
    users, 
    login, 
    brands,      
    categories,  
    providers,    
    ai_scanner,       
    inventory_matcher, 
    inventory_batch,   
    barcode,
    upload, 
    school_lists,
    sales, 
    clientes,
    smart_quotations,
    business,
    notifications,
    invoices,
    business_management, # 🔥 FASE 2: Nuevo
    auth_context,        # 🔥 FASE 2: Nuevo
    community_quotes     # 🔥 FASE 2: Nuevo
)
from app.api.v1.endpoints import smart_inventory_matcher

api_router = APIRouter()

# --- Rutas de Autenticación y Contexto ---
api_router.include_router(login.router, prefix="/login", tags=["Login"])
api_router.include_router(users.router, prefix="/users", tags=["Usuarios"])
api_router.include_router(auth_context.router, prefix="/auth", tags=["Autenticación y Contexto"]) # 🔥 NUEVO

# --- Gestión del Negocio y Equipo ---
api_router.include_router(business.router, prefix="/business", tags=["Business"])
api_router.include_router(business_management.router, prefix="/business-management", tags=["Business Management"]) # 🔥 NUEVO

# --- Rutas de Utilidad ---
api_router.include_router(upload.router, prefix="/upload", tags=["Subida de Imágenes"])
api_router.include_router(notifications.router, prefix="/notifications", tags=["Notificaciones"]) 

# --- Rutas de Inventario (CRUDs) ---
api_router.include_router(products.router, prefix="/products", tags=["Productos"])
api_router.include_router(brands.router, prefix="/brands", tags=["Gestión de Marcas"])
api_router.include_router(categories.router, prefix="/categories", tags=["Gestión de Categorías"])
api_router.include_router(providers.router, prefix="/providers", tags=["Gestión de Proveedores"])
api_router.include_router(invoices.router, prefix="/invoices", tags=["Dashboard de Facturas"])

# --- Rutas de Escáner IA ---
api_router.include_router(ai_scanner.router, prefix="/scanner/ai", tags=["Scanner"])
api_router.include_router(inventory_matcher.router, prefix="/scanner/match", tags=["Scanner"])
api_router.include_router(inventory_batch.router, prefix="/scanner/batch", tags=["Scanner"])
api_router.include_router(barcode.router, prefix="/scanner/barcode", tags=["Scanner"])
api_router.include_router(school_lists.router, prefix="/school-lists", tags=["Listas Escolares IA"])

# --- Rutas de Ventas, CRM y Cotizaciones ---
api_router.include_router(sales.router, prefix="/sales", tags=["Ventas"])
api_router.include_router(clientes.router, prefix="/clientes", tags=["Clientes CRM"])
api_router.include_router(smart_quotations.router, prefix="/smart-quotations", tags=["Cotizaciones Inteligentes"])
api_router.include_router(community_quotes.router, prefix="/community-quotes", tags=["Cotizaciones de Comunidad"]) # 🔥 NUEVO

api_router.include_router(
    smart_inventory_matcher.router, 
    prefix="/smart-inventory-matcher",  
    tags=["Smart Matcher"]
)