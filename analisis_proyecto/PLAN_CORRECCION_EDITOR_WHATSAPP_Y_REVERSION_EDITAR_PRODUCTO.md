# PLAN MAESTRO: REINGENIERÍA DEL SISTEMA DE CHIPS Y ENUNCIADO ADAPTATIVO EN EDITOR WHATSAPP Y CORRECCIÓN PROFUNDA DE REVERSIÓN (UNDO) EN EDITAR PRODUCTO

**Documento:** `analisis_proyecto/PLAN_CORRECCION_EDITOR_WHATSAPP_Y_REVERSION_EDITAR_PRODUCTO.md`  
**Fecha:** 6 de Noviembre de 2026  
**Versión:** 1.0 — Especificación Técnica Definitiva (Mobile Awards Quality)  
**Estado:** Esperando Aprobación de Plan de Trabajo (Paso 1: Diagnóstico Forense y Arquitectura de Solución)  
**Metodología:** Loop Autónomo + Árbitro Interno Adversarial (Zero-Regressions, Zero-Unicode-Emojis, Order-Agnostic Chip Toggles, Complete Undo Restoration)

---

## 1. RESUMEN EJECUTIVO Y OBJETIVOS ESTRATÉGICOS

### 1.1. Contexto y Diagnóstico Forense de los 3 Problemas Críticos
A partir de las pruebas exhaustivas en vivo y las **5 capturas de pantalla reales** aportadas por el comerciante, se han diagnosticado 3 problemas críticos de lógica, reactividad y preservación de estado:

1. **Bug Crítico al Desactivar Chips y Duplicación de Líneas en Cuentas Bancarias (`Captura 1: 7.35.44 PM.jpeg`):**
   * **Evidencia en Captura 1:** Al interactuar con la sección `Cuentas Bancarias / Yape / Plin`, teniendo activos `BCP` y `CCI`, al tocar `CCI` para desactivarlo, en vez de eliminarse se duplica en el campo de texto:
     ```text
     BCP Soles:
     CCI Interbancario:
     CCI Interbancario:
     ```
   * Además, se observa que la única forma en que el sistema permitía borrarlos era desactivando estrictamente en el mismo orden de inserción (primero el primero, luego el segundo).
   * **Doble Check Redundante:** En la Captura 1 y 2, los chips activos muestran a la vez el icono `Icons.check_circle` y el carácter `"✓"` dentro del texto (`"✓ BCP"`, `"✓ CCI"`, `"✓ Yape"`), produciendo una redundancia visual antiestética.
   * **Objetivo Estratégico 1:** Reingeniería completa del parser de líneas de medios de pago. Independizar la detección, activación y desactivación de chips del orden de inserción. Eliminar duplicaciones al 100%. Incorporar **memoria temporal de sesión** para que, si el usuario desactiva por error una cuenta que ya tenía un número digitado (ej. `BCP Soles: 191-12345678`), al volver a presionar `+ BCP` se restaure el número escrito en lugar de la etiqueta vacía. Retirar el `"✓"` redundante del texto y aplicar micro-animaciones fluidas (`AnimatedContainer` + `AnimatedSwitcher`).

2. **Falsos Positivos de "Modificado" y Enunciado Estático en Perfil de Negocio (`Captura 2: 7.35.43 PM (1).jpeg`):**
   * **Evidencia en Captura 2:** En la tarjeta `"Guardar estos cambios en el perfil de mi negocio"`, tras editar un dato y regresarlo manualmente a su estado original (o desactivar el chip que se acababa de tocar), el badge amarillo `[Modificado]` permanece encendido como si hubiera diferencias pendientes.
   * **Texto Estático Ineficiente:** El subtítulo siempre muestra el párrafo genérico largo: *"Actualiza tu teléfono, RUC, dirección y cuentas de pago como predeterminados para futuras cotizaciones."*, desperdiciando espacio vertical valioso en pantalla móvil.
   * **Objetivo Estratégico 2:** Comparación reactiva normalizada en tiempo real entre los valores actuales de los controladores (`Teléfono`, `RUC`, `Dirección` y `Cuentas de pago`) frente a los valores baseline del negocio. Si los valores vuelven a coincidir con el perfil original, ocultar automáticamente el badge `[Modificado]` y desmarcar la casilla de actualización. Reemplazar el texto estático por un **enunciado adaptativo y ultra-conciso** que informe con precisión qué campos cambiarán (ej. *"Se actualizará en tu perfil: Teléfono."* o *"Se actualizarán en tu perfil: Teléfono y Cuentas de pago."*), y cuando no haya cambios: *"Tus datos coinciden con el perfil actual de tu negocio."*.

3. **Fallo Catastrófico del Botón Deshacer (`Undo`) en `Editar Producto` (`Capturas 3, 4 y 5`):**
   * **Evidencia en Captura 3 (`7.35.43 PM (2).jpeg` — Estado Original):** El producto está en modo **`Mixto`**, con `Stock Base Actual: 66 und`, `+ Ingreso (Nuevas): 0 und`, `= Stock Final: 66 und`, `Costo Base Unitario: S/ 2.00`. Abajo, el cuadro azul `Stock Final Calculado por Variante` muestra las 2 variantes compartidas:
     * `Principal (Par x2): 2 disp. (de 33 máx.)`
     * `Caja (½ Docena x6): 11 disp.`
   * **Evidencia en Captura 4 (`7.35.43 PM (3).jpeg` — Modificación):** Se ingresan `50 und` en `+ Ingreso (Nuevas)`, elevando `= Stock Final` a `116 und`. Los cálculos por variante suben a 58 máx. y 19 disp. Aparece el botón amarillo de deshacer (`Icons.undo_rounded`) en el AppBar.
   * **Evidencia en Captura 5 (`7.35.43 PM (4).jpeg` — Ejecución de Undo):** Al pulsar el botón de deshacer:
     1. `+ Ingreso (Nuevas)` **NO se revierte a 0 und** (se queda congelado en `50 und` y el final en `116 und`).
     2. **Se corrompe la configuración de variantes:** Todas las variantes compartidas pierden su bandera `usaStockCompartido` y pasan a modo `Independiente` (`Stock Propio`). Como resultado, el cuadro azul `Stock Final Calculado por Variante` **desaparece de la vista**.
   * **Objetivo Estratégico 3:** Diagnosticar la cadena de snapshots en `ProductEditSnapshot`, `ProductEditOperations`, `ProductStockStrategySelector` y `ProductControllerFactory`. Garantizar que `ProductEditSnapshot` capture el 100% de la configuración de stock (`modoStock`, `costoBase`, `stockBase`, `stockIngreso`, `usaStockCompartido`, `cupoMaximoVariante`, `savedPropioSnapshot`, `savedCompartidoSnapshot`). Al presionar deshacer o restaurar, devolver intacta la pantalla a su estado original (ingreso en 0, variantes en modo compartido, cuadro azul visible y stock final en 66 und), ocultando de inmediato el botón de deshacer.

---

### 1.2. Principios y Metodología: Loop Autónomo + Árbitro Interno Adversarial
* **Fase 1 (Análisis y Planificación — Estado Actual):** Diagnóstico línea por línea de las causas raíces en el código fuente, especificación de arquitecturas y diagramas de flujo. **Cero modificaciones de archivos de lógica hasta aprobación.**
* **Fase 2 (Ejecución Atómica):** Modificación quirúrgica y modular de los componentes involucrados sin alterar flujos no relacionados.
* **Árbitro Interno Adversarial (Criterios de Aceptación Inflexibles):**
  1. *Regla de Chips Independientes:* Los 5 chips (`Yape`, `Plin`, `BCP`, `BBVA`, `CCI`) pueden activarse o desactivarse en cualquier orden sin generar líneas duplicadas ni líneas en blanco residuales.
  2. *Memoria de Números de Cuenta:* Si se retira un chip con número de cuenta y se vuelve a encender en la misma sesión, se restaura dicho número.
  3. *Reversión Cero Falsos Positivos en Negocio:* Si los campos coinciden con el perfil original, `hasBusinessChanges == false`, el badge `[Modificado]` desaparece y el checkbox se desactiva.
  4. *Fidelidad Total de Deshacer en Edición:* El botón de deshacer debe restaurar `+ Ingreso` a 0, recalcular el stock final exactamente a 66 und, conservar `usaStockCompartido: true` en todas las variantes correspondientes y ocultarse si el estado actual es idéntico al inicial.

---

## 2. DIAGNÓSTICO FORENSE EN CÓDIGO (ARCHIVOS Y LÍNEAS EXACTAS)

### 2.1. Bloque 1: Chips de Pago y Duplicación en `wa_business_section.dart`
* **Archivo:** `app_movil/lib/features/smart_quotation/widgets/whatsapp/wa_business_section.dart`
* **Causa Raíz de Duplicación (L33 – L58):**
  ```dart
  void _togglePaymentMethod({
    required String defaultSnippet,
    required RegExp linePattern,
    bool placeCursorAtEnd = false,
  }) {
    String currentText = paymentCtrl.text.replaceAll(RegExp(r'[📱🏦🏛️]\s*'), '');
    final bool isPresent = linePattern.hasMatch(currentText); // ⚠️ ERROR CRÍTICO
  ```
  Los patrones pasados en las líneas 173, 189, 202, 216, 230 son del estilo:
  `RegExp(r'^\s*CCI(?:\s*Interbancario)?\s*:?[^\n]*', caseSensitive: false)`
  En Dart, `^` evalúa **únicamente el inicio absoluto del String** a menos que se configure explícitamente `multiLine: true`. Cuando el usuario tiene en la primera línea `BCP Soles:` y en la segunda `CCI Interbancario:`, `linePattern.hasMatch(currentText)` devuelve **`false`** para `CCI` porque `currentText` no empieza con `CCI`. Al dar `false`, el código asume que `CCI` no está presente y ejecuta la rama `else`:
  ```dart
  lines.add(defaultSnippet); // ⚠️ Inserta un segundo "CCI Interbancario:"
  ```
  Esto explica por qué la única forma en que funcionaba era borrando los chips estrictamente en orden LIFO/FIFO desde la primera línea.

* **Causa Raíz de Desalineación entre Detección de Activo y Remoción (L68 – L72 vs L173 – L230):**
  * Para marcar visualmente el chip activo se usa `RegExp(r'\bCCI\b', caseSensitive: false).hasMatch(cleanPaymentText)`. Esta expresión sí encuentra `CCI` en cualquier línea, por lo que el chip se muestra activo (`[✓ CCI]`).
  * Sin embargo, al pulsar el chip activo para apagarlo, `_togglePaymentMethod` usa el regex con ancla `^` sin multilínea, concluye que no existe y lo añade de nuevo.

* **Causa Raíz de Doble Check Redundante (L355 – L368):**
  ```dart
  Icon(
    isActive ? Icons.check_circle_rounded : icon,
    size: 14,
    color: isActive ? ... : ...,
  ),
  const SizedBox(width: 5),
  Text(
    isActive ? "✓ $label" : "+ $label", // ⚠️ ERROR: Muestra "✓" teniendo ya check_circle_rounded
  ```
  Esto produce la redundancia visual: `[ (✓) ✓ BCP ]`.

* **Causa Raíz de Pérdida de Números Digitados:**
  `WaBusinessSection` es un `StatelessWidget` que no mantiene ningún diccionario o mapa de memoria temporal de los números digitados por el usuario. Al desactivar un chip, la línea se desecha por completo; al reactivarlo, siempre se inyecta el `defaultSnippet` genérico vacío (`"BCP Soles: "`).

---

### 2.2. Bloque 2: Detección de Cambios y Enunciado Adaptativo en `whatsapp_preview_screen.dart` y `wa_business_section.dart`
* **Archivo:** `app_movil/lib/features/smart_quotation/screens/whatsapp_preview_screen.dart`
* **Causa Raíz de Falsos Positivos de "Modificado" (L723 – L730):**
  ```dart
  final bool hasBusinessChanges = (biz != null) && (
    _bizAddressCtrl.text != (biz.address ?? "") ||
    _bizRucCtrl.text != (biz.ruc ?? "") ||
    _bizPhoneCtrl.text != userPhone ||
    _bizPaymentCtrl.text != (biz.paymentInfo ?? "") || // ⚠️ Discrepancia de inicialización y formateo
    _bizLat != biz.latitud ||
    _bizLng != biz.longitud
  );
  ```
  1. **Discrepancia en inicialización (L227):**
     `_bizPaymentCtrl.text = biz.paymentInfo ?? "BCP: 000-000...\nYape: 999...";`
     Si en la base de datos `biz.paymentInfo` es `null` o vacío, `_bizPaymentCtrl.text` se carga con el placeholder de ejemplo. Pero en L727 se compara contra `(biz.paymentInfo ?? "")` (cadena vacía), marcando `hasBusinessChanges = true` desde el primer milisegundo sin que el usuario haya tocado nada.
  2. **Falta de normalización de cadenas:**
     Comparaciones estrictas `!=` fallan ante diferencias sutiles como saltos de línea Windows (`\r\n`) vs Unix (`\n`), espacios finales en blanco o líneas vacías generadas por los toggles.
  3. **Ausencia de reseteo automático de `updateBusinessData`:**
     Cuando el usuario regresa los datos a los valores originales, `_config.updateBusinessData` permanece con el valor booleano previo en vez de desactivarse automáticamente.

* **Causa Raíz de Enunciado Estático (L297 – L307 de `wa_business_section.dart`):**
  El subtítulo de la tarjeta `Guardar estos cambios en el perfil de mi negocio` está completamente hardcodeado:
  ```dart
  subtitle: Padding(
    padding: const EdgeInsets.only(top: 4.0),
    child: Text(
      "Actualiza tu teléfono, RUC, dirección y cuentas de pago como predeterminados para futuras cotizaciones.",
  ```
  No existe ninguna reactividad que analice cuáles campos han cambiado realmente.

---

### 2.3. Bloque 3: Reversión / Undo Catastrófica en `Editar Producto`
* **Archivos Involucrados:**
  1. `app_movil/lib/features/catalog/widgets/edit/product_edit/product_edit_snapshot.dart`
  2. `app_movil/lib/features/catalog/screens/product_edit_screen.dart`
  3. `app_movil/lib/features/catalog/widgets/edit/product_edit/product_edit_change_detector.dart`
  4. `app_movil/lib/features/catalog/widgets/form/product_stock_strategy_selector.dart`
  5. `app_movil/lib/features/catalog/widgets/form/product_controller_factory.dart`

* **Causa Raíz de Amnesia en `PresentationSnapshot` (L6 – L109 de `product_edit_snapshot.dart`):**
  `PresentationSnapshot` almacena campos como `id`, `dbId`, `specific`, `precioVenta`, `stockFinal`, pero **omite por completo los siguientes campos críticos:**
  * `usaStockCompartido` (booleano que define si la variante descuenta del inventario base o propio).
  * `cupoMaximoVariante` (límite máximo físico asignado a la variante).
  * `savedPropioSnapshot` (mapa con los valores guardados de la variante en modo independiente).
  * `savedCompartidoSnapshot` (mapa con los valores guardados de la variante en modo compartido).
  * `stockBaseOriginal`, `costoBaseOriginal`, `costoBaseUnitario`.
  Al no capturarse en el snapshot, en `isIdenticalTo` (L111 – L166) nunca se comparan.

* **Causa Raíz de Amnesia en `ProductEditSnapshot` (L171 – L233 de `product_edit_snapshot.dart`):**
  `ProductEditSnapshot` almacena cabecera del producto (`name`, `desc`, `barcode`, `categoryId`, `brandId`, `generalProviderId`, `presentations`), pero **ignora por completo los campos de la estrategia de stock:**
  * `modoStock` (cadena: `'COMPARTIDO'`, `'INDEPENDIENTE'`, `'MIXTO'`).
  * `baseCost` (costo base unitario del producto).
  * `stockCompartido` (stock base total).
  * `stockIngreso` (unidades de nuevo ingreso digitadas en el selector).

* **Causa Raíz de la Destrucción del Modo Compartido al Ejecutar Undo (`restoreInto`, L283 – L331 de `product_edit_snapshot.dart`):**
  Cuando se presiona el botón de regresar, `_applySnapshot` invoca `snapshot.restoreInto(...)`. Esta función destruye los controladores existentes y llama a:
  ```dart
  final newMap = ProductControllerFactory.createNewControllerMap(
    id: keyId,
    dbId: p.dbId,
    isDefault: p.isDefault,
    isExpanded: p.isDefault,
    isEditMode: true,
    specificName: p.specific,
    ...
  );
  ```
  **¡No le pasa `usaStockCompartido`!**  
  En `ProductControllerFactory.createNewControllerMap` (L62 de `product_controller_factory.dart`):
  `bool usaStockCompartido = false,`
  Por consiguiente, **todas las variantes reconstruidas renacen con `usaStockCompartido = false`**.  
  Al forzarlas a falsas, en modo `Mixto`, ninguna variante es compartida.

* **Causa Raíz de la Desaparición del Cuadro Azul "Stock Final Calculado por Variante" (L723 – L730 de `product_stock_strategy_selector.dart`):**
  ```dart
  final sharedItems = widget.controllers!.where((c) {
    if (widget.selectedStrategy == 'COMPARTIDO') return true;
    if (widget.selectedStrategy == 'MIXTO') return c['usaStockCompartido'] == true;
    return false;
  }).toList();

  if (sharedItems.isEmpty) return const SizedBox.shrink(); // ⚠️ Se oculta porque no hay variantes compartidas
  ```
  Al haber reseteado `usaStockCompartido` a `false` en todas las variantes, `sharedItems.isEmpty` es `true`, haciendo que el widget retorne `SizedBox.shrink()` y se esfume de la pantalla.

* **Causa Raíz de la Congelación de `+ Ingreso (Nuevas)` en 50 und (L410 – L450 de `product_edit_screen.dart`):**
  En `_applySnapshot`:
  1. No se toca `_sharedIngresoCtrl`. Sigue teniendo `"50"`.
  2. No se toca `_sharedStockCtrl`. Sigue teniendo `"116"`.
  3. No se restaura `_modoStock` ni `_baseCostCtrl`.
  El usuario ve que el campo de ingreso se quedó en 50 und y el stock final en 116 und, mientras las variantes se rompieron.

---

## 3. ARQUITECTURA DE LA SOLUCIÓN Y DISEÑO TÉCNICO DETALLADO

```
                                  ARQUITECTURA DE FLUJO INTEGRAL
                                  
   ===================================================================================================
   1. EDITOR WHATSAPP: SISTEMA DE CHIPS INTELIGENTES (ORDER-AGNOSTIC + SESSION MEMORY)
   ===================================================================================================
   [ Tap Chip: BCP / CCI / Yape ] 
               │
               ▼
   [ PaymentChipParser.matchesLine(line) ]  ──► Identificación precisa por prefijo canónico de línea
               │
      ¿Activo en alguna línea?
         ├── SÍ (Desactivar):
         │      ├── Extraer texto completo de la línea y guardar en `_sessionPaymentMemory[chipType]`
         │      ├── Remover todas las líneas coincidentes
         │      └── Sanitizar saltos de línea (cero líneas vacías huérfanas)
         └── NO (Activar):
                ├── ¿Existe en `_sessionPaymentMemory[chipType]`?
                │      ├── SÍ ──► Inyectar línea previamente guardada con su número digitado
                │      └── NO ──► Inyectar `defaultSnippet` canónico
                └── Anexar limpiamente al final del `TextField`
               │
               ▼
   [ UI Micro-animada ]: Icono `check_circle` (sin "✓" en texto) + AnimatedContainer fluido

   ===================================================================================================
   2. PERFIL DE NEGOCIO: DETECCIÓN INTELIGENTE DE CAMBIOS REALES Y ENUNCIADO DINÁMICO
   ===================================================================================================
   Baseline Original: [ Phone, RUC, Address, Normalized PaymentInfo ]
               │  (Comparación normalizada en tiempo real mediante trim, clean-lines & regex)
               ▼
   Diferencias encontradas:
         ├── Ninguna ([]) ──► hasBusinessChanges = false
         │                    ├── Badge [Modificado] OCULTO
         │                    ├── Checkbox 'Guardar en perfil': DESMARCADO Y DESACTIVADO
         │                    └── Subtítulo: "Tus datos coinciden con el perfil actual de tu negocio."
         └── 1 o más ([Campos]) ──► hasBusinessChanges = true
                              ├── Badge [Modificado] VISIBLE
                              └── Subtítulo Adaptativo: "Se actualizará en tu perfil: Teléfono." 
                                  o "Se actualizarán en tu perfil: Teléfono y Cuentas de pago."

   ===================================================================================================
   3. EDITAR PRODUCTO: REVERSIÓN TOTAL (UNDO) Y PRESERVACIÓN FIDEDIGNA DE VARIANTES
   ===================================================================================================
   ProductEditSnapshot (Inmutable)
         ├── Datos Generales: Name, Desc, Img, Barcode, Category, Brand, Provider, State, IdsToDelete
         ├── Estrategia Global: modoStock, baseCost, stockCompartido, stockIngreso (¡NUEVOS!)
         └── PresentationSnapshot:
                 ├── Identificadores y Textos: id, dbId, specific, unidad, factor, precio, costo, margen...
                 ├── Estrategia de Variante: usaStockCompartido, cupoMaximoVariante (¡PRESERVADOS!)
                 └── Cachés de Modo: savedPropioSnapshot, savedCompartidoSnapshot (¡PRESERVADOS!)
               │
      [ Tap Botón Deshacer (Undo) / Restaurar ]
               │
               ▼
   [ _applySnapshot ]
         ├── Restaura: _modoStock, _baseCostCtrl, _sharedStockCtrl, _sharedIngresoCtrl.text = "0"
         ├── Restaura cada variante con `usaStockCompartido: true/false` exacto
         ├── Reconstruye `savedPropioSnapshot` y `savedCompartidoSnapshot`
         ├── Dispara recálculo síncrono en `ProductStockStrategySelector`
         └── ¿Estado actual == Inicial? ──► SÍ: Oculta automáticamente el botón de Deshacer
```

---

### 3.1. Especificación Técnica: Chips de Medios de Pago (`wa_business_section.dart`)
1. **Enum Canónico `PaymentChipType`:**
   ```dart
   enum PaymentChipType {
     yape(
       label: "Yape",
       icon: Icons.phone_android_rounded,
       color: Color(0xFF732282),
       prefixPattern: r'^\s*Yape(?:\s*Soles)?\s*:?',
     ),
     plin(
       label: "Plin",
       icon: Icons.smartphone_rounded,
       color: Color(0xFF00A3E0),
       prefixPattern: r'^\s*Plin(?:\s*Soles)?\s*:?',
     ),
     bcp(
       label: "BCP",
       icon: Icons.account_balance_rounded,
       color: Color(0xFF002A64),
       prefixPattern: r'^\s*BCP(?:\s*Soles)?\s*:?',
     ),
     bbva(
       label: "BBVA",
       icon: Icons.account_balance_rounded,
       color: Color(0xFF004481),
       prefixPattern: r'^\s*BBVA(?:\s*Soles)?\s*:?',
     ),
     cci(
       label: "CCI",
       icon: Icons.assured_workload_rounded,
       color: Color(0xFF00695C), // Color adaptativo para tema claro/oscuro
       prefixPattern: r'^\s*CCI(?:\s*Interbancario)?\s*:?',
     );

     final String label;
     final IconData icon;
     final Color color;
     final String prefixPattern;

     const PaymentChipType({
       required this.label,
       required this.icon,
       required this.color,
       required this.prefixPattern,
     });

     bool matchesLine(String line) =>
         RegExp(prefixPattern, caseSensitive: false).hasMatch(line);

     String defaultSnippet(String cleanPhone) {
       switch (this) {
         case PaymentChipType.yape:
           return "Yape: ${cleanPhone.isNotEmpty ? cleanPhone : '[Mi Teléfono]'}";
         case PaymentChipType.plin:
           return "Plin: ${cleanPhone.isNotEmpty ? cleanPhone : '[Mi Teléfono]'}";
         case PaymentChipType.bcp:
           return "BCP Soles: ";
         case PaymentChipType.bbva:
           return "BBVA: ";
         case PaymentChipType.cci:
           return "CCI Interbancario: ";
       }
     }
   }
   ```
2. **Parser y Toggle Order-Agnostic con Memoria de Sesión:**
   * La sesión mantendrá un mapa: `final Map<PaymentChipType, String> _sessionPaymentMemory = {};`.
   * Al pulsar un chip:
     1. Se divide el texto actual en líneas con `split('\n')`.
     2. Se comprueba si alguna línea cumple `type.matchesLine(l)`.
     3. Si existe:
        * Se localiza la línea y, si contiene más texto que la etiqueta vacía (ej. `BCP Soles: 191-12345678`), se almacena en `_sessionPaymentMemory[type]`.
        * Se eliminan todas las líneas coincidentes con `type.matchesLine`.
     4. Si no existe:
        * Se extrae el valor de `_sessionPaymentMemory[type]`. Si no hay nada en memoria, se genera con `type.defaultSnippet(cleanPhone)`.
        * Se añade la línea al final.
     5. Se filtran líneas vacías intermedias y se unen con `\n`.
     6. Se actualiza `paymentCtrl.text` y se posiciona el cursor al final de forma segura.
3. **Refinamiento Visual del Chip:**
   * El texto pasa a ser simplemente `label` cuando está activo (ej. `"BCP"`), y `"+ $label"` cuando está inactivo (ej. `"+ BCP"`). **Cero doble check `"✓"`**.
   * El icono utiliza `AnimatedSwitcher` entre el icono de la entidad y `Icons.check_circle_rounded`.
   * El contenedor utiliza `AnimatedContainer` con interpolación suave de color, borde y elevación.

---

### 3.2. Especificación Técnica: Normalización y Enunciado Dinámico en Perfil de Negocio
1. **Normalizador Canónico:**
   ```dart
   static String normalizePaymentText(String raw) {
     return raw
         .replaceAll('\r\n', '\n')
         .replaceAll('\r', '\n')
         .replaceAll(RegExp(r'[📱🏦🏛️]\s*'), '')
         .split('\n')
         .map((l) => l.trim())
         .where((l) => l.isNotEmpty)
         .join('\n');
   }
   ```
2. **Detector de Diferencias en Campos Individuales:**
   * `isPhoneChanged`: `_bizPhoneCtrl.text.trim() != originalPhone.trim()`
   * `isRucChanged`: `_bizRucCtrl.text.trim() != originalRuc.trim()`
   * `isAddressChanged`: `_bizAddressCtrl.text.trim() != originalAddress.trim()`
   * `isPaymentChanged`: `normalizePaymentText(_bizPaymentCtrl.text) != normalizePaymentText(originalPayment)`
3. **Construcción del Enunciado Conciso Adaptativo:**
   * Si no hay cambios:  
     `"Tus datos coinciden con el perfil actual de tu negocio."`
     (Badge `[Modificado]` oculto, `_config.updateBusinessData = false`, checkbox deshabilitado).
   * Si hay 1 cambio (ej. Teléfono):  
     `"Se actualizará en tu perfil: Teléfono."`
   * Si hay varios cambios (ej. Teléfono y Cuentas):  
     `"Se actualizarán en tu perfil: Teléfono y Cuentas de pago."`
     (Badge `[Modificado]` visible en color ámbar, checkbox activo para confirmación).
   * Se evitan totalmente valores antiguos y nuevos, conservando la tarjeta en 2 líneas de altura óptima.

---

### 3.3. Especificación Técnica: Reestructuración de `PresentationSnapshot` y `ProductEditSnapshot`
1. **Extensión de `PresentationSnapshot`:**
   ```dart
   class PresentationSnapshot {
     // Campos existentes...
     final bool usaStockCompartido;         // 🛡️ OBLIGATORIO
     final int? cupoMaximoVariante;         // 🛡️ OBLIGATORIO
     final Map<String, dynamic>? savedPropioSnapshot;     // 🛡️ OBLIGATORIO
     final Map<String, dynamic>? savedCompartidoSnapshot; // 🛡️ OBLIGATORIO
     final int? stockBaseOriginal;
     final double? costoBaseOriginal;
     final double? precioOfertaExacto;
     final double? costoBaseUnitario;
     ...
   ```
2. **Extensión de `ProductEditSnapshot`:**
   ```dart
   class ProductEditSnapshot {
     // Campos existentes...
     final String modoStock;         // 🛡️ 'COMPARTIDO', 'INDEPENDIENTE', 'MIXTO'
     final String baseCost;          // 🛡️ Costo base unitario formateado
     final String stockCompartido;   // 🛡️ Stock base total
     final String stockIngreso;      // 🛡️ '+ Ingreso (Nuevas)'
     ...
   ```
3. **Reconstrucción Integral en `restoreInto`:**
   Al restaurar, `ProductEditSnapshot.restoreInto` sincronizará:
   * `baseCostCtrl.text = baseCost;`
   * `sharedIngresoCtrl.text = stockIngreso;`
   * `sharedStockCtrl.text = stockCompartido;`
   * `onModoStockChanged(modoStock);`
   * En cada variante restaurada mediante `createNewControllerMap`, pasará explícitamente:
     `usaStockCompartido: p.usaStockCompartido,`
     `cupoMaximoVariante: p.cupoMaximoVariante,`
     `stockBaseOriginal: p.stockBaseOriginal,`
     `costoBaseOriginal: p.costoBaseOriginal,`
     `precioOfertaExacto: p.precioOfertaExacto,`
   * Y reinserterá intactos:
     `newMap['savedPropioSnapshot'] = p.savedPropioSnapshot;`
     `newMap['savedCompartidoSnapshot'] = p.savedCompartidoSnapshot;`
     `newMap['costoBaseUnitario'] = p.costoBaseUnitario;`

4. **Sincronización Reactiva en `ProductStockStrategySelector`:**
   * Garantizar que `didUpdateWidget` escuche `sharedIngresoController` si este es reemplazado o reconfigurado.
   * Al restaurar `_sharedIngresoCtrl.text = "0"` y `_sharedStockCtrl.text = "66"`, el selector actualizará de inmediato la visualización de los 3 bloques (`Stock Base Actual: 66 und`, `+ Ingreso (Nuevas): 0 und`, `= Stock Final: 66 und`).
   * Como las presentaciones mantienen `usaStockCompartido: true`, el cuadro `Stock Final Calculado por Variante` permanecerá **visible con sus cálculos exactos (`2 disp. (de 33 máx.)` y `11 disp.`)**.
   * Al cumplirse `current.isIdenticalTo(_initialSnapshot!)`, `_hasUnsavedChanges` pasará automáticamente a `false`, ocultando el botón amarillo de deshacer en el AppBar.

---

## 4. PLAN DE TRABAJO PASO A PASO (FASES MODULARES)

```
   ┌────────────────────────────────────────────────────────────────────────┐
   │ FASE 1: Reingeniería del Sistema de Chips en Editor WhatsApp           │
   │ - Implementar enum PaymentChipType con prefijos canónicos.            │
   │ - Implementar memoria temporal de sesión _sessionPaymentMemory.        │
   │ - Eliminar duplicación por ancla '^' y soportar orden agnóstico.      │
   │ - Retirar "✓" redundante y perfeccionar micro-animaciones en chips.   │
   └───────────────────────────────────┬────────────────────────────────────┘
                                       │
                                       ▼
   ┌────────────────────────────────────────────────────────────────────────┐
   │ FASE 2: Detección Real de Cambios y Enunciado Adaptativo en Perfil     │
   │ - Normalizador canónico de strings y medios de pago.                   │
   │ - Detección campo por campo contra los datos baseline de negocio.      │
   │ - Enunciado dinámico conciso sin valores antiguos ni nuevos.           │
   │ - Reseteo automático de badge [Modificado] y casilla de actualización. │
   └───────────────────────────────────┬────────────────────────────────────┘
                                       │
                                       ▼
   ┌────────────────────────────────────────────────────────────────────────┐
   │ FASE 3: Extensión Forense de Modelos de Snapshot en Edición Producto   │
   │ - PresentationSnapshot: captura de usaStockCompartido, cupo, snapshots.│
   │ - ProductEditSnapshot: captura de modoStock, baseCost, stockCompartido,│
   │   stockIngreso.                                                        │
   │ - ProductControllerFactory: soporte de snapshots y flags en rebuild.   │
   │ - ProductEditChangeDetector: comparación completa y fiable.            │
   └───────────────────────────────────┬────────────────────────────────────┘
                                       │
                                       ▼
   ┌────────────────────────────────────────────────────────────────────────┐
   │ FASE 4: Reparación del Flujo de Deshacer (Undo) y Restauración UI      │
   │ - snapshot.restoreInto: sincronización de controladores de estrategia. │
   │ - Preservación de usaStockCompartido y cuadro de cálculo de variante.  │
   │ - Ocultamiento automático del botón amarillo cuando se vuelve a cero.  │
   │ - didUpdateWidget en ProductStockStrategySelector.                     │
   └───────────────────────────────────┬────────────────────────────────────┘
                                       │
                                       ▼
   ┌────────────────────────────────────────────────────────────────────────┐
   │ FASE 5: Verificación Integral del Árbitro Adversarial y Tests Estáticos│
   │ - flutter analyze en los módulos afectados (cero warnings).            │
   │ - Verificación contra los escenarios de las 5 capturas.                │
   │ - Comprobación de no-regresión en creación y venta.                   │
   └────────────────────────────────────────────────────────────────────────┘
```

### Fase 1: Reingeniería del Sistema de Chips en `Editor WhatsApp`
* **Archivos a modificar:** `app_movil/lib/features/smart_quotation/widgets/whatsapp/wa_business_section.dart`.
* **Acciones concretas:**
  1. Definir la estructura `PaymentChipType` con expresiones regulares para líneas (`prefixPattern`) y generación de snippets canónicos.
  2. Implementar `_sessionPaymentMemory` para conservar las cuentas digitadas cuando un chip es apagado.
  3. Reemplazar `_togglePaymentMethod` por una rutina de partición en líneas (`split('\n')`), detección agnóstica de orden y recomposición sin saltos vacíos.
  4. Modificar `_buildPaymentQuickChip` para eliminar el `"✓ "` del texto (dejando únicamente `label` cuando está activo y `"+ $label"` cuando está inactivo).
  5. Enriquecer la animación del chip con `AnimatedSwitcher` en el icono (`Icons.check_circle_rounded` vs icono bancario) y transición de escala en `AnimatedContainer`.

### Fase 2: Detección Real de Cambios y Enunciado Adaptativo en Perfil de Negocio
* **Archivos a modificar:**
  * `app_movil/lib/features/smart_quotation/screens/whatsapp_preview_screen.dart`
  * `app_movil/lib/features/smart_quotation/widgets/whatsapp/wa_business_section.dart`
* **Acciones concretas:**
  1. En `whatsapp_preview_screen.dart`, guardar los valores iniciales limpios de `originalPhone`, `originalRuc`, `originalAddress` y `originalPayment`.
  2. Implementar `normalizePaymentText` y calcular la lista `List<String> changedBusinessFields`.
  3. Si `changedBusinessFields.isEmpty`:
     * Forzar `hasBusinessChanges = false`.
     * Si `_config.updateBusinessData` estaba activo, resetearlo a `false`.
  4. Pasar `changedBusinessFields` a `WaBusinessSection`.
  5. En `WaBusinessSection`, renderizar el subtítulo dinámico conciso según la cantidad de campos en `changedBusinessFields`. Si está vacío, mostrar `"Tus datos coinciden con el perfil actual de tu negocio."`.

### Fase 3: Extensión Forense de Modelos de Snapshot en `Editar Producto`
* **Archivos a modificar:**
  * `app_movil/lib/features/catalog/widgets/edit/product_edit/product_edit_snapshot.dart`
  * `app_movil/lib/features/catalog/widgets/edit/product_edit/product_edit_change_detector.dart`
  * `app_movil/lib/features/catalog/widgets/form/product_controller_factory.dart`
* **Acciones concretas:**
  1. Agregar `usaStockCompartido`, `cupoMaximoVariante`, `savedPropioSnapshot`, `savedCompartidoSnapshot`, `stockBaseOriginal`, `costoBaseOriginal`, `precioOfertaExacto`, `costoBaseUnitario` a `PresentationSnapshot`.
  2. Actualizar `PresentationSnapshot.fromControllerMap` y `PresentationSnapshot.isIdenticalTo`.
  3. Agregar `modoStock`, `baseCost`, `stockCompartido`, `stockIngreso` a `ProductEditSnapshot`.
  4. Actualizar `ProductEditSnapshot.capture` y `ProductEditSnapshot.isIdenticalTo`.
  5. En `ProductEditChangeDetector`, actualizar la comparación para incluir los nuevos campos del snapshot inicial y del estado del formulario.

### Fase 4: Reparación del Flujo de Deshacer (Undo) y Restauración en UI
* **Archivos a modificar:**
  * `app_movil/lib/features/catalog/screens/product_edit_screen.dart`
  * `app_movil/lib/features/catalog/widgets/form/product_stock_strategy_selector.dart`
* **Acciones concretas:**
  1. En `ProductEditSnapshot.restoreInto`, recibir `baseCostCtrl`, `sharedStockCtrl`, `sharedIngresoCtrl`, `onModoStockChanged` y restaurar sus valores exactos.
  2. En la reconstrucción de variantes de `restoreInto`, suministrar `usaStockCompartido` y `cupoMaximoVariante` a `createNewControllerMap`, y restaurar `savedPropioSnapshot` y `savedCompartidoSnapshot`.
  3. En `product_edit_screen.dart`, actualizar `_applySnapshot` para restaurar los controladores de estrategia antes de re-vincular los listeners, evitando loops de debounce.
  4. Asegurar que `_hasUnsavedChanges` compare el estado actual completo contra `_initialSnapshot`, ocultando el botón amarillo de deshacer en cuanto el formulario regrese a su estado original.
  5. En `product_stock_strategy_selector.dart`, verificar que `didUpdateWidget` sincronice reactivamente ante cambios en `sharedIngresoController` y refresque los cálculos de variantes.

### Fase 5: Verificación del Árbitro Adversarial y Tests Estáticos
* **Acciones concretas:**
  1. Ejecutar análisis estático con `flutter analyze` en `app_movil` para verificar cero errores de tipado o null-safety.
  2. Contrastar el comportamiento contra las 5 capturas:
     * *Escenario 1 (Captura 1):* Activar BCP y CCI -> Desactivar CCI -> CCI desaparece limpiamente sin duplicados.
     * *Escenario 2 (Captura 2):* Digitar cuenta en Yape -> Desactivar Yape -> Reactivar Yape -> El número se restaura.
     * *Escenario 3 (Captura 2):* Regresar datos a perfil original -> Badge [Modificado] se oculta y texto indica que coinciden.
     * *Escenario 4 (Capturas 3, 4 y 5):* Subir +50 und en ingreso -> Presionar botón amarillo de deshacer -> Ingreso regresa a 0 und, stock final regresa a 66 und, variantes conservan `usaStockCompartido: true`, cuadro azul permanece visible y botón amarillo se oculta.

---

## 5. TABLA DE CONTROL DE ARCHIVOS AFECTADOS

| Archivo | Responsabilidad Principal | Modificaciones Clave |
|---|---|---|
| `app_movil/lib/features/smart_quotation/widgets/whatsapp/wa_business_section.dart` | Chips de pago y tarjeta de perfil | Enum `PaymentChipType`, toggle order-agnostic, memoria de sesión, eliminación de `"✓"` redundante, subtítulo dinámico conciso. |
| `app_movil/lib/features/smart_quotation/screens/whatsapp_preview_screen.dart` | Pantalla Editor WhatsApp | Normalización de datos originales de negocio, cálculo de `changedBusinessFields`, reseteo de `updateBusinessData`. |
| `app_movil/lib/features/catalog/widgets/edit/product_edit/product_edit_snapshot.dart` | Snapshots inmutables de producto y variantes | Inclusión de `modoStock`, `baseCost`, `stockCompartido`, `stockIngreso`, `usaStockCompartido`, `cupoMaximoVariante`, `savedPropioSnapshot`, `savedCompartidoSnapshot`. |
| `app_movil/lib/features/catalog/widgets/edit/product_edit/product_edit_change_detector.dart` | Detección forense de cambios sin guardar | Comparación completa de estrategia de stock y flags de variante. |
| `app_movil/lib/features/catalog/screens/product_edit_screen.dart` | Pantalla de edición de producto | Captura y aplicación completa de snapshots en `_recordUndoSnapshot`, `_undoLastChange`, `_restoreOriginalSavedState` y `_hasUnsavedChanges`. |
| `app_movil/lib/features/catalog/widgets/form/product_stock_strategy_selector.dart` | Selector de estrategia de stock | Sincronización reactiva en `didUpdateWidget`, preservación del cuadro resumen de variantes compartidas. |

---

## 6. CRITERIOS DE ACEPTACIÓN INMEDIATOS PARA EL ÁRBITRO INTERNO ADVERSARIAL

1. **Cero Duplicados en Chips:** Tocar consecutivamente `BCP`, `CCI`, `BBVA`, luego desactivar `CCI`, luego desactivar `BCP` y volver a activar `BCP`: el texto resultante no tendrá líneas repetidas ni saltos dobles.
2. **Memoria Temporal Funcional:** Si el usuario escribe `BCP Soles: 191-99887766` y toca el chip `BCP` (desactivar), al tocar `+ BCP` la línea vuelve a ser `BCP Soles: 191-99887766`.
3. **Cero Doble Check en UI:** Ningún chip activo tendrá simultáneamente el icono `check_circle` y el texto `"✓"`.
4. **Reversibilidad Limpia en Perfil:** Al dejar los campos de teléfono, RUC, dirección y cuentas idénticos a los del negocio, el badge `[Modificado]` debe desaparecer sin requerir recargar la pantalla.
5. **Enunciado Dinámico y Conciso:** El texto inferior indicará estrictamente `Se actualizará en tu perfil: [Campos]` sin mostrar valores antiguos/nuevos, o `Tus datos coinciden con el perfil actual de tu negocio.` si no hay cambios.
6. **Deshacer Fidedigno en Edición:**
   * Al agregar `50 und` en `+ Ingreso` y presionar deshacer, `+ Ingreso` vuelve a `0 und`.
   * `= Stock Final` vuelve a `66 und`.
   * Todas las variantes marcadas como compartidas permanecen con `usaStockCompartido: true`.
   * El cuadro azul `Stock Final Calculado por Variante` permanece visible con `2 disp. (de 33 máx.)` y `11 disp.`.
   * El botón amarillo de deshacer se oculta automáticamente al quedar el formulario idéntico al snapshot inicial.

