# Plan de Trabajo: Fragmentación y Reducción de Archivos Extensos (> 500 líneas)

## Diagnóstico y Objetivos

He analizado a fondo el código fuente del aplicativo mediante un script en Dart y, tal como sospechabas, existe una cantidad considerable de archivos que superan las 500 líneas de código. Tener archivos tan extensos (algunos rozando las 1000 líneas) dificulta la mantenibilidad, aumenta la probabilidad de introducir bugs, y ralentiza el análisis y desarrollo futuro.

El objetivo de este plan es **extraer componentes de UI (Modales, Tarjetas, Secciones), lógica de negocio y configuraciones** hacia archivos más pequeños (preferiblemente en carpetas `widgets/` locales de cada Feature), sin alterar la funcionalidad actual ni simplificarla, sino ordenándola bajo el patrón de "Feature-first".

> [!NOTE]
> Además de proponer este plan, te comento que **ya he solucionado todos los problemas que me indicaste** en el último mensaje: 
> 1. Incongruencias matemáticas en pagos a crédito (Abonos Iniciales e Intereses) en `sales_checkout_screen.dart`.
> 2. Mejora visual de los productos en `sale_financial_detail_screen.dart` (ahora se muestran con imágenes y el texto original cotizado).
> 3. El historial de pagos `ledger_timeline_tab` ya vincula e indica correctamente a qué Venta pertenece el "Abono Inicial".
> 4. Los errores amarillos (Linter) de deprecación de `Share` y warnings de sintaxis (`{}`) han sido corregidos de forma segura.

---

## Archivos Extensos Detectados y Plan de Fragmentación

A continuación, detallo los archivos más críticos encontrados y la estrategia exacta para reducirlos. Se dividirá el trabajo en **4 Fases prioritarias**:

### FASE 1: Las Pantallas Monolíticas Más Grandes (+800 líneas)

#### 1. `lib/features/profile/screens/notifications_screen.dart` (949 líneas)
Esta pantalla maneja renderizado de muchas alertas y filtros.
* **Nuevos Archivos a Crear:**
  * `lib/features/profile/widgets/notifications/notification_filter_bar.dart` (Para aislar los chips de filtrado).
  * `lib/features/profile/widgets/notifications/notification_item_card.dart` (Para extraer el diseño individual de cada notificación según su tipo).
  * `lib/features/profile/widgets/notifications/notification_empty_state.dart`.

#### 2. `lib/features/smart_quotation/screens/manual_quotation_screen.dart` (919 líneas)
Tiene demasiados modales integrados para agregar productos y editar listas.
* **Nuevos Archivos a Crear:**
  * `lib/features/smart_quotation/widgets/manual/manual_product_search_sheet.dart` (Para el BottomSheet de búsqueda de productos).
  * `lib/features/smart_quotation/widgets/manual/manual_quote_item_card.dart` (El diseño de la tarjeta de cada producto en la cotización).
  * `lib/features/smart_quotation/widgets/manual/manual_quote_summary_footer.dart` (La barra inferior con totales).

### FASE 2: Pantallas de Catálogo y Detalle de Ventas (+700 líneas)

#### 3. `lib/features/smart_quotation/screens/sale_history_detail_screen.dart` (757 líneas)
* **Nuevos Archivos a Crear:**
  * `lib/features/smart_quotation/widgets/history/sale_status_header.dart`
  * `lib/features/smart_quotation/widgets/history/sale_payment_timeline.dart` (El historial de pagos de esa venta específica).

#### 4. `lib/screens/product_edit_screen.dart` (730 líneas)
Maneja edición de fotos, formulación de precios y atributos.
* **Nuevos Archivos a Crear:**
  * `lib/screens/widgets/product_edit/product_image_picker.dart`
  * `lib/screens/widgets/product_edit/product_pricing_form.dart`
  * `lib/screens/widgets/product_edit/product_presentation_list.dart`

#### 5. `lib/features/smart_quotation/screens/quotation_detail_screen.dart` (719 líneas)
* **Nuevos Archivos a Crear:**
  * `lib/features/smart_quotation/widgets/detail/quotation_client_info_card.dart`
  * `lib/features/smart_quotation/widgets/detail/quotation_action_buttons.dart` (Rechazar, Aprobar, Editar).

#### 6. `lib/widgets/product_action_sheet.dart` (718 líneas)
* **Nuevos Archivos a Crear:**
  * Esta hoja de acción es gigantesca. La separaremos en modales más pequeños (ej: `StockUpdateModal`, `PriceUpdateModal`).

#### 7. `lib/features/smart_quotation/screens/crm/client_detail_screen.dart` (706 líneas)
* **Nuevos Archivos a Crear:**
  * `lib/features/smart_quotation/widgets/crm/client_stats_header.dart`
  * Extraer las pestañas del `TabBarView` a archivos separados (si no lo están ya).

### FASE 3: Componentes Críticos del Flujo de Cotización (+600 líneas)

* **`lib/features/smart_quotation/screens/whatsapp_preview_screen.dart` (697 líneas):** Separar el renderizado del mensaje (`whatsapp_message_bubble.dart`) de la lista de opciones de envío.
* **`lib/widgets/staging/variant_editor_row.dart` (679 líneas):** A pesar de ser un widget, contiene mucha lógica de variantes. Separar en `variant_price_calculator.dart`.
* **`lib/screens/catalog/catalog_screen.dart` (673 líneas) y `lib/screens/tabs/products_tab.dart` (656 líneas):** Extraer los "SliverAppBars" y las grillas en archivos modulares (ej: `catalog_filter_header.dart`).
* **`lib/features/smart_quotation/screens/sales_checkout_screen.dart` (663 líneas):** Ya empecé a reducirlo antes extrayendo modales, pero terminaré extrayendo `CheckoutSummaryCard` y `CheckoutActionFooter`.

### FASE 4: Otras Pantallas Importantes (+500 líneas)
* `analytics_dashboard_screen.dart` (600 líneas): Extraer el `DatePicker` y los summary cards.
* `team_management_screen.dart` (586 líneas)
* `invoice_review_screen.dart` (581 líneas)
* `workbench_screen.dart` (574 líneas)
* `product_create_screen.dart` (562 líneas)
* Modales complejos (`payment_entry_modal.dart`, `manual_quote_detail_modal.dart`).

---

> [!IMPORTANT]
> **User Review Required:**
> ¿Estás de acuerdo con este plan de fragmentación? ¿Deseas que comience ejecutando la **Fase 1** (los archivos de más de 900 líneas) en el siguiente paso? Puedes confirmar tu aprobación o indicarme si tienes alguna preferencia en el orden.
