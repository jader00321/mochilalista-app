# 🏛️ Mochilalista App - Arquitectura y Documentación Técnica (v4.0)

Esta documentación describe a profundidad la arquitectura de la aplicación Mochilalista, estructurada con un diseño **Offline-First**, arquitectura por funcionalidades (*Feature-Driven*) y principios de alta cohesión.

---

## 1. Patrón Arquitectónico: Feature-Driven + Layered Architecture

El proyecto se estructura dividiendo la base de código por funcionalidades (features) en la capa de presentación y dominio, manteniendo los servicios (data) en una capa Core de apoyo.

```mermaid
graph TD
    subgraph UI Layer [Capa de Presentación (Flutter UI)]
        Widgets
        Screens
        Modals
    end

    subgraph State Layer [Capa de Estado (Provider)]
        CP[CatalogProvider]
        SP[ScannerProvider]
        SQP[SmartQuotationProvider]
        AP[AnalyticsProvider]
    end

    subgraph Service Layer [Capa Core & Servicios]
        MS[MasterDataService]
        AI[AIExtractionService]
        FS[File & PDF Service]
        Auth[AuthService]
    end

    subgraph Data Layer [Capa de Datos]
        DB[(SQLite Local DB)]
        Prefs[SharedPreferences]
        FileSystem[Local File System]
    end

    UI Layer -->|Consume y Despacha| State Layer
    State Layer -->|Delega lógica pesada| Service Layer
    Service Layer -->|Lee/Escribe| Data Layer
```

## 2. Gestión del Estado Central (Providers)

Mochilalista utiliza `provider` para la inyección de dependencias y reactividad. La jerarquía principal en `main.dart` es:

* **`DatabaseProvider`**: Inicializa la base de datos `sqflite` (instancia singleton). Bloquea la UI en un "Loading Splash" hasta que el motor de BD esté listo.
* **`AuthProvider`**: Valida perfiles, gestiona el inicio de sesión por PIN y mantiene en memoria el `business_id` (Negocio activo).
* **`CatalogProvider` & `InventoryProvider`**: Agrupan los datos masivos de productos, presentaciones, marcas y categorías. Utilizan cachés internas (`MasterDataCache`) para acelerar búsquedas y listados.
* **`SmartQuotationProvider` & `ScannerProvider`**: Módulos efímeros/especializados. El escáner mantiene el estado en progreso de la Inteligencia artificial y el `SmartQuotation` orquesta el carrito de compra y generación de la factura.

## 3. Modelo de Datos Entidad-Relación (ERD)

La base de datos (SQLite) se estructura garantizando el aislamiento por negocio (`business_id`), permitiendo múltiples negocios (multitenant) en un mismo dispositivo.

```mermaid
erDiagram
    BUSINESS {
        int id PK
        string name
        string ruc
        string default_currency
        string whatsapp
    }
    USER {
        int id PK
        string pin
        int active_business_id FK
    }
    PRODUCT {
        int id PK
        int business_id FK
        string sku
        string title
        int brand_id FK
        int category_id FK
        string image_path
    }
    PRODUCT_PRESENTATION {
        int id PK
        int product_id FK
        string unit_name
        float base_price
        float stock
    }
    SALE {
        int id PK
        int business_id FK
        string client_name
        float total_amount
        string payment_status
        datetime created_at
        string pdf_path
    }
    SALE_ITEM {
        int id PK
        int sale_id FK
        int presentation_id FK
        float quantity
        float unit_price
        float subtotal
    }

    BUSINESS ||--o{ PRODUCT : has
    PRODUCT ||--|{ PRODUCT_PRESENTATION : contains
    BUSINESS ||--o{ SALE : generates
    SALE ||--|{ SALE_ITEM : includes
    PRODUCT_PRESENTATION ||--o{ SALE_ITEM : referenced_by
    USER }o--|| BUSINESS : belongs_to
```

## 4. Motor de IA Inteligente: Secuencia de Extracción (Smart Scanner)

El corazón innovador de la app es su capacidad para procesar comprobantes sin necesidad de backend propio.

```mermaid
sequenceDiagram
    autonumber
    actor U as Usuario (App)
    participant UI as Flutter UI
    participant SP as ScannerProvider
    participant AI as AIExtractionService
    participant Gemini as Google Gemini AI (HTTPS)
    participant DB as SQLite / Catalog

    U->>UI: Captura/Selecciona Foto de Factura
    UI->>SP: processImage(File)
    activate SP
    SP->>UI: Notifica estado: "Iniciando motor AI..."
    SP->>AI: analyzeInvoiceWithAI(File, API_KEY)
    activate AI
    AI->>Gemini: Request (Prompt optimizado + Base64 Image)
    note right of AI: El prompt fuerza salida JSON estricta<br>con items, cantidades y descripciones.
    Gemini-->>AI: Response JSON Text
    AI->>AI: Parseo seguro a InvoiceModel
    AI-->>SP: List<InvoiceItem>
    deactivate AI
    
    SP->>UI: Notifica estado: "Realizando Matching de Inventario..."
    SP->>DB: Fetch All Products (Cache local)
    DB-->>SP: Productos
    SP->>SP: string_similarity (Jaro-Winkler)
    note left of SP: Cruza el texto de la IA<br>con los títulos de SQLite.
    
    SP-->>UI: Devuelve lista de matches
    deactivate SP
    UI-->>U: Renderiza pantalla de Aprobación/Edición
```

## 5. Diseño y Estándares de Código

* **Importaciones Absolutas:** En la v4.0, todos los archivos del directorio `lib` implementan estíctamente importaciones con sintaxis `package:app_movil/...`. Esto evita colisiones del analizador de Dart y facilita la trazabilidad.
* **Componentes UI Reutilizables:** Se emplea una carpeta `core/widgets/` para tarjetas, diálogos y botones estándar que comparten la paleta visual (vibrante, moderna) de la aplicación, garantizando una UX consistente (ej: `ProductPresentationCard`, `CustomBottomSheets`).
* **Seguridad (DotEnv):** Toda credencial sensible viaja a través del archivo `.env` que se excluye del control de versiones.

## 6. Módulo Analytics (Reporting)

Mochilalista genera métricas locales sin necesidad de telemetría remota.

```mermaid
graph LR
    DB[(SQLite)] -->|SQL Queries Optimizadas| DAO(Sale & Inventory DAO)
    DAO --> AnalyticsProvider
    AnalyticsProvider -->|Calcula| KPI1[Top Clients]
    AnalyticsProvider -->|Calcula| KPI2[Dead Stock]
    AnalyticsProvider -->|Calcula| KPI3[Restock Alerts]
    KPI1 --> UI(Dashboard UI)
    KPI2 --> UI
    KPI3 --> UI
```
