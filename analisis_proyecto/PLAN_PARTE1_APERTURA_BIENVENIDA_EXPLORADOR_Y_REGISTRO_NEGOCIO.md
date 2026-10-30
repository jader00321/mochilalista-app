# PLAN MAESTRO PARTE 1: APERTURA EN FRÍO ("MOBILE AWARDS"), SISTEMA DUAL DE TEMAS, EVOLUCIÓN DE SELECCIÓN DE PERFILES, MODO EXPLORADOR BLINDADO Y CONFIGURACIÓN DE NEGOCIO

**Documento:** `analisis_proyecto/PLAN_PARTE1_APERTURA_BIENVENIDA_EXPLORADOR_Y_REGISTRO_NEGOCIO.md`  
**Fecha:** 29 de Octubre de 2026  
**Versión:** 1.0 — Especificación Técnica Forense y Arquitectónica  
**Estado:** Esperando Revisión y Aprobación del Usuario (Paso 1: Planificación y Diagnóstico)  
**Metodología:** Loop Autónomo + Árbitro Interno Adversarial (Zero-Regressions, Zero-Overflows & Mobile Awards Experience)  

---

## 1. RESUMEN EJECUTIVO Y OBJETIVOS ESTRATÉGICOS

### 1.1. Contexto y Visión Global
La modernización integral de los flujos de bienvenida y configuración de **MochilaLista** representa el punto de contacto más determinante de la aplicación: la primera impresión del comerciante.  
Tras la inspección del código fuente y el análisis de las 4 capturas enviadas por el usuario, se han detectado oportunidades de transformación radical y defectos visuales específicos en 4 áreas cardinales:

1. **Apertura de la App (*Cold-Start Launch Experience*):**  
   Actualmente la app no cuenta con una pantalla de bienvenida animada; al abrirse muestra un `Scaffold` con un `CircularProgressIndicator` genérico en el centro mientras verifica la sesión SQLite. Se busca crear una experiencia cinemática memorable, de nivel **Mobile Awards**, con 3 variantes dinámicas de animación que roten entre arranques, ejecutadas a 60/120fps nativos y con activación **exclusiva en arranque en frío (*True Cold-Start Only*)**, transicionando de forma orgánica hacia la pantalla de perfiles o el home mediante curvas fluidas y `Hero`.

2. **Garantía de Modo Claro por Defecto y Paridad Absoluta Light / Dark Mode:**  
   Garantizar que todo usuario que abra la app por primera vez (sin registro previo en `SharedPreferences`) inicie en **Modo Claro (`ThemeMode.light`)**, y asegurar una paridad visual impecable en ambos temas (Claro y Oscuro), erradicando colores hardcodeados discordantes y permitiendo cambiar de tema desde la propia pantalla de bienvenida.

3. **Evolución de `Selecciona tu espacio de trabajo` e Integración del `Modo Explorador` (`Imagen 1`):**  
   Resolver el truncamiento tosco de nombres comerciales largos (`librería BAZAR...`), agregar distintivos de valor real como el badge `"Último activo"`, indicador de PIN si está protegido y sub-identificadores; incorporar un acceso **discreto, elegante y armónico al `Modo Explorador`** (`🧭 Explorar la app sin registrarse`), y blindar la navegación en modo explorador con **datos demo realistas** en toda la app sin arrojar pantallas rojas ni errores por falta de perfil SQLite, añadiendo un botón persistente o banner `"Crear mi Negocio"` para convertir visitantes en usuarios registrados.

4. **Reingeniería y Pulido de `Configura tu Negocio` (`Imágenes 2 y 3`):**  
   Corregir el corte de texto con puntos suspensivos en el label `Información de Pago (Yape, Plin, Cuent...`; agregar **chips interactivos rápidos (`+ Yape`, `+ Plin`, `+ BCP`, `+ CCI`)** que faciliten la entrada de datos; solucionar la colisión y corte abrupto del formulario contra el `SliverAppBar` verde al hacer scroll; habilitar un bloque opcional limpio para **RUC y Correo Electrónico** (que guarde en la BD); rediseñar el selector de logo a una **previsualización circular limpia** idéntica a cómo se verá en el avatar del Home; e incorporar un indicador visual de progreso y validación amigable 100% responsiva (320dp a tablets).

---

## 2. DIAGNÓSTICO FORENSE EN CÓDIGO (ARCHIVOS Y LÍNEAS EXACTAS)

### 2.1. Carencia de Experiencia Cold-Start y Salto Abrupto de Arranque
* **Archivos Involucrados:**
  * `app_movil/lib/main.dart` (Líneas 245–264)
  * `app_movil/lib/core/providers/auth_provider.dart` (Líneas 69–102)
* **Diagnóstico en Código:**
  En `main.dart`, el builder de `home` gestiona la carga inicial de la siguiente manera:
  ```dart
  home: Consumer<AuthProvider>(
    builder: (context, auth, _) {
      if (auth.status == AuthStatus.checking) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (auth.status == AuthStatus.profileSelection) {
        return const ProfileSelectionScreen();
      }
      if (auth.status == AuthStatus.authenticated && auth.user != null) {
        if (auth.hasPinCache) {
          return LockScreen(userId: auth.user!.id); 
        } else {
          return const HomeScreen(); 
        }
      }
      return const ProfileSelectionScreen();
    },
  )
  ```
* **Problemas Identificados:**
  1. Durante la lectura asíncrona de SQLite en `auth.checkInitialState()`, se renderiza un `Scaffold` en blanco con un `CircularProgressIndicator` básico.
  2. En dispositivos rápidos, esta comprobación dura entre 80ms y 250ms, generando un "fogonazo" o parpadeo visual antes de renderizar abruptamente `ProfileSelectionScreen` o `HomeScreen`.
  3. No existe ninguna bandera en memoria de sesión que rastree si el proceso acaba de arrancar en frío o si es una simple reconstrucción del widget tree, impidiendo modular una animación cinemática controlada.
  4. Falta una pantalla de presentación que proyecte la identidad visual de **MochilaLista**, sincronice la carga de recursos de fondo y transicione suavemente al destino final.

---

### 2.2. Sistema de Temas: Estado Inicial y Desconexión en Bienvenida
* **Archivos Involucrados:**
  * `app_movil/lib/core/providers/theme_provider.dart` (Líneas 4–27)
  * `app_movil/lib/main.dart` (Líneas 192–243)
  * `app_movil/lib/core/widgets/auth_background.dart` (Líneas 59–81)
* **Diagnóstico en Código:**
  1. En `ThemeProvider`:
     ```dart
     Future<void> _loadTheme() async {
       final prefs = await SharedPreferences.getInstance();
       final isDark = prefs.getBool(_key) ?? false;
       _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
       notifyListeners();
     }
     ```
     Aunque `prefs.getBool(_key) ?? false` teóricamente devuelve `false` si es nulo, `_themeMode` se inicializa como `ThemeMode.light` en memoria pero no hay validación explícita que garantice que en la primera instalación jamás tome el valor del sistema operativo si `SharedPreferences` está vacío.
  2. En `ProfileSelectionScreen` y `OnboardingScreen`, **NO existe ningún botón o switch para alternar entre Modo Claro y Modo Oscuro**. El usuario está obligado a iniciar sesión en un perfil, navegar a `ProfileScreen` y cambiarlo allí.
  3. En `auth_background.dart`, el gradiente superior en modo oscuro utiliza tonos verdes fijos `[Color(0xFF0F3A11), Color(0xFF142C23)]`, mientras que en modo claro usa azules `[Color(0xFF1976D2), Color(0xFF0D47A1)]`. Esta discrepancia cromática desconecta la paleta de marca y genera contrastes agresivos con textos blancos o negros en componentes hijos.

---

### 2.3. Selección de Perfiles (`profile_selection_screen.dart` y `widgets/profile_card_widgets.dart`) — Imagen 1
* **Archivos Involucrados:**
  * `app_movil/lib/features/auth/screens/onboarding/profile_selection_screen.dart` (Líneas 335–489, 583–688)
  * `app_movil/lib/features/auth/screens/onboarding/widgets/profile_card_widgets.dart` (Líneas 207–240)
* **Diagnóstico en Código y Captura Forense (`Imagen 1`):**
  1. **Truncamiento Rígido de Nombres:**
     En `ProfileCardContent` (Líneas 212–221 de `profile_card_widgets.dart`):
     ```dart
     Text(
       bName,
       style: TextStyle(
         fontWeight: FontWeight.w900,
         fontSize: 17,
         color: isDark ? Colors.white : Colors.black87,
       ),
       maxLines: 1,
       overflow: TextOverflow.ellipsis,
     ),
     ```
     En la `Imagen 1` se aprecia que ambos perfiles muestran `"librería BAZAR..."`. Al fijar `maxLines: 1` con un avatar de 52dp y flecha a la derecha, nombres comerciales normales en el rubro librero (ej. *"Librería Bazar Luzam"* o *"Librería Bazar San Carlos"*) son cercenados prematuramente.
  2. **Ausencia de Badges y Metadatos Clave:**
     * No hay indicación visual de cuál fue el **último negocio activo** utilizado en el teléfono (`last_active_user_id`), obligando al comerciante a recordar cuál de las tarjetas homónimas es la que estaba operando.
     * No hay indicador de **seguridad con PIN** (`hasPin`), de modo que el usuario no sabe si al tocar la tarjeta entrará directamente o se le solicitará código biométrico/PIN.
  3. **Ausencia Total de Acceso al Modo Explorador:**
     En `_buildNormalBottomSection` de `profile_selection_screen.dart` (Líneas 647–688), solo existen dos opciones:
     * Botón `CREAR NUEVO NEGOCIO`
     * Botón `¿Tienes un backup? Restaurar aquí`
     No existe **ningún acceso para explorar la aplicación sin registrarse**, dejando a un comerciante indeciso frente a un muro de registro forzado.

---

### 2.4. Modo Explorador: Desconexión y Ausencia de Datos Demo
* **Archivos Involucrados:**
  * `app_movil/lib/core/screens/home_screen.dart` (Líneas 110–126, 267–282, 361–405)
  * `app_movil/lib/features/catalog/screens/inventory_screen.dart` (Líneas 155–157, 268–285)
  * `app_movil/lib/features/catalog/screens/catalog/catalog_screen.dart`
  * `app_movil/lib/features/catalog/services/product_service.dart` (Líneas 17–20, 33–36)
  * `app_movil/lib/features/analytics/screens/analytics_dashboard_screen.dart` (Líneas 70–73, 552–566)
* **Diagnóstico en Código:**
  1. Si un usuario entrara a `HomeScreen` con `hasActiveContext == false` (`isGuest == true`), la barra de navegación se adapta (`Explorar`, `Inventario`, `Catálogo`).
  2. **Falla Crítica de Datos Vacíos:** En una instalación limpia, SQLite tiene 0 productos y 0 categorías. `ProductService.fetchInventory` evalúa:
     ```dart
     if (_negocioId == null) return null;
     ```
     Al ser `_negocioId == null`, todas las pantallas del catálogo e inventario retornan listas vacías y muestran banners de *"No hay productos registrados"*. El visitante no puede apreciar el potencial del sistema de inventarios, ni la interfaz de variantes, ni la venta rápida, ni las estadísticas, encontrando una aplicación vacía y desierta.
  3. En `AnalyticsDashboardScreen`, `prov.runStaggeredAnalysis()` verifica `if (_negocioId == null) return;` y aborta silenciosamente, dejando el panel de estadísticas en estado inerte permanente sin mostrar métricas ni gráficos de demostración.
  4. No existe una barra flotante o fija accesible desde cualquier pantalla del modo explorador que le permita al usuario decir: *"Me gustó la app, quiero crear mi negocio ahora"*.

---

### 2.5. Reingeniería y Pulido de `Configura tu Negocio` (`onboarding_screen.dart`) — Imágenes 2 y 3
* **Archivos Involucrados:**
  * `app_movil/lib/features/auth/screens/onboarding/onboarding_screen.dart` (Líneas 357–488, 501–640)
  * `app_movil/lib/core/widgets/custom_text_field.dart` (Líneas 56–74)
  * `app_movil/lib/core/widgets/image_picker_field.dart` (Líneas 83–128)
  * `app_movil/lib/core/services/auth_service.dart` (Líneas 44–88)
* **Diagnóstico en Código y Capturas Forenses (`Imágenes 2 y 3`):**
  1. **Corte del Label de Información de Pago:**  
     En `onboarding_screen.dart` (Línea 576):
     ```dart
     CustomTextField(
       label: 'Información de Pago (Yape, Plin, Cuenta, etc.)', 
       icon: Icons.account_balance_wallet_outlined, 
       controller: _infoPagoCtrl,
     )
     ```
     En `custom_text_field.dart`, este texto se asigna como `labelText: widget.label` dentro de `InputDecoration` con `prefixIcon`. Flutter calcula el ancho horizontal disponible y, en viewports de 360–400dp, corta el texto bruscamente con puntos suspensivos: `Información de Pago (Yape, Plin, Cuent...` (visible claramente en `Imágenes 2 y 3`).
  2. **Falta de Chips Rápidos de Pago:**  
     El usuario tiene que redactar manualmente *"Yape: 987654321"* en el teclado de su móvil, lo cual genera fricción. Faltan chips interactivos táctiles (`+ Yape`, `+ Plin`, `+ BCP`, `+ CCI`) que al tocarlos inserten la plantilla automáticamente.
  3. **Colisión de Scroll contra el SliverAppBar (Imagen 2):**  
     En `onboarding_screen.dart` (Líneas 501–510):
     ```dart
     child: Transform.translate(
       offset: const Offset(0, -32),
       child: Container(
         padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
         decoration: BoxDecoration(
           color: surfaceColor,
           borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
     ```
     Al hacer scroll descendente en el formulario, el contenedor se desplaza hacia arriba y cuando el `SliverAppBar` alcanza su estado colapsado (`pinned: true`), el contenido del formulario colisiona de golpe contra el borde inferior plano del AppBar verde, cortando los campos superiores sin sombra de transición, margen de respiro ni redondeo superior estético.
  4. **Omisión de RUC y Correo Electrónico:**  
     El formulario de `OnboardingScreen` no solicita RUC ni Email. Sin embargo, la tabla `negocios` tiene la columna `ruc` y la tabla `usuarios` tiene la columna `email`. En `auth_service.dart`:
     ```dart
     userId = await txn.insert('usuarios', {
       'nombre_completo': nombreDueno,
       'email': null, // HARDCODEADO A NULL
     ...
     await txn.insert('negocios', {
       'nombre_comercial': nombreNegocio,
       // RUC OMITIDO TOTALMENTE
     ```
     Esto impide que comerciantes con RUC 10 o 20 puedan configurar su razón fiscal desde el inicio, y limita las funciones posteriores de facturación y recuperación de PIN.
  5. **Selector de Logo Rectangular vs Avatar Circular:**  
     En `ImagePickerField` (Líneas 83–128), el logo se previsualiza en una caja rectangular gigante (`height: 160`, `width: double.infinity`), pero en el resto de la app el logo se visualiza como un círculo perfecto de 50x50 (`ClipOval`). El usuario no puede prever cómo lucirá su logo circularmente.

---

## 3. DISEÑO ARQUITECTÓNICO Y ESPECIFICACIONES TÉCNICAS

```
                             FLUJO DE ARRANQUE EN FRÍO
                               (True Cold-Start Only)
                                         │
                         ┌───────────────┴───────────────┐
                         ▼                               ▼
                 [ Proceso Nuevo ]              [ App en Segundo Plano ]
                (_coldStartCompleted=false)     (_coldStartCompleted=true)
                         │                               │
                         ▼                               ▼
             ┌─────────────────────────┐         ┌─────────────────────────┐
             │ ColdStartSplashScreen   │         │ No interrumpe la vista  │
             │ (Mobile Awards Quality) │         │ (AppLifecycleState      │
             │ • 3 Coreografías        │         │  resumed mantiene flujo │
             │ • 60/120 fps nativo     │         │  habitual o LockScreen) │
             │ • Logo MochilaLista     │         └─────────────────────────┘
             │ • Hero Transition       │
             └───────────┬─────────────┘
                         │
         ┌───────────────┴───────────────┐
         ▼                               ▼
[ Sin Perfil Activo ]           [ Perfil Activo ]
         │                               │
         ▼                               ├───────────────┬───────────────┐
┌─────────────────────────┐              ▼               ▼               ▼
│ ProfileSelectionScreen  │         [ Con PIN ]     [ Sin PIN ]     [ Invitado ]
│ • Selector Claro/Oscuro │              │               │               │
│ • Badges: Último Activo │              ▼               ▼               ▼
│   y Protegido con PIN   │         LockScreen       HomeScreen      HomeScreen
│ • Nombres 2 líneas      │                                          (Modo Demo)
│ • 🧭 MODO EXPLORADOR    │
└─────────────────────────┘
```

---

### 3.1. Arquitectura de Apertura en Frío (*True Cold-Start Only*)
1. **Control en Memoria de Sesión:**
   * Se define una variable estática en memoria `static bool _coldStartCompleted = false;` en una clase de control de ciclo de vida (`AppLaunchManager` o en `AuthProvider`).
   * La pantalla de animación de bienvenida **SOLO** se ejecuta cuando `_coldStartCompleted == false`.
   * Una vez completada la animación y transicionada la pantalla hacia el destino, la bandera se marca en `_coldStartCompleted = true`.
   * Si el usuario minimiza la aplicación a segundo plano y la vuelve a abrir (`AppLifecycleState.resumed`), la app continúa directamente en la pantalla donde estaba o en `LockScreen` según el retardo de seguridad configurado, sin jamás reproducir el splash de bienvenida.
2. **Ciclo de Vida y Limpieza Inmediata de Recursos:**
   * El widget `ColdStartSplashScreen` maneja un único `AnimationController` orquestador (o controladores atómicos) que son liberados inmediatamente en `dispose()` tras completar la transición de salida, garantizando cero consumo residual de RAM o CPU.

---

### 3.2. Coreografía de las 3 Variantes de Animación Dinámica
Para brindar una sensación fresca en cada arranque en frío, se implementará un selector dinámico (`variantIndex = (DateTime.now().second + _launchCounter) % 3`) que alterna entre 3 coreografías exclusivas diseñadas con `CustomPainter` nativo a 60/120fps:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                   VARIANTES DE APERTURA (COLD-START)                        │
├───────────────────────────────┬─────────────────────────────┬───────────────┤
│ 1. Pulso Orbital Ejecutivo    │ 2. Despliegue Geométrico    │ 3. Sincronía  │
│                               │    y Onda de Luz            │    de Módulos │
├───────────────────────────────┼─────────────────────────────┼───────────────┤
│ • Dos anillos orbitales con   │ • Polígonos de cristal que  │ • Nodos       │
│   halo lumínico giran en      │   se abren desde el centro  │   constelación│
│   sentidos opuestos al logo.  │   revelando el isotipo.     │   convergen:  │
│ • Destello sutil de luz sobre │ • SweepGradient expansivo   │   Inventario, │
│   el isotipo MochilaLista.    │   como onda de choque.      │   IA, Radar.  │
│ • Texto "MochilaLista" emerge │ • Partículas flotantes con  │ • Copys       │
│   con deslizamiento y fade.   │   efecto de brillo dinámico │   dinámicos   │
│ • Duración: 1600ms fluida.    │ • Duración: 1700ms fluida.  │   rotativos.  │
└───────────────────────────────┴─────────────────────────────┴───────────────┘
```

1. **Variante 1: Pulso Orbital Ejecutivo:**
   * Anillos elípticos concéntricos con `CustomPainter` que rotan a velocidades compensadas con gradientes cian y azul cobalto, proyectando un resplandor ambiental (*glowing blur*) que rodea el logo de MochilaLista.
   * Micro-pulsación en la escala del logo (`0.92 → 1.05 → 1.0`) mediante curva elástica suave.
2. **Variante 2: Despliegue Geométrico y Onda de Luz:**
   * Malla geométrica sutil en el fondo que se ilumina con una onda expansiva circular (*ripple wave* con gradiente radial y `ImageFilter.blur`).
   * Un barrido de brillo (*shimmer sweep*) que cruza en diagonal el logo, revelando la tipografía corporativa con opacidad escalonada.
3. **Variante 3: Sincronización Inteligente de Módulos:**
   * Cuatro orbes de energía estilizados representan los módulos de la aplicación (*Inventario*, *Escáner IA*, *Cotizaciones*, *Radar Comercial*) orbitando hacia el centro hasta fusionarse en el logo de MochilaLista.
   * Mensajes dinámicos y tranquilizadores que van rotando en la base:
     * *"Sincronizando base de datos local..."*
     * *"Calibrando escáner de visión artificial..."*
     * *"Sintonizando radar comercial regional..."*
     * *"Tu negocio listo en un instante."*

---

### 3.3. Sistema de Temas: Claro por Defecto y Selector en Bienvenida
1. **Regla de Primer Uso Incondicional:**
   * Modificar `ThemeProvider._loadTheme()` para comprobar explícitamente:
     ```dart
     final prefs = await SharedPreferences.getInstance();
     if (!prefs.containsKey('is_dark_mode')) {
       _themeMode = ThemeMode.light; // SIEMPRE CLARO PARA USUARIOS NUEVOS
     } else {
       final isDark = prefs.getBool('is_dark_mode') ?? false;
       _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
     }
     ```
2. **Selector Discreto de Tema en la Esquina Superior de Bienvenida:**
   * En `ProfileSelectionScreen` (y en el AppBar de `OnboardingScreen`), incorporar en la esquina superior derecha un botón flotante con diseño glassmorphic y animación de rotación suave (sol $\leftrightarrow$ luna) que permite cambiar entre Modo Claro y Modo Oscuro al instante.
3. **Paridad Cromática Dual:**
   * Unificar `AuthBackground` para que tanto en modo claro como en modo oscuro proyecte un gradiente de diseño corporativo de alta gama:
     * **Modo Claro:** Gradiente azul rey y zafiro profundo `[Color(0xFF1E88E5), Color(0xFF0D47A1)]` con fondo de tarjetas en blanco marfil puro `Color(0xFFFFFFFF)` y bordes sutiles `Color(0xFFE2E8F0)`.
     * **Modo Oscuro:** Gradiente grafito y esmeralda nocturna profunda `[Color(0xFF0D1F18), Color(0xFF132820)]` o zafiro medianoche `[Color(0xFF0F172A), Color(0xFF1E293B)]` que coincida armónicamente con la paleta de la app, fondo de tarjetas en `Color(0xFF1E2235)` y textos con contraste AAA.

---

### 3.4. Rediseño de `Selecciona tu espacio de trabajo` (`Imagen 1`)
1. **Solución a Nombres Comerciales Truncados:**
   * Modificar `ProfileCardContent` para permitir hasta **2 líneas** de texto comercial con altura de línea compacta (`maxLines: 2, height: 1.25`) y tamaño adaptativo (16sp en pantallas compactas, 17sp en estándar).
2. **Distintivos de Valor en la Tarjeta de Perfil:**
   * **Badge "Último activo":** Si el perfil coincide con `last_active_user_id`, se despliega una píldora visual en verde esmeralda o azul celeste en la esquina superior derecha de la tarjeta: `● Último activo`.
   * **Indicador de Seguridad (PIN):** Ícono vectorial discreto `Icons.lock_rounded` junto al nombre del dueño si la cuenta posee PIN configurado.
   * **Diferenciador de Perfiles Homónimos:** Si dos perfiles comparten el mismo nombre comercial, se visualiza debajo un tag con su moneda o identificador `#ID` para que el comerciante reconozca de inmediato cuál es cuál.
3. **Acceso Discreto y Elegante al `Modo Explorador`:**
   * En la parte inferior de la tarjeta o debajo de las acciones secundarias, se añade un botón táctil con estilo píldora minimalista:
     `🧭 Explorar la app sin registrarse (Modo Demo)`
   * Con diseño limpio, bordes redondeados y tipografía seminegrita que no distrae al usuario recurrente pero invita de forma cálida al nuevo visitante.

---

### 3.5. Blindaje del Modo Explorador & `DemoDataProvider`
1. **Auditoría y Blindaje Anti-Crash:**
   * Crear o potenciar un servicio `DemoDataService` / `ExplorerContext` que, cuando `auth.hasActiveContext == false`, provea un conjunto en memoria de **datos de demostración realistas**:
     * **8 a 12 Productos de Librería y Comercio:** (ej. *Cuaderno Standford Cuadriculado 100H*, *Caja Lapiceros Faber-Castell 033 x50*, *Resma Papel Fotocopia A4 Navigator*, *Tijera Artesco Escolar 5"*, *Goma en Barra Pritt 40g*), con precios en Soles, categorías y fotos/iconos reales.
     * **Mesa de Trabajo / Cotizaciones:** 2 cotizaciones escolares de prueba (*Lista 3ro Primaria - Colegio San Agustín*, *Lista Inicial 5 Años - Mi Pequeño Mundo*) con estado "En preparación" y "Completada".
     * **Estadísticas / Inteligencia de Negocio:** Datos simulados de ventas semanales (S/ 2,450.00), gráficos activos y alertas de stock para que el panel de analítica luzca vibrante y demuestre todo su poder analítico.
2. **Barra Global de Conversión ("Crear mi Negocio"):**
   * En todas las ventanas principales durante el Modo Explorador, se mantendrá un banner o píldora flotante inferior estilizada:
     `🧭 Estás en Modo Explorador (Demostración) • [ Crear mi Negocio ]`
   * Al pulsar `"Crear mi Negocio"`, se abre de inmediato `OnboardingScreen` permitiendo al comerciante crear su perfil real en segundos.

---

### 3.6. Reingeniería y Pulido de `Configura tu Negocio` (`Imágenes 2 y 3`)
1. **Corrección del Label y Chips Interactivos de Pago:**
   * Cambiar el label rígido por una etiqueta limpia `"Información de Pago"` y un `hintText` explicativo `"Ej: Yape 987654321 / BCP 193-..."`.
   * Debajo del campo de texto, agregar una fila horizontal de **chips táctiles rápidos**:
     * `[+ Yape]` $\rightarrow$ agrega al texto `Yape: `
     * `[+ Plin]` $\rightarrow$ agrega al texto `Plin: `
     * `[+ BCP]` $\rightarrow$ agrega al texto `BCP: `
     * `[+ BBVA]` $\rightarrow$ agrega al texto `BBVA: `
     * `[+ CCI]` $\rightarrow$ agrega al texto `CCI: `
   * Permite armar los datos de transferencia en un par de toques sin tipeo engorroso.
2. **Resolución de Colisión de Scroll con SliverAppBar:**
   * Rediseñar la integración del `SliverAppBar` con un `SliverPersistentHeader` o `SliverToBoxAdapter` que mantenga un radio curvado constante con sombra superior y un margen de respiro de al menos 16dp, evitando que los campos de texto choquen rígidamente contra la barra colapsada.
3. **Bloque Opcional para RUC y Correo Electrónico:**
   * Agregar una sección opcional `"Datos Fiscales y Contacto (Opcional)"`:
     * Campo `RUC (11 dígitos)` con formateador numérico y validación de 11 dígitos.
     * Campo `Correo Electrónico` con validación de sintaxis de email.
   * Conectar estos campos con `AuthService.registerLocalProfile` para que se almacenen de una vez en las tablas `negocios` y `usuarios` de SQLite.
4. **Previsualización de Logo Circular con Recorte Limpio:**
   * Reemplazar la caja rectangular gris de 160dp por un **avatar circular central de 100x100 dp** con borde decorativo, botón de cámara flotante y texto interactivo `"Tocar para agregar logo de tu negocio"`.
   * Al seleccionar una imagen, se muestra exactamente como se verá en el Home de la app.
5. **Indicador de Progreso Visual y Responsividad Multi-Pantalla:**
   * Barra de progreso horizontal o contador en la cabecera: `"Completado: 2 de 3 pasos"` que se anima dinámicamente conforme se llenan los campos obligatorios.
   * Ajuste de padding y márgenes con `clamp()` para asegurar renderizado impecable en pantallas de 320dp, 360–400dp y tablets.

---

## 4. PLAN DE TRABAJO POR FASES DE IMPLEMENTACIÓN BLINDADAS

### FASE 1: Arquitectura de Arranque en Frío (*True Cold-Start*) y las 3 Variantes de Animación
* **Objetivo:** Implementar la experiencia de apertura Mobile Awards con activación exclusiva en arranque en frío y transición Hero fluida.
* **Acciones Concretas:**
  1. Crear `app_movil/lib/core/services/app_launch_manager.dart` con la bandera estática `static bool _coldStartCompleted = false;` y lógica de orquestación.
  2. Crear `app_movil/lib/core/screens/splash/cold_start_splash_screen.dart` con:
     * Variante 1: *Pulso Orbital Ejecutivo* (anillos elípticos concéntricos con `CustomPainter`, resplandor y halo focal).
     * Variante 2: *Despliegue Geométrico y Onda de Luz* (polígonos de cristal y `SweepGradient` expansivo).
     * Variante 3: *Sincronización Inteligente de Módulos* (nodos orbitales convergiendo al centro con mensajes dinámicos rotativos).
  3. Integrar la transición `Hero` del logo hacia `ProfileSelectionScreen` o `HomeScreen`.
  4. Actualizar `main.dart` para que el flujo de arranque invoque `ColdStartSplashScreen` únicamente si `_coldStartCompleted == false`, transicionando al destino correspondiente y liberando memoria (`dispose()`).
* **Verificación de la Fase:** Compilación limpia sin errores de análisis (`dart analyze`), transición suave a 60/120fps, y verificación de que al minimizar la app y volver a abrirla NO se reejecute el splash.

---

### FASE 2: Modo Claro por Defecto y Selector Dual de Temas en Bienvenida
* **Objetivo:** Garantizar que los usuarios nuevos inicien en Modo Claro y habilitar cambio de tema desde la pantalla de bienvenida.
* **Acciones Concretas:**
  1. Modificar `ThemeProvider._loadTheme()` en `app_movil/lib/core/providers/theme_provider.dart` para asegurar que ante la ausencia de `'is_dark_mode'`, el valor inicial sea estrictamente `ThemeMode.light`.
  2. Refactorizar `app_movil/lib/core/widgets/auth_background.dart` para que ofrezca paridad cromática de alta gama tanto en Light como en Dark Mode, sin colores hardcodeados discordantes.
  3. Incorporar en la esquina superior de `ProfileSelectionScreen` y `OnboardingScreen` un selector interactivo discreto de tema (sol/luna) con micro-animación.
* **Verificación de la Fase:** Probar en simulador/dispositivo borrando datos de la app: comprobar que inicia en Modo Claro; alternar el switch en la pantalla de bienvenida y certificar paridad de contrastes.

---

### FASE 3: Rediseño Responsivo de Selección de Perfiles (`Imagen 1`)
* **Objetivo:** Resolver truncamientos de nombres comerciales, añadir badges de valor y habilitar acceso discreto a Modo Explorador.
* **Acciones Concretas:**
  1. Modificar `app_movil/lib/features/auth/screens/onboarding/widgets/profile_card_widgets.dart`:
     * Permitir hasta 2 líneas en el nombre comercial con tipografía responsiva.
     * Añadir badge de `"Último activo"` según `last_active_user_id`.
     * Añadir icono de PIN protegido (`Icons.lock_rounded`) si el perfil tiene seguridad.
     * Añadir identificador o detalle diferenciador para perfiles con nombres idénticos.
  2. Modificar `app_movil/lib/features/auth/screens/onboarding/profile_selection_screen.dart`:
     * Incorporar en la parte inferior de la tarjeta el acceso sutil y elegante: `🧭 Explorar la app sin registrarse (Modo Demo)`.
     * Configurar la acción de tap para enrutar directamente a `HomeScreen` en modo invitado.
* **Verificación de la Fase:** Validar con nombres largos en viewports de 320dp y 360dp que no haya cortes con `...` ni desbordamientos de pantalla (`RenderFlex overflow`).

---

### FASE 4: Blindaje Integral del Modo Explorador y Datos de Demostración Realistas
* **Objetivo:** Garantizar que la navegación en modo explorador sea fluida, rica en funciones, visualmente completa y libre de pantallas rojas.
* **Acciones Concretas:**
  1. Crear `app_movil/lib/core/services/demo_data_service.dart` que provea catálogos de demostración (8-12 productos escolares y de bazar con precios, stock y categorías), 2 cotizaciones en mesa de trabajo y métricas financieras de ejemplo.
  2. Blindar `HomeScreen`, `InventoryScreen`, `CatalogScreen`, `WorkbenchScreen`, `QuickSaleScreen` y `AnalyticsDashboardScreen` para que, cuando `isGuest == true`:
     * Carguen sin errores los datos de demostración en lugar de listas vacías.
     * Bloqueen acciones de persistencia real con modales explicativos amables.
  3. Implementar un banner o barra flotante global sutil en Modo Explorador con el botón `"Crear mi Negocio"`, que abre `OnboardingScreen` en cualquier momento.
* **Verificación de la Fase:** Recorrer minuciosamente todas las pantallas en Modo Explorador y confirmar que no se produce ninguna excepción de base de datos ni pantalla roja.

---

### FASE 5: Reingeniería y Pulido de `Configura tu Negocio` (`Imágenes 2 y 3`)
* **Objetivo:** Resolver el corte de texto en Información de Pago, agregar chips interactivos, eliminar colisión de scroll, agregar RUC/Email y previsualización de logo circular.
* **Acciones Concretas:**
  1. Modificar `app_movil/lib/features/auth/screens/onboarding/onboarding_screen.dart`:
     * Cambiar label de pago a `"Información de Pago"` y colocar `hintText`.
     * Agregar chips rápidos `[+ Yape]`, `[+ Plin]`, `[+ BCP]`, `[+ BBVA]`, `[+ CCI]` debajo del campo.
     * Reestructurar el `SliverAppBar` y el contenedor superior para mantener un margen de respiro y transición limpia al hacer scroll hacia arriba.
     * Agregar sección opcional de `"Datos Fiscales y Contacto"` para **RUC** (11 dígitos) y **Correo Electrónico**.
     * Reemplazar el contenedor rectangular del logo por un **avatar circular de 100x100** con vista previa idéntica al Home.
     * Incorporar indicador de progreso visual del formulario y optimización responsiva (320dp a tablets).
  2. Actualizar `app_movil/lib/core/services/auth_service.dart` y `AuthProvider` para persistir `ruc` y `email` en la base de datos al registrar el negocio.
* **Verificación de la Fase:** Probar el formulario en pantallas compactas (`320dp`) y estándar (`360-400dp`), hacer scroll completo hacia abajo y arriba, verificar chips de pago, registrar un negocio con RUC/Email y confirmar en SQLite su correcta persistencia.

---

### FASE 6: Pruebas de Estrés del Árbitro Interno Adversarial y Certificación Final
* **Objetivo:** Someter todas las ventanas intervenidas a las pruebas más exigentes de robustez, diseño y rendimiento.
* **Acciones Concretas:**
  1. Ejecución de `flutter analyze` para certificar 0 advertencias y 0 errores.
  2. Simulación de dispositivos de baja resolución (`320x568` iPhone SE 1st gen y Android compactos de 320dp) para verificar que no existe ni un solo píxel de overflow.
  3. Verificación de ciclos de vida: cerrar app por completo $\rightarrow$ splash abre y transiciona; minimizar app $\rightarrow$ splash NO reaparece.
  4. Alternancia dinámica entre Modo Claro y Modo Oscuro en todas las pantallas creadas/modificadas, certificando contraste legible en textos y fondos.
  5. Prueba de extremo a extremo del Modo Explorador: navegar, interactuar con datos demo y pulsar `"Crear mi Negocio"` completando el registro.

---

## 5. MATRIZ DE CONTROL DEL ÁRBITRO INTERNO ADVERSARIAL

| # | Escenario Adversarial Crítico | Riesgo Potencial | Estrategia de Mitigación y Blindaje |
|---|---|---|---|
| **A1** | **Usuario minimiza la app tras abrirla y regresa al primer plano** | Splash se vuelve a disparar molestando al usuario | Bandera estática en memoria `_coldStartCompleted = true` inmediatamente tras el primer arranque; ignorar eventos `AppLifecycleState.resumed`. |
| **A2** | **Dispositivo de gama baja o modo de ahorro de batería extremo** | Animaciones CustomPainter provocan tirones (jank) | Controladores ligeros basados en funciones matemáticas puras; eliminación de shaders pesados; `dispose()` estricto al completar la transición. |
| **A3** | **Usuario nuevo abre la app por primera vez con el móvil configurado en Dark Mode a nivel de SO** | La app se abre en modo oscuro en contra de la regla | `ThemeProvider._loadTheme()` comprueba si la clave `'is_dark_mode'` existe en `SharedPreferences`; si no existe, impone `ThemeMode.light` forzado. |
| **A4** | **Nombre comercial extremadamente largo (ej: "Librería, Papelería y Bazar San Cristóbal de Huamanga")** | Desbordamiento o corte con `...` ilegible | `maxLines: 2`, `TextOverflow.ellipsis`, `Auto-size / clamp` en tipografía y ajuste de padding horizontal. |
| **A5** | **Dos negocios creados con el mismo nombre comercial por el mismo usuario** | Confusión absoluta sobre cuál perfil seleccionar | Distintivo `Último activo` en el perfil de la última sesión + tag de identificación secundario (`#ID` o moneda). |
| **A6** | **Usuario en Modo Explorador intenta cotizar, vender o ver inventario** | Excepción SQLite por `negocioId == null` y pantalla roja | `DemoDataService` intercepta cuando `hasActiveContext == false` entregando listas demo en memoria con cero llamadas nulas a SQLite. |
| **A7** | **Scroll rápido hacia abajo en "Configura tu Negocio" en pantalla pequeña (320dp)** | El primer campo de texto se corta rígidamente contra el AppBar verde | Transición suave con curva `SliverPersistentHeader` y margen superior de 16dp fijo de respiro visual. |
| **A8** | **Usuario presiona repetidamente los chips de pago (`+ Yape`, `+ Plin`)** | Texto duplicado desordenado en el campo de pago | Lógica inteligente que detecta si el método ya está presente en el texto antes de concatenar con salto de línea limpio. |
| **A9** | **Selección de una imagen cuadrada o panorámica muy grande como logo** | La vista previa deforma el formulario o se desborda | Avatar circular fijo `100x100` con `UniversalImage(fit: BoxFit.cover)` y recorte circular limpio. |
| **A10** | **Usuario cancela la selección de imagen o selecciona un archivo corrupto** | Crash al procesar archivo local | Bloque `try-catch` robusto en `ImageService` y fallback automático al icono por defecto. |

---

## 6. MAPA DE ARCHIVOS A CREAR Y MODIFICAR (PARTE 1)

### Archivos Nuevos a Crear:
1. `app_movil/lib/core/services/app_launch_manager.dart` (Gestión del ciclo de vida y bandera en frío).
2. `app_movil/lib/core/screens/splash/cold_start_splash_screen.dart` (Experiencia de apertura "Mobile Awards" con las 3 coreografías).
3. `app_movil/lib/core/services/demo_data_service.dart` (Conjunto de datos realistas para navegación en Modo Explorador).
4. `app_movil/lib/core/widgets/explorer_conversion_dock.dart` (Barra sutil permanente de Modo Explorador con botón "Crear mi Negocio").

### Archivos Existentes a Modificar:
1. `app_movil/lib/main.dart` (Integración de Cold-Start en `home` y control de temas).
2. `app_movil/lib/core/providers/theme_provider.dart` (Garantía de Modo Claro por defecto en primera apertura).
3. `app_movil/lib/core/widgets/auth_background.dart` (Paridad y armonía cromática dual Light/Dark).
4. `app_movil/lib/features/auth/screens/onboarding/profile_selection_screen.dart` (Selector de temas, acceso a Modo Explorador, micro-animaciones).
5. `app_movil/lib/features/auth/screens/onboarding/widgets/profile_card_widgets.dart` (Badges de "Último activo", PIN, nombres a 2 líneas).
6. `app_movil/lib/features/auth/screens/onboarding/onboarding_screen.dart` (Chips interactivos de pago, corrección de colisión de scroll, RUC/Email, logo circular, indicador de progreso).
7. `app_movil/lib/core/services/auth_service.dart` y `app_movil/lib/core/providers/auth_provider.dart` (Soporte de persistencia para RUC y Email).
8. `app_movil/lib/core/screens/home_screen.dart` y pantallas principales (Blindaje de datos demo y visualización de la barra de conversión).

---

## 7. CRITERIOS DE ACEPTACIÓN PARA LA ORDEN DE EJECUCIÓN

1. **Apertura en Frío Exclusiva:** El splash cinemático solo se ejecuta al abrir la app desde cero (`_coldStartCompleted == false`). Al minimizar y reanudar, jamás reaparece.
2. **3 Coreografías Dinámicas:** Las 3 variantes de animación (*Pulso Orbital*, *Despliegue Geométrico*, *Sincronización de Módulos*) funcionan con fluidez de 60/120fps y transicionan suavemente a la pantalla destino.
3. **Modo Claro por Defecto:** Toda instalación sin datos previos arranca en Modo Claro incondicionalmente, con paridad de contrastes y selector manual en bienvenida.
4. **Perfiles Responsivos y sin Cortes:** Nombres comerciales de hasta 2 líneas sin `...` abrupto, badge `"Último activo"` y badge de PIN presente.
5. **Modo Explorador 100% Funcional:** Navegación viva y poblada con productos y cotizaciones demo realistas, cero pantallas rojas por SQLite y botón visible `"Crear mi Negocio"`.
6. **Configuración de Negocio Pulida:** Label de pago sin cortes, chips `+ Yape / + Plin / + BCP` funcionales, scroll sin colisión contra el AppBar, campos RUC y Email guardados en BD, y logo en avatar circular.
7. **Calidad de Código:** Cero advertencias ni errores en `dart analyze`.
