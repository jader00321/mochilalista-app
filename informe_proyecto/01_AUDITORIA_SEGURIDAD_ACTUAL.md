# 🔒 INFORME 1: Auditoría de Seguridad — Estado Actual de MochilaLista v9.23.0

**Fecha de Auditoría:** 13 de Noviembre de 2026  
**Versión de Código Analizada:** `v9.23.0+73`  
**Esquema de Base de Datos:** Versión `34`  
**Entorno de Ejecución:** Flutter 3.9.0+ / Dart 3.9.0 (Android SDK 36, Java 17)  
**Autor:** Auditoría Integral de Seguridad y Arquitectura de Software  
**Objetivo:** Evaluar las vulnerabilidades de seguridad de la aplicación tras la incorporación de los módulos de Noviembre 2026 (Cotizador Universal IA, Extracción/Corte de Variantes con Stock Compartido, Fidelización/Premios/Reputación y Centro de Notificaciones Inteligente) y diseñar las soluciones técnicas definitivas antes de su comercialización.

---

## 📋 1. Resumen Ejecutivo y Estado a Noviembre 2026

MochilaLista ha evolucionado de forma sustancial durante 2026, consolidándose como una suite comercial **offline-first de alto rendimiento** para comerciantes mayoristas y minoristas en Perú. La versión actual (`9.23.0+73`) integra módulos críticos de negocio:
1. **Cotizador Universal IA (`smart_quotation`):** Procesamiento multimodal de listas escolares y pedidos complejos con modelos Gemini 3.8 Flash y Gemini 3.1 Flash-Lite.
2. **Extracción y Corte de Variantes con Stock Compartido:** Auditoría de facturas de proveedores con distribución de stock dependiente/independiente.
3. **Centro de Fidelización, Premios y Reputación Financiera:** Sistema de scoring crediticio, límites de mora y canje de recompensas.
4. **Centro de Notificaciones Inteligente:** Bandejas categorizadas (Prioritarias, Archivadas, Silenciadas/No deseadas) y alertas en tiempo real.

A pesar de su robustez funcional, la auditoría de seguridad sobre el código base actual revela **vulnerabilidades críticas que bloquean su distribución comercial**. Si la app se distribuyera hoy en formato APK directo, un atacante o competidor podría:
- Extraer la clave de Google Gemini y generar consumos masivos no autorizados.
- Descompilar el código binario (`libapp.so`) y clonar los algoritmos propietarios de cotización y fidelización.
- Copiar la base de datos completa de un cliente (`mochilalista.db` v34) en texto plano con precios de costo, márgenes y clientes.
- Burlar cualquier sistema de licencias si se implementara con llaves simétricas compartidas.

### Matriz de Vulnerabilidades Identificadas

| Severidad | Total | Estado | Impacto Comercial Directo |
|-----------|:-----:|:------:|---------------------------|
| 🔴 **CRÍTICA** | 5 | Bloqueante | Riesgo financiero, clonación de software y robo de secretos |
| 🟠 **ALTA** | 5 | Urgente | Compromiso de integridad de datos y suplantación |
| 🟡 **MEDIA** | 4 | Importante | Fuga de datos en tránsito local y fuerza bruta |
| 🟢 **BAJA** | 4 | Hardening | Higiene de código y exposición de metadatos |

---

## 🔴 2. Vulnerabilidades Críticas (Bloqueantes Comerciales)

### CRIT-01: Exposición de `GOOGLE_API_KEY` en Assets y Memoria Binaria

* **Ubicación en código:**
  * `pubspec.yaml` (Línea 79): `assets: - .env`
  * `lib/core/config/api_constants.dart` (Líneas 7-16): Lectura directa mediante `dotenv.env['GOOGLE_API_KEY']`
  * `lib/main.dart`: Inicialización obligatoria con `dotenv.load()`
* **Diagnóstico de Riesgo:**
  1. Al estar `.env` declarado en los `assets` del `pubspec.yaml`, el archivo se empaqueta sin cifrar dentro del archivo ZIP del APK (`assets/flutter_assets/.env`). Cualquier usuario puede cambiar la extensión `.apk` a `.zip`, descomprimirlo y obtener la clave en 5 segundos.
  2. Aunque se retire del `.env` y se inyecte con `--dart-define`, un binario compilado contiene cadenas literales en la sección `.rodata` de `libapp.so`. Al ejecutar el comando `strings libapp.so | grep "AIza"`, la clave de Google Cloud queda visible en texto plano.
  3. Un tercero puede usar esa clave para consumir cuotas de Gemini 3.8 Flash, generando costos imprevistos o provocando la suspensión de la cuenta por parte de Google.
* **Solución Técnica Definitiva (Doble Capa: XOR en Memoria + Restricción Google Cloud):**
  1. **Retiro de Assets:** Eliminar `.env` del archivo `pubspec.yaml` y agregar `.env` a `.gitignore`.
  2. **Ofuscación XOR en Memoria:** Almacenar la API Key como un arreglo de bytes enmascarado con una clave XOR de ciclo variable. La reconstrucción de la cadena ocurre únicamente en memoria volátil en el microsegundo exacto en que se instancia `GoogleAIClient`, y se limpia de inmediato. De esta forma, el comando `strings` sobre `libapp.so` solo encuentra secuencias de bytes aleatorias.
  3. **Restricción Criptográfica en Google Cloud Console:**
     * Acceder a **Google Cloud Console > Credentials > API Key**.
     * Configurar **Application restrictions** en **Android apps**.
     * Registrar el nombre de paquete de producción: `com.mochilalista.app`.
     * Registrar la huella digital **SHA-1** y **SHA-256** del certificado de firma (`mochilalista-release.jks`).
     * *Efecto del blindaje:* Aunque un atacante obtenga los bytes de la clave, Google rechazará el 100% de las peticiones HTTP que no provengan de un binario firmado con tu Keystore de producción oficial.

---

### CRIT-02: Identificador de Aplicación Genérico (`com.example.app_movil`)

* **Ubicación en código:**
  * `android/app/build.gradle.kts` (Línea 8 y Línea 26):
    ```kotlin
    namespace = "com.example.app_movil"
    defaultConfig {
        applicationId = "com.example.app_movil"
        ...
    }
    ```
  * `android/app/src/main/AndroidManifest.xml` (Línea 2): `package="com.example.app_movil"`
* **Diagnóstico de Riesgo:**
  1. `com.example.*` es el identificador por defecto de plantillas Flutter. Los sistemas operativos Android tratan las aplicaciones con el mismo `applicationId` como el mismo paquete: cualquier otra app instalada con dicho ID intentará sobrescribirla.
  2. Google Play Store rechaza automáticamente cualquier intento de registro bajo el namespace `com.example`.
  3. Impide la vinculación de servicios protegidos de Google Cloud (Maps, Gemini, Play Integrity) que exigen un dominio inverso profesional.
* **Solución Técnica Definitiva:**
  * Modificar de forma sincronizada en `build.gradle.kts`, `AndroidManifest.xml` y la estructura de carpetas de Kotlin (`android/app/src/main/kotlin/com/mochilalista/app/MainActivity.kt`) al identificador oficial: `com.mochilalista.app`.

---

### CRIT-03: Compilación Release Firmada con Clave de Debug

* **Ubicación en código:**
  * `android/app/build.gradle.kts` (Líneas 34-38):
    ```kotlin
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug") // 🔴 CRÍTICO
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
    ```
* **Diagnóstico de Riesgo:**
  1. La firma de debug (`debug.keystore`) utiliza contraseñas públicas universales (`android` / `androiddebugkey`).
  2. Un atacante puede decompilar la aplicación, inyectar código malicioso para extraer la base de datos o burlar el sistema de licencias, volver a firmarla con cualquier debug keystore e instalarla como si fuera legítima.
  3. No hay garantía de autoría ni protección de identidad digital del creador.
* **Solución Técnica Definitiva:**
  1. Generar un Keystore RSA de 4096 bits exclusivo y privado: `mochilalista-release.jks`.
  2. Configurar la lectura de credenciales desacoplada mediante `android/key.properties` (archivo que se excluye explícitamente de Git).
  3. Configurar en `build.gradle.kts` el bloque `signingConfigs.create("release")`.
  4. Custodiar dicho archivo con copias de seguridad desconectadas (unidad física encriptada). Perder este archivo impediría actualizar las instalaciones de los clientes.

---

### CRIT-04: Base de Datos SQLite (v34) en Texto Plano y Estrategia de Cifrado sin Ruptura de Pruebas

* **Ubicación en código:**
  * `lib/core/database/local_db.dart` (Línea 34): `openDatabase(path, version: 34, ...)`
  * `lib/core/utils/backup_manager.dart`: Copia directa de `mochilalista.db`
* **Diagnóstico de Riesgo:**
  1. La base de datos contiene más de 20 tablas operativas: `ventas`, `productos`, `clientes`, `facturas_carga`, `eventos_financieros_cliente`, `historial_puntos_reputacion`, `smart_quotations` y `stock_ledger`.
  2. En dispositivos con acceso root, copias de seguridad por depuración USB (ADB) o mediante inspección física de almacenamiento, cualquier persona puede extraer el archivo `mochilalista.db` y examinar costos de importación, precios de compra a proveedores, listas de clientes y números de teléfono.
* **Corrección Técnica Rigurosa (Arquitectura Dual para Producción y `flutter test`):**
  * **El Peligro de Reemplazo Directo:** Si se reemplaza indiscriminadamente `sqflite` por `sqflite_sqlcipher` en `local_db.dart`:
    1. Se rompen inmediatamente las **más de 96 suites de pruebas unitarias y de integración** que corren en Windows (`flutter test`) usando `sqflite_common_ffi`, ya que SQLCipher requiere binarios nativos compilados de OpenSSL C que no existen en el entorno de desarrollo estándar de Windows.
    2. Si un comerciante ya tiene datos en su versión actual sin cifrar, abrir la base de datos con una contraseña de SQLCipher lanzará una excepción fatal: `DatabaseException: file is not a database`, provocando pérdida de datos aparente y caída de la app.
  * **Solución Arquitectónica:**
    1. **Abstracción del Factory de Conexión:**
       Implementar un `DatabaseConnectionProvider` que detecte el entorno:
       - Si está en ejecución de pruebas (`Platform.environment.containsKey('FLUTTER_TEST')` o `kIsTestEnvironment`): inicializa SQLite plano en memoria mediante `sqflite_common_ffi` sin requerir librerías externas de Windows.
       - Si está en dispositivo móvil físico (Android): inicializa el driver cifrado `sqflite_sqlcipher` con cifrado AES-256.
    2. **Migración Transparente y Segura de Bases de Datos Existentes:**
       Al inicializar la app en un dispositivo de actualización:
       - Inspeccionar los primeros 16 bytes del archivo `mochilalista.db`. Si la cabecera coincide exactamente con la cadena mágica `"SQLite format 3\000"`, el archivo está sin cifrar.
       - Ejecutar el comando SQLCipher seguro de migración sin riesgo de corrupción:
         ```sql
         ATTACH DATABASE 'mochilalista_encrypted.db' AS encrypted KEY 'CLAVE_AES256_DERIVADA';
         SELECT sqlcipher_export('encrypted');
         DETACH DATABASE encrypted;
         ```
       - Cerrar la conexión original, renombrar `mochilalista.db` como `mochilalista_legacy.bak` y promover `mochilalista_encrypted.db` a `mochilalista.db`.
       - Si los primeros 16 bytes no corresponden a la cabecera de texto plano, la base de datos ya está cifrada y se abre directamente con la clave en memoria.

---

### CRIT-05: Exposición Total de la Lógica de Negocio en el Binario (Falta de Ofuscación Dart)

* **Diagnóstico de Riesgo:**
  1. Las compilaciones estándar `flutter build apk --release` preservan nombres de clases, nombres de tablas SQLite, identificadores de campos, prompts de IA y métodos de cálculo financiero en la tabla de símbolos de `libapp.so`.
  2. Herramientas automatizadas como `darter` o desensambladores ARM permiten reconstruir el árbol de widgets y la lógica de validación de licencias en pocas horas.
* **Solución Técnica Definitiva:**
  * Adoptar obligatoriamente la regla de compilación comercial con ofuscación profunda y separación de símbolos:
    ```bash
    flutter build apk --release \
      --obfuscate \
      --split-debug-info=./build/symbols_v9230/ \
      --dart-define=PRODUCTION=true
    ```
  * Los mapas de desofuscación generados en `./build/symbols_v9230/` deben guardarse junto con el código fuente en el archivo maestro del proyecto, permitiendo traducir futuros reportes de fallos mientras el APK distribuido queda completamente anonimizado.

---

## 🟠 3. Vulnerabilidades Altas (Integridad y Acceso)

### ALTA-01: Hash de PIN Débil o Almacenamiento en Texto Plano

* **Ubicación en código:** `lib/core/providers/auth_provider.dart`
* **Diagnóstico:** Si bien `FlutterSecureStorage` utiliza Android KeyStore, almacenar el PIN de 4 a 6 dígitos en texto plano permite que, en caso de compromiso de root o extracción de memoria, el atacante recupere el PIN numérico de inmediato.
* **Solución:** Almacenar en `FlutterSecureStorage` únicamente el hash criptográfico `PBKDF2-HMAC-SHA256` del PIN junto con una sal (`salt`) aleatoria de 32 bytes única por instalación. Al validar el acceso, se calcula el hash del PIN ingresado y se compara en tiempo constante (`constant-time comparison`) para evitar ataques de temporización (`timing attacks`).

---

### ALTA-02: Tráfico en Texto Plano Permitido en Manifiesto Android

* **Ubicación en código:** `android/app/src/main/AndroidManifest.xml` (Línea 34): `android:usesCleartextTraffic="true"`
* **Diagnóstico:** Permite que cualquier componente de la app realice solicitudes HTTP sin cifrar. En redes WiFi comerciales o públicas, un atacante puede interceptar peticiones de red mediante Man-in-the-Middle (MITM).
* **Solución:**
  1. Cambiar a `android:usesCleartextTraffic="false"`.
  2. Configurar `android:networkSecurityConfig="@xml/network_security_config"` restringiendo el tráfico exclusivamente a HTTPS con TLS 1.3 para los endpoints de Google AI (`generativelanguage.googleapis.com`).

---

### ALTA-03: Ausencia de Verificación de Integridad en Tiempo de Ejecución (Anti-Tampering)

* **Diagnóstico:** La app carece de un mecanismo que compruebe si el APK que se está ejecutando fue recompilado o alterado por un tercero tras remover controles de acceso.
* **Solución:** Implementar un validador nativo en `MainActivity.kt` o mediante invocación por MethodChannel que consulte el PackageInfo de Android y compare la huella digital SHA-256 de las firmas del certificado en ejecución contra la huella legítima del autor. Si difiere, la app aborta su inicialización inmediatamente.

---

### ALTA-04: Permisos Excesivos y Obsoletos en `AndroidManifest.xml`

* **Ubicación en código:** `android/app/src/main/AndroidManifest.xml` (Líneas 4-22)
* **Diagnóstico:** Se solicitan permisos como:
  * `ACCESS_BACKGROUND_LOCATION` (Línea 10): Genera alertas de privacidad invasivas en Android 11+ y no es requerido para un sistema POS de mostrador.
  * `READ_EXTERNAL_STORAGE` y `WRITE_EXTERNAL_STORAGE`: Obsoletos en Android 13+ (API 33+), sustituidos por Scoped Storage y PhotoPicker.
* **Solución:** Eliminar `ACCESS_BACKGROUND_LOCATION`. Reemplazar los permisos de almacenamiento por los selectores estándar de Android (`READ_MEDIA_IMAGES` para Android 13+ y retención de archivos en el sandbox privado `/data/user/0/com.mochilalista.app/files`).

---

### ALTA-05: Falta de Detección Defensiva de Entornos Root / Emuladores Inseguros

* **Diagnóstico:** El uso de la app en entornos rooteados o emuladores de desarrollo desprotegidos expone el almacenamiento interno a herramientas de memoria como Frida, Xposed o GameGuardian para alterar variables de stock o fechas de licencia.
* **Solución:** Implementar rutinas de detección de binarios `su`, paquetes de superusuario (`com.topjohnwu.magisk`) y propiedades de compilación de emuladores (`ro.kernel.qemu`). Mostrar advertencia de seguridad operacional al usuario sin bloquear de forma destructiva a comerciantes que utilicen dispositivos legítimos modificados.

---

## 🟡 4. Vulnerabilidades Medias

### MED-01: Archivos de Respaldo (`.mlbg`) sin Cifrado Criptográfico

* **Ubicación en código:** `lib/core/utils/backup_manager.dart` (Líneas 17-66)
* **Diagnóstico:** La función `_createGlobalBackupZip` genera un archivo ZIP estándar comprimido con la base de datos `mochilalista.db` y las imágenes de facturas. Cuando el comerciante comparte su backup por WhatsApp o lo guarda en Google Drive, cualquier persona con acceso al archivo puede abrirlo con 7-Zip o WinRAR y examinar toda la contabilidad del negocio.
* **Solución:** Cifrar el flujo de bytes del archivo de backup usando **AES-256-GCM**. La clave de cifrado se derivará mediante `PBKDF2` a partir de una "Contraseña de Respaldo del Negocio" definida por el usuario, o de una clave maestra de recuperación vinculada a su licencia. De este modo, el archivo `.mlbg` es completamente ilegible si se extravía o se envía por canales de mensajería abiertos.

---

### MED-02: Ausencia de Rate Limiting en Verificación de PIN

* **Ubicación en código:** `lib/core/providers/auth_provider.dart`
* **Diagnóstico:** No existe penalización de tiempo ante intentos fallidos consecutivos de ingreso de PIN. Un PIN de 4 dígitos (10,000 combinaciones) puede adivinarse en pocos minutos si alguien tiene acceso físico temporal al teléfono.
* **Solución:** Implementar bloqueo temporal progresivo:
  * 3 intentos erróneos: espera de 30 segundos.
  * 5 intentos erróneos: espera de 5 minutos.
  * 10 intentos erróneos: bloqueo temporal requiriendo el código de recuperación o clave maestra.

---

### MED-03: Imágenes de Facturas Almacenadas en Caché Temporal sin Limpieza

* **Ubicación en código:** `lib/features/scanner/services/invoice_processor_service.dart`
* **Diagnóstico:** Las fotografías de facturas y boletas de proveedores capturadas por la cámara se procesan y almacenan en directorios temporales sin un ciclo de recolección garantizado. Si el dispositivo se conecta a una computadora mediante MTP, estas imágenes podrían ser leídas.
* **Solución:** Guardar las imágenes temporales exclusivamente en el directorio `getTemporaryDirectory()`, aplicar nombres UUID sin metadatos del proveedor y ejecutar una rutina de borrado seguro (`shred/delete`) una vez que los ítems han sido transferidos a `facturas_carga` en la base de datos.

---

### MED-04: Emisión de Logs de Depuración en Producción (`debugPrint`)

* **Ubicación en código:** Dispersos en más de 40 archivos de `lib/core/` y `lib/features/`
* **Diagnóstico:** Se emiten trazas de error con consultas SQL, respuestas de API de Gemini y estructuras JSON internas en Logcat mediante `debugPrint()`. Cualquier aplicación con permiso `READ_LOGS` en versiones antiguas de Android o conectada a un visor de logs puede monitorear la actividad del negocio.
* **Solución:** Centralizar todas las salidas en un servicio unificado `AppLogger` que condicione toda salida a `kDebugMode`. En compilaciones `--release`, las llamadas deben resolverse como operaciones nulas (no-op).

---

## 🟢 5. Vulnerabilidades Bajas

| ID | Hallazgo | Riesgo | Solución Recomendada |
|----|----------|--------|----------------------|
| **LOW-01** | `db_inspector_screen.dart` accesible en código | Exposición de visor interno de base de datos | Envolver la ruta en una bandera condicional de modo depuración (`if (kDebugMode)`) para que no se incluya en release. |
| **LOW-02** | Nombre del archivo de base de datos predecible (`mochilalista.db`) | Facilita la localización por herramientas forenses | Renombrar internamente el archivo de almacenamiento a un identificador neutro (ej. `.ml_data_store.dat`). |
| **LOW-03** | Capturas de pantalla permitidas en pantallas sensibles | Fuga de saldos y márgenes por capturas accidentales | Implementar `FlutterWindowManager.addFlags(FLAG_SECURE)` en pantallas financieras críticas (Balance, Ganancias, Lista de Clientes con Deuda). |
| **LOW-04** | Metadatos EXIF no depurados en imágenes de recibos | Geoposición GPS y datos de cámara adjuntos a fotos | Utilizar la librería `image` para decodificar y reescribir los bytes eliminando bloques EXIF antes de guardar. |

---

## 📊 6. Mapa de Priorización y Plan de Acción Inmediato

```
ALTO IMPACTO   │  ALTA-05  ALTA-02    │  CRIT-01 (API Key)  CRIT-03 (Firma Release)
               │                      │  CRIT-04 (Cifrado)  CRIT-05 (Ofuscación)
               │                      │  CRIT-02 (App ID)
───────────────┼──────────────────────┼─────────────────────────────────────────────
MEDIO IMPACTO  │  MED-01 (Backups)    │  ALTA-01 (Hash PIN)  ALTA-03 (Anti-Tamper)
               │  MED-02 (Rate Limit) │  ALTA-04 (Permisos)
               │  MED-03 (Imágenes)   │
───────────────┼──────────────────────┼─────────────────────────────────────────────
BAJO IMPACTO   │  LOW-01   LOW-02     │  MED-04 (Logs Release)
               │  LOW-03   LOW-04     │
───────────────┼──────────────────────┼─────────────────────────────────────────────
               │ BAJA PROBABILIDAD    │ ALTA PROBABILIDAD DE EXPLOTACIÓN
```

### Matriz de Ejecución Técnica Pre-Comercialización

1. **Paso 1 (Inmediato - 1 hora):** Configurar `com.mochilalista.app`, generar `mochilalista-release.jks` y configurar `build.gradle.kts`.
2. **Paso 2 (Inmediato - 2 horas):** Retirar `.env` de assets, aplicar ofuscación XOR a la API Key y configurar restricciones de SHA-1 en Google Cloud Console.
3. **Paso 3 (Arquitectura - 3 horas):** Implementar abstracción de base de datos (`DatabaseConnectionProvider`) que asegure compatibilidad con SQLCipher en Android mientras preserva el 100% de los tests en Windows con `sqflite_common_ffi`.
4. **Paso 4 (Higiene - 1 hora):** Ajustar permisos en `AndroidManifest.xml` y silenciar `AppLogger` en modo release.

---
*Continúa en → [02_PROPUESTAS_COMERCIALIZACION.md](file:///c:/Users/vjuli/Documents/mochilalista-app/informe_proyecto/02_PROPUESTAS_COMERCIALIZACION.md)*
