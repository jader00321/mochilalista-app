# PLAN MAESTRO: UNIVERSALIZACIÓN DEL COTIZADOR IA, MODAL DINÁMICO DE CONFIRMACIÓN, FORMATEO MONETARIO PDF Y PERFECCIONAMIENTO DE WHATSAPP

**Documento:** `analisis_proyecto/PLAN_UNIVERSALIZACION_COTIZADOR_IA_MODAL_CONFIRMACION_PDF_Y_WHATSAPP.md`  
**Estado:** Propuesta Técnica y Arquitectura de Implementación — Pendiente de Aprobación  
**Metodología:** Loop Autónomo + Árbitro Interno Adversarial (Blindaje Multi-Escenario)  
**Módulos Involucrados:**  
* `lib/features/scanner/screens/scan_screen.dart` (Universalización de pantalla de captura y chips de contexto)
* `lib/core/widgets/home/quotation_banner.dart` & `smart_action_grid.dart` (Apertura de textos y desvinculación del sesgo escolar)
* `lib/features/smart_quotation/services/ai_extraction_service.dart` (Prompt multimodal, detección de rubro y extracción omnicanal)
* `lib/features/smart_quotation/models/extracted_list_model.dart` (Modelo de datos ampliado con DTOs de contexto comercial)
* `lib/features/smart_quotation/screens/extraction_result_screen.dart` (Corrección de cortes en AppBar y tarjetas, selector de contexto)
* `lib/features/smart_quotation/widgets/extraction/quotation_confirmation_modal.dart` (Nuevo modal animado interactivo pre-cotización)
* `lib/features/smart_quotation/providers/matching_provider.dart` & `services/matching_service.dart` (Ponderación mayorista vs unidad)
* `lib/features/smart_quotation/screens/matching_screen.dart` (Cabecera adaptativa y acordeón multi-escenario)
* `lib/features/smart_quotation/services/quotation_naming_engine.dart` (Nombramiento inteligente desacoplado de grados escolares)
* `lib/features/smart_quotation/models/smart_quotation_model.dart` (Deduplicación inteligente en `displayNameClean`)
* `lib/features/smart_quotation/utils/pdf_generator.dart` (Corrección de moneda `AppCurrency`, deduplicación y aspect ratio de logo)
* `lib/features/smart_quotation/screens/pdf_preview_screen.dart` (Ampliación de opciones de documento, títulos comerciales y validez)
* `lib/features/smart_quotation/screens/whatsapp_preview_screen.dart` (Estructuración con precios unitarios `c/u` y deduplicación)
* `lib/features/smart_quotation/widgets/whatsapp/wa_message_editor.dart` (Carrusel de 4 plantillas y chips modulares de 1 toque)
* `lib/features/smart_quotation/models/whatsapp_config_model.dart` (Nuevas banderas modulares de visualización)

---

## 1. RESUMEN EJECUTIVO Y ANÁLISIS DE LAS CAPTURAS REALES (IMÁGENES 1 A 5)

Las pruebas de campo con comerciantes y clientes reales revelaron un problema crítico de adopción: el módulo de **Cotización Inteligente** es percibido exclusivamente como una herramienta para *"listas de útiles escolares"*, limitando severamente su uso comercial durante los 12 meses del año. En la práctica, los comerciantes reciben a diario:
1. **Listas de compras variadas** (abarrotes, ferretería, bazar, limpieza, bebidas) para cotizar canastas familiares o comparar precios.
2. **Requerimientos al por mayor (B2B)** de bodegas, pequeños restaurantes o empresas que solicitan cotizaciones de cajas, paquetes, fardos y docenas para evaluar su inversión.
3. **Listas escolares** (en temporada de campaña).

Sumado a este sesgo semántico, se evidenciaron defectos visuales, truncamientos tipográficos en pantallas compactas (`320dp` y `360dp`), ausencia de confirmación antes de emparejar inventario, errores de formato monetario en el PDF (`1,00 S/`), descripciones con palabras redundantes y falta de herramientas ágiles en el editor de WhatsApp.

```
                              FLUJO DEL SISTEMA AUDITADO
┌─────────────────┐     ┌───────────────────┐     ┌───────────────────────┐
│ 1. Escanear     │ ──> │ 2. Datos          │ ──> │ 3. Modal Confirmación │
│    Lista        │     │    Extraídos      │     │    (NUEVO - Fase 3)   │
│ (Captura 1)     │     │ (Captura 2)       │     │    [Unidad / Mayoreo] │
└─────────────────┘     └───────────────────┘     └───────────────────────┘
                                                              │
                                                              ▼
┌─────────────────┐     ┌───────────────────┐     ┌───────────────────────┐
│ 6. Editor       │ <── │ 5. Vista Previa   │ <── │ 4. Cotización         │
│    WhatsApp     │     │    PDF            │     │    Inteligente        │
│ (Captura 5)     │     │ (Captura 4)       │     │ (Captura 3)           │
└─────────────────┘     └───────────────────┘     └───────────────────────┘
```

---

### Radiografía Forense de las 5 Capturas Reales

#### Captura 1 (`11.59.32 AM (1).jpeg`) — Pantalla `Escanear Lista`
* **Defecto Detectado:** El subtítulo indica textualmente: *"Toma una foto clara y bien iluminada de la lista de útiles escolares."* Esto repele a comerciantes que desean escanear una lista de abarrotes o una proforma de ferretería.
* **Carencia Visual:** No existen indicadores de los diferentes tipos de listas soportadas ni guía rápida para pedidos al por mayor o requerimientos familiares.

#### Captura 2 (`11.59.31 AM.jpeg`) — Pantalla `Datos Extraídos`
* **Truncamiento Crítico en AppBar:** El título superior dice `"Datos Extraíd"` (cortado) y el subtítulo dice `"15 productos ide..."` (truncado), debido a que el botón `COTIZAR (15/15)` consume más del 50% del ancho del `AppBar` en pantallas de `360dp`.
* **Cortes en Filas de Datos:**
  * En cada tarjeta (`Fila #1`, `Fila #2`), el campo de cantidad se lee como **`"Ca..."`** en vez de `"Cant."`.
  * El campo de marca se corta diciendo **`"Marca..."`** con un icono que consume espacio horizontal innecesario.
  * En la tarjeta superior de metadata, los textos se cortan: `"Alumno/a (..."` y `"7° Básico a 4"`.
* **Sesgo de Campos Fijos:** La tarjeta muestra fijos los campos `🎓 Institución Educativa (Colegio)`, `Alumno/a` y `Grado/Sección`, desconcertando al comerciante si escaneó una lista de abarrotes o un pedido mayorista.
* **Salto Abrupto:** Al pulsar `COTIZAR (15/15)`, la app navega de inmediato a `MatchingScreen` sin confirmar cuántos ítems válidos hay ni qué política de precios priorizar (unidad vs cajas/bultos).

#### Captura 3 (`11.59.32 AM (2).jpeg`) — Pantalla `Cotización Inteligente`
* **Acordeón Rígido:** El segundo acordeón se titula rígidamente **`"🎓 Datos del Cliente y Colegio"`**, independientemente de si los productos son bebidas o víveres.
* **Inyección Incoherente en el Título:** El generador automático de títulos (`QuotationNamingEngine`) inyecta `"Cotización (7° Básico a 4° |"`, asociando grados escolares a cotizaciones comerciales estándar.

#### Captura 4 (`12.00.49 PM.jpeg`) — Pantalla `Vista Previa PDF`
* **Bug Crítico de Formato de Moneda:** En la tabla del PDF, las columnas `Unit.` y `Total` muestran: **`1,00 S/`** y **`2,00 S/`** (símbolo al final y coma decimal), mientras que en la parte inferior dice **`IMPORTE TOTAL: S/ 5.00`** (símbolo adelante y punto decimal). Hay una flagrante incoherencia tipográfica y contable.
* **Palabras y Marcas Duplicadas:**
  * Fila 1: `"Agua Sin Gas PET 500ML San carlos Sin Gas 500ml x 20 Transparente"` (repite *"Sin Gas 500ml"* dos veces).
  * Fila 2: `"Gaseosa concordia PET 355ML Concordia Cultura 355ml x 15"` (repite *"Concordia"* y *"355ml"* dos veces).
  * Fila 3: `"Gaseosa concordia Fresa PET 355ML Concordia Fresa 355ml x 15"`.
* **Deformación de Logo:** El contenedor de logo de 68x68 distorsiona las proporciones originales si el logo no es estrictamente cuadrado.
* **Opciones del PDF Limitadas:** El modal `OPCIONES` no ofrece alternar rápidamente entre títulos comerciales (`COTIZACIÓN`, `PROFORMA COMERCIAL`, `PRESUPUESTO MAYORISTA`, `COTIZACIÓN ESCOLAR`) ni adaptar los datos del encabezado al contexto del pedido.

#### Captura 5 (`12.00.49 PM (1).jpeg`) — Pantalla `Editor WhatsApp`
* **Nombres Repetitivos sin Precio Unitario:** Imprime líneas largas con duplicación de tokens (`▪ 2x Agua Sin Gas PET 500ML San carlos Sin Gas 500ml x 20 Transparente -> *S/ 2.00*`), sin indicar el precio unitario (`S/ 1.00 c/u`).
* **Falta de Plantillas por Escenario y Chips Modulares:** El editor carece de selectores contextuales (`General`, `Mayorista`, `Resumen Rápido`, `Escolar`) y requiere edición manual para prender o apagar bloques clave (precios unitarios, empaque, datos de facturación/RUC, validez de oferta y medios de pago).

---

## 2. DIAGNÓSTICO TÉCNICO Y CAUSAS RAÍCES EN CÓDIGO FUENTE

### 2.1 Sesgo Escolar en Captura e IA
* **`app_movil/lib/features/scanner/screens/scan_screen.dart` (Líneas 286-287, 480-499):**
  ```dart
  // Línea 286
  final String subtitle = isQuotation
      ? "Toma una foto clara y bien iluminada de la lista de útiles escolares."
      : "Sube tu factura de compra para procesar y reponer el stock.";
  ```
  Textos duros que restringen mentalmente el caso de uso.
* **`app_movil/lib/features/smart_quotation/services/ai_extraction_service.dart` (Líneas 166-211):**
  El prompt del sistema (`_buildListExtractionPrompt()`) instruye textualmente:
  ```
  Actúa como un experto en digitalización de listas de útiles escolares en librerías y papelerías...
  METADATA: Busca nombre de la institución educativa o colegio, nombre del alumno/estudiante y grado o sección.
  ```
  El esquema JSON de salida solo contempla `institution_name`, `student_name`, `grade_level`. No permite capturar nombres de negocios, números de RUC, notas generales ni autodetectar el tipo de pedido.
* **`app_movil/lib/core/widgets/home/quotation_banner.dart` (Líneas 18-20, 48) & `smart_action_grid.dart` (Línea 289):**
  Textos como *"cierra ventas de listas escolares"* y *"Tienes una lista escolar procesada sin guardar"*.

### 2.2 Truncamientos y Desbordes en `extraction_result_screen.dart`
* **AppBar Rígido (Líneas 119-142):**
  ```dart
  appBar: AppBar(
    title: Column(
      children: [
        SizedBox(width: double.infinity, child: MarqueeText(text: isClient ? ... : "Validar Datos Extraídos")),
        Text("${provider.items.length} productos identificados"),
      ],
    ),
    actions: [
      Flexible(child: Padding(child: FittedBox(child: FilledButton.icon(...))))
    ],
  )
  ```
  En un AppBar de Flutter, las acciones (`actions`) no se restringen automáticamente por `Flexible` sin límites explícitos. `FilledButton.icon` con texto largo (`COTIZAR (15/15)`) roba más del 50% de la pantalla, dejando al título con menos de 140dp, forzando la elipsis: `"Datos Extraíd"`.
* **Corte en Campo `"Cant."` (`"Ca..."`) y `"Marca..."` (Líneas 528-565):**
  ```dart
  Row(
    children: [
      Expanded(flex: 2, child: _buildTextField(controller: _qtyCtrl, label: "Cant.", isNumber: true)),
      const SizedBox(width: 12),
      Expanded(flex: 3, child: _buildTextField(controller: _unitCtrl, label: "Unidad")),
      const SizedBox(width: 12),
      Expanded(flex: 4, child: _buildTextField(controller: _brandCtrl, label: "Marca (Opcional)", icon: Icons.branding_watermark)),
    ]
  )
  ```
  En `360dp`, `flex: 2` otorga un ancho neto aproximado de ~66dp. Como `_buildTextField` aplica `contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)`, se consumen 32dp solo en márgenes internos, dejando escasos 34dp para el texto de la etiqueta `"Cant."`, lo que obliga a Flutter a truncar a `"Ca..."`. Del mismo modo, en `flex: 4` (~130dp), la presencia del icono prefijo (24dp) más 32dp de padding deja el espacio insuficiente para `"Marca (Opcional)"`, cortando a `"Marca..."`.
* **Persistencia del Teclado:** Ningún `TextField` cuenta con `onTapOutside: (_) => FocusScope.of(context).unfocus()`, provocando que el teclado virtual tape las filas inferiores al editar.

### 2.3 Ausencia de Modal de Confirmación y Estrategia de Precios
* **Navegación Inmediata (Líneas 143-168 de `extraction_result_screen.dart`):**
  Al presionar el botón `COTIZAR`, se ejecuta directamente `Navigator.push(...)` hacia `MatchingScreen`. No se ofrece al comerciante revisar un resumen del lote ni definir si las búsquedas en catálogo deben privilegiar presentaciones minoristas (unidades) o presentaciones mayoristas (cajas, paquetes, fardos).

### 2.4 Error de Formato Monetario (`1,00 S/`) y Duplicidad en PDF
* **`app_movil/lib/features/smart_quotation/utils/pdf_generator.dart` (Líneas 253, 767-780 vs 824-1021):**
  ```dart
  // Línea 253
  final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
  ...
  // Líneas 767-780 (Celdas de la tabla de productos)
  pw.Text(currency.format(item.unitPriceApplied)...) // Produce: "1,00 S/"
  pw.Text(currency.format(item.quantity * item.unitPriceApplied)...) // Produce: "2,00 S/"
  ...
  // Línea 1021 (Pie de totales)
  pw.Text(AppCurrency.format(finalTotal)...) // Produce: "S/ 5.00"
  ```
  La clase `AppCurrency` (`app_movil/lib/core/utils/currency_formatter.dart`) utiliza el patrón explícito `'S/ #,##0.00'`. Sin embargo, las celdas de la tabla usaban la instancia local de `NumberFormat.currency(locale: 'es_PE')`, la cual por convención regional coloca el símbolo al final y coma decimal.
* **Duplicación en `displayName` (`smart_quotation_model.dart`, Líneas 227-242):**
  ```dart
  String get displayName {
    final buffer = StringBuffer();
    if (productName != null) buffer.write(productName);
    if (brandName != null && brandName != "null") buffer.write(" $brandName");
    if (specificName != null) buffer.write(" $specificName");
    return buffer.toString().trim();
  }
  ```
  Si `productName` ya contiene `"Agua Sin Gas PET 500ML"`, `brandName` contiene `"San Carlos"` y `specificName` contiene `"Sin Gas 500ml x 20 Transparente"`, la concatenación ciega repite los términos `"Sin Gas"`, `"500ml"` y marcas comerciales.

### 2.5 Carencias en `whatsapp_preview_screen.dart` y `wa_message_editor.dart`
* **Líneas 510-535 de `whatsapp_preview_screen.dart`:**
  El bucle de generación inyecta directamente `item.displayName` sin sanitización de tokens repetidos y solo concatena `lineTotal`, omitiendo el precio unitario (`c/u`) cuando la cantidad es superior a 1.
* **`wa_message_editor.dart` (Líneas 109-265):**
  Los estilos actuales están enfocados en tonos de cobranza/comercial, pero no ofrecen un selector superior por caso de negocio (`General`, `Mayorista`, `Rápido`, `Escolar`) ni botones modulares directos para encender/apagar el desglose de precios unitarios o datos de cliente.

---

## 3. PLAN MAESTRO DE TRABAJO POR FASES (FASES 1 A 5)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ FASE 1: Universalización Escáner IA, Detección de Rubro y Contexto          │
│ ├── Rediseño de Escanear Lista con chips de escenarios comerciales          │
│ ├── Prompt y parser IA omnicanal (Unidades y Mayoreo)                       │
│ └── Cabecera adaptativa en Datos Extraídos y Cotización Inteligente         │
└─────────────────────────────────────┬───────────────────────────────────────┘
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ FASE 2: Eliminación de Cortes de Texto y Responsividad (320dp y 360dp)      │
│ ├── Reingeniería del AppBar (titleSpacing, FittedBox y botón compacto)      │
│ ├── Rebalanceo de Flex y paddings en filas ("Cant.", "Marca")               │
│ └── Desvanecimiento de teclado con onTapOutside en todos los campos         │
└─────────────────────────────────────┬───────────────────────────────────────┘
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ FASE 3: Nuevo Modal de Confirmación Animado en Botón COTIZAR (X/Y)          │
│ ├── Modal animado con ScaleTransition + FadeTransition                      │
│ ├── Resumen de lote (X de Y válidos) y advertencia de ítems en 0           │
│ └── Selector de Enfoque de Precios (🏷️ Menudeo vs 📦 Mayorista)            │
└─────────────────────────────────────┬───────────────────────────────────────┘
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ FASE 4: Corrección de Moneda (S/ X.XX), Deduplicación en PDF y WhatsApp     │
│ ├── Formato estricto AppCurrency.format(...) en todas las celdas PDF        │
│ ├── Formateador inteligente de nombres sin tokens repetidos                 │
│ ├── Logo PDF con relación de aspecto contenida y opciones avanzadas         │
│ └── WhatsApp: Precios unitarios (c/u), carrusel y chips modulares           │
└─────────────────────────────────────┬───────────────────────────────────────┘
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│ FASE 5: Responsividad Universal, Modo Oscuro/Claro y Calidad Cero Regresiones│
│ ├── Pruebas 320dp/360dp sin desbordes (RenderFlex = 0)                      │
│ ├── Modo Oscuro impecable con .withValues(alpha: ...)                       │
│ └── flutter analyze con 0 errores, 0 warnings y 0 infos                     │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

### FASE 1: Universalización del Escáner IA y Adaptabilidad Multipropósito (`Pedido General`, `Mayorista / Negocio` y `Lista Escolar`)

#### 1.1 Modelo de Datos Contextual (`extracted_list_model.dart`)
* Se define el enum oficial de modos de cotización:
  ```dart
  enum QuotationContextMode {
    general,   // 🛒 Pedido de compras variado / canasta / ferretería / abarrotes
    wholesale, // 📦 Pedido al por mayor / Negocio / Bodega / B2B
    school,    // 🎓 Lista escolar de útiles
  }
  ```
* Se amplía `ExtractedMetadata` para incluir atributos comerciales universales:
  ```dart
  class ExtractedMetadata {
    QuotationContextMode contextMode;
    String? clientOrContactName;  // Cliente, Apoderado o Contacto comercial
    String? businessOrInstitutionName; // Negocio/Empresa/RUC o Colegio
    String? phone;                // Teléfono de contacto
    String? referenceNotes;       // Notas, grado o referencia del pedido
    // Compatibilidad retroactiva garantizada:
    String? get institutionName => businessOrInstitutionName;
    String? get studentName => clientOrContactName;
    String? get gradeLevel => referenceNotes;
  }
  ```

#### 1.2 Rediseño Inclusivo de `ScanScreen` (`scan_screen.dart`)
* **Archivo:** `app_movil/lib/features/scanner/screens/scan_screen.dart` (Líneas 280-335, 480-500).
* **Cambios:**
  * Actualizar el subtítulo de la pantalla a:
    *"Toma una foto clara de cualquier lista de compras, pedido al por mayor, requerimiento de negocio o lista escolar."*
  * Incorporar un carrusel interactivo de chips informativos mostrando los 3 escenarios soportados:
    * `🛒 Lista de Compras / Pedido`
    * `📦 Pedido al por Mayor / Negocio`
    * `🎓 Lista Escolar`
  * Ajustar los mensajes de progreso dinámicos del `ScanningDialog` para que digan:
    *"Leyendo productos, marcas, empaques y presentaciones requeridas..."* y *"Estructurando pedido con máxima precisión..."*.
* **Banner de Home y Acciones Rápidas:**
  * `quotation_banner.dart` (Línea 19): Subtítulo actualizado a: *"Administra cotizaciones, verifica stock y cierra ventas de cualquier tipo de lista o pedido."*
  * `smart_action_grid.dart` (Línea 289): Texto de reanudación: *"Tienes una lista o pedido procesado sin guardar."*

#### 1.3 Adaptación del Prompt y Parser IA (`ai_extraction_service.dart`)
* **Archivo:** `app_movil/lib/features/smart_quotation/services/ai_extraction_service.dart` (Líneas 166-211).
* **Instrucciones Renovadas al Agente Gemini:**
  ```
  Actúa como un experto en digitalización y procesamiento de listas comerciales, pedidos de compras, órdenes al por mayor para negocios/bodegas y listas de útiles escolares.
  Analiza la imagen proporcionada y extrae la información en JSON puro.

  1. AUTODETECCIÓN DE TIPO:
     - "detected_mode": Evalúa el contenido y clasifica en "general", "wholesale" o "school".
       * "wholesale": Si contiene cajas, bultos, paquetes, docenas, fardos, cantidades altas o datos de negocio/empresa.
       * "school": Si contiene cuadernos, útiles, menciones a colegios, alumnos o grados escolares.
       * "general": Si es una lista de compras cotidiana de hogar, abarrotes, bazar o ferretería.

  2. METADATA:
     - "contact_name": Nombre de la persona, cliente o alumno identificado.
     - "organization_name": Nombre de la empresa, bodega o institución educativa.
     - "phone": Teléfono si está manuscrito o impreso.
     - "reference_info": Grado escolar, notas o referencia de la compra.

  3. ÍTEMS (Cualquier Rubro Comercial):
     - "full_name": Nombre limpio del producto sin duplicar la marca ni empaques secundarios.
     - "brand": Marca explícita si se menciona.
     - "quantity": Número entero o decimal. Si no se indica, asumir 1.
     - "unit": Presentación normalizada (unidad, caja, paquete, docena, fardo, bolsa, kilo, lata, botella, pack).
     - "notes": Colores, medidas, tamaños o detalles adicionales.
  ```

#### 1.4 Cabecera Contextual Adaptativa en `extraction_result_screen.dart`
* **Selector Rápido de Modo de Cotización (1 Toque):**
  En la parte superior de `Datos Extraídos`, se presenta un selector segmentado con diseño fluido (`AnimatedContainer`):
  1. `🛒 Pedido General`: Muestra `Cliente / Solicitante`, `Teléfono / WhatsApp`, `Nota / Referencia`.
  2. `📦 Mayorista / Negocio`: Muestra `Contacto / Cliente`, `Negocio / Empresa / RUC`, `Teléfono / WhatsApp`.
  3. `🎓 Lista Escolar`: Muestra `Alumno/a o Apoderado`, `Institución Educativa (Colegio)`, `Grado / Nivel`.
* El cambio de modo realiza una transición suave (`AnimatedSize`) modificando al instante los labels, hints e iconos sin perder la información digitada.

#### 1.5 Adaptación en `Cotización Inteligente` (`matching_screen.dart` y `quotation_naming_engine.dart`)
* **Acordeón Dinámico:**
  En `matching_screen.dart` (Línea 915), el título e icono del acordeón cambian dinámicamente según el modo activo:
  * Si es General: `"Datos del Cliente y Pedido"` (`Icons.shopping_bag_outlined`).
  * Si es Mayorista: `"Datos del Cliente y Negocio"` (`Icons.storefront_rounded`).
  * Si es Escolar: `"Datos del Cliente y Colegio"` (`Icons.school_outlined`).
* **Botón Mágico de Título (`✨`):**
  `QuotationNamingEngine.generateTitle` recibirá el parámetro `contextMode`. Si el modo es `general` o `wholesale`, **no inyectará colegios ni grados escolares** en el título de la cotización, produciendo encabezados limpios como:
  * `Bodega San José · Pedido Mayorista · 12 Nov [IA]`
  * `Juan Pérez · Pedido · 12 Nov [IA]`
  * `Juan · San Pedro (3° Prim) · 12 Nov [IA]`

---

### FASE 2: Corrección de Cortes de Texto y Responsividad en `Datos Extraídos` (`320dp` y `360dp`)

#### 2.1 Reingeniería del AppBar en `extraction_result_screen.dart`
* **Archivo:** `app_movil/lib/features/smart_quotation/screens/extraction_result_screen.dart` (Líneas 119-182).
* **Solución de Layout:**
  * Fijar `titleSpacing: 8.0` para maximizar el área útil del título.
  * Encapsular el bloque de título en `FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft)` con tamaño tipográfico base de `17sp` para que `"Datos Extraídos"` y `"${provider.items.length} productos identificados"` nunca sufran elipsis ni cortes.
  * Rediseñar el botón de acción a un formato compacto pero prominente:
    * Padding horizontal reducido: `EdgeInsets.symmetric(horizontal: 10, vertical: 6)`.
    * Icono `Icons.check_circle_rounded` de `16dp`.
    * Texto: `COTIZAR ($readyCount/$totalCount)`.
    * Ancho restringido a un máximo de `125dp`, garantizando que en un ancho de pantalla de `320dp` el título disponga de al menos `150dp` libres.

#### 2.2 Rebalanceo de Campos en Tarjetas de Filas (`_InternalItemCard`)
* **Archivo:** `app_movil/lib/features/smart_quotation/screens/extraction_result_screen.dart` (Líneas 528-565).
* **Corrección de Proporciones:**
  * **Campo Cantidad (`_qtyCtrl`):** Cambiar de `flex: 2` a `flex: 3`, reduciendo el `contentPadding` a `EdgeInsets.symmetric(horizontal: 8, vertical: 10)`. Esto garantiza que `"Cant."` se lea siempre completo sin convertirse en `"Ca..."`.
  * **Campo Unidad (`_unitCtrl`):** Mantener en `flex: 4` con label `"Unidad"`.
  * **Campo Marca (`_brandCtrl`):** Asignar `flex: 5`, simplificar label a `"Marca"` (en lugar de `"Marca (Opcional)"`), y remover el icono prefijo innecesario que consumía 32dp.
  * **Control de Foco Global:** Agregar a todos los `TextField` de la tarjeta:
    ```dart
    onTapOutside: (_) => FocusScope.of(context).unfocus(),
    ```
    permitiendo cerrar el teclado virtual de inmediato al tocar cualquier área fuera del campo.

#### 2.3 Responsividad en Tarjeta de Metadata
* En pantallas angostas (`< 360dp`), el layout de dos columnas de los campos inferiores de metadata se convertirá dinámicamente en un diseño apilado vertical o con paddings ultracompactos, evitando que `"Alumno/a (..."` y `"7° Básico a 4"` se trunquen.

---

### FASE 3: Nuevo Modal de Confirmación Dinámico y Animado en el Botón `COTIZAR (X/Y)`

#### 3.1 Diseño e Interacción del Componente
* **Nuevo Archivo:** `app_movil/lib/features/smart_quotation/widgets/extraction/quotation_confirmation_modal.dart`.
* **Disparador:** Al pulsar `COTIZAR (X/Y)` en `Datos Extraídos`, se interrumpe la navegación directa y se despliega este modal con animación fluida:
  * `ScaleTransition` (de 0.90 a 1.0) combinada con `FadeTransition` bajo curva `Curves.easeOutCubic`.
  * Feedback háptico ligero (`HapticFeedback.mediumImpact()`).

```
┌────────────────────────────────────────────────────────┐
│               ⚡ GENERAR COTIZACIÓN                     │
│                                                        │
│   ┌────────────────────────────────────────────────┐   │
│   │  ✓ Vas a cotizar 15 de 15 productos extraídos  │   │
│   │    Todos los ítems cuentan con cantidad válida │   │
│   └────────────────────────────────────────────────┘   │
│                                                        │
│   ¿Cómo deseas buscar las coincidencias en stock?     │
│                                                        │
│   ┌────────────────────────────────────────────────┐   │
│   │ (•) 🏷️ Precio Público / Menudeo                │   │
│   │     Prioriza unidades individuales y precios   │   │
│   │     de lista al detalle.                       │   │
│   ├────────────────────────────────────────────────┤   │
│   │ ( ) 📦 Priorizar Mayorista / Cajas / Paquetes  │   │
│   │     Prioriza presentaciones por volumen y      │   │
│   │     precios de fardos, cajas y docenas.        │   │
│   └────────────────────────────────────────────────┘   │
│                                                        │
│   ℹ El sistema vinculará automáticamente tus productos │
│     y calculará los mejores precios de tu inventario.  │
│                                                        │
│   [ Seguir Revisando ]     [ Sí, Generar Cotización → ]│
└────────────────────────────────────────────────────────┘
```

#### 3.2 Elementos y Lógica del Modal
1. **Resumen Visual del Lote:**
   * Badge superior de estado:
     * Si `validItems == totalItems`: Badge verde con check: *"Vas a cotizar todos los 15 productos identificados."*
     * Si `validItems < totalItems`: Badge ámbar de advertencia: *"Vas a cotizar X de Y productos. Dejaste (Y - X) ítems sin nombre o con cantidad 0."*
2. **Selector de Enfoque de Precios y Presentaciones (1 Toque):**
   * **`🏷️ Precio Público / Menudeo`** (Seleccionado por defecto en modo General y Escolar): Pondera presentaciones unitarias (`unidad`, `pieza`, `frasco`).
   * **`📦 Priorizar Mayorista / Cajas / Paquetes`** (Seleccionado por defecto en modo Mayorista): Pondera presentaciones por volumen (`caja`, `paquete`, `pack`, `docena`, `fardo`).
3. **Acciones:**
   * Botón secundario: `[Seguir Revisando]` (Cierra el modal y mantiene al usuario en `Datos Extraídos`).
   * Botón primario: `[Sí, Generar Cotización →]` (Ejecuta la navegación a `MatchingScreen` pasando la estrategia seleccionada).

#### 3.3 Integración con el Motor de Emparejamiento (`MatchingService.dart`)
* En `MatchingService.runBatchMatching`, se agrega el parámetro booleano `prioritizeWholesale`:
  * Cuando `prioritizeWholesale == true`, al evaluar los resultados de la base de datos SQLite, aquellas presentaciones cuyo `nombreEspecifico` o `unidadVenta` contenga términos como `caja`, `pack`, `pqte`, `docena`, `fardo`, `x 12`, `x 24` reciben un bono de ponderación (`+30 puntos de score`).
  * De esta forma, la IA selecciona automáticamente la presentación en caja o paquete del catálogo sin que el comerciante tenga que cambiar variante por variante manualmente.

---

### FASE 4: Corrección de Moneda (`1,00 S/`), Deduplicador Inteligente de Nombres y Mejoras en PDF y WhatsApp

#### 4.1 Corrección Integral de Moneda en `pdf_generator.dart`
* **Archivo:** `app_movil/lib/features/smart_quotation/utils/pdf_generator.dart` (Líneas 253, 765-785).
* **Solución Técnica:**
  * Eliminar la variable local `final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');`.
  * Estandarizar **el 100% de las celdas de precios y subtotales** con la llamada oficial:
    ```dart
    AppCurrency.format(item.unitPriceApplied)
    AppCurrency.format(item.quantity * item.unitPriceApplied)
    ```
  * Resultado garantizado en A4 y Ticket 80mm: **`S/ 1.00`**, **`S/ 2.00`**, coincidiendo matemáticamente y estéticamente con el pie de página **`IMPORTE TOTAL: S/ 5.00`**.

#### 4.2 Deduplicador Inteligente de Nombres (`displayNameClean`)
* **Archivo:** `app_movil/lib/features/smart_quotation/models/smart_quotation_model.dart` (Línea 227).
* **Algoritmo de Normalización y Limpieza de Tokens:**
  Crear el getter `displayNameClean` (y helper reusable `ProductDisplayFormatter`):
  1. Si `productName` ya contiene la marca (ej. `"Gaseosa concordia"` ya tiene `"Concordia"`), la marca no se concatena de nuevo.
  2. Si `specificName` repite palabras ya presentes en `productName` (ej. `"Sin Gas"`, `"500ml"`, `"Concordia"`), dichos tokens se filtran de forma no sensible a mayúsculas.
  3. Formateo limpio de empaques: Si la variante contiene multiplicadores (ej. `x 20 Transparente`), se formatea elegantemente entre paréntesis:
     * De: `"Agua Sin Gas PET 500ML San carlos Sin Gas 500ml x 20 Transparente"`
     * A: `"Agua Sin Gas PET 500ML (San Carlos • x20 Transparente)"`
     * De: `"Gaseosa concordia PET 355ML Concordia Cultura 355ml x 15"`
     * A: `"Gaseosa Concordia PET 355ML (Cultura • x15)"`
* Este getter se consumirá de manera uniforme tanto en la tabla del PDF como en las líneas del mensaje de WhatsApp.

#### 4.3 Cabecera de Logo sin Deformación y Modal `OPCIONES` en PDF
* **Logo con Aspect Ratio Protegido (`pdf_generator.dart`, Líneas 510-524):**
  * Ajustar el contenedor del logo con `pw.FittedBox(fit: pw.BoxFit.contain)` y restricciones proporcionales para evitar estiramientos horizontales o verticales.
* **Ampliación de Opciones en `pdf_preview_screen.dart` (Líneas 908-928):**
  * Agregar chips directos para títulos de documento:
    * `COTIZACIÓN`
    * `PROFORMA COMERCIAL`
    * `PRESUPUESTO MAYORISTA`
    * `COTIZACIÓN ESCOLAR`
  * Permitir desde el modal ocultar o mostrar condicionalmente:
    * Columna de Precio Unitario y Subtotal.
    * Bloque de Descuento/Ahorro Total.
    * Validez formal de la cotización (`3 días`, `7 días`, `15 días`, `30 días`).
    * Datos contextuales (mostrar RUC de la empresa del cliente o colegio solo si aplica).

#### 4.4 Perfeccionamiento y Modularidad en `Editor WhatsApp` (`whatsapp_preview_screen.dart` y `wa_message_editor.dart`)
* **Precios Unitarios (`c/u`) en Mensaje:**
  En `whatsapp_preview_screen.dart` (Líneas 515-535), cuando `item.quantity > 1` (y según la configuración activa), la línea se generará como:
  ```
  ▪ 2x Agua Sin Gas PET 500ML (San Carlos • x20) — S/ 1.00 c/u -> *S/ 2.00*
  ```
* **Carrusel Superior de 4 Plantillas por Escenario (1 Toque):**
  1. `🛒 Estándar / Pedido`: Detalle ordenado, subtotales y saludo formal de compra.
  2. `📦 Mayorista / Negocio`: Destaca empaques, cajas, precio unitario por volumen y datos de facturación.
  3. `⚡ Resumen Rápido`: Mensaje ultraconciso con conteo total de ítems y monto final a pagar.
  4. `🎓 Lista Escolar`: Enfocado en útiles escolares, notas de marca sugerida y tiempos de atención.
* **Barra de Chips Modulares de Contenido Rápido:**
  Chips de encendido/apagado instantáneo (con icono de check `✓`):
  * `[✓ Precios Unitarios (c/u)]`
  * `[✓ Marca / Empaque]`
  * `[✓ Datos del Cliente / RUC]`
  * `[✓ Validez de Oferta]`
  * `[✓ Medios de Pago]`
* Botones de acción rápida:
  * `[🔄 Restaurar]` a la plantilla original sin perder datos.
  * `[📋 Copiar]` mensaje al portapapeles con confirmación visual.
  * `onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus()` en el contenedor del editor.

---

### FASE 5: Responsividad Universal (`320dp` / `360dp`), Modo Claro / Oscuro y Validación sin Falsos Positivos

* **Garantía Cero Overflow (`RenderFlex overflowed = 0`):**
  * Auditoría exhaustiva en viewports de `320 x 568` (iPhone SE 1ra gen), `360 x 640` (gama de entrada Android) y `412 x 915` (pantallas modernas).
  * Todos los textos y columnas envueltos con `Flexible`, `Expanded` o `FittedBox` con límites mínimos legibles.
* **Paleta Cromática y Modo Oscuro:**
  * Uso riguroso de `Color.withValues(alpha: ...)` eliminando cualquier mención de `withOpacity(...)`.
  * Contrastes WCAG AAA: Superficies oscuras `Color(0xFF14141C)` y `Color(0xFF23232F)`, textos claros con opacidad mínima del 85% para lectura nítida bajo luz solar.
* **Integridad de Compilación:**
  * Ejecución de `flutter analyze` exigiendo **0 errores, 0 warnings y 0 infos**.
  * Blindaje offline: Funcionamiento 100% operativo sin conexión a internet (Local-First en SQLite).

---

## 4. MATRIZ DEL ÁRBITRO INTERNO ADVERSARIAL (DESAFÍOS EXTREMOS Y CONTRAMEDIDAS)

A continuación, se documenta la evaluación crítica del sistema sometido a estrés comercial:

| # | Escenario Adversarial / Caso Extremo | Riesgo Identificado | Contramedida de Blindaje Implementada |
|---|---|---|---|
| **A1** | La lista escaneada mezcla ítems unitarios (1 tajador) con ítems al por mayor (10 cajas de leche). | La IA podría sesgar toda la cotización a un solo extremo, cotizando unidades cuando se pedían cajas o viceversa. | El prompt de IA extrae la unidad explícita de cada línea (`unidad`, `caja x24`). En el emparejamiento, el sistema prioriza la presentación que coincida con la unidad del ítem individualmente, y solo usa la estrategia global como criterio de desempate. |
| **A2** | La imagen es borrosa o un comprobante atípico y la IA no detecta el modo de cotización (`detected_mode == null`). | Crash al deserializar o pantalla en blanco en `Datos Extraídos`. | Fallback seguro a `QuotationContextMode.general`. Los campos se inicializan con valores por defecto y el selector superior permite al usuario cambiar a `Mayorista` o `Escolar` en 1 toque. |
| **A3** | El comerciante cambia de modo en `Datos Extraídos` tras haber digitado datos (ej. pasa de Escolar a Mayorista). | Pérdida de los datos digitados en los controladores de texto. | Los campos de entrada comparten un modelo de respaldo unificado (`clientOrContactName`, `businessOrInstitutionName`). Al conmutar de modo, los textos se preservan intactos, solo cambia la etiqueta visual y el icono. |
| **A4** | Un producto legítimamente tiene palabras repetidas en su marca comercial (ej. `"Coca-Cola Zero Azúcar Coca-Cola"`). | El deduplicador de nombres podría amputar erróneamente partes del nombre comercial. | La deduplicación se realiza por segmentos estructurales: compara `productName` contra `brandName` y `specificName`. No realiza un `Set<String>` indiscriminado sobre el string completo, respetando nombres de marca duplicados legítimos. |
| **A5** | El usuario selecciona `Priorizar Mayorista`, pero el inventario solo tiene presentaciones unitarias de dicho producto. | El producto quedaría sin vincular (`Tocar para vincular`) dando una falsa impresión de stock cero. | Si no existe una presentación mayorista en stock, el algoritmo de `MatchingService` retrocede automáticamente a la mejor presentación unitaria disponible (fallback gradual con advertencia visual de empaque alternativo). |
| **A6** | Dispositivo ultra angosto (`320dp`) con escalado de fuente del sistema al 130%. | El nuevo modal de confirmación o el AppBar de `Datos Extraídos` desborda vertical u horizontalmente. | El modal se construye dentro de un `SingleChildScrollView` con límites proporcionales `BoxConstraints(maxHeight: screenHeight * 0.85)` y paddings simétricos de 12dp. Las filas de botones usan `Flex` adaptativo. |
| **A7** | Exportación de PDF de una cotización antigua creada antes de esta refactorización. | Discrepancia en campos que esperaban metadata escolar en la base de datos SQLite. | Getters retrocompatibles en `ExtractedMetadata` y `SmartQuotationModel`. La lectura de SQLite mapea transparentemente `colegio` a `businessOrInstitutionName` sin requerir migraciones destructivas de base de datos. |

---

## 5. MATRIZ DE ARCHIVOS, IMPACTO Y LÍNEAS AFECTADAS

| Archivo | Rol en la Solución | Líneas Estimadas | Nivel de Impacto |
|---|---|---|---|
| `app_movil/lib/features/scanner/screens/scan_screen.dart` | Subtítulo inclusivo, chips interactivos de escenarios | 280-335, 480-500 | Medio |
| `app_movil/lib/core/widgets/home/quotation_banner.dart` | Eliminación de sesgo escolar en Home | 18-22, 48 | Bajo |
| `app_movil/lib/core/widgets/home/smart_action_grid.dart` | Texto universal de reanudación de lista | 285-300 | Bajo |
| `app_movil/lib/features/smart_quotation/models/extracted_list_model.dart` | Enum `QuotationContextMode`, metadata ampliada | 1-55 | Medio |
| `app_movil/lib/features/smart_quotation/services/ai_extraction_service.dart` | Prompt omnicanal y detección de rubro comercial | 166-211 | Alto |
| `app_movil/lib/features/smart_quotation/screens/extraction_result_screen.dart` | AppBar responsivo, selector de modo, corrección `"Ca..."` y `"Marca"` | 119-182, 328-375, 528-565 | Crítico |
| `app_movil/lib/features/smart_quotation/widgets/extraction/quotation_confirmation_modal.dart` | **Nuevo Modal:** Confirmación animada y estrategia de precios | Creación nueva (~250 líneas) | Crítico |
| `app_movil/lib/features/smart_quotation/services/matching_service.dart` | Scoring con bono mayorista en presentaciones | 45-185 | Alto |
| `app_movil/lib/features/smart_quotation/providers/matching_provider.dart` | Propagación de estrategia mayorista y metadata contextual | 140-197 | Medio |
| `app_movil/lib/features/smart_quotation/screens/matching_screen.dart` | Acordeón contextual dinámico y orquestación | 50-100, 915-950 | Alto |
| `app_movil/lib/features/smart_quotation/services/quotation_naming_engine.dart` | Generación de títulos comerciales desacoplados de grados | 20-130 | Medio |
| `app_movil/lib/features/smart_quotation/models/smart_quotation_model.dart` | Getter `displayNameClean` con deduplicación inteligente | 227-243 | Alto |
| `app_movil/lib/features/smart_quotation/utils/pdf_generator.dart` | Corrección moneda `AppCurrency`, logo contain, descripciones limpias | 253, 510-524, 720-785 | Crítico |
| `app_movil/lib/features/smart_quotation/screens/pdf_preview_screen.dart` | Chips de títulos comerciales y opciones ampliadas | 905-930, 1550-1610 | Medio |
| `app_movil/lib/features/smart_quotation/screens/whatsapp_preview_screen.dart` | Inyección de `c/u`, carrusel de 4 plantillas y chips modulares | 510-540, 850-935 | Alto |
| `app_movil/lib/features/smart_quotation/widgets/whatsapp/wa_message_editor.dart` | Interfaz de carrusel por escenario y snippets modulares | 100-300 | Alto |
| `app_movil/lib/features/smart_quotation/models/whatsapp_config_model.dart` | Nuevos flags de configuración (`showUnitPrices`, `contextTemplate`) | 1-150 | Medio |

---

## 6. PROTOCOLO DE VERIFICACIÓN Y PRUEBAS ADVERSARIALES POST-EJECUCIÓN

Una vez aprobada y ejecutada la implementación, se correrá el siguiente protocolo exhaustivo de verificación:

### 1. Pruebas de Interfaz y Responsividad (320dp y 360dp)
* Cargar una lista con 15 productos en un emulador o simulador configurado en `320 x 568` y verificar:
  * El AppBar de `Datos Extraídos` muestra `"Datos Extraídos"` y `"15 identificados"` sin cortes ni elipsis.
  * El botón `COTIZAR (15/15)` es completamente legible y operable.
  * Todas las tarjetas muestran `"Cant."` completo, sin truncarse a `"Ca..."`.
  * El campo `"Marca"` se muestra limpio sin elipsis `"Marca..."`.
  * Al tocar fuera de cualquier `TextField`, el teclado se oculta instantáneamente.

### 2. Prueba del Modal de Confirmación Animado
* Presionar `COTIZAR (15/15)`. Verificar:
  * Despliegue con animación fluida `ScaleTransition` + `FadeTransition` sin tartamudeos ni saltos.
  * Resumen del lote indicando 15 productos.
  * Conmutar entre `🏷️ Precio Público / Menudeo` y `📦 Priorizar Mayorista / Cajas / Paquetes`.
  * Confirmar que al presionar `[Seguir Revisando]` el modal se cierra y el usuario permanece en `Datos Extraídos`.
  * Confirmar que al presionar `[Sí, Generar Cotización →]` se navega a `Cotización Inteligente` aplicando la estrategia elegida.

### 3. Prueba de Adaptabilidad Multi-Escenario
* Simular o escanear una lista de abarrotes mayorista:
  * Verificar que el acordeón de `Cotización Inteligente` se titula `"Datos del Cliente y Negocio"`.
  * Verificar que el botón mágico `✨` genera un título comercial formal (ej. `Bodega San José · Pedido Mayorista · 12 Nov [IA]`), **sin ninguna mención de grados ni colegios**.

### 4. Prueba de Fidelidad en PDF (A4 y Ticket 80mm)
* Abrir `Vista Previa PDF` y verificar:
  * Todas las celdas de precios unitarios y subtotales muestran estrictamente formato peruano estándar: **`S/ 1.00`**, **`S/ 2.00`** (nunca `1,00 S/`).
  * Las descripciones de productos muestran nombres limpios sin tokens repetidos (ej. `"Agua Sin Gas PET 500ML (San Carlos • x20)"`, sin duplicar `"Sin Gas"` ni `"500ml"`).
  * El logo comercial en la esquina superior izquierda mantiene su aspecto sin deformación (`BoxFit.contain`).
  * En el modal `OPCIONES`, seleccionar `PROFORMA COMERCIAL` y `PRESUPUESTO MAYORISTA`, verificando que el encabezado del PDF cambia en tiempo real.

### 5. Prueba de Personalización en Editor de WhatsApp
* Abrir `Editor WhatsApp` y verificar:
  * Cada producto con cantidad `> 1` muestra el precio unitario desglose: `▪ 2x Producto — S/ 1.00 c/u -> *S/ 2.00*`.
  * Alternar entre las plantillas del carrusel (`🛒 Estándar`, `📦 Mayorista`, `⚡ Resumen`, `🎓 Escolar`) y comprobar que el texto se reconfigura fielmente.
  * Probar los chips modulares (`Precios Unitarios`, `Medios de Pago`, `Validez`, `Marca / Empaque`) y verificar la adición/eliminación inmediata.
  * Probar botones `[🔄 Restaurar]` y `[📋 Copiar]`.

### 6. Verificación de Código y Calidad Estática
* Ejecutar:
  ```powershell
  flutter analyze
  ```
  Exigiendo **0 errores, 0 warnings y 0 infos**.

---

## 7. CRONOGRAMA DE EJECUCIÓN SECUENCIAL (PASO A PASO)

Tras la revisión y aprobación por parte del usuario, la ejecución se realizará en el siguiente orden secuencial y controlado:

```
[Paso 1: Modelos y Servicios IA/Matching]
  ├── Extensión de extracted_list_model.dart (QuotationContextMode y DTOs)
  ├── Actualización del prompt y parser en ai_extraction_service.dart
  └── Lógica de bonificación mayorista en matching_service.dart y matching_provider.dart

[Paso 2: Universalización de Pantallas de Entrada y Banner]
  ├── scan_screen.dart (subtítulo universal y chips informativos de escenarios)
  └── quotation_banner.dart y smart_action_grid.dart (textos omnicanal)

[Paso 3: Responsividad y Corrección de Cortes en Datos Extraídos]
  ├── extraction_result_screen.dart (AppBar titleSpacing, FittedBox y botón compacto)
  ├── Rebalanceo de Flex y padding en _InternalItemCard ("Cant." y "Marca")
  └── Selector de contexto comercial en cabecera con AnimatedSwitcher

[Paso 4: Construcción del Modal de Confirmación Animado]
  ├── quotation_confirmation_modal.dart (Scale + Fade, resumen de lote y selector de estrategia)
  └── Cableado en botón COTIZAR (X/Y) de extraction_result_screen.dart

[Paso 5: Adaptabilidad en Cotización Inteligente]
  ├── matching_screen.dart (Acordeón contextual dinámico según el modo)
  └── quotation_naming_engine.dart (Generador de títulos sin grados escolares en modo general/b2b)

[Paso 6: Deduplicador de Nombres y Formato de Moneda en PDF]
  ├── smart_quotation_model.dart (Implementación de displayNameClean)
  ├── pdf_generator.dart (Estandarización estricta con AppCurrency.format)
  ├── Corrección de aspect ratio de logo en cabecera PDF
  └── pdf_preview_screen.dart (Nuevas opciones de títulos comerciales y visibilidad)

[Paso 7: WhatsApp con Precios Unitarios y Modularidad]
  ├── whatsapp_preview_screen.dart (Inyección de S/ X.XX c/u y nombres limpios)
  ├── wa_message_editor.dart (Carrusel de 4 plantillas y chips modulares)
  └── whatsapp_config_model.dart (Nuevos flags de configuración)

[Paso 8: Pruebas Adversariales, Responsive Check y Compilación]
  ├── Verificación 320dp y 360dp sin desbordes
  ├── Modo Claro y Modo Oscuro (.withValues(alpha: ...))
  └── flutter analyze (0 errores, 0 warnings, 0 infos)
```

