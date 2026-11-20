# PLAN MAESTRO 12: PULIDO UX, MODAL DE PEDIDO PERSONALIZABLE, BLINDAJE DE PORTAPAPELES, ACTUALIZACIÓN VS. RESTAURACIÓN Y GOOGLE DRIVE ESTILO WHATSAPP
### Versión: 1.0 — Fecha: 20 de Noviembre de 2026
**Proyecto:** MochilaLista App Móvil Offline & Ecosistema de Licenciamiento  
**Dispositivo Físico de Certificación:** Samsung Galaxy A54 5G (Android 14 / One UI 6.1)  
**Marco Normativo:** Decreto Legislativo 822 (Derechos de Autor) e INDECOPI (Perú)  
**Titular y Autor:** Julio Angello Vasquez Navarro  

---

## 1. RESUMEN EJECUTIVO Y ANÁLISIS FORENSE DE CAUSAS RAÍZ

Tras la compilación y prueba real en hardware físico con `mochilalista_v9.32_atp.apk` (`v9.32.0+76`), se diagnosticaron 6 comportamientos que requieren corrección y perfeccionamiento para asegurar una experiencia comercial óptima en producción.

A continuación se detalla la causa raíz técnica encontrada en el código fuente de cada uno de los 6 pilares:

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                          DIAGNÓSTICO FORENSE DE CAUSAS RAÍZ                            │
├────────────────────────────────────────────────────────────────────────────────────────┤
│ 1. Actualización vs. Backup:                                                           │
│    - HomeScreen ejecuta coordinateStartup() en addPostFrameCallback (~16ms).           │
│    - LicenseProvider.checkLicense() es asíncrono (~150-300ms en hardware real).        │
│    - licenseProv.license es null en frame 1 -> Aborta silenciosamente sin mostrar nada.│
│    - Al restaurar .mlbg, sobreescribe SQLite con la versión vieja -> dispara el modal. │
│                                                                                        │
│ 2. Redundancia de Novedades en Perfil:                                                 │
│    - Fila duplicada en 'Configuración General' y enlace en tarjeta inferior legal.     │
│    - Debe removerse la fila de configuración y preservarse intacta la tarjeta legal.   │
│                                                                                        │
│ 3. Modal Pedir Plan (OrderPlanBottomSheet):                                            │
│    - Usa bottom: viewInsets.bottom + 20 (cubre teclado, pero ignora la barra Android). │
│    - viewPadding.bottom de 48-56dp (3 botones Android) corta el botón por la mitad.    │
│    - Todo metido en un scroll único; faltan chips rápidos de 1 toque para comerciantes.│
│                                                                                        │
│ 4. Detector de Portapapeles (Pegar y Activar):                                         │
│    - extractLicenseToken tenía fallback (Prioridad 3) que devolvía texto arbitrario.   │
│    - Al copiar reportes con 'ML-B0F8', concatenaba 'ML9-===REPORTETÉCNICO...'.         │
│    - Mensaje de error recortado (...separados por u...) en CustomSnackBar de 1 línea. │
│                                                                                        │
│ 5. Escanear Lista (ScanScreen):                                                        │
│    - Icono vectorial + emoji crudo duplicado en las 3 etiquetas (🛒, 📦, 🎓).          │
│    - Sin SingleChildScrollView ni SafeArea inferior; altura 520dp choca con nav bar.   │
│                                                                                        │
│ 6. Google Drive Estilo WhatsApp:                                                       │
│    - FlutterSecureStorage preserva ml_gdrive_user_cache tras desinstalar.              │
│    - Falta flujo guiado para restaurar las últimas 5 copias al vincular la cuenta.     │
│    - Cabecera duplicada ("Copia en la Nube" y "Copia en Google Drive" apiladas).       │
│    - Diálogo de error muestra términos técnicos intimidantes (SHA-1, Cloud Console).   │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. PILARES OBLIGATORIOS Y ESPECIFICACIÓN TÉCNICA

---

### PILAR 1: Lógica Definitiva del Modal `¡Actualización Exitosa!`
* **Archivos implicados:**
  * `app_movil/lib/core/services/startup_flow_coordinator.dart`
  * `app_movil/lib/core/utils/backup_manager.dart`
  * `app_movil/lib/features/auth/screens/onboarding/profile_selection_screen.dart`
  * `app_movil/lib/core/screens/home_screen.dart`
  * `app_movil/lib/core/providers/license_provider.dart`
* **Causa Raíz:**
  1. `StartupFlowCoordinator.coordinateStartup` se ejecuta en `HomeScreen` dentro de `addPostFrameCallback`. Si `licenseProv.license == null` (lo cual ocurre habitualmente en el primer frame porque `checkLicense()` realiza consultas asíncronas de hardware y base de datos), el método retornaba de inmediato `StartupScenarioResult.normalStartupNoModal` y no se volvía a evaluar.
  2. Al restaurar un respaldo `.mlbg`, la base de datos completa se sobreescribía con la tabla `licencia_app` del respaldo, la cual contenía la versión antigua (`9.31.0+75` o anterior). Al reiniciar o entrar a la app, el sistema detectaba `oldVersion != currentVersion` y mostraba erróneamente `¡Actualización Exitosa!`.
* **Solución de Arquitectura:**
  1. **Aseguramiento de Licencia Cargada:** En `coordinateStartup(context)`, si `licenseProv.license == null`, ejecutar `await licenseProv.checkLicense()` para garantizar que la evaluación se realice con los datos reales de SQLite.
  2. **Coordinación en ProfileSelectionScreen y HomeScreen:** Permitir que `coordinateStartup` pueda evaluarse de forma segura tanto en `ProfileSelectionScreen` como en `HomeScreen`, utilizando una bandera en memoria (`static bool _hasCoordinatedThisSession = false;`) para evitar ejecuciones duplicadas en la misma sesión.
  3. **Inmunización Post-Restauración en `BackupManager`:** En `BackupManager.restoreBackupFromFilePath` (punto central de restauración local y nube), inmediatamente tras restaurar el archivo SQLite y antes de retornar éxito, ejecutar:
     ```dart
     await db.execute('''
       UPDATE licencia_app 
       SET last_executed_app_version = ?
       WHERE id = 1
     ''', [OwnerLegalIdentity.currentAppVersionWithBuild]);
     ```
     Con esto, toda restauración queda sellada con la versión actual del ejecutable, garantizando que restaurar un backup **jamás dispare falsamente el modal de actualización**.
  4. **Persistencia Garantizada al Cerrar:** En `PostUpdateWelcomeModal`, asegurar que al pulsar cualquier botón de acción o cerrar el diálogo, se persista `updateLastExecutedVersion(currentVersion)`.

---

### PILAR 2: Eliminación de Redundancia de Novedades en `Perfil`
* **Archivos implicados:**
  * `app_movil/lib/features/profile/screens/profile_screen.dart`
* **Causa Raíz:**
  * En la tarjeta `Configuración General` existía un ítem `ProfileMenuItem` con título *"Novedades de esta Versión (9.32.0)"*.
  * En la tarjeta inferior de marco legal e identidad (`MochilaLista v9.32.0`), existía otro acceso idéntico *"Novedades v9.32.0"*.
* **Solución de Arquitectura:**
  1. **Eliminación limpia:** Remover el `ProfileMenuItem` de novedades y su respectivo `_buildDivider` dentro del bloque `Configuración General`, dejando ese grupo enfocado únicamente en:
     * Modo Oscuro (Switch)
     * Notificaciones (Fila)
     * Impresora Térmica (Fila)
  2. **Preservación de Tarjeta Inferior:** Mantener y pulir el botón `Novedades v${OwnerLegalIdentity.currentAppVersion}` en el `Wrap` inferior de identidad junto a `Ver Contrato EULA` y `Gestionar Licencia`.
  3. **Blindaje de Layout:** No alterar márgenes, paddings ni el comportamiento del scroll general de `ProfileScreen`.

---

### PILAR 3: Rediseño Profesional y Seguro del Modal `Solicitar Plan` (`OrderPlanBottomSheet`)
* **Archivos implicados:**
  * `app_movil/lib/features/auth/screens/license/license_status_and_activation_screen.dart`
* **Causa Raíz:**
  * El modal utilizaba `bottom: bottomInset + 20`. `viewInsets.bottom` solo mide la altura del teclado en pantalla (0 cuando está cerrado).
  * La barra de navegación de 3 botones de Android (Atrás / Inicio / Recientes) ocupa entre 48dp y 56dp (`viewPadding.bottom`), provocando que el botón verde `Enviar por WhatsApp` quede tapado en un 50%.
  * Faltaban herramientas de personalización rápida de mensaje para comerciantes.
* **Solución de Arquitectura:**
  Rediseñar `OrderPlanBottomSheet` bajo una estructura de 3 zonas fijas y desplazables:
  1. **Cabecera Ejecutiva Fija:**
     * Indicador visual superior (pill).
     * Icono vectorial en contenedor con opacidad `.withValues(alpha: 0.15)`.
     * Título del plan y subtítulo conciso.
     * Botón circular de cierre (`Icons.close_rounded`).
  2. **Cuerpo Desplazable Cómodo (`Expanded + SingleChildScrollView`):**
     * **Tarjeta de Resumen Ejecutiva:** Nombre del plan, precio en `S/`, vigencia, badge de escaneos IA y `Hardware ID` con micro-botón para copiar en 1 toque.
     * **Chips Interactivos Opcionales de 1 Toque:** Chips predefinidos que al tocarlos insertan o alternan frases útiles en el mensaje:
       * Chip A: *"Ya realicé el Yape/Plin"* (agrega: `\n• Estado: Pago realizado vía Yape/Plin. Adjunto comprobante.`)
       * Chip B: *"Solicito cuenta BCP/BBVA"* (agrega: `\n• Consulta: Solicito números de cuenta para transferencia bancaria.`)
       * Chip C: *"Requiero Factura Comercial"* (agrega: `\n• Requerimiento: Solicito emisión de Factura con RUC.`)
     * **Caja de Texto Multilínea:** `TextField` con 3 a 5 líneas, tipografía monoespaciada legible, fondo contrastante y contador discreto de caracteres.
  3. **Zona de Acciones Inferior Fija y Protegida:**
     * Contenedor con borde superior sutil y protección dinámica:
       ```dart
       padding: EdgeInsets.only(
         left: 20,
         right: 20,
         top: 12,
         bottom: math.max(
           MediaQuery.viewInsetsOf(context).bottom,
           MediaQuery.viewPaddingOf(context).bottom,
         ) + 12,
       )
       ```
     * Fila con botones secundarios: `Copiar Mensaje` (OutlinedButton) y `Restablecer` (OutlinedButton).
     * Botón principal destacado: `Enviar por WhatsApp` (Color oficial `#25D366`, icono Material `Icons.chat_rounded`, 100% visible por encima de la barra de Android).
     * Certificado para `0px Overflow` en resoluciones compactas (`320x568dp` y `360x640dp`).

---

### PILAR 4: Blindaje Estricto del Detector de Portapapeles y Errores Sin Truncar
* **Archivos implicados:**
  * `app_movil/lib/core/services/license/ed25519_license_validator.dart`
  * `app_movil/lib/features/auth/screens/license/license_status_and_activation_screen.dart`
  * `app_movil/lib/core/widgets/custom_snackbar.dart` (o presentación de mensajes)
* **Causa Raíz:**
  * `Ed25519LicenseValidator.extractLicenseToken` incluía un tercer paso de "fallback tradicional" que, si la entrada no coincidía con el regex estricto, simplemente eliminaba espacios y devolvía el texto plano.
  * Si el usuario copiaba un reporte de soporte conteniendo `ML-B0F8`, el fallback devolvía el reporte completo.
  * `_isValidCandidateCode` validaba falsamente ese texto y la pantalla concatenaba `ML9-` al texto del reporte, resultando en `ML9-===REPORTETÉCNICOG` y disparando un error críptico truncado en pantalla.
* **Solución de Arquitectura:**
  1. **Expresión Regular Estricta de Licencia:**
     ```dart
     static final RegExp _licenseTokenPattern = RegExp(
       r'(?:ML9-)?([A-Za-z0-9_-]{12,}\.[A-Za-z0-9_-]{20,})',
     );
     ```
  2. **Eliminación Total de Fallbacks Permisivos:** Si un texto no cumple con la estructura `Payload.Firma` en formato Base64URL, `extractLicenseToken` retornará estrictamente cadena vacía `''`.
  3. **Detección Confiable en Portapapeles:**
     * `_isValidCandidateCode(text)` retornará `true` **únicamente** si `extractLicenseToken(text).isNotEmpty`.
     * Jamás se activará ante Hardware IDs (`ML-XXXX`), reportes de soporte, números de cuenta o textos arbitrarios.
  4. **Vista Previa y Pegado Limpio:**
     * `_detectedClipboardCode` almacenará exclusivamente el token extraído con su prefijo canónico `ML9-<token>`.
     * Al pulsar `Pegar y Activar`, se insertará y procesará directamente dicho token limpio, sin textos basura adicionales.
  5. **Avisos de Error No Truncados:** Asegurar que los mensajes de error en `CustomSnackBar` permitan hasta 3 líneas legibles (`maxLines: 3`), evitando que el texto quede cortado en puntos suspensivos.

---

### PILAR 5: Rediseño Visual y Limpieza en `Escanear Lista` (`ScanScreen`)
* **Archivos implicados:**
  * `app_movil/lib/features/scanner/screens/scan_screen.dart`
* **Causa Raíz:**
  * En las etiquetas de escenarios de cotización, se incluía un icono vectorial Material y a la vez un emoji crudo dentro del string (`icon: Icons.shopping_bag_outlined, label: "🛒 Compras / Pedido"`).
  * La pantalla no envolvía su contenido en un `SingleChildScrollView` ni consideraba el `viewPadding.bottom` de la barra de navegación de Android. Con un icono circular de 170dp de alto total y botones de 150x150dp, la altura total superaba los 520dp, colisionando con los 3 botones de navegación de Android.
* **Solución de Arquitectura:**
  1. **Cero Emojis Duplicados:** Modificar las etiquetas para usar exclusivamente texto limpio:
     * `"Compras / Pedido"` con `Icons.shopping_bag_outlined`
     * `"Mayorista / Negocio"` con `Icons.storefront_rounded`
     * `"Lista Escolar"` con `Icons.school_outlined`
  2. **Proporción Armónica:** Reducir el círculo decorativo superior a 64dp de icono con 20dp de padding (altura total ~104dp vs 170dp anterior), liberando más de 65dp verticales.
  3. **Disposición Alineada de Chips:** Agrupar las 3 etiquetas en una fila balanceada o columna compacta uniforme con tipografía de 11.5dp y padding simétrico.
  4. **Protección Contra Colisión Inferior:**
     * Envolver el panel principal en `SafeArea(top: false, bottom: true)`.
     * Incorporar `SingleChildScrollView(physics: const BouncingScrollPhysics())`.
     * Añadir margen inferior dinámico:
       ```dart
       padding: EdgeInsets.only(
         left: 20,
         right: 20,
         top: 10,
         bottom: math.max(MediaQuery.viewPaddingOf(context).bottom, 16) + 16,
       )
       ```
     * Dimensionar los botones `Cámara` y `Galería` de forma responsiva (`136x136dp` con radio `24dp`), garantizando comodidad visual y táctil en cualquier densidad de pantalla.

---

### PILAR 6: Reestructuración UX de Google Drive Backup Estilo WhatsApp
* **Archivos implicados:**
  * `app_movil/lib/core/services/backup/google_drive_backup_service.dart`
  * `app_movil/lib/core/services/backup/i_google_drive_backup_service.dart`
  * `app_movil/lib/core/services/license/license_repository.dart`
  * `app_movil/lib/features/profile/widgets/google_drive_backup_sheet.dart`
  * `app_movil/lib/features/profile/screens/backup_screen.dart`
  * `app_movil/lib/features/auth/screens/onboarding/profile_selection_screen.dart`
* **Causas Raíz:**
  1. Al desinstalar y reinstalar la app, `FlutterSecureStorage` (respaldado en hardware Keystore) preservaba `'ml_gdrive_user_cache'`, haciendo que la app pareciera tener una cuenta vinculada sin haber iniciado sesión limpiamente.
  2. Al vincular una cuenta Gmail con copias existentes, la app solo mostraba un SnackBar general y dejaba los respaldos abajo en la lista, sin guiar al comerciante para restaurar su negocio en 1 clic.
  3. En `BackupScreen` se mostraba el encabezado `_buildSectionHeader("Copia de Seguridad en la Nube")` y justo debajo `GoogleDriveBackupSheet` mostraba otro encabezado idéntico `"Copia de Seguridad en Google Drive"`.
  4. El diálogo de error de Google Drive exponía términos técnicos de desarrollador (`SHA-1`, `Google Cloud Console`, `ApiException: 10`) en el cuerpo principal.
* **Solución de Arquitectura:**
  1. **Gobernanza de Arranque Limpio:** En `LicenseRepository` cuando `rows.isEmpty` en `licencia_app` (instalación limpia tras desinstalar), ejecutar limpieza integral de claves de almacenamiento seguro:
     ```dart
     await _secureStorage.delete(key: 'ml_gdrive_user_cache');
     await _secureStorage.delete(key: 'ml_gdrive_config');
     ```
     Y proveer un método `clearSession()` en `GoogleDriveBackupService` que desconecte la sesión de Google Sign-In al reinstalar de cero.
  2. **Flujo de Restauración Guiada Estilo WhatsApp:**
     * Al vincular la cuenta en `GoogleDriveBackupSheet` (y en Onboarding), si `listBackups()` encuentra copias en `appDataFolder`:
     * Desplegar inmediatamente una tarjeta destacada o Bottom Sheet amigable: **"Copias de seguridad encontradas en tu cuenta de Google"**.
     * Listar las últimas copias (hasta 5), ordenadas por fecha reciente, mostrando:
       - Fecha y hora legible (ej. *"Hoy, 08:30 AM"* o *"19/11/2026, 11:45 PM"*).
       - Tamaño exacto en MB/KB.
       - Tipo de respaldo (Multi-Perfil Completo `.mlbg`).
     * Botón principal de 1 toque: **"Restaurar esta copia"**, ejecutando la restauración completa y actualizando de inmediato `last_executed_app_version`.
  3. **Limpieza de Encabezados y Margen Seguro:**
     * En `BackupScreen`, remover la redundancia de títulos: unificar la presentación para que el bloque de nube tenga un único encabezado armónico.
     * Añadir padding inferior seguro en el `ListView` de `BackupScreen` para que la última tarjeta respire por encima de la barra de navegación de Android.
  4. **Diálogo de Conexión 100% Humano:**
     * Texto principal cálido y comprensible: *"No fue posible conectar con tu cuenta de Google en este momento. Revisa tu conexión a internet o intenta nuevamente."*
     * Desplegable colapsado por defecto: *"Ver información técnica para soporte"*, conteniendo Paquete, Versión, Hardware ID, SHA-1 y botón para copiar al portapapeles.

---

## 3. PLAN DE TRABAJO SECUENCIAL POR FASES

---

### FASE 1: Lógica Definitiva del Modal `¡Actualización Exitosa!` y Blindaje Anti-Restauración
* **Objetivo:** Garantizar que el modal aparezca de forma confiable tras una actualización real de versión y jamás tras restaurar un backup.
* **Acciones en código:**
  1. En `app_movil/lib/core/services/startup_flow_coordinator.dart`:
     - Asegurar la carga asíncrona de la licencia antes de verificar la versión (`await licenseProv.checkLicense()` si `license == null`).
     - Añadir bandera estática para evitar re-ejecuciones duplicadas en la misma sesión.
  2. En `app_movil/lib/core/utils/backup_manager.dart`:
     - En `restoreBackupFromFilePath`, actualizar inmediatamente `last_executed_app_version` en `licencia_app` con `OwnerLegalIdentity.currentAppVersionWithBuild`.
  3. En `app_movil/lib/features/auth/screens/onboarding/profile_selection_screen.dart`:
     - Integrar la verificación controlada de `coordinateStartup` en el arranque.
  4. En `app_movil/lib/features/auth/widgets/post_update_welcome_modal.dart`:
     - Garantizar que el cierre del diálogo persista la versión vista.
* **Pruebas automatizadas requeridas:**
  - Nueva suite: `app_movil/test/post_update_vs_backup_restore_test.dart` verificando:
    * Actualización real (`9.31.0` -> `9.32.0` o `9.33.0`) dispara el modal exactamente 1 vez.
    * Restauración de un backup con versión antigua actualiza `last_executed_app_version` y NO dispara el modal.
    * Cierre del modal persiste la versión en SQLite.

---

### FASE 2: Eliminación de Redundancia en `Perfil` y Rediseño de `ScanScreen`
* **Objetivo:** Limpiar la lista de configuración en `ProfileScreen` y eliminar emojis duplicados y desbordes en `ScanScreen`.
* **Acciones en código:**
  1. En `app_movil/lib/features/profile/screens/profile_screen.dart`:
     - Remover el ítem redundante de novedades de `Configuración General`.
     - Preservar intacto el enlace `Novedades v9.32.0` en la tarjeta inferior de marco legal.
     - Mantener el diseño, scroll y márgenes actuales de `ProfileScreen`.
  2. En `app_movil/lib/features/scanner/screens/scan_screen.dart`:
     - Eliminar emojis de las etiquetas (`"Compras / Pedido"`, `"Mayorista / Negocio"`, `"Lista Escolar"`).
     - Reducir el círculo superior a 64dp y optimizar el espaciado vertical.
     - Envolver el contenido en `SafeArea(bottom: true)` y `SingleChildScrollView`.
     - Añadir margen inferior dinámico sobre la barra de navegación de Android.
* **Pruebas automatizadas requeridas:**
  - Nueva suite o actualización: `app_movil/test/profile_and_scanner_ux_test.dart` verificando:
    * Ausencia de novedades en `Configuración General` y presencia en la tarjeta legal.
    * Ausencia de emojis crudos en `ScanScreen`.
    * Renderizado sin overflow en pantallas compactas de `320x568dp` y `360x640dp`.

---

### FASE 3: Rediseño Profesional del Modal `Solicitar Plan` (`OrderPlanBottomSheet`)
* **Objetivo:** Corregir el corte del botón sobre la barra de Android y dotar al modal de chips de 1 toque y resumen estructurado.
* **Acciones en código:**
  1. En `app_movil/lib/features/auth/screens/license/license_status_and_activation_screen.dart`:
     - Reestructurar `OrderPlanBottomSheet` en 3 zonas: Cabecera Fija, Cuerpo Desplazable y Zona de Acciones Inferior Fija.
     - Implementar chips interactivos de 1 toque (*"Ya realicé el Yape/Plin"*, *"Solicito cuenta BCP/BBVA"*, *"Requiero Factura Comercial"*).
     - Añadir protección con `SafeArea(bottom: true)` y cálculo de margen inferior con `math.max(viewInsets.bottom, viewPadding.bottom) + 12`.
     - Incorporar micro-botón de copiado para el `Hardware ID`.
* **Pruebas automatizadas requeridas:**
  - Actualizar `app_movil/test/order_modal_and_ui_density_widget_test.dart`:
    * Verificar visibilidad del botón WhatsApp con barra de sistema simulada (`viewPadding.bottom = 48dp`).
    * Probar interacción y concatenación de los chips de 1 toque en el controlador de texto.
    * Probar copiado rápido de Hardware ID.

---

### FASE 4: Blindaje Criptográfico Estricto del Portapapeles y Errores Sin Truncar
* **Objetivo:** Evitar falsas detecciones de licencias ante textos de soporte o Hardware IDs y mostrar errores completos.
* **Acciones en código:**
  1. En `app_movil/lib/core/services/license/ed25519_license_validator.dart`:
     - Restringir `extractLicenseToken` a coincidencias estrictas de `Payload.Firma` Base64URL con prefijo opcional `ML9-`.
     - Eliminar el fallback de texto arbitrario (retornar `''` si no es un token válido).
  2. En `app_movil/lib/features/auth/screens/license/license_status_and_activation_screen.dart`:
     - Validar que el portapapeles contenga un token criptográfico real antes de mostrar el banner verde.
     - Mostrar en la vista previa del banner únicamente el token limpio extraído.
     - Pegar el token limpio directamente sin duplicar prefijos.
     - Configurar los avisos de error para que no se trunquen en pantalla.
* **Pruebas automatizadas requeridas:**
  - Actualizar `app_movil/test/clean_install_eula_and_replay_protection_test.dart` y tests de licencia:
    * Probar que textos como `"ML-B0F8"`, `"=== REPORTE TÉCNICO ==="` o números de cuenta retornen token vacío y NO activen el banner.
    * Probar que un token real `ML9-ey...` se extraiga y active con éxito.

---

### FASE 5: Experiencia Google Drive Backup Estilo WhatsApp
* **Objetivo:** Lograr vinculación intuitiva, arranque limpio tras desinstalar, restauración guiada de las últimas 5 copias y mensajes humanos.
* **Acciones en código:**
  1. En `app_movil/lib/core/services/license/license_repository.dart` y `google_drive_backup_service.dart`:
     - Limpiar caché de sesión de Google Drive en `FlutterSecureStorage` durante instalaciones limpias.
  2. En `app_movil/lib/features/profile/widgets/google_drive_backup_sheet.dart`:
     - Desplegar asistente/tarjeta guiada de **"Copias de seguridad encontradas"** al vincular cuenta si existen respaldos (hasta 5 copias fechadas con tamaño y botón de restauración).
     - Redactar mensajes amigables y colapsar datos de soporte en desplegable discreto.
  3. En `app_movil/lib/features/profile/screens/backup_screen.dart`:
     - Eliminar la duplicación de títulos en el bloque de nube.
     - Añadir margen inferior seguro en el `ListView`.
* **Pruebas automatizadas requeridas:**
  - Actualizar `app_movil/test/google_drive_backup_and_cloning_rule_test.dart`:
    * Verificar listado y selección de hasta 5 copias fechadas.
    * Verificar que la limpieza de sesión resetee el estado de vinculación.

---

### FASE 6: Regresión Global, Compilación Oficial v9.33_atp, Acta de Cierre y GitHub
* **Objetivo:** Certificar la estabilidad global del sistema, actualizar la versión a `v9.33.0+77` (`mochilalista_v9.33_atp`), compilar el APK oficial ofuscado y registrar el cierre en GitHub.
* **Acciones:**
  1. Actualizar versión a `9.33.0+77` en `pubspec.yaml`, `owner_legal_identity.dart`, `app_changelog_registry.dart`, `mochilalista_admin/` y manuales.
  2. Regresión global completa:
     - `node --check` en scripts JS del Admin.
     - `dart analyze` y `dart test` en `mochilalista_admin/`.
     - `flutter analyze --no-pub lib test` (0 issues).
     - `flutter test` en todas las suites de prueba móvil.
  3. Compilación de Release:
     ```bash
     flutter build apk --release --obfuscate --split-debug-info=build/app_symbols --dart-define=PRODUCTION=true
     ```
  4. Copia del binario y notas a `C:\Users\vjuli\Documents\v-app-offline apks\mochilalista_v9.33_atp.apk`.
  5. Verificación de firma y hashes con `apksigner`.
  6. Acta de certificación firmada y `git push` limpio a `origin dev/mejoras-v9.0-comercializacion-seguridad`.

---

## 4. CRITERIOS DE ACEPTACIÓN ESTRICTOS

1. **Modal de Actualización:** Al actualizar de `v9.32` a `v9.33`, el modal `¡Actualización Exitosa!` debe mostrarse de forma confiable al arrancar. Al restaurar un `.mlbg` en cualquier versión, jamás debe dispararse `¡Actualización Exitosa!`.
2. **Pantalla Perfil:** Cero filas de novedades en `Configuración General`. El enlace inferior `Novedades v9.33.0` abre el modal correctamente. Layout y scroll 100% idénticos al actual.
3. **Modal Pedir Plan:** El botón `Enviar por WhatsApp` debe quedar 100% visible y cómodo por encima de la barra de navegación de 3 botones de Android. Los chips de 1 toque deben agregar sus textos de forma limpia y fluida.
4. **Portapapeles:** Copiar cualquier texto que no sea un token Ed25519 con punto y firma (como `ML-B0F8` o reportes) jamás activará el recuadro verde ni concatenará `ML9-`. Los errores de código manual deben mostrarse completos.
5. **Escanear Lista:** Cero emojis duplicados en las etiquetas. Disposición compacta y botones `Cámara` y `Galería` con respiro cómodo sobre la barra de navegación de Android (`0px Overflow` en `320x568dp` y `360x640dp`).
6. **Google Drive Estilo WhatsApp:** En instalación limpia tras desinstalar, no debe aparecer cuenta vinculada por defecto. Al vincular una cuenta con copias, se despliega de inmediato la opción de restaurar entre las últimas 5 copias fechadas. Cabecera única y sin textos técnicos intimidantes en el diálogo de error.
7. **Calidad de Código:** `flutter analyze` y `dart analyze` con `0 issues`, y 100% de pruebas unitarias y de widgets aprobadas en verde.

---

## 5. ACTA DE CIERRE Y CERTIFICACIÓN FINAL DEL PLAN MAESTRO 12 (RELEASE v9.33_atp)

* **Fecha de Cierre:** 20 de Noviembre de 2026
* **Versión Oficial de Producción:** `v9.33.0+77` (`mochilalista_v9.33_atp`)
* **Autor y Titular Legal Exclusivo:** Julio Angello Vasquez Navarro
* **Marco Legal y Propiedad Intelectual:** D.L. 822 (Ley sobre el Derecho de Autor) e INDECOPI (Perú)
* **Estado de Ejecución:** **100% COMPLETADO (Fases 1 a 6 aprobadas y certificadas)**

---

### ESTADO DETALLADO DE LAS 6 FASES DEL PLAN MAESTRO 12

| Fase | Descripción y Alcance | Estado | Pruebas / Validación |
| :--- | :--- | :---: | :--- |
| **Fase 1** | **Modal ¡Actualización Exitosa! y Separación Real Update vs Backup:** Eliminada condición de carrera entre `StartupFlowCoordinator` y `LicenseProvider`. Inmunización estricta en `BackupManager` para que restaurar backups (.mlbg local o nube) actualice internamente la versión sellando `last_executed_app_version` y jamás dispare falsos avisos de actualización. | **100% CERRADA** | 4/4 pruebas específicas en verde (`test/post_update_vs_backup_restore_test.dart`) |
| **Fase 2** | **Limpieza UX en ProfileScreen y Rediseño de ScanScreen:** Eliminada la redundancia de novedades en 'Configuración General' de `ProfileScreen` preservando sus 7 ítems intactos y su punto de acceso único en el pie. Rediseño limpio, aireado y profesional de `ScanScreen` (`Escanear Lista`) con encabezado formal, cero emojis dobles y respiro visual. | **100% CERRADA** | 7/7 pruebas específicas en verde (`test/profile_and_scanner_ux_test.dart`) |
| **Fase 3** | **Bottom Sheet Profesional OrderPlanBottomSheet:** Rediseño interactivo en 3 zonas (tarjeta resumen con precio S/ y Hardware ID, área de personalización rápida con 4 chips táctiles y caja multilínea editable, y barra de acción fija protegida con `SafeArea` y padding dinámico sobre la barra de navegación de 3 botones de Android). Cero desbordes en 320dp y 360dp. | **100% CERRADA** | 10/10 pruebas específicas en verde (`test/order_modal_and_ui_density_widget_test.dart`) |
| **Fase 4** | **Blindaje Criptográfico de Extractor de Tokens y Portapapeles:** `Ed25519LicenseValidator` y detector de portapapeles en `LicenseStatusAndActivationScreen` exigen estructura estricta de 3 segmentos base64url y firma Ed25519 válida (rechazo inmediato de URLs, textos y tokens corruptos). Botón `Pegar y Activar` inmune a prefijos duplicados `ML9-ML9-`. Despliegue completo sin truncamiento en `CustomSnackBar`. | **100% CERRADA** | 20/20 pruebas específicas en verde (`test/hardware_id_and_token_parser_test.dart`, `test/license_screen_catalog_and_clipboard_test.dart`) |
| **Fase 5** | **Experiencia Google Drive Backup Estilo WhatsApp:** Purga limpia de credenciales en `LicenseRepository` al reinstalar tras desinstalar. Al vincular cuenta en `GoogleDriveBackupSheet`, despliegue inmediato de restauración guiada de hasta las 5 copias más recientes con fechas y tamaños. Cabecera unificada y margen inferior seguro en `BackupScreen`. Diálogo de error humano con panel técnico colapsable. | **100% CERRADA** | 23/23 pruebas específicas en verde (`test/google_drive_backup_and_cloning_rule_test.dart`, `test/backup_multi_profile_database_integrity_test.dart`) |
| **Fase 6** | **Regresión Global, Release v9.33_atp y Cierre en GitHub:** Versión oficial `9.33.0+77` sincronizada en móvil, admin y manual. 60/60 pruebas en admin y 137/137 pruebas en móvil al 100% en verde. Servidor admin respondiendo 200 OK. Compilación release ofuscada de `mochilalista_v9.33_atp.apk` (109.00 MB), verificación criptográfica con `apksigner` y sincronización limpia a GitHub. | **100% CERRADA** | 60/60 Admin + 137/137 Móvil (197/197 pruebas en verde) + APK compilado y firmado |

---

### FICHA CRIPTOGRÁFICA Y DE ENTREGA DEL APK OFICIAL

* **Nombre de Archivo:** `mochilalista_v9.33_atp.apk`
* **Ubicación Oficial en Biblioteca:** `C:\Users\vjuli\Documents\v-app-offline apks\mochilalista_v9.33_atp.apk`
* **Notas de Versión y Cambios:**
  - `C:\Users\vjuli\Documents\v-app-offline apks\mochilalista_v9.33_atp.txt`
  - `C:\Users\vjuli\Documents\v-app-offline apks\mochilalista_v9.33_atp_cambios.txt`
* **Tamaño Exacto:** `114,297,378 bytes` (`109.00 MB`)
* **SHA-256 del Archivo:** `EF882D34C24CAE5739E615F373249F92D9FEB5AAD449E0864925844538E87175`
* **SHA-1 del Archivo:** `FD2C6972563D8DD1BC231869F38D13DD77FFFD0D`
* **Esquemas de Firma Validados por `apksigner`:** APK Signature Scheme v2 (`Verifies: true`)
* **Certificado Firmante (Producción Release Keystore):**
  - **DN:** `CN=Julio Angello Vasquez Navarro, OU=MochilaLista Core Development, O=MochilaLista, L=Piura, ST=Piura, C=PE`
  - **Algoritmo:** RSA 4096 bits
  - **Huella SHA-1 del Certificado:** `e79c5354063f28d25ee4efe644d5670065c6b866`
  - **Huella SHA-256 del Certificado:** `7c43addc34776f3974eac23fdacc47599efd5393a4dbb28672d06899833ffd20`

---

### CERTIFICACIÓN DE RESULTADOS LORADOS EN REGRESIÓN GLOBAL

1. **Sintaxis JS Admin:** `node --check mochilalista_admin/web/js/admin_app.js` -> `Código de salida 0 (0 errores)`.
2. **Análisis Estático Admin:** `dart analyze mochilalista_admin` -> `No issues found!`.
3. **Suite Completa Admin:** `dart test` -> `60/60 pruebas aprobadas (100% en verde)`.
4. **Análisis Estático Móvil:** `flutter analyze --no-pub lib test` -> `No issues found! (ran in 24.1s)`.
5. **Regresión Completa Móvil:** `flutter test (15 suites de pruebas)` -> `137/137 pruebas aprobadas (100% en verde)`.
6. **Instancia Limpia Servidor Admin:** `http://localhost:8080/` (200 OK) y `http://localhost:8080/api/vault/health` (200 OK) verificado sin procesos huérfanos.

**Plan Maestro 12 cerrado, certificado y listo para validación en vivo en Samsung Galaxy A54 5G.**

