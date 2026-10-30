# PLAN MAESTRO: MOTOR DE VENTAS ATÓMICO, SINCRONIZACIÓN DE STOCK COMPARTIDO, COTIZACIONES Y MODALES DE DETALLE (PARTE 2)

**Documento:** `analisis_proyecto/PLAN_PARTE2_MOTOR_VENTAS_STOCK_COMPARTIDO_Y_MODALES_DETALLE.md`  
**Fecha:** 28 de Octubre de 2026  
**Versión:** 1.0 — Especificación Técnica Definitiva (Mobile Awards Quality)  
**Estado:** Esperando Aprobación de Plan de Trabajo (Paso 1: Diagnóstico Forense y Diseño Arquitectónico)  
**Metodología:** Loop Autónomo + Árbitro Adversarial (Test-Driven, Zero-Regressions & Zero-Overflows)

---

## 1. RESUMEN EJECUTIVO Y OBJETIVOS ESTRATÉGICOS

### 1.1. Contexto Global
Tras certificar y validar al 100% la **Parte 1** (Migración SQLite V26, columna `cupo_maximo_variante`, selector responsive de `Estrategia de Stock`, costos reactivos en cascada, memoria bidireccional de modo y asesor inteligente de variantes), pasamos a la **Segunda Etapa (Parte 2)**. 

A partir de las pruebas operativas en ventas reales y del análisis forense de las **5 capturas de pantalla** aportadas por el usuario:
1. `3.00.18 AM.jpeg` y `3.00.18 AM (1).jpeg`: El modal `Abastecer / Editar Stock` permite modificar las unidades base de una variante compartida de forma aislada (ej. subir a 26 Pares = 52 unidades base superando el pool de 48, o reducir a 20 Pares reduciendo el pool central y desincronizando las demás variantes hermanas), además de disparar alertas alarmistas de "unidades sueltas sobrantes" que no aplican a stock compartido.
2. `1.32.18 AM.jpeg` (`ManualQuoteDetailModal` - Cotización Manual): El banner `"Pool Base Disponible: 48 und."` permanece estático incluso cuando el usuario selecciona una variante independiente (`Surtido · Unidad (Stock Propio)`), y los precios muestran formato antiguo (`0,00 S/`).
3. `2.09.18 AM.jpeg` (`ProductQuoteDetailModal` - Cotización Inteligente / Escáner IA): La fila de selección de variantes no muestra el nombre de las variantes (`Principal`, `Surtido`, `Caja`), el chip `"✓ Unidad - 2,00 S/"` se corta en el borde derecho por falta de un degradado sutil (`ShaderMask`) y los precios no siguen el estándar oficial peruano (`AppCurrency.format`).
4. **Flujo de Ventas y Cotizaciones**: Al vender una variante compartida en Caja Rápida o al cobrar una lista cotizada, se debe descontar atómicamente del `stock_compartido` en unidades base ($cantidad \times factor$), sincronizar `stock_actual` en todas las variantes compartidas y recalcular de inmediato el stock final vendible de cada variante respetando su `cupo_maximo_variante`. Al anular la venta (`voidSale`), se deben restaurar exactamente las unidades base al pool y recalcular el stock final de todas las variantes hermanas.

---

### 1.2. Los 4 Ejes Fundamentales de la Parte 2

```
                                  ┌────────────────────────────────────────────────────────┐
                                  │   PARTE 2: MOTOR DE VENTAS, COTIZACIONES Y MODALES     │
                                  └──────────────────────────┬─────────────────────────────┘
                                                             │
            ┌──────────────────────────────┬─────────────────┴────────────┬──────────────────────────────┐
            ▼                              ▼                              ▼                              ▼
  ┌───────────────────┐          ┌───────────────────┐          ┌───────────────────┐          ┌───────────────────┐
  │   1. MOTOR DE     │          │  2. COTIZACIONES  │          │   3. MODAL DE     │          │   4. MODALES DE   │
  │     VENTAS        │          │   INTELIGENTES    │          │  ABASTECIMIENTO   │          │     DETALLE       │
  ├───────────────────┤          ├───────────────────┤          ├───────────────────┤          ├───────────────────┤
  │• Venta atómica    │          │• Simulación libre │          │• Variante         │          │• Soporte para los │
  │  en unidades base │          │  de cantidades.   │          │  Compartida:      │          │  3 modos (Comp,   │
  │• Sincronización   │          │• Alertas exactas  │          │  Solo edita cupo  │          │  Indep, Mixto).   │
  │  de hermanas.     │          │  por cupo y pool  │          │  final sin tocar  │          │• Banner reactivo  │
  │• Respeto de cupo  │          │  acumulado.       │          │  el pool base.    │          │  según variante.  │
  │  máximo.          │          │• Bloqueo estricto │          │• Bloqueo > máx con│          │• ShaderMask en    │
  │• Reversión limpia │          │  pre-venta en     │          │  aviso temporal 4s│          │  chips variantes. │
  │  en voidSale.     │          │  Resoluciones.    │          │• Variante Propia: │          │• Estandarización  │
  │• 0ms en SQLite.   │          │• Centro de Res.   │          │  Modo estándar.   │          │  AppCurrency.     │
  └───────────────────┘          └───────────────────┘          └───────────────────┘          └───────────────────┘
```

---

## 2. DIAGNÓSTICO FORENSE Y EVIDENCIA VISUAL EN CÓDIGO

### 2.1. Descuento en Ventas y Sincronización del Pool Compartido
* **Archivos:**
  * `lib/features/smart_quotation/services/sales_service.dart` (Líneas 100–175, 435–515)
  * `lib/features/smart_quotation/providers/quick_sale_provider.dart` (Líneas 180–275, 414–438)
  * `lib/features/catalog/models/inventory_wrapper.dart` (Líneas 25–48)
  * `lib/features/smart_quotation/models/matching_model.dart` (Líneas 10–55)
* **Diagnóstico Forense:**
  1. En `sales_service.dart`, `createSale` descuenta `baseUnitsToDeduct = quantity * factor`. Sin embargo, `presCheck` se consulta con columnas que no incluyen `cupo_maximo_variante`. Si la variante compartida tenía un cupo de venta manual configurado (ej. cupo de `6` cuando físicamente alcanzan `8`), el motor permitía vender `8` porque el pool físico lo permitía, violando el cupo asignado por el comerciante.
  2. En `quick_sale_provider.dart`, `getRemainingVendibleStock` y `getRemainingAvailableForPresentation` calculan `remainingPool ~/ factor`, sin acotar por `presentation.cupoMaximoVariante`.
  3. `MatchedProduct` no cuenta con el campo `cupoMaximoVariante`, por lo que al transferirse una variante al carrito de Caja Rápida o a una lista cotizada, se pierde la información del cupo y se valida únicamente contra el stock físico ilimitado.
  4. En `voidSale` (`sales_service.dart`), la reversión atómica restaura `stock_compartido` y `stock_actual` de variantes compartidas, pero no refresca de forma consistente la memoria de `InventoryProvider` para que todas las tarjetas hermanas recalculen su `displayStock` de inmediato.

---

### 2.2. Verificación de Stock y Simulación en Cotizaciones
* **Archivos:**
  * `lib/features/smart_quotation/services/quotation_service.dart` (`validateIntegrity`, Líneas 62–160, 400–435)
  * `lib/features/smart_quotation/screens/manual_quotation_screen.dart` (Líneas 570–615)
  * `lib/features/smart_quotation/screens/matching_screen.dart` (Líneas 280–305)
  * `lib/features/smart_quotation/widgets/matching/matching_item_row.dart` (Líneas 80–105)
  * `lib/features/smart_quotation/widgets/manual/manual_quote_item_card.dart` (Líneas 95–103, 220–248)
  * `lib/features/smart_quotation/widgets/smart_update_modal.dart` (Líneas 90–150)
* **Diagnóstico Forense:**
  1. **Regla de Negocio de Cotizaciones:** Al presupuestar una lista escolar o corporativa, el vendedor debe poder ingresar cualquier cantidad solicitada por el cliente (ej. cotizar `30 cuadernos` aunque en inventario solo queden `10`).
  2. **Advertencias de Stock Compartido:** Cuando la cotización incluye 2 o más variantes del mismo producto compartido (ej. `20 Pares` = 40 und. base y `3 Medias Docenas` = 18 und. base, total 58 und. base sobre un pool de 48), `MatchingProvider.sharedDemandPerProduct` calcula la demanda, pero `ManualQuoteItemCard` y `MatchingItemRow` requieren comprobar con precisión quirúrgica:
     * El stock final individual con cupo: $\min(\text{cupo}, \lfloor \text{pool} \div \text{factor} \rfloor)$.
     * La colisión de pool: $\sum (\text{cantidad}_i \times \text{factor}_i) > \text{pool\_compartido}$.
  3. **Bloqueo Pre-Venta en `validateIntegrity`:** Al pulsar "Cobrar" o convertir la cotización en venta, `validateIntegrity` debe bloquear si la demanda acumulada supera el pool compartido O si alguna variante supera su `cupo_maximo_variante`, impidiendo transacciones ilegales y derivando al usuario al `SmartUpdateModal` (Centro de Resoluciones) para ajustar cantidades o abastecer stock.

---

### 2.3. Modal `Abastecer / Editar Stock` (`stock_update_modal.dart`)
* **Archivo:** `lib/core/widgets/stock_update_modal.dart` (Líneas 40–185, 220–355, 395–435)
* **Diagnóstico Forense (Evidencia en Capturas 2 y 3):**
  1. Al abrir el modal en una variante compartida (`Principal · Par x2`, pool = 48 unidades base, stock final = 24 pares), el modal presenta las opciones `"Sumar Compra"` y `"Fijar Stock Total"`.
  2. Al cambiar a 26 pares (Captura 3), el modal calcula `26 Par = 52 unidades base` y al presionar "Aplicar Cambios", ejecuta `updatePresentation(stock: 52)`, lo cual sobrescribe el pool base completo en SQLite y memoria a 52, o reduce el pool central si se baja la cantidad.
  3. Si la variante compartida queda con residuo respecto al pool ($46 \pmod 6 = 4$), el modal despliega una alerta molesta e irrelevante: *"Hay 4 u. base suelta(s) que no completan un ½ Docena (x6)..."*, ignorando que esas 4 unidades base están disponibles para otras variantes hermanas (`Par` o `Unidad`).
* **Comportamiento Requerido:**
  * **Variante Compartida:** El modal **SOLO permite editar el `Stock Final` (su cupo vendible `cupo_maximo_variante`)**.
  * No modifica las unidades base compartidas (`stock_compartido` ni `stock_actual`).
  * Muestra claramente el contexto: `"Ajustando Cupo Vendible: X de un máximo de Y según las Z unidades base compartidas"`, con botón `"Restaurar al máximo"`.
  * Si el usuario intenta aumentar por encima de $\lfloor \text{Pool Base} \div \text{Factor} \rfloor$, el valor se bloquea en el máximo y se muestra un banner temporal animado de 4 segundos:
    > *"⚠️ No puedes aumentar más del máximo permitido (X [Unidad] según tus Y unidades base compartidas). El cambio de la cantidad de unidades base solo se puede realizar en la ventana de Editar Producto."*
  * Al guardar, actualiza `cupo_maximo_variante` en `presentaciones_producto` (o `null` si es el máximo físico) sin alterar las unidades base.
  * **Variante Propia / Independiente:** Mantiene intacto el flujo completo (`Sumar Compra` y `Fijar Stock Total`).

---

### 2.4. Modales de Detalles de Producto y Estandarización Monetaria
* **Archivos:**
  * `lib/features/smart_quotation/widgets/quick_sale/quick_sale_detail_modal.dart` (Líneas 240–310, 760–815)
  * `lib/features/smart_quotation/widgets/manual/manual_quote_detail_modal.dart` (Líneas 275–340, 915–965)
  * `lib/features/smart_quotation/widgets/matching/product_quote_detail_modal.dart` (Líneas 555–560, 740–815)
  * `lib/core/widgets/product_detail_modal.dart` (Líneas 390–440)
* **Diagnóstico Forense (Evidencia en Capturas 4 y 5):**
  1. **Banner Estático en Modo Mixto (Captura 4):** Los 4 modales evalúan `if (_fullProduct.hasSharedStock)` a nivel de producto. En modo `MIXTO`, si el usuario selecciona una variante independiente (`Surtido · Unidad (Stock Propio: 20 und)`), el modal continúa mostrando erróneamente `"Pool Base Disponible: 48 und."`. El banner debe ser **100% reactivo al modo de la variante actualmente seleccionada**.
  2. **Truncamiento y Falta de Nombre en Chips (Captura 5):** En `ProductQuoteDetailModal`, los chips solo muestran `"${p.unidadVenta} - ${p.precioVentaFinal}"`, omitiendo el `nombreEspecifico` (`Principal`, `Surtido`, `Caja`). Además, el chip del extremo derecho se corta abruptamente sin degradado suave (`ShaderMask`).
  3. **Formato Monetario Antiguo:** En las Capturas 4 y 5 se observan cadenas como `"0,00 S/"`, `"2,00 S/"`, `"1,70 S/"` generadas por `NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ')`. Todo el sistema debe emplear exclusivamente `AppCurrency.format(...)` (`S/ #,##0.00`).

---

## 3. ARQUITECTURA MATEMÁTICA Y FLUJO OPERATIVO

### 3.1. Caso Real de Prueba: Descuento Atómico y Recálculo Cruzado

```
ESTADO INICIAL:
• Producto: "kiwkkd" (Modo Compartido, productos.stock_compartido = 48)
• Variante 1 ("Par", Factor = 2): Stock Final = 48 ~/ 2 = 24 Pares. (cupo = null)
• Variante 2 ("½ Docena", Factor = 6): Stock Final = 48 ~/ 6 = 8 Medias Docenas. (cupo = null)

TRANSACCIÓN:
• El usuario vende 1 Par de la Variante 1 en Caja Rápida o Cotización.

PASO 1: CÁLCULO DE UNIDADES BASE VENDIDAS
• 1 Par × Factor 2 = 2 unidades base.

PASO 2: ACTUALIZACIÓN ATÓMICA SQLITE (0ms)
• UPDATE productos SET stock_compartido = 48 - 2 = 46 WHERE id = prodId;
• UPDATE presentaciones_producto SET stock_actual = 46 WHERE producto_id = prodId AND usa_stock_compartido = 1;
• INSERT INTO stock_ledger (presentation_id: pres1, cantidad: -2, tipo: 'VENTA', ...);

PASO 3: RECÁLCULO DE STOCK FINAL EFECTIVO DE TODAS LAS VARIANTES
• Variante 1 ("Par", Factor = 2):
  - Físico: 46 ~/ 2 = 23 Pares.
  - Efectivo: min(cupo ?? 23, 23) = 23 Pares.
• Variante 2 ("½ Docena", Factor = 6):
  - Físico: 46 ~/ 6 = 7 Medias Docenas. (Residuo: 46 % 6 = 4 unidades base en pool).
  - Efectivo: min(cupo ?? 7, 7) = 7 Medias Docenas.
  - ¡CERO alertas de unidades sobrantes en tarjetas ni modales compartidos!

PASO 4: CASO CON CUPO ASIGNADO (cupo_maximo_variante = 6)
• Si la Variante 2 tenía un cupo manual de 6:
  - Físico = 7.
  - Efectivo = min(6, 7) = 6 Medias Docenas.
• Si el pool cae a 30 base:
  - Físico = 30 ~/ 6 = 5.
  - Efectivo = min(6, 5) = 5 Medias Docenas.

PASO 5: REVERSIÓN ATÓMICA EN voidSale
• UPDATE productos SET stock_compartido = 46 + 2 = 48 WHERE id = prodId;
• UPDATE presentaciones_producto SET stock_actual = 48 WHERE producto_id = prodId AND usa_stock_compartido = 1;
• INSERT INTO stock_ledger (presentation_id: pres1, cantidad: +2, tipo: 'ANULACION', ...);
• Ambas variantes recalculan su stock final: 24 Pares y 8 Medias Docenas.
```

---

## 4. FASES DETALLADAS DE IMPLEMENTACIÓN (LOOP AUTÓNOMO)

### FASE 1: Motor de Ventas Atómico, Sincronización de Pool y Reversión en SQLite
* **Objetivo:** Blindar la deducción y reposición atómica de stock en unidades base con recálculo automático para todas las variantes hermanas y respeto irrestricto de `cupo_maximo_variante`.
* **Archivos a modificar:**
  1. `lib/features/smart_quotation/services/sales_service.dart`:
     * En `createSale`:
       * Consultar `cupo_maximo_variante` en `presCheck`.
       * En variantes con `usa_stock_compartido = 1`, verificar que la cantidad vendida no supere `cupo_maximo_variante` (si está fijado).
       * Deducir atómicamente $cantidad \times factor$ unidades base de `productos.stock_compartido` y actualizar `presentaciones_producto.stock_actual` para todas las variantes con `usa_stock_compartido = 1` de ese producto.
       * Registrar en `stock_ledger` la cantidad en unidades base (`-baseUnitsToDeduct`).
     * En `voidSale`:
       * Al anular la venta, restaurar $+baseUnitsToRestore$ en `productos.stock_compartido` y `presentaciones_producto.stock_actual` para todas las variantes con `usa_stock_compartido = 1`.
       * Registrar en `stock_ledger` la transacción de tipo `'ANULACION'`.
  2. `lib/features/smart_quotation/models/matching_model.dart`:
     * Agregar `cupoMaximoVariante` a `MatchedProduct` (constructor, `fromJson`, `copyWith`, `clone`).
     * Actualizar el cálculo de stock disponible en `MatchedProduct` para que use `unidadesVendiblesDisponibles` (respetando cupo si es compartido).
  3. `lib/features/smart_quotation/providers/quick_sale_provider.dart`:
     * En `getRemainingVendibleStock` y `getRemainingAvailableForPresentation`, acotar el stock vendible resultante con `presentation.cupoMaximoVariante`.
     * En `_validateSharedStockDemand`, si la variante tiene un cupo fijado y la cantidad solicitada excede el cupo, emitir advertencia precisa: *"El cupo asignado para esta variante es de $cupo $unidad."*.
  4. `lib/features/catalog/providers/inventory_provider.dart`:
     * Enriquecer `updatePresentation` para admitir `cupoMaximoVariante`.
     * Reconstruir `ProductPresentation` preservando o actualizando `cupoMaximoVariante`.
     * Implementar método `updateVariantQuota(int presentationId, int? cupo)` para actualizaciones directas desde el modal de abastecimiento a 0ms.

---

### FASE 2: Sistema de Cotizaciones: Simulación Flexible vs. Advertencias Exactas y Bloqueo Pre-Venta
* **Objetivo:** Permitir la creación libre de presupuestos con cualquier cantidad y desplegar advertencias de stock exactas (cupo individual y colisión de pool compartido), con bloqueo estricto al momento del cobro.
* **Archivos a modificar:**
  1. `lib/features/smart_quotation/services/quotation_service.dart`:
     * En `validateIntegrity`:
       * Consultar `cupo_maximo_variante` de cada presentación.
       * Para cada ítem con `usa_stock_compartido = 1`:
         * Validar si la cantidad requerida supera su `cupo_maximo_variante`. Si lo supera, generar `StockWarning` bloqueante: *"Supera el cupo asignado para esta variante (requiere $req, cupo $cupo)."*.
         * Validar si la demanda acumulada de todas las variantes del mismo pool supera `stock_compartido`. Si lo supera, generar `StockWarning` bloqueante: *"Stock compartido insuficiente (demanda acumulada del pool: $demanda und. base, disponible: $pool und. base)."*.
       * Calcular `availableUnits` considerando $\min(\text{cupo}, \lfloor \text{pool} \div \text{factor} \rfloor)$.
  2. `lib/features/smart_quotation/screens/manual_quotation_screen.dart` y `manual_quote_item_card.dart`:
     * Mantener la capacidad de presupuestar cualquier cantidad sin bloqueo en la pantalla de cotización manual.
     * En `ManualQuoteItemCard`, calcular `isSharedPoolExceeded` y verificar si supera el cupo de la variante.
     * Reemplazar `NumberFormat.currency` por `AppCurrency.format(...)`.
  3. `lib/features/smart_quotation/screens/matching_screen.dart` y `matching_item_row.dart`:
     * Comprobar colisión de pool en `MatchingProvider.hasStockWarnings`.
     * Actualizar `MatchingItemRow` para resaltar visualmente si el ítem supera su cupo o si el pool compartido está colisionado.
  4. `lib/features/smart_quotation/widgets/smart_update_modal.dart` y `quotation_detail_screen.dart`:
     * Mostrar mensajes claros y botones de resolución guiada cuando una cotización tenga problemas de pool compartido o cupo antes de proceder al cobro.

---

### FASE 3: Reingeniería del Modal `Abastecer / Editar Stock` (`stock_update_modal.dart`)
* **Objetivo:** Convertir el modal en un configurador intuitivo de cupo vendible cuando la variante es compartida, bloqueando intentos de superar el stock físico real y manteniendo el flujo normal para stock propio.
* **Archivos a modificar:**
  1. `lib/core/widgets/stock_update_modal.dart`:
     * **Detección de Modo:** Evaluar `widget.presentation.usaStockCompartido`.
     * **Si la variante es `Compartida`:**
       * Ocultar el selector `"Sumar Compra"` / `"Fijar Stock Total"`.
       * Reemplazar la cabecera por: `"Ajustar Cupo de Stock Vendible"`.
       * Calcular el máximo físico permitido: $\text{Máx Físico} = \text{poolBase} \div \text{factor}$.
       * Obtener el cupo actual: `widget.presentation.cupoMaximoVariante ?? Máx Físico`.
       * Mostrar tarjeta informativa:
         * Icono `Icons.hub_rounded`.
         * Texto: *"Asignando cupo de venta para esta variante. Máximo disponible: $maxFisico $_unidadVenta según las $poolBase unidades base compartidas."*
         * Botón de acción rápida: `[Restaurar al máximo ($maxFisico)]`.
       * **Bloqueo de Exceso + Banner Animado Temporal (4s):**
         * Si el usuario intenta aumentar con `+`, chips rápidos o teclado por encima de `maxFisico`:
           * Bloquear el valor en `maxFisico`.
           * HapticFeedback de error.
           * Activar banner animado temporal de 4 segundos:
             > *"⚠️ No puedes aumentar más del máximo permitido ($maxFisico $_unidadVenta según tus $poolBase unidades base compartidas). El cambio de la cantidad de unidades base solo se puede realizar en la ventana de Editar Producto."*
       * **Ocultar Alerta de Unidades Sueltas:** Ocultar el banner de "unidades residuales sueltas" (`_currentStockRemainder`), ya que esas unidades pertenecen al pool compartido y no son sobrantes de esta variante.
       * **Acción Guardar:** Llamar a `provider.updatePresentation(widget.presentation.id!, cupoMaximoVariante: newQuota == maxFisico ? null : newQuota)` **SIN pasar `stock_actual`**, evitando cualquier alteración del pool central.
     * **Si la variante es `Stock Propio / Independiente`:**
       * Mantener intacto el funcionamiento existente (`Sumar Compra` y `Fijar Stock Total`), actualizando `stockActual` directamente.

---

### FASE 4: Pulido Integral de Modales de Detalles y Estandarización Monetaria
* **Objetivo:** Unificar la experiencia visual en los 4 modales de detalle, garantizando adaptabilidad al modo de la variante, ausencia de truncamientos y formato monetario oficial.
* **Archivos a modificar:**
  1. `lib/features/smart_quotation/widgets/quick_sale/quick_sale_detail_modal.dart`:
     * Hacer que el banner de disponibilidad sea reactivo a `_currentSelection.usaStockCompartido`:
       * Si es compartida: mostrar Pool Base y stock final disponible considerando cupo y demanda del carrito.
       * Si es propia: mostrar `"📦 Stock Propio disponible: X [Unidad]"`.
     * En la fila de variantes, agregar `ShaderMask` horizontal para evitar cortes abruptos en bordes.
     * En los chips de variantes, incluir nombre específico + unidad + factor + precio formateado con `AppCurrency.format`.
  2. `lib/features/smart_quotation/widgets/manual/manual_quote_detail_modal.dart` (Captura 4):
     * Corregir el bug donde el banner `"Pool Base Disponible: 48 und."` se mostraba incluso para variantes de `Stock Propio`.
     * Alternar banner reactivo según el modo de `_currentSelection`.
     * Reemplazar todos los `NumberFormat.currency(...)` por `AppCurrency.format(...)`.
     * Envolver la fila de chips con `ShaderMask`.
  3. `lib/features/smart_quotation/widgets/matching/product_quote_detail_modal.dart` (Captura 5):
     * Corregir el label de los chips: formatear como `"${p.nombreEspecifico ?? ''} · ${p.unidadVenta} (x${p.unidadesPorVenta}) - ${AppCurrency.format(p.precioVentaFinal)}"`.
     * Implementar `ShaderMask` horizontal suave en la lista de chips.
     * Banner de pool reactivo únicamente si la variante seleccionada es compartida.
     * Estandarización a `AppCurrency.format(...)`.
  4. `lib/core/widgets/product_detail_modal.dart` (Catálogo):
     * Banner de stock reactivo al modo de la variante seleccionada (`_currentPres.usaStockCompartido`).
     * Visualización de stock vendible considerando `unidadesVendiblesDisponibles` (cupo).
     * Estandarización a `AppCurrency.format(...)`.

---

### FASE 5: Suite de Pruebas Automatizadas y Certificación Adversarial
* **Objetivo:** Crear una suite de pruebas comprensiva y ejecutar el análisis estático global para certificar 0 errores, 0 warnings y velocidad a 0ms.
* **Nuevo Archivo de Prueba:**
  * `test/stock_compartido_parte2_ventas_cotizaciones_y_modales_test.dart`
* **Casos de Prueba Esenciales:**
  1. **Test 1: Venta Atómica en Caja Rápida con Stock Compartido:**
     * Pool de 48 unidades base, Par x2 (stock 24) y ½ Docena x6 (stock 8).
     * Vender 1 Par -> Pool pasa a 46, Par pasa a 23, ½ Docena pasa a 7 (con 4 base sobrantes en pool sin alertas).
  2. **Test 2: Respeto de Cupo Máximo en Venta:**
     * Pool de 48, variante con cupo fijado en 6. Vender 6 es exitoso; intentar vender 7 es rechazado por exceder cupo.
  3. **Test 3: Reversión Atómica en `voidSale`:**
     * Anular la venta de 1 Par restaura el pool a 48 y las variantes a 24 y 8 respectivamente.
  4. **Test 4: Simulación Libre vs. Bloqueo en Cotizaciones:**
     * Crear cotización manual con cantidad mayor al stock disponible (permitido).
     * `validateIntegrity` detecta exceso de pool o cupo y bloquea el cobro hasta resolución.
  5. **Test 5: Modal `Abastecer / Editar Stock` en Modo Compartido:**
     * Abrir modal en variante compartida -> Solo permite editar cupo.
     * Intentar subir por encima del máximo físico es bloqueado en el máximo y activa banner temporal.
     * Aplicar cambios guarda `cupo_maximo_variante` sin alterar las unidades base del pool central.
  6. **Test 6: Modal `Abastecer / Editar Stock` en Modo Stock Propio:**
     * Variante independiente mantiene modos `"Sumar Compra"` y `"Fijar Stock Total"`.
  7. **Test 7: Reactividad de Modales de Detalle (Mixto / Compartido / Propio):**
     * Seleccionar variante compartida muestra pool base; seleccionar variante propia muestra `"📦 Stock Propio disponible"`.
  8. **Test 8: Estandarización Monetaria:**
     * Todos los modales formatean precios con `AppCurrency.format` (`S/ #,##0.00`) sin residuos `"0,00 S/"`.
* **Comandos de Certificación:**
  * `flutter test test/stock_compartido_parte2_ventas_cotizaciones_y_modales_test.dart`
  * `flutter test` (suite global)
  * `flutter analyze lib/ test/` (0 errores, 0 advertencias)

---

## 5. RÚBRICA DEL ÁRBITRO ADVERSARIAL (PARTE 2)

El árbitro adversarial someterá el código a 5 pruebas de estrés antes de certificar la Parte 2:

1. **Auditoría de Integridad del Pool en Ventas y Anulaciones:**
   * ¿El descuento de stock descuenta en unidades base ($cantidad \times factor$) sin desincronizar a las variantes hermanas?
   * ¿La anulación (`voidSale`) devuelve exactamente las unidades base al pool central?
2. **Auditoría de Inviolabilidad del Cupo:**
   * ¿Es imposible vender más unidades que el `cupo_maximo_variante` tanto en Caja Rápida como en el cobro de cotizaciones?
3. **Auditoría del Modal de Abastecimiento Compartido:**
   * ¿El modal de abastecimiento en modo compartido altera exclusivamente el cupo sin tocar las unidades base del pool?
   * ¿Impide superar el máximo físico y muestra el banner temporal animado de 4 segundos?
   * ¿Se eliminó la alerta alarmista de "unidades sobrantes" en variantes compartidas?
4. **Auditoría de Reactividad en Modales de Detalle:**
   * En productos en modo `MIXTO`, ¿el banner de disponibilidad conmuta fielmente entre Pool Base y Stock Propio al cambiar de variante?
   * ¿Los chips de variantes muestran nombre, factor y precio completo con `ShaderMask` lateral?
   * ¿Se erradicó por completo el formato antiguo (`0,00 S/`) a favor de `AppCurrency.format`?
5. **Auditoría de Salud Estática y Dinámica:**
   * ¿El análisis estático arroja 0 errores y 0 advertencias?
   * ¿Pasan el 100% de las pruebas automatizadas?

---

## 6. TABLA RESUMEN DE ARCHIVOS A INTERVENIR

| Archivo | Rol en el Sistema | Modificaciones Planificadas |
|---|---|---|
| `sales_service.dart` | Motor Transaccional SQLite de Ventas | Deducción y reversión atómica de unidades base en pool, verificación de `cupo_maximo_variante`, trazabilidad en `stock_ledger`. |
| `quick_sale_provider.dart` | Gestor de Estado Caja Rápida | Acotar stock vendible por `cupoMaximoVariante`, sincronización reactiva a 0ms. |
| `matching_model.dart` | Modelos de Cotización y Matching | Agregar `cupoMaximoVariante` a `MatchedProduct`, serialización y clonación. |
| `quotation_service.dart` | Integridad Pre-Venta de Cotizaciones | Validación de demanda acumulada de pool compartido y cupos individuales en `validateIntegrity`. |
| `stock_update_modal.dart` | Modal Abastecer / Editar Stock | Modo Cupo exclusivo para variantes compartidas con bloqueo > máx físico, banner temporal 4s y eliminación de alerta de sobrantes. |
| `quick_sale_detail_modal.dart` | Detalle en Caja Rápida | Banner reactivo compartido vs. propio, chips con nombre/factor/precio y `ShaderMask`, `AppCurrency.format`. |
| `manual_quote_detail_modal.dart` | Detalle en Cotización Manual | Banner reactivo compartido vs. propio, corrección de formato monetario, `ShaderMask`. |
| `product_quote_detail_modal.dart` | Detalle en Cotización Inteligente | Inclusión de nombre específico en chips, `ShaderMask` para evitar cortes, `AppCurrency.format`. |
| `product_detail_modal.dart` | Detalle en Catálogo General | Banner reactivo según variante, visualización con cupo vendible, `AppCurrency.format`. |
| `inventory_provider.dart` | Proveedor Global de Inventario | Soporte de `cupoMaximoVariante` en `updatePresentation` y método `updateVariantQuota`. |
| `test/...parte2...test.dart` | Suite de Pruebas Automatizadas | 8 pruebas integrales de ventas, reversiones, cupos, cotizaciones y modales. |

---

*Fin del Plan Maestro Parte 2. Listo para revisión y aprobación por parte del usuario.*
