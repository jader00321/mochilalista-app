# Plan de Trabajo: Reestructuración del Módulo Scanner

## Resumen de la Auditoría

He analizado en profundidad **14 archivos** del módulo Scanner. Los hallazgos se organizan en 3 capas de criticidad: **Encoding/IA**, **Motor Financiero** y **UI/UX**.

---

## Diagnóstico Detallado

### 🔴 Hallazgo 1 — Encoding Roto: caracteres con tilde/ñ llegan distorsionados

**Archivo:** [scanner_ai_service.dart L38-44](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/services/scanner_ai_service.dart#L38-L44)

```dart
// ACTUAL — No hay control de encoding en la respuesta
String cleanJson = response.text!
    .replaceAll('```json', '')
    .replaceAll('```', '')
    .trim();
final decoded = json.decode(cleanJson);
```

El SDK de `google_generative_ai` devuelve `response.text` como un `String` Dart, que internamente es UTF-16. Sin embargo, cuando el modelo responde con acentos (`ñ`, `á`, `é`) en nombres de productos peruanos ("Cuaderno Stanford Triple Renglón", "Lápiz Mongol Nº 2"), estos caracteres pueden llegar **mal codificados** si:
1. El JSON contenía secuencias de escape Unicode raw (`\u00f1`) que `json.decode` maneja bien, O
2. La respuesta venía con bytes Latin-1/Windows-1252 embebidos que Flutter interpreta como UTF-8 roto → `Ã±` en vez de `ñ`.

**El problema real** es que no hay **ningún sanitizado post-decodificación**. Si la IA devuelve `"L\u00e1piz"` funciona, pero si devuelve bytes crudos con codificación mixta, se rompe silenciosamente.

**Solución:**
- Añadir un paso de sanitización UTF-8 explícita: `utf8.decode(response.text!.codeUnits, allowMalformed: true)` antes de `json.decode`.
- Agregar una función `_sanitizeEncoding()` que normalice secuencias Unicode comunes del español peruano.

---

### 🔴 Hallazgo 2 — El Prompt no separa correctamente Marca vs Nombre vs Variante

**Archivo:** [scanner_ai_service.dart L56-101](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/services/scanner_ai_service.dart#L56-L101)

```dart
// ACTUAL — Instrucciones vagas para separar campos
'producto_padre_estimado': "El nombre general limpio"
'variante_detectada': "Características específicas, colores, tamaños"
'marca_detectada': "Solo si se menciona explícitamente"
```

**Problemas encontrados:**
1. **Sin Few-Shot Examples:** La IA no tiene ejemplos concretos de facturas peruanas de papelería. El prompt dice "nombre general limpio" pero no dice qué incluir/excluir. Resultado: la IA pone `"Faber Castell Lápiz"` en `producto_padre_estimado` en vez de separar `marca = "Faber Castell"` y `padre = "Lápiz"`.
2. **Descripción original no se preserva bien:** Cuando la factura dice `"LAPIZ FC MONGOL HB X 12"`, la IA tiene que *inferir* que `FC` = `Faber Castell`, `MONGOL` es la línea, `HB` es la variante y `X 12` es la presentación. Sin ejemplos, falla.
3. **No hay instrucción sobre `unidad_venta`:** El prompt pide `unidad_venta` pero no explica la diferencia entre la unidad de compra del proveedor (`ump_compra`) y la unidad en la que el comerciante revende. El campo llega inconsistente.
4. **No hay instrucción sobre separar componentes:** Si la factura tiene `"CUADERNO STANFORD A4 CUADR. X 60HJ"`, la IA debe entender que `STANFORD` es marca, `CUADERNO` es padre, `A4 Cuadriculado 60 hojas` es variante. Sin ejemplos, esto es ambiguo.

**Solución:** Reescribir el prompt con:
- **Few-Shot Examples**: 3-4 ejemplos reales de facturas de papelería peruana con la respuesta JSON esperada.
- **Reglas explícitas de prioridad**: "La marca NUNCA va en producto_padre_estimado", "Si no puedes identificar la marca, deja marca_detectada vacío".
- **Chain-of-thought implícito**: Pedir a la IA que primero identifique la marca, luego el nombre base, y finalmente las variantes.
- **Instrucción clara de unidad_venta**: "La unidad de venta es cómo el comerciante revende al público. Si compra Docenas pero vende por Unidad, ump_compra='DOC', unidad_venta='Unidad'."

---

### 🔴 Hallazgo 3 — Cálculo de Costo Unitario Incorrecto en el Matching Engine

**Archivo:** [scanner_matching_engine.dart L99-102](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/services/scanner_matching_engine.dart#L99-L102)

```dart
// ACTUAL — Solo divide precio por lote, ignora la cantidad comprada
double costoUnitario = item.unidadesPorLote > 0
    ? (item.precioUmpProveedor / item.unidadesPorLote)
    : 0;
```

**El Bug:** Esta fórmula calcula `costo = precioUmpProveedor / unidadesPorLote`, pero `precioUmpProveedor` es el precio **de un lote** (ej: precio de 1 Docena), no el total pagado. La fórmula correcta debería ser:

```
costoUnitarioIndividual = totalPagoLote / (cantidadUmpComprada × unidadesPorLote)
```

**Ejemplo real:**
- Compro 0.25 MLL (250 unidades) de lápices, pago S/ 45.00 total.
- `cantidadUmpComprada = 0.25`, `unidadesPorLote = 1000`, `totalPagoLote = 45.00`
- **Actual:** `costoUnitario = precioUmpProveedor / 1000` → depende de un campo que puede estar vacío o inferido.
- **Correcto:** `costoUnitario = 45.00 / (0.25 × 1000) = 45.00 / 250 = S/ 0.18`

Adicionalmente en el `VariantEditorRow` la fórmula (línea 104) **sí está correcta**: `costoBaseIndiv = totalPago / (cantComprada * unidPorLote)`. Pero la discrepancia entre la fórmula del Engine y la del Widget causa que el costo inicial mostrado sea diferente al que el widget recalcula.

**Solución:** Unificar la fórmula de costo en un solo lugar (utilidad compartida) y usarla tanto en el engine como en el widget.

---

### 🟡 Hallazgo 4 — Matching Engine: búsqueda SQL demasiado simplista

**Archivo:** [scanner_matching_engine.dart L46-53](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/services/scanner_matching_engine.dart#L46-L53)

```dart
// ACTUAL — LIKE con nombre completo
final prodQuery = await db.query(
  'productos',
  where: 'negocio_id = ? AND nombre LIKE ?',
  whereArgs: [negocioId, '%$searchName%'],
  limit: 1,
);
```

**Problemas:**
1. **Usa `LIKE` con el nombre padre completo**, que puede incluir marca, variante, o basura de la IA. Si `searchName = "Cuaderno Stanford A4"`, el `LIKE '%Cuaderno Stanford A4%'` fallará si en la BD se guardó como `"Cuaderno Stanford"` (sin `A4`).
2. **Solo retorna 1 resultado** (`limit: 1`), perdiendo posibles mejores matches.
3. **No hace fuzzy matching**: No considera variaciones ortográficas ni abreviaciones (`"CDRNO"` vs `"Cuaderno"`).
4. **No busca por marca**: El motor no intenta vincular `marca_detectada` con la tabla `marcas` en la BD.

**Solución:**
- Dividir `searchName` en tokens y buscar con `AND` parcial: `WHERE nombre LIKE '%Cuaderno%' AND nombre LIKE '%Stanford%'`.
- Retornar múltiples candidatos (limit: 5) y ordenar por coincidencia.
- Implementar un score de confianza real basado en tokens coincidentes / tokens totales.
- Añadir matching de marca contra la tabla `marcas`.

---

### 🟡 Hallazgo 5 — Sin matching de variante (Presentación) inteligente

**Archivo:** [scanner_matching_engine.dart L70-93](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/services/scanner_matching_engine.dart#L70-L93)

```dart
// ACTUAL — Toma la PRIMERA presentación que encuentre
if (presQuery.isNotEmpty) {
  presMatch = MatchResult(
    estado: "MATCH_SUGERIDO",
    confianza: 80,
    datos: MatchData(
      id: presQuery.first['id'] as int,  // ← SIEMPRE la primera
```

Si un producto tiene 5 presentaciones ("Azul A4", "Rojo A4", "Verde A5", etc.), el engine siempre elige la **primera** sin importar cuál se parece más a la variante detectada por la IA. Debería comparar `varianteDetectada` contra `nombre_especifico` de cada presentación y elegir la mejor.

**Solución:** Iterar sobre todas las presentaciones y calcular un score de similitud string contra `varianteDetectada`, eligiendo la de mayor confianza.

---

### 🟡 Hallazgo 6 — Encoding roto en `variant_editor_row.dart` (caracteres mojibake)

**Archivo:** [variant_editor_row.dart L7](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_editor_row.dart#L7) y [L76](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_editor_row.dart#L76)

```dart
// Línea 7: "ðŸ"¥ WIDGET CON ESTADO" ← Emoji roto
// Línea 76: "ðŸ"¥ DETECCIÃ"N INTELIGENTE" ← Tilde rota
```

Los comentarios del archivo tienen caracteres mojibake (`ðŸ"¥` en vez de 🔥, `Ã"N` en vez de `ÓN`). Esto indica que el archivo fue guardado con encoding incorrecto en algún momento. No afecta la ejecución pero es indicativo de un problema de toolchain.

**Solución:** Re-guardar el archivo con UTF-8 BOM o limpiar los comentarios rotos.

---

### 🟢 Hallazgo 7 — Factor de ganancia hardcodeado en 1.35

**Archivos:**
- [scanner_matching_engine.dart L122](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/services/scanner_matching_engine.dart#L122): `factorGananciaVentaSugerido: 1.35`
- [variant_editor_row.dart L108](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_editor_row.dart#L108): `margen = 1.35`

El margen de ganancia por defecto está hardcodeado en `1.35` (35%) en múltiples lugares. Para un negocio de papelería en Perú, algunos productos tienen márgenes del 20% y otros del 80%. Debería ser configurable por categoría o basado en el margen histórico del producto si ya existe.

**Solución:**
- Si la presentación existe en BD, usar su `factor_ganancia_venta` actual como base.
- Si es producto nuevo, usar el margen promedio de la categoría del negocio.
- Fallback: 1.35 si no hay datos históricos.

---

## Fases de Implementación

---

## Fase 1: Corrección de Encoding y Optimización del Prompt IA

### Objetivos
- Eliminar toda distorsión de caracteres acentuados
- Mejorar drásticamente la precisión de extracción de Marca, Nombre y Variante
- Mejorar la extracción de datos financieros (cantidades, totales)

### Cambios Propuestos

#### [MODIFY] [scanner_ai_service.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/services/scanner_ai_service.dart)
1. **Sanitización UTF-8**: Añadir `_sanitizeResponse()` que aplica `utf8.decode(text.codeUnits, allowMalformed: true)` + normalización de secuencias Unicode comunes.
2. **Reescritura completa del prompt** usando Few-Shot Prompting:
   - 3 ejemplos reales de facturas de papelería peruana (Stanford, Faber Castell, Artesco)
   - Reglas explícitas de separación: "La marca NUNCA aparece en producto_padre_estimado"
   - Instrucción clara sobre `unidad_venta` vs `ump_compra`
   - Instrucción de redondeo matemático: "Si total_pago_lote y cantidad_ump_comprada están disponibles, calcula precio_ump_proveedor como total_pago_lote / cantidad_ump_comprada"
3. **Configuración del modelo**: Añadir `generationConfig` con `responseMimeType: 'application/json'` y `temperature: 0.1` para respuestas más determinísticas.

#### [MODIFY] [variant_editor_row.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_editor_row.dart)
- Limpiar comentarios con encoding roto (mojibake).

---

## Fase 2: Refactor del Motor Financiero y Matching

### Objetivos
- Unificar la fórmula de costo unitario en un solo lugar
- Mejorar la inteligencia del matching de productos y presentaciones
- Implementar margen dinámico basado en historial

### Cambios Propuestos

#### [NEW] [scanner_cost_engine.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/services/scanner_cost_engine.dart)
Utilidad compartida con las fórmulas financieras:
- `calculateUnitCost(totalPago, cantidadUmp, unidadesPorLote)` → costo unitario individual
- `calculatePresentationCost(unitCost, unidadesPorVenta)` → costo por presentación de venta
- `suggestSalePrice(cost, margin)` → precio de venta sugerido
- `calculateMargin(salePrice, cost)` → margen calculado
- `suggestDynamicMargin(categoryId, negocioId)` → margen promedio histórico por categoría

#### [MODIFY] [scanner_matching_engine.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/services/scanner_matching_engine.dart)
1. **Matching tokenizado**: Dividir `searchName` en tokens y buscar con múltiples `LIKE`.
2. **Score de confianza real**: Calcular `tokensCoincidentes / tokensTotal * 100`.
3. **Matching de marca**: Buscar `marca_detectada` en la tabla `marcas`.
4. **Matching de presentación inteligente**: Comparar `varianteDetectada` contra todas las `nombre_especifico` del producto padre, elegir la mejor.
5. **Usar `scanner_cost_engine.dart`** para el cálculo de costos en vez de la fórmula inline actual.
6. **Margen dinámico**: Si la presentación ya existe, usar su `factor_ganancia_venta` actual; si no, usar margen promedio de la categoría.

#### [MODIFY] [variant_editor_row.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_editor_row.dart)
- Refactorizar `_recalcularMatematica()` para usar `ScannerCostEngine` en lugar de fórmulas inline.
- Esto garantiza que el cálculo del engine y el de la UI siempre coincidan.

#### [MODIFY] [variant_price_calculator.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_price_calculator.dart)
- Refactorizar `_recalcularModal()` para usar `ScannerCostEngine`.

---

## Fase 3: Rediseño Total de la UI/UX y Animaciones

### Objetivos
- Interfaz profesional y limpia para la revisión de facturas
- Validación visual por estados (Match exacto ✅, Nuevo 🆕, Requiere revisión ⚠️)
- Transiciones suaves y campos fáciles de editar
- UX de edición financiera intuitiva con sliders y cálculos en tiempo real

### Cambios Propuestos

#### [MODIFY] [invoice_review_screen.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/screens/invoice_review_screen.dart)
1. **Header mejorado**: Añadir resumen visual con chips de estado (✅ Completos, ⚠️ Revisar, 🆕 Nuevos).
2. **Split View optimizado**: Mejorar el divisor para que sea más intuitivo con iconos de grip más grandes.
3. **Tarjetas de item premium**: Rediseñar con bordes de color según estado, animaciones de entrada staggered.
4. **Quick-edit inline**: Permitir editar nombre/marca/variante directamente en la tarjeta sin abrir modal.

#### [MODIFY] [review_item_card.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/review/review_item_card.dart)
1. **Indicador visual de confianza**: Borde lateral de color (verde = datos completos, naranja = parcial, rojo = falta info crítica).
2. **Layout de 2 zonas**: Zona superior (Descripción: Nombre, Marca, Variante) y zona inferior (Finanzas: Cantidad, Total, UMP).
3. **Validación en tiempo real**: Resaltar campos vacíos o sospechosos con borde rojo sutil.
4. **Animación de eliminación**: `AnimatedList` con `SlideTransition` al eliminar ítems.

#### [MODIFY] [invoice_staging_screen.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/screens/invoice_staging_screen.dart)
1. **Barra de progreso global**: Mostrar porcentaje de ítems clasificados vs pendientes.
2. **Chips de filtro**: Filtrar por estado (Todos, Vinculados, Nuevos, Sin Revisar).
3. **Animaciones de transición**: Fade-in al cargar, slide al navegar entre ítems.
4. **Botón de guardado mejorado**: Progress indicator lineal con porcentaje visible.

#### [MODIFY] [staging_product_group_card.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/staging_product_group_card.dart)
1. **Header con indicador visual**: Icono de estado (✅/🆕/⚠️) + nombre + marca + badge de match.
2. **Animación de expansión**: `AnimatedCrossFade` para mostrar/ocultar variantes.
3. **Color-coding**: Fondo verde suave para matches confirmados, azul para nuevos, naranja para pendientes.

#### [MODIFY] [variant_editor_row.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_editor_row.dart)
1. **Slider de margen**: Reemplazar el campo de texto del margen por un `Slider` con rango 1.10 a 3.00, con labels "Bajo (10%)" → "Alto (200%)".
2. **Cálculo visual en tiempo real**: Mostrar `Costo → ×Margen → Precio` como una fórmula visual animada.
3. **Botón de "restaurar margen histórico"**: Si el producto ya existe en BD, un botón para volver al margen anterior.

#### [MODIFY] [variant_price_calculator.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_price_calculator.dart)
1. **Tabla comparativa mejorada**: Layout de 2 columnas más claro (Actual vs Nuevo) con iconos y colores.
2. **Toggle switches**: Reemplazar checkboxes por `CupertinoSwitch` o `Switch.adaptive` más elegantes.
3. **Resumen de impacto**: Al final del modal, mostrar un resumen de "¿Qué cambiará?" con los valores antes/después.

---

## Fase 4: Refinamiento de Interfaz y Corrección de Casos Borde (Post-Análisis Visual)

### Objetivos
- Corregir problemas de formato en decimales detectados en las capturas.
- Evitar que se muestre la palabra `null` en nombres de presentación.
- Eliminar por completo los últimos restos de "mojibake" detectados en etiquetas específicas.
- Asegurar que la lógica de estadísticas de la cabecera funcione con total precisión.

### Problemas Detectados en las Capturas (No previstos originalmente)
1. **Decimales excesivos**: En los campos "Costo Real Base" (ej. S/ 14.4667 c/u), "Costo Unit" (S/ 1.2083) y "Precio Venta Final" (S/ 30.375). Esto rompe el diseño y no es profesional para finanzas.
2. **Presentaciones `null`**: En la vista de "Variante Existente" (dropdown azul), el nombre de la variante se muestra como `null (Disp: 12)` si la BD no retorna un `nombre_especifico`.
3. **Restos de Mojibake**: Aún persisten cadenas mal codificadas en el widget de grupos (`Añadir otra presentación`) y en las etiquetas de nueva variante (`Nombre Específico / Detalle`, `Compró`, `Cálculo Factura`).
4. **Matemáticas de cabecera confusas**: En la captura, la barra muestra `Actualizar: 5`, `Crear: 15` y `Total: 15`. Si los vinculados y nuevos suman más que el total, la lógica de la variable `totalActiveVariants` en `ScannerProvider` tiene un problema de conteo que requiere ser ajustado.

### Cambios Propuestos

#### [MODIFY] [review_item_card.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/review/review_item_card.dart) y [variant_editor_row.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_editor_row.dart)
- **Corrección de Mojibake**: Reemplazar textos estáticos que contienen `Ã±` y `Ã³` por sus valores correctos (`ñ`, `ó`, `í`, `á`).
- **Formateo inteligente**: Integrar de forma global un formateo de precios para que solo use máximo 2 a 3 decimales si es necesario, o lo redondee limpiamente con la función `_formatSmartDecimal()`.

#### [MODIFY] [staging_product_group_card.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/staging_product_group_card.dart)
- **Manejo de `null` en Dropdown**: Si `nombre_especifico` es `null`, reemplazarlo por la cadena `"General"` u ocultarlo y mostrar solo `unidad_venta`. 
- **Corrección de Mojibake**: Corregir texto del botón "Añadir otra presentación (Fraccionamiento)".

#### [MODIFY] [scanner_provider.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/providers/scanner_provider.dart)
- **Corrección de la lógica `Total`**: Validar cómo se calculan `countLinked`, `countNew` y `totalActiveVariants` para que la suma sea congruente en la barra de progreso (ej. si una variante nueva está dentro de un producto vinculado, verificar su contabilidad).

---

## Resumen de Impacto

| Categoría | Cambios | Impacto |
|---|---|---|
| 🔴 Encoding | 2 | Elimina distorsión de acentos y ñ en datos extraídos |
| 🔴 Prompt IA | 1 | Mejora drástica en separación Marca/Nombre/Variante |
| 🔴 Cálculo Financiero | 3 | Costo unitario correcto y consistente en todo el flujo |
| 🟡 Matching | 3 | Matching inteligente por tokens, marca y presentación |
| 🟢 Margen Dinámico | 1 | Márgenes basados en historial, no hardcodeados |
| 🎨 UI/UX | 6 | Interfaz premium con estados visuales y micro-animaciones |
| 🐛 Fase 4 (Fixes Visuales) | 3 | Corrección de decimales, labels nulos y matemática de totales en la UI |

> [!IMPORTANT]
> He añadido esta nueva **Fase 4** al plan para solucionar los defectos visuales detectados en tus capturas recientes. ¿Apruebas que proceda con su implementación?
