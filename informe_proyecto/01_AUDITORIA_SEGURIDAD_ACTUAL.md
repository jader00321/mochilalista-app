# 🔒 INFORME 1: Auditoría de Seguridad — Estado Actual de MochilaLista v8.5.0

**Fecha:** 3 de Octubre de 2026  
**Versión Analizada:** 8.5.0+47  
**Autor:** Auditoría Automatizada de Seguridad  
**Objetivo:** Identificar vulnerabilidades de seguridad en la app antes de la comercialización.

---

## 📋 Resumen Ejecutivo

MochilaLista es una aplicación Flutter offline-first con una base de datos SQLite local, integración con Google Gemini AI, y un sistema de backups robusto. Tras un análisis exhaustivo del código fuente, se han identificado **18 vulnerabilidades** clasificadas por severidad. Este informe detalla cada una con su riesgo real, impacto en un escenario comercial, y la solución recomendada.

### Tabla de Severidad

| Severidad | Cantidad | Descripción |
|-----------|----------|-------------|
| 🔴 **CRÍTICA** | 5 | Explotables inmediatamente. Bloquean la comercialización. |
| 🟠 **ALTA** | 5 | Riesgo significativo para datos de usuarios y el modelo de negocio. |
| 🟡 **MEDIA** | 4 | Podrían ser explotadas con conocimiento técnico moderado. |
| 🟢 **BAJA** | 4 | Mejoras de hardening y buenas prácticas. |

---

## 🔴 VULNERABILIDADES CRÍTICAS (Bloquean Comercialización)

### CRIT-01: API Key de Google Gemini Expuesta en Texto Plano

**Archivo afectado:** [`.env`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/.env)

**Descripción:** La clave de API de Google Gemini (`GOOGLE_API_KEY`) está almacenada directamente en el archivo `.env`, el cual se incluye como asset del APK (`assets: [.env]` en [`pubspec.yaml`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/pubspec.yaml#L76)). Esto significa que:

1. Cualquier persona con el APK puede descomprimir el archivo (un APK es un ZIP) y leer la API Key en texto plano.
2. Un atacante puede usar tu API Key para hacer llamadas ilimitadas a Gemini AI, generando costos a tu cuenta de Google.
3. Google podría bloquear tu API Key por abuso, dejando a TODOS tus usuarios sin funciones de IA.

**Impacto:** ⚠️ **FINANCIERO DIRECTO** — Un atacante podría generar miles de dólares en costos de API usando tu clave.

**Evidencia en código:**
```yaml
# pubspec.yaml línea 76
assets:
  - .env   # ← El archivo .env se empaqueta dentro del APK
```
```env
# .env línea 9
GOOGLE_API_KEY=AQ.Ab8RN6L****REDACTADO_POR_SEGURIDAD****  # ← Visible para cualquiera
```

**Solución recomendada:**
- **Inmediata:** Rotar (cambiar) la API Key actual en Google AI Studio, la actual está comprometida al estar en un repositorio.
- **Permanente:** Mover la API Key fuera del APK. Opciones:
  - *Opción A (Recomendada):* Usar `--dart-define` en tiempo de compilación para inyectar la key sin incluirla en assets.
  - *Opción B:* Hacer que cada usuario registre su propia API Key de Gemini (distribución del costo).
  - *Opción C:* Crear un proxy server mínimo que controle el acceso (pero requiere infraestructura online).

---

### CRIT-02: Application ID Genérico — `com.example.app_movil`

**Archivo afectado:** [`build.gradle.kts`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/android/app/build.gradle.kts#L26)

**Descripción:** El `applicationId` sigue siendo `com.example.app_movil`, que es el nombre por defecto de los proyectos Flutter. Esto tiene múltiples implicaciones críticas:

1. **Google Play Store rechazará** cualquier publicación con `com.example.*`.
2. **No se puede firmar con keystore de producción** de forma profesional.
3. **Cualquier otra app con el mismo ID podría reemplazar la tuya** en el dispositivo del usuario.
4. Los usuarios no podrían identificar la app legítima de una falsa.

**Solución recomendada:**
- Cambiar a un `applicationId` único como `com.mochilalista.app` o `com.tunombre.mochilalista`.
- Generar un keystore de producción propio para firmar la app.

---

### CRIT-03: APK Firmado con Debug Key — Sin Firma de Producción

**Archivo afectado:** [`build.gradle.kts`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/android/app/build.gradle.kts#L33-L39)

**Descripción:** La compilación release usa la firma de debug:
```kotlin
release {
    signingConfig = signingConfigs.getByName("debug")  // ← PELIGRO
    isMinifyEnabled = false
    isShrinkResources = false
}
```

**Impacto:**
1. Cualquiera puede crear una versión "modificada" de tu app y distribuirla como si fuera original.
2. Los usuarios no tienen forma de verificar que el APK que reciben es legítimo.
3. Un atacante podría inyectar malware, robar datos del negocio, y redistribuir el APK.

**Solución recomendada:**
- Crear un keystore de producción: `keytool -genkey -v -keystore mochilalista-release.jks`.
- Configurar `signingConfigs` con el keystore de producción.
- Activar `isMinifyEnabled = true` y `isShrinkResources = true` para ofuscar el código.
- **NUNCA perder el keystore** — sin él, no podrás publicar actualizaciones.

---

### CRIT-04: Base de Datos SQLite Sin Cifrado

**Archivo afectado:** [`local_db.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/core/database/local_db.dart)

**Descripción:** La base de datos `mochilalista.db` se almacena sin cifrado alguno. En un dispositivo rooteado, o incluso con un cable USB y herramientas como ADB, es posible:

1. Extraer el archivo `.db` completo del dispositivo.
2. Abrirlo con cualquier visor SQLite y leer TODA la información del negocio.
3. Obtener datos de clientes, ventas, precios de costo, márgenes de ganancia, proveedores y deudas.

**Impacto en comercial:** Si un competidor obtiene acceso al teléfono de tu cliente, podría extraer toda su información comercial confidencial.

**Solución recomendada:**
- Reemplazar `sqflite` por `sqflite_sqlcipher` que usa SQLCipher (AES-256).
- Derivar la clave de cifrado del PIN del usuario + un salt único del dispositivo.
- La base de datos sería completamente ilegible sin la clave.

---

### CRIT-05: Código Fuente Visible — Sin Ofuscación Dart

**Contexto:** Compilación actual

**Descripción:** Al compilar con `flutter build apk --release` sin el flag `--obfuscate`, todo el código Dart queda expuesto en el snapshot del APK. Un atacante con herramientas de ingeniería inversa puede:

1. Extraer los nombres de todas las clases, métodos y variables.
2. Entender la lógica de negocio, el algoritmo de matching, y los flujos de validación.
3. **Clonar la funcionalidad completa de la app** en su propia aplicación.
4. **Descubrir y burlar cualquier sistema de licencias/códigos de acceso** que implementemos.

**Solución recomendada:**
```bash
flutter build apk --release --obfuscate --split-debug-info=build/debug-info
```
- Agregar `--obfuscate` convierte todos los nombres legibles en strings aleatorios.
- `--split-debug-info` guarda el mapeo (necesario para debugging) en una carpeta separada que NO se distribuye.

---

## 🟠 VULNERABILIDADES ALTAS

### ALTA-01: PIN de Seguridad Almacenado en Texto Plano (Reversible)

**Archivo afectado:** [`auth_provider.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/core/providers/auth_provider.dart#L124)

**Descripción:** Aunque se usa `FlutterSecureStorage`, el PIN se almacena como texto plano:
```dart
await _secureStorage.write(key: 'pin_${newUser.id}', value: pin);
```

Si bien `FlutterSecureStorage` cifra los datos en Android Keystore, el PIN en sí no está hasheado. Esto significa que si alguien tiene acceso al secure storage (dispositivo rooteado), puede leer el PIN directamente.

**Solución:** Almacenar un hash SHA-256 del PIN + salt, en vez del PIN en texto plano. Al verificar, hashear la entrada del usuario y comparar hashes.

---

### ALTA-02: `allowBackup="false"` Insuficiente Sin Network Security Config

**Archivo afectado:** [`AndroidManifest.xml`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/android/app/src/main/AndroidManifest.xml#L34)

**Descripción:** Se tiene `android:usesCleartextTraffic="true"` que permite tráfico HTTP sin cifrar. Esto expone las comunicaciones de la app (como las llamadas a la API de Gemini) a ataques Man-in-the-Middle (MITM) en redes WiFi públicas.

**Solución:**
- Cambiar `android:usesCleartextTraffic="false"`.
- Crear un `network_security_config.xml` que solo permita HTTPS.

---

### ALTA-03: Sin Validación de Integridad del APK (Tampering)

**Descripción:** No existe ningún mecanismo para detectar si el APK ha sido modificado después de la compilación. Un atacante podría:
1. Descompilar el APK.
2. Remover el sistema de licencias o validación.
3. Recompilar y distribuir una versión "crackeada".

**Solución:** Implementar verificación de firma del APK en runtime para detectar si la app ha sido reempaquetada.

---

### ALTA-04: Permisos Excesivos en el Manifiesto

**Archivo afectado:** [`AndroidManifest.xml`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/android/app/src/main/AndroidManifest.xml)

**Descripción:** La app solicita permisos que podrían no necesitar todas las veces:
- `ACCESS_BACKGROUND_LOCATION` — Riesgo de vigilancia percibida por el usuario.
- `READ_EXTERNAL_STORAGE` + `WRITE_EXTERNAL_STORAGE` — Acceso amplio al almacenamiento.

**Impacto:** Los usuarios podrían rechazar la app o Google Play podría restringir la publicación.

**Solución:** Revisar cada permiso y solicitar solo los estrictamente necesarios, usando scoped storage para archivos.

---

### ALTA-05: No Existe Protección Anti-Root / Anti-Emulador

**Descripción:** La app funciona igual en dispositivos rooteados y emuladores. En un dispositivo rooteado, cualquier app maliciosa puede acceder a los datos de MochilaLista, incluyendo la base de datos, el secure storage, y los archivos de backup.

**Solución:** Implementar detección de root (usando `flutter_jailbreak_detection` o checks manuales) y mostrar una advertencia al usuario.

---

## 🟡 VULNERABILIDADES MEDIAS

### MED-01: Backup `.mlbg` y `.mlb` Sin Cifrado

Los archivos de backup contienen toda la base de datos y se pueden abrir con WinRAR/7-Zip. Si alguien intercepta el archivo compartido por WhatsApp, tiene acceso total a los datos del negocio.

**Solución:** Cifrar el contenido del ZIP con una contraseña derivada del PIN del usuario.

---

### MED-02: Sin Rate Limiting en Verificación de PIN

El sistema de verificación de PIN no tiene límite de intentos. Un atacante con acceso físico puede probar todas las combinaciones posibles (fuerza bruta) — un PIN de 4 dígitos tiene solo 10,000 combinaciones.

**Solución:** Implementar bloqueo progresivo (3 intentos → esperar 30s, 5 intentos → esperar 5min, 10 intentos → bloqueo temporal).

---

### MED-03: Imágenes de Facturas Almacenadas Sin Protección

Las imágenes escaneadas de facturas se guardan en el directorio de documentos de la app sin cifrado. Contienen información comercial sensible (precios de costo, proveedores, condiciones).

**Solución:** Almacenar imágenes en el directorio privado de la app con nombres ofuscados.

---

### MED-04: Logs de Debug Activos en Producción

Múltiples `debugPrint()` a lo largo del código podrían exponer información sensible en logcat:
```dart
debugPrint("Error leyendo perfiles locales: $e");  // Podría revelar estructura DB
```

**Solución:** Crear un wrapper de logging que solo imprima en modo debug, silenciando en release.

---

## 🟢 VULNERABILIDADES BAJAS

| ID | Descripción | Solución |
|----|-------------|----------|
| LOW-01 | `db_inspector_screen.dart` disponible en producción | Proteger con flag de debug o eliminar |
| LOW-02 | Versión de base de datos expuesta en nombre del archivo | Ofuscar nombre del archivo DB |
| LOW-03 | Sin detección de screenshots/grabación de pantalla | Implementar `FLAG_SECURE` en ventanas sensibles |
| LOW-04 | No se borra la caché temporal de imágenes procesadas | Implementar limpieza automática post-procesamiento |

---

## 📊 Mapa de Riesgo Visual

```
IMPACTO ALTO    │  ALTA-05    │  CRIT-01  CRIT-03
                │  ALTA-02    │  CRIT-04  CRIT-05
                │             │  CRIT-02
────────────────┼─────────────┼───────────────────
IMPACTO MEDIO   │  MED-01     │  ALTA-01  ALTA-03
                │  MED-02     │  ALTA-04
                │  MED-03     │
────────────────┼─────────────┼───────────────────
IMPACTO BAJO    │  LOW-01     │  MED-04
                │  LOW-02     │
                │  LOW-03     │
                │  LOW-04     │
────────────────┼─────────────┼───────────────────
                │ BAJA        │ ALTA
                │ PROBABILIDAD │ PROBABILIDAD
```

---

## ✅ Prioridad de Remediación (Orden Recomendado)

| Prioridad | ID | Esfuerzo Estimado | Bloquea Comercialización |
|-----------|-----|-------------------|--------------------------|
| 1 | CRIT-01 | 2-3 horas | ✅ SÍ |
| 2 | CRIT-02 | 1 hora | ✅ SÍ |
| 3 | CRIT-03 | 2 horas | ✅ SÍ |
| 4 | CRIT-05 | 30 minutos | ✅ SÍ |
| 5 | CRIT-04 | 4-6 horas | ✅ SÍ |
| 6 | ALTA-02 | 1 hora | ⚠️ Recomendado |
| 7 | ALTA-01 | 2 horas | ⚠️ Recomendado |
| 8 | ALTA-03 | 3-4 horas | ⚠️ Recomendado |
| 9 | MED-02 | 2 horas | ❌ No |
| 10 | MED-01 | 3 horas | ❌ No |

---

> [!CAUTION]
> **Las 5 vulnerabilidades CRÍTICAS deben resolverse ANTES de distribuir la app comercialmente.** Cualquier persona con conocimiento técnico básico puede explotar CRIT-01 (robar tu API Key) y CRIT-05 (clonar tu app) en menos de 10 minutos con herramientas gratuitas.

---

*Continúa en → [02_PROPUESTAS_COMERCIALIZACION.md](file:///c:/Users/vjuli/Documents/mochilalista-app/informe_proyecto/02_PROPUESTAS_COMERCIALIZACION.md)*
