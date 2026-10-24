# 🚀 PLAN MAESTRO DE TRABAJO: UNIFICACIÓN DEL MODAL DE DETALLES, ARQUITECTURA DUAL DE DESCUENTOS, PERSISTENCIA ENTRE VARIANTES Y SINCRONIZACIÓN DE MÁRGENES (CAJA RÁPIDA & COTIZACIÓN MANUAL)

**Documento de Especificación Técnica, Diagnóstico Forense y Protocolo Adversarial**  
**Proyecto:** MochilaLista App (Local-First SQLite, 0ms Latency, Flutter Mobile)  
**Módulos Involucrados:**
- **Caja Rápida:** `quick_sale_screen.dart`, `quick_sale_detail_modal.dart`, `quick_sale_cart_item.dart`, `quick_sale_provider.dart`.
- **Cotización Manual:** `manual_quotation_screen.dart`, `manual_quote_detail_modal.dart`, `manual_price_modifier.dart`, `manual_quote_item_card.dart`, `manual_quote_footer.dart`, `catalog_search_modal.dart`, `manual_quote_catalog_ext.dart`, `manual_quote_data_ext.dart`, `manual_quote_offers_ext.dart`.
- **Gestión de Precios e Inventario:** `price_update_modal.dart` (`lib/core/widgets/price_update_modal.dart`), `inventory_provider.dart`, `interactive_sheet_wrapper.dart`.
- **Modelos de Dominio:** `matching_model.dart` (`MatchedProduct`), `product_model.dart` (`ProductPresentation`), `smart_quotation_model.dart` (`QuotationItem`).
**Fecha:** Octubre 2026  
**Metodología:** Loop Autónomo + Árbitro Interno Adversarial Estricto  

---

## 📸 1. AUDITORÍA FORENSE DE LAS 5 CAPTURAS Y DIAGNÓSTICO EN CÓDIGO FUENTE

A partir de la inspección minuciosa de las 5 capturas remitidas por el usuario y la auditoría línea por línea del código fuente, se establece la causa raíz exacta de cada falla:

| Captura | Pantalla / Componente | Diagnóstico Forense del Problema | Causa Raíz Exacta en Código Fuente |
| :--- | :--- | :--- | :--- |
| **Imagen 1** | **`Caja Rápida` (Lista de Ítems en Carrito)** | **Corrupción de Precio en Variante `12x15ml`:** Tras abrir y cerrar `Editar Catálogo`, la variante `12x15ml` (cuyo precio base real es `S/ 1.00` sin oferta) aparece con el precio y descuento de la variante `verde`: `Base 1,20 S/ -> 1,14 S/ (-5%)`. | • `quick_sale_detail_modal.dart` L647-650: Al tocar `Editar Catálogo`, busca la presentación en `_fullProduct!.presentaciones` mediante fallback ciego `?? _fullProduct!.presentaciones.firstOrNull`.<br>• Como `_loadVariants()` usó `getFullProductWithFallback` (que en memoria solo tenía la variante inicial o incompleta), el selector tomó la primera variante (`verde`).<br>• En L660-689, sobrescribió `_systemPrice = 1.20` y `offerPrice = 1.14` en `_currentSelection` (que correspondía a `12x15ml`), y llamó a `quickProv.syncItemPriceAndStock` con el `presentationId` de `12x15ml` inyectando los datos de `verde`. |
| **Imagen 2** | **Modal Detalles en `Caja Rápida`** (`Shampoo Romero 12x15ml`) | **1. Ausencia de Chips de Selección de Presentación:** No muestra la sección `"Seleccionar Presentación:"` que sí tiene Cotización Manual.<br>**2. Switch de Descuento Apagado pero Aplica Descuento:** El switch `"Aplicar Descuento"` está en OFF, pero el subtotal sigue calculando `1,14 S/` con `Ahorro: 0,06 S/`. | • `quick_sale_detail_modal.dart` L471-473: Condiciona los chips a `_fullProduct != null && _fullProduct!.presentaciones.length > 1`. Al cargar vía `getFullProductWithFallback` (L103) desde wrappers filtrados en `_inventoryItems`, la lista tiene longitud <= 1 y los chips nunca se pintan.<br>• `quick_sale_detail_modal.dart` L550-553: Al apagar el switch, asigna `effPrice = _currentSelection.hasOffer ? _currentSelection.effectivePrice : _systemPrice`. Si hay oferta en BD, la mantiene activa forzosamente. |
| **Imagen 3** | **Modal `Gestionar Precio`** (`PriceUpdateModal` / `Editar Catálogo`) | **1. Botón `"Quitar Oferta"` Cortado en el Borde Inferior:** En la tarjeta verde `PRECIO FINAL AL CLIENTE`, el texto rojo `"Quitar Oferta"` se corta por la mitad contra el borde inferior.<br>**2. Falta de Enunciado Informativo:** No aclara que este modal edita permanentemente la base de datos de inventario. | • `price_update_modal.dart` L805-829: `TextButton` con `padding: EdgeInsets.zero`, `minimumSize: Size(0,0)` y `shrinkWrap` pegado al fondo de un contenedor con padding vertical comprimido.<br>• La acción inferior fija (`bottomAction`, L258-320) colisiona visualmente con el scroll cuando el viewport es menor a 700dp. |
| **Imagen 4** | **Modal Detalles en `Cotización Manual`** (`Shampoo Romero 12x15ml`) | **1. Ambigüedad Total en Chips de Presentación:** Ambos chips dicen `"Unidad"` y `"Unidad"`, sin distinguir si uno es `verde` y el otro `12x15ml`.<br>**2. Pérdida de Estado al Alternar Chips:** Si el usuario modifica cantidad o descuento en una variante y cambia de chip, al regresar sus cambios se borraron por completo. | • `manual_quote_detail_modal.dart` L646: `ChoiceChip(label: Text(p.unidadVenta ?? "Unidad"))`. Solo lee `unidadVenta`, ignorando por completo `nombreEspecifico` (ej. `"verde"`, `"12x15ml"`).<br>• `manual_quote_detail_modal.dart` L203-251: `_updateVariant(pres)` sobrescribe las variables locales (`_qtyCtrl`, `_priceCtrl`, etc.) desde cero sin ningún mapa de estado en memoria (`Map<int, VariantDetailState>`). |
| **Imagen 5** | **Modal Detalles en `Cotización Manual`** (`SAN CARLOS - jekeke Color`) | **Bug Crítico de Imposibilidad de Desactivar Descuentos:** Aunque el usuario desactive el switch `"Aplicar Descuento"` para vender/cotizar a precio base regular (`13,90 S/`), el modal mantiene `Ahorro: 1,39 S/` y `Subtotal: 12,51 S/`, y al guardar la tarjeta sigue con descuento. | • `manual_quote_detail_modal.dart` L675-678: `onToggle: (v) { if (!v) { final eff = _currentSelection.hasOffer ? _currentSelection.effectivePrice : _systemPrice; _priceCtrl.text = eff.toStringAsFixed(2); } }`. Si tiene oferta de BD, el apagado del switch es totalmente ignorado.<br>• `manual_quote_detail_modal.dart` L262-265 (`_confirm`): `if (!_isManualPrice) { overridePrice = _currentSelection.hasOffer ? _currentSelection.effectivePrice : null; }`. Retorna la oferta de BD en lugar de anularla con el precio base regular. |

---

## 🎯 2. PRINCIPIOS RECTORES Y ARQUITECTURA DE SOLUCIÓN

### Principio 1: Unificación del Modal de Detalles (`Cotización Manual` <-> `Caja Rápida`)
Ambas ventanas de venta y cotización deben ofrecer la misma experiencia visual, ergonómica y funcional.
- Se toma como estándar arquitectural la estructura moderna de `ManualQuoteDetailModal` con `ManualPriceModifier`.
- En ambas ventanas, `_loadVariants()` consultará directamente la base de datos SQLite mediante `invProv.fetchProductById(_currentSelection.productId)`, garantizando que el 100% de las presentaciones registradas estén siempre disponibles en memoria.
- Se erradica de forma definitiva cualquier fallback ciego (`?? presentaciones.firstOrNull` o `?? presentaciones.first`). Las variantes se identificarán unívocamente mediante `presentationId`.

### Principio 2: Claridad y Descriptividad en Chips de Presentación
- Cuando un producto cuente con múltiples variantes registradas, la etiqueta de cada chip debe ser auto-explicativa:
  * Si tiene `nombreEspecifico` (ej. `"verde"`, `"12x15ml"`, `"Rojo"`):  
    **`[ nombreEspecifico · unidadVenta ]`** (ej. `verde · Unidad`, `12x15ml · Unidad`).
  * Si el factor de venta es mayor a 1:  
    **`[ unidadVenta (xFactor) ]`** o **`[ nombreEspecifico · unidadVenta (xFactor) ]`** (ej. `Par (x2)`, `Docena (x12)`).
- De este modo, en la Imagen 4 el usuario verá con total claridad: `[ verde · Unidad ]` y `[ ✓ 12x15ml · Unidad ]`.

### Principio 3: Arquitectura Dual de Descuentos (Permanente en BD vs. Temporal de Operación)
El sistema debe diferenciar y gobernar limpiamente los dos tipos de descuento:

1. **TIPO 1: Descuento Permanente de Inventario / Base de Datos (`Editar Catálogo` -> `PriceUpdateModal`):**
   * Persiste en SQLite en la tabla `presentaciones_producto` (`precio_oferta`, `tipo_descuento`, `valor_descuento`).
   * Rige para todo el catálogo y futuras ventas/cotizaciones.
   * `PriceUpdateModal` incluirá un aviso claro y conciso:
     > *"💡 Los cambios realizados aquí actualizan el precio y la oferta de forma permanente en tu Catálogo/Inventario. Si solo deseas dar un descuento temporal para esta venta o cotización, hazlo directamente en el modal anterior con 'Aplicar Descuento'"*.
   * Se corrige el layout de la tarjeta verde para que `"Quitar Oferta"` se muestre 100% íntegro, visible y con padding táctil amplio (40px de altura efectiva).

2. **TIPO 2: Descuento Especial / Temporal de la Operación (Switch `"Aplicar Descuento"` en Modal de Detalles):**
   * **Regla de Oro de Desactivación:** Si el usuario apaga el switch `"Aplicar Descuento"`, **el descuento se desactiva verdaderamente**:
     - `_priceCtrl.text` se fija en `_systemPrice.toStringAsFixed(2)`.
     - `_discountCtrl.clear()`.
     - `Ahorro` = `0.00 S/` (oculto).
     - `Subtotal` = `_systemPrice * cantidad`.
     - En `_confirm()`, se establece un precio override explícito igual a `_systemPrice` (o bandera de oferta desactivada), impidiendo que el carrito o cotización vuelvan a aplicar la oferta de catálogo.
   * **Indicador Visual de Procedencia:** Dentro de la tarjeta `"Aplicar Descuento"` se renderiza un badge contextual:
     - `📦 Oferta de Catálogo`: Cuando la variante tiene oferta en BD y el switch está activo sin modificaciones manuales.
     - `✨ Descuento Especial (Solo aquí)`: Cuando el usuario ingresó un descuento temporal propio para esa venta o cotización.
     - `🚫 Oferta desactivada para esta operación`: Cuando la variante tiene oferta en BD pero el usuario apagó el switch para cobrar el precio base regular.

### Principio 4: Persistencia de Estado por Variante (`Map<int, VariantDetailState>`)
- Dentro del Modal de Detalles se implementará un mapa de borradores en memoria indexado por `presentationId`: `Map<int, VariantDetailState> _variantDrafts`.
- Al conmutar entre chips de presentación:
  1. El estado actual de la variante saliente (cantidad, switch activo/inactivo, descuento manual, precio modificado) se guarda en `_variantDrafts[salientePresId]`.
  2. Si la variante entrante ya existía en `_variantDrafts`, se restauran íntegramente sus campos y controladores.
  3. Si la variante entrante no está en borradores pero ya existía en la lista de cotización o carrito de caja rápida, se inicializa con los valores vigentes en dicha lista.
  4. Si es completamente nueva, se inicializa con cantidad 1, precio base de la BD y su oferta de catálogo por defecto.
- De esta forma, el usuario puede alternar entre chips cuantas veces desee sin perder jamás sus modificaciones.

### Principio 5: Reactividad Instantánea a 0ms en Cadena
- Al pulsar `APLICAR CAMBIOS` o `Quitar Oferta` en `PriceUpdateModal`, este retorna el objeto `ProductPresentation` actualizado a SQLite.
- El Modal de Detalles abierto debajo:
  1. Recarga de inmediato la información fresca desde SQLite (`await invProv.fetchProductById(...)`).
  2. Identifica la presentación exacta por `presentationId`.
  3. Actualiza a 0ms su Precio Base, su oferta de catálogo, su Ahorro y su Subtotal.
  4. Actualiza la entrada correspondiente en `_variantDrafts`.
  5. Sincroniza al instante con el provider (`quickProv.syncItemPriceAndStock` o `smartProv.syncItemPriceAndStock` / `onCatalogUpdated`).
- La tarjeta del producto en la pantalla principal (`Caja Rápida` o `Cotización Manual`) se actualiza reactivamente a 0ms en segundo plano.

### Principio 6: Cierre Táctil Universal (`Drag-to-Dismiss` + Botón `✕`)
- Se incorpora en la esquina superior derecha del Modal de Detalles un botón `✕` discreto y accesible (`Icons.close_rounded`) para cierre inmediato con un solo toque.
- Se optimiza el comportamiento gestual en `InteractiveSheetWrapper`:
  - Se garantiza que el scroll interno tenga `physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics())`.
  - El modal intercepta el arrastre descendente desde cualquier punto del cuerpo del modal cuando la posición del scroll se encuentra en el tope (`pixels <= 0`), permitiendo descartar el modal arrastrando hacia abajo desde cualquier área sin obligar a apuntar a la barra superior.

### Principio 7: Paridad y Perfeccionamiento del Botón del Ojito (`👁️`) en `Cotización Manual`
- Se dota a `Cotización Manual` de la misma capacidad de privacidad frente al cliente que tiene `Caja Rápida`:
  1. Los `MatchedProduct` generados en `manual_quotation_screen.dart`, `catalog_search_modal.dart`, `manual_quote_data_ext.dart` y `manual_quote_offers_ext.dart` incluirán su `cost` calculado a partir de `pres.costoPresentacionFinal`.
  2. En `ManualQuoteItemCard`, se añade el badge animado de margen unitario (`• XX% mrg`) con semáforo cromático (verde >= 20%, ámbar 10-19%, rojo < 10%).
  3. En `ManualQuoteFooter`, se calcula la utilidad neta total estimada (`estimatedTotalProfit = sum((effectivePrice - cost) * qty)`) y se muestra el badge `"Ganancia ~S/ X.XX"` con semáforo de salud de margen.
  4. Al pulsar el botón del ojito (`👁️`) en el `AppBar`, tanto los badges de margen de las tarjetas como el resumen de ganancia del footer se ocultan/muestran de forma instantánea con animación fluida de 250ms (`AnimatedSwitcher`).

---

## 🏗️ 3. DIAGRAMA DE FLUJO ARQUITECTURAL DE LAS 7 FASES

```mermaid
flowchart TD
    subgraph FASE 1: Erradicación del Bug de Variantes y Búsqueda Unívoca por presentationId
        F1_1[quick_sale_detail_modal: reemplazar getFullProductWithFallback por fetchProductById] --> F1_2[Eliminar fallback ciego firstOrNull en onTap Editar Catálogo]
        F1_2 --> F1_3[Garantizar matching unívoco pres.id == _currentSelection.presentationId]
        F1_3 --> F1_4[Blindar syncItemPriceAndStock para apuntar estrictamente a la variante editada]
    end

    subgraph FASE 2: Unificación de Modales de Detalles y Chips Descriptivos
        F2_1[Unificar UI de quick_sale_detail_modal con arquitectura de manual_quote_detail_modal] --> F2_2[Formatear chips: nombreEspecifico · unidadVenta xFactor]
        F2_2 --> F2_3[Garantizar visualización de chips de presentación en ambas pantallas]
        F2_3 --> F2_4[Homogeneizar componentes de imagen, factores, stock y botones de acción]
    end

    subgraph FASE 3: Arquitectura Dual de Descuentos y Desactivación Real
        F3_1[Modificar onToggle del switch: si es OFF, forzar precio base regular y ahorro cero] --> F3_2[Persistir overridePrice = systemPrice para impedir reactivación de oferta de BD]
        F3_2 --> F3_3[Badges de procedencia: Oferta de Catálogo vs Descuento Especial vs Oferta Desactivada]
        F3_3 --> F3_4[Aviso informativo en PriceUpdateModal + corrección de padding y corte de Quitar Oferta]
    end

    subgraph FASE 4: Persistencia de Estado por Variante en Memoria
        F4_1[Diseñar estructura VariantDetailState con qty, switch, precio y descuento] --> F4_2[Mantener Map presentationId, VariantDetailState en el modal]
        F4_2 --> F4_3[Guardar borrador de la variante activa antes de conmutar chip]
        F4_3 --> F4_4[Restaurar borrador exacto al regresar a un chip previamente editado]
    end

    subgraph FASE 5: Reactividad Instantánea 0ms y Drag-to-Dismiss Universal
        F5_1[PriceUpdateModal retorna presentación actualizada al pop] --> F5_2[Modal de detalles refresca estado y caché a 0ms tras cerrar Editar Catálogo]
        F5_2 --> F5_3[Propagar actualización inmediata a la tarjeta principal detrás del modal]
        F5_3 --> F5_4[Incorporar botón de cierre X superior derecho + AlwaysScrollable BouncingPhysics]
    end

    subgraph FASE 6: Botón del Ojito y Márgenes de Ganancia en Cotización Manual
        F6_1[Inyectar costo factor-aware pres.costoPresentacionFinal en MatchedProduct de Cotización] --> F6_2[Implementar badge • XX% mrg en ManualQuoteItemCard con AnimatedSwitcher]
        F6_2 --> F6_3[Calcular Ganancia Total Estimada en ManualQuoteFooter con semáforo de margen]
        F6_3 --> F6_4[Sincronizar visibilidad con quickProv.hideProfits en AppBar de Cotización Manual]
    end

    subgraph FASE 7: Pruebas Automatizadas y Protocolo Adversarial
        F7_1[Diseñar suite de pruebas en test/sale_quote_modals_unified_discounts_and_margins_test.dart] --> F7_2[Verificar pruebas de no-confusión de variantes y persistencia entre chips]
        F7_2 --> F7_3[Verificar prueba de desactivación real de descuento y badges de procedencia]
        F7_3 --> F7_4[Verificar paridad del botón del ojito, reactividad 0ms y suite completa de regresión]
    end

    FASE 1 --> FASE 2 --> FASE 3 --> FASE 4 --> FASE 5 --> FASE 6 --> FASE 7
```

---

## 📝 4. ESPECIFICACIÓN TÉCNICA DETALLADA POR FASE

### FASE 1: Erradicación del Bug de Confusión de Variantes e Identificación Unívoca por `presentationId`

#### Archivos Involucrados:
- `lib/features/smart_quotation/widgets/quick_sale/quick_sale_detail_modal.dart`
- `lib/features/smart_quotation/widgets/manual/manual_quote_detail_modal.dart`
- `lib/features/smart_quotation/screens/quick_sale_screen.dart`
- `lib/features/smart_quotation/providers/quick_sale_provider.dart`

#### 1.1. Carga Exhaustiva desde Base de Datos:
- En `QuickSaleDetailModal._loadVariants()`, sustituir la llamada a `getFullProductWithFallback(_currentSelection.productId)` por `invProv.fetchProductById(_currentSelection.productId)`.
- Esto garantiza que `_fullProduct` contenga siempre el array íntegro de presentaciones registradas en SQLite, sin verse afectado por filtros en memoria ni estados parciales de `_inventoryItems`.

#### 1.2. Erradicación del Fallback Ciego (`firstOrNull`):
- En `quick_sale_detail_modal.dart` L647-650 y L660-662:
  ```dart
  // ANTES (PELIGROSO: confundía variantes al tomar la primera si fallaba la búsqueda)
  targetPres = _fullProduct!.presentaciones.where(
    (p) => p.id == _currentSelection.presentationId,
  ).firstOrNull ?? _fullProduct!.presentaciones.firstOrNull;
  
  // AHORA (ESTRICTO: busca únicamente la presentación seleccionada)
  targetPres = _fullProduct!.presentaciones.where(
    (p) => p.id == _currentSelection.presentationId,
  ).firstOrNull;
  
  if (targetPres == null) {
    // Si no está en el array en memoria, buscarlo directamente en la base de datos por ID
    targetPres = await invProv.fetchPresentationById(_currentSelection.presentationId);
  }
  ```
- Si `targetPres` es nulo tras la búsqueda estricta, registrar advertencia y abortar sin tocar ninguna otra variante ajena.
- Al retornar de `PriceUpdateModal`, actualizar estrictamente la variante cuyo `id == _currentSelection.presentationId`. Jamás aplicar datos a una variante distinta.

#### 1.3. Sincronización Blindada en `QuickSaleProvider`:
- En `quickProv.syncItemPriceAndStock(presentationId, ...)` verificar que el índice coincida exactamente con `p.presentationId == presentationId`.
- Preservar los campos propios de la variante (nombre específico, factor, costo) sin permitir contaminación cruzada entre presentaciones del mismo producto padre.

---

### FASE 2: Unificación del Modal de Detalles y Chips Descriptivos de Presentación

#### Archivos Involucrados:
- `lib/features/smart_quotation/widgets/quick_sale/quick_sale_detail_modal.dart`
- `lib/features/smart_quotation/widgets/manual/manual_quote_detail_modal.dart`
- `lib/features/smart_quotation/widgets/manual/manual_price_modifier.dart`

#### 2.1. Homogeneización de la Interfaz:
- Replicar en `QuickSaleDetailModal` el diseño premium, márgenes y distribución estructurada de `ManualQuoteDetailModal`:
  - Uso compartido de `ManualPriceModifier` para la sección de descuentos.
  - Sección de cabecera con avatar de producto, zoom de imagen, marca destacada, nombre del producto, factor de conversión, stock disponible y botón táctil `[ ✏️ Ajustar ]` de stock.
  - Botón principal de guardado con altura uniforme de 54-60dp y estilo `ElevatedButton`.

#### 2.2. Chips Descriptivos y Diferenciados (`"Seleccionar Presentación:"`):
- En la construcción de cada `ChoiceChip`, generar la etiqueta dinámica:
  ```dart
  String formatPresentationChipLabel(ProductPresentation p) {
    final hasSpecific = p.nombreEspecifico != null && p.nombreEspecifico!.trim().isNotEmpty;
    final unit = p.unidadVenta ?? "Unidad";
    final factor = p.unidadesPorVenta > 1 ? " (x${p.unidadesPorVenta})" : "";
    
    if (hasSpecific) {
      return "${p.nombreEspecifico!.trim()} · $unit$factor";
    }
    return "$unit$factor";
  }
  ```
- **Resultado Visible:**
  - Variante 1: `[ verde · Unidad ]`
  - Variante 2: `[ 12x15ml · Unidad ]`
  - Variante con factor: `[ Par (x2) ]` o `[ Color · Par (x2) ]`
- Los chips se renderizan en una fila con scroll horizontal suave (`SingleChildScrollView(scrollDirection: Axis.horizontal)`), padding táctil generoso (12dp) y selección claramente resaltada con el color primario de la app.

---

### FASE 3: Arquitectura Dual de Descuentos, Desactivación Real y Corrección Visual en `Gestionar Precio`

#### Archivos Involucrados:
- `lib/core/widgets/price_update_modal.dart`
- `lib/features/smart_quotation/widgets/manual/manual_price_modifier.dart`
- `lib/features/smart_quotation/widgets/manual/manual_quote_detail_modal.dart`
- `lib/features/smart_quotation/widgets/quick_sale/quick_sale_detail_modal.dart`
- `lib/features/smart_quotation/providers/quick_sale_provider.dart`
- `lib/features/smart_quotation/screens/manual/manual_quote_catalog_ext.dart`

#### 3.1. Corrección del Bug de Desactivación de Descuento:
- En `manual_quote_detail_modal.dart` y `quick_sale_detail_modal.dart`, modificar el callback `onToggle`:
  ```dart
  void _handleDiscountToggle(bool isEnabled) {
    setState(() {
      _isDiscountActive = isEnabled;
      if (!isEnabled) {
        // 🔥 DESACTIVACIÓN REAL: Se cobra estrictamente el Precio Base Regular
        _priceCtrl.text = _systemPrice.toStringAsFixed(2);
        _discountCtrl.clear();
      } else {
        // Activación: Si el catálogo tiene oferta, se propone inicialmente dicha oferta
        if (_currentSelection.hasOffer) {
          _priceCtrl.text = _currentSelection.effectivePrice.toStringAsFixed(2);
          final disc = _systemPrice - _currentSelection.effectivePrice;
          _discountCtrl.text = disc > 0 ? disc.toStringAsFixed(2) : "";
        } else {
          _priceCtrl.text = _systemPrice.toStringAsFixed(2);
          _discountCtrl.clear();
        }
      }
    });
  }
  ```
- **Cálculo de Totales en Tiempo Real:**
  ```dart
  double currentPrice = double.tryParse(_priceCtrl.text) ?? _systemPrice;
  double effectiveFinalPrice = _isDiscountActive ? currentPrice : _systemPrice;
  double subtotal = effectiveFinalPrice * currentQty;
  double totalSavings = _isDiscountActive ? math.max(0.0, (_systemPrice - effectiveFinalPrice) * currentQty) : 0.0;
  ```
- **Persistencia en `_confirm()`:**
  ```dart
  double? overridePrice;
  if (!_isDiscountActive) {
    // Si la variante tenía oferta en BD pero el usuario apagó el switch,
    // guardamos explícitamente _systemPrice como override para anular la oferta en esta operación
    overridePrice = _currentSelection.hasOffer ? _systemPrice : null;
  } else {
    overridePrice = currentPrice;
  }
  ```

#### 3.2. Badges de Procedencia de Descuento en `ManualPriceModifier`:
- En la cabecera de la sección de descuento, junto al switch, mostrar una micro-etiqueta informativa:
  - **`📦 Oferta de Catálogo`** (Verde suave): Cuando `_isDiscountActive && _currentSelection.hasOffer && (currentPrice - _currentSelection.effectivePrice).abs() < 0.01`.
  - **`✨ Descuento Especial (Solo aquí)`** (Naranja/Ámbar suave): Cuando `_isDiscountActive && ((!_currentSelection.hasOffer) || (currentPrice - _currentSelection.effectivePrice).abs() >= 0.01)`.
  - **`🚫 Oferta desactivada para esta operación`** (Gris azulado): Cuando `!_isDiscountActive && _currentSelection.hasOffer`.

#### 3.3. Perfeccionamiento de `PriceUpdateModal` (`Gestionar Precio` — Imagen 3):
- **Aviso Informativo Superior:**
  Debajo de `"Actualiza el precio regular o define una oferta."`, agregar:
  ```dart
  Container(
    margin: const EdgeInsets.only(top: 10, bottom: 4),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: widget.isDark ? Colors.blue.withValues(alpha: 0.12) : Colors.blue.shade50,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: widget.isDark ? Colors.blue.withValues(alpha: 0.3) : Colors.blue.shade200),
    ),
    child: Row(
      children: [
        Icon(Icons.info_outline, size: 16, color: widget.isDark ? Colors.blue[300] : Colors.blue[800]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            "Los cambios aquí actualizan tu Catálogo/Inventario de forma permanente.",
            style: TextStyle(fontSize: 11, color: widget.isDark ? Colors.blue[200] : Colors.blue[900], height: 1.3),
          ),
        ),
      ],
    ),
  ),
  ```
- **Reparación del Botón `"Quitar Oferta"` (Cero Cortes):**
  - Modificar el contenedor verde `PRECIO FINAL AL CLIENTE`:
    * `padding: const EdgeInsets.fromLTRB(16, 14, 16, 14)`
    * `SizedBox(height: 10)` entre el precio de oferta y el botón.
    * Reemplazar el `TextButton` comprimido por un botón con área táctil cómoda:
      ```dart
      InkWell(
        onTap: () => setState(() {
          finalOfferPrice = null;
          discountCtrl.clear();
          _activeRoundingTarget = null;
          _preRoundedValor = null;
          isBasePriceUpdate = false;
          errorMsg = null;
        }),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
          ),
          child: Text(
            "Quitar Oferta",
            style: TextStyle(color: widget.isDark ? Colors.red[300] : Colors.red[700], fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      )
      ```
    * Añadir `padding: const EdgeInsets.fromLTRB(20, 8, 20, 32)` al `SingleChildScrollView` para que la tarjeta no quede jamás pegada ni solapada por el botón azul `APLICAR CAMBIOS`.

---

### FASE 4: Persistencia de Estado por Variante en Memoria dentro del Modal de Detalles

#### Archivos Involucrados:
- `lib/features/smart_quotation/widgets/manual/manual_quote_detail_modal.dart`
- `lib/features/smart_quotation/widgets/quick_sale/quick_sale_detail_modal.dart`

#### 4.1. Estructura `VariantDetailState`:
```dart
class VariantDetailState {
  final int presentationId;
  int quantity;
  bool isDiscountActive;
  double price;
  String discountInput;
  bool isManualPrice;
  String? customName;

  VariantDetailState({
    required this.presentationId,
    required this.quantity,
    required this.isDiscountActive,
    required this.price,
    required this.discountInput,
    required this.isManualPrice,
    this.customName,
  });

  VariantDetailState copyWith({
    int? quantity,
    bool? isDiscountActive,
    double? price,
    String? discountInput,
    bool? isManualPrice,
    String? customName,
  }) {
    return VariantDetailState(
      presentationId: presentationId,
      quantity: quantity ?? this.quantity,
      isDiscountActive: isDiscountActive ?? this.isDiscountActive,
      price: price ?? this.price,
      discountInput: discountInput ?? this.discountInput,
      isManualPrice: isManualPrice ?? this.isManualPrice,
      customName: customName ?? this.customName,
    );
  }
}
```

#### 4.2. Ciclo de Vida y Transición entre Chips:
1. En `initState()`, inicializar el borrador para `widget.product.presentationId` con los valores recibidos de la llamada inicial.
2. Al dispararse `_updateVariant(ProductPresentation nextPres)`:
   - **Paso A (Guardado del borrador saliente):**
     ```dart
     _variantDrafts[_currentSelection.presentationId] = VariantDetailState(
       presentationId: _currentSelection.presentationId,
       quantity: int.tryParse(_qtyCtrl.text) ?? 1,
       isDiscountActive: _isDiscountActive,
       price: double.tryParse(_priceCtrl.text) ?? _systemPrice,
       discountInput: _discountCtrl.text,
       isManualPrice: _isManualPrice,
       customName: _currentCustomName,
     );
     ```
   - **Paso B (Carga o creación del borrador entrante):**
     * Si `_variantDrafts.containsKey(nextPres.id!)`: restaurar directamente el estado guardado.
     * Si no existe en el mapa:
       - Si la variante entrante ya está listada en la cotización o carrito de caja rápida: inicializarla con la cantidad y el precio override existentes en dicha lista.
       - Si es nueva: inicializar con cantidad 1, precio base de la presentación `nextPres.precioVentaFinal`, oferta de catálogo si existe, y `_isDiscountActive = nextPres.hasOffer`.
   - **Paso C (Hidratación de UI):**
     * Actualizar `_currentSelection` con la nueva presentación.
     * Actualizar `_systemPrice = nextPres.precioVentaFinal`.
     * Restaurar `_qtyCtrl.text`, `_priceCtrl.text`, `_discountCtrl.text` y `_isDiscountActive`.
     * Ejecutar `setState(() {})`.

---

### FASE 5: Reactividad Instantánea a 0ms en Cadena y Drag-to-Dismiss Universal

#### Archivos Involucrados:
- `lib/core/widgets/price_update_modal.dart`
- `lib/core/widgets/interactive_sheet_wrapper.dart`
- `lib/features/smart_quotation/widgets/manual/manual_quote_detail_modal.dart`
- `lib/features/smart_quotation/widgets/quick_sale/quick_sale_detail_modal.dart`
- `lib/features/smart_quotation/screens/quick_sale_screen.dart`
- `lib/features/smart_quotation/screens/manual_quotation_screen.dart`

#### 5.1. Flujo de Retorno y Notificación 0ms:
1. En `PriceUpdateModal`, al guardar satisfactoriamente en SQLite:
   ```dart
   if (context.mounted) Navigator.pop(context, true);
   ```
2. En el Modal de Detalles (`Editar Catálogo`):
   ```dart
   final didUpdate = await PriceUpdateModal.show(...);
   if (didUpdate == true) {
     // 1. Recargar datos frescos de SQLite
     final refreshedProd = await invProv.fetchProductById(_currentSelection.productId);
     if (refreshedProd != null) {
       final exactPres = refreshedProd.presentaciones.firstWhere(
         (p) => p.id == _currentSelection.presentationId,
       );
       
       setState(() {
         _fullProduct = refreshedProd;
         _systemPrice = exactPres.precioVentaFinal;
         final newOffer = exactPres.hasOffer ? exactPres.effectivePrice : null;
         _currentSelection = _currentSelection.copyWith(
           price: exactPres.precioVentaFinal,
           offerPrice: newOffer,
           stock: exactPres.stockActual ~/ (exactPres.unidadesPorVenta > 0 ? exactPres.unidadesPorVenta : 1),
         );
         
         // Si el descuento activo corresponde al catálogo, actualizar de inmediato
         if (_isDiscountActive && !_isCustomPrice) {
           _priceCtrl.text = (_currentSelection.effectivePrice).toStringAsFixed(2);
           final disc = _systemPrice - _currentSelection.effectivePrice;
           _discountCtrl.text = disc > 0 ? disc.toStringAsFixed(2) : "";
         }
       });
       
       // 2. Propagar de inmediato a la lista de la pantalla principal (0ms)
       widget.onCatalogUpdated?.call(
         exactPres.id!,
         exactPres.stockActual,
         exactPres.precioVentaFinal,
         exactPres.hasOffer ? exactPres.effectivePrice : null,
       );
       
       // Sincronizar provider activo (QuickSaleProvider o SmartQuotationProvider)
       if (context.mounted) {
         Provider.of<QuickSaleProvider>(context, listen: false).syncItemPriceAndStock(
           exactPres.id!,
           newPrice: exactPres.precioVentaFinal,
           newOfferPrice: exactPres.hasOffer ? exactPres.effectivePrice : null,
           clearOffer: !exactPres.hasOffer,
           newStock: exactPres.stockActual ~/ (exactPres.unidadesPorVenta > 0 ? exactPres.unidadesPorVenta : 1),
         );
       }
     }
   }
   ```

#### 5.2. Drag-to-Dismiss Universal y Botón `✕`:
- En la esquina superior derecha del modal (alineado con la barra superior o cabecera del producto), añadir:
  ```dart
  IconButton(
    icon: const Icon(Icons.close_rounded, size: 24),
    tooltip: "Cerrar",
    onPressed: () => Navigator.pop(context),
  )
  ```
- Configurar el `SingleChildScrollView` del modal con:
  ```dart
  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
  ```
- Garantizar que el `InteractiveSheetWrapper` transmita el gesto de sobre-desplazamiento vertical hacia abajo (`overscroll < 0`) hacia `_triggerDismiss()`, de modo que arrastrar hacia abajo desde cualquier parte del modal cuando el scroll está en el tope cierre el modal elásticamente.

---

### FASE 6: Modo de Visibilidad de Márgenes y Ganancia Total (`👁️`) en `Cotización Manual`

#### Archivos Involucrados:
- `lib/features/smart_quotation/screens/manual_quotation_screen.dart`
- `lib/features/smart_quotation/widgets/manual/manual_quote_item_card.dart`
- `lib/features/smart_quotation/widgets/manual/manual_quote_footer.dart`
- `lib/features/smart_quotation/widgets/manual/catalog_search_modal.dart`
- `lib/features/smart_quotation/screens/manual/manual_quote_data_ext.dart`
- `lib/features/smart_quotation/screens/manual/manual_quote_offers_ext.dart`

#### 6.1. Inyección de Costo Factor-Aware en `MatchedProduct`:
- En todos los puntos de creación de `MatchedProduct` en Cotización Manual:
  ```dart
  final double presCost = pres.costoPresentacionFinal;
  final double? calculatedCost = presCost > 0
      ? presCost
      : (pres.factorGananciaVenta != null && pres.factorGananciaVenta! > 0
          ? pres.precioVentaFinal / pres.factorGananciaVenta!
          : null);
  
  MatchedProduct(
    ...
    cost: calculatedCost,
  );
  ```

#### 6.2. Badge de Margen en `ManualQuoteItemCard`:
- Junto al texto `"Unitario"`, agregar el componente animado que escucha `QuickSaleProvider.hideProfits`:
  ```dart
  if (item.cost != null && item.cost! > 0) ...[
    Builder(
      builder: (ctx) {
        final quickProv = Provider.of<QuickSaleProvider>(ctx);
        final double margin = ((manualPrice - item.cost!) / manualPrice) * 100;
        final Color marginColor = margin >= 20
            ? (isDark ? Colors.green[400]! : Colors.green[700]!)
            : (margin >= 10
                ? (isDark ? Colors.amber[400]! : Colors.amber[800]!)
                : (isDark ? Colors.red[400]! : Colors.red[700]!));

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: quickProv.hideProfits
              ? const SizedBox.shrink(key: ValueKey('margin_hidden'))
              : Row(
                  key: const ValueKey('margin_visible'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: marginColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 5, height: 5, decoration: BoxDecoration(color: marginColor, shape: BoxShape.circle)),
                          const SizedBox(width: 3),
                          Text(
                            "${margin.round()}% mrg",
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: marginColor),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    ),
  ],
  ```

#### 6.3. Ganancia Total Estimada en `ManualQuoteFooter`:
- En `_ManualQuotationScreenState`, calcular:
  ```dart
  double get _estimatedTotalProfit {
    double profit = 0;
    for (var item in _items) {
      final qty = _quantities[item.presentationId] ?? 1;
      final effectivePrice = _overriddenPrices[item.presentationId] ?? (item.offerPrice ?? item.price);
      if (item.cost != null && item.cost! > 0) {
        profit += (effectivePrice - item.cost!) * qty;
      }
    }
    return profit > 0 ? profit : 0.0;
  }
  ```
- Enviar `estimatedProfit: _estimatedTotalProfit` a `ManualQuoteFooter`.
- En `ManualQuoteFooter`, renderizar sobre o junto al Total a Cobrar:
  ```dart
  Consumer<QuickSaleProvider>(
    builder: (ctx, quickProv, _) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: (!quickProv.hideProfits && widget.estimatedProfit > 0)
            ? Container(
                key: const ValueKey('quote_visible_profit_badge'),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: widget.isDark ? Colors.green.withValues(alpha: 0.2) : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: widget.isDark ? Colors.green.withValues(alpha: 0.4) : Colors.green.shade300,
                  ),
                ),
                child: Text(
                  "Ganancia ~${currency.format(widget.estimatedProfit)}",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: widget.isDark ? Colors.green[300] : Colors.green[800],
                  ),
                ),
              )
            : const SizedBox.shrink(key: ValueKey('quote_empty_profit_badge')),
      );
    },
  )
  ```

---

### FASE 7: Suite de Pruebas Automatizadas y Protocolo Adversarial

#### Archivos Involucrados:
- Nuevo archivo de prueba: `test/sale_quote_modals_unified_discounts_and_margins_test.dart`
- Suites de regresión:
  * `test/caja_rapida_cotizacion_clientes_reengineering_test.dart`
  * `test/discounts_rounding_price_update_and_offers_filter_test.dart`
  * `test/stock_factor_aware_and_sale_modals_sync_test.dart`

#### Casos de Prueba Críticos Obligatorios:
1. **Prueba 1 (Erradicación de Confusión de Variantes):** Al abrir `PriceUpdateModal` desde la variante 2 (`12x15ml`), verificar que el modal recibe estrictamente `presentationId: 2` y que jamás contamina los precios con la variante 1 (`verde`).
2. **Prueba 2 (Desactivación Real de Descuento):** Con un producto con oferta del 10% en BD (`13.90` -> `12.51`), apagar el switch `"Aplicar Descuento"` en el modal de detalles y comprobar que:
   - El subtotal pasa exactamente a `13.90 S/`.
   - El ahorro pasa a `0.00 S/`.
   - Al pulsar `GUARDAR CAMBIOS`, la tarjeta en la lista muestra precio regular `13.90 S/` sin oferta.
3. **Prueba 3 (Persistencia de Estado por Variante):** En un producto con 2 variantes:
   - Variante 1: modificar cantidad a 4 y activar descuento especial de `1.00 S/`.
   - Conmutar a Variante 2: verificar que carga su estado normal.
   - Conmutar de vuelta a Variante 1: verificar que mantiene cantidad 4 y el descuento especial de `1.00 S/`.
4. **Prueba 4 (Chips Descriptivos):** Verificar que un producto con 2 variantes vendidas por `Unidad` renderiza los chips con sus nombres específicos: `verde · Unidad` y `12x15ml · Unidad`.
5. **Prueba 5 (Visibilidad de Márgenes en Cotización Manual):**
   - Con `hideProfits == false`: verificar presencia de los badges `• XX% mrg` en las tarjetas y `Ganancia ~S/ X.XX` en el footer.
   - Con `hideProfits == true`: verificar que ningún badge de margen ni texto de ganancia sea visible.
6. **Prueba 6 (Reactividad 0ms):** Modificar el precio en `PriceUpdateModal` y verificar que el Modal de Detalles y la lista principal se actualizan inmediatamente al confirmar sin recargar la pantalla.

---

## 🛡️ 5. PROTOCOLO DEL ÁRBITRO INTERNO ADVERSARIAL

Para garantizar que la implementación sea impecable y no sufra regresiones, el Árbitro Interno Adversarial auditará las siguientes reglas antes de dar cualquier tarea por terminada:

```
┌────────────────────────────────────────────────────────────────────────┐
│               CHECKLIST ADVERSARIAL DE ACEPTACIÓN FINAL                │
├────────────────────────────────────────────────────────────────────────┤
│ [ ] 1. ¿Existe algún fallback '.first' o '.firstOrNull' en la búsqueda │
│        de presentaciones al abrir Editar Catálogo?                     │
│        -> DEBE SER TOTALMENTE NULO. Búsqueda 100% por presentationId. │
│                                                                        │
│ [ ] 2. Al apagar el switch "Aplicar Descuento", ¿el subtotal refleja   │
│        inmediatamente el precio base regular sin céntimos fantasma?    │
│        -> OBLIGATORIO: Ahorro = 0, Subtotal = precioBase * cantidad.   │
│                                                                        │
│ [ ] 3. ¿El botón "Quitar Oferta" en PriceUpdateModal se ve completo,   │
│        con texto íntegro y sin recortes en la parte inferior?          │
│        -> OBLIGATORIO: Margen y padding visual impecables.             │
│                                                                        │
│ [ ] 4. ¿Los chips de presentación muestran nombre específico y unidad? │
│        -> OBLIGATORIO: Ej. "verde · Unidad" y "12x15ml · Unidad".      │
│                                                                        │
│ [ ] 5. ¿Conmutar entre chips de variantes preserva las modificaciones  │
│        de cantidad, switch y descuento sin borrar el trabajo del user? │
│        -> OBLIGATORIO: Mapa de borradores _variantDrafts activo.       │
│                                                                        │
│ [ ] 6. ¿El botón del ojito oculta y muestra instantáneamente costos,   │
│        márgenes y ganancia total en Cotización Manual?                 │
│        -> OBLIGATORIO: Animación fluida de 250ms sin parpadeos.        │
│                                                                        │
│ [ ] 7. ¿Se puede cerrar el modal arrastrando hacia abajo o con botón X?│
│        -> OBLIGATORIO: Drag-to-dismiss elástico y botón X disponible.  │
│                                                                        │
│ [ ] 8. ¿Pasaron el 100% de los tests automatizados sin regresiones?    │
│        -> OBLIGATORIO: flutter test exitoso con cero fallos.           │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 📌 6. ARCHIVO DEL PLAN Y ESTADO ACTUAL

- **Ubicación del Documento:** `analisis_proyecto/PLAN_UNIFICACION_MODAL_DETALLES_DESCUENTOS_Y_MARGENES.md`
- **Estado Actual:** 🟡 **EN ESPERA DE APROBACIÓN DEL USUARIO** (No se ha modificado ningún archivo de código de la app en este turno de diseño y planificación).
