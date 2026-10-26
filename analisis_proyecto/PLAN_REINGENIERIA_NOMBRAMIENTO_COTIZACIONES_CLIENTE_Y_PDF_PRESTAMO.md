# PLAN DE TRABAJO MAESTRO: REINGENIERÍA DEL SISTEMA DE NOMBRAMIENTO INTELIGENTE DE COTIZACIONES, GESTIÓN DE CLIENTE/COLEGIO Y COMPROBANTE PDF DE PRÉSTAMO

**Proyecto:** Mochila Lista — Aplicación Móvil POS / CRM / Analítica  
**Documento:** Plan de Trabajo Detallado, Auditoría Forense y Arquitectura de Solución  
**Ruta:** `analisis_proyecto/PLAN_REINGENIERIA_NOMBRAMIENTO_COTIZACIONES_CLIENTE_Y_PDF_PRESTAMO.md`  
**Metodología:** Loop Autónomo Continuo + Árbitro Interno Adversarial  
**Estado:** Pendiente de Aprobación por el Usuario  

---

## 1. RESUMEN EJECUTIVO Y OBJETIVOS ESTRATÉGICOS

A partir de la auditoría forense del código fuente y el contraste directo contra las **2 capturas de pantalla adjuntas** y el archivo real **`COMPROBANTE DE PRESTAMO.pdf`**, se ha detectado una serie de inconsistencias de estado, desbordes visuales y fallas contables en tres módulos cruciales de la aplicación:

1. **Cotización Manual (`manual_quotation_screen.dart` y widgets modulares):** Pérdida de reactividad al desvincular o cambiar clientes (el nombre del cliente queda pegado permanentemente en el título), botón `"Guardar en Mis Clientes"` cortado visualmente por colisión de padding, choque físico del botón flotante naranja `+` sobre los controles de la tarjeta del cliente, y uso de formatos numéricos locales con coma (`18,80 S/`) en lugar del estándar corporativo `AppCurrency.format(...)`.
2. **Flujo de Escáner IA (`matching_screen.dart`, `matching_provider.dart`):** Falta de paridad con la cotización manual en la previsualización y edición del título inteligente, omisión del colegio/grado en el nombramiento cuando no hay cliente registrado, y discrepancias en la sincronización de metadatos extraídos hacia SQLite.
3. **Generador de Comprobante de Préstamo en PDF (`pdf_generator.dart`, `COMPROBANTE DE PRESTAMO.pdf`):** Falla contable de alta gravedad donde el campo `"Capital Prestado"` refleja el total con interés en lugar del capital neto desembolsado, ausencia de la fila obligatoria `"Interés Aplicado"`, impresión duplicada del bloque de totales al final del documento, error ortográfico en el encabezado (`"PRESTAMO"` sin tilde) y falta de estandarización monetaria a `AppCurrency.format(...)` (`S/ #,##0.00`) en todo el recibo y cronograma de 24 cuotas.

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                           MAPA DE REINGENIERÍA INTEGRAL Y ARQUITECTURA OBJETIVO                         │
├───────────────────────────────┬───────────────────────────────┬─────────────────────────────────────────┤
│ 1. MOTOR DE NOMBRAMIENTO      │ 2. CABECERAS Y CLIENTES       │ 3. AUDITORÍA CONTABLE Y REDISEÑO        │
│    REACTIVO (MANUAL / IA)     │    EN COTIZACIÓN MANUAL       │    DEL PDF DE PRÉSTAMO PERSONAL         │
├───────────────────────────────┼───────────────────────────────┼─────────────────────────────────────────┤
│ • QuotationNamingEngine:      │ • Corrección de corte visual  │ • Corrección contable estricta:         │
│   Sincronización bidireccional│   del botón de guardado CRM.  │   Capital Prestado = Total / (1 + r%).  │
│   cliente/colegio/modo.       │ • Reubicación del FAB naranja │ • Nueva fila "Interés Aplicado (r%)".   │
│ • Desvinculación limpia       │   (cero bloqueo a botones).   │ • Eliminación del bloque de totales     │
│   (elimina cliente pegado).   │ • Estilizado elegante de      │   duplicado en pie de recibo.           │
│ • Formato humano inteligente: │   etiquetas InputDecoration.  │ • Corrección tipográfica a:             │
│   Sujeto · Correlativo Legible│ • Sincronización rápida CRM   │   "COMPROBANTE DE PRÉSTAMO".            │
│   (sin códigos #dd-HHmm feos).│   con feedback visual claro.  │ • Migración universal de montos a       │
│ • Botón "Restaurar nombre     │ • Footer migrado a            │   AppCurrency.format(S/ #,##0.00) en el │
│   automático" en 1 toque.     │   AppCurrency.format(...).    │   resumen y las 24 cuotas.              │
└───────────────────────────────┴───────────────────────────────┴─────────────────────────────────────────┘
```

---

## 2. DIAGNÓSTICO FORENSE LÍNEA POR LÍNEA Y ANÁLISIS DE EVIDENCIAS

### 2.1. Bloque 1: Bug Crítico en Nombramiento de Cotizaciones y Pérdida de Reactividad (Capturas 1 y 2)

* **Archivos Involucrados:**
  * `app_movil/lib/features/smart_quotation/screens/manual/manual_quote_data_ext.dart` (Líneas 30–57)
  * `app_movil/lib/features/smart_quotation/screens/manual/manual_quote_client_ext.dart` (Líneas 5–32)
  * `app_movil/lib/features/smart_quotation/providers/smart_quotation_provider.dart` (Líneas 281–307)
  * `app_movil/lib/features/smart_quotation/services/quotation_service.dart` (Líneas 10–35)

* **Evidencia en Capturas 1 y 2:**
  * **Captura 1 (`3.20.37 PM.jpeg`):** Se selecciona al cliente `"Freddy"`, el sistema genera el título `"Freddy #25-1520 (3) - Manual"`.
  * **Captura 2 (`3.20.37 PM (1).jpeg`):** El usuario pulsa `"Desvincular"`. El panel del cliente se limpia correctamente (`Nombre` y `Teléfono` vacíos, sin cliente vinculado), pero el campo `"Nombre / Título de la Cotización"` **se queda congelado con `"Freddy #22-0146 (2) - Manual"`**.
* **Causa Raíz en Código:**
  1. En `manual_quote_data_ext.dart`:
     ```dart
     void _generateDynamicName() async {
       if (_isGeneratingName) return;
       final auth = Provider.of<AuthProvider>(context, listen: false);
       
       bool shouldGenerate = _quoteTitleCtrl.text.isEmpty || 
                             _quoteTitleCtrl.text.startsWith("Cotización") ||
                             _quoteTitleCtrl.text.contains("- Pedido") ||
                             _quoteTitleCtrl.text == "Cliente General";

       if (shouldGenerate) {
           _isGeneratingName = true;
           ...
       }
     }
     ```
     Una vez que la cotización adquiere el nombre `"Freddy #..."`, la condición `shouldGenerate` evalúa **estrictamente a `false`** porque el texto ya no empieza con `"Cotización"`, no tiene `"- Pedido"`, no está vacío ni es `"Cliente General"`.
  2. En `manual_quote_client_ext.dart`:
     ```dart
     void _clearClient() {
       updateState(() {
         _selectedClient = null; _updateClientData = true; 
         _clientNameCtrl.clear(); _clientPhoneCtrl.clear(); _clientDniCtrl.clear();
         _clientAddressCtrl.clear(); _clientEmailCtrl.clear(); _clientNotesCtrl.clear();
         _hasUnsavedChanges = true;
       });
       _generateDynamicName(); // <--- LLAMADA INÚTIL: shouldGenerate es false
     }
     ```
     Al desvincular al cliente, `_clearClient()` llama a `_generateDynamicName()`, la cual aborta de inmediato debido a que `shouldGenerate` es falso. **El nombre del cliente jamás se remueve del título.**
  3. **Problema del Formato `#dd-HHmm`:**
     En `smart_quotation_provider.dart:282`:
     `final timeStr = DateFormat('dd-HHmm').format(DateTime.now());`
     Genera identificadores como `#25-1520` (día 25, 15:20) o `#22-0146` (día 22, 01:46). Este formato resulta incomprensible para el usuario, parece un código de error o lote técnico, y no aprovecha la numeración correlativa real (`numero_secuencial`) ni la información contextual del colegio o grado escolar.
  4. **Problema en Duplicados (`quotation_service.dart:22`):**
     `cloneData['client_name'] = "${cloneData['client_name']} (Copia)";`
     Al duplicar sucesivamente, se generan títulos aberrantes como `"Freddy #25-1520 (3) - Manual (Copia) (Copia)"`.

---

### 2.2. Bloque 2: Pulido de Lógica y Diseño en Cabeceras de Cotización Manual (Capturas 1 y 2)

* **Archivos Involucrados:**
  * `app_movil/lib/features/smart_quotation/widgets/manual/manual_quote_client_header.dart` (Líneas 56–76, 132–174)
  * `app_movil/lib/features/smart_quotation/widgets/manual/manual_quote_headers_section.dart` (Líneas 110–138)
  * `app_movil/lib/features/smart_quotation/screens/manual_quotation_screen.dart` (Líneas 578–588)
  * `app_movil/lib/features/smart_quotation/widgets/manual/manual_quote_footer.dart` (Líneas 42, 115, 130)

* **Evidencias y Diagnóstico:**
  1. **Botón `"Guardar en Mis"` Cortado (Captura 2):**
     * En la Captura 2 se aprecia que al final de la tarjeta de Cliente y Colegio, el botón de guardado en CRM aparece truncado diciendo solo `"Guardar en Mis"`.
     * Causa: En `manual_quote_client_header.dart:134`, se renderiza un `SwitchListTile` con título `"Guardar en Mis Clientes"`. La altura disponible dentro del viewport sin padding inferior compensatorio hace que la segunda línea o el borde inferior quede cortado por el margen de la tarjeta o por la barra fija inferior.
  2. **Colisión del Botón Flotante Naranja `+`:**
     * En `manual_quotation_screen.dart:578-588`:
       ```dart
       floatingActionButton: _items.isNotEmpty 
         ? Padding(
             padding: const EdgeInsets.only(bottom: 85), 
             child: FloatingActionButton(
               onPressed: () => _showCatalogModal(isDark), 
               backgroundColor: isDark ? Colors.orange[400] : Colors.orange[800],
               child: Icon(Icons.add, ...),
             ),
           )
         : null,
       ```
     * El FAB está anclado a `bottom: 85` fijo a la derecha. Cuando el usuario expande las tarjetas superiores de Identificación o Cliente/Colegio, el botón naranja **se posiciona directamente sobre el botón `"Desvincular"` y las flechas de los desplegables de "Más detalles"**, bloqueando los toques e impidiendo la interacción táctil.
  3. **Etiquetas de Campos (`InputDecoration`) Cortando la Línea Superior:**
     * En `manual_quote_headers_section.dart:113` y `manual_quote_client_header.dart:160`, el uso de `labelText` estándar en `TextField` genera hendiduras irregulares en el borde superior en modo oscuro (`borderSide: BorderSide.none` sobre fondos contrastados o `OutlineInputBorder` con padding asimétrico).
  4. **Formato Monetario Antiguo en la Barra Inferior:**
     * En `manual_quote_footer.dart:42`:
       `final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');`
       Imprime `"Ganancia ~3,80 S/"` y `"18,80 S/"`. Viola la directriz del proyecto de usar el estándar oficial `AppCurrency.format(...)` (`S/ 18.80` y `Ganancia ~S/ 3.80`).
  5. **Auditoría de Sincronización CRM (`🔄`):**
     * En `manual_quote_client_header.dart:57`, el icono `Icons.change_circle` azul al lado de "Información de Contacto" simplemente abre el modal de búsqueda `ClientSearchModal`. Si el usuario modifica el teléfono o DNI de un cliente ya vinculado, los cambios no se guardan en el CRM de inmediato, sino solo al guardar la cotización completa. El usuario requiere una vía clara para actualizar o registrar los datos en el CRM con retroalimentación visual confirmatoria.

---

### 2.3. Bloque 3: Auditoría Profunda del Flujo de Cotización Creada con IA (Escáner IA)

* **Archivos Involucrados:**
  * `app_movil/lib/features/smart_quotation/screens/matching_screen.dart` (Líneas 48–110, 248–262, 749–796)
  * `app_movil/lib/features/smart_quotation/providers/matching_provider.dart` (Líneas 331–445)
  * `app_movil/lib/features/smart_quotation/screens/extraction_result_screen.dart` (Líneas 147–165)

* **Diagnóstico Forense:**
  1. **Disociación en la Extracción de Metadatos:**
     * En `extraction_result_screen.dart`, la IA detecta: `institutionName`, `studentName`, `gradeLevel`.
     * Estos se pasan a `MatchingScreen` mediante `ExtractedMetadata`.
     * En `MatchingScreen`, los datos se asignan a `_schoolCtrl`, `_gradeCtrl` y `_clientNameCtrl`.
     * Sin embargo, en `MatchingScreen` **no existe la tarjeta de `"Identificación de Cotización"`**. El usuario no ve qué nombre tendrá la cotización resultante ni puede editarlo durante la revisión del escaneo.
  2. **Falla en la Persistencia de Colegio/Grado vaciados (`matching_provider.dart:351`):**
     ```dart
     if (institutionName != null && institutionName.isNotEmpty) activeState.metadata!.institutionName = institutionName;
     if (gradeLevel != null && gradeLevel.isNotEmpty) activeState.metadata!.gradeLevel = gradeLevel;
     ```
     Si el usuario borra intencionalmente el colegio o grado porque la IA lo detectó de forma errónea, la condición ignora el vaciado y guarda el valor previo extraído.
  3. **Ausencia de Nombramiento Reactivo IA:**
     * `MatchingProvider.saveQuotation` utiliza la misma lógica estática antigua:
       `"$rawClientName #$timeStr ($count) - $typeLabel"`
       Y si no hay cliente, genera `"Cotización IA #16-2134"`, ignorando por completo que en la hoja escolar se detectó la institución y el grado (ej. `"Colegio San Pedro (3° Primaria)"`).

---

### 2.4. Bloque 4: Auditoría Forense y Contable del Comprobante PDF de Préstamo (`COMPROBANTE DE PRESTAMO.pdf`)

* **Archivos Involucrados:**
  * `app_movil/lib/features/smart_quotation/utils/pdf_generator.dart` (Líneas 233, 283–288, 701–732, 734–895)
  * `app_movil/lib/features/smart_quotation/services/client_service.dart` (Líneas 596–617)
  * `app_movil/lib/features/smart_quotation/screens/whatsapp_preview_screen.dart` (Líneas 1000–1007)
  * `app_movil/lib/features/smart_quotation/widgets/history/detail_widgets/detail_status_card.dart` (Líneas 173–204)
  * Archivo analizado: `C:\Users\vjuli\Downloads\COMPROBANTE DE PRESTAMO.pdf` (5,542 bytes, 1 página A4).

* **Inspección Forense del PDF Real:**
  ```
  LIBRERÍA BAZAR LUZAM talara Tel: 976 644 890
  COMPROBANTE DE PRESTAMO  N° #000004  24/10/2026 13:39
  CLIENTE: ANGELLO  Tel: 922836879
  ─────────────────────────────────────────────────────────────
  RESUMEN DE PRÉSTAMO
  Capital Prestado: 1.200,00 S/       <--- [ERROR CONTABLE GRAVE]
  Total a Devolver: 1.200,00 S/       <--- [FALTA FILA DE INTERÉS]
  Monto Abonado: 0,00 S/
  Saldo Pendiente: 1.200,00 S/
  ─────────────────────────────────────────────────────────────
  IMPORTE TOTAL: 1.200,00 S/          <--- [BLOQUE DUPLICADO INÚTIL]
  Monto Abonado: 0,00 S/
  SALDO PENDIENTE: 1.200,00 S/
  ─────────────────────────────────────────────────────────────
  PLAN DE CUOTAS (24 cuotas)
  Cuota 1: 50,00 S/  Vence: 26/10/2026  PENDIENTE
  ...
  Cuota 24: 50,00 S/ Vence: 21/11/2026 PENDIENTE
  ─────────────────────────────────────────────────────────────
  Generado por MochilaLista          Gracias por su preferencia
  ```

* **Causas Raíz Identificadas:**
  1. **Distorsión del Capital Prestado (`pdf_generator.dart:706-708`):**
     ```dart
     final double capital = (saleData['monto_total'] ?? 0.0).toDouble();
     final double interes = (saleData['monto_interes'] ?? 0.0).toDouble();
     final double total = capital + interes;
     ```
     En `client_service.dart:612`, al registrar el préstamo, `monto_total` almacena la deuda total con intereses (`amount + amount * rate / 100`). En `pdf_generator.dart`, el código toma `saleData['monto_total']` creyendo que es el capital inicial, y como `saleData['monto_interes']` no existe en la base de datos (es nulo), asume interés cero y calcula un capital inflado de `1.200,00 S/`.
     *Contraste:* En `detail_status_card.dart:179-183`, la app ya posee la fórmula matemática contable correcta para descomponer el monto:
     `debtBase = debtWithInterest / (1 + (interesRate / 100)); interestAmount = debtWithInterest - debtBase;`
  2. **Omisión de la Fila `"Interés Aplicado"`:**
     Al no calcularse el interés neto en soles a partir de `porcentaje_interes`, la condición `if (interes > 0)` nunca se cumple y el PDF oculta el desglose del costo financiero al prestatario.
  3. **Bloque de Totales Duplicado:**
     En `pdf_generator.dart:283-288`:
     ```dart
     if (isLoan)
       _buildLoanSection(saleData, config, currency, colors, isTicket: false),
     pw.SizedBox(height: isCompact ? 8 : 14),
     _buildTotalsSection(quotation, config, currency, colors, saleData, isTicket: false),
     ```
     `_buildLoanSection` ya imprime el resumen financiero completo del préstamo. Inmediatamente después, `_buildTotalsSection` vuelve a imprimir un `totalsBox` con `IMPORTE TOTAL: 1.200,00 S/`, `Monto Abonado: 0,00 S/` y `SALDO PENDIENTE: 1.200,00 S/`, redundando innecesariamente y saturando la hoja.
  4. **Error Tipográfico en Encabezado:**
     En `whatsapp_preview_screen.dart:1002`, el título se configura como `"COMPROBANTE DE PRESTAMO"` (sin tilde). En visores PDF o al combinarse con fuentes, produce inconsistencias o caracteres erróneos reportados como `"PRESTAMΜΟ"`. Debe normalizarse a `"COMPROBANTE DE PRÉSTAMO"`.
  5. **Formato Monetario Universal:**
     `pdf_generator.dart:201` utiliza `NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ')`, produciendo `1.200,00 S/` y `50,00 S/` con comas decimales y sufijo. Debe adoptar universalmente la salida de `AppCurrency.format(...)` (`S/ 1,200.00` y `S/ 50.00`).

---

## 3. ARQUITECTURA TÉCNICA Y ESPECIFICACIÓN DE DISEÑO

### 3.1. Motor Inteligente y Reactivo de Nombramiento (`QuotationNamingEngine`)

Se creará una clase desacoplada `QuotationNamingEngine` ubicada en `app_movil/lib/features/smart_quotation/services/quotation_naming_engine.dart`.

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                   QUOTATION NAMING ENGINE                                       │
├─────────────────────────────────────────────────────────────────────────────────────────────────┤
│ ENTRADAS REACTIVAS:                                                                             │
│ • selectedClient (ClientModel?)                                                                 │
│ • typedClientName (String)                                                                      │
│ • schoolName (String?)                                                                          │
│ • gradeLevel (String?)                                                                          │
│ • quotationType ('manual' | 'ai_scan' | 'pack')                                                 │
│ • sequentialNumber (int?)                                                                       │
│ • isClone (bool) / isClientRole (bool)                                                          │
├─────────────────────────────────────────────────────────────────────────────────────────────────┤
│ REGLAS DE COMPOSICIÓN HUMANA:                                                                   │
│ 1. Sujeto Principal:                                                                            │
│    - Con cliente: "Freddy"                                                                      │
│    - Con cliente + colegio: "Freddy · San Pedro (3° Prim)"                                      │
│    - Sin cliente, con colegio: "San Pedro (3° Prim)"                                            │
│    - Sin datos: "Cotización"                                                                    │
│ 2. Correlativo / Identificador:                                                                 │
│    - Si tiene número secuencial asignado: "#042"                                                │
│    - Si es nueva en borrador: correlativo proyectado o fecha limpia humana "26 Oct"            │
│    - Si el cliente tiene cotizaciones activas previas: "(Lista 2)" o "(2)"                      │
│ 3. Etiqueta de Origen:                                                                          │
│    - Manual: "[Manual]"                                                                         │
│    - IA Scan: "[IA]"                                                                            │
│    - Pack: "[Pack Escolar]"                                                                     │
│ 4. Modo Clonado / Duplicado:                                                                    │
│    - "Freddy · San Pedro #045 (Copia de #042) [Manual]"                                         │
├─────────────────────────────────────────────────────────────────────────────────────────────────┤
│ GESTIÓN DE ESTADO (AUTO vs MANUAL):                                                             │
│ • isAutoMode = true mientras el texto coincida con una plantilla autogenerada.                  │
│ • Si el usuario teclea su propio texto: isAutoMode = false (se respeta su edición).             │
│ • Botón "🔄 Restaurar nombre automático" aparece como suffixIcon para volver al modo reactivo. │
└─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

#### Reglas de Sincronización Reactiva:
* **Al vincular cliente:** Reemplaza el sujeto por el nombre del cliente y actualiza el correlativo de listas del cliente.
* **Al cambiar cliente por otro:** Sustituye inmediatamente el nombre del cliente anterior por el nuevo cliente, preservando correlativo y origen.
* **Al desvincular cliente (`_clearClient`):** Remueve de inmediato el nombre del cliente y regresa a la combinación `[Colegio / Grado]` o `"Cotización"`, manteniendo intacta la numeración secuencial.
* **Al modificar colegio o grado:** Actualiza el sujeto si no hay cliente (o lo complementa si está en modo auto).

---

### 3.2. Pulido de Diseño en Cabeceras de Cotización Manual

1. **Resolución del Botón `"Guardar en Mis Clientes"` Cortado:**
   * En `manual_quote_client_header.dart`, rediseñar la sección inferior de persistencia CRM.
   * En lugar de un `SwitchListTile` apretado, utilizar un contenedor estilizado con padding generoso (`EdgeInsets.symmetric(horizontal: 16, vertical: 12)`), texto en una sola línea o con salto controlado sin elipsis forzada, y espacio de scroll inferior (`SizedBox(height: 16)`) para que jamás choque contra la barra `TOTAL`.
   * Agregar acción directa de sincronización: si el cliente está vinculado y sus datos se modifican (teléfono, DNI, dirección), mostrar un botón/chip activo: **`"🔄 Actualizar en CRM"`** con feedback visual instantáneo (SnackBar verde y actualización en base de datos sin necesidad de guardar toda la cotización).
2. **Reubicación Ergonómica del Botón Flotante Naranja `+`:**
   * Modificar el `floatingActionButton` en `manual_quotation_screen.dart`.
   * El botón actual `Padding(bottom: 85)` tapa los controles cuando se expanden los acordeones.
   * Se aplicará una de dos soluciones armónicas:
     * **Opción A (Recomendada):** Desplazar el FAB dinámicamente o anclar el botón de "Agregar Producto" dentro del bloque de lista de productos / barra superior, y en la barra inferior dotar de acceso directo rápido.
     * **Opción B:** Configurar `floatingActionButtonLocation: FloatingActionButtonLocation.endFloat` con `bottom: 90` y padding responsivo, ocultando el botón cuando los acordeones superiores estén en edición activa (`_isQuoteDataExpanded || _isClientPanelExpanded`).
3. **Etiquetas `InputDecoration` con Terminación Limpia:**
   * Ajustar todos los `TextField` de las cabeceras (`manual_quote_headers_section.dart` y `manual_quote_client_header.dart`) con:
     * `floatingLabelBehavior: FloatingLabelBehavior.auto`
     * `filled: true` con `fillColor` armonioso (`Color(0xFF14141C)` en dark, `Colors.grey.shade50` en light).
     * `contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16)`.
     * Bordes redondeados `BorderRadius.circular(12)` con `borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300)`.
4. **Estandarización de Moneda en Barra Inferior:**
   * En `manual_quote_footer.dart`:
     * Reemplazar `currency.format(widget.totalAmount)` por `AppCurrency.format(widget.totalAmount)`.
     * Reemplazar `Ganancia ~${currency.format(widget.estimatedProfit)}` por `Ganancia ~${AppCurrency.format(widget.estimatedProfit)}`.

---

### 3.3. Paridad Total en Cotización Escaneada con IA (`MatchingScreen`)

1. **Incorporación de la Cabecera de Identificación de Cotización:**
   * Añadir a `MatchingScreen` un acordeón superior de `"Identificación de Cotización"` idéntico al de la cotización manual, conectado al `QuotationNamingEngine`.
   * El título se inicializará reactivamente a partir de los datos extraídos por la IA (ej. `"Colegio San Pedro (3° Prim) #043 [IA]"` o con el nombre del alumno/cliente si fue detectado en la hoja).
2. **Sincronización Bidireccional de Cliente y Colegio:**
   * Cuando el usuario vincula o crea un cliente en `MatchingScreen`, el título de la cotización IA se actualiza reactivamente al instante.
   * Al guardar (`saveQuotation`), se persiste el título editado o autogenerado, y se guardan fielmente `institution_name` y `grade_level` incluso si fueron modificados o vaciados por el usuario.

---

### 3.4. Reingeniería Contable y Estética del Comprobante PDF de Préstamo

1. **Descomposición Contable Exacta en `pdf_generator.dart`:**
   ```dart
   final double interesRate = (saleData['porcentaje_interes'] ?? 0).toDouble();
   final double totalWithInterest = (saleData['monto_total'] ?? 0.0).toDouble();
   final double abonoInicial = (saleData['abono_inicial'] ?? 0.0).toDouble();
   final double debtWithInterest = totalWithInterest - abonoInicial;
   
   // Verdad contable estricta:
   final double debtBase = (interesRate > 0 && debtWithInterest > 0)
       ? debtWithInterest / (1 + (interesRate / 100))
       : debtWithInterest;
   final double interestAmount = debtWithInterest - debtBase;
   final double capitalNeto = abonoInicial + debtBase;
   final double abonado = (saleData['monto_pagado'] ?? 0.0).toDouble();
   final double saldo = totalWithInterest - abonado > 0 ? totalWithInterest - abonado : 0.0;
   ```
2. **Nueva Fila `"Interés Aplicado"`:**
   ```dart
   _buildPaymentRow("Capital Prestado:", AppCurrency.format(capitalNeto), isTicket: isTicket),
   if (interestAmount > 0.01)
     _buildPaymentRow(
       interesRate > 0 ? "Interés Aplicado (${interesRate.toStringAsFixed(1)}%):" : "Interés Aplicado:",
       "+ ${AppCurrency.format(interestAmount)}",
       valueColor: colors['savings'], // verde o destacado
       isTicket: isTicket,
     ),
   _buildPaymentRow("Total a Devolver:", AppCurrency.format(totalWithInterest), isBold: true, isTicket: isTicket),
   _buildPaymentRow("Monto Abonado:", AppCurrency.format(abonado), isTicket: isTicket),
   _buildPaymentRow("Saldo Pendiente:", AppCurrency.format(saldo), isBold: true, valueColor: saldo > 0 ? colors['debt'] : colors['savings'], isTicket: isTicket),
   ```
3. **Eliminación del Bloque Duplicado de Totales:**
   * En `pdf_generator.dart`: Si `isLoan == true`, `_buildTotalsSection` omitirá por completo la caja `totalsBox` (ya que toda esa información se presentó con precisión en `_buildLoanSection`), y solo renderizará el `cuotasWidget` (`PLAN DE CUOTAS`) si existen cuotas activas.
4. **Normalización del Encabezado del Documento:**
   * En `pdf_generator.dart`, `whatsapp_preview_screen.dart` y `pdf_preview_screen.dart`, unificar el título por defecto a:
     **`"COMPROBANTE DE PRÉSTAMO"`** (con tilde ortográfica en la É y codificación segura).
5. **Estandarización Monetaria Universal:**
   * Reemplazar todas las apariciones de `currency.format(...)` en `pdf_generator.dart` por llamadas a `AppCurrency.format(...)` para asegurar que todo el recibo (resumen, cuota 1 a 24, abonos y saldos) se exprese en el formato estándar `S/ #,##0.00`.

---

## 4. FASES DE IMPLEMENTACIÓN Y METODOLOGÍA DEL LOOP AUTÓNOMO

Bajo nuestra metodología de trabajo autónomo, la ejecución se dividirá en 5 Fases secuenciales con validaciones cruzadas:

```
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│                                   FASES DEL PLAN DE ACCIÓN                                  │
├─────────┬───────────────────────────────────────────────────────────────────────────────────┤
│ FASE 1  │ Creación del Motor de Nombramiento Reactivo (QuotationNamingEngine)               │
│         │ • Desarrollo de la clase de nombramiento desacoplada con soporte de auto/custom.   │
│         │ • Integración en manual_quotation_screen.dart y sus extensiones de datos/cliente. │
│         │ • Implementación del botón "🔄 Restaurar nombre automático" en el TextField.       │
├─────────┼───────────────────────────────────────────────────────────────────────────────────┤
│ FASE 2  │ Pulido de Cabeceras, Choque de FAB y Formato Monetario en Cotización Manual       │
│         │ • Corrección de dimensiones y padding del botón "Guardar en Mis Clientes".        │
│         │ • Reubicación/protección del FAB naranja para evitar colisiones con "Desvincular".│
│         │ • Estilización de etiquetas InputDecoration en tema claro y oscuro.               │
│         │ • Migración universal de manual_quote_footer.dart a AppCurrency.format(...).      │
│         │ • Sincronización ágil al CRM de clientes ya vinculados con confirmación visual.   │
├─────────┼───────────────────────────────────────────────────────────────────────────────────┤
│ FASE 3  │ Auditoría y Paridad en la Ventana de Cotización con IA (MatchingScreen)           │
│         │ • Incorporación de la cabecera de Identificación de Cotización en MatchingScreen. │
│         │ • Conexión reactiva al QuotationNamingEngine al cambiar cliente/colegio.          │
│         │ • Aseguramiento de persistencia en SQLite de metadatos (Institución/Grado).       │
├─────────┼───────────────────────────────────────────────────────────────────────────────────┤
│ FASE 4  │ Reingeniería Contable, Eliminación de Duplicados y Rediseño de PDF de Préstamo    │
│         │ • Corrección de la descomposición matemática de Capital Prestado e Interés en PDF.│
│         │ • Inclusión de la fila "Interés Aplicado (X%)" en el Resumen del Préstamo.        │
│         │ • Eliminación de la caja de totales redundante en pie de página del comprobante.  │
│         │ • Corrección ortográfica ("COMPROBANTE DE PRÉSTAMO") en todos los generadores.    │
│         │ • Estandarización a AppCurrency.format(...) en las 24 cuotas del plan de pagos.   │
├─────────┼───────────────────────────────────────────────────────────────────────────────────┤
│ FASE 5  │ Batería de Pruebas Automatizadas y Arbitraje Adversarial                          │
│         │ • Unit Tests para QuotationNamingEngine (vincular, desvincular, cambiar, custom). │
│         │ • Unit Tests para la matemática del comprobante PDF de préstamo (con y sin tasa). │
│         │ • Verificación visual y pruebas de regresión en cotizaciones y ventas.            │
└─────────┴───────────────────────────────────────────────────────────────────────────────────┘
```

---

## 5. MATRIZ DE CRITERIOS DE ACEPTACIÓN Y ARBITRAJE INTERNO ADVERSARIAL

| # | Requerimiento Crítico | Condición de Fallo (Rechazado por Árbitro) | Condición de Éxito (Aprobado) |
|---|------------------------|--------------------------------------------|-------------------------------|
| **1** | **Desvinculación Reactiva de Cliente** | El título mantiene el nombre del cliente anterior tras pulsar `"Desvincular"`. | El nombre del cliente se elimina de inmediato y el título vuelve a su plantilla base manteniendo el correlativo. |
| **2** | **Sustitución Limpia de Cliente** | Al cambiar de cliente A a cliente B, el título conserva restos del cliente A o altera el correlativo erróneamente. | El nombre de cliente A es sustituido limpiamente por el de cliente B en tiempo real. |
| **3** | **Restauración de Nombre Automático** | Si el usuario editó el título y luego desea volver al modo dinámico, no hay opción disponible. | Un botón `🔄` en el campo restaura la plantilla inteligente con 1 toque. |
| **4** | **Formato Humano de Nombres** | Continúa usando `#dd-HHmm` confuso (ej. `#25-1520`). | Títulos limpios, humanos y legibles con cliente, colegio, correlativo y tipo. |
| **5** | **Botón Guardar en Mis Clientes** | El texto aparece cortado como `"Guardar en Mis"` en dispositivos físicos. | Se muestra completo, con padding holgado y sin cortes en el borde inferior. |
| **6** | **Colisión de FAB Naranja** | El FAB naranja tapa el botón `"Desvincular"` o las flechas de desplegables. | El FAB se ubica sin obstaculizar ningún control táctil de las tarjetas. |
| **7** | **Estandarización Monetaria** | Aparecen montos con comas o sufijo `S/` (`18,80 S/`). | Se utiliza estrictamente `AppCurrency.format(...)` (`S/ 18.80`). |
| **8** | **Paridad en Cotización IA** | `MatchingScreen` no muestra título reactivo o ignora el colegio en el nombre. | Muestra cabecera de título reactiva sincronizada con metadatos de la IA. |
| **9** | **Capital Prestado en PDF** | El comprobante muestra el total con interés en lugar del capital neto entregado. | Muestra estrictamente el capital neto entregado (ej. `S/ 1,000.00`). |
| **10**| **Fila Interés Aplicado en PDF** | No se desglosa el interés ni el porcentaje acordado. | Fila explícita: `Interés Aplicado (20%): + S/ 200.00`. |
| **11**| **Duplicidad de Totales en PDF** | Se imprime dos veces la caja de `IMPORTE TOTAL / SALDO PENDIENTE`. | Estructura única, sin bloques redundantes, limpia y ejecutiva. |
| **12**| **Ortografía del Título PDF** | Dice `"PRESTAMO"` sin tilde o con caracteres extraños. | Dice exactamente `"COMPROBANTE DE PRÉSTAMO"`. |
| **13**| **Moneda en Cuotas PDF** | Las cuotas dicen `50,00 S/`. | Todas las cuotas dicen `S/ 50.00` con `AppCurrency.format(...)`. |

---
*Fin del documento de Plan de Trabajo y Diagnóstico Forense.*
