# PLAN MAESTRO 11: CORRECCIÓN DE PRUEBAS REALES EN SAMSUNG GALAXY A54 5G, SINCRONIZACIÓN REACTIVA IA, RESPALDO TOTAL MULTI-PERFIL, GOBERNANZA DE INSTALACIÓN LIMPIA Y PULIDO DEL ECOSISTEMA

**Documento Oficial de Auditoría Forense, Diagnóstico de Causa Raíz y Plan de Trabajo por Fases**  
**Versión:** 1.1 (Revisada y Blindada tras Auditoría Cruzada)  
**Fecha de Auditoría:** 19 de Noviembre de 2026  
**Dispositivo Físico de Pruebas Reales:** Samsung Galaxy A54 5G (`SM-A546E`), Android 14 / One UI 6.1  
**Build Auditado en Celular:** `mochilalista_v9.31_atp.apk` (`v9.31.0+75`)  
**Ecosistema:** Aplicación Móvil Flutter (`app_movil/`) y Plataforma de Gestión Propietaria (`mochilalista_admin/`)  
**Autor y Titular de Propiedad Intelectual:** Julio Angello Vasquez Navarro  
**Marco Legal y Regulatorio:** D.L. 822 (Ley sobre el Derecho de Autor) • INDECOPI Perú • Ley N° 29733 (Protección de Datos Personales)  

---

## ÍNDICE GENERAL DEL PLAN MAESTRO

1. **RESUMEN EJECUTIVO Y CERTIFICACIÓN DE PRUEBAS REALES**
2. **DIAGNÓSTICO FORENSE Y CAUSA RAÍZ DE LOS 6 PILARES**
   - 2.1. Causa Raíz: Desincronización del Contador IA (`49` vs `50`) y Textos Truncados en `AiSettingsScreen`
   - 2.2. Causa Raíz: Omisión del EULA tras Desinstalar, Acceso a Novedades y Re-canje de Token con `iat`
   - 2.3. Causa Raíz: Google Drive `ApiException: 10`, Alerta No Invasiva y Certificación Multi-Perfil de `.mlbg`
   - 2.4. Causa Raíz: Modal Previo Editable del Botón `Pedir` y Desalineación Visual en Activación
   - 2.5. Causa Raíz: Lanzador de Escritorio, Rotación de Backups en Admin y Erratas en el Manual
   - 2.6. Matriz de Pruebas Automatizadas y Protocolo de Certificación
3. **PLAN DE IMPLEMENTACIÓN DETALLADO POR FASES SECUENCIALES**
   - **FASE 1:** Sincronización Reactiva 1:1 de Cuota IA (Fuente Única de Verdad en `INCLUDED` y `BYOK`) y Rediseño Anti-Overflow de `AiSettingsScreen`
   - **FASE 2:** Gobernanza de Instalación Limpia, EULA Obligatorio, Modal de Novedades y Blindaje Criptográfico Re-canje con `iat`
   - **FASE 3:** Google Drive — Diálogo OAuth No Invasivo, Certificación Multi-Perfil y Rediseño Jerárquico de `Respaldos`
   - **FASE 4:** Modal Previo Editable de Pedidos Comerciales y Pulido Visual de `Licencia y Activación` (Estándar Visual Cero Emojis)
   - **FASE 5:** Lanzador de Escritorio en 1 Clic Robusto, Rotación de Snapshots en Admin y Limpieza Documental
   - **FASE 6:** Batería Exhaustiva de Tests Automatizados, Regresión Completa y Compilación del APK Comercial Ofuscado
4. **GUÍA ACCIONABLE PARA GOOGLE CLOUD CONSOLE (OAUTH SHA-1)**
5. **CRONOGRAMA DE EJECUCIÓN Y CRITERIOS DE ACEPTACIÓN ESTRICTOS**

---

## 1. RESUMEN EJECUTIVO Y CERTIFICACIÓN DE PRUEBAS REALES

Las pruebas de campo ejecutadas directamente sobre el hardware físico del autor (**Samsung Galaxy A54 5G**, modelo `SM-A546E`, ejecutando el APK comercial firmado `mochilalista_v9.31_atp.apk`) han arrojado resultados extraordinariamente valiosos que ninguna simulación en emulador o suite sintética es capaz de reproducir. 

El comportamiento general de la aplicación móvil es sólido:
- La activación offline con Ed25519 funciona a la perfección.
- El escaneo y extracción inteligente de facturas y listas escolares con IA procesó documentos reales correctamente.
- El hardware ID `ML-B0F8` se derivó adecuadamente a partir de `Settings.Secure.ANDROID_ID`.

Sin embargo, las pruebas reales evidenciaron **fricciones de experiencia de usuario (UX), asincronías de estado en memoria y discrepancias de arranque limpio** que deben ser resueltas de inmediato para que la aplicación responda al 100% como un producto comercial de nivel empresarial para comerciantes minoristas en Perú.

Este documento establece la auditoría técnica profunda, identifica la línea exacta de código que origina cada comportamiento no deseado y define un **Plan de Trabajo Maestro dividido en 6 Fases rigurosas**, garantizando **cero impacto en producción, cero regresiones y compatibilidad absoluta**.

---

## 2. DIAGNÓSTICO FORENSE Y CAUSA RAÍZ DE LOS 6 PILARES

### 2.1. Pilar 1: Desincronización del Contador IA (`49` vs `50`) y Textos Truncados en `AiSettingsScreen`

#### Evidencia Real en Dispositivo Físico
Al realizar un escaneo real de factura con IA en el celular, el contador se debitó en la base de datos (de 50 a 49). En la pantalla **Licencia y Activación** (`LicenseStatusAndActivationScreen`), el contador se actualizó a:
> **`49 escaneos acumulados disponibles`**

No obstante, al navegar a **Cotizador Universal IA y Cuota** (`AiSettingsScreen`), la pantalla continuaba mostrando:
> Tarjeta superior: **`50 usos disponibles`**  
> Tarjeta central: **`50 disponibles`**

#### Diagnóstico Forense y Causa Raíz en Código
La causa raíz es triple y radica en una asincronía entre `LicenseProvider`, el modelo inmutable `LicenseModel` y la pantalla `AiSettingsScreen`:

1. **`LicenseProvider.consumeAiScan()` actualizaba `_remainingAiScans` pero NO actualizaba `_license`:**
   En `app_movil/lib/core/providers/license_provider.dart` (líneas 119-126):
   ```dart
   Future<bool> consumeAiScan({DateTime? overrideNow}) async {
     final success = await _repository.consumeAiScan(overrideNow: overrideNow);
     if (success) {
       _remainingAiScans = await _repository.getRemainingAiScans(overrideNow: overrideNow);
       notifyListeners();
     }
     return success;
   }
   ```
   `_repository.consumeAiScan()` decrementó el valor en la columna SQLite `ai_accumulated_scans` a `49`. Luego `_remainingAiScans` pasó a valer `49`. Sin embargo, la variable privada `LicenseModel? _license` en `LicenseProvider` **quedó congelada con la instancia previa** cargada durante el arranque, donde `_license.aiAccumulatedScans` aún valía `50`. Idéntico desfase ocurría si se invocaba `setAiSelectedMode()`, `redeemCode()` o `refreshAiScans()` sin recargar `_license`.

2. **El getter `aiAccumulatedScans` priorizaba la propiedad desactualizada de `_license`:**
   En `app_movil/lib/core/providers/license_provider.dart` (línea 55):
   ```dart
   int get aiAccumulatedScans => _license?.aiAccumulatedScans ?? _remainingAiScans;
   ```
   Como `_license` no era nulo, el getter evaluaba la parte izquierda (`_license!.aiAccumulatedScans`) y devolvía invariablemente `50`, ignorando por completo que `_remainingAiScans` ya era `49`.

3. **Discrepancia de lectura entre ambas pantallas:**
   - En `LicenseStatusAndActivationScreen.dart` (línea 563):
     ```dart
     "$remainingAiScans escaneos acumulados disponibles"
     ```
     Leía directamente `licenseProv.remainingAiScans`, mostrando correctamente **49**.
   - En `AiSettingsScreen.dart` (líneas 403-404):
     ```dart
     final remainingScans = licenseProv?.remainingAiScans ?? 50;
     final accumulatedScans = licenseProv?.aiAccumulatedScans ?? remainingScans;
     ```
     Leía `accumulatedScans`, el cual invocaba el getter estancado de `_license?.aiAccumulatedScans` (que devolvía **50**). Además, `AiSettingsScreen` no ejecutaba un `refreshAiScans()` en su `initState()`.

4. **Comportamiento en Modo `BYOK` (Clave Propia):**
   Actualmente `getRemainingAiScans()` devuelve `999999` si el usuario está en modo `BYOK` con clave activa. Esto generaba confusión si una pantalla interpretaba `remainingAiScans` como el saldo de la bolsa acumulada. En modo `BYOK`, la bolsa acumulada de MochilaLista **debe permanecer congelada pero visualmente visible con su valor real numérico (ej. 49)**, informando con total claridad: *"Tus 49 usos acumulados están protegidos y congelados"*.

#### Textos Truncados en `AiSettingsScreen`
- **`Bolsa Acumulativa d...`:**  
  En `AiSettingsScreen.dart` (líneas 607-630), el widget `Row` contiene un `Expanded(child: Text("Bolsa Acumulativa de IA", overflow: TextOverflow.ellipsis))` compitiendo en la misma línea con el badge `Container("Bolsa Activa")`. En anchos de pantalla de `360dp` (ancho típico de Android con escala de fuente estándar), el ancho restante para el texto es menor a 150dp, forzando la elipsis.
- **`Bóveda Segura ...`:**  
  En `AiSettingsScreen.dart` (líneas 725-743), el título `Expanded(child: Text("Bóveda Segura Multi-Clave", overflow: TextOverflow.ellipsis))` comparte fila con el botón `ElevatedButton.icon(label: Text("Agregar Clave"))` que consume más de 130dp de ancho. Esto trunca el título en cualquier pantalla de 360dp o menor.

---

### 2.2. Pilar 2: Arranque Limpio tras Desinstalar, EULA Obligatorio, Acceso a Novedades y Re-canje de Token con `iat`

#### Causa Raíz de la Omisión del EULA en Instalación Limpia
Al desinstalar por completo la aplicación en Android e instalar `v9.31.0+75` de cero, Android eliminó el sandbox local (`mochilalista.db`). Sin embargo, **la app no volvió a mostrar el modal de Términos de Licencia (EULA)** debido a dos causas concretas:
1. **Lectura residual en `LicenseRepository.getOrCreateLicense()`:**  
   En `app_movil/lib/core/services/license/license_repository.dart` (líneas 71-78 y 188-210):
   ```dart
   // 🛡️ Persistencia global de EULA a nivel de dispositivo
   String? deviceEulaVersion;
   String? deviceEulaTimestamp;
   try {
     deviceEulaVersion = await _secureStorage.read(key: deviceEulaVersionKey);
     deviceEulaTimestamp = await _secureStorage.read(key: deviceEulaTimestampKey);
   } catch (_) {}
   ```
   En dispositivos Samsung con Knox / Android Keystore, las llaves de `flutter_secure_storage` no siempre se purgan con una desinstalación si no se re-inicializa el Keystore, o si existió sincronización del sistema. Al encontrar `deviceEulaVersion != null`, `licencia_app` se sembró con `eula_accepted_version = "1.0"`.
2. **Ubicación tardía de `StartupFlowCoordinator.coordinateStartup()`:**  
   La coordinación de arranque solo se llama en `HomeScreen.initState()`. Si un usuario nuevo arranca en `ProfileSelectionScreen` o `OnboardingScreen`, el EULA nunca se evaluaba antes de la creación del perfil, permitiendo crear negocios sin aceptar previamente el contrato.

#### Análisis Forense del Hardware ID (`ML-B0F8`)
En `MainActivity.kt` (líneas 24-28):
```kotlin
val androidId = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
result.success(androidId ?: "generic_android_fallback")
```
En `DeviceFingerprint.dart` (líneas 33-37 y 85):
```dart
static String deriveFingerprintFromRawId(String rawId) {
  final bytes = utf8.encode('${rawId}_mochilalista_salt_2026_julio');
  final hash = sha256.convert(bytes).toString().toUpperCase();
  return 'ML-${hash.substring(0, 4)}';
}
```
**Certificación:** El ID `ML-B0F8` en el Samsung Galaxy A54 proviene directamente de `ANDROID_ID` con la sal criptográfica oficial. En Android 8.0+, `ANDROID_ID` tiene alcance por clave de firma de la app y usuario del dispositivo; es 100% estable ante actualizaciones y reinstalaciones del mismo APK firmado por el autor.

#### Blindaje de Reinstalación y Re-canje de Código `ML9-...` con `iat`
Si un usuario que compró un plan comercial desinstala y vuelve a pegar su token en una instalación limpia:
- Actualmente, `Ed25519LicenseValidator` no utiliza el claim `'iat'` (fecha de emisión en UTC) incluido por `LicenseSigner` para calcular la vigencia.
- Al reinstalar de cero, `currentLicense` nace como un `TRIAL` con expiración en `now + 30 días`. Al canjear un código de 30 días, `Ed25519LicenseValidator` le sumaba 30 días encima de la fecha del trial (`baseDate = currentLicense.fechaExpiracion`), **otorgándole 60 días en total** o reiniciando un plan mensual desde hoy en lugar de respetar la fecha de emisión original.
- **Reglas Criptográficas Obligatorias y Excepciones:**
  1. **Excepciones Estrictas:** El tope `iat + daysToAdd` aplica **única y exclusivamente a planes de suscripción temporal** (`MENSUAL`, `TRIMESTRAL`, `SEMESTRAL`, `ANUAL`). **NUNCA** debe aplicarse ni bloquear a:
     - `PERPETUO_LIBERADO` (vigencia de por vida).
     - `RECARGA_IA_150` (bolsa de escaneos sin caducidad).
     - `PASE_ACTUALIZACION_ANUAL` (ventana de updates anual para perpetuos).
  2. **Compatibilidad y Retrocompatibilidad:** Soporte para leer `'iat'` y el alias `'e'` (si existiera en tokens legacy), con fallback seguro si un token antiguo no transportara dicho claim.
  3. **Regla Acumulativa en Renovación Comercial:** Si el usuario ya cuenta con una suscripción comercial activa pagada (no trial), la renovación anticipada **mantiene su regla acumulativa sin pérdida de días** (`newExpiration = currentLicense.fechaExpiracion.add(Duration(days: daysToAdd))`).
  4. **Regla de Reinstalación en `TRIAL`:** Si el estado actual es `TRIAL` (instalación limpia tras desinstalar) y se canjea un token de suscripción:
     - Si `now.isAfter(iat.add(Duration(days: daysToAdd)))`: El token se rechaza por expirado (evita revivir tokens antiguos).
     - Si el token fue emitido hace más de 24 horas (`now.difference(iat) > 24h`, escenario de recuperación tras reinstalar): La fecha de expiración se fija **estrictamente en `iat.add(Duration(days: daysToAdd))`**, recuperando el remanente legítimo sin regalar días extra ni sumar los 30 días del nuevo trial.
     - Si el token es una compra recién emitida (`now.difference(iat) <= 24h`): La nueva expiración se fija en `now.add(Duration(days: daysToAdd))` (o `iat + daysToAdd`), reemplazando al trial (no sumándose encima), manteniendo en verde la paridad con `cross_platform_admin_to_mobile_ed25519_verification_test.dart`.

#### Evaluación Honesta del Trial Único en Arquitectura 100% Offline
Técnicamente, en una arquitectura 100% Offline sin servidor central, el sistema operativo Android garantiza que al desinstalar una app se purga su almacenamiento privado (`/data/data/com.mochilalista.app/`). Ninguna app offline en el mundo puede garantizar matemáticamente que un teléfono nunca existió si se borra el disco local y no hay conexión a internet.  
**Mitigaciones Reales Planificadas:**
1. Mantener `ANDROID_ID` como ancla de hardware estable.
2. Si el comerciante conecta su Google Drive, almacenar un marcador criptográfico en `drive.appdata` (`ml_trial_marker_<hash(ANDROID_ID)>.dat`). Al instalar de nuevo y vincular la misma cuenta de Google, la app detecta que el trial ya fue gozado en ese equipo.
3. Si el usuario restaura un backup `.mlbg`, la base de datos recupera su historial de transacciones y licencias original.

---

### 2.3. Pilar 3: Google Drive Backup — `ApiException: 10`, Alerta No Invasiva y Certificación Multi-Perfil

#### Diagnóstico Técnico de `ApiException: 10`
En los Servicios de Google Play (`GoogleSignIn` en Android), el error `ApiException: 10` corresponde estrictamente a:
> **`CommonStatusCodes.DEVELOPER_ERROR` (Código 10)**  
> **Causa exacta:** La huella digital criptográfica SHA-1 del certificado con el que fue firmado el APK instalado en el celular **NO está dada de alta** en la consola de Google Cloud (`Google Cloud Console > Credentials > OAuth 2.0 Client IDs for Android`) bajo el nombre de paquete `com.mochilalista.app`.

#### Toast Rojo Cortado que Tapa la Cabecera
En `google_drive_backup_sheet.dart` (líneas 192-202):
```dart
} catch (e) {
  if (mounted) {
    setState(() => _isLoading = false);
    final cleanMsg = e.toString().replaceFirst('Exception: ', '');
    CustomSnackBar.show(context, message: cleanMsg, isError: true);
  }
}
```
`CustomSnackBar.show` dispara un banner flotante en la parte superior que tapa completamente el título `Respaldos y Seguridad` y trunca el texto con puntos suspensivos (`Google Cloud Console ...`).  
**Solución:** Reemplazar este snackbar invasivo por un Diálogo modal limpio que nunca tape la pantalla, proporcionando:
- Título amigable: *"Configuración de Acceso a Google Drive"*
- Explicación clara para el comerciante.
- Detalle técnico completo.
- Botón con icono Material `Icons.copy_rounded`: *"Copiar Datos de Soporte Técnico"* (que copie al portapapeles: Nombre de paquete `com.mochilalista.app`, versión de la app, Hardware ID, detalle del error y huella SHA-1 si está disponible).
- Botón *"Entendido"*.

#### Certificación Forense del Respaldo Multi-Perfil Integral
Se auditó forensemente `BackupManager._getDatabaseFile()` y `_createGlobalBackupZip()` en `backup_manager.dart` (líneas 77-107):
```dart
final dbBytes = await dbFile.readAsBytes();
archive.addFile(ArchiveFile('mochilalista.db', dbBytes.length, dbBytes));
```
**Certificación Oficial:** El archivo `.mlbg` empaqueta el archivo físico completo `mochilalista.db` de SQLite en disco. Dicho archivo contiene **el 100% de las tablas multi-perfil de la aplicación**:
- `usuarios` (todos los usuarios y administradores)
- `negocios` (todos los perfiles comerciales)
- `productos`, `categorias`, `stock_ledger`
- `clientes`, `ventas`, `ventas_items`, `pagos_venta`
- `smart_quotations`, `smart_quotation_items`
- `licencia_app`, `licencia_logs`
- Bóveda de claves BYOK y configuraciones locales.  
**Ningún dato queda excluido.** Respaldar en `.mlbg` o en Google Drive respalda **el ecosistema completo de la base de datos**.

#### Rediseño UX y Separación de Bloques en `BackupScreen`
Actualmente la pantalla mezcla en un solo scroll confuso el backup local y la nube. Se reorganizará en dos grandes bloques jerárquicos independientes:
- **Bloque A: Copia de Seguridad en la Nube (Google Drive Cifrado):**
  - Título y subtítulo desplegados en múltiples líneas sin truncamiento: *"Copia de Seguridad en Google Drive (Opcional)"* y *"Respaldo automático con cifrado AES-256-GCM atado a tu cuenta de Google"*.
  - **Antes de Vincular:** Vista previa informativa completa detallando lo que incluye una vez vinculado (respaldo manual o automático, selección de frecuencia Diario/Semanal/Mensual, switch Solo Wi-Fi, historial de las últimas 5 copias fechadas con restauración en 1 clic y cobertura total: *"Base de datos completa: todos tus perfiles y negocios"*).
  - **Una vez Vinculado:** Controles interactivos completos:
    - Selector de modo: **Automático vs Manual**.
    - Selector de frecuencia: **Diario / Semanal / Mensual**.
    - Switch: **Respaldar solo con conexión Wi-Fi**.
    - Botón principal: **Respaldar Ahora en Google Drive**.
    - Historial visual de las **últimas 5 copias fechadas** con fecha, hora, tamaño formateado y botón para restaurar.
- **Bloque B: Copia Local en el Teléfono (`.mlbg`):**
  - Claramente diferenciada para copias manuales en almacenamiento interno o envío por WhatsApp.
  - **Reubicación de Protección Automática:** La tarjeta heredada **`Protección Automática -> Activar Backups Automáticos`** (gobernada por Workmanager) se moverá y renombrará explícitamente dentro de este Bloque B como **"Respaldo Local Automático en Memoria del Teléfono"**, eliminando cualquier confusión con Google Drive.

---

### 2.4. Pilar 4: Modal Editable de Pedido y Pulido Visual de `Licencia y Activación`

#### Modal Previo Editable al Pulsar `Pedir`
En `license_status_and_activation_screen.dart` (líneas 1263-1271):
Al pulsar `Pedir`, el código invoca inmediatamente `_launchRawWhatsAppUrl(uri)`, abriendo WhatsApp directamente sin permitir al comerciante revisar o personalizar el mensaje.  
**Solución Requerida:**  
Desplegar un Bottom Sheet interactivo que muestre:
- Tarjeta de resumen: Plan elegido, precio en Soles (`S/`), vigencia, escaneos IA acumulativos incluidos y Hardware ID.
- Campo de texto multilínea editable con `TextEditingController` precargada con el mensaje oficial generado por `OwnerLegalIdentity.buildPlanOrderMessage()`.
- Botones de acción con **iconos vectoriales Material (estrictamente cero emojis crudos)**:
  - Botón con `Icons.copy_rounded`: **`Copiar Mensaje`** (con toast flotante).
  - Botón con `Icons.refresh_rounded`: **`Restablecer Texto`**.
  - Botón principal con `Icons.chat_rounded`: **`Enviar por WhatsApp`**.

#### Pulido Visual en `Licencia y Activación`
1. **Desalineación de Botones QR:**  
   En líneas 764-810, `Escanear QR` ocupa 1 línea de texto mientras que `QR desde Galería` se divide en 2 líneas (`QR desde\nGalería`), provocando que una caja sea más alta que la otra. Se resolverá envolviendo la fila en `IntrinsicHeight` y definiendo un alto uniforme de `48dp`.
2. **Badge de Escaneos IA en Tarifario Comercial:**  
   Cada tarjeta del catálogo de planes incluirá un badge visual con los escaneos acumulativos incluidos (`+50 IA`, `+180 IA`, `+450 IA`, `+1,200 IA`, `+200 IA`, `+100 IA`, `+150 IA`), y el enlace de texto `"Pedir"` se transformará en un botón estilo chip táctil con fondo y bordes definidos.
3. **Tarjeta Anual y Densidad Anti-Overflow:**  
   Revisión de la tarjeta del plan `Anual` para que en pantallas de `320dp` y `360dp` no sufra ningún desbordamiento (`0px Overflow`), garantizando que precios, badges y textos respiren con holgura.

---

### 2.5. Pilar 5: Mejoras Operativas en `mochilalista_admin/` y Documentación

1. **Lanzador de Escritorio en 1 Clic Robusto (`Iniciar_MochilaLista_Admin.bat`):**  
   Script `.bat` en la raíz del repositorio que:
   - Utiliza la ruta absoluta del script: **`cd /d "%~dp0mochilalista_admin"`**, permitiendo anclarlo directamente como acceso directo en el Escritorio de Windows sin errores de directorio de trabajo.
   - Verifica el puerto con filtrado estricto: **`netstat -ano | findstr ":8080 " | findstr "LISTENING"`** (evitando falsos positivos causados por conexiones `TIME_WAIT` o puertos con prefijos similares como 18080).
   - Si no está activo, inicia `start "MochilaLista Admin Server" /min dart run server.dart`.
   - Espera 2 segundos e invoca `start http://localhost:8080` en el navegador predeterminado.
2. **Rotación Automática de `mochilalista_admin/backups/`:**  
   Actualmente, tanto `DatabaseService._createSnapshot()` como `ConfigService._createBackupSnapshot()` crean snapshots JSON en cada operación sin depuración, acumulando decenas de archivos. Se incorporará una política de retención automática que conserve los últimos 30 snapshots automáticos, preservando de forma indefinida los respaldos manuales (`manual` o `vault`).
3. **Limpieza en Documentación (`05_MANUAL_OPERATIVO_...md`):**  
   - En la Sección 1.11, corregir los nombres exactos de las 5 hojas generadas por `excel_export_service.dart`: `Resumen Ejecutivo`, `Cartera CRM`, `Libro de Pagos`, `Equipos y Licencias`, y `Guia y Glosario`.
   - En el índice (línea 50), reemplazar *"Cuota Mensual"* por *"Bolsa de Escaneos con IA"*.

---

### 2.6. Pilar 6: Matriz de Pruebas Automatizadas y Protocolo de Certificación

Se planifican suites completas en Flutter y Dart para validar de extremo a extremo:
- Reactividad del contador de escaneos IA (`50 -> 49`) en `AiSettingsScreen` y `LicenseStatusAndActivationScreen` tanto en `INCLUDED` como en `BYOK`.
- Verificación del EULA obligatorio en base de datos limpia y retención sin re-petición al crear múltiples perfiles.
- Re-canje de licencia respetando `iat + daysToAdd` en suscripciones temporales y paridad con `cross_platform_admin_to_mobile_ed25519_verification_test.dart`.
- Integridad física del respaldo multi-perfil en `.mlbg`.
- Renderizado visual a `320dp` y `360dp` con 0 desbordamientos (`0px Overflow`), 0 títulos cortados y cero emojis crudos en botones.
- Rotación automática de snapshots en `mochilalista_admin`.
- Compilación comercial limpia y ofuscada con `--split-debug-info`.

---

## 3. PLAN DE IMPLEMENTACIÓN DETALLADO POR FASES SECUENCIALES

```mermaid
flowchart TD
    Fase1["FASE 1: Sincronización Reactiva IA (Fuente Única) y Rediseño Anti-Overflow AiSettingsScreen"]
    Fase2["FASE 2: Gobernanza EULA Limpio, Novedades y Blindaje Criptográfico Re-canje con iat"]
    Fase3["FASE 3: Google Drive UX, Alerta No Invasiva, Separación de Bloques y Certificación .mlbg"]
    Fase4["FASE 4: Modal Editable de Pedidos Comerciales y Pulido Visual Activación (Cero Emojis)"]
    Fase5["FASE 5: Lanzador Admin Robusto en 1 Clic, Rotación Backups y Ajustes Manual"]
    Fase6["FASE 6: Tests Automatizados E2E, Regresión Completa y Compilación del APK Verificado"]

    Fase1 --> Fase2
    Fase2 --> Fase3
    Fase3 --> Fase4
    Fase4 --> Fase5
    Fase5 --> Fase6
```

---

### FASE 1: Sincronización Reactiva 1:1 de Cuota IA (Fuente Única de Verdad en `INCLUDED` y `BYOK`) y Rediseño Anti-Overflow de `AiSettingsScreen`

* **Objetivo:** Establecer a `LicenseProvider` como la única fuente de verdad reactiva para el saldo acumulado de IA, garantizando coherencia matemática instantánea en todas las pantallas (`INCLUDED` y `BYOK`) y eliminando todos los títulos truncados en dispositivos compactos (`320dp` - `360dp`).
* **Archivos a intervenir en ejecución posterior:**
  - `app_movil/lib/core/providers/license_provider.dart`
  - `app_movil/lib/features/profile/screens/ai_settings_screen.dart`
  - `app_movil/lib/core/services/license/license_repository.dart`
* **Tareas Técnicas Detalladas:**
  1. **Fuente Única de Verdad en `LicenseProvider`:**
     - Modificar `consumeAiScan()`, `redeemCode()`, `setAiSelectedMode()` y `refreshAiScans()` para que **siempre recarguen en tándem tanto `_license = await _repository.getOrCreateLicense()` como `_remainingAiScans = await _repository.getRemainingAiScans()`**.
     - Asegurar que el getter `aiAccumulatedScans` retorne consistentemente `_license?.aiAccumulatedScans ?? _remainingAiScans` tanto en modo `INCLUDED` como en modo `BYOK`.
     - En modo `BYOK`, garantizar que la tarjeta de bolsa acumulativa muestre siempre el saldo acumulado real numérico (ej. `49 disponibles`) con el badge `"Bolsa Congelada (BYOK)"`, sin reemplazar dicho valor por `999999` (el cual solo aplica al balance de escaneo operativo ilimitado con clave propia).
  2. **Reactividad en `AiSettingsScreen`:**
     - Invocar `context.read<LicenseProvider?>()?.refreshAiScans()` en `initState()`.
     - Consumir el valor reactivo de `licenseProv.aiAccumulatedScans` en la tarjeta superior ("49 usos disponibles") y en la tarjeta central ("49 disponibles"), erradicando la asincronía con `LicenseStatusAndActivationScreen`.
  3. **Rediseño Anti-Truncado de Tarjetas (`320dp` / `360dp`):**
     - **Tarjeta de Bolsa de IA:** Reestructurar la cabecera en un diseño vertical o flexible (`Column` con `CrossAxisAlignment.start` o `Wrap`), permitiendo que el título `"Bolsa Acumulativa de IA"` se muestre completo en hasta 2 líneas sin `TextOverflow.ellipsis` y el badge `"Bolsa Activa"` / `"Bolsa Congelada"` se sitúe alineado elegantemente sin aplastar el texto.
     - **Tarjeta de Bóveda Segura:** Reorganizar la cabecera para que en pantallas de `360dp` el botón `+ Agregar Clave` se sitúe debajo del título o en un layout que otorgue el 100% del ancho al título `"Bóveda Segura Multi-Clave"`, garantizando **cero puntos suspensivos** y **`0px Overflow`**.
     - Aplicar rigurosamente `.withValues(alpha: ...)` en toda la pantalla, erradicando cualquier uso de `.withOpacity()`.

---

### FASE 2: Gobernanza de Instalación Limpia, EULA Obligatorio, Modal de Novedades y Blindaje Criptográfico Re-canje con `iat`

* **Objetivo:** Exigir legalmente la aceptación de los Términos de Licencia (EULA) en toda instalación limpia (sin herencia residual de Keystore), proveer acceso manual en cualquier momento a las novedades de la versión y blindar el re-canje de tokens con reglas temporales estrictas basadas en `iat`.
* **Archivos a intervenir en ejecución posterior:**
  - `app_movil/lib/core/services/license/license_repository.dart`
  - `app_movil/lib/core/services/startup_flow_coordinator.dart`
  - `app_movil/lib/core/services/license/ed25519_license_validator.dart`
  - `app_movil/lib/features/profile/screens/profile_screen.dart`
  - `app_movil/lib/features/auth/screens/license/license_status_and_activation_screen.dart`
  - `app_movil/lib/features/auth/screens/onboarding/profile_selection_screen.dart`
* **Tareas Técnicas Detalladas:**
  1. **EULA en Base de Datos Limpia sin Herencia Residual:**
     - En `LicenseRepository.getOrCreateLicense()`, cuando la tabla `licencia_app` se crea de cero, `eula_accepted_version` debe inicializarse estrictamente en `null`.
     - Limpiar proactivamente cualquier clave residual en `_secureStorage` (`ml_device_eula_accepted_version`) cuando se detecta una instalación limpia, impidiendo que llaves supervivientes en Android Keystore omitan la aceptación del contrato.
     - Garantizar que `ProfileSelectionScreen` y `OnboardingScreen` no permitan acceder ni crear negocios si el EULA no ha sido aceptado, **sin volver a solicitarlo jamás una vez aceptado** al crear o conmutar entre múltiples perfiles (manteniendo en verde `test/eula_widget_and_legal_persistence_test.dart`).
  2. **Acceso Manual a "Novedades de esta Versión" (`v9.31.0`):**
     - Añadir en `ProfileScreen` (menú de ajustes del perfil) un elemento de lista con icono Material `Icons.rocket_launch_rounded`:  
       **"Novedades de esta Versión (v9.31.0)"** que abre `PostUpdateWelcomeModal.show(context, appVersion: AppChangelogRegistry.currentVersion)`.
     - Añadir un acceso discreto en `LicenseStatusAndActivationScreen` (ícono en AppBar o enlace al pie del catálogo comercial).
  3. **Blindaje de Re-canje con Claim `'iat'` y Excepciones Obligatorias:**
     - En `Ed25519LicenseValidator.validateAndParse()`, extraer el claim `'iat'` (y alias `'e'`) del payload firmado, con fallback seguro a tokens legacy sin `iat`.
     - **Excepciones Obligatorias:** El tope de vencimiento `iat + daysToAdd` aplica **exclusivamente a planes de suscripción temporal** (`MENSUAL`, `TRIMESTRAL`, `SEMESTRAL`, `ANUAL`). **NUNCA** debe aplicarse ni bloquear a:
       - `PERPETUO_LIBERADO` (vigencia de por vida).
       - `RECARGA_IA_150` (bolsa de escaneos sin caducidad).
       - `PASE_ACTUALIZACION_ANUAL` (ventana de updates de 12 meses para licencias perpetuas).
     - **Regla Acumulativa en Renovación Comercial:** Si el usuario ya cuenta con una suscripción comercial activa pagada (no trial), la renovación anticipada mantiene su regla acumulativa sin pérdida de días (`newExpiration = currentLicense.fechaExpiracion.add(Duration(days: daysToAdd))`).
     - **Regla de Reinstalación en `TRIAL`:** Si el estado actual es `TRIAL` (instalación limpia tras desinstalar) y se canjea un token de suscripción:
       - Si `now.isAfter(iat.add(Duration(days: daysToAdd)))`: El token se rechaza por expirado.
       - Si el token fue emitido hace más de 24 horas (`now.difference(iat) > 24h`, recuperación tras desinstalar): La expiración se fija estrictamente en `iat.add(Duration(days: daysToAdd))`, recuperando el remanente legítimo sin regalar días extra ni sumar los 30 días del nuevo trial.
       - Si el token es una compra recién emitida (`now.difference(iat) <= 24h`): La nueva expiración se fija en `now.add(Duration(days: daysToAdd))` (o `iat + daysToAdd`), reemplazando al trial (no sumándose a los 30 días del trial), manteniendo en verde `test/cross_platform_admin_to_mobile_ed25519_verification_test.dart`.
  4. **Marcador de Trial en Google Drive (`drive.appdata`):**
     - Preparar en `GoogleDriveBackupService` la escritura y verificación de un archivo ligero cifrado `ml_trial_claim_<hash>.dat` que certifique si ese `ANDROID_ID` ya gozó de una prueba gratuita, mitigando el reseteo de pruebas en usuarios que vinculan la nube.

---

### FASE 3: Google Drive — Diálogo OAuth No Invasivo, Certificación Multi-Perfil y Rediseño Jerárquico de `Respaldos`

* **Objetivo:** Eliminar el toast rojo invasivo ante errores de autenticación OAuth, guiar la configuración de Google Cloud Console, certificar el respaldo multi-perfil y rediseñar la pantalla de respaldos en dos secciones limpias sin solapamiento con la protección local automática.
* **Archivos a intervenir en ejecución posterior:**
  - `app_movil/lib/features/profile/widgets/google_drive_backup_sheet.dart`
  - `app_movil/lib/features/profile/screens/backup_screen.dart`
  - `app_movil/lib/core/utils/backup_manager.dart`
  - `app_movil/android/app/src/main/kotlin/com/mochilalista/app/MainActivity.kt`
* **Tareas Técnicas Detalladas:**
  1. **Manejo Amigable y No Invasivo de `ApiException: 10`:**
     - En `_handleSignIn()` de `google_drive_backup_sheet.dart`, capturar la excepción y desplegar un Diálogo modal limpio (`showDialog`) con:
       - Título: *"Configuración de Acceso a Google Drive"*
       - Explicación amigable para el comerciante: *"Google requiere autorizar la firma digital de este teléfono para permitir la conexión segura con tu Google Drive."*
       - Botón con icono Material `Icons.copy_rounded`: **`[Copiar Datos de Soporte Técnico]`** (que copia al portapapeles el paquete `com.mochilalista.app`, versión, Hardware ID y detalle técnico del error).
       - Botón con `Icons.check_rounded`: **`[Entendido]`**.
     - En `MainActivity.kt`, añadir soporte en el `MethodChannel` para consultar la huella SHA-1 activa del APK si se requiere lectura nativa.
  2. **Certificación y Versión Dinámica de `.mlbg`:**
     - En `BackupManager._createGlobalBackupZip()`, reemplazar la versión fija `'9.30.0+74'` por `OwnerLegalIdentity.currentAppVersionWithBuild`.
     - Certificar que la exportación incluya físicamente `mochilalista.db` y todas las imágenes locales `img_*`, respaldando el 100% multi-perfil.
  3. **Rediseño Jerárquico de `BackupScreen` (Dos Bloques Claros):**
     - **Bloque A: Copia de Seguridad en la Nube (Google Drive Cifrado):**
       - Título y subtítulo en múltiples líneas sin truncamiento: *"Copia de Seguridad en Google Drive (Opcional)"* y *"Respaldo automático con cifrado AES-256-GCM atado a tu cuenta de Google"*.
       - **Vista Previa Antes de Vincular:** Detalle informativo claro que explica lo que se desbloquea al conectar (modo manual/automático, frecuencias Diario/Semanal/Mensual, switch Solo Wi-Fi, historial de las 5 copias más recientes y nota de alcance: *"Base de datos completa: todos tus perfiles y negocios"*).
       - **Controles Una Vez Vinculado:** Selector Manual/Automático, Frecuencia, switch Solo Wi-Fi, botón Respaldar Ahora y lista de las últimas 5 copias fechadas con acción de restaurar.
     - **Bloque B: Copia Local en el Teléfono (`.mlbg`):**
       - Guardado en Descargas, carpeta personalizada y envío por WhatsApp.
       - **Reubicación de Protección Automática:** Mover la tarjeta heredada de backups locales automáticos en segundo plano (Workmanager) dentro de este Bloque B, renombrándola explícitamente como **"Respaldo Local Automático en Memoria del Teléfono"** para erradicar cualquier confusión con Google Drive.

---

### FASE 4: Modal Previo Editable de Pedidos Comerciales y Pulido Visual de `Licencia y Activación` (Estándar Visual Cero Emojis)

* **Objetivo:** Proporcionar al comerciante un Bottom Sheet asistido para revisar y personalizar su mensaje de WhatsApp antes de enviarlo, igualar la geometría de botones QR, incorporar badges de IA en planes y aplicar el estándar estricto de cero emojis crudos en botones.
* **Archivos a intervenir en ejecución posterior:**
  - `app_movil/lib/features/auth/screens/license/license_status_and_activation_screen.dart`
* **Tareas Técnicas Detalladas:**
  1. **Modal / Bottom Sheet de Pedido Comercial Editable:**
     - Al tocar `Pedir` en cualquier plan, abrir un Bottom Sheet elegante que presente:
       - Resumen visual: Nombre del plan, precio en `S/`, vigencia en días, escaneos IA acumulativos incluidos y Hardware ID del equipo.
       - Campo de texto multilínea editable precargado con el mensaje oficial de pedido.
       - Botones de acción con **iconos vectoriales Material (cero emojis crudos)**:
         - Botón con `Icons.copy_rounded`: **`Copiar Mensaje`** (con toast flotante).
         - Botón con `Icons.refresh_rounded`: **`Restablecer Texto`**.
         - Botón principal con `Icons.chat_rounded`: **`Enviar por WhatsApp`** (lanza WhatsApp con el mensaje final editado).
  2. **Alineación Geométrica de Botones QR:**
     - Envolver la fila de botones `Escanear QR` y `QR desde Galería` en `IntrinsicHeight` o fijar `minHeight: 48dp`, garantizando idéntica altura visual independientemente de si el texto ocupa 1 o 2 líneas.
  3. **Badges de Escaneos IA y Estilo de Botón `Pedir`:**
     - Incorporar en cada ítem del tarifario un badge visual estilizado indicando los escaneos acumulativos incluidos (`+50 IA`, `+180 IA`, `+450 IA`, `+1,200 IA`, `+200 IA`, `+100 IA`, `+150 IA`).
     - Reemplazar el simple texto verde `"Pedir"` por un botón interactivo estilo chip con padding táctil óptimo y bordes redondeados.
  4. **Densidad y Anti-Overflow (`320dp` / `360dp`):**
     - Verificar que todas las tarjetas (incluyendo `Anual`, `Perpetua` y `Pase Anual`) no generen ningún desbordamiento (`0px Overflow`) en resoluciones estrechas de 320dp y 360dp.
     - Aplicar rigurosamente `.withValues(alpha: ...)` eliminando cualquier `.withOpacity()`.

---

### FASE 5: Lanzador Admin Robusto en 1 Clic, Rotación de Backups y Ajustes Documentales

* **Objetivo:** Garantizar la ejecución inmediata de la plataforma admin desde un acceso directo en el Escritorio con filtrado robusto de puerto, implementar retención automática de snapshots en disco y corregir detalles en el manual operativo.
* **Archivos a intervenir en ejecución posterior:**
  - `Iniciar_MochilaLista_Admin.bat` (nuevo archivo en raíz)
  - `mochilalista_admin/lib/database_service.dart`
  - `mochilalista_admin/lib/config_service.dart`
  - `informe_proyecto/05_MANUAL_OPERATIVO_DEL_PROPIETARIO_Y_COMANDOS_RELEASE.md`
* **Tareas Técnicas Detalladas:**
  1. **Creación de `Iniciar_MochilaLista_Admin.bat`:**
     - Implementar script en la raíz con:
       ```bat
       @echo off
       title MochilaLista Admin Launcher
       cd /d "%~dp0mochilalista_admin"
       netstat -ano | findstr ":8080 " | findstr "LISTENING" >nul
       if %errorlevel% neq 0 (
           start "MochilaLista Admin Server" /min dart run server.dart
           timeout /t 2 /nobreak >nul
       )
       start http://localhost:8080
       ```
  2. **Política de Rotación de Snapshots en `mochilalista_admin`:**
     - En `DatabaseService`, implementar `_cleanOldSnapshots()` que conserve exactamente los últimos 30 snapshots automáticos con prefijo `sandbox_` o `prod_`, eliminando los excedentes antiguos y respetando los manuales (`manual` o `vault`).
     - En `ConfigService`, aplicar retención de los últimos 30 archivos `owner_config_backup_*.json`.
  3. **Limpieza Documental en `05_MANUAL_OPERATIVO_...md`:**
     - En Sección 1.11, corregir los nombres exactos de las 5 hojas Excel: `Resumen Ejecutivo`, `Cartera CRM`, `Libro de Pagos`, `Equipos y Licencias`, y `Guia y Glosario`.
     - En Sección 4.3 (y tabla de contenidos), reemplazar *"Cuota Mensual"* por *"Bolsa de Escaneos con IA"*.

---

### FASE 6: Batería Exhaustiva de Tests Automatizados, Regresión Completa y Compilación del APK Comercial Ofuscado

* **Objetivo:** Certificar mediante pruebas automáticas unitarias, de widgets y de integración que cada corrección funciona al 100%, ejecutar la suite completa de regresión en ambas plataformas y compilar el APK comercial definitivo.
* **Archivos a intervenir en ejecución posterior:**
  - Nuevas pruebas en `app_movil/test/`
  - Nuevas pruebas en `mochilalista_admin/test/`
* **Protocolo de Pruebas y Compilación:**
  1. **Nuevas Suites de Pruebas Automatizadas:**
     - `test/ai_quota_reactive_sync_test.dart`: Verifica que tras `consumeAiScan()`, `LicenseProvider.remainingAiScans` y `aiAccumulatedScans` decrecen de forma idéntica (`50 -> 49`) y se mantienen sincronizados en `INCLUDED` y `BYOK`.
     - `test/clean_install_eula_and_replay_protection_test.dart`: Simula instalación limpia (tabla SQLite vacía), valida que `eulaAcceptedVersion` es nulo, exige EULA y comprueba que un código de suscripción calcula la expiración atada a `iat` sin duplicar días.
     - `test/backup_multi_profile_database_integrity_test.dart`: Verifica que el archivo `.mlbg` empaqueta la base de datos completa con múltiples perfiles y negocios.
     - `test/order_modal_and_ui_density_widget_test.dart`: Prueba el Bottom Sheet editable de pedido y verifica el renderizado a `320x568` y `360x640` con 0 desbordamientos (`0px Overflow`) y cero emojis en botones.
     - `mochilalista_admin/test/admin_backup_rotation_test.dart`: Certifica que tras 35 operaciones consecutivas de guardado se conservan exactamente 30 snapshots automáticos en `backups/`.
  2. **Suite de Regresión Completa:**
     - Ejecutar en `app_movil/`: `flutter analyze` y `flutter test` sobre todas las suites existentes (incluyendo `cross_platform_admin_to_mobile_ed25519_verification_test.dart` y `eula_widget_and_legal_persistence_test.dart`).
     - Ejecutar en `mochilalista_admin/`: `dart analyze` y `dart test`.
  3. **Compilación Oficial del APK Comercial:**
     - Ejecutar la compilación final verificada:
       ```powershell
       flutter build apk --release --obfuscate --split-debug-info=build/app_symbols --dart-define=PRODUCTION=true
       ```

---

## 4. GUÍA ACCIONABLE PARA GOOGLE CLOUD CONSOLE (OAUTH SHA-1)

Para habilitar permanentemente el inicio de sesión en Google Drive en el teléfono físico Samsung Galaxy A54 5G y en cualquier compilación de prueba o comercial, se deben seguir estos pasos exactos en Google Cloud Console:

1. **Obtener las Huellas SHA-1 Reales de los Keystores:**
   - **Keystore de Depuración (Debug Keystore):**
     ```powershell
     keytool -list -v -keystore "$env:USERPROFILE\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
     ```
   - **Keystore de Release Comercial (si aplica):**
     ```powershell
     keytool -list -v -keystore "ruta\a\tu\keystore_release.jks" -alias tu_alias
     ```
2. **Registrar en Google Cloud Console:**
   - Ingresar a: `https://console.cloud.google.com/apis/credentials`
   - Seleccionar el proyecto correspondiente a MochilaLista.
   - En **ID de cliente de OAuth 2.0**, verificar o crear un cliente de tipo **Android**:
     - **Nombre del paquete:** `com.mochilalista.app`
     - **Huella digital del certificado SHA-1:** Pegar la huella hexadecimal copiada (ej. `AD:40:FC:...`).
   - Guardar cambios. (Google propaga las credenciales en sus servidores en un lapso de 2 a 5 minutos).
3. **Comportamiento en la App tras la Fase 3:**
   - Si por alguna razón la huella no está registrada o no hay internet, la app ya no mostrará el toast rojo invasivo; desplegará el diálogo explicativo con un botón para copiar los datos técnicos y compartirlos con soporte.

---

## 5. CRONOGRAMA DE EJECUCIÓN Y CRITERIOS DE ACEPTACIÓN ESTRICTOS

| Fase | Alcance Principal | Impacto en Producción | Criterio de Aceptación Estricto | Estado Final |
| :--- | :--- | :--- | :--- | :--- |
| **Fase 1** | Sincronización IA (Fuente Única) y Rediseño de `AiSettingsScreen` | Cero regresiones | Ambas pantallas muestran la misma cifra tras un escaneo en `INCLUDED` y `BYOK`. 0 textos cortados en 360dp. | **100% COMPLETADA** |
| **Fase 2** | EULA Limpio, Novedades y Blindaje `iat` | Seguridad legal y comercial | Toda instalación limpia exige EULA. Re-canje no regala días extra. Novedades accesibles en ajustes. | **100% COMPLETADA** |
| **Fase 3** | Diálogo Google Drive, Respaldo Multi-Perfil y Jerarquía UX | Experiencia de usuario | Diálogo amigable ante error OAuth. `.mlbg` certifica 100% de la BD SQLite. Pantalla de respaldos con Bloques A y B. | **100% COMPLETADA** |
| **Fase 4** | Modal Editable de Pedidos y Pulido QR (Cero Emojis) | Comercial y estético | Botón `Pedir` abre modal con texto editable e iconos Material. Botones QR nivelados en altura. | **100% COMPLETADA** |
| **Fase 5** | Lanzador Admin Robusto, Rotación Backups y Manual | Operatividad del autor | Doble clic en `.bat` inicia admin y abre navegador. Máximo 30 snapshots automáticos. Manual corregido. | **100% COMPLETADA** |
| **Fase 6** | Tests Automatizados, Regresión y Compilación APK | Certificación integral | 100% de tests unitarios/widgets pasando. Compilación de APK release ofuscado sin errores ni warnings. | **100% COMPLETADA** |

---

## 6. ACTA DE CIERRE Y CERTIFICACIÓN FINAL DEL PLAN MAESTRO 11

**Fecha de Emisión y Cierre Oficial:** 20 de Noviembre de 2026  
**Versión de Producción Consolidada:** `v9.32.0+76` (`mochilalista_v9.32_atp`)  
**Autor y Titular Legal Exclusivo:** Julio Angello Vasquez Navarro  
**Marco Normativo:** Decreto Legislativo 822 (Ley sobre el Derecho de Autor) e INDECOPI Perú  

Se certifica que los **6 Pilares y las 6 Fases** contempladas en este Plan Maestro han sido ejecutadas, validadas y auditadas en código real y en hardware físico (Samsung Galaxy A54 5G), satisfaciendo al 100% los criterios de aceptación técnicos y comerciales.

### Resumen de Resultados de Certificación Automatizada:
1. **Frontend Móvil (`app_movil/`):**
   * `flutter analyze --no-pub lib test`: **`No issues found!`** (0 errores, 0 advertencias).
   * Suite de Pruebas de Regresión Integral (13 archivos de prueba de Planes 07, 08, 09, 10 y 11): **`117/117 pruebas aprobadas`** (`All tests passed!`).
2. **Plataforma Administrativa (`mochilalista_admin/`):**
   * Sintaxis JavaScript: `node --check mochilalista_admin/web/js/admin_app.js` -> **Código de salida 0 (OK)**.
   * `dart analyze`: **`No issues found!`** (0 errores, 0 lints).
   * Suite de Pruebas Backend Admin: **`60/60 pruebas aprobadas`** (`All tests passed!`).
   * Servicio en Vivo: `GET / -> 200 OK` y `GET /api/vault/health -> 200 OK` en `http://localhost:8080`.
3. **Binario Oficial Generado y Verificado:**
   * **Nombre de Archivo:** `mochilalista_v9.32_atp.apk`
   * **Ubicación:** `C:\Users\vjuli\Documents\v-app-offline apks\mochilalista_v9.32_atp.apk`
   * **Tamaño Exacto:** `114,149,610 bytes` (`108.86 MB`)
   * **Huella Digital SHA-256:** `1603EDC4118F6A2642D54E5B76603403BEE77B1B380F664B02C07628ADFF8243`
   * **Huella Digital SHA-1:** `35080CFD0804841B68A51A4FFB2318499DC91BEC`
   * **Certificado de Firma (SHA-1 Digest):** `ad40fc4dc8edc40739729b183398a1d701fe5626`
   * **Certificado de Firma (SHA-256 Digest):** `f76f8a44669ce71156890af79273c6298019ce5f41c59ade56310b343a853206`
   * **Verificación de Integridad:** `apksigner verify --print-certs` -> **VÁLIDA Y VERIFICADA**.

> **PLAN MAESTRO 11 CULMINADO Y CERTIFICADO EXITOSAMENTE AL 100%. LISTO PARA DISTRIBUCIÓN Y DESPLIEGUE EN PRODUCCIÓN.**
