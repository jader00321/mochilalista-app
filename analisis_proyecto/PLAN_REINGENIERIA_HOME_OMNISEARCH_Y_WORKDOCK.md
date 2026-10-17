# PLAN MAESTRO: REINGENIERÍA DEL HOME, BUSCADOR OMNICANAL MULTI-PALABRA, GLOBO FLOTANTE DEL WORKDOCK Y HOME STUDIO

**Documento:** `analisis_proyecto/PLAN_REINGENIERIA_HOME_OMNISEARCH_Y_WORKDOCK.md`  
**Fecha:** Octubre 2026  
**Versión:** 2.0 — Planificación Técnica Definitiva Perfeccionada  
**Estado:** Listo para Aprobación y Ejecución  
**Módulos Afectados:**
* `lib/core/screens/home_screen.dart`
* `lib/core/widgets/omni_search_bar.dart`
* `lib/core/widgets/persistent_work_dock.dart`
* `lib/core/widgets/home/dashboard_header.dart`
* `lib/core/widgets/home/smart_action_grid.dart`
* `lib/core/widgets/home/weekly_sales_chart.dart`
* `lib/core/widgets/home/quotation_banner.dart`
* `lib/core/widgets/home/recent_activity_list.dart`
* `lib/features/analytics/widgets/restock_smart_banner.dart`
* `lib/features/scanner/screens/barcode_scanner_screen.dart`
* `lib/features/scanner/widgets/barcode_not_found_dialog.dart` (Nuevo componente)
* `lib/features/catalog/screens/product_create_screen.dart`
* `lib/features/smart_quotation/screens/quotation_detail_screen.dart`

---

## 1. RESUMEN EJECUTIVO Y OBJETIVOS ESTRATÉGICOS

La pantalla de Inicio (`HomeScreen`) es el epicentro neurálgico de MochilaLista. Es lo primero que ve el comerciante al abrir la app o al atender a un cliente en mostrador. Debe combinar **velocidad de respuesta instantánea**, **precisión en la búsqueda local de datos**, **control personalizado de accesos** y una **estética de clase mundial (Mobile Awards)**.

A través de la auditoría técnica exhaustiva en código, se detectaron fallas de diseño, lógica y layout que merman la experiencia:
1. **El Buscador Omnicanal (`omni_search_bar.dart`) falla severamente:** 
   * Las consultas de clientes se rompen en SQLite porque buscan columnas inexistentes (`numero_documento` y `total_deuda` en lugar de `dni_ruc` y `deuda_total`), disparando excepciones que dejaban resultados en 0.
   * La búsqueda de productos exige coincidencia continua estricta (`LIKE '%$term%'`) y excluye marcas y categorías en la cláusula `WHERE`, impidiendo encontrar términos como `"cuaderno stanford"` o `"agua gas 500"`.
   * Falta de normalización real de tildes en SQLite: normalizar en Dart no basta si en la base de datos la columna tiene acento (`'á' != 'a'`).
   * No existe aislamiento `try/catch` entre entidades: si una falla, anula a las demás.
   * Al abrir el buscador con input vacío, muestra contadores vacíos `(0)` en lugar de mostrar registros recientes del negocio.
2. **El botón de escáner en la barra del buscador del Home abre la función equivocada:**
   * En lugar de abrir el lector de código de barras de productos, abre `ScanScreen()`, que es el digitalizador OCR de listas escolares.
   * No existe un flujo de producto no encontrado amigable ni inyección automática en la primera presentación de `ProductCreateScreen`.
3. **El `PersistentWorkDock` satura el espacio inferior, trunca textos y bloquea toques:**
   * Títulos como `"Borrador de Cotización"` y `"Conciliación IA"` se truncan a `"Borrador d..."` y `"Conciliaci..."` en pantallas comunes.
   * Cuando se transforme a modo globo flotante (58x58px), debe tener un área de hit-test acotada para no bloquear los toques sobre el Home, y notificar a `HomeScreen` para ajustar el padding inferior del scroll view en tiempo real.
4. **Falta de Personalización y Libertad del Usuario en la Cuadrícula del Home ("Home Studio"):**
   * El comerciante no puede elegir qué tarjetas ver ni en qué orden mostrarlas según la rutina de su negocio. Se necesita un sistema interactivo para reordenar y ocultar/mostrar tarjetas con persistencia local.
5. **Desbalances visuales y tipográficos en el Dashboard:**
   * La tarjeta de KPIs muestra `"Operacione"` / `"s Hoy"` roto en dos líneas y repite `"Listas Listas"`.
   * La píldora de alerta de stock queda aislada a la derecha con un vacío asimétrico.

---

## 2. DIAGNÓSTICO TÉCNICO EN CÓDIGO (EVIDENCIAS EXACTAS)

### 2.1. Diagnóstico del Buscador Omnicanal (`omni_search_bar.dart`)

#### A. Error Crítico en Consulta de Clientes (Columnas Inexistentes)
* **Archivo:** `lib/core/widgets/omni_search_bar.dart` (Líneas 165–170):
  ```sql
  SELECT id, nombre_completo, telefono, numero_documento, saldo_a_favor, total_deuda, nivel_confianza
  FROM clientes
  WHERE negocio_id = ? AND (nombre_completo LIKE ? OR telefono LIKE ? OR numero_documento LIKE ?)
  ```
* **Causa Raíz:** En el esquema de SQLite (`LocalDatabase`, tabla `clientes`), las columnas oficiales son `dni_ruc` (no `numero_documento`) y `deuda_total` (no `total_deuda`).
* **Efecto:** Cada vez que el usuario escribe un término, la consulta de clientes lanza una `DatabaseException: no such column: numero_documento`. En la línea 201, `catch (_)` traga el error sin loguearlo, dejando `_clientResults = []` permanentemente vacío.

#### B. Limitación de Búsqueda de Productos (Sin Cruce de Atributos ni Normalización SQLite)
* **Archivo:** `lib/core/widgets/omni_search_bar.dart` (Líneas 153–162):
  ```sql
  SELECT ... FROM presentaciones_producto pr
  JOIN productos p ON pr.producto_id = p.id
  LEFT JOIN marcas m ON p.marca_id = m.id
  WHERE p.negocio_id = ? AND (p.nombre LIKE ? OR pr.nombre_especifico LIKE ? OR pr.codigo_barras LIKE ?)
  ```
* **Causa Raíz:**
  1. No evalúa `m.nombre` (marca) ni `c.nombre` (categoría). `"cuaderno stanford"` devuelve 0 resultados.
  2. Al enviar `'%$term%'` completo, exige la subcadena contigua exacta (`"agua gas 500"` falla si en la BD dice `"Agua San Mateo con gas 500ml"`).
  3. **Problema de Tildes en SQLite:** Si en SQLite el registro es `"Lápiz"` y el término de búsqueda normalizado en Dart es `"lapiz"`, la cláusula `WHERE columna LIKE '%lapiz%'` devuelve `FALSE` porque SQLite no normaliza diacríticos nativamente en la columna.
  4. **Falta de Aislamiento:** Las consultas de Productos, Clientes, Cotizaciones y Ventas se ejecutaban secuencialmente en un único bloque `try/catch`. Si una fallaba, cancelaba la ejecución de las siguientes.

---

### 2.2. Diagnóstico del Botón de Escáner en la Barra del Home

* **Archivo:** `lib/core/screens/home_screen.dart` (Líneas 245–254):
  ```dart
  OmniSearchBar(
    onBarcodeTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ScanScreen(), // ❌ Error: abre ScanScreen en ScanMode.quotation (OCR de listas)
        ),
      );
    },
  ),
  ```
* **Causa Raíz:** `ScanScreen()` abre por defecto el escáner de listas escolares con IA.
* **Comportamiento Esperado:** Debe abrir `BarcodeScannerScreen` (el lector de código de barras de productos) filtrando por `negocio_id` activo. Si existe, hidratar el `Product` y abrir `ProductDetailScreen` seleccionando la presentación exacta (`initialPresentationId`). Si no existe, presentar el diálogo modal `BarcodeNotFoundDialog` y precargar el código en la primera presentación de `ProductCreateScreen`.

---

### 2.3. Diagnóstico del Layout y Gestos en `PersistentWorkDock`

* **Archivo:** `lib/core/widgets/persistent_work_dock.dart` (Líneas 276–292, 355–462):
  * **Ancho saturado:** Coexisten: Avatar (44px) + SizedBox (12px) + Expanded Column + Botón Descartar (40px) + Botón Reanudar (110px) = 230px fijos. En móviles de 360–390px, el área de texto queda comprimida a menos de 100px (`"Borrador d..."`).
  * **HitTest en Modo Globo:** Si el widget sigue envuelto en `Positioned(bottom: 0, left: 0, right: 0)`, cuando se reduzca visualmente a un globo de 58x58px, el contenedor padre transparente seguirá capturando toques en toda la franja inferior del `HomeScreen`, bloqueando la interacción del usuario.
  * **Solapamiento en Home:** `home_screen.dart` tiene un padding estático de 100px. Cuando el dock está presente (altura ~130px), tapa la última fila de tarjetas de `SmartActionGrid`.

---

## 3. ARQUITECTURA DE SOLUCIÓN Y DISEÑO DETALLADO

```
                                  ARQUITECTURA DEL HOME Y OMNISEARCH
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│                                       HOME SCREEN                                           │
│  ┌───────────────────────────────────────────────────────────────────────────────────────┐  │
│  │ DashboardHeader (Aurora Glassmorphism + KPIs sin desborde + Animación Numérica)       │  │
│  └───────────────────────────────────────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────────────────────────────────────┐  │
│  │ OmniSearchBar: Input inteligente + Botón Escáner Barcode Real                         │  │
│  └──────────────────┬──────────────────────────────────────────┬─────────────────────────┘  │
│                     │ Tap Input                                │ Tap Barcode                │
│                     ▼                                          ▼                            │
│  ┌──────────────────────────────────────────────┐ ┌──────────────────────────────────────┐  │
│  │ OMNI SEARCH MODAL INTERACTIVO                │ │ BARCODE SCANNER SCREEN               │  │
│  │ • Motor SQLite Multi-Palabra Tokenizado      │ │ • Lector Cámara Barcode              │  │
│  │ • SQLite REPLACE anidado (100% anti-tildes)  │ │ • Filtro negocio_id activo           │  │
│  │ • Bloques try/catch independientes           │ │ • Búsqueda instantánea en SQLite     │  │
│  │ • Carga de recientes por defecto             │ │                                      │  │
│  │ • Tarjetas inline de presentaciones directas │ │ ¿Existe en BD?                       │  │
│  │ • Selector de Ordenamiento Dinámico          │ │ ├── SÍ ──> ProductDetailScreen       │  │
│  │ • Rutas directas: QuotationDetail, etc.      │ │ └── NO ──> BarcodeNotFoundDialog     │  │
│  └──────────────────────────────────────────────┘ │            └──> ProductCreateScreen  │  │
│                                                   │                 (_controllers.first) │  │
│                                                   └──────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────────────────────────────────────┐  │
│  │ Scrollable Feed (Padding dinámico reactivo al Dock: 140px vs 30px):                   │  │
│  │ • Barra de Alerta Inteligente Balanceada (Pulso Ámbar)                                │  │
│  │ • Gráfico Semanal Interactivo con Curva y Resumen Fluido                              │  │
│  │ • HOME STUDIO: Cabecera con botón "Personalizar" (Reordenamiento Drag & Drop)         │  │
│  │ • Smart Action Grid Personalizable (Ocultar/Mostrar accesos + Persistencia)          │  │
│  │ • Actividad Reciente tipo Feed Transaccional                                         │  │
│  └───────────────────────────────────────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────────────────────────────────────┐  │
│  │ PersistentWorkDock Híbrido:                                                           │  │
│  │ [Modo Barra Completa] <===== Deslizar Izq/Der =====> [Globo Esquina 58x58px]           │  │
│  │ • Tipografía optimizada (sin truncar)      • HitTest acotado estrictamente a 58x58px  │  │
│  │ • Descarte y reanudación rápida             • Magnetic edge snapping (Izq / Der)      │  │
│  │ • Notifica a HomeScreen vía ValueNotifier   • Libera 100% de toques en la pantalla    │  │
│  └───────────────────────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

### 3.1. Reingeniería del Motor de Búsqueda Omnicanal Local

#### A. Normalización Real de Tildes en SQLite mediante Función SQL Helper
Para garantizar coincidencia 100% infalible entre texto buscado y datos almacenados (tenga tilde la búsqueda o la base de datos), creamos un helper SQL que despoja las tildes directamente en la consulta:

```dart
/// Envuelve una columna o expresión SQL para pasar a minúsculas y sustituir tildes en SQLite
String sqlUnaccent(String sqlExpr) {
  return "REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LOWER(IFNULL($sqlExpr, '')), 'á', 'a'), 'é', 'e'), 'í', 'i'), 'ó', 'o'), 'ú', 'u')";
}
```

* **En Dart:** El token del usuario se normaliza a minúsculas sin acentos:
  `"Lápiz"` o `"lapiz"` $\rightarrow$ `"lapiz"`.
* **En SQLite:**
  `WHERE ${sqlUnaccent('p.nombre')} LIKE '%lapiz%'`
  Si en SQLite está `"Lápiz"`, el `sqlUnaccent` lo transforma en `"lapiz"`, coincidiendo al 100%.

#### B. Aislamiento Estricto mediante `try/catch` Independiente por Entidad
El método `_performSearch` ejecutará 4 bloques aislados:
```dart
// 1. Productos
try {
  _productResults = await _searchProducts(db, businessId, tokens);
} catch (e) {
  AppLogger.error('OmniSearch.products', e);
  _productResults = [];
}

// 2. Clientes
try {
  _clientResults = await _searchClients(db, businessId, tokens);
} catch (e) {
  AppLogger.error('OmniSearch.clients', e);
  _clientResults = [];
}

// 3. Cotizaciones
try {
  _quoteResults = await _searchQuotes(db, businessId, tokens);
} catch (e) {
  AppLogger.error('OmniSearch.quotes', e);
  _quoteResults = [];
}

// 4. Ventas
try {
  _saleResults = await _searchSales(db, businessId, tokens);
} catch (e) {
  AppLogger.error('OmniSearch.sales', e);
  _saleResults = [];
}
```
Esto garantiza que una falla en una entidad **jamás deje en blanco los resultados de las otras tres**.

#### C. Estado Inicial Vacío con Carga de Recientes y Contadores Reales
Cuando el modal se abre por primera vez con el input vacío, o cuando el usuario cambia entre los chips (`Todos`, `Productos`, `Clientes`, `Cotizaciones`, `Ventas`) sin haber digitado texto:
* Se ejecutan consultas de carga reciente (`ORDER BY id DESC LIMIT 10` por categoría).
* Los chips de categoría muestran sus contadores reales de elementos disponibles recientes: `📦 Productos (10)`, `👤 Clientes (8)`, etc., en lugar de mostrar `(0)` vacío.
* Se presenta un subtítulo dinámico elegante: `"Registros recientes en tu negocio (Escribe para filtrar)"`.

#### D. Algoritmo de Scoring y Relevancia en Memoria
* **+100 puntos:** Coincidencia exacta con el término completo.
* **+70 puntos:** Comienza con el término (`startsWith`).
* **+40 puntos:** Todos los tokens están presentes en el nombre principal.
* **+20 puntos:** Coincidencias en marca, categoría o documento.
* **+10 puntos:** Registros recientes.

#### E. Selector de Ordenamiento Dinámico
Barra de control compacta con píldoras animadas:
* `Relevancia` (orden natural de scoring)
* `Más Recientes` (`fecha DESC` o `id DESC`)
* `Alfabético (A - Z)`
* `Mayor Precio / Monto` y `Menor Precio / Monto`

---

### 3.2. Tarjetas de Resultado en Dos Modos (Recogido vs. Desplegado Inline) y Navegación

#### A. Listado Directo de Presentaciones Individuales en Productos
* La consulta de productos lista directamente las **presentaciones registradas en SQLite** (`presentaciones_producto pr JOIN productos p ...`).
* **Modo 1 — Recogido:** Tarjeta limpia (~72px) con avatar/foto, nombre del producto + nombre específico (`"Cuaderno Standford A4 100h"`), precio de esa presentación, badge de stock de esa variante y botón de acción rápida a la derecha.
* **Modo 2 — Desplegado Inline (Al presionar la tarjeta):**
  * La tarjeta se expande con `AnimatedSize` mostrando **los detalles específicos de esa presentación elegida**:
    * Factor de empaque (`unidades_por_venta`, `unidad_venta`).
    * Stock actual de esa variante y stock de alerta.
    * Precio regular, precio oferta (si aplica) y margen.
    * Código de barras y categoría.
  * **No se satura con la lista de otras variantes hermanas**.
  * Botón full-width: `"Ver Ficha Completa del Producto"` $\rightarrow$ Navega a `ProductDetailScreen` pasando `initialPresentationId: presentationId` para enfocar directamente esa variante.

#### B. Rutas y Enrutamiento Preciso en Todas las Entidades
* **Cotizaciones:** Al presionar la tarjeta o su botón de detalle, navega directamente a:
  ```dart
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => QuotationDetailScreen(
        quotationId: quoteId,
        clientName: q['client_name'],
      ),
    ),
  );
  ```
  `QuotationDetailScreen` ya implementa la hidratación completa de la cotización desde SQLite.
* **Clientes:** Hidrata el cliente mediante `ClientService().getClientById(clientId)` o `trackingProv.getClientById(clientId)` y navega a `ClientDetailScreen(client: clientModel)`.
* **Ventas:** Navega a `SaleHistoryDetailScreen(saleId: saleId)`.
* **Productos:** Hidrata con `invProv.getFullProductWithFallback(productId)` y abre `ProductDetailScreen(product: fullProduct, initialPresentationId: presentationId)`.

---

### 3.3. Flujo del Escáner de Códigos de Barras e Inyección en `ProductCreateScreen`

#### 1. Conexión en `home_screen.dart`
Reemplazar `ScanScreen()` por `BarcodeScannerScreen(captureOnly: false, isFromQuickSale: false)`.

#### 2. Detección y Enrutamiento en `BarcodeScannerScreen`
* Consulta en SQLite filtrando siempre por `p.negocio_id = ?` (`AuthProvider.activeBusinessId`).
* **Caso A (Existe en inventario):**
  * Obtiene el producto completo con `invProv.getFullProductWithFallback(productId)`.
  * Determina la `presentationId` exacta del código escaneado.
  * Navega a `ProductDetailScreen(product: fullProduct, initialPresentationId: presentationId)`.
* **Caso B (NO existe en inventario):**
  * Pausa el escáner de cámara.
  * Muestra el modal interactivo `BarcodeNotFoundDialog`.
  * Botón `"Registrar Nuevo Producto"` $\rightarrow$ Cierra el modal y navega a:
    ```dart
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ProductCreateScreen(initialBarcode: scannedCode),
      ),
    );
    ```

#### 3. Inyección Automática en `ProductCreateScreen`
* En `lib/features/catalog/screens/product_create_screen.dart`:
  1. Parámetro en el constructor: `final String? initialBarcode;`.
  2. En `initState()`:
     ```dart
     @override
     void initState() {
       super.initState();
       if (widget.initialBarcode != null && widget.initialBarcode!.isNotEmpty) {
         _barcodeCtrl.text = widget.initialBarcode!;
       }
       WidgetsBinding.instance.addPostFrameCallback((_) {
         Provider.of<InventoryProvider>(context, listen: false).loadMasterData();
       });
       _addPresentation(isDefault: true);
       // Inyección en la primera presentación creada
       if (widget.initialBarcode != null && widget.initialBarcode!.isNotEmpty && _controllers.isNotEmpty) {
         (_controllers.first['barcode'] as TextEditingController).text = widget.initialBarcode!;
       }
     }
     ```
  Esto garantiza que el código escaneado aparezca ya lleno tanto en el encabezado general del producto como en su primera presentación.

---

### 3.4. Transformación del `PersistentWorkDock` en Globo Flotante con HitTest Acotado

#### A. Gestión de Área de Toque (`HitTest`) y Posicionamiento
* Cuando el Dock esté expandido: Se ubica en la parte inferior ocupando el ancho normal con margen horizontal de 16px.
* Cuando el Dock esté minimizado a **Globo Flotante (58x58px)**:
  * Su widget contenedor en `HomeScreen` **no debe ocupar `left: 0, right: 0`**.
  * Se posiciona mediante un `Positioned` con coordenadas absolutas (`left` o `right`, y `bottom`), teniendo un tamaño acotado de `width: 58, height: 58`.
  * De esta forma, el área transparente no intercepta toques y el usuario puede interactuar libremente con todos los botones, tarjetas y scrolls de `HomeScreen`.

#### B. Sincronización del Padding Inferior del Home
* `PersistentWorkDock` expondrá un callback o `ValueNotifier<bool>`:
  `final ValueChanged<bool>? onBubbleModeChanged;`
* En `_HomeScreenState`, se gestionará la variable `bool _isDockInBubbleMode = false;`.
* El `SingleChildScrollView` del Home ajustará dinámicamente su padding final:
  ```dart
  SizedBox(height: _hasActiveDockTasks ? (_isDockInBubbleMode ? 35 : 140) : 25)
  ```
  Esto evita completamente que el Dock tape la última fila de tarjetas cuando está expandido, y elimina el espacio vacío cuando está en modo globo.

#### C. Gestos, Morphing y Magnetic Edge Snapping
* **Arrastre Lateral en Modo Barra:** Deslizar horizontalmente el dock hacia la izquierda o derecha activa la animación elástica de reducción hacia la esquina correspondiente.
* **Arrastre del Globo:** El usuario puede arrastrar el globo por la pantalla. Al soltarlo (`onPanEnd`), una animación de resorte lo atrae magnéticamente al borde más cercano (izquierdo o derecho) a 16px del margen.
* **Pulso Neón y Badge:** El globo muestra un borde luminoso del color de la tarea más urgente, icono animado y un badge con el conteo de tareas activas.
* **Tipografía Optimizada en Barra:** Reorganización del espacio interno para que `"Borrador de Cotización"` y `"Conciliación IA"` se muestren completos sin puntos suspensivos prematuros (`"Borrador d..."`).

---

### 3.5. Sistema "Home Studio": Personalización, Reordenamiento y Visibilidad de Tarjetas

Para que el usuario sienta la app verdaderamente suya y adapte el flujo de trabajo a la dinámica específica de su negocio, se diseñará e implementará el sistema **Home Studio**:

```
                              HOME STUDIO: PERSONALIZADOR VISUAL
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│ GESTIÓN OPERATIVA                                        [ ✏️ Personalizar ] [ 👁️ Ver todo ]│
├─────────────────────────────────────────────────────────────────────────────────────────────┤
│ (Modo Edición Activo: Borde pulsante sutil + Reorderable + Controles de Visibilidad)        │
│                                                                                             │
│ ┌──────────────────────┐  ┌──────────────────────┐  ┌──────────────────────┐                │
│ │ [::] Venta Rápida [x]│  │ [::] Cotizar Lista[x]│  │ [::] Clientes    [x]│  ...            │
│ │ Caja al paso         │  │ Escaneo con IA       │  │ Deudas y Pagos   │                │
│ └──────────────────────┘  └──────────────────────┘  └──────────────────────┘                │
│                                                                                             │
│  [+] Bandeja de Tarjetas Ocultas (2): [ Cargar Factura (+) ] [ DB Inspector (+) ]           │
│  [ Restablecer Orden de Fábrica ]                                        [ Guardar / Listo ]│
└─────────────────────────────────────────────────────────────────────────────────────────────┘
```

#### A. Componentes y Funcionalidades del Home Studio
1. **Botón de Modo Edición en Cabecera:**
   * Junto al título `"Gestión Operativa"`, se incorpora un botón estilizado `[ ✏️ Personalizar ]`.
   * Al presionarlo, la sección conmuta a **Modo Edición Interactivo** con feedback háptico.
2. **Reordenamiento Intuitivo (Drag & Drop):**
   * Las tarjetas pueden arrastrarse para reordenar sus posiciones mediante `ReorderableBuilder` o `LongPressDraggable` interactivo.
   * El usuario puede mover su acción favorita (ej. "Venta Rápida" o "Crear Pedido") a la posición número 1.
3. **Control de Visibilidad (Ocultar / Mostrar):**
   * Cada tarjeta en modo edición incluye un botón `[ x ]` / `[ 👁️ ]` para ocultarla si el comerciante no utiliza esa función habitualmente.
   * Las tarjetas ocultas se desplazan a la **Bandeja de Accesos Ocultos** inferior, desde donde pueden restaurarse con un solo toque `[ + ]`.
4. **Persistencia Local por Negocio (`SharedPreferences`):**
   * Se guarda el array de IDs ordenados y el set de IDs ocultos:
     * `home_cards_order_${businessId}`
     * `home_cards_hidden_${businessId}`
   * Al iniciar sesión o cambiar de negocio, la cuadrícula se inicializa con las preferencias guardadas de ese negocio específico.
5. **Botón de Restauración ("Restablecer Orden de Fábrica"):**
   * Permite volver al orden predeterminado del sistema con un solo toque.

#### B. Propuestas Adicionales de Personalización Creativa
1. **Modo de Densidad de Tarjetas:** Selector en el panel de personalización para alternar entre **Cuadrícula Amplia (2 columnas con subtítulo e icono grande)** y **Cuadrícula Compacta (3 columnas o píldoras ágiles)** para comerciantes que prefieren máxima densidad visual.
2. **Tarjeta Destacada ("Hero Quick Access"):** El usuario puede marcar 1 tarjeta como favorita para que se despliegue a ancho completo con acceso prioritario en la parte superior de la cuadrícula.
3. **Indicador Visual de Personalización Activa:** Si el usuario tiene un diseño personalizado, un pequeño punto azul en el botón de edición le recuerda que su interfaz está personalizada.

---

### 3.6. Reestructuración "Mobile Awards" de `home_screen.dart` y Dashboard

#### A. Correcciones Visuales en `dashboard_header.dart`
* **"Operaciones Hoy":** Usar `FittedBox(fit: BoxFit.scaleDown)` con `maxLines: 1` para erradicar la división no deseada `"Operacione"` / `"s Hoy"`.
* **"Listas Listas":** Reemplazar por `"Listas Preparadas"` o `"Cotizaciones Listas"`.
* **Contadores Numéricos Animados (*Count-Up*):**
  * Integrar `TweenAnimationBuilder<double>` en los valores monetarios (`S/ 0.00 -> S/ 1,450.00`) y de conteo para que suban con fluidez al cargar la pantalla o al refrescar.

#### B. Rediseño del Chip de Alerta de Stock (`RestockSmartBanner`)
* Eliminar el `Align(alignment: Alignment.centerRight)` huérfano.
* Transformarlo en una **barra inteligente de estado full-width con pulso luminoso**:
  * Fondo suave ámbar translúcido, icono de advertencia con micro-pulso y texto centrado o justificado: `"⚠️ 1 producto requiere reabastecimiento urgente"`, con botón `"Revisar"`.

---

## 4. PLAN DE TRABAJO POR FASES (LOOP AUTÓNOMO + ÁRBITRO ADVERSARIAL)

```
FASE 1: Motor SQLite Multi-Palabra, Normalización con REPLACE anidado, try/catch y carga de recientes
FASE 2: UI Buscador Omnicanal (Presentaciones directas, Modo Inline específico, Ordenamiento y Navegación)
FASE 3: Flujo Escáner de Barcode, Modal Producto No Encontrado e Inyección en ProductCreateScreen
FASE 4: Reingeniería del WorkDock (Globo Flotante 58x58 con HitTest acotado, Sincronización de Padding)
FASE 5: Sistema "Home Studio" de Personalización & Reordenamiento de Tarjetas + Pulido Dashboard
FASE 6: Protocolo de Validación, Árbitro Adversarial y Verificación de Regresiones
```

---

### FASE 1: Motor de Búsqueda SQLite Multi-Palabra, Normalización con REPLACE Anidado y Aislamiento

* **Objetivo:** Motor de búsqueda 100% insensible a mayúsculas y tildes, con tokenización inteligente y tolerancia a fallos.
* **Archivos Afectados:**
  * `lib/core/widgets/omni_search_bar.dart`
* **Tareas Específicas:**
  1. Corregir columnas en la tabla `clientes`: usar `dni_ruc` y `deuda_total`.
  2. Implementar helper SQL `sqlUnaccent` con 5 niveles de `REPLACE` para despojar tildes en SQLite.
  3. Implementar tokenización y lematización en Dart: segmentar la cadena de búsqueda y cruzar cada token con `AND` sobre los campos combinados de cada entidad.
  4. Aislar las 4 consultas en bloques `try/catch` independientes para que un fallo en una entidad jamás anule las demás.
  5. Implementar carga por defecto de registros recientes con contadores reales al abrir el modal con input vacío o cambiar de chips.
  6. Implementar scoring de relevancia para ordenar coincidencias exactas y de prefijo en primer lugar.
* **Criterios de Aceptación:**
  * Búsquedas con tildes y sin tildes devuelven los mismos resultados exactos.
  * Términos como `"cuaderno stanford"` y `"agua gas 500"` encuentran sus registros correspondientes.
  * Si la tabla clientes tiene algún error, productos y cotizaciones siguen mostrándose sin problemas.

---

### FASE 2: UI del Buscador Omnicanal — Modo Recogido/Desplegado Inline, Ordenamiento Dinámico y Navegación

* **Objetivo:** Experiencia de búsqueda fluida con tarjetas interactivas de doble estado y navegación sin pantallas blancas.
* **Archivos Afectados:**
  * `lib/core/widgets/omni_search_bar.dart`
* **Tareas Específicas:**
  1. Modificar la consulta de productos para listar presentaciones individuales directamente (`presentaciones_producto`).
  2. Diseñar la tarjeta de doble modo:
     * **Modo Recogido:** Tarjeta limpia de 72px con avatar, nombre del producto + presentación, precio, stock y botón rápido.
     * **Modo Desplegado:** `AnimatedSize` mostrando detalles específicos de esa variante (empaque, stock variante, precio, código, categoría).
  3. Incorporar selector de ordenamiento dinámico en la cabecera del modal (*Relevancia*, *Más Recientes*, *Alfabético A-Z*, *Mayor/Menor Precio*).
  4. Conectar rutas seguras:
     * Cotización $\rightarrow$ `QuotationDetailScreen(quotationId: id, clientName: name)`.
     * Cliente $\rightarrow$ `ClientDetailScreen(client: fullClient)`.
     * Venta $\rightarrow$ `SaleHistoryDetailScreen(saleId: id)`.
     * Producto $\rightarrow$ `ProductDetailScreen` con producto hidratado y `initialPresentationId`.
* **Criterios de Aceptación:**
  * Tocar una tarjeta la expande inline con animación fluida sin ocultar los demás resultados.
  * Todas las rutas abren su pantalla completa con datos íntegros y cero pantallas blancas.

---

### FASE 3: Flujo Escáner de Barcode en Home, Modal Producto No Encontrado e Inyección de Código

* **Objetivo:** Conectar el escáner de códigos de barras del Home con flujo inteligente de creación de productos.
* **Archivos Afectados:**
  * `lib/core/screens/home_screen.dart`
  * `lib/features/scanner/screens/barcode_scanner_screen.dart`
  * `lib/features/catalog/screens/product_create_screen.dart`
  * Creación de `lib/features/scanner/widgets/barcode_not_found_dialog.dart`
* **Tareas Específicas:**
  1. En `home_screen.dart`, actualizar `onBarcodeTap` para navegar a `BarcodeScannerScreen()`.
  2. En `BarcodeScannerScreen`, filtrar siempre por `negocio_id` activo.
  3. Si el código no existe en inventario, pausar cámara y desplegar `BarcodeNotFoundDialog` con código copiable y botón de registro.
  4. En `ProductCreateScreen`:
     * Recibir `final String? initialBarcode;`.
     * En `initState()`, asignar el valor a `_barcodeCtrl` y al controlador `'barcode'` de la primera presentación (`_controllers.first`).
* **Criterios de Aceptación:**
  * Escanear un código inexistente abre el diálogo animado. Al tocar "Registrar", el código aparece precargado en el formulario y en su primera variante.

---

### FASE 4: Reingeniería del `PersistentWorkDock` — Arrastre Lateral y Globo Flotante con HitTest Acotado

* **Objetivo:** Convertir el dock en un globo de 58x58px que no bloquee toques en el Home y sincronice el padding del scroll.
* **Archivos Afectados:**
  * `lib/core/widgets/persistent_work_dock.dart`
  * `lib/core/screens/home_screen.dart`
* **Tareas Específicas:**
  1. Implementar detección de deslizamiento horizontal (`onHorizontalDragEnd`) en el Dock con animación elástica a globo (58x58px).
  2. Acotar el `HitTest` del globo: cuando esté minimizado, su contenedor se posiciona exactamente con `width: 58, height: 58` sin ocupar toda la franja inferior de la pantalla.
  3. Soporte para arrastrar el globo entre la esquina izquierda y derecha con adherencia magnética (*Magnetic Edge Snapping*).
  4. Conectar callback `onBubbleModeChanged(bool isBubble)` hacia `HomeScreen` para ajustar el padding inferior del scroll view en tiempo real (140px vs 35px).
  5. Optimizar tipografía en modo expandido para evitar cortes como `"Borrador d..."`.
* **Criterios de Aceptación:**
  * El globo no bloquea toques en el Home.
  * Se adhiere magnéticamente a los bordes.
  * El scroll del Home nunca queda oculto detrás del dock.

---

### FASE 5: Sistema "Home Studio" de Personalización & Reordenamiento de Tarjetas + Pulido Dashboard

* **Objetivo:** Dotar al usuario de control total sobre las tarjetas del Home y eliminar desbordamientos visuales.
* **Archivos Afectados:**
  * `lib/core/widgets/home/smart_action_grid.dart`
  * `lib/core/widgets/home/dashboard_header.dart`
  * `lib/features/analytics/widgets/restock_smart_banner.dart`
  * `lib/core/screens/home_screen.dart`
* **Tareas Específicas:**
  1. En `smart_action_grid.dart`, añadir botón `[ ✏️ Personalizar ]` en la cabecera.
  2. Implementar Modo Edición con soporte de reordenamiento de tarjetas y botones de visibilidad `[ x ]` para ocultar/mostrar.
  3. Crear bandeja inferior de tarjetas ocultas y botón para restablecer orden de fábrica.
  4. Persistir orden y visibilidad en `SharedPreferences` aislado por `businessId`.
  5. En `dashboard_header.dart`, corregir `"Listas Listas"` a `"Listas Preparadas"`, envolver `"Operaciones Hoy"` en `FittedBox` e integrar contadores numéricos animados (*count-up*).
  6. En `restock_smart_banner.dart`, transformar el chip suelto en una barra de estado full-width con pulso luminoso.
* **Criterios de Aceptación:**
  * El usuario puede mover y ocultar tarjetas a su gusto y sus preferencias persisten al reiniciar la app.
  * Cero desbordamientos de texto en el header.

---

### FASE 6: Protocolo de Validación, Árbitro Adversarial y Verificación de Regresiones

* **Objetivo:** Máxima estabilidad y cero advertencias.
* **Tareas Específicas:**
  1. Ejecución de `flutter analyze` en todo el proyecto asegurando cero errores en los archivos modificados.
  2. Pruebas de búsqueda con tildes, desordenadas y por atributos cruzados.
  3. Validación de escáner de códigos de barras (existente vs no existente).
  4. Prueba de gestos del WorkDock y libertad de toques en el Home.
  5. Prueba de persistencia del Home Studio (reordenar, ocultar, reiniciar app).
* **Criterios de Aceptación:**
  * Código limpio, robusto y probado.

---

## 5. MATRIZ DE RIESGOS Y MEDIDAS DE MITIGACIÓN

| Riesgo Identificado | Probabilidad | Impacto | Estrategia de Mitigación |
| :--- | :---: | :---: | :--- |
| **Lentitud en SQLite por búsqueda multi-palabra con `REPLACE`** | Media | Medio | Limitar con `LIMIT 15` por categoría, debouncing de 250ms en el input y uso de índices en `negocio_id`. |
| **Colisión gestual entre scroll de tarjetas y swipe del WorkDock** | Media | Medio | Capturar el gesto horizontal solo cuando `dx.abs() > dy.abs() * 2` y velocidad superior a 300 px/s. |
| **Bloqueo de toques por el contenedor del globo flotante** | Media | Alto | Limitar el tamaño del `Positioned` a 58x58 px exactos cuando esté en modo burbuja, dejando libre el resto del stack. |
| **Inconsistencia de estado al cambiar de negocio en el Home Studio** | Baja | Medio | La clave de persistencia en `SharedPreferences` incluye el `businessId` activo. |

---

## 6. CONCLUSIÓN Y PRÓXIMOS PASOS

Con la integración de estos 4 ajustes críticos y el sistema **Home Studio**, el Plan Maestro garantiza una solución técnicamente sólida, sin fallas en tiempo de ejecución y con una experiencia de personalización inigualable.

**Próximo paso:** Tras la confirmación del usuario, iniciaremos de inmediato con la **Fase 1** (Motor de Búsqueda SQLite con normalización `REPLACE`, `try/catch` independiente y carga de recientes).
