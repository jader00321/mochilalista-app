# 📊 Informe de Análisis - MochilaLista App v2.0
## Resumen Ejecutivo

**Fecha de análisis:** 3 de Agosto de 2026  
**Versión analizada:** Branch `feature/version-offline`  
**Analista:** Antigravity AI

---

## 🎯 ¿Qué es MochilaLista?

MochilaLista es una **plataforma Full-Stack** diseñada para negocios minoristas/mayoristas de papelería y útiles escolares en Perú. Su propósito es digitalizar y automatizar los procesos de:

1. **Gestión de Inventarios** - CRUD completo de productos, presentaciones, categorías, marcas y proveedores
2. **Escaneo IA de Facturas** - Usa Google Gemini para extraer datos de facturas físicas y cargar inventario automáticamente
3. **Cotización Inteligente (Smart Quotation)** - Escanea listas escolares con IA, hace matching con el catálogo local, y genera cotizaciones PDF
4. **CRM de Clientes** - Gestión de clientes, deudas, pagos parciales, cuotas y seguimiento de entregas
5. **Ventas y Checkout** - Sistema de ventas con múltiples métodos de pago, créditos, y control de deudas
6. **Integración WhatsApp** - Envío directo de cotizaciones PDF a clientes vía WhatsApp Business
7. **Backup & Restauración** - Exportación a descargas locales, WhatsApp, y Google Drive

---

## 🏗️ Arquitectura del Proyecto

### Stack Tecnológico

| Capa | Tecnología | Propósito |
|------|-----------|-----------|
| **Frontend Móvil** | Flutter/Dart (SDK ^3.9.0) | App Android/iOS nativa |
| **Base de Datos Local** | SQLite (sqflite) | Almacenamiento offline principal |
| **IA (OCR/Extracción)** | Google Gemini AI (gemini-2.5-flash) | Procesamiento de imágenes directo |
| **Backend (Legacy)** | Python FastAPI + PostgreSQL | API RESTful contenedorizada |
| **Infraestructura** | Docker + Docker Compose | PostgreSQL + pgAdmin + API |

### Métricas del Código

| Componente | Archivos | Líneas estimadas |
|-----------|----------|-----------------|
| **Flutter (lib/)** | 186 archivos `.dart` | ~25,000+ LOC |
| **Backend Python** | 70 archivos `.py` | ~8,000+ LOC |
| **Total** | 256 archivos | ~33,000+ LOC |

---

## 🧭 Estado Actual de la Arquitectura

### Transición Offline-First (En Progreso)

El proyecto se encuentra en una **fase crítica de transición**:

- **ANTES (v1.0):** La app dependía 100% del backend Python (FastAPI + PostgreSQL) para todas las operaciones. La IA corría en el servidor.
- **AHORA (v2.0 - branch `feature/version-offline`):** La app está migrando a un modelo **offline-first** donde:
  - SQLite es la base de datos principal
  - Google Gemini AI se llama directamente desde el celular (sin backend intermediario)
  - El matching de productos se hace localmente con `string_similarity`
  - El backend Python queda como **código legacy** que no se usa activamente desde la app

> ⚠️ **HALLAZGO CRÍTICO:** El backend Python (FastAPI + PostgreSQL + 22 endpoints) sigue en el repositorio y tiene una infraestructura Docker completa, pero **la app móvil ya no lo consume**. Todos los servicios del frontend operan directamente contra SQLite. Esto genera **código muerto** que aumenta la complejidad del proyecto y confunde a quien revisa el código.

---

## 📊 Inventario de Componentes del Frontend

### Estructura de Directorios (lib/)

```
lib/
├── main.dart                     # Entry point + 15 providers registrados
├── config/
│   └── api_constants.dart        # Google API Key + Modelo Gemini
├── database/
│   └── local_db.dart             # Singleton SQLite - 13 tablas, 4 versiones de migración
├── models/ (11 archivos)
│   ├── user_model.dart           # UserModel + BusinessModel
│   ├── product_model.dart        # Product + ProductPresentation (complejo)
│   ├── scanner_models.dart       # AIInvoiceResponse, StagingResponse, MatchResult...
│   └── ... (8 más: brand, category, invoice, notification, provider, workspace, team, crm)
├── providers/ (10 archivos)
│   ├── auth_provider.dart        # Autenticación offline con PIN
│   ├── scanner_provider.dart     # Motor de escaneo IA + matching + batch save (587 líneas)
│   ├── catalog_provider.dart     # Catálogo público + carrito de compras
│   ├── inventory_provider.dart   # Gestión completa de inventario (430 líneas)
│   └── ... (6 más: theme, notification, printer, invoice, team, backup)
├── services/ (5 archivos)
│   ├── auth_service.dart         # CRUD usuarios/negocios en SQLite
│   ├── product_service.dart      # CRUD productos con transacciones
│   ├── master_data_service.dart  # CRUD categorías/marcas/proveedores
│   └── ... (2 más: image_service, local_notification)
├── screens/ (13+ archivos + 4 subdirectorios)
│   ├── home_screen.dart          # Dashboard principal con NavigationBar
│   ├── inventory_screen.dart     # Gestión de inventario con tabs
│   ├── scan_screen.dart          # Escáner de imágenes/cámara
│   ├── catalog/catalog_screen.dart
│   ├── onboarding/ (3 pantallas: lock, onboarding, profile_selection)
│   ├── scanner/ (5 pantallas: barcode, invoice_detail, history, review, staging)
│   └── tabs/ (4 pestañas: products, categories, brands, providers)
├── widgets/ (28+ archivos + 3 subdirectorios)
├── features/
│   ├── profile/ (6 pantallas + 7 widgets)
│   └── smart_quotation/ (complejo)
│       ├── models/ (6 archivos)
│       ├── providers/ (8 archivos)
│       ├── screens/ (13 pantallas + CRM: 3 pantallas)
│       ├── services/ (5 archivos)
│       ├── utils/ (2 archivos: pdf_generator, receipt_manager)
│       └── widgets/ (8 subdirectorios + 3 archivos raíz)
└── utils/ (3 archivos: backup_manager, google_auth_client, hardware_validator)
```

### Resumen de Pantallas por Módulo

| Módulo | Pantallas | Función |
|--------|----------|---------|
| **Onboarding** | 3 | Registro, selección de perfil, pantalla de bloqueo PIN |
| **Home/Dashboard** | 1 | Dashboard con header, banner de cotizaciones, grid de acciones |
| **Inventario** | 5 | Inventario principal, crear/editar/detalle producto, DB inspector |
| **Catálogo** | 1 | Catálogo público con carrito, filtros, búsqueda |
| **Scanner/Factura** | 6 | Escaneo IA, edición de datos IA, staging, review, historial |
| **Smart Quotation** | 14 | Workbench, matching, cotización manual, PDF, WhatsApp, checkout, ventas |
| **CRM Clientes** | 4 | Tracking, detalle cliente, órdenes, detalle financiero |
| **Perfil** | 6 | Perfil usuario, equipo, impresora, backup, mapa, notificaciones |

---

## 🗄️ Base de Datos Local (SQLite)

### Esquema de 13 Tablas

| # | Tabla | Propósito | Relaciones clave |
|---|-------|-----------|-----------------|
| 1 | `usuarios` | Perfiles locales del dueño/equipo | - |
| 2 | `negocios` | Información del negocio (nombre, RUC, logo, moneda) | FK→usuarios |
| 3 | `negocio_usuario` | Relación multi-tenant (rol, permisos) | FK→usuarios, negocios |
| 4 | `codigos_acceso_negocio` | Códigos de invitación para equipo | FK→negocios |
| 5 | `categorias` | Categorías de productos | FK→negocios |
| 6 | `marcas` | Marcas de productos | FK→negocios |
| 7 | `proveedores` | Proveedores del negocio | FK→negocios |
| 8 | `productos` | Productos padre (genéricos) | FK→negocios, categorias, marcas |
| 9 | `presentaciones_producto` | Variantes de producto (precio, stock, proveedor) | FK→productos, proveedores |
| 10 | `facturas_carga` | Facturas escaneadas por IA | FK→negocios, proveedores |
| 11 | `clientes` | CRM de clientes con deuda y saldo | FK→negocios |
| 12 | `smart_quotations` | Cotizaciones inteligentes | FK→negocios, clientes |
| 13 | `smart_quotation_items` | Items de cotización | FK→quotations, productos |
| 14 | `ventas` | Registro de ventas | FK→negocios, clientes, cotizaciones |
| 15 | `venta_items` | Items de venta (v3-v4 migración) | FK→ventas, presentaciones |
| 16 | `cuotas` | Plan de pagos en cuotas | FK→ventas |
| 17 | `pagos` | Registro de pagos parciales/totales | FK→negocios, clientes, ventas |
| 18 | `notificaciones` | Notificaciones del sistema | FK→usuarios, negocios |

### Historial de Migraciones

- **v1→v2:** Columna `moneda` en negocios
- **v2→v3:** Tabla `venta_items` + recálculo de deudas
- **v3→v4:** Campos adicionales en `venta_items` (original_unit_price, brand_name, etc.)

---

## 🔌 Conexión Frontend ↔ Backend

### Estado Actual: **DESCONECTADOS**

El frontend (Flutter) opera 100% offline contra SQLite. El backend Python está presente pero **inactivo**:

- `api_constants.dart` solo contiene la key de Google Gemini - **no hay URL de backend**
- Todos los servicios (`auth_service.dart`, `product_service.dart`, `master_data_service.dart`) hacen queries directas a SQLite
- El paquete `http` está en `pubspec.yaml` pero no se usa en servicios actuales
- El paquete `dio` está en `pubspec.yaml` pero tampoco se usa

> **Conclusión:** El backend Python es código legacy de la v1.0. La app funciona sin él.

---

## 📱 Flujo de Autenticación (Offline-First)

1. **App Inicia** → `AuthProvider.checkInitialState()` busca perfiles en SQLite
2. **Sin Perfiles** → Navega a `ProfileSelectionScreen` (Onboarding)
3. **Con Perfiles** → Verifica `last_active_user_id` en SharedPreferences
4. **Tiene PIN** → Muestra `LockScreen` para autenticación biométrica
5. **Sin PIN** → Directo a `HomeScreen`

> No hay login contra servidor. Todo es local con PIN almacenado en `FlutterSecureStorage`.

---

## 🤖 Motor de Inteligencia Artificial

### Dos flujos de IA independientes:

1. **Escaneo de Facturas** (`scanner_provider.dart`):
   - Captura foto → envía a Gemini con prompt contable detallado
   - Gemini devuelve JSON con proveedor, RUC, fecha, items con UMP/precios
   - Matching local contra SQLite para vincular con catálogo existente
   - Review interactivo → Batch save transaccional

2. **Escaneo de Listas Escolares** (`ai_extraction_service.dart`):
   - Captura foto de lista escolar → envía a Gemini con prompt de digitalización
   - Gemini devuelve JSON con metadata (colegio, alumno, grado) e items
   - Matching inteligente con `string_similarity` contra catálogo del negocio
   - Genera cotización automática → PDF → WhatsApp
