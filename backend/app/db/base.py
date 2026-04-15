from app.db.base_class import Base

# 1. Usuarios y Control de Acceso Multi-Tenant
from app.models.user import User
from app.models.business import Business
from app.models.negocio_usuario import NegocioUsuario  # 🔥 FASE 1
from app.models.codigo_acceso import CodigoAccesoNegocio # 🔥 FASE 1

# 2. Inventario
from app.models.category import Category
from app.models.provider import Provider
from app.models.invoice import Invoice
from app.models.product import Product
from app.models.product_presentation import ProductPresentation
from app.models.brand import Brand

# 3. Cotización Inteligente
from app.models.smart_quotation import SmartQuotation, SmartQuotationItem

# 4. CRM (Clientes, Ventas y Pagos)
from app.models.cliente import Cliente
from app.models.venta import Venta, Cuota # Agregada cuota
from app.models.pago import Pago

# 5. Sistema
from app.models.notification import Notification