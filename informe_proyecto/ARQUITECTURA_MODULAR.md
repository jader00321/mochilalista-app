# ARQUITECTURA MODULAR DE MOCHILALISTA (GUÍA DE CONSULTA RÁPIDA)

> **Estado Certificado:** Plan Maestro 25 v5.0 — **0 archivos `>= 800` L** (`778` archivos `.dart` en `app_movil/lib/` + `153` archivos fuente propios en `mochilalista_admin/`), **`1,914/1,914` pruebas en verde** (`277` en `mochilalista_admin/` + `1,637` en `app_movil/`).

---

## 1. MochilaLista Admin Backend (`mochilalista_admin/`)

* **Punto de entrada y router:** [`server.dart`](../mochilalista_admin/server.dart) (`139` L) delega en `lib/http/api_router.dart`, `lib/http/auth_pin_middleware.dart` (PIN local `423 Locked` + cookie `HttpOnly`), `lib/http/static_handler.dart` (anti-traversal y bloqueo `403` a `/partials/*`), `lib/http/html_assembler.dart` y `lib/http/windows_shell_helpers.dart`.
* **Transversal `lib/core/` (`6` utilidades DRY):** `time_utils.dart` (Lima GMT-5), `semver_utils.dart`, `csv_utils.dart` (BOM UTF-8 + RFC-4180), `path_security.dart`, `backup_rotation_helper.dart` (límite `30` snapshots) y `commercial_constants.dart`.
* **`11` Barrels retrocompatibles en `lib/*.dart` (`1–2` L):** `apk_inspector_service.dart`, `client_sync_service.dart`, `commercial_config_sync_service.dart`, `config_service.dart`, `database_service.dart`, `dpapi_service.dart`, `excel_export_service.dart`, `license_signer.dart`, `time_utils.dart`, `vault_crypto_service.dart` y `vault_storage_service.dart`.

| Funcionalidad / Endpoints `/api/*` | Router (`lib/http/routes/`) | Servicios y Repositorios Subyacentes (`lib/`) |
|---|---|---|
| Dashboard y CRM (`/api/dashboard`, `/api/clients*`, `/api/clients/export*`) | `clients_routes.dart` | `data/database_service.dart`, `clients_repository.dart`, `clients_lifecycle_repository.dart`, `payments_receipts_repository.dart`, `core/csv_utils.dart` |
| Finanzas, Excel `.xlsx` y Respaldos (`/api/finances*`, `/api/export/excel*`, `/api/backups*`) | `finances_backups_routes.dart` | `data/finances_export_repository.dart`, `backups_repository.dart`, `export/excel_export_service.dart` (`excel_sheets_builder`, `excel_styles`) |
| Licencias Ed25519 e Inspector (`/api/licenses/generate`, `/api/licenses/inspect`, `/api/sync/*`) | `licenses_sync_routes.dart` | `sync/license_signer.dart`, `client_sync_service.dart`, `mlc1_payload_inspector.dart` |
| Releases APK y Matriz SemVer (`/api/releases*`, descarga, carga y autodetección) | `releases_routes.dart`, `releases_files_routes.dart`, `release_apk_helper.dart` | `data/releases_repository.dart`, `apk/apk_inspector_service.dart` (`apk_binary_tools`, `apk_cache_store`, `apk_companion_notes_reader`, `apk_directory_scanner`, `apk_models`) |
| Configuración, Plantillas WA y `MLC1` (`/api/config*`) | `config_routes.dart` | `config/config_service.dart` (`config_defaults`, `config_normalizer`, `config_apk_dirs_helper`, `config_template_renderer`), `sync/commercial_config_sync_service.dart`, `dart_defaults_exporter.dart` |
| Bóveda DPAPI, `.mlvault` y PIN (`/api/vault/*`) | `vault_routes.dart` | `vault/vault_storage_service.dart`, `vault_crypto_service.dart`, `dpapi_service.dart`, `vault_integrity_auditor.dart`, `vault_package_codec.dart`, `vault_pin_session_manager.dart` |
| Modo Sandbox/Prod, Chrome y Apagado (`/api/system/*`, `/api/mode`) | `system_routes.dart` | `data/database_service.dart`, `sandbox_seed_data.dart`, `core/path_security.dart`, `core/time_utils.dart` |

---

## 2. MochilaLista Admin Web (`mochilalista_admin/web/` — Zero-Bundler `?v=25`)

* **Cascada CSS (`19` hojas `css/*?v=25`):** `00_tokens.css` → `01_layout_shell.css` → `02_components_core.css` → `03_components_modals.css` → `modules/*.css` (`11` hojas) → `90_light_theme_base.css` → `91_light_theme_modules.css` → `95_responsive.css` → `99_print.css`.
* **Núcleo y Estado JS (`?v=25`):** Vendor (`qrcode.min.js`, `jsqr.min.js`), `js/core/` (`fetch_auth.js`, `semver.js`, `time_lima.js`, `formatters.js`, `clipboard.js`, `whatsapp.js`, `qr_utils.js`, `canvas_pdf_utils.js`, `ui_feedback.js`), `js/state/app_store.js` y arranque en `js/bootstrap.js`.
* **HTML ensamblado en memoria:** `web/index.html` combina los `18` parciales `web/partials/**` vía `HtmlTemplateAssembler`; toda petición directa HTTP a `/partials/*` recibe `403`.

| Pestaña / Modal / Drawer | Parcial HTML (`web/partials/`) | CSS Modular (`web/css/modules/`) | Módulos JS (`web/js/modules/`) |
|---|---|---|---|
| Navegación y Sidebar | `layout/sidebar.html` | `01_layout_shell.css` (base) | `navigation_theme.js` |
| Dashboard KPIs (`#tabDashboard`) | `tabs/tab_dashboard.html` | `dashboard_crm.css` | `dashboard.js` |
| Cartera CRM (`#tabClients`) | `tabs/tab_clients.html`, `modals/modals_clients_crm.html`, `modals_sync_migration.html` | `dashboard_crm.css` | `clients_crm.js`, `client_sync_reported.js`, `client_sync_global.js`, `modals_crud_clients.js`, `modals_history_and_migrate.js` |
| Ficha 360° Drawer | `drawers/client_360_drawer.html` | `crm_drawer.css` | `drawer_360_core.js`, `drawer_360_profile_tab.js`, `drawer_360_payments.js` |
| Generador Licencias y Comprobantes | `tabs/tab_license_studio.html`, `modals/modals_licenses_wa.html`, `modals/modals_receipts.html` | `receipts_modal.css`, `wa_composer.css` | `license_projection.js`, `license_studio.js`, `license_emission.js`, `license_credential_canvas.js`, `receipts_preview_and_canvas.js`, `receipts_canvas_render.js`, `receipts_export_and_events.js`, `whatsapp_templates.js`, `whatsapp_composer.js` |
| Versiones APK (`#tabReleaseManager`) | `tabs/tab_release_manager.html`, `modals/modals_releases.html` | `releases_catalog.css`, `releases_matrix.css` | `releases_catalog.js`, `releases_edit_and_verify.js`, `releases_matrix.js`, `releases_wa_dispatch.js`, `releases_upload_and_dual_guide.js`, `releases_create_and_local_builds.js`, `releases_search_dirs_and_upload.js` |
| Inspector Tri-Protocolo (`#tabInspector`) | `tabs/tab_inspector.html` | `inspector_sync.css` | `inspector_history_and_qr.js`, `inspector_mlc1_render.js`, `inspector_sync_and_dispatch.js` |
| Finanzas & Respaldos (`#tabFinancesAndBackups`) | `tabs/tab_finances_backups.html`, `modals/modals_backups_preview.html` | `finances_backups.css` | `finances_backups.js`, `excel_export.js` |
| Configuración y `MLC1` (`#tabSettings`) | `tabs/tab_settings.html`, `modals/modals_settings_mlc1.html` | `settings_center.css`, `settings_mlc1.css` | `settings_core_and_dirty.js`, `settings_form_and_templates.js`, `mlc1_sync_exporter.js` |
| Bóveda Seguridad (`#tabSecurityVault`) | `tabs/tab_security_vault.html`, `modals/modals_vault_security.html` | `security_vault.css` | `security_vault_health.js`, `security_vault_portability.js`, `security_vault_pin.js` |

---

## 3. App Móvil (`app_movil/lib/` — `778` `.dart`, `0` archivos `>= 800` L)

* **Utilidades DRY compartidas (`core/utils/` y `core/widgets/`):** `AppCurrency` (`currency_formatter.dart`), `AppDateFormatter` (`app_date_formatter.dart`), `ClipboardHelper` (`clipboard_helper.dart`), `WhatsAppUriBuilder` (`whatsapp_uri_builder.dart`), `AppFeedbackHelper` (`app_feedback_helper.dart`) y `UniversalImage` (`core/widgets/universal_image.dart` con `cacheWidth/Height` y sin `existsSync()` en `build()`).
* **SQLite `v36` inmutable (`core/database/`):** `local_db.dart` (`LocalDatabase`) + parts `local_db_schema_v36.dart`, `local_db_migrations.dart`, `local_db_loyalty_init.dart`, junto a `database_connection_factory.dart` y `product_queries.dart`.
* **Proveedores `ChangeNotifier` únicos y configuración comercial:** `NotificationProvider` (`core/providers/notification_provider*.dart`), `AnalyticsProvider` (`features/analytics/providers/analytics_provider*.dart`), `ScannerProvider` (`features/scanner/providers/scanner_provider*.dart`), `InventoryProvider` (`features/catalog/providers/inventory_provider.dart` + `inventory/`), `SaleProvider` (`features/smart_quotation/providers/sale_provider.dart` + `sale/`); `OwnerCommercialDefaults` (`core/config/owner_commercial_defaults.dart`) consumido por `OwnerLegalIdentity` (`core/config/owner_legal_identity.dart`).

| Área / Feature | Coordinadores, Pantallas y Servicios Principales | Sub-módulos / Parts / Helpers (`app_movil/lib/`) |
|---|---|---|
| **Inicio, Widgets y Onboarding** | `main.dart`, `core/screens/home_screen.dart`, `auth/screens/onboarding/` (`lock_screen.dart` intacto, `onboarding_screen.dart`, `profile_selection_screen.dart`), `license_status_and_activation_screen.dart` | `core/screens/home/`, `core/widgets/home/` (`dashboard_header/`, `smart_action_grid/`), `core/widgets/search/` (`omni_search_bar.dart` + 6 módulos), `core/widgets/{filter_drawer,live_filter,export_options,discount_intelligent,persistent_work_dock}/`, `features/auth/screens/license/widgets/activation_feedback/` |
| **Analytics & Radar Comercial** | `analytics_dashboard_screen.dart`, `commercial_radar_screen.dart`, `predictive_analytics_screen.dart`, `smart_restock_screen.dart`, `audit_trail_screen.dart`, `commercial_radar_service.dart` | `features/analytics/screens/{analytics_dashboard,audit_trail,commercial_radar,predictive_analytics,smart_restock}/`, `features/analytics/services/commercial_radar_{persistence,scoring,sources}.dart`, `widgets/dashboard/commercial_radar_card/` |
| **Catálogo & Inventario** | `product_repository.dart`, `inventory_provider.dart`, `catalog/catalog_screen.dart`, `product_edit_screen.dart`, `tabs/products_tab.dart`, `product_detail_modal.dart`, `stock_update_modal.dart`, `price_update_modal.dart` | `features/catalog/repositories/product_repository_*.dart`, `providers/inventory/`, `screens/{catalog,product_edit,tabs/widgets}/`, `widgets/edit/product_edit/operations/`, `widgets/form/{create_operations,stock_strategy}/`, `widgets/variants/extract_config/`, `core/widgets/presentation_card/{math_engine,stock_section}/`, `core/widgets/{price_update,product_detail,stock_update}/` |
| **Perfil, Drive, Notif & Promos** | `profile_screen.dart`, `backup_screen.dart`, `ai_settings_screen.dart`, `notifications_screen.dart`, `business_backup_service.dart`, `google_drive_backup_sheet.dart`, `offers_tab.dart`, `bundle_builder_screen.dart` | `features/profile/screens/{ai_settings,backup,notifications,profile}/`, `services/business_backup/`, `widgets/google_drive/`, `widgets/notifications/{settings,stock_analysis}/`, `features/promotions/screens/{offers_tab,bundle_builder}/` |
| **Escáner & Facturas** | `scan_screen.dart`, `invoice_detail_screen.dart`, `invoice_staging_screen.dart`, `invoice_pdf_report_service.dart`, `comparative_update_modal.dart` | `features/scanner/providers/scanner_provider_*.dart`, `screens/{scan,invoice_detail,invoice_staging}/`, `services/invoice_pdf_report/`, `widgets/staging/{comparative_modal,product_group,variant_editor}/` |
| **Cotizaciones, POS & CRM** | Barrel `models/crm_models.dart` (`6` L → `7` archivos), `client_service.dart`, `sales_service.dart`, `quotation_service.dart`, `loyalty_whatsapp_service.dart`, `pdf_generator.dart`, `workbench_screen.dart`, `manual_quotation_screen.dart`, `matching_screen.dart`, `quotation_detail_screen.dart`, `whatsapp_preview_screen.dart`, `quick_sale_screen.dart`, `sale_history_detail_screen.dart`, `crm/loyalty_center_screen.dart`, `crm/sale_financial_detail_screen.dart` | `features/smart_quotation/services/{client_service_*,sales_service_*,quotation/,loyalty_whatsapp/}`, `utils/pdf/`, `screens/{extraction_result,manual/,manual_quotation/,matching/,pdf_preview/,quick_sale/,quotation_detail/,sale_history_detail/,whatsapp_preview/,crm/loyalty_center/,crm/sale_financial_detail/}`, `widgets/crm/{client_stats,finance_actions,ledger_timeline,loyalty_history}/`, `widgets/history/detail_widgets/{cuota_morosidad_modal.dart,whatsapp_preview/}`, `widgets/{manual/detail_modal,matching/detail_modal,matching/item_row,quick_sale/detail_modal,quick_sale/header,smart_update}/` |

---

## 4. Compilación Dual Release, Higiene Técnica y Red de Pruebas (`1,914` tests)

1. **Cadena de Build Release Dual (ARM físico + compatibilidad emulador intacta):**
   [`compilar_release_dual.bat`](../compilar_release_dual.bat) → [`scripts/compilar_release_dual.ps1`](../scripts/compilar_release_dual.ps1) (Higiene A: parser AST `0` errores, `0` verbos fuera de `(Get-Verb).Verb`, único BOM `EF BB BF`, `CRLF` puro; compila Universal con `--target-platform android-arm64,android-arm` exigiendo `arm64-v8a` + `armeabi-v7a` sin `x86_64` y ARM64 Ligero con `--split-per-abi`) → [`app_movil/android/app/build.gradle.kts`](../app_movil/android/app/build.gradle.kts) (sincronización condicional de `ndk.abiFilters` cuando `!split-per-abi && target-platform`, preservando intactas reglas R8/ProGuard, `--split-per-abi` y `flutter run` en `x86_64`). Resultados reales en Fase 10: Universal **`70.41 MB` (`73,832,529` B, `-34.64 %`)** y ARM64 Ligero **`38.55 MB` (`40,426,427` B)**.
2. **Higiene Git y Pruebas Automatizadas:** `.gitattributes` en la raíz fija `eol=crlf` (`.bat`/`.ps1`) y `eol=lf` (`.dart`/`.js`/`.css`/`.html`/`.md`); la red combinada de **`1,914` pruebas** corre sobre **`59` archivos (`277` tests)** en `mochilalista_admin/test/` (cargador único [`test/support/web_bundle_loader.dart`](../mochilalista_admin/test/support/web_bundle_loader.dart)) y **`171` archivos (`1,637` tests)** en `app_movil/test/`.
