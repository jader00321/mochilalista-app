# Plan de Trabajo: Perfeccionamiento del Flujo de Conciliación de Listas Escolares

## Diagnóstico Visual Completo (Capturas Analizadas)

### Capturas de `matching_screen` (nuevas):

| # | Problema Visual | Severidad | Archivo Responsable |
|---|---|---|---|
| 1 | **Título `"Cotización Inteli..."` truncado** en AppBar | 🔴 Alta | [`matching_screen.dart` L533](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/matching_screen.dart#L533) |
| 2 | **0/15 Listos** — El algoritmo no encontró ningún match | 🔴 Crítica | [`matching_service.dart` L24-34](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/matching_service.dart#L24-L34) |
| 3 | **Campos del header truncados**: `"Colegio / In..."`, `"Nombre Co..."`, `"7° Básico a 4..."` | 🟡 Media | [`manual_quote_institution_header.dart` L36](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/manual/manual_quote_institution_header.dart#L36), [`manual_quote_client_header.dart` L73](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/manual/manual_quote_client_header.dart#L73) |
| 4 | **Banner "IA: Promociones analizadas"** siempre visible incluso con 0 matches y 0 bundles aplicados | 🟡 Media | [`matching_screen.dart` L802-824](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/matching_screen.dart#L802-L824) |
| 5 | **FAB menu con fondo oscuro cubre todo** sin animación de entrada | 🟡 Media | [`matching_screen.dart` L708-749](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/matching_screen.dart#L708-L749) |

### Captura anterior (matching vinculado con overflow):

| # | Problema Visual | Severidad | Archivo Responsable |
|---|---|---|---|
| 6 | **Texto "Unitario" renderizado verticalmente** (letras apiladas U-n-i-t-a-r-i-o) | 🔴 Crítica | [`matching_item_row.dart` L183-209](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/matching/matching_item_row.dart#L183-L209) |
| 7 | **Badge azul `"UND (x1)"`** redundante con la zona de precios | 🟡 Media | [`matching_item_row.dart` L143-147](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/matching/matching_item_row.dart#L143-L147) |
| 8 | **Selector +/- desborda** límites de la tarjeta | 🔴 Alta | [`matching_item_row.dart` L213-247](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/matching/matching_item_row.dart#L213-L247) |

---

## Análisis de Lógica de Promociones

### Estado Actual en [`matching_provider.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/providers/matching_provider.dart#L165-L224):

```dart
// _detectAndApplyBundles() busca bundles activos y verifica si los productos
// matcheados coinciden con los requeridos por el paquete
for (var req in requiredItems) {
  final found = _pairs.where((p) => p.selectedProduct?.productId == req.productoId).toList();
  if (found.isEmpty) { canFormBundle = false; break; }
}
```

**Problemas identificados:**
1. **Depende de que el matching haya funcionado**: Si el algoritmo no vincula productos (como vemos en la captura: 0/15), `_detectAndApplyBundles` nunca encontrará coincidencias y el banner "IA: Promociones analizadas" se muestra vacío e incoherente.
2. **El banner es estático**: Se muestra SIEMPRE sin importar si hay bundles activos o si el análisis fue exitoso. Debería ocultarse o cambiar su mensaje según el estado real.
3. **El `toggleBundleGrouping(-1, true)` del botón "Re-Agrupar"** funciona correctamente, pero vuelve a llamar `_detectAndApplyBundles` que seguirá sin encontrar nada si no hay matches.
4. **La lógica `matchedPairsForBundle.length == requiredItems.length`** (L213) es correcta conceptualmente pero frágil: no considera `cantidadRequerida` del `BundleItemModel`, solo cuenta items 1 a 1.

**Veredicto:** La lógica de promociones es **funcionalmente correcta** pero su presentación visual es **incoherente** cuando no hay matches. No necesita un refactor de lógica, sino una mejora de presentación condicional.

---

## Fase 1: Optimización del Algoritmo de Búsqueda por Palabras Clave

> [!IMPORTANT]
> **Esta es la fase más crítica.** Sin esto, todo lo demás (promociones, tarjetas, totales) queda roto porque nada se vincula.

### Cambios en [`matching_service.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/matching_service.dart):

**Problema raíz (L24-34):** La búsqueda SQL actual exige coincidencia exacta del nombre completo:
```sql
AND (p.nombre LIKE '%Goma de borrar%' OR pr.nombre_especifico LIKE '%Goma de borrar%')
LIMIT 1
```

**Solución: Sistema de Tokenización + Scoring**

1. **Crear helper `_normalizeAndTokenize(String input)`:**
   - Convertir a minúsculas.
   - Eliminar tildes (`á→a`, `é→e`, `í→i`, `ó→o`, `ú→u`, `ñ→n`).
   - Dividir por espacios en tokens.
   - Filtrar stopwords (`de`, `la`, `el`, `en`, `y`, `a`, `un`, `una`, `los`, `las`, `por`, `para`, `con`).
   - Filtrar tokens menores a 2 caracteres (excepto números como "2B").

2. **Construir query SQL dinámico por tokens:**
   ```sql
   WHERE p.negocio_id = ? AND pr.activo = 1
   AND (
     p.nombre LIKE '%goma%' OR p.nombre LIKE '%borrar%'
     OR pr.nombre_especifico LIKE '%goma%' OR pr.nombre_especifico LIKE '%borrar%'
     OR m.nombre LIKE '%goma%' OR m.nombre LIKE '%borrar%'
   )
   LIMIT 20
   ```

3. **Scoring en memoria (post-query):**
   - Para cada fila candidata, calcular un puntaje:
     - **+30 pts** por token que aparezca en `p.nombre` (producto padre).
     - **+20 pts** por token que aparezca en `pr.nombre_especifico` (presentación).
     - **+15 pts** por token que coincida con `m.nombre` (marca).
     - **+10 pts** bonus si `item.brand` coincide con la marca del producto.
   - Seleccionar la fila con el score más alto.
   - Clasificar: score ≥ 60 → `AUTO`, score 30-59 → `SUGGESTION`, score < 30 → `NONE`.

4. **Guardar el score real** en `BackendMatchResult.score` para que el UI pueda mostrar la confianza del match.

---

## Fase 2: Corrección de Overflows y Rediseño de Tarjetas Vinculadas

### Cambios en [`matching_item_row.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/matching/matching_item_row.dart):

**Problema 1: "Unitario" vertical (L183-209)**
La fila inferior tiene esta estructura actual:
```
Row(
  Expanded(flex: 3)    ← Columna "Unitario" + Precio
  SizedBox(width: 4)
  Column(              ← Botones +/- SIN restricción de ancho
    Container(h: 35)   ← se expande sin límite
  )
)
```
Cuando la pantalla es estrecha, el `Column` sin `Expanded` empuja al `Expanded(flex:3)` hasta dejarlo con ~20px de ancho, forzando el renderizado vertical de "Unitario".

**Solución:**
- Envolver el control de cantidad en un `SizedBox(width: 100)` con ancho fijo.
- Usar `Expanded` para la columna de precios (ya lo tiene, pero el `Column` de botones necesita restricción).
- Reemplazar el label "Unitario" por un formato compacto inline:
  ```dart
  // Antes: Column("Unitario", precio)
  // Después: FittedBox con precio directo
  FittedBox(
    fit: BoxFit.scaleDown,
    child: Text("S/ 16.88 c/u", style: ...bold),
  )
  ```

**Problema 2: Badge azul redundante (L143-147)**
- **Eliminar** el `Container` que muestra `"UND (x1)"`. La unidad ya se informará integrada en el precio como `"S/ 16.88 c/u"` o en un chip sutil al lado del nombre.

**Problema 3: Estado "Sin vincular" truncado (L59)**
- El texto `"Tocar para vincular"` se trunca en pantallas estrechas → envolver con `FittedBox(fit: BoxFit.scaleDown)`.

---

## Fase 3: Responsividad en AppBars y Headers

### 3.1 AppBar de [`matching_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/matching_screen.dart#L532-L555):

```dart
// Antes (L533):
title: Text(isClient ? "Completar mi Pedido" : "Cotización Inteligente", ...)

// Después:
title: FittedBox(
  fit: BoxFit.scaleDown,
  alignment: Alignment.centerLeft,
  child: Text(isClient ? "Completar mi Pedido" : "Cotización Inteligente", ...),
)
```

Badge "X/Y Listos" (L548-553): Envolverlo en `Flexible` para que no empuje al título.

### 3.2 AppBar de [`extraction_result_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/extraction_result_screen.dart#L117-L127):

```dart
// Envolver título con FittedBox:
title: FittedBox(
  fit: BoxFit.scaleDown,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(isClient ? "Revisa tu Lista Escolar" : "Validar Datos Extraídos", ...),
      Text("${provider.items.length} productos identificados", ...),
    ],
  ),
)
```

### 3.3 Campos truncados en headers:

En [`manual_quote_institution_header.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/manual/manual_quote_institution_header.dart#L36-L38):
- Los labels `"Colegio / Institución"` y `"Grado / Sección"` se truncan → acortarlos a `"Colegio"` y `"Grado"` respectivamente, o usar `labelStyle` con `overflow: TextOverflow.ellipsis`.

En [`manual_quote_client_header.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/manual/manual_quote_client_header.dart#L73):
- `"Nombre Completo"` se corta a `"Nombre Co..."` → acortar label a `"Nombre"` o usar un hint más compacto.

---

## Fase 4: Rediseño y Mejora de `extraction_result_screen`

### Cambios en [`extraction_result_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/extraction_result_screen.dart):

1. **AppBar responsivo** (ya descrito en Fase 3.2).

2. **Animaciones de entrada en las tarjetas `_InternalItemCard`:**
   - Actualmente las tarjetas aparecen de golpe sin ninguna transición.
   - Implementar `AnimatedList` o `staggered animation` para que cada tarjeta entre con un fade + slide sutil desde abajo (delay escalonado de 50ms por item).

3. **Animación del divider "ARRASTRAR":**
   - El divider ya cambia de color al arrastrar (`dragging`), pero puede mejorar con una animación de pulso (`AnimatedScale`) en estado idle para llamar la atención del usuario.

4. **Botón "COTIZAR" / "BUSCAR PRODUCTOS" del AppBar:**
   - Verificar que no desborde en pantallas estrechas. Usar `Flexible` en la fila de `actions`.

5. **Mejora visual de `_InternalItemCard`:**
   - Agregar un indicador visual de completitud (borde verde si `fullName` no está vacío, naranja si falta algún campo).
   - Animar la eliminación de items (slide-out lateral con `AnimatedSwitcher`).

---

## Fase 5: Pulido General de `matching_screen` — Promociones, Animaciones, Coherencia

### 5.1 Banner de Promociones Condicional

En [`matching_screen.dart` L802-824](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/matching_screen.dart#L802-L824):

```dart
// Antes: SIEMPRE visible
Container(
  child: Text("IA: Promociones analizadas", ...)
)

// Después: Solo visible si hay bundles activos Y al menos 1 match
if (provider.activeBundles.isNotEmpty && provider.matchedCount > 0) ...[
  _buildPromotionsBanner(provider, isDark, theme),
]
```

- Si `matchedCount == 0`, no tiene sentido analizar promociones.
- Si `activeBundles.isEmpty`, el banner es falso — no hay nada que "Re-Agrupar".
- El texto "IA: Promociones analizadas" debería ajustarse dinámicamente:
  - Si se encontraron paquetes: `"✨ X paquete(s) detectado(s)"`.
  - Si se analizaron pero no aplican: `"No se encontraron paquetes aplicables"`.

### 5.2 Animaciones de Transición en Tarjetas

- **Cuando un item se vincula** (pasa de "Tocar para vincular" a tarjeta con producto): implementar `AnimatedSwitcher` con `crossFadeState` para una transición suave.
- **Cuando un item se desvincula**: fade-out del producto → fade-in del estado vacío.

### 5.3 FAB Menu con Animación de Entrada

En [`matching_screen.dart` L708-749](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/matching_screen.dart#L708-L749):
- El overlay oscuro aparece de golpe (`GestureDetector(child: Container(color: Colors.black87))`).
- Reemplazar por `AnimatedOpacity` para un fade-in suave de 200ms.
- Los botones del SpeedDial podrían entrar con `SlideTransition` escalonado (cada uno con 50ms de delay).

### 5.4 Coherencia Visual del Bottom Bar

En [`matching_smart_bottom_bar.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/matching/matching_smart_bottom_bar.dart):
- Cuando el total es `S/ 0.00` (porque no hay matches), el text `displayLarge` con "S/ 0.00" en azul se siente incoherente.
- Si `totalNetAmount == 0`, mostrar un mensaje alternativo como `"Vincula productos para ver el total"` en gris, en lugar del monto.

---

## Resumen de Archivos a Modificar

| Archivo | Fase | Tipo |
|---|---|---|
| [`matching_service.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/matching_service.dart) | 1 | Refactor completo de `runBatchMatching` |
| [`matching_item_row.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/matching/matching_item_row.dart) | 2 | Rediseño de layout de tarjeta |
| [`matching_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/matching_screen.dart) | 3, 5 | AppBar + banner promociones + animaciones FAB |
| [`extraction_result_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/extraction_result_screen.dart) | 3, 4 | AppBar + animaciones de tarjetas |
| [`manual_quote_institution_header.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/manual/manual_quote_institution_header.dart) | 3 | Labels responsivos |
| [`manual_quote_client_header.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/manual/manual_quote_client_header.dart) | 3 | Labels responsivos |
| [`matching_smart_bottom_bar.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/matching/matching_smart_bottom_bar.dart) | 5 | Mensaje condicional cuando total = 0 |

---

## Plan de Verificación

| Fase | Criterio de Éxito |
|---|---|
| **1** | Escanear una lista de 15 ítems escolares → se espera ≥10/15 vinculaciones automáticas (vs. 0/15 actual) |
| **2** | En dispositivo de 360dp de ancho: cero overflows, texto "Unitario" nunca vertical, botones +/- dentro de la tarjeta |
| **3** | Títulos del AppBar nunca truncados con "...", campos del header legibles |
| **4** | Tarjetas de extracción entran con animación suave, el divider pulsa sutilmente |
| **5** | Banner de promociones oculto si no hay matches; FAB menu con fade-in; bottom bar muestra mensaje informativo cuando total = 0 |

> [!IMPORTANT]
> **Aprobación Requerida:** Este plan NO modifica código hasta que tú lo apruebes. Las 5 fases están ordenadas por prioridad de impacto. ¿Estás de acuerdo con el plan o deseas ajustar algún punto antes de proceder?
