# PLAN MAESTRO 25: AUDITORÍA ARQUITECTÓNICA TOTAL, MODULARIZACIÓN SEGURA POR CAPAS, CONSOLIDACIÓN DRY (CERO DUPLICACIÓN), OPTIMIZACIÓN DE PESO APK Y RECURSOS, E HIGIENE DE INGENIERÍA

> **Documento Técnico y Hoja de Ruta Arquitectónica — Versión 3.1 (`CHECKPOINT PARCIAL 6C-2 CERRADO — BLOQUE III FASE 9C SUB-LOTE 9C-2 CERTIFICADO`)**  
> **Proyecto:** MochilaLista POS Comercial (`app_movil/`) & MochilaLista Admin Platform (`mochilalista_admin/`)  
> **Línea Base Certificada:** Rama `dev/mejoras-v9.0-comercializacion-seguridad` tras el cierre de los Planes Maestros 23 (`e84583a`), 23.5 (`09a84df`) y 24 (`fffb329`) — **`1,693/1,693` pruebas en verde** (`255/255` en `mochilalista_admin/` y `1,438/1,438` en `app_movil/`), motor QR ISO/IEC 18004 V1–V40 en `qrcode.min.js`, `owner_commercial_defaults.dart`, Inspector Tri-Protocolo (`ML9`/`MLS1`/`MLC1`) y `compilar_release_dual.bat` con `--init-notes` operativos.  
> **Objetivo Estratégico:** Eliminar la fragilidad de los archivos monolíticos extensos (`> 800–1,000` líneas tanto en código reciente como heredado), organizar el código en capas cohesivas, consolidar lógica duplicada bajo una sola fuente de verdad (DRY), corregir bugs latentes y código muerto detectados, optimizar de forma realista el peso del APK (incluyendo emisión Universal ARM física `~70.6 MB` aprobada por el propietario) y el consumo de recursos (RAM/CPU/DOM), e incorporar los 4 pilares de higiene técnica (`Problems = 0` en PowerShell, `.gitattributes`, caché-busting unificado `?v=25` y `ARQUITECTURA_MODULAR.md`), **preservando el 100 % de las funciones, contratos de datos, pruebas e interfaces existentes**.

---

## SECCIÓN 1 — RADIOGRAFÍA REAL DEL REPOSITORIO (CENSO DE ARCHIVOS > 800 / 1,000 LÍNEAS)

El censo programático completo ejecutado en modo solo lectura sobre todo el código fuente del repositorio (excluyendo `build/`, `.dart_tool/`, `.git/`, `backups/`, `releases_apks/`, `qrcode.min.js` y `jsqr.min.js`) arroja la siguiente distribución exacta:

### 1.1 Resumen Cuantitativo por Área del Repositorio

| Área / Subproyecto | Archivos | Líneas Totales | Archivos `>= 500` L | Archivos `>= 800` L | Archivos `>= 1,000` L |
|---|---:|---:|---:|---:|---:|
| **`mochilalista_admin/` — Fuente** (`.dart`, `.js`, `.css`, `.html`, `.bat`) | `17` | `42,788` | `12` | **`11`** | **`9`** |
| **`mochilalista_admin/test/`** (`.dart`, `255` tests) | `52` | `20,051` | `15` | `3` | `0` |
| **`app_movil/lib/`** (`.dart`, fuente móvil) | `474` | `228,231` | `141` | **`84`** | **`63`** |
| **`scripts/` y raíz** (`.ps1`, `.bat`) | `6` | `1,281` | `1` | **`1`** | `0` |
| **Total Fuente Productivo (`admin_src` + `app_movil/lib` + `scripts_root`)** | **`497`** | **`272,300`** | **`154`** | **`96`** | **`72`** |

*(Nota: `app_movil/test/` aporta adicionalmente `145` archivos de prueba `.dart` que ejecutan la batería móvil de `1,438` casos.)*

---

### 1.2 Censo Completo de `mochilalista_admin/` y `scripts/` (Ordenado por Líneas)

| # | Ruta Exacta | Líneas | Bytes | Capa / Responsabilidades Mezcladas Actualmente |
|---:|---|---:|---:|---|
| 1 | `mochilalista_admin/web/js/admin_app.js` | **15,969** | 690,830 | **Monolito Frontend Total:** interceptor `fetch` PIN 423, navegación, tema, Sandbox/Prod, Dashboard SVG, CRM, Generador Ed25519, Canvas Credenciales/Boletas/Facturas + PDF 1.4, Drawer 360°, Sync `.mlsync`, Compositor WA, Releases/Matriz/Guía Dual, Inspector Tri-Protocolo, Finanzas/Backups, Settings 4 tabs, Emisor `MLC1`/Dart, Excel y Bóveda/Kit Rescate (`328` funciones). |
| 2 | `mochilalista_admin/web/css/styles.css` | **7,399** | 150,529 | **Monolito CSS Total:** variables dark + `144` reglas `[data-theme="light"]` intercaladas por bloques históricos + `10` bloques `@media` (responsive + `@media print`) dispersos a lo largo de 7,399 líneas. |
| 3 | `mochilalista_admin/web/index.html` | **4,825** | 342,528 | **Monolito DOM Total:** Shell sidebar/header + 8 pestañas (`#tabDashboard`..`#tabSecurityVault`) + 17 modales (`#modalCreateClient`..`#modalCommercialConfigSync`) + `#drawerClient360` + `#printableEmergencyKit`. |
| 4 | `mochilalista_admin/server.dart` | **3,220** | 117,150 | **Monolito HTTP & Bootstrap:** arranque CLI, lectura de configuración de modo inicial, middleware PIN (`423` + cookies `HttpOnly`), enrutador monolítico de ~50 endpoints `/api/*`, helpers de verificación APK, selector nativo PowerShell de carpetas y servidor estático. |
| 5 | `mochilalista_admin/lib/database_service.dart` | **2,750** | 101,865 | **Monolito DB JSON + Finanzas + Backups + Releases:** persistencia dual Sandbox/Prod, snapshots/rotación, CRUD clientes, sync `MLS1`, migración hardware, pagos + correlativos `BOL`/`FAC`, exportación CSV clientes/finanzas, backups manuales/preview/restore y catálogo de releases/matriz. |
| 6 | `mochilalista_admin/lib/apk_inspector_service.dart` | **1,871** | 63,895 | **Monolito Forense APK:** modelos DTO (`ApkSearchDirConfig`, `ApkDetectionReport`, `ApkInspectionResult`), caché persistente JSON con cola serializada, canonicalización de rutas, escáner BFS de directorios, lectura ZIP/ABIs, ejecución `aapt2`/`apksigner` y lector de notas compañeras `_atp.txt`/`_atp_cambios.txt`. |
| 7 | `mochilalista_admin/lib/config_service.dart` | **1,401** | 55,720 | **Monolito Configuración:** reglas anti-rutas prohibidas APK, catálogo por defecto de 10 ítems, 9 plantillas WA, correlativos `BOL`/`FAC`, normalización de esquemas legados, motor de snapshots/rotación y deep-merge. |
| 8 | `mochilalista_admin/lib/vault_storage_service.dart` | **1,135** | 40,802 | **Monolito Bóveda & Sesiones:** orquestación DPAPI + espejo `%APPDATA%` + nube local, auditoría SHA-256 de 5 archivos críticos, exportación/importación `.mlvault`, gestión de PIN/sesiones en memoria y validación de rutas de nube. |
| 9 | `mochilalista_admin/lib/commercial_config_sync_service.dart` | **1,042** | 37,061 | **Monolito `MLC1` + Export Dart:** canonicalización JSON, firma/verificación Ed25519 `MLC1-...`, validador estricto de esquema `v == 1`, diff vs `owner_config` y generador completo de `owner_commercial_defaults.dart`. |
| 10 | `mochilalista_admin/lib/excel_export_service.dart` | **990** | 42,023 | **Generador Excel Multi-Hoja:** generación de libro maestro (5 hojas) y reporte financiero filtrado + estilos/paletas inline. |
| 11 | `mochilalista_admin/lib/vault_crypto_service.dart` | **874** | 29,892 | **Motor Cripto Bóveda:** modelos `VaultKeyring`/`RescueKitResult`, KDF PBKDF2 (`100,000` iter.), slots DPAPI/`.mlkey`/Rescate/QR/PIN y empaquetado cifrado `.mlvault`. |
| 12 | `scripts/compilar_release_dual.ps1` | **889** | 45,976 | **Compilador Dual Guiado:** CLI flags, descubrimiento Build-Tools, pre-chequeos, `flutter analyze`/`build` Universal + ARM64, auditoría `aapt2` + `apksigner`, resumen y `--init-notes` (con 6 verbos no aprobados por `PSScriptAnalyzer`). |
| 13 | `mochilalista_admin/lib/client_sync_service.dart` | 570 | 19,783 | Protocolo `MLS1-...` / `.mlsync` (en tamaño sano `< 600` L; candidato menor a compartir normalización de fechas/planes). |
| 14 | `mochilalista_admin/lib/license_signer.dart` | 318 | 11,822 | Firma Ed25519 `ML9-...` y lectura de claves maestras. |
| 15 | `mochilalista_admin/lib/dpapi_service.dart` | 174 | 6,030 | Envoltura Windows DPAPI vía PowerShell. |
| 16 | `mochilalista_admin/lib/time_utils.dart` | 144 | 5,090 | `PeruTimeHelper` (`America/Lima`, GMT-5). |
| — | Scripts `.bat` / `.ps1` auxiliares (`Iniciar_MochilaLista_Admin.bat`, `compilar_apk_*.bat`, `compilar_release_dual.bat`, `Crear_Acceso_Directo_Escritorio.ps1`, `admin_server.bat`) | `14..143` | — | Lanzadores Windows en tamaño compacto (`<= 143` L). |

---

### 1.3 Censo de Monolitos en `app_movil/lib/` (`84` archivos `>= 800` L, `63` archivos `>= 1,000` L)

#### Top 35 Archivos Más Grandes en `app_movil/lib/` (Todos `>= 1,338` líneas)

| # | Ruta Exacta (`app_movil/lib/...`) | Líneas | Bytes | Responsabilidades Mezcladas Actualmente |
|---:|---|---:|---:|---|
| 1 | `features/auth/screens/license/license_status_and_activation_screen.dart` | **4,769** | 183,613 | Pantalla principal + catálogo comercial + tarjetas bancarias + parser `ML9`/`MLC1` + escáner QR + `PlanDetailBottomSheet` + `OrderPlanBottomSheet` + helpers WhatsApp/portapapeles. |
| 2 | `features/smart_quotation/widgets/crm/client_finance_actions_modal.dart` | **4,209** | 168,713 | DTOs de borrador (`FinanceWithdrawDraft`, `FinanceLoanDraft`, `ClientFinanceDraftManager`) + 3 pestañas completas (Abono, Préstamo con cronograma editable, Retiro) + formateador español propio. |
| 3 | `features/smart_quotation/services/client_service.dart` | **3,065** | 107,591 | CRUD clientes + Ledger 360° + recálculo deuda/saldo/entregas + edición/reversión pagos + motor completo de fidelización/metas/recompensas/reputación + retiros/préstamos. |
| 4 | `features/smart_quotation/services/sales_service.dart` | **2,680** | 101,745 | Transacción venta/POS + historial/estadísticas + anulación atómica/restauración + morosidad manual/automática + sincronización notificaciones de cuotas. |
| 5 | `features/smart_quotation/screens/crm/loyalty_center_screen.dart` | **2,636** | 108,061 | 3 pestañas complejas (Reputación, Metas/Premios, Difusión Ofertas), dock audiencia, tarjetas de clientes/premios/metas y filtros. |
| 6 | `features/analytics/screens/commercial_radar_screen.dart` | **2,607** | 102,831 | Pantalla Radar + `SliverPersistentHeaderDelegate` + cards pulso/noticias + modal completo `LocationPickerSheet` (distritos/provincias Perú) + launcher URL. |
| 7 | `features/scanner/screens/invoice_detail_screen.dart` | **2,295** | 115,592 | Vista dividida `MultiSplitView` + visor foto + visor JSON crudo + buscador proveedor + editor estados + hoja descarga/exportación. |
| 8 | `features/analytics/screens/predictive_analytics_screen.dart` | **2,267** | 92,920 | Simulador "¿Qué pasa si...?" + gráfico patrimonio + tarjetas diagnóstico + 4 modales explicativos internos. |
| 9 | `features/profile/screens/notifications_screen.dart` | **2,257** | 96,844 | Bandeja agrupada por cliente + acciones rápidas cobranza/abastecimiento/kardex + modales detalle/menú + filtros temporales/categoría. |
| 10 | `features/smart_quotation/screens/pdf_preview_screen.dart` | **1,961** | 110,724 | Visor zoom interactivo + selector formato/tema PDF + modal completo de personalización de diseño PDF (`~1,000` L en un solo método). |
| 11 | `features/smart_quotation/widgets/manual/manual_quote_detail_modal.dart` | **1,920** | 83,649 | Editor detallado de ítem manual + selector variante + cálculo descuento/precio/stock máximo. |
| 12 | `core/widgets/omni_search_bar.dart` | **1,902** | 75,836 | Barra trigger + modal `_OmniSearchSheet` + motor SQL/Dart sin tildes + scoring + 4 tipos de cards (`Product`, `Client`, `Quote`, `Sale`) + 6 ítems polimórficos. |
| 13 | `features/smart_quotation/screens/quotation_detail_screen.dart` | **1,870** | 66,189 | Detalle de cotización + motor validación stock/precios + conversión a pack + renombrado/evidencia/estado + header sliver. |
| 14 | `features/profile/screens/profile_screen.dart` | **1,790** | 69,775 | Perfil usuario/negocio + foto + tarjeta legal EULA + menú configuración + selector cámara/galería + cierre de sesión. |
| 15 | `features/smart_quotation/models/crm_models.dart` | **1,759** | 58,652 | `15` clases de dominio mezcladas (`ClientModel`, `PaymentModel`, `SaleSummary`, `InstallmentModel`, `SaleModel`, `SalesStatsModel`, `BundleChange`, `ValidationResult`, `LedgerItem`, `ReputationTier`, etc.). |
| 16 | `features/scanner/widgets/staging/variant_editor_row.dart` | **1,727** | 84,961 | Fila compleja de staging factura + matemática compra/margen + panel balance stock + cupo mixto + `MiniInput`/`ResumenTag`. |
| 17 | `features/smart_quotation/widgets/matching/product_quote_detail_modal.dart` | **1,720** | 68,190 | Modal detalle en matching de cotizaciones + cálculo márgenes/variantes. |
| 18 | `features/catalog/screens/catalog/catalog_screen.dart` | **1,689** | 67,409 | Catálogo cliente/tienda + carrito + ordenamiento + filtros + tarjetas rápidas. |
| 19 | `features/analytics/screens/smart_restock_screen.dart` | **1,657** | 67,502 | Pantalla de reabastecimiento inteligente + alertas agotamiento + generador orden compra. |
| 20 | `features/profile/widgets/google_drive_backup_sheet.dart` | **1,648** | 70,332 | Hoja Drive completa: autenticación Google, listado versiones nube, subida/descarga/restauración y formateo fecha propio. |
| 21 | `features/smart_quotation/widgets/history/detail_widgets/cuota_morosidad_modal.dart` | **1,612** | 62,334 | Modal configuración/aplicación de mora manual/automática en cuotas. |
| 22 | `features/smart_quotation/widgets/quick_sale/quick_sale_detail_modal.dart` | **1,606** | 69,409 | Modal detalle de ítem en Caja Rápida + variantes y stock. |
| 23 | `features/catalog/widgets/variants/variant_extract_config_modal.dart` | **1,594** | 70,124 | Modal extracción/corte/copia de variantes a nuevo producto. |
| 24 | `features/auth/screens/onboarding/profile_selection_screen.dart` | **1,535** | 54,866 | Selector/creador/restaurador de perfiles locales + PIN + flujo arranque. |
| 25 | `features/smart_quotation/widgets/crm/client_loyalty_history_modal.dart` | **1,525** | 67,322 | Modal historial de puntos, reputación y premios del cliente. |
| 26 | `core/widgets/product_detail_modal.dart` | **1,467** | 68,124 | Modal universal de detalle rápido de producto. |
| 27 | `core/providers/notification_provider.dart` | **1,462** | 59,089 | Motor de generación/agrupación/silenciamiento de alertas stock, cuotas y cotizaciones. |
| 28 | `core/widgets/home/smart_action_grid.dart` | **1,455** | 56,996 | Grilla inteligente de acciones en Home + tarjetas KPI + accesos directos. |
| 29 | `core/database/local_db.dart` | **1,450** | 73,528 | Conexión SQLCipher/FFI + snapshot rollback + migraciones `v19 -> v36` + `_createDB` `v36` + seeds de fidelización/notificaciones/licencia. |
| 30 | `features/smart_quotation/widgets/crm/payment_entry_modal.dart` | **1,446** | 60,387 | Modal de registro/edición de abonos de clientes. |
| 31 | `features/analytics/services/commercial_radar_service.dart` | **1,417** | 59,359 | Motor de fuentes RSS/noticias comerciales + análisis regional Perú. |
| 32 | `features/scanner/providers/scanner_provider.dart` | **1,405** | 54,081 | Estado de escaneo IA de facturas + cola + matching + staging. |
| 33 | `features/catalog/repositories/product_repository.dart` | **1,395** | 53,737 | CRUD productos/presentaciones + consultas stock compartido + auditoría columnas SQL. |
| 34 | `features/smart_quotation/screens/whatsapp_preview_screen.dart` | **1,346** | 56,932 | Editor/vista previa de mensajes WhatsApp + adjuntos/ubicación + envío `wa.me`. |
| 35 | `features/promotions/screens/bundle_builder_screen.dart` | **1,338** | 61,479 | Constructor de packs/ofertas promocionales + fechas + descuentos. |

*(Los restantes **49** archivos entre `800` y `1,337` líneas en `app_movil/lib/` incluyen piezas críticas como `sale_financial_detail_screen.dart` [1,333], `stock_update_modal.dart` [1,335], `scan_screen.dart` [1,303], `analytics_dashboard_screen.dart` [1,274], `quick_sale_screen.dart` [1,269], `matching_screen.dart` [1,262], `onboarding_screen.dart` [1,254], `product_create_operations.dart` [1,250], `presentation_stock_section.dart` [1,239], `sale_provider.dart` [1,236], `product_edit_screen.dart` [1,229], `products_tab.dart` [1,227], `pdf_generator.dart` [1,217], `audit_trail_screen.dart` [1,204], `commercial_radar_card.dart` [1,200], `inventory_provider.dart` [1,174], `ai_settings_screen.dart` [1,167], `backup_screen.dart` [1,144], `product_stock_strategy_selector.dart` [1,128], `staging_product_group_card.dart` [1,108], `matching_item_row.dart` [1,106], `ledger_timeline_tab.dart` [1,072], `loyalty_whatsapp_service.dart` [1,031], `live_filter_bottom_sheet.dart` [1,031], `client_full_stats_modal.dart` [1,029], `presentation_math_engine.dart` [1,020], `analytics_provider.dart` [1,006], `price_update_modal.dart` [1,003], además de 21 archivos entre `800–999` líneas.)*

#### Directorios Sobrecargados o Desbalanceados en `app_movil/lib/`

| Directorio | Archivos | Líneas | Diagnóstico Estructural |
|---|---:|---:|---|
| `lib/features/smart_quotation/widgets` | **80** | 43,084 | Mezcla CRM (`crm/`), historial (`history/`), caja rápida (`quick_sale/`), WhatsApp (`whatsapp/`), cotización manual (`manual/`), matching (`matching/`), checkout (`checkout/`) y modales raíz. Muchos modales rebasan `1,500–4,200` L. |
| `lib/core/widgets` | **107** | 33,470 | Sobrecargado: mezcla layout de Home (`home/`), tour (`tour/`), tarjetas de presentación (`presentation_card/`), buscador omnicanal (`omni_search_bar.dart`, `1,902` L) y decenas de modales/tarjetas de catálogo que pertenecen a `shared/` o `catalog/`. |
| `lib/features/smart_quotation/screens` | **22** | 19,177 | Mezcla 3 dominios distintos bajo `smart_quotation`: **CRM/Fidelización** (`crm/`), **POS/Caja Rápida/Ventas** (`quick_sale_screen`, `sales_checkout_screen`, `sales_history_screen`) y **Cotizaciones/PDF/WhatsApp**. |
| `lib/features/auth/screens` | **11** | 11,300 | Concentrado principalmente en `license_status_and_activation_screen.dart` (`4,769` L) y `profile_selection_screen.dart` (`1,535` L). |
| `lib/features/catalog/widgets` | **28** | 10,462 | Sub-carpetas `form/`, `edit/`, `detail/`, `variants/` bien encaminadas, pero con modales extensos (`1,128–1,594` L). |

---

## SECCIÓN 2 — AUDITORÍA DE DUPLICACIÓN (DRY), BUGS LATENTES Y CÓDIGO MUERTO

### 2.1 Hallazgos en `mochilalista_admin/` (Backend Dart + Frontend JS/CSS/HTML)

| ID | Categoría | Ubicación Exacta (Archivo:Línea) | Evidencia Real & Impacto | Fuente Única de Verdad Planificada |
|---|---|---|---|---|
| **D-ADM-01** | **Bug / Colisión JS** | `admin_app.js:1220` (`compareSemVer(v1, v2)`) **vs** `admin_app.js:6997` (`compareSemVer(a, b)`) **+ Dart** `server.dart:173` (`parse`) y `apk_inspector_service.dart:452` | **Dos definiciones globales de `compareSemVer` en `admin_app.js`:** la de `:6997` (que compara `+build`) **sobrescribe silenciosamente** por hoisting a la de `:1220` (que descarta `+build`), haciendo que `:1220` sea código muerto sombreado y un riesgo grave de comportamiento distinto al separar módulos. | `js/core/semver.js` (una sola `compareSemVer`) y `lib/core/semver_utils.dart`. |
| **D-ADM-02** | **Bug Real CSV** | `database_service.dart:2536-2561` (`exportClientsToCsv`) **vs** `:1440-1448` (`_escapeCsvCell`) & `:1511-1561` (`exportFinancesToCsv`) | `exportFinancesToCsv()` usa `_escapeCsvCell` (RFC-4180 + limpieza `\r\n`), pero `exportClientsToCsv()` (línea `2557`) interpola en crudo 13 de 14 campos (`business_name`, `owner_name`, `document_id`, `phone`, etc.) y solo reemplaza `"` en `notes` **sin sanitizar `\r`/`\n`**. Cualquier comilla o salto de línea corrompe las filas del CSV en Excel. | `lib/core/csv_utils.dart` (`CsvCellEscaper.escapeCell`, usado por todos los exportadores). |
| **D-ADM-03** | **DRY Portapapeles** | `admin_app.js:6973` (`copyPlainTextToClipboard` con fallback `execCommand`) **vs** `:1658, 1889, 1902, 3245, 5005, 9235, 12809, 12996, 14807, 14814, 14824, 14833, 14853` | **13+ llamadas directas** a `navigator.clipboard.writeText(...)` sin el fallback `textarea + execCommand('copy')`, duplicando lógica y degradando compatibilidad en contextos locales sin foco o clipboard restringido. | `js/core/clipboard.js` (`copyPlainTextToClipboard` y `copyPngBlobToClipboard`). |
| **D-ADM-04** | **DRY / Bug TZ Lima** | `admin_app.js:5514, 5560` (`formatLimaDateTime`, `formatLimaIsoDate`) **vs** `:1254` (`getLocalIsoDate`), `:3154, 3532, 3723` (`toLocaleString/Date('es-PE')`) **+ Dart** `config_service.dart:936-945` **vs** `time_utils.dart:106` | `getLocalIsoDate` y los formatos de canvas/recibos (`:3154, 3532, 3723`) dependen del reloj/TZ del navegador sin forzar `timeZone: 'America/Lima'`. En Dart, `config_service.dart:936-945` reconstruye a mano `y, m, d, h, min, s, ms, us` en lugar de usar `PeruTimeHelper.formatLimaFilenameTimestamp()`. | `js/core/time_lima.js` (`formatLimaDateTime`, `formatLimaIsoDate`, `formatLimaReceiptStamp`) y `lib/core/time_utils.dart`. |
| **D-ADM-05** | **DRY Planes & Teléfonos** | `admin_app.js:1274` (`formatPlanHumanLabel`) **vs** `:6308` (`formatPlanLabel`); `:42` (`normalizePeruPhone`) **vs** `:1261` (`formatPeruvianPhoneDisplay`) | Dos formateadores distintos para etiquetas de planes y dos normalizadores de teléfono Perú en JS, además de `DatabaseService.normalizePeruPhone` (`database_service.dart:279`). | `js/core/formatters.js` (`formatPlanHumanLabel` + alias `formatPlanLabel`, `normalizePeruPhone`) y `lib/core/commercial_constants.dart`. |
| **D-ADM-06** | **DRY WhatsApp URIs** | `admin_app.js:853, 3299, 8771, 8819, 13010, 14570` (`api.whatsapp.com/send`) **vs** `:4290, 6625, 6782` (`wa.me/`) | Construcción manual de URLs WhatsApp en 9 sitios con mezcla de dominios (`api.whatsapp.com` vs `wa.me`) y concatenaciones repetidas de `encodeURIComponent`. | `js/core/whatsapp.js` (`buildWhatsAppSendUrl`). |
| **D-ADM-07** | **DRY UI Tarjeta Rescate** | `admin_app.js:5962-6000` (`analyzeGlobalSync`) **vs** `:11081-11112` (`renderInspectClientSync`) | Bloque HTML completo `.sync-migration-rescue-card` (`bhw -> hw`) copiado casi línea por línea entre el modal de sincronización global y el Inspector Tri-Protocolo. | Helper compartido `renderMigrationRescueCard(...)` en `js/modules/client_sync.js` o `js/core/ui_components.js`. |
| **D-ADM-08** | **DRY Rotación Backups** | `database_service.dart:154-236` **vs** `config_service.dart:932-1012` | Ambos servicios implementan independientemente `_createBackupSnapshot` y `_cleanOldSnapshots` (listado, filtrado de prefijos protegidos, ordenamiento descendente y purga `> 30`). | `lib/core/backup_rotation_helper.dart`. |
| **D-ADM-09** | **Seguridad Path Estático** | `server.dart:3170-3220` (`_handleStaticFile`) | Construye `String filePath = path == '/' ? 'web/index.html' : 'web$path'` sin validar contención canónica dentro de `Directory('web')` (mientras `/api/releases/*` y `/api/backups/*` sí aplican canonicalización estricta). | `lib/http/static_handler.dart` con validación `isPathWithinDirectory(webRoot, resolved)` y bloqueo `..` / `%2e%2e`. |
| **D-ADM-10** | **Rendimiento I/O & DOM** | `server.dart` (`13` llamadas `existsSync`/`resolveSymbolicLinksSync`), `apk_inspector_service.dart` (`9`), `database_service.dart` (`5`), `admin_app.js:1467-1655` (`renderClientsTable`) | I/O síncrono dentro de rutas HTTP `async` que puede bloquear el *event loop* de Dart cuando hay rutas de disco lentas o de red; en JS, `renderClientsTable` hace `tbody.appendChild(tr)` fila por fila dentro de `.forEach` sin `DocumentFragment`. | Migrar `existsSync` en handlers HTTP a `await file.exists()` y usar `DocumentFragment` en renders masivos de tablas. |

---

### 2.2 Hallazgos en `app_movil/` (Código Reciente + Heredado)

| ID | Categoría | Ubicación Exacta (`app_movil/...`) | Evidencia Real & Impacto | Fuente Única de Verdad / Remediación |
|---|---|---|---|---|
| **D-MOV-01** | **DRY Moneda (`0` usos)** | `lib/core/utils/currency_formatter.dart:1-17` (`AppCurrency.format`) **vs** **`267`** `'S/ '` manuales en `lib/` + `_formatCurrency` duplicado en `analytics_dashboard_screen.dart:260` y widgets `charts/` / `dashboard/` | Existe `AppCurrency.format` en `core/utils/`, pero tiene **`0` usos reales** en todo `lib/`. Cada pantalla/tarjeta implementa `S/ ${val.toStringAsFixed(2)}` o `_formatCurrency` por su cuenta. | Adoptar `AppCurrency.format(...)` como única fuente de verdad en `core/utils/currency_formatter.dart`. |
| **D-MOV-02** | **DRY + CPU Fechas** | `97` ocurrencias de `DateFormat(...)` + `_formatDateSpanish` duplicado en `client_finance_actions_modal.dart:450` y `audit_trail_screen.dart:240` + `_formatDateTime`/`_formatDate` en `google_drive_backup_sheet.dart:785`, `license_activation_feedback_modal.dart:52` | Se instancian objetos `DateFormat(...)` repetidamente dentro de `build()` y builders de listas (`recent_activity_list.dart`, `notification_item_card.dart`, etc.), y se duplican implementaciones manuales de meses en español. | `lib/core/utils/app_date_formatter.dart` con `DateFormat` estáticos cacheados y formatos peruanos canónicos. |
| **D-MOV-03** | **DRY Portapapeles** | **`22`** llamadas directas `Clipboard.setData(...)` repartidas en `license_status_and_activation_screen.dart`, `license_locked_screen.dart`, `profile_screen.dart`, etc. | Duplicación de `Clipboard.setData`, `HapticFeedback` y snackbar/toast de confirmación. | `lib/core/utils/clipboard_helper.dart` (`ClipboardHelper.copyWithFeedback`). |
| **D-MOV-04** | **Bug Real WhatsApp URI** | **`10+`** sitios `wa.me/` (`client_tracking_screen.dart:279`, `client_card.dart:34`, `whatsapp_preview_screen.dart:1333`, `cuota_reminder_modal.dart:83`, `whatsapp_preview_modal.dart:434`, `loyalty_whatsapp_service.dart:38`, etc.) | `client_tracking_screen.dart:279`, `client_card.dart:34` y `whatsapp_preview_screen.dart:1333` anteponen `"51"` ciegamente (`"https://wa.me/51${client.phone...}"`), produciendo teléfonos rotos `5151...` o `51+51...` si el cliente ya tiene `+51` o `51`, y `whatsapp_preview_screen.dart:1333` no aplica `Uri.encodeComponent` en esa línea. | `lib/core/utils/whatsapp_uri_builder.dart` + `PeruPhoneNormalizer` (normalización `+51` segura y `Uri.encodeComponent` garantizado). |
| **D-MOV-05** | **DRY Feedback UI** | `showSnackBar(` (**`88`** ocurrencias) **vs** `NotificationToastFeedback` (**`31`** ocurrencias) | Coexistencia inconsistente entre `ScaffoldMessenger.of(context).showSnackBar` crudo y toasts personalizados en 15+ pantallas y operaciones. | `lib/core/utils/app_feedback_helper.dart`. |
| **D-MOV-06** | **Rendimiento Imágenes & Listas** | `lib/core/widgets/universal_image.dart:115-124`, `dashboard_header.dart:514`, `sale_financial_detail_screen.dart:1258`, `pdf_preview_screen.dart:1932`, **`0`** `cacheWidth`, **`39`** `shrinkWrap: true`, **`155`** `SingleChildScrollView` | `UniversalImage.build()` llama `file.existsSync()` sincrónico en el hilo UI en cada rebuild y carga `Image.file` sin `cacheWidth`/`cacheHeight` (decodificando imágenes de cámara de alta resolución completas para miniaturas). Múltiples modales usan `shrinkWrap: true` anidados que anulan el reciclado de viewport. | Agregar `cacheWidth`/`cacheHeight` calculados según tamaño lógico × DPR, sacar `existsSync` de `build()` y convertir listas internas largas a `SliverList` / `ListView.builder`. |
| **D-MOV-07** | **Código Muerto / Huérfano** | 1) `features/profile/screens/business_backup_screen.dart` (2 L)<br>2) `core/widgets/safe_dropdown.dart` (81 L)<br>3) `core/widgets/super_switch.dart` (75 L)<br>4) `features/profile/widgets/team/access_codes_tab.dart` (235 L) y `team_members_tab.dart` (337 L)<br>5) `AndroidManifest.xml:33` (`com.google.android.geo.API_KEY`)<br>6) `pubspec.yaml:14` (`cupertino_icons: ^1.0.8`) | **Verificado por búsqueda global en `lib/` y `test/`:** `0` importaciones de `business_backup_screen.dart`, `safe_dropdown.dart`, `super_switch.dart`, `access_codes_tab.dart` y `team_members_tab.dart`; `0` usos de `CupertinoIcons` en todo el código Dart; `AndroidManifest.xml:33` contiene placeholder muerto de Google Maps cuando la app usa `flutter_map` (OpenStreetMap). | **APROBADO por propietario:** remover en Fase 6 los 5 archivos huérfanos (`730` L totales, respaldados en historial Git) + limpiar `com.google.android.geo.API_KEY`; remover `cupertino_icons` en Fase 10 (`-116 KB` en APK). |

---

## SECCIÓN 3 — MAPA DE CONTRATOS DE PRUEBAS & PROTOCOLO ANTI-REGRESIÓN DE 9 PUNTOS

### 3.1 Inventario Exacto de Suites Acopladas a Archivos Monolíticos

#### A. En `mochilalista_admin/test/` (`52` archivos, `255` tests)

El análisis estático de los 52 archivos de prueba detectó que:
* **`34` de `52` archivos** leen directamente activos reales de `web/` (`web/index.html`, `web/css/styles.css`, `web/js/admin_app.js` y/o `qrcode.min.js`/`jsqr.min.js`; el hallazgo `#35` del primer grep, `apk_inspector_and_releases_test.dart:153`, corresponde únicamente a una entrada sintética `'assets/index.html'` dentro de un ZIP simulado).
* **`29` archivos** importan `../server.dart` e invocan `handleRequest(...)` o `applyStartupModeFromConfig(...)`.
* **`14` archivos** ejecutan **`node`** en tiempo real extrayendo bloques entre marcadores de `admin_app.js` o validando sintaxis (`node --check`), concretamente dependientes de:
  * **Marcadores JS contractuales críticos:**
    * `function formatApkSizeMb(` .. `function renderSignatureStatusBadge(` (`releases_matrix_and_ui_test.dart`, `plan22_fase2_releases_matrix_catalog_test.dart`, `plan22_fase3_wa_composer_test.dart`, `plan23_5_fase2_mlc1_inspector_ui_test.dart`, `plan23_5_fase4_release_guide_ui_test.dart`, `plan23_fase2_settings_and_templates_test.dart`, `plan23_fase3_mlc1_desktop_emitter_test.dart`, `plan24_fase2_mlc1_modal_ui_and_inspector_test.dart`, `plan24_fase3_dart_defaults_export_test.dart`)
    * `let isVerifyAllCatalogRunning = false;` .. `/**\n * Carga notas compañeras` (`plan23_5_fase2`, `plan23_5_fase4`, `plan23_fase6_apk_cache_verify_all_test.dart`, `plan24_fase3`)
    * `// =================== 5. INSPECTOR FORENSE DUAL` .. `// =================== 6. FINANZAS` (`plan22_fase4`, `plan23_5_fase2`, `plan23_5_fase4`, `plan24_fase2`, `plan24_fase3`)
    * `// =================== 8. CENTRO DE PERSONALIZACIÓN TOTAL` .. `// =================== 9. EXPORTACIÓN A MICROSOFT EXCEL` (`plan23_fase2`, `plan23_fase3`)
    * `// =================== 3B. COMPOSITOR UNIVERSAL DE WHATSAPP` .. `// =================== 4. RELEASE MANAGER` (`plan22_fase3`)
    * `function showToast(` .. `let confirmCallback = null;` (`plan22_fase2`, `plan22_fase4`)
    * `function formatLimaDateTime(` .. `analyzeSyncReported` (`plan22_fase4`, `client_offline_sync_and_migration_test.dart`)
    * Funciones QR en `admin_app.js` + `qrcode.min.js` + `jsqr.min.js` (`plan24_fase1_qr_and_updates_test.dart`, `plan24_fase5_cross_parity_test.dart`)
  * **Marcadores HTML contractuales:** secciones por `id="tab..."`, `id="modal..."`, `id="drawerClient360"` hasta `<script src="js/admin_app.js` (`plan23_fase1`, `plan24_fase2`), y verificación explícita `href="css/styles.css?v=23"` / `src="js/admin_app.js?v=23"` en `plan23_fase2_settings_and_templates_test.dart:334-335`.
  * **Scripts PowerShell/Bat:** `admin_backup_rotation_test.dart:195`, `fase1_plan18_launcher_and_browser_test.dart:50,86`, `fase2_plan18_license_generator_test.dart:124`, `fase6_plan18_finances_excel_and_closure_test.dart:283`, `plan23_5_fase3_dual_compiler_test.dart`, `plan24_fase4_init_notes_test.dart` (verificando BOM `EF BB BF` y salida CLI `--dry-run`/`--help`/`--verify-only`, **ninguno** depende de nombres internos de las 6 funciones privadas de `compilar_release_dual.ps1`).

#### B. Estrategia de Loaders Unificados en `mochilalista_admin/test/` (Migración Temprana en Fase 0, Cero Debilitamiento de Aserciones)

1. Crear **`mochilalista_admin/test/support/web_bundle_loader.dart`** y **migrar los `34` archivos reales lectores de `web/` dentro de la propia Fase 0** (antes de dividir `index.html`, `styles.css` o `admin_app.js`), sumando además `test/plan25_fase0_hygiene_and_loader_test.dart` y certificando `258/258` en verde sobre los activos actuales:
   * `WebBundleLoader.loadHtml()` → durante la Fase 0 lee `web/index.html` y, a partir de Fase 3, invoca exactamente al mismo `HtmlTemplateAssembler.assemble('web')` que `server.dart` usa en producción para entregar `/` e `/index.html`, produciendo el documento HTML íntegro con orden determinista de `<link>` y `<script>`.
   * `WebBundleLoader.loadCss()` → lee `web/css/styles.css` en Fase 0 y, desde Fase 3, concatena los archivos CSS listados en el manifiesto determinista de `web/css/` en el orden estricto de cascada (`00_tokens.css` → `base` → `components` → `modules/*` → `90_light_theme.css` → `95_responsive.css` → `99_print.css`).
   * `WebBundleLoader.loadJs()` → lee `web/js/admin_app.js` en Fase 0 y, durante Fases 4–5B, concatena los módulos JS en el orden exacto de `<script>` en `index.html` (`core/*` → `state/store.js` → `modules/*` → `bootstrap.js`), conservando los encabezados de sección contractuales (`// =================== 5. INSPECTOR...`, etc.) y el orden de funciones puras (`formatApkSizeMb`..`renderSignatureStatusBadge`) para que **100 %** de los harnesses Node.js (`indexOf`, `substring`, extracción por llaves y `node --check` tanto sobre **cada `.js` individual** como sobre el **bundle concatenado completo**) continúen funcionando sin perder ni relajar una sola aserción.
   * Actualizar `plan23_fase2_settings_and_templates_test.dart:334-335` en Fase 3 para validar el nuevo manifiesto `?v=25` en lugar de `?v=23`.
2. **Retrocompatibilidad estricta de imports en `mochilalista_admin/lib/` (Fases 1 y 2):**
   * Al mover las implementaciones desde la raíz de `mochilalista_admin/lib/` hacia `lib/core/`, `lib/data/`, `lib/config/`, `lib/apk/`, `lib/sync/`, `lib/vault/` y `lib/export/`, se **conservarán archivos *barrel* livianos (`export '...';`) en todas las rutas originales** (`lib/database_service.dart`, `lib/config_service.dart`, `lib/apk_inspector_service.dart`, `lib/vault_storage_service.dart`, `lib/vault_crypto_service.dart`, `lib/commercial_config_sync_service.dart`, `lib/excel_export_service.dart`, `lib/license_signer.dart`, `lib/client_sync_service.dart`, `lib/dpapi_service.dart`, `lib/time_utils.dart`) para que los **`52` archivos de test existentes sigan compilando sin reescrituras masivas de `import`**.

#### C. En `app_movil/test/` (`145` archivos, `1,438` tests)

* **Dependencias de imports más frecuentes:** `auth_provider.dart` (`45` tests), `local_db.dart` (`41`), `inventory_provider.dart` (`36`), `crm_models.dart` (`34`), `product_model.dart` (`28`), `license_provider.dart` (`26`), `inventory_wrapper.dart` (`25`), `device_fingerprint.dart` (`23`), `quick_sale_provider.dart` (`22`), `smart_quotation_model.dart` (`21`), `tracking_provider.dart` (`19`), `ed25519_license_validator.dart` (`19`), `currency_formatter.dart` (`18`), `owner_legal_identity.dart` (`14`), `license_status_and_activation_screen.dart` (`12`).
* **Dependencias `Key(...)` / `ValueKey(...)` contractuales:** `btn_mlc1_dialog_apply`, `btn_mlc1_dialog_cancel`, `dialog_mlc1_confirm_apply`, `dialog_mlc1_reset_confirm`, `switch_locked_include_license_ref`, `btn_locked_whatsapp`, `btn_locked_share_mlsync`, `btn_apply_district`, `btn_use_province`, `coach_card_arrow`, `coach_card_body`, etc.
* **Estrategia de preservación 100 % en `app_movil/`:**
  * Todo modelo o clase pública extraída desde un archivo monolítico (por ejemplo clases secundarias de `crm_models.dart`, o `PlanDetailBottomSheet` / `OrderPlanBottomSheet` desde `license_status_and_activation_screen.dart`, o `LocationPickerSheet` desde `commercial_radar_screen.dart`) mantendrá un **`export '...'`** en el archivo original (patrón Barrel / Facade) y conservará exactamente todas sus `ValueKey(...)` / `Key(...)` públicas para garantizar compatibilidad binaria/fuente con los `145` archivos de test existentes.
  * Para `local_db.dart`, `client_service.dart`, `sales_service.dart` y `product_repository.dart`, la modularización interna podrá utilizar `part` / `part of` o mixins/delegados privados preservando la API pública estática/instancia al 100 %.

---

### 3.2 Protocolo Obligatorio Anti-Regresión de 9 Puntos (Reglas de Oro del Plan 25)

1. **Extracción Pura Separada de Cambios de Lógica:** Toda división de un archivo monolítico se realiza primero mediante **extracción pura** (mover bloques idénticos sin alterar lógica ni firmas) y se valida contra toda la batería de tests; solo en un paso separado se consolida DRY, se corrigen bugs (`exportClientsToCsv`, `wa.me/51...`, `compareSemVer`) o se optimiza rendimiento.
2. **Prohibición de Truncamiento y Paridad de Símbolos ("Anti-Resumen"):** Antes y después de dividir cada archivo monolítico, se verificará el inventario de funciones/clases/endpoints/IDs DOM/`Key`s Flutter (`conteo antes == conteo después`). Queda **absolutamente prohibido** usar comentarios de omisión (`// ... resto igual ...`), eliminar validaciones de borde, o borrar/debilitar pruebas existentes.
3. **Arquitectura Web Zero-Bundler + Orden Determinista JS y Cascada CSS (`mochilalista_admin/web/`):**
   * Operación **100 % directa sobre `dart run server.dart`** (`http://localhost:8080` y Chrome `--app`) sin Webpack, Vite, Rollup ni compilación Node.js en producción.
   * **Orden estricto JS:** `js/core/` → `js/state/` → `js/modules/` → `js/bootstrap.js`, exponiendo explícitamente en `window` todas las funciones invocadas desde atributos inline `onclick="..."`/`onchange="..."` (`89` en HTML + `35` en JS), evitando colisiones `let`/`const` en ámbito global, listeners duplicados (`DOMContentLoaded` único) y caché obsoleta mediante `?v=25`.
   * **Orden estricto CSS:** `00_tokens.css` → `01_base_layout.css` → `02_components.css` → `modules/*.css` → **`90_light_theme.css` (`[data-theme="light"]`)** → **`95_responsive.css` (`@media` responsive)** → **`99_print.css` (`@media print`)**, preservando intactos el tema claro *Executive Slate* y la impresión A4 del Kit de Rescate.
   * Los parciales HTML de `web/partials/` serán ensamblados deterministamente en memoria por `server.dart` (`HtmlTemplateAssembler`), 100 % offline y sin alterar ningún `#id`, `name` ni `data-*`.
4. **Preservación de Middleware de Seguridad y Arranque:** Al dividir `server.dart` en routers por dominio, **ningún endpoint `/api/*`** podrá evadir el guardián PIN (`HTTP 423 Locked`), cookies `HttpOnly` (`vault_session_token`) ni la validación canónica anti *path-traversal* (incluyendo ahora `_handleStaticFile`). En `app_movil/lib/main.dart`, preservar íntegramente el orden de los 23 providers en `MultiProvider`, `@pragma('vm:entry-point') callbackDispatcher` e inicialización de `ApiConstants` / `Workmanager`.
5. **Inmutabilidad de Contratos, SQLite `v36` y Bóveda PIN:**
   * **PROHIBIDO** renombrar claves JSON en disco (`owner_config.json`, `prod_clients_db.json`, `prod_releases_db.json`, `.mlvault`, `.mlsync`), claves `SharedPreferences` (`ml_commercial_config_v1`), rutas `/api/...`, `#id` del DOM ni `Key(...)`/`ValueKey(...)` de Flutter.
   * **PROHIBIDO alterar el esquema SQLite `v36`** en `app_movil/lib/core/database/local_db.dart` (toda modularización vía `part` debe mantener 100 % idénticas tablas, columnas, índices y migraciones `v19 -> v36`).
   * **PROHIBIDO debilitar o alterar la seguridad de `app_movil/lib/features/auth/screens/onboarding/lock_screen.dart`**.
6. **Prevención de Imports Circulares y Estado Duplicado:** Una sola fuente de verdad (`core/` / `shared/`), prohibiendo estrictamente dependencias circulares entre módulos y duplicación de instancias de `ChangeNotifier` o cachés de estado en memoria.
7. **Clasificación de Riesgo en Optimizaciones APK (R8 / ProGuard / Dependencias):** Separar optimizaciones 100 % seguras (`--split-per-abi`, remoción de `cupertino_icons` sin uso, compresión lossless de PNGs, poda de código muerto y DRY) de cambios en R8/ProGuard que pudieran afectar `cryptography` (Ed25519), `mobile_scanner` (ML Kit offline), `pdf`/`printing`, `sqflite`/`sqlcipher`, `workmanager` o `google_sign_in` en `--release --obfuscate`. Jamás prometer ahorros irreales ni retirar modelos ML Kit offline bundled (`libbarhopper_v3.so` + `.tflite`).
8. **Fases Atómicas Segregadas por Proyecto y Tope Estricto por Turno:** Nunca mezclar refactorización de `mochilalista_admin/` y `app_movil/` en una misma fase, y acotar cada sub-fase ejecutable a un tope máximo de **3 a 6 archivos monolíticos (o ~5,000–6,000 líneas extraídas) por turno** para impedir truncamientos. Toda fase/bloque cierra con verificación íntegra en verde y **checkpoint commit atómico reversible** antes de abrir el siguiente.
9. **Blindaje de Producción, Secretos, APKs Certificados y Git:**
   * **PROHIBIDO** modificar, exponer o commitear `mochilalista_admin/data/prod_*`, `owner_config.json`, `vault_keyring.json`, `vault_settings.json`, `data/.apk_inspection_cache.json`, `private_keys/`, `releases_apks/` ni `app_movil/android/key.properties` (**prohibido usar `git add .`**; solo `git add` selectivo por rutas verificadas).
   * **PROHIBIDO** sobrescribir los APKs certificados `v9.41` existentes en `C:\Users\vjuli\Documents\v-app-offline apks\` durante benchmarks/pruebas de Fase 10 (usar `--out-dir "<carpeta_temporal>"`).
   * Pruebas siempre aisladas en `Directory.systemTemp` con `tearDown()`, comandos síncronos sin colgarse, cero emojis crudos en controles UI (`web/` con `<svg>` acotados, `app_movil/` con `Icons.*` y `.withValues(alpha: ...)`), soporte dual dark + `[data-theme="light"]`, `0px Overflow` en `320x568dp`, `360x640dp` y `412x915dp` a `TextScaler.linear(1.3)`, y **sin `git tag` ni merge a `main`**.

---

## SECCIÓN 4 — ARQUITECTURA MODULAR OBJETIVO POR CAPAS (ÁRBOL DE CARPETAS EXACTO)

### 4.1 `mochilalista_admin/` — Backend Dart (`dart run server.dart`)

```text
mochilalista_admin/
├── server.dart                                 (139 L: arranque CLI, applyStartupModeFromConfig, compareSemVer, HttpServer & handleRequest)
├── lib/
│   ├── *.dart (11 BARRELS RETROCOMPATIBLES)  (1–2 L c/u: export 'data/database_service.dart', config, apk, vault, sync, export, time_utils)
│   ├── core/
│   │   ├── time_utils.dart                     (144 L: PeruTimeHelper - reubicado con barrel en lib/)
│   │   ├── semver_utils.dart                   (102 L: Única fuente de verdad SemVer Dart)
│   │   ├── csv_utils.dart                      (24 L: CsvCellEscaper RFC-4180 + BOM + sanitize newlines)
│   │   ├── path_security.dart                  (226 L: canonicalizePath + isPathWithinDirectory + forbiddenDirs)
│   │   ├── backup_rotation_helper.dart         (167 L: Snapshot atómico + rotación maxAutoSnapshots + tokens protegidos)
│   │   └── commercial_constants.dart           (99 L: Slugs canónicos, días/AI por plan, officialSignerSha256)
│   ├── data/                                   (8 módulos part/mixin < 450 L + barrel lib/database_service.dart)
│   │   ├── database_service.dart               (291 L: fachada, modo Sandbox/Prod, init, resetSandbox & snapshots)
│   │   ├── clients_repository.dart             (431 L: CRUD clientes, sync .mlsync/MLS1 y deleteClient)
│   │   ├── clients_lifecycle_repository.dart   (360 L: migración hardware, recordCodeEmission, markClientUpdated, recordApkDispatched)
│   │   ├── payments_receipts_repository.dart   (316 L: pagos manuales, edición/eliminación, correlativos BOL/FAC)
│   │   ├── finances_export_repository.dart     (217 L: libro consolidado + historial + CSV clientes/finanzas)
│   │   ├── releases_repository.dart            (420 L: catálogo releases, variantes, batch updates y matriz adopción)
│   │   ├── backups_repository.dart             (445 L: snapshots manuales/auto, preview, restore y purge-sandbox)
│   │   └── sandbox_seed_data.dart              (176 L: semilla inicial demostración Sandbox)
│   ├── config/
│   │   ├── config_service.dart                 (468 L: estado config, load/save/reset por scope)
│   │   ├── config_defaults.dart                (319 L: getDefaultConfig catálogo 10 ítems + 9 plantillas WA)
│   │   ├── config_normalizer.dart              (369 L: normalización legados, propagación legal, deepMerge)
│   │   ├── config_apk_dirs_helper.dart         (169 L: validación, canonicalización y reset de rutas APK)
│   │   └── config_template_renderer.dart       (88 L: motor de plantillas WA y bloques bancarios BCP/BBVA)
│   ├── apk/
│   │   ├── apk_models.dart                     (212 L: ApkSearchDirConfig, ApkDetectionReport, ApkInspectionResult)
│   │   ├── apk_cache_store.dart                (274 L: caché JSON persistente + cola de escritura)
│   │   ├── apk_directory_scanner.dart          (341 L: escáner BFS acotado + cuotas equilibradas)
│   │   ├── apk_companion_notes_reader.dart     (309 L: lector notas compañeras *_atp.txt + schema/pubspec)
│   │   ├── apk_binary_tools.dart               (255 L: lectura ZIP ABI + aapt2 + apksigner + build-tools)
│   │   └── apk_inspector_service.dart          (546 L: orquestador y ranking híbrido de APKs)
│   ├── sync/
│   │   ├── license_signer.dart                 (296 L: ML9 Ed25519)
│   │   ├── client_sync_service.dart            (551 L: MLS1 / .mlsync)
│   │   ├── commercial_config_sync_service.dart (571 L: firma/verificación MLC1 + exportación)
│   │   ├── mlc1_payload_inspector.dart         (379 L: validación de esquema y cálculo de diff MLC1)
│   │   └── dart_defaults_exporter.dart         (146 L: generación completa owner_commercial_defaults.dart)
│   ├── vault/
│   │   ├── dpapi_service.dart                  (181 L: Windows DPAPI)
│   │   ├── vault_crypto_models.dart            (136 L: excepciones, VaultKeyring, VaultUnlockCredential, etc.)
│   │   ├── vault_crypto_service.dart           (520 L: PBKDF2, slots AES-GCM, keyring)
│   │   ├── vault_package_codec.dart            (339 L: empaquetado/desempaquetado cifrado .mlvault Nivel 2)
│   │   ├── vault_pin_session_manager.dart      (231 L: PIN status/configure/verify/recover/sessions)
│   │   ├── vault_integrity_auditor.dart        (456 L: auditoría 5 archivos SHA-256 + calificación de protección)
│   │   └── vault_storage_service.dart          (538 L: DPAPI + espejo + nube + auto-recuperación)
│   ├── export/
│   │   ├── excel_styles.dart                   (95 L: paletas y CellStyle compartidos)
│   │   ├── excel_sheets_builder.dart           (506 L: constructores de las hojas Excel del libro maestro)
│   │   └── excel_export_service.dart           (403 L: fachada de exportación .xlsx multi-hoja)
│   └── http/                                   (15 módulos < 540 L; 0 existsSync bloqueantes; contención estricta en web/)
│       ├── html_assembler.dart                 (107 L: ensamblado determinista en memoria de index + @PARTIAL con contención web/)
│       ├── static_handler.dart                 (< 150 L: servidor web/ anti-traversal D-ADM-09 + 404 activos inexistentes + SPA fallback)
│       ├── auth_pin_middleware.dart            (83 L: guardián HTTP 423 + cookies HttpOnly + CORS)
│       ├── windows_shell_helpers.dart          (184 L: selector nativo PowerShell -STA, portapapeles CF_HDROP y launchBrowser async)
│       ├── http_context.dart                   (65 L: contexto HTTP compartido y helpers JSON)
│       ├── api_router.dart                     (137 L: despachador central protegido por AuthPinMiddleware)
│       └── routes/
│           ├── vault_routes.dart               (383 L: /api/vault/*)
│           ├── system_routes.dart              (85 L: /api/system/*, /api/mode)
│           ├── clients_routes.dart             (497 L: /api/dashboard, /api/clients/*, pagos y boletas)
│           ├── licenses_sync_routes.dart       (419 L: /api/licenses/* Tri-Protocolo ML9/MLS1/MLC1 y /api/sync/*)
│           ├── finances_backups_routes.dart    (204 L: /api/finances/*, /api/export/*, /api/backups/*)
│           ├── release_apk_helper.dart         (206 L: resolución async de variantes APK + inspectAndComputeReleaseVerification)
│           ├── releases_files_routes.dart      (530 L: búsqueda, browse, upload, import-local-apk, download, copy-file, reveal-file)
│           ├── releases_routes.dart            (294 L: CRUD releases, verify, verify-all, companion-notes, mark-sent, matrix)
│           └── config_routes.dart              (201 L: /api/config/* incluyendo MLC1 y dart-defaults-snippet)
└── test/
    └── support/
        └── web_bundle_loader.dart              (Loader unificado HTML/CSS/JS para los 34 tests lectores de web/ sin debilitar aserciones)
```

---

### 4.2 `mochilalista_admin/web/` — Frontend Zero-Bundler (`?v=25`)

```text
mochilalista_admin/web/
├── index.html                                  (140 L: shell head ?v=25 + markers <!-- @PARTIAL:... --> + scripts ordenados ?v=25)
├── partials/                                   (18 parciales <= 445 L ensamblados en memoria por HtmlTemplateAssembler; bloqueados por HTTP /partials/*)
│   ├── layout/
│   │   └── sidebar.html                        (99 L: sidebar lateral colapsable)
│   ├── tabs/
│   │   ├── tab_dashboard.html                  (133 L)
│   │   ├── tab_clients.html                    (68 L)
│   │   ├── tab_license_studio.html             (308 L)
│   │   ├── tab_release_manager.html            (216 L)
│   │   ├── tab_inspector.html                  (164 L)
│   │   ├── tab_finances_backups.html           (201 L)
│   │   ├── tab_settings.html                   (348 L)
│   │   └── tab_security_vault.html             (341 L)
│   ├── drawers/
│   │   └── client_360_drawer.html              (374 L)
│   └── modals/
│       ├── modals_clients_crm.html             (445 L: Create/Edit Client, History, ManualPayment)
│       ├── modals_receipts.html                (275 L: PaymentReceipt)
│       ├── modals_sync_migration.html          (358 L: SyncReported, GlobalClientSync, MigrateDevice)
│       ├── modals_licenses_wa.html             (403 L: ConfirmLicenseEmission, Confirm, WaComposer, QuickQr)
│       ├── modals_releases.html                (354 L: CreateRelease, EditRelease, FixClientVersion)
│       ├── modals_settings_mlc1.html           (216 L: UnsavedSettings, ResetSettingsScope, CommercialConfigSync)
│       ├── modals_vault_security.html          (353 L: ImportVault, AutoRecovery, PrintableEmergencyKit, VaultAuditReport)
│       └── modals_backups_preview.html         (70 L: BackupPreview)
├── css/                                        (19 hojas <= 600 L con ?v=25 en cascada estricta; styles.css retirado)
│   ├── 00_tokens.css                           (60 L: variables root Deep Obsidian + tipografía + reset base)
│   ├── 01_layout_shell.css                     (564 L: sidebar, header, navegación, tooltips, mode switcher)
│   ├── 02_components_core.css                  (537 L: botones, badges, tablas, formularios, alertas, toasts)
│   ├── 03_components_modals.css                (586 L: modales base, grillas, paginación y controles reutilizables)
│   ├── modules/
│   │   ├── dashboard_crm.css                   (393 L: dashboard KPIs, gráficos SVG, tabla CRM y búsqueda)
│   │   ├── crm_drawer.css                      (453 L: Drawer 360°, tabs internas, badges y timeline)
│   │   ├── receipts_modal.css                  (472 L: split modal boletas/facturas y vista previa A4/ticket)
│   │   ├── releases_catalog.css                (600 L: drop zone APK, tarjetas versión y tabla catálogo)
│   │   ├── releases_matrix.css                 (575 L: matriz releases, guía dual y modales release)
│   │   ├── inspector_sync.css                  (574 L: inspector tri-protocolo ML9/MLS1/MLC1 y sync diff)
│   │   ├── finances_backups.css                (410 L: filtros finanzas, pills backups y modal preview)
│   │   ├── wa_composer.css                     (293 L: compositor WhatsApp multi-plantilla y preview móvil)
│   │   ├── settings_center.css                 (419 L: Settings 4 tabs, catálogos comerciales y dirty guard)
│   │   ├── settings_mlc1.css                   (306 L: Ficha MLC1 QR Vía 1 y Vía 2 exportador Dart)
│   │   └── security_vault.css                  (240 L: bóveda DPAPI, factores 25%, tabla 6 cols y PIN lock overlay)
│   ├── 90_light_theme_base.css                 (238 L: reglas [data-theme="light"] de tokens, shell y componentes)
│   ├── 91_light_theme_modules.css              (481 L: reglas [data-theme="light"] de módulos e inspector)
│   ├── 95_responsive.css                       (82 L: TODAS las reglas @media max-width consolidadas)
│   └── 99_print.css                            (155 L: reglas exclusivas @media print — Kit de Rescate A4 intacto)
└── js/                                         (Zero-Bundler: 50 scripts ordenados con ?v=25 [48 app + 2 vendor]; admin_app.js RETIRADO)
    ├── qrcode.min.js                           (ISO/IEC 18004 V1-V40 - intacto)
    ├── jsqr.min.js                             (Decodificador QR - intacto)
    ├── core/                                   (9 módulos DRY <= 217 L - CERTIFICADOS Fase 4)
    │   ├── fetch_auth.js                       (39 L: Interceptor fetch PIN HTTP 423)
    │   ├── semver.js                           (46 L: Única compareSemVer + getLatestPublishedVersion — Fix D-ADM-01)
    │   ├── time_lima.js                        (108 L: formatLimaDateTime, formatLimaIsoDate, formatLimaReceiptStamp, getLocalIsoDate GMT-5 — Fix D-ADM-04)
    │   ├── formatters.js                       (115 L: normalizePeruPhone, formatPeruvianPhoneDisplay, formatPlanHumanLabel/formatPlanLabel, normalizePlanToSlug, escapeHtml — DRY D-ADM-05)
    │   ├── clipboard.js                        (79 L: copyPlainTextToClipboard con fallback + copyPngBlobToClipboard — DRY D-ADM-03)
    │   ├── whatsapp.js                         (24 L: buildWhatsAppSendUrl + sanitizeWhatsAppDigits — DRY D-ADM-06)
    │   ├── qr_utils.js                         (128 L: getUtf8ByteLength, renderSafeQrCode, downloadQrWithQuietZone)
    │   ├── canvas_pdf_utils.js                 (140 L: roundRect, wrapText, drawFallbackLogo, generateOfflinePdfFromCanvas, sanitizeDownloadFileName)
    │   └── ui_feedback.js                      (217 L: showToast, initModalConfirm, showConfirmModal, openModal/closeModal, isDesktopAppMode)
    ├── state/                                  (Estado compartido Fase 4 - CERTIFICADO)
    │   └── app_store.js                        (23 L: currentMode, globalClients, globalReleases, globalFinances, ownerConfig, punteros UI/drawer)
    ├── modules/                                (37 sub-módulos <= 582 L extraídos en Fases 4 + 5A + 5B; 0 navigator.clipboard directos)
    │   ├── navigation_theme.js                 (459 L - F4: initNavigation, initTheme, applyTheme, applyTableDensity, initModeSwitcher, shutdown screen)
    │   ├── dashboard.js                        (335 L - F4: loadDashboard, gráficos SVG, KPI click events)
    │   ├── clients_crm.js                      (400 L - F4: loadClients, omnichannel search, filter counts, renderClientsTable con DocumentFragment D-ADM-10)
    │   ├── license_projection.js               (441 L - F4: GEN_SVGS, decodeMl9TokenPayload, selectClientForLicense, updateLiveLicenseProjection)
    │   ├── license_studio.js                   (511 L - F4: initLicenseStudioEvents, renderSelectedGeneratorLicense, openQuickQrModal)
    │   ├── license_emission.js                 (352 L - F4: openConfirmEmissionModal, generateLicense, executeConfirmedEmission)
    │   ├── license_credential_canvas.js        (271 L - F4: renderCredentialCanvas, downloadCredential, copyCredentialToClipboard)
    │   ├── receipts_preview_and_canvas.js      (330 L - F5A: boletas/facturas DOM + formatLimaReceiptStamp D-ADM-04)
    │   ├── receipts_canvas_render.js           (368 L - F5A: drawReceiptOnCanvas Canvas2D IGV/PNG)
    │   ├── receipts_export_and_events.js       (253 L - F5A: PDF offline, copyPngBlobToClipboard D-ADM-03, WA D-ADM-06)
    │   ├── drawer_360_core.js                  (259 L - F5A: switchDrawerTab, initDrawerEvents, updateDrawerEditPlanFields)
    │   ├── drawer_360_profile_tab.js           (499 L - F5A: openClient360Drawer + clipboard DRY D-ADM-03)
    │   ├── drawer_360_payments.js              (229 L - F5A: closeClient360Drawer, delete, pagos manuales/edición)
    │   ├── client_sync_reported.js             (430 L - F5A: renderMigrationRescueCard DRY D-ADM-07 + diff/sync por cliente)
    │   ├── client_sync_global.js               (342 L - F5A: analyzeGlobalSync + applyGlobalSync + initClientSyncEvents)
    │   ├── whatsapp_templates.js               (290 L - F5A: marcador 3B, plantillas WA_TEMPLATES y snippets)
    │   ├── whatsapp_composer.js                (352 L - F5A: compositor WhatsApp multi-plantilla + buildWhatsAppSendUrl D-ADM-06)
    │   ├── releases_catalog.js                 (408 L - F5A: marcador 4, formatApkSizeMb..renderSignatureStatusBadge, loadReleases)
    │   ├── releases_edit_and_verify.js         (582 L - F5A: isVerifyAllCatalogRunning..loadCompanionNoteIntoField + variantes edición)
    │   ├── releases_matrix.js                  (402 L - F5A: matriz inteligente de despliegues y cortesías)
    │   ├── releases_wa_dispatch.js             (551 L - F5A: parseApkSizeMbNumber..sendWaDispatchTextOnly + D-ADM-06)
    │   ├── releases_upload_and_dual_guide.js   (494 L - F5A/5B: drag&drop APK, guía dual PC con copyPlainTextToClipboard D-ADM-03, textareas expandibles)
    │   ├── releases_create_and_local_builds.js (372 L - F5A: tarjeta APK activo y grilla Biblioteca Local)
    │   ├── releases_search_dirs_and_upload.js  (466 L - F5A: carpetas APK de búsqueda y carga multipart)
    │   ├── inspector_history_and_qr.js         (441 L - F5A: marcador 5, historial sesión, guía 3 protocolos, lector jsQR)
    │   ├── inspector_mlc1_render.js            (334 L - F5A: auditoría declarativa MLC1- en Inspector)
    │   ├── inspector_sync_and_dispatch.js      (427 L - F5A: renderInspectClientSync con renderMigrationRescueCard D-ADM-07 + inspectToken)
    │   ├── finances_backups.js                 (568 L - F5B: marcador Sección 6, finanzas GMT-5, paginación 20, backups preview/restore/purge)
    │   ├── modals_crud_clients.js              (581 L - F5B: marcador Sección 7, eventos modales y edición rápida clientes)
    │   ├── modals_history_and_migrate.js       (488 L - F5B: historial pagos/hardware, flujos 1 paso y migración con D-ADM-03/06)
    │   ├── settings_core_and_dirty.js          (455 L - F5B: marcador Sección 8, 4 sub-tabs, dirty guard, snapshots, loadConfig, initSettingsEvents)
    │   ├── settings_form_and_templates.js      (519 L - F5B: reset scopes, preview WA en vivo, poblado y guardado de configuración)
    │   ├── mlc1_sync_exporter.js               (468 L - F5B: marcador Sección 8B, QR 512 px, exportador .dart y share WA/clipboard DRY D-ADM-03/06)
    │   ├── excel_export.js                     (55 L - F5B: marcador Sección 9, exportación Excel maestro y financiero)
    │   ├── security_vault_health.js            (451 L - F5B: marcador #tabSecurityVault, salud/factores 25%, tabla 6 cols y copy DRY D-ADM-03)
    │   ├── security_vault_portability.js       (494 L - F5B: auditoría modal, espejo, cloud path, .mlkey, Kit Rescate A4 y export .mlvault)
    │   └── security_vault_pin.js               (313 L - F5B: importación .mlvault, auto-recuperación espejo y bloqueo/recuperación PIN)
    └── bootstrap.js                            (44 L - F5B: Único DOMContentLoaded + bootstrapAuthenticatedWorkspace; ubicado tras excel_export y previo a Vault)
```

---

### 4.3 `app_movil/lib/` — Estructura Objetivo por Capas (Módulo Core + Features Cohesivos)

```text
app_movil/lib/
├── main.dart                                   (Intacto en orden de MultiProvider, callbackDispatcher y startup)
├── core/
│   ├── config/                                 (api_constants, app_changelog_registry, owner_commercial_defaults, owner_legal_identity)
│   ├── database/
│   │   ├── database_connection_factory.dart    (Intacto)
│   │   ├── product_queries.dart                (Intacto)
│   │   ├── local_db.dart                       (319 L [CERTIFICADA F7A]: Facade LocalDatabase + conexión segura + SQLite v36 inmutable)
│   │   ├── local_db_schema_v36.dart            (250 L [CERTIFICADA F7A]: _onConfigure + PRAGMA + _createDB v36 + licencia/eventos)
│   │   ├── local_db_migrations.dart            (488 L [CERTIFICADA F7A]: _onUpgrade v19..v36 + sanitizePresentacionesDefault)
│   │   └── local_db_loyalty_init.dart          (450 L [CERTIFICADA F7A]: notificaciones silenciadas/prefs + loyalty rules/seeds)
│   ├── providers/
│   │   └── notification_provider.dart          (192 L [CERTIFICADA F7B] + 4 parts <= 488 L: sync, generators, actions, lifecycle)
│   ├── utils/
│   │   ├── currency_formatter.dart             (49 L [CERTIFICADA F6]: AppCurrency.format con decimals y separador de miles configurable)
│   │   ├── app_date_formatter.dart             (156 L [CERTIFICADA F6]: DateFormat estáticos + parseFileTimestamp + formatDateSpanish único)
│   │   ├── clipboard_helper.dart               (40 L [CERTIFICADA F6]: copyWithFeedback con haptic + AppFeedbackHelper)
│   │   ├── whatsapp_uri_builder.dart           (70 L [CERTIFICADA F6]: normalización +51 segura sin duplicar prefijo y https://wa.me/)
│   │   ├── app_feedback_helper.dart            (104 L [CERTIFICADA F6]: facade unificado CustomSnackBar/SnackBar/Toast)
│   │   └── ... (app_logger, backup_*, cuota_date_helper, hardware_validator, smart_search_matcher)
│   └── widgets/
│       ├── universal_image.dart                (249 L [CERTIFICADA F6]: computeSafeCacheDimension DPR + cacheWidth/Height + sin existsSync en build)
│       ├── search/                             (omni_search_bar.dart facade + omni_search_sheet + cards por entidad + scoring)
│       └── ... (home/, tour/, [CERTIFICADA 9C-1]: product_detail_modal.dart 299 L + 3 parts en product_detail/ <= 445 L, stock_update_modal.dart 364 L + 3 parts en stock_update/ <= 422 L con fixes 0px @ 1.3x; [CERTIFICADA 9C-2]: presentation_stock_section.dart 326 L + 3 parts en presentation_card/stock_section/ <= 413 L con fixes 0px @ 1.3x y fix en inventory_item_tile.dart 579 L)
└── features/
    ├── auth/
    │   └── screens/
    │       ├── onboarding/                     (lock_screen.dart 439 L INTOCABLE; profile_selection_screen.dart 509 L + onboarding_screen.dart 318 L [CERTIFICADA F8A])
    │       │   └── widgets/                    (profile_selection_lists_section 294 L, profile_backup_section 308 L, profile_drive_modals 468 L, onboarding_form_steps 502 L, onboarding_categories_and_branding 456 L + preexistentes <= 495 L)
    │       └── license/
    │           ├── license_status_and_activation_screen.dart (287 L [CERTIFICADA F8A]: coordinador + exports compatibilidad)
    │           └── widgets/
    │               ├── commercial_plan_models.dart           (277 L)
    │               ├── license_status_card.dart              (531 L)
    │               ├── license_activation_card.dart          (323 L)
    │               ├── license_mlc1_sync_dialogs.dart        (510 L)
    │               ├── license_catalog_section.dart          (486 L)
    │               ├── license_bank_accounts_section.dart    (481 L)
    │               ├── plan_detail_bottom_sheet.dart         (433 L)
    │               ├── order_plan_bottom_sheet.dart          (395 L + order_plan_bottom_sheet_sections.dart 496 L)
    │               └── qr_scanner_sheet.dart                 (537 L + qr_scanner_overlay_painter.dart 112 L)
    ├── smart_quotation/                        (Subdividido internamente manteniendo imports o re-exports compatibles)
    │   ├── models/                             (crm_models.dart 6 L barrel [CERTIFICADA F8B] -> client_model 194 L, payment_and_ledger_models 199 L, sale_and_installment_models 449 L, quotation_validation_models 257 L, reputation_tier_model 181 L, loyalty_models 483 L, crm_parse_helpers 6 L)
    │   ├── services/
    │   │   ├── client_service.dart             (62 L [CERTIFICADA F7A] + 6 parts <= 626 L: crud, ledger, payments, payment_fifo, loyalty, loyalty_rewards)
    │   │   └── sales_service.dart              (57 L [CERTIFICADA F7B] + 6 parts <= 534 L: pos_tx, history_stats, void_restore, restore_delivery, morosidad, notifications)
    │   ├── screens/                            (crm/loyalty_center_screen.dart 496 L [CERTIFICADA 8C-1] + 6 módulos en crm/loyalty_center/ <= 549 L; pdf_preview/, quotation_detail/, whatsapp_preview/ pendientes)
    │   └── widgets/
    │       ├── crm/
    │       │   ├── client_finance_actions_modal.dart (528 L [CERTIFICADA F8B] + 9 módulos en finance_actions/ <= 591 L + exports DTOs/DraftManager)
    │       │   ├── payment_entry_modal.dart          (515 L [CERTIFICADA F8B] + payment_entry_header_and_chips 585 L + payment_entry_specific_and_submit 382 L + general_preview_tab 170 L)
    │       │   └── ... (quick_sale_detail_modal.dart 373 L [CERTIFICADA 8C-2] + 4 módulos en quick_sale/detail_modal/ <= 373 L; client_loyalty_history_modal.dart 479 L [CERTIFICADA 8C-2] + 3 módulos en crm/loyalty_history/ <= 465 L; manual_price_modifier.dart 545 L responsivo 0px @ 1.3x; Fase 9A..9E pendientes)
    │       └── history/detail_widgets/
    │           └── cuota_morosidad_modal.dart        (412 L [CERTIFICADA F8B] + manual 536 L + auto 509 L + preview_actions 204 L)
    ├── analytics/
    │   ├── providers/
    │   │   └── analytics_provider.dart         (131 L [CERTIFICADA 9A-2] + 4 parts <= 348 L: models, queries, inventory_snapshots, calculations; instancia única ChangeNotifier)
    │   ├── services/
    │   │   └── commercial_radar_service.dart   (217 L [CERTIFICADA F7B] + 3 parts <= 546 L: sources, scoring, persistence)
    │   ├── screens/                            ([CERTIFICADA 9A-1 + 9A-2]: commercial_radar_screen.dart 514 L + 5 módulos en commercial_radar/ <= 510 L con export LocationPickerSheet; predictive_analytics_screen.dart 318 L + 7 módulos en predictive_analytics/ <= 529 L; smart_restock_screen.dart 178 L + 6 módulos en smart_restock/ <= 534 L con export SmartRestockItem; analytics_dashboard_screen.dart 461 L + 2 parts en analytics_dashboard/ <= 440 L)
    │   └── widgets/                            ([CERTIFICADA 9A-2]: commercial_radar_card.dart 255 L + 2 parts en commercial_radar_card/ <= 523 L; fixes 0px Overflow @ 1.3x en radar_card_news_item.dart, financial_summary_card.dart y kpi_summary_row.dart)
    ├── scanner/                                ([CERTIFICADA 9B-1 + 9B-2]: scanner_provider.dart 280 L + 4 parts <= 403 L como instancia única ChangeNotifier; invoice_detail_screen.dart 377 L + 4 parts en invoice_detail/ <= 561 L con AppDateFormatter y AppCurrency; variant_editor_row.dart 401 L + 6 módulos en variant_editor/ <= 548 L con export MiniInput/ResumenTag; scan_screen.dart 247 L + 3 parts en scan/ <= 428 L; staging_product_group_card.dart 183 L + 3 parts en product_group/ <= 533 L con fixes 0px @ 1.3x en Pool Compartido)
    ├── catalog/                                ([CERTIFICADA F7A]: product_repository.dart 88 L + 3 parts <= 485 L; [CERTIFICADA 9C-1]: catalog_screen.dart 569 L + 3 parts en catalog/widgets/ <= 460 L, variant_extract_config_modal.dart 432 L + 3 parts en variants/extract_config/ <= 446 L; [CERTIFICADA 9C-2]: product_create_operations.dart 292 L + 4 módulos en form/create_operations/ <= 618 L con export ProductCreateHydratedData, product_edit_screen.dart 364 L + 3 parts en product_edit/ <= 367 L, products_tab.dart 293 L + 3 parts en tabs/widgets/ <= 503 L; pendiente 9C-3: inventory_provider, product_stock_strategy_selector, presentation_math_engine, price_update_modal)
    └── profile/                                (notifications_screen.dart 372 L [CERTIFICADA 8C-1] + 7 módulos en notifications/ <= 580 L; profile_screen.dart 346 L [CERTIFICADA 8C-1] + 4 módulos en profile/ <= 466 L; google_drive_backup_sheet.dart 353 L [CERTIFICADA 8C-2] + 4 módulos en google_drive/ <= 452 L)
```

---

## SECCIÓN 5 — DIAGNÓSTICO REAL DE PESO APK (UNIVERSAL `107.73 MB` / ARM64 `38.66 MB`) Y OPTIMIZACIÓN DE RECURSOS

### 5.1 Perfilado Exacto de los Binarios `v9.41.0+85` en Producción

Inspección directa en modo solo lectura de las entradas ZIP reales de ambos binarios emitidos por `compilar_release_dual.bat` en `C:\Users\vjuli\Documents\v-app-offline apks\`:

* **APK Universal (`mochilalista_v9.41_atp.apk`):** `112,960,854` bytes (**`107.73 MB`**)
* **APK ARM64 Ligero (`mochilalista_v9.41_arm64_atp.apk`):** `40,542,457` bytes (**`38.66 MB`**, ahorro ya certificado de **`-64.11 %`**)

#### Top 25 Entradas Más Pesadas Dentro de Cada APK `v9.41`

| # | Entrada Interna — `mochilalista_v9.41_atp.apk` (Universal) | Tam. Compr. (Bytes) | Entrada Interna — `mochilalista_v9.41_arm64_atp.apk` (ARM64) | Tam. Real / Compr. (Bytes) |
|---:|---|---:|---|---:|
| 1 | `lib/armeabi-v7a/libapp.so` *(Dart AOT)* | 20,071,004 | `lib/arm64-v8a/libapp.so` *(Dart AOT)* | 18,088,880 |
| 2 | `lib/x86_64/libapp.so` *(Dart AOT)* | 18,678,704 | `lib/arm64-v8a/libflutter.so` *(Flutter Engine)* | 11,317,712 |
| 3 | `lib/arm64-v8a/libapp.so` *(Dart AOT)* | 18,088,880 | `lib/arm64-v8a/libbarhopper_v3.so` *(ML Kit QR offline)* | 4,946,720 |
| 4 | `lib/x86_64/libflutter.so` *(Flutter Engine)* | 12,564,816 | `classes.dex` *(5,006,660 raw -> 2,156,393 compr.)* | 2,156,393 |
| 5 | `lib/arm64-v8a/libflutter.so` *(Flutter Engine)* | 11,317,712 | `lib/arm64-v8a/libsqlite3.so` *(SQLite/FFI)* | 1,732,360 |
| 6 | `lib/armeabi-v7a/libflutter.so` *(Flutter Engine)* | 8,276,324 | `resources.arsc` *(recursos compilados)* | 494,440 |
| 7 | `lib/x86_64/libbarhopper_v3.so` *(ML Kit QR)* | 5,909,280 | `assets/mlkit_barcode_models/barcode_ssd_mobilenet_v1_dmp25_quant.tflite` | 390,456 |
| 8 | `lib/arm64-v8a/libbarhopper_v3.so` *(ML Kit QR)* | 4,946,720 | `assets/mlkit_barcode_models/oned_feature_extractor_mobile.tflite` | 276,552 |
| 9 | `lib/armeabi-v7a/libbarhopper_v3.so` *(ML Kit QR)* | 3,244,440 | `assets/mlkit_barcode_models/oned_auto_regressor_mobile.tflite` | 213,880 |
| 10 | `classes.dex` *(5,006,660 raw -> 2,156,393 compr.)* | 2,156,393 | `assets/flutter_assets/NOTICES.Z` | 122,600 |
| 11 | `lib/arm64-v8a/libsqlite3.so` | 1,732,360 | `assets/flutter_assets/packages/cupertino_icons/assets/CupertinoIcons.ttf` *(257,628 raw)* | **115,944** |
| 12 | `lib/armeabi-v7a/libsqlite3.so` | 1,713,736 | `classes2.dex` *(207,536 raw -> 93,420 compr.)* | 93,420 |
| 13 | `lib/x86_64/libsqlite3.so` | 1,709,544 | `assets/flutter_assets/assets/logo.png` *(256×256 px)* | **73,718** |
| 14 | `resources.arsc` | 494,440 | `assets/flutter_assets/fonts/MaterialIcons-Regular.otf` *(110,412 raw)* | 57,204 |
| 15 | `assets/mlkit_barcode_models/barcode_ssd_mobilenet_v1_dmp25_quant.tflite` | 390,456 | `lib/arm64-v8a/libimage_processing_util_jni.so` | 32,544 |
| 16 | `assets/mlkit_barcode_models/oned_feature_extractor_mobile.tflite` | 276,552 | `res/o-.png` *(launcher icon resource)* | 31,990 |
| 17 | `assets/mlkit_barcode_models/oned_auto_regressor_mobile.tflite` | 213,880 | `res/RJ.png` | 18,528 |
| 18 | `assets/flutter_assets/NOTICES.Z` | 122,600 | `res/FS.png` | 9,067 |
| 19 | `assets/flutter_assets/packages/cupertino_icons/assets/CupertinoIcons.ttf` | **115,944** | `lib/arm64-v8a/libdatastore_shared_counter.so` | 7,112 |
| 20 | `classes2.dex` *(207,536 raw)* | 93,420 | `res/E5.ogg` | 6,401 |
| 21 | `assets/flutter_assets/assets/logo.png` | **73,718** | `AndroidManifest.xml` *(27,748 raw)* | 5,857 |
| 22 | `assets/flutter_assets/fonts/MaterialIcons-Regular.otf` *(110,412 raw)* | 57,204 | `res/yn.png` | 5,405 |
| 23 | `lib/x86_64/libimage_processing_util_jni.so` | 49,496 | `kotlin/kotlin.kotlin_builtins` *(29,399 raw)* | 5,342 |
| 24 | `lib/arm64-v8a/libimage_processing_util_jni.so` | 32,544 | `assets/flutter_assets/shaders/ink_sparkle.frag` *(21,328 raw)* | 5,140 |
| 25 | `res/o-.png` | 31,990 | `lib/arm64-v8a/libsurface_util_jni.so` | 4,896 |

#### Resumen por Categoría:
* **Universal (`107.73 MB`):** `lib/x86_64` (**`37.12 MB`**) + `lib/arm64-v8a` (**`34.46 MB`**) + `lib/armeabi-v7a` (**`31.79 MB`**) = **`103.37 MB` (`95.95 %` del APK son binarios `.so` almacenados sin compresión para `mmap` directo)**; `classes*.dex` (`2.15 MB`), `mlkit_barcode_models` (`0.84 MB`), `resources.arsc` (`0.47 MB`), `flutter_assets` (`0.36 MB`), `res/` (`0.25 MB`).
* **ARM64 (`38.66 MB`):** `lib/arm64-v8a` (**`34.46 MB` = `89.1 %`**), `classes*.dex` (`2.15 MB`), `mlkit_barcode_models` (`0.84 MB`), `resources.arsc` (`0.47 MB`), `flutter_assets` (`0.36 MB`), `res/` (`0.25 MB`).

---

### 5.2 Diagnóstico Realista de Ahorros de Peso, RAM y CPU (Clasificación por Riesgo)

| Optimización | Estado / Categoría | Ahorro Estimado Realista | Veredicto Técnico |
|---|---|---:|---|
| **R8 (`isMinifyEnabled = true`) + `isShrinkResources = true` + `--split-debug-info`** | **Ya activo** en `build.gradle.kts:70-71` y `compilar_release_dual.ps1:751,769` | Ya aplicado (`classes.dex` = `2.15 MB`, `res/` = `245 KB`) | **Conservar intacto.** No queda margen de 20 MB en DEX/res porque R8 ya está operando. |
| **`--split-per-abi` ARM64 Ligero** | **Ya activo** en Plan 23.5 | **`-69.07 MB` (`-64.11 %`)** | **Consolidado** como binario oficial principal para WhatsApp (`38.66 MB`). |
| **Remover `cupertino_icons: ^1.0.8`** (`pubspec.yaml:14`) | **100 % Segura** (`0` usos verificados en `lib/` ni `test/`) | **`~116 KB`** comprimidos (`257.6 KB` raw) en ambos APKs | **EJECUTAR en Fase 10.** |
| **Compresión lossless `assets/logo.png` + `mipmap-*/ic_launcher.png` (WebP/PNG optimizado)** | **100 % Segura** | **`~80–120 KB`** en ambos APKs | **EJECUTAR en Fase 10.** |
| **Consolidación DRY + Remoción de código muerto/huérfano (`228,231` L -> menos clases/métodos duplicados en AOT)** | **100 % Segura** | **`~0.4–1.0 MB`** en `libapp.so` por ABI (`~1.2–3.0 MB` en Universal) + menor tiempo de parseo y memoria AOT | **EJECUTAR en Fases 6–9.** |
| **Limpieza `AndroidManifest.xml:33` (`com.google.android.geo.API_KEY` muerto) + archivos huérfanos `team/*.dart` y widgets sin uso** | **APROBADA (Fase 6)** | `~10–30 KB` + `-730` L muertas | **EJECUTAR en Fase 6** (verificado `0` usos; respaldado en Git). |
| **Optimización de RAM/CPU en Runtime (`UniversalImage` `cacheWidth` + sin `existsSync` en `build()`, `DateFormat` estáticos, `shrinkWrap` reducidos, `DocumentFragment` + async I/O en Admin)** | **100 % Segura** | **Menos picos de RAM (`~10–30 MB` al listar productos con fotos), menos jank en scroll y 0 bloqueos de event loop en Admin** | **EJECUTAR en Fases 2, 5, 6 y 9E.** |
| **APK Universal físico sin `x86_64` (`--target-platform android-arm64,android-arm` en `compilar_release_dual.ps1`)** | **APROBADA por propietario (Fase 10)** | **`-37.12 MB`** en Universal (`107.73 MB` -> **`~70.6 MB`**, `< 100 MB` WhatsApp Web) | **EJECUTAR en Fase 10:** actualizar `compilar_release_dual.ps1` + verificación `aapt2` + `plan23_5_fase3_dual_compiler_test.dart` + Manual 05. **No afecta** `flutter run` en emuladores `x86_64` ni el APK ARM64 Ligero (`38.66 MB`). |
| **Retirar `mobile_scanner` bundled (`libbarhopper_v3.so` + `.tflite`) o forzar R8 agresivo sin pruebas** | **ALTO RIESGO / RECHAZADA** | (`~5.8 MB` ARM64 / `~14.9 MB` Universal) | **RECHAZADO:** pasarlo a unbundled rompería el escáner QR/barras en teléfonos 100 % offline sin Google Play Services. Cualquier ajuste en `proguard-rules.pro` exige keep-rules explícitas para `cryptography`, `sqlcipher`, `workmanager`, `local_auth`, `google_sign_in`, `printing` y prueba física `--release --obfuscate`. |

---

## SECCIÓN 6 — PLAN DE HIGIENE TÉCNICA Y DOCUMENTACIÓN VIVA

### 6.1 Higiene A — `Problems = 0` en `scripts/compilar_release_dual.ps1`

La auditoría contra `(Get-Verb).Verb` de PowerShell detectó **6 funciones** con verbos no aprobados (`PSUseApprovedVerbs`), manteniendo además **1 único BOM UTF-8 (`EF BB BF`)** exigido por PowerShell 5.1 (`plan24_fase4_init_notes_test.dart:300`) y `NO_BOM_PARSE_ERRORS = 0`:

| Línea | Nombre Actual | Verbo Inválido | Nombre Aprobado Objetivo | Referencias Externas en Tests |
|---:|---|---|---|---|
| `16` | `T` | `T` | `ConvertTo-Utf8DisplayText` | `0` externas (solo llamadas internas en `.ps1`) |
| `58` | `Fail-WithGuidance` | `Fail` | `Stop-WithGuidance` | `0` externas |
| `194` | `Parse-PubspecVersion` | `Parse` | `ConvertFrom-PubspecVersion` | `0` externas |
| `227` | `Verify-KeystoreConfigSafe` | `Verify` | `Test-KeystoreConfigSafe` | `0` externas |
| `373` | `Parse-ApkSignerSummary` | `Parse` | `ConvertFrom-ApkSignerSummary` | `0` externas |
| `404` | `Certify-ApkForensic` | `Certify` | `Test-ApkForensic` | `0` externas |

*(Nota: se mantendrán intactos los parámetros CLI `--help`, `--dry-run`, `--verify-only`, `--skip-analyze`, `--no-pause`, `--init-notes`, `--out-dir`, el comportamiento exacto y el BOM `EF BB BF`, validando con `Invoke-ScriptAnalyzer` que el script cierre con **`0` advertencias / `Problems = 0`**).*

---

### 6.2 Higiene B — `.gitattributes` en la Raíz del Repositorio

Actualmente **no existe** `.gitattributes` en `C:\Users\vjuli\Documents\mochilalista-app\`. Se creará un `.gitattributes` limpio en la raíz sin ejecutar renormalizaciones masivas innecesarias sobre archivos intactos:

```gitattributes
# MochilaLista — Normalización determinista de finales de línea y binarios
* text=auto

# Scripts Windows obligatorios con CRLF para cmd.exe y PowerShell 5.1
*.bat text eol=crlf
*.ps1 text eol=crlf

# Código fuente, web y documentación consistentes con LF
*.dart text eol=lf
*.js text eol=lf
*.css text eol=lf
*.html text eol=lf
*.md text eol=lf
*.json text eol=lf
*.yaml text eol=lf
*.yml text eol=lf
*.kts text eol=lf
*.xml text eol=lf
*.properties text eol=lf

# Activos binarios y criptográficos (nunca alterar bytes)
*.png binary
*.ico binary
*.jpg binary
*.jpeg binary
*.ttf binary
*.otf binary
*.ogg binary
*.apk binary
*.jks binary
*.keystore binary
*.db binary
*.sqlite binary
*.sqlite3 binary
*.mlvault binary
*.mlkey binary
*.xlsx binary
*.pdf binary
*.zip binary
```

---

### 6.3 Higiene C — Caché-Busting Unificado `?v=25`

* En `mochilalista_admin/web/index.html` (`:10` y `:4823`) actualmente figuran `href="css/styles.css?v=23"` y `src="js/admin_app.js?v=23"`, y en `informe_proyecto/05_MANUAL_OPERATIVO_DEL_PROPIETARIO_Y_COMANDOS_RELEASE.md:346` aún se cita `?v=23`.
* En la Fase 3–5 se unificará **`?v=25`** en **todas** las etiquetas `<link rel="stylesheet" href="css/...?v=25">` y `<script src="js/...?v=25"></script>` (incluyendo `qrcode.min.js?v=25` y `jsqr.min.js?v=25` si aplica o todos los módulos propios), además de actualizar `plan23_fase2_settings_and_templates_test.dart:334-335` y el Manual `05_MANUAL_OPERATIVO...md`.

---

### 6.4 Higiene D — Mapa de Arquitectura Modular (`informe_proyecto/ARQUITECTURA_MODULAR.md`)

Se creará una guía ejecutiva de consulta rápida (`1–2` páginas claras, **UTF-8 sin BOM**) al cierre del Plan 25 que mapea de forma exacta:
1. **MochilaLista Admin Backend (`mochilalista_admin/`):** tabla Funcionalidad / Endpoint `/api/*` → Archivo Router (`lib/http/routes/*.dart`) → Servicio/Repositorio (`lib/data/`, `lib/vault/`, `lib/apk/`, `lib/config/`, `lib/sync/`, `lib/export/`).
2. **MochilaLista Admin Web (`mochilalista_admin/web/`):** tabla Pestaña / Modal / Drawer → Parcial HTML (`web/partials/*`) → Hoja CSS (`web/css/*`) → Módulo JS (`web/js/modules/*`) y orden de carga `?v=25`.
3. **App Móvil (`app_movil/lib/`):** tabla Feature / Pantalla / Servicio Core → Archivo(s) modular(es) y ubicación de utilidades DRY (`AppCurrency`, `AppDateFormatter`, `ClipboardHelper`, `WhatsAppUriBuilder`, `LocalDatabase` parts SQLite `v36` y `OwnerCommercialDefaults`).
4. **Scripts y Certificación Dual:** `compilar_release_dual.bat` → `scripts/compilar_release_dual.ps1` → `test/support/web_bundle_loader.dart`.

---

## SECCIÓN 7 — HOJA DE RUTA EN SUB-FASES ATÓMICAS, CHECKPOINTS Y CRITERIOS DE CERTIFICACIÓN

Cada sub-fase respeta estrictamente el **Tope Atómico por Turno** (**máximo `3–6` archivos monolíticos o `~5,000–6,000` líneas extraídas por sub-fase**), está **segregada por proyecto**, y exige:
* Inventario verificado de símbolos (`antes == después`) sin truncamientos ni comentarios `// ...`.
* Análisis estático limpio (`dart analyze` en `mochilalista_admin/` o `flutter analyze --no-pub` en `app_movil/`).
* Batería completa del subproyecto tocado en verde (`dart test` = `255/255`+ en Admin, `flutter test --no-pub -j 1` = `1,438/1,438`+ en Móvil).

| Bloque | Sub-Fase | Proyecto | Alcance Exacto (Topes Verificados) | Meta Tamaño | Verificación Obligatoria |
|---|---|---|---|---|---|
| **0** | **Fase 0** *(CERTIFICADA)* | Raíz + Scripts + Tests Admin | **Higiene A + B + Red de Seguridad Completa:** Renombradas 6 funciones en `scripts/compilar_release_dual.ps1` (`NO_BOM_PARSE_ERRORS=0`, `14` funciones con `0` verbos fuera de `(Get-Verb).Verb`, `CRLF` puro, único BOM `EF BB BF`), creado `.gitattributes` verificando cero archivos no editados en `git status`, creado `test/support/web_bundle_loader.dart`, **migrados los `34` archivos reales lectores de `web/`** sin debilitar aserciones y añadido `test/plan25_fase0_hygiene_and_loader_test.dart`. *(Nota: módulo externo `PSScriptAnalyzer` no instalado localmente; equivalencia validada vía Parser AST + `(Get-Verb).Verb`).* | `.ps1` con `0` verbos no aprobados; `34` tests migrados | AST/Verbs = 0 (`FUNCTIONS_COUNT=14`); `compilar_release_dual.bat --help/--dry-run/--verify-only --init-notes --no-pause` (`exit 0`); `git status` limpio; `dart analyze` limpio; `dart test` (`258/258`). |
| **I** | **Fase 1** *(CERTIFICADA)* | `mochilalista_admin/` (`lib/`) | **DRY Backend + Extracción Servicios Soporte (6 servicios + `time_utils`/`dpapi`/`signer`/`client_sync`):** creada capa `lib/core/` (`6` módulos: `time_utils`, `semver_utils`, `csv_utils` corrigiendo `D-ADM-02` en `database_service.dart#exportClientsToCsv`, `path_security`, `backup_rotation_helper`, `commercial_constants`); modularizados `apk_inspector_service`, `config_service`, `vault_storage_service`, `vault_crypto_service`, `commercial_config_sync_service` y `excel_export_service` en `32` archivos `< 600` L (máx `571` L) conservando **`10` barrels `1–2` L (`export '...'`) en `lib/*.dart`**, adaptado `releases_matrix_and_ui_test.dart` a lectura modular de `lib/apk/` y agregado `test/plan25_fase1_admin_core_and_services_test.dart`. | Todos `< 600` L (`571` máx); `10` barrels `1–2` L | `dart analyze` (`No issues found!`); censo de líneas (`32` módulos `< 600` L); `dart test` completo (`262/262` en verde sin romper imports heredados). |
| **I** | **Fase 2** *(CERTIFICADA)* | `mochilalista_admin/` (`server.dart` + `database_service.dart`) | **Modularización DB & HTTP (2 monolitos -> `23` módulos):** dividido `database_service.dart` (`2,708` L) en `8` archivos `lib/data/*` (`<= 445` L) con barrel `lib/database_service.dart` (`1` L); dividido `server.dart` (`3,220` L) en `server.dart` (`139` L) + `15` archivos `lib/http/**` (`<= 530` L) con `AuthPinMiddleware` (`423` Locked + cookies `HttpOnly`), `StaticHandler` anti-traversal **`D-ADM-09`**, `HtmlTemplateAssembler`, `SemVerUtils` unificado y migración de `existsSync` HTTP a I/O `async` **`D-ADM-10`** + `test/plan25_fase2_db_and_http_modular_test.dart`. | `server.dart` = `139` L; todo `lib/` `< 600` L (máx `571` L) | `dart analyze` (`No issues found!`); `0` `existsSync` en `lib/http/**`; test PIN `423` + traversal + `dart test` completo (`265/265` verde). |
| **II** | **Fase 3** *(CERTIFICADA)* | `mochilalista_admin/web/` (HTML + CSS) | **Capas CSS + Parciales HTML + `?v=25` (`19` CSS + `18` Parciales):** retirado `css/styles.css` (`7,399` L) y dividido en `19` hojas CSS (`<= 600` L) respetando orden `00_tokens -> 01_layout_shell -> 02..03_components -> modules/* -> 90..91_light_theme -> 95_responsive -> 99_print`; dividido `index.html` (`4,825` L) en `140` L + `18` parciales `web/partials/**` (`<= 445` L); añadido `HtmlTemplateAssembler.assembleSync()` (`184` L) y bloqueo HTTP `403` para `/partials/*` en `StaticHandler` (`138` L); unificado `?v=25` en stylesheets y scripts; actualizado `WebBundleLoader` + `plan23_fase2_settings_and_templates_test.dart` (`?v=25`) y agregada suite `test/plan25_fase3_html_css_modular_test.dart`. | CSS `<= 600` L; Parciales `<= 445` L; `index.html` = `140` L | `dart analyze` (`No issues found!`); paridad `901/901` IDs + `87` `onclick` + `266` `<svg>` + `144` light + `11` `@media` + `2` `@media print`; `node --check`; `dart test` completo (`268/268` verde) + HTTP `/`. |
| **II** | **Fase 4** *(CERTIFICADA)* | `mochilalista_admin/web/js/` (Parte 1) | **Extracción JS Core + Estado + Bloque 1 (`17` módulos `<= 511` L):** creada capa `js/core/` (`9` módulos `<= 217` L: `fetch_auth`, `semver` única `compareSemVer` **`D-ADM-01`**, `time_lima` GMT-5 **`D-ADM-04`**, `formatters` **`D-ADM-05`**, `clipboard` **`D-ADM-03`**, `whatsapp` **`D-ADM-06`**, `qr_utils`, `canvas_pdf_utils`, `ui_feedback`), `js/state/app_store.js` (`23` L) y `7` módulos de Bloque 1 (`navigation_theme`, `dashboard`, `clients_crm` con `DocumentFragment` **`D-ADM-10`**, `license_projection`, `license_studio`, `license_emission`, `license_credential_canvas`); orden estricto `?v=25` en `index.html`, actualizado `WebBundleLoader.jsFilePaths()` + `plan25_fase0`/`fase3_plan18_5`/`plan22_fase3`/`plan22_fase4`/`plan23_fase2`/`plan24_fase2`/`plan25_fase3` y creada suite `test/plan25_fase4_js_core_and_modules_p1_test.dart`; `admin_app.js` reducido `15,969 -> 12,341` L preservando intactos los bloques de Fases 5A/5B. | Todos `< 600` L (`511` máx); `0` duplicados `let`/`const` | `node --check` en cada `.js` + bundle concatenado (`exit 0`); `COMPARE_SEMVER_DEFS=1`; `MISSING_FUNCTIONS=0`; `dart analyze` (`No issues found!`); `dart test` completo (`271/271` verde). |
| **II** | **Fase 5A** *(CERTIFICADA)* | `mochilalista_admin/web/js/` (Parte 2A) | **Extracción JS Bloque 2A (`20` sub-módulos `<= 582` L):** extraídos `receipts_*` (`3`), `drawer_360_*` (`3`), `client_sync_*` (`2` con helper único **`renderMigrationRescueCard` — Fix `D-ADM-07`**), `whatsapp_*` (`2`), `releases_*` (`7` preservando `formatApkSizeMb..renderSignatureStatusBadge` y `isVerifyAllCatalogRunning..Carga notas compañeras`) e `inspector_*` (`3` preservando Sección 5 antes de Sección 6 en `admin_app.js`); adoptados `formatLimaReceiptStamp`, `copyPlainTextToClipboard`/`copyPngBlobToClipboard` y `buildWhatsAppSendUrl`; orden `?v=25` en `index.html`, adaptados `plan22_fase3`, `plan22_fase4`, `plan23_5_fase2`, `plan25_fase4` y creada suite `test/plan25_fase5a_js_modules_p2a_test.dart`; `admin_app.js` reducido `12,341 -> 4,459` L. | Sub-módulos `<= 582` L (`< 650`); `admin_app.js` = `4,459` L | `node --check` individual + concatenado (`exit 0`); `MISSING_INLINE_HANDLERS=0`; `COMPARE_SEMVER_DEFS=1`; `dart analyze` (`No issues found!`); `dart test` completo (`274/274` verde). |
| **II** | **Fase 5B** *(CERTIFICADA)* | `mochilalista_admin/web/js/` (Parte 2B) | **Extracción JS Bloque 2B & Retiro Definitivo de `admin_app.js` (`10` módulos + `bootstrap.js`):** extraídos `finances_backups.js` (`568` L), `modals_crud_clients.js` (`581` L), `modals_history_and_migrate.js` (`488` L), `settings_core_and_dirty.js` (`455` L), `settings_form_and_templates.js` (`519` L), `mlc1_sync_exporter.js` (`468` L), `excel_export.js` (`55` L), `bootstrap.js` (`44` L), `security_vault_health.js` (`451` L), `security_vault_portability.js` (`494` L) y `security_vault_pin.js` (`313` L); migrado el 100 % restante de `navigator.clipboard` y enlaces WA en `modals_history_and_migrate`, `mlc1_sync_exporter`, `security_vault_health` y `releases_upload_and_dual_guide` (`D-ADM-03`/`06`); eliminado `admin_app.js` del árbol y de `web/index.html`; actualizados tests contractuales + creada suite `plan25_fase5b_js_closure_and_zero_monoliths_test.dart` (`277/277` en verde). | Todos `< 600` L (máx `582` L en `modules/`); **`0` monolitos en Admin** | `node --check` `50/50` + bundle (`exit 0`); `DIRECT_CLIPBOARD_IN_MODULES=0`; `dart analyze` (`No issues found!`); `dart test` (`277/277`) + `handleRequest()` HTTP `200`/`404`/`403`. |
| **III** | **Fase 6** *(CERTIFICADA)* | `app_movil/` (Core DRY + Código Muerto) | **Consolidación DRY Móvil, Rendimiento Base & Limpieza Aprobada:** extendido `AppCurrency.format` (`49` L, **`403`** ocurrencias en `lib/`) con parámetro `includeThousandsSeparator` y `decimals`; creados `AppDateFormatter` (`156` L, **`29`** usos), `ClipboardHelper` (`40` L, **`20`** usos con **`0`** `Clipboard.setData` fuera del helper), `WhatsAppUriBuilder` (`70` L, **`14`** usos sobre `https://wa.me/` corrigiendo bugs `51+phone`), `AppFeedbackHelper` (`104` L); optimizado `UniversalImage` (`249` L, `computeSafeCacheDimension` DPR + sin `file.existsSync()` en `build()`); retirados los **`5`** archivos huérfanos aprobados (`730` L) y `com.google.android.geo.API_KEY` en `AndroidManifest.xml`; añadida suite `plan25_fase6_core_dry_and_cleanup_test.dart` (`9` tests) y alineado `inventory_card_redesign_and_360_sync_test.dart` a `AppCurrency.format`. | Core utils `<= 156` L (`< 250` L); `-730` L muertas; `0` `Clipboard.setData` directos | `flutter analyze --no-pub` (`No issues found!`); `flutter test --no-pub -j 1` (`1,447/1,447` en verde). |
| **III** | **Fase 7** *(CERTIFICADA: `7A` + `7B`)* | `app_movil/` (Persistencia & Servicios Core — `7A` + `7B`) | **Sub-lote `7A` *(CERTIFICADO — `3` archivos, `5,910` L -> `15` módulos)*:** `local_db.dart` (`318` L + `schema_v36` `249` L, `migrations` `487` L, `loyalty_init` `449` L, **SQLite `v36` 100 % inmutable `MISSING_SQL_DDL=0`**); `product_repository.dart` (`81` L + `queries` `449` L, `stock_audit` `385` L, `mutations` `483` L); `client_service.dart` (`61` L + `crud` `143` L, `ledger` `554` L, `payments` `594` L, `payment_fifo` `625` L, `loyalty` `545` L, `loyalty_rewards` `550` L); micro-higiene llaves `{}` en `notifications_screen.dart:1824` y `offers_tab.dart:728,736`; suite `plan25_fase7a_persistence_and_core_services_test.dart`.<br>**Sub-lote `7B` *(CERTIFICADO — `3` archivos, `5,559` L -> `16` módulos)*:** `sales_service.dart` (`57` L + `pos_tx` `516` L, `history_stats` `350` L, `void_restore` `416` L, `restore_delivery` `483` L, `morosidad` `534` L, `notifications` `433` L); `commercial_radar_service.dart` (`217` L + `sources` `546` L, `scoring` `486` L, `persistence` `454` L con aislamiento `profile_id` intacto); `notification_provider.dart` (`192` L + `sync` `391` L, `generators` `488` L, `actions` `444` L, `lifecycle` `185` L como instancia única `ChangeNotifier`); suite `plan25_fase7b_sales_radar_notifications_test.dart`. | Todos `< 600–650` L (máx `625` L en `7A`, `546` L en `7B`); `0` monolitos en persistence/services/providers | `MISSING_SQL_DDL=0`; `MISSING_PUBLIC_METHODS=0` (`6/6` servicios); `flutter analyze --no-pub` (`No issues found!`); `flutter test --no-pub -j 1` (`1,454/1,454` en verde). |
| **III** | **Fase 8A** *(CERTIFICADA)* | `app_movil/` (Auth & Onboarding — `3` archivos -> `19` módulos) | **Modularización Auth/Licencias/Onboarding (`7,558` L -> `19` módulos `<= 537` L, `lock_screen.dart` `0` cambios, `license_activation_feedback_modal.dart` reservado para `9E-4`):** dividido `license_status_and_activation_screen.dart` (`287` L + `11` módulos `<= 537` L con `export`s de `CommercialPlanDetail`, `PlanDetailBottomSheet`, `OrderPlanBottomSheet` y `QrScannerSheet`); dividido `profile_selection_screen.dart` (`509` L + `3` parts `<= 468` L); dividido `onboarding_screen.dart` (`318` L + `2` parts `<= 502` L); preservados `assets/logo.png` y todas las `ValueKey`s (`MISSING_PUBLIC_CLASSES=0`, `MISSING_WIDGET_KEYS=0`); creada suite `plan25_fase8a_auth_onboarding_modular_test.dart` (`0px Overflow` en `320x568`/`360x640`/`412x915` a `TextScaler.linear(1.3)`). | Todos `< 650` L (máx `537` L; coordinadores `287`/`509`/`318` L) | `MISSING_PUBLIC_CLASSES=0`; `MISSING_WIDGET_KEYS=0`; `IMMUTABLE_DIFF=0`; `flutter analyze --no-pub` (`No issues found!`); `flutter test --no-pub -j 1` (`1,459/1,459` verde). |
| **III** | **Fase 8B** *(CERTIFICADA)* | `app_movil/` (CRM Finanzas & Cuotas — `4` archivos -> `25` módulos) | **Modularización CRM Financiero (`9,026` L -> `25` archivos cohesivos `<= 591` L):** convertido `crm_models.dart` (`1,759` L -> **`6` L** barrel `export`) hacia `7` archivos `<= 483` L (`crm_parse_helpers` `6`, `client_model` `194`, `payment_and_ledger_models` `199`, `sale_and_installment_models` `449`, `quotation_validation_models` `257`, `reputation_tier_model` `181`, `loyalty_models` `483`); dividido `client_finance_actions_modal.dart` (`4,209` L -> `528` L coordinador + `9` módulos en `finance_actions/` `<= 591` L con `export`s de `FinanceWithdrawDraft`, `FinanceLoanDraft`, `ClientFinanceDraftManager`); dividido `cuota_morosidad_modal.dart` (`1,612` L -> `412` L + `3` parts `<= 536` L); dividido `payment_entry_modal.dart` (`1,446` L -> `515` L + `2` parts `<= 585` L + ajuste `0px Overflow` en carrusel chips y `general_preview_tab.dart` `170` L); creada suite `plan25_fase8b_crm_finance_models_modular_test.dart` (`320x568`/`360x640`/`412x915 @ 1.3x`). | Barrel `6` L; modelos `<= 483` L (`< 550`); modales `<= 591` L (`< 650`) | `MISSING_PUBLIC_CLASSES=0`; `MISSING_WIDGET_KEYS=0`; `IMMUTABLE_DIFF=0`; `flutter analyze --no-pub` (`No issues found!`); `flutter test --no-pub -j 1` (`1,464/1,464` verde). |
| **III** | **Fase 8C** *(CERTIFICADA: `8C-1` + `8C-2`)* | `app_movil/` (Fidelización, Notif, Perfil, Drive, Caja Rápida & Reputación — `6` archivos) | **Sub-lote `8C-1` *(CERTIFICADO — `7,442` L reales [incluyendo `notifications_screen.dart` `3,016` L reales vs `2,257` L del censo base] -> `20` archivos `<= 580` L)*:** `loyalty_center_screen.dart` (`496` L + `6` módulos en `crm/loyalty_center/` `<= 549` L); `notifications_screen.dart` (`372` L + `7` módulos en `notifications/` `<= 580` L + ajuste responsivo `Wrap` `0px Overflow @ 1.3x` en `notifications_grouped_client_section.dart`); `profile_screen.dart` (`346` L + `4` módulos en `profile/` `<= 466` L); suite `plan25_fase8c1_loyalty_notifications_profile_modular_test.dart` (`426` L).<br>**Sub-lote `8C-2` *(CERTIFICADO — `4,779` L censo base / `4,768` L reales -> `14` archivos `<= 479` L + fix `manual_price_modifier.dart` `545` L)*:** `google_drive_backup_sheet.dart` (`353` L + `4` módulos en `google_drive/` `<= 452` L preservando `showOnboardingInvitation`/`executeDirectRestore`/`showOAuthErrorDialog`); `quick_sale_detail_modal.dart` (`373` L + `4` módulos en `quick_sale/detail_modal/` `<= 373` L + fix `0px Overflow @ 1.3x` en `quick_sale_discount_and_totals_section.dart` y `manual_price_modifier.dart`); `client_loyalty_history_modal.dart` (`479` L + `3` módulos en `crm/loyalty_history/` `<= 465` L + `BoxFormatConstraints`); suite `plan25_fase8c2_drive_quicksale_loyalty_modal_test.dart` (`460` L, `320x568`/`360x640`/`412x915 @ 1.3x`). | Coordinadores `<= 496` L; sub-módulos `<= 580` L (`< 650`) | `MISSING_PUBLIC_CLASSES=0`; `MISSING_WIDGET_KEYS=0`; `OVER_LIMIT_FILES=0`; `0px Overflow @ 1.3x`; `flutter analyze --no-pub` (`No issues found!`); `flutter test --no-pub -j 1` (`1,472/1,472` verde). |
| **III** | **Fase 9A** *(CERTIFICADA: `9A-1` + `9A-2`)* | `app_movil/` (Analytics & Radar `>= 1,000` L — 6 archivos -> `32` módulos) | **Sub-lote `9A-1` *(CERTIFICADO — `3` archivos, `6,531` L -> `21` archivos `<= 534` L)*:** `commercial_radar_screen.dart` (`514` L + `5` módulos `<= 510` L en `commercial_radar/` con `export` `LocationPickerSheet` y `ValueKey`s `btn_apply_district`/`btn_use_province`), `predictive_analytics_screen.dart` (`318` L + `7` módulos `<= 529` L en `predictive_analytics/` + fixes `0px Overflow @ 1.3x`), `smart_restock_screen.dart` (`178` L + `6` módulos `<= 534` L en `smart_restock/` con `export` `SmartRestockItem`, `AppDateFormatter.formatDate` y fixes responsivos `320dp @ 1.3x`); suite `plan25_fase9a1_analytics_radar_restock_modular_test.dart`.<br>**Sub-lote `9A-2` *(CERTIFICADO — `3` archivos, `3,480` L -> `11` archivos `<= 523` L)*:** `analytics_dashboard_screen.dart` (`461` L + `2` parts en `analytics_dashboard/` `<= 440` L con `AppDateFormatter.ddMM`), `commercial_radar_card.dart` (`255` L + `2` parts en `commercial_radar_card/` `<= 523` L manteniendo aislamiento `profile_id`), `analytics_provider.dart` (`131` L fachada `< 400` L + `4` parts `<= 348` L: `models`, `queries` con literal SQL `'` compatible SQLite 3.4x, `inventory_snapshots`, `calculations` usando `AppDateFormatter.mmYyyy`/`yyyyMMdd`, instancia única `ChangeNotifier`); fixes reales `0px Overflow @ 1.3x` en `radar_card_news_item.dart`, `financial_summary_card.dart` y `kpi_summary_row.dart`; suite `plan25_fase9a2_analytics_dashboard_card_provider_test.dart` + **Checkpoint 6A**. | Coordinadores `<= 514` L (`< 550`); fachada Provider `131` L (`< 400`); sub-módulos `<= 534` L (`< 650`) | `MISSING_PUBLIC_CLASSES=0`; `MISSING_PUBLIC_METHODS=0`; `MISSING_WIDGET_KEYS=0`; `OVER_LIMIT_FILES=0`; `0px Overflow @ 1.3x` (`320/360/412dp`); `flutter analyze --no-pub` (`No issues found!`); `flutter test --no-pub -j 1` (**`1,482/1,482`** verde). |
| **III** | **Fase 9B** *(CERTIFICADA: `9B-1` + `9B-2`)* | `app_movil/` (Scanner & Facturas `>= 1,000` L — 5 archivos -> `25` módulos) | **Sub-lote `9B-1` *(CERTIFICADO — `3` archivos, `5,427` L -> `17` archivos `<= 561` L)*:** `invoice_detail_screen.dart` (`377` L + `4` parts en `invoice_detail/` `<= 561` L con `AppDateFormatter`, `AppCurrency` y fixes `0px @ 1.3x`), `variant_editor_row.dart` (`401` L manteniendo `VariantEditorRowState` público + `export` `MiniInput`/`ResumenTag` + `6` módulos en `variant_editor/` `<= 548` L: `inputs_and_tags`, `math_and_modals`, `stock_panels`, `cards_and_mixto`, `form_body` y `new_purchase_section` + fixes `0px @ 1.3x`) y `scanner_provider.dart` (`280` L fachada `< 400` L + `4` parts `<= 403` L como instancia única `ChangeNotifier`); suite `plan25_fase9b1_scanner_detail_variant_provider_test.dart` (`497` L).<br>**Sub-lote `9B-2` *(CERTIFICADO — `2` archivos, `2,411` L -> `8` archivos `<= 533` L)*:** `scan_screen.dart` (`247` L + `3` parts en `scan/` `<= 428` L con endurecimiento responsive @ `1.3x`) y `staging_product_group_card.dart` (`183` L + `3` parts en `product_group/` `<= 533` L con fix `0px Overflow` en `_buildSharedMasterPoolBlock` @ `320dp x 1.3x`); suite `plan25_fase9b2_scan_screen_and_staging_group_test.dart` (`577` L) + **Checkpoint 6B**. | Coordinadores `<= 401` L (`scan_screen` `247` L, `staging_product_group_card` `183` L `< 550`); fachada Provider `280` L (`< 400`); sub-módulos `<= 561` L (`< 650`, `9B-2` `<= 533` L `< 600`) | `MISSING_PUBLIC_CLASSES=0`; `MISSING_PUBLIC_METHODS=0`; `MISSING_WIDGET_KEYS=0`; `OVER_LIMIT_FILES=0`; `0px Overflow @ 1.3x` (`320/360/412dp`); `flutter analyze --no-pub` (`No issues found!`); `flutter test --no-pub -j 1` (**`1,491/1,491`** verde). |
| **III** | **Fase 9C** *(EN PROGRESO: `9C-1 + 9C-2` CERTIFICADAS)* | `app_movil/` (Catálogo & Productos `>= 1,000` L — 12 archivos en `4+4+4`) | **Sub-lote `9C-1` *(CERTIFICADO — `4` archivos, `6,085` L -> `16` módulos `<= 569` L)*:** `catalog_screen.dart` (`569` L + `3` parts `<= 460` L con `AppCurrency.format`), `variant_extract_config_modal.dart` (`432` L + `3` parts `<= 446` L), `product_detail_modal.dart` (`299` L + `3` parts `<= 445` L) y `stock_update_modal.dart` (`364` L + `3` parts `<= 422` L); suite `plan25_fase9c1` (`611` L) + **Checkpoint Parcial `6C-1`**.<br>**Sub-lote `9C-2` *(CERTIFICADO — `4` archivos, `4,945` L -> `17` módulos `<= 618` L + fix `inventory_item_tile.dart` `579` L)*:** `product_create_operations.dart` (`292` L fachada + `4` módulos en `form/create_operations/` `<= 618` L con `export ProductCreateHydratedData` y `AppFeedbackHelper`), `presentation_stock_section.dart` (`326` L + `3` parts en `stock_section/` `<= 413` L), `product_edit_screen.dart` (`364` L + `3` parts en `product_edit/` `<= 367` L con DRY `_captureCurrentSnapshot` y fix diálogo), `products_tab.dart` (`293` L + `3` parts en `tabs/widgets/` `<= 503` L con fixes `0px @ 1.3x` en toast/sheet) y fix responsivo `@ 1.3x` en `inventory_item_tile.dart` (`579` L sin truncamiento `ellipsis`); suite `plan25_fase9c2_catalog_create_edit_products_tab_test.dart` (`641` L) + **Checkpoint Parcial `6C-2`**.<br>**Sub-lote `9C-3` (`4,325` L — Pendiente):** `inventory_provider.dart` (`1,174`), `product_stock_strategy_selector.dart` (`1,128`), `presentation_math_engine.dart` (`1,020`), `price_update_modal.dart` (`1,003`). | `9C-1/2`: coordinadores `292–569` L (`< 600` L), sub-módulos `23–618` L (`< 650` L); `9C-3` pendiente | `9C-2`: `MISSING_PUBLIC_CLASSES=0`; `MISSING_PUBLIC_METHODS=0`; `MISSING_WIDGET_KEYS=0`; `OVER_LIMIT_FILES=0`; `0px Overflow @ 1.3x` (`320/360/412dp`); `flutter analyze --no-pub` (`No issues found!`); `flutter test --no-pub -j 1` (**`1,499/1,499`** verde). |
| **III** | **Fase 9D** | `app_movil/` (Cotiz., PDF, Búsqueda & Resto `>= 1,000` L — 21 archivos en `3+3+4+4+4+3`) | **Sub-lote `9D-1` (`5,783` L):** `pdf_preview_screen` (`1,961`), `manual_quote_detail_modal` (`1,920`), `omni_search_bar` (`1,902`).<br>**Sub-lote `9D-2` (`5,045` L):** `quotation_detail_screen` (`1,870`), `product_quote_detail_modal` (`1,720`), `smart_action_grid` (`1,455`).<br>**Sub-lote `9D-3` (`5,286` L):** `whatsapp_preview_screen` (`1,346`), `bundle_builder_screen` (`1,338`), `sale_financial_detail_screen` (`1,333`), `quick_sale_screen` (`1,269`).<br>**Sub-lote `9D-4` (`4,919` L):** `matching_screen` (`1,262`), `sale_provider` (`1,236`), `pdf_generator` (`1,217`), `audit_trail_screen` (`1,204`).<br>**Sub-lote `9D-5` (`4,489` L):** `ai_settings_screen` (`1,167`), `backup_screen` (`1,144`), `matching_item_row` (`1,106`), `ledger_timeline_tab` (`1,072`).<br>**Sub-lote `9D-6` (`3,091` L):** `loyalty_whatsapp_service` (`1,031`), `live_filter_bottom_sheet` (`1,031`), `client_full_stats_modal` (`1,029`). | Todos `< 550–650` L (`0` archivos `>= 1,000` L en `app_movil/lib/`) | `flutter analyze --no-pub` y `flutter test --no-pub -j 1` en verde tras cada sub-lote `9D-1..6`. |
| **III** | **Fase 9E** | `app_movil/` (Cierre `800–999` L — 21 archivos en `4+4+4+4+5` + `shrinkWrap`) | **Sub-lote `9E-1` (`3,823` L):** `comparative_update_modal` (`999`), `invoice_staging_screen` (`956`), `quick_sale_header` (`948`), `invoice_pdf_report_service` (`920`).<br>**Sub-lote `9E-2` (`3,647` L):** `sale_history_detail_screen` (`917`), `stock_analysis_modal` (`916`), `manual_quotation_screen` (`912`), `export_options_modal` (`907`).<br>**Sub-lote `9E-3` (`3,583` L):** `dashboard_header` (`902`), `extraction_result_screen` (`901`), `filter_drawer` (`895`), `product_edit_operations` (`885`).<br>**Sub-lote `9E-4` (`3,433` L):** `smart_update_modal` (`883`), `persistent_work_dock` (`864`), `license_activation_feedback_modal` (`849`), `notification_settings_modal` (`837`).<br>**Sub-lote `9E-5` (`4,088` L):** `quotation_service` (`828`), `discount_intelligent_modal` (`826`), `business_backup_service` (`815`), `home_screen` (`810`), `whatsapp_preview_modal` (`809`) + reemplazo de `shrinkWrap: true` críticos por slivers/builders. | **`0` archivos `>= 800` L en todo el repositorio** | `flutter analyze --no-pub`; censo automático `>= 800` L = 0; pruebas widget/overflow `1.3x` + `flutter test --no-pub -j 1`. |
| **IV** | **Fase 10** | `app_movil/` + Compilador Dual | **Optimización Segura APK & Benchmark Protegido:** retirar `cupertino_icons: ^1.0.8`, comprimir lossless `assets/logo.png` + `mipmap-*`, aplicar `--target-platform android-arm64,android-arm` al build Universal en `compilar_release_dual.ps1` (actualizando verificación `aapt2` + `plan23_5_fase3_dual_compiler_test.dart`, sin afectar `flutter run` ni ARM64 Ligero), y compilar/auditar en **carpeta temporal** `compilar_release_dual.bat --no-pause --init-notes --out-dir "<temp_bench>"` **sin sobrescribir los APKs `v9.41` certificados**. | Universal `~70.6 MB` (`-37.1+ MB`); ARM64 `< 38 MB` | Benchmark ZIP antes vs después, SHA-256 + `aapt2` + `apksigner` RSA-4096 en `<temp_bench>`; `dart test` + `flutter test --no-pub -j 1` 100 % en verde. |
| **IV** | **Fase 11** | `informe_proyecto/` | **Documentación Viva y Cierre Certificado:** redactar `informe_proyecto/ARQUITECTURA_MODULAR.md` (1–2 páginas, UTF-8 sin BOM), actualizar `05_MANUAL_OPERATIVO_DEL_PROPIETARIO_Y_COMANDOS_RELEASE.md` (referencias `?v=25`, rutas modulares y Universal ARM físico `~70.6 MB`), certificar censo final `0` archivos `>= 800` L, `PSScriptAnalyzer Problems=0` y cero archivos sensibles modificados. | Guía 1–2 págs. | Auditoría final `git status`, verificación UTF-8 sin BOM, `dart test` + `flutter test --no-pub -j 1`. |

---

### 7.1 Política Obligatoria de Checkpoints Git por Bloque Certificado

Para garantizar reversibilidad inmediata ante cualquier regresión, **nunca** se trabajará sin puntos de restauración limpios:
1. Cada bloque certificado cerrará con un commit atómico en `dev/mejoras-v9.0-comercializacion-seguridad` (**sin `git tag` ni merge a `main`**, nunca usando `git add .` ni agregando secretos/datos reales):
   * **Checkpoint 0 *(CERRADO)*:** `Fase 0` (`.gitattributes`, `compilar_release_dual.ps1` con `0` verbos no aprobados y AST=0, `WebBundleLoader` + `34` tests migrados + `plan25_fase0_hygiene_and_loader_test.dart`, `dart analyze` limpio, `258/258` verde).
   * **Checkpoint 1 *(CERRADO)*:** `Bloque I Admin Backend` (`Fases 1 + 2`, `55` módulos `< 600` L, `11` barrels `1–2` L, `server.dart` = `139` L, `dart analyze` limpio, `265/265` pruebas en verde).
   * **Checkpoint 2 *(CERRADO)*:** `Bloque II Admin Web` (`Fases 3 + 4 + 5A + 5B`, **`0` monolitos en todo `mochilalista_admin/`**, `index.html` = `187` L, `19` CSS `<= 600` L + `18` parciales `<= 445` L + `48` scripts propios `<= 582` L con `?v=25`, `styles.css` y `admin_app.js` retirados, `D-ADM-01..10` cerrados en Admin, `dart analyze` limpio, **`277/277`** en verde + `node --check` OK).
   * **Checkpoint 3 *(CERRADO)*:** `Fase 6` (Core DRY móvil `core/utils/* <= 156 L`, **`403`** `AppCurrency.format`, **`0`** `Clipboard.setData` fuera de `clipboard_helper.dart`, fix WhatsApp `51+phone`, `UniversalImage` `cacheWidth/Height` sin `existsSync`, retiro de **`5`** huérfanos `730` L + `API_KEY`, `flutter analyze = No issues found!`, **`1,447/1,447`** en verde).
   * **Checkpoint 4 *(CERRADO)*:** `Fase 7` (`7A + 7B`: `6` archivos `11,469` L -> `31` módulos cohesivos `<= 625` L, `SQLite v36` 100 % inmutable `MISSING_SQL_DDL=0`, `MISSING_PUBLIC_METHODS=0`, `flutter analyze = No issues found!`, **`1,454/1,454`** en verde).
   * **Checkpoint 5A *(CERRADO)*:** `Fase 8A` (`license_status_and_activation_screen.dart` `287` L, `profile_selection_screen.dart` `509` L y `onboarding_screen.dart` `318` L -> `19` módulos `<= 537` L, `lock_screen.dart` `0` cambios, `MISSING_PUBLIC_CLASSES=0`, `MISSING_WIDGET_KEYS=0`, `0px Overflow @ 1.3x`, `flutter analyze = No issues found!`, **`1,459/1,459`** en verde).
   * **Checkpoint 5B *(CERRADO)*:** `Fase 8B` (`crm_models.dart` `6` L barrel + `7` modelos `<= 483` L; `client_finance_actions_modal.dart` `528` L + `9` módulos `<= 591` L; `cuota_morosidad_modal.dart` `412` L + `3` parts `<= 536` L; `payment_entry_modal.dart` `515` L + `2` parts `<= 585` L; `MISSING_PUBLIC_CLASSES=0`, `MISSING_WIDGET_KEYS=0`, `0px Overflow @ 1.3x`, `flutter analyze = No issues found!`, **`1,464/1,464`** en verde).
   * **Checkpoint 5C *(CERRADO)*:** `Fase 8C` (`8C-1 + 8C-2`: `6` monolitos `12,210` L reales -> `34` archivos cohesivos `<= 580` L, coordinadores `<= 496` L, fixes reales `0px Overflow @ 1.3x` en `notifications_grouped_client_section.dart`, `quick_sale_discount_and_totals_section.dart` y `manual_price_modifier.dart` `545` L, `MISSING_PUBLIC_CLASSES=0`, `MISSING_WIDGET_KEYS=0`, `flutter analyze = No issues found!`, **`1,472/1,472`** en verde).
   * **Checkpoint 6A *(CERRADO)*:** `Fase 9A` (`9A-1 + 9A-2`: `6` monolitos `10,011` L -> `32` archivos cohesivos `<= 534` L, fachada `analytics_provider.dart` `131` L `< 400` L + `4` parts `<= 348` L como instancia única `ChangeNotifier`, fixes `0px Overflow @ 1.3x` en `predictive_analytics/*`, `smart_restock/*`, `radar_card_news_item.dart`, `financial_summary_card.dart` y `kpi_summary_row.dart`, suites `plan25_fase9a1` + `plan25_fase9a2`, `MISSING_PUBLIC_CLASSES=0`, `MISSING_PUBLIC_METHODS=0`, `MISSING_WIDGET_KEYS=0`, `flutter analyze = No issues found!`, **`1,482/1,482`** en verde).
   * **Checkpoint 6B *(CERRADO)*:** `Fase 9B` (`9B-1 + 9B-2`: `5` monolitos `7,838` L -> `25` archivos cohesivos `<= 561` L, `scan_screen.dart` `247` L + `3` parts `<= 428` L, `staging_product_group_card.dart` `183` L + `3` parts `<= 533` L, `invoice_detail_screen.dart` `377` L + `4` parts `<= 561` L, `variant_editor_row.dart` `401` L + `6` módulos `<= 548` L, fachada `scanner_provider.dart` `280` L `< 400` L + `4` parts `<= 403` L como instancia única `ChangeNotifier`, fixes `0px Overflow @ 1.3x` en `_buildSharedMasterPoolBlock` / tarjetas IA / control variante, suites `plan25_fase9b1` + `plan25_fase9b2`, `MISSING_PUBLIC_CLASSES=0`, `MISSING_PUBLIC_METHODS=0`, `MISSING_WIDGET_KEYS=0`, `flutter analyze = No issues found!`, **`1,491/1,491`** en verde).
   * **Checkpoint Parcial 6C-1 *(CERRADO)*:** `Fase 9C — Sub-lote 9C-1` (`catalog_screen.dart` `569` L + `3` parts `<= 460` L, `variant_extract_config_modal.dart` `432` L + `3` parts `<= 446` L, `product_detail_modal.dart` `299` L + `3` parts `<= 445` L, `stock_update_modal.dart` `364` L + `3` parts `<= 422` L -> `16` archivos `<= 569` L, suite `plan25_fase9c1_catalog_detail_stock_modals_test.dart` `611` L, `MISSING_PUBLIC_CLASSES=0`, `MISSING_WIDGET_KEYS=0`, `OVER_LIMIT_FILES=0`, `0px Overflow @ 1.3x`, `flutter analyze = No issues found!`, **`1,495/1,495`** en verde).
   * **Checkpoint Parcial 6C-2 *(CERRADO)*:** `Fase 9C — Sub-lote 9C-2` (`product_create_operations.dart` `292` L + `4` módulos `<= 618` L con `export ProductCreateHydratedData`, `presentation_stock_section.dart` `326` L + `3` parts `<= 413` L, `product_edit_screen.dart` `364` L + `3` parts `<= 367` L, `products_tab.dart` `293` L + `3` parts `<= 503` L -> `17` archivos `<= 618` L + fix responsivo `@ 1.3x` en `inventory_item_tile.dart` `579` L, suite `plan25_fase9c2_catalog_create_edit_products_tab_test.dart` `641` L, `MISSING_PUBLIC_CLASSES=0`, `MISSING_PUBLIC_METHODS=0`, `MISSING_WIDGET_KEYS=0`, `OVER_LIMIT_FILES=0`, `0px Overflow @ 1.3x`, `flutter analyze = No issues found!`, **`1,499/1,499`** en verde).
   * **Checkpoints 6C (`9C-3`) / 6D / 6E:** tras cerrar cada bloque `Fase 9C`, `9D` y `9E` (pudiendo además hacer commit parcial por sub-lote si se ejecuta en turnos independientes).
   * **Checkpoint 7:** `Fase 10` (optimización APK verificada en `--out-dir` temporal + `100 %` pruebas en verde).
   * **Checkpoint 8:** `Fase 11` (`ARQUITECTURA_MODULAR.md` + `Manual 05` + certificación final).

---

> **Estado Actual del Plan Maestro 25 (v3.1):** **Checkpoint Parcial 6C-2 CERRADO — Bloque III Fase 9C Sub-lote `9C-2` (`product_create_operations.dart` `292` L + `4` módulos, `presentation_stock_section.dart` `326` L + `3` parts, `product_edit_screen.dart` `364` L + `3` parts, `products_tab.dart` `293` L + `3` parts -> `17` archivos `<= 618` L + fix `@ 1.3x` en `inventory_item_tile.dart` `579` L + suite `plan25_fase9c2_catalog_create_edit_products_tab_test.dart` `641` L) 100 % COMPLETADO Y CERTIFICADO (`MISSING_PUBLIC_CLASSES=0`, `MISSING_PUBLIC_METHODS=0`, `MISSING_WIDGET_KEYS=0`, `OVER_LIMIT_FILES=0`, `0px Overflow @ 1.3x`, `flutter analyze = No issues found!`, `1,499/1,499` en verde).**  
> **Siguiente Paso:** Ejecutar **Bloque III (`app_movil/`) — Fase 9C (`Sub-lote 9C-3`: `inventory_provider.dart`, `product_stock_strategy_selector.dart`, `presentation_math_engine.dart`, `price_update_modal.dart`)** cerrando definitivamente el **Checkpoint 6C**.
