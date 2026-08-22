# Plan de Trabajo: Depuración Crítica y Rediseño del Módulo "Cotización Inteligente" (v2)

## Contexto y Diagnóstico

El módulo de Cotización Inteligente (`features/smart_quotation/`) presenta 7 problemas que afectan la estabilidad del estado, la precisión de la búsqueda, la lógica de guardado de ofertas y la experiencia visual. Este plan aborda cada uno con la máxima profundidad técnica.

---

## Hallazgos del Análisis Profundo

### 🔴 BUG 1: Pérdida de Interactividad (onTap muere tras vincular)

**Archivos raíz:** [`matching_product_search_modal.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/matching/matching_product_search_modal.dart) (línea 69) + [`matching_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/matching_screen.dart) (línea 430)

**Diagnóstico:** El `MatchingProductSearchModal` llama a `prov.loadInventory(reset: true)` (línea 69) usando el **`InventoryProvider` global**. Esto modifica los `_inventoryItems` globales, activa `notifyListeners()`, y provoca que **toda la cadena de widgets que consumen `InventoryProvider`** se reconstruyan. Cuando el modal se cierra, el `MatchingScreen` (que también depende indirectamente del `InventoryProvider` vía `_openDetailsModal` en línea 432) se reconstruye con datos contaminados. El `MatchingItemRow` pierde su identidad de estado (`_MatchingItemRowState`) en la reconstrucción, y el `InkWell.onTap` (línea 148 de `matching_item_row.dart`) deja de funcionar porque el widget se reconstruyó con un nuevo estado que no preserva las callbacks.

**Adicionalmente**, en `_openDetailsModal` (línea 432-436), se intenta buscar el `Product` en `inventoryProv.products`, que **ya fue contaminado** por la búsqueda del modal. Si no se encuentra, crea un `Product` fallback incompleto. Esto contribuye al bug.

---

### 🔴 BUG 2: Eliminación sin Confirmación

**Archivo:** [`matching_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/matching_screen.dart) (líneas 661, 682)

`onDelete: () => matchingProvider.deletePair(bp.sourceItem.id)` se ejecuta directamente sin ningún `showDialog` previo. En la UI (captura 1-2), el botón de la papelera está entre las dos tarjetas, accesible con un toque accidental.

---

### 🟡 BUG 3: Motor de Búsqueda sin Tolerancia Singular/Plural

**Archivo:** [`matching_service.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/matching_service.dart) (líneas 13-36, 61-67)

El método `_normalizeAndTokenize()` normaliza acentos y elimina stopwords, pero **no aplica lematización** (singular/plural). La comparación de tokens (línea 97: `pNombre.contains(token)`) es literalmente exacta. Si la factura dice "Lápices" y la BD tiene "Lápiz", el token normalizado `lapices` nunca coincide con `lapiz`.

**Solución disponible:** Ya existe el [`SpanishLemmatizer`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/services/spanish_lemmatizer.dart) creado para el módulo Escáner. Se puede reutilizar directamente.

---

### 🟡 BUG 4: Desborde Visual en Tarjeta de Oferta (Bundle)

**Archivo:** [`matching_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/matching_screen.dart) (líneas 603-668)

El contenedor del bundle (captura 4) tiene múltiples problemas:
- La `Row` del header (línea 619) usa un `Row` hijo directo sin `Flexible`/`Expanded`, causando overflow horizontal.
- `Text("✨ Agrupados en ${bundleModel.nombrePaquete}")` (línea 629) no tiene `maxLines`/`overflow`, causando desborde.
- `Text(bundleModel.descripcion!)` (línea 631) tampoco está contenida.
- Los `MatchingItemRow` internos no tienen padding horizontal adecuado dentro del `Container` del bundle.
- El botón "Desarmar" (línea 636-640) compite por espacio horizontal con el título.

---

### 🔴 BUG 5: Falso Positivo en Centro de Resoluciones (Nombre de Oferta)

**Archivos:** [`matching_model.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/models/matching_model.dart) (línea 195) + [`quotation_service.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/quotation_service.dart) (línea 138-141)

**Raíz del bug:** Cuando un item pertenece a un bundle, `toQuotationItemJson()` (línea 195) guarda:
```dart
"product_name": selectedProduct!.productName, // ← "Folder" (nombre del PRODUCTO)
```

Pero en la validación de integridad, el Centro de Resoluciones (línea 138-141 de `quotation_service.dart`) compara:
```dart
String currentName = bundle['nombre_paquete'] as String?; // ← "Liquidez: Folder"
String savedName = item['product_name'] as String?;       // ← "Folder" (guardado incorrectamente)
```

Como `"Folder" != "Liquidez: Folder"`, el sistema detecta un "cambio de nombre" falso, mostrando:
> Nombre: "Folder" → "Liquidez: Folder"

**La solución es:** Cuando un item tiene `bundleId != null`, guardar `product_name` con el `nombrePaquete` del bundle, no con el `productName` del producto individual.

---

### 🟡 BUG 6: Buscador Dependiente del Estado Global

**Archivo:** [`matching_product_search_modal.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/matching/matching_product_search_modal.dart) (líneas 40-82)

El modal usa `Provider.of<InventoryProvider>` directamente:
- Línea 40-43: `prov.loadMasterData()` y luego `_performSearch()` con `prov.loadInventory()`
- Línea 48-49: `prov.loadMore()` para paginación
- Línea 80-82: `_mappedResults = prov.items` → consume directamente el estado global

Esto contamina `_inventoryItems`, `_lastQuery`, `_lastCategoryIds`, etc. del provider global. Si el usuario vuelve a la pantalla de Inventario, encontrará datos contaminados.

---

### 🟡 BUG 7: Modal de Detalles sin Pulido Visual

**Archivo:** [`product_quote_detail_modal.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/matching/product_quote_detail_modal.dart) (líneas 363-674)

El modal funciona bien (captura 3), pero carece de:
- Transiciones suaves al expandir/colapsar secciones (ofertas, precio especial)
- Padding insuficiente en la sección de ofertas del bundle
- El selector de variantes como `ChoiceChip` sin diferenciación visual clara de stock

---

## Plan de Trabajo por Fases

---

### Fase 1: Desacoplamiento del Buscador (Bug 6 → Resuelve Bug 1)

> **Objetivo:** Hacer que el modal de búsqueda sea 100% independiente del `InventoryProvider` global, eliminando la contaminación de estado que causa el Bug 1.

#### [MODIFY] [`matching_product_search_modal.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/matching/matching_product_search_modal.dart)

**Cambio arquitectónico completo:** Reemplazar la dependencia de `InventoryProvider` por queries SQLite directas e independientes, igual que se hizo en [`manual_product_search.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/core/widgets/manual_product_search.dart) del módulo Escáner:

1. **Estado local completo:**
   - Crear variables locales: `List<InventoryWrapper> _localResults = []`, `bool _hasMore = true`, `int _skip = 0`, `final int _pageSize = 20`, `bool _isLoading = false`, `bool _isLoadingMore = false`
   - Para categorías, cargar una vez localmente desde `MasterDataCache` o SQLite (via `_loadLocalCategories()`)
   - **Eliminar toda referencia a `Provider.of<InventoryProvider>`**

2. **Búsqueda independiente via SQLite:**
   - Crear método `_searchProducts(String query, {bool reset = true})` que ejecute directamente `ProductQueries.fullInventoryQuery` con parámetros `LIMIT` y `OFFSET` sobre `LocalDatabase.instance`
   - Integrar el filtrado por categoría (`_selectedCategoryId`) como un `WHERE` adicional

3. **Infinite scroll:**
   - El `ScrollController` actual se mantiene, pero en vez de llamar a `prov.loadMore()`, llama a `_searchProducts(currentQuery, reset: false)` que incrementa `_skip` y hace `addAll`

4. **Limpieza al cerrar:**
   - Al cerrar el modal, NO se contamina ningún estado global. El `InventoryProvider` permanece intacto.

> [!IMPORTANT]
> **Esta fase resuelve tanto el Bug 6 (independencia) como el Bug 1 (pérdida de interactividad)**, porque la reconstrucción del árbol de widgets ya no será disparada por cambios en `InventoryProvider`. Adicionalmente, hay que verificar que `_openDetailsModal` no dependa de `inventoryProv.products` contaminado — actualmente ya tiene un fallback (línea 438-451) que construye el `Product` manualmente, pero conviene reforzarlo cargando directamente desde SQLite.

---

### Fase 2: Corrección de Lógica de Guardado de Ofertas (Bug 5)

> **Objetivo:** Que el `product_name` guardado en una fila que pertenece a un bundle refleje el nombre real de la oferta (bundle), no el nombre del producto individual.

#### [MODIFY] [`matching_model.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/models/matching_model.dart)

En `MatchPair.toQuotationItemJson()` (línea 181-205):

1. **Lógica condicional para el nombre:**
   ```dart
   // Si este item pertenece a un bundle, el product_name
   // debe ser el nombre del bundle, no del producto individual.
   // Esto evita el falso positivo en el Centro de Resoluciones.
   "product_name": bundleName ?? selectedProduct!.productName,
   ```

2. **Agregar campo `bundleName` a `MatchPair`:**
   - Añadir `String? bundleName;` al modelo `MatchPair`
   - En `clone()`, copiar `bundleName`

#### [MODIFY] [`matching_provider.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/providers/matching_provider.dart)

En `_detectAndApplyBundles()` (línea 188-231):

1. Cuando se asigna `p.bundleId = bundle.id` (línea 225), también asignar:
   ```dart
   p.bundleName = bundle.nombrePaquete;
   ```

2. En `toggleBundleGrouping()` (línea 234-249), cuando se deshace un bundle (`pair.bundleId = null`), también limpiar:
   ```dart
   pair.bundleName = null;
   ```

---

### Fase 3: Motor NLP — Integración del Lematizador en el Comparador (Bug 3)

> **Objetivo:** Que el motor de matching reconozca igualdades entre singulares/plurales reutilizando el `SpanishLemmatizer` ya existente.

#### [MODIFY] [`matching_service.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/matching_service.dart)

1. **Importar el lematizador:**
   ```dart
   import 'package:app_movil/features/scanner/services/spanish_lemmatizer.dart';
   ```

2. **Aplicar lematización en `_normalizeAndTokenize()` (línea 13-36):**
   - Después de la tokenización actual, aplicar `SpanishLemmatizer.lemmatize()` a cada token
   - Generar variantes (original + lematizada) para ampliar la cobertura de búsqueda

3. **Expandir la query SQL (línea 61-67):**
   - Para cada token, generar condiciones LIKE tanto con el token original como con su versión lematizada:
   ```
   (p.nombre LIKE '%lapiz%' OR p.nombre LIKE '%lapices%' OR ...)
   ```

4. **Mejorar el scoring (línea 96-100):**
   - Comparar tokens lematizados: si `lemmatize("lapices") == lemmatize("lapiz")` → coincidencia semántica → +25 puntos
   - Aplicar distancia de Levenshtein para typos menores (umbral ≤ 2) → +15 puntos

---

### Fase 4: Confirmación de Borrado (Bug 2)

> **Objetivo:** Impedir la eliminación accidental de filas con un diálogo de confirmación elegante.

#### [MODIFY] [`matching_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/matching_screen.dart)

1. **Crear método `_confirmAndDeletePair()`:**
   ```dart
   void _confirmAndDeletePair(MatchPair pair, bool isDark) {
     showDialog(
       context: context,
       builder: (ctx) => AlertDialog(
         // Diseño premium con nombre del producto, ícono de warning
         // Botones: "Cancelar" (gris) y "Eliminar" (rojo)
         onPressed: () {
           Navigator.pop(ctx);
           matchingProvider.deletePair(pair.sourceItem.id);
         }
       )
     );
   }
   ```

2. **Reemplazar callbacks directos** en:
   - Línea 661: `onDelete: () => _confirmAndDeletePair(bp, isDark)`
   - Línea 682: `onDelete: () => _confirmAndDeletePair(pair, isDark)`

---

### Fase 5: Rediseño Visual de la Tarjeta de Oferta/Bundle (Bug 4)

> **Objetivo:** Refactorizar el contenedor del bundle agrupado para que sea visualmente premium, sin desbordes.

#### [MODIFY] [`matching_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/matching_screen.dart)

Refactorizar el bloque de renderizado del bundle (líneas 603-668):

1. **Header del Bundle:**
   - Usar `Expanded` para el texto del título + `Flexible` para el botón "Desarmar"
   - Limitar `maxLines: 2` y `overflow: TextOverflow.ellipsis` en el nombre del bundle
   - Mover la descripción a una segunda línea con `Text(..., maxLines: 1, overflow: TextOverflow.ellipsis)`

2. **Contenedor General:**
   - Añadir `clipBehavior: Clip.antiAlias` al `Container`
   - Ajustar el borde amarillo/ámbar a `1.5px` con `borderRadius: 16`
   - Fondo semitransparente más sutil: `Colors.amber.withValues(alpha: 0.03)` en dark
   
3. **Items Internos:**
   - Los `MatchingItemRow` dentro del bundle deben tener `padding: EdgeInsets.symmetric(horizontal: 8)` para no pegarse a los bordes

4. **Savings Badge:**
   - Rediseñar como un chip flotante con `Container` redondeado, ícono `local_offer`, y texto verde

---

### Fase 6: Pulido Visual del Modal de Detalles (Bug 7)

> **Objetivo:** Mejoras de UX/UI incrementales al `ProductQuoteDetailModal` para que se sienta premium.

#### [MODIFY] [`product_quote_detail_modal.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/matching/product_quote_detail_modal.dart)

1. **Animaciones suaves:**
   - Envolver la sección de ofertas (`_buildOffersSection`) en `AnimatedSize(duration: Duration(milliseconds: 300), curve: Curves.easeInOut)` para que al activar/desactivar una oferta, la transición sea fluida
   - Envolver el bloque de "Precio Especial al Cliente" en `AnimatedCrossFade` para que el despliegue de los campos de descuento sea animado

2. **Selector de Variantes mejorado:**
   - Agregar debajo de cada `ChoiceChip` un micro-indicador de stock: punto verde (en stock), naranja (bajo), rojo (agotado)
   - Mostrar el precio al lado del nombre de la unidad en cada chip

3. **Padding y Espaciado:**
   - Aumentar el `SizedBox(height)` entre secciones de 20 a 24 para mayor respiro
   - Agregar separador visual (línea `Divider` sutil) antes de la sección de "Cantidad" para separar visualmente

4. **Micro-animación del botón Confirmar:**
   - Añadir un scale effect sutil con `AnimatedScale` al botón "CONFIRMAR PRODUCTO" cuando cambian los datos

---

## Verificación

### Pruebas Manuales
1. Abrir Cotización Inteligente → vincular un producto manualmente → cerrar el modal de búsqueda → verificar que el `onTap` (Modal de Detalles) **sigue funcionando**
2. Verificar que el Inventario principal NO se alteró después de usar el buscador de cotizaciones
3. Verificar infinite scroll en el buscador refactorizado (más de 20 resultados)
4. Verificar que "Lápices" encuentra "Lápiz" y viceversa en el matching automático
5. Tocar el botón de papelera → verificar que aparece diálogo de confirmación
6. Vincular un bundle/oferta → guardar cotización → abrir la cotización → verificar que el Centro de Resoluciones **NO** muestra falso positivo de nombre
7. Verificar que la tarjeta del bundle **NO** tiene overflow horizontal (scroll en diferentes tamaños de pantalla)
8. Verificar animaciones suaves en el modal de detalles

### Validación Estática
```
flutter analyze lib/features/smart_quotation/
```

---

## Resumen de Archivos Afectados

| Archivo | Fase | Acción |
|---------|------|--------|
| `smart_quotation/widgets/matching/matching_product_search_modal.dart` | 1 | MODIFY (desacoplar de InventoryProvider) |
| `smart_quotation/models/matching_model.dart` | 2 | MODIFY (bundleName en MatchPair + toQuotationItemJson) |
| `smart_quotation/providers/matching_provider.dart` | 2 | MODIFY (asignar bundleName en _detectAndApplyBundles) |
| `smart_quotation/services/matching_service.dart` | 3 | MODIFY (integrar SpanishLemmatizer) |
| `smart_quotation/screens/matching_screen.dart` | 4, 5 | MODIFY (confirmación borrado + rediseño tarjeta bundle) |
| `smart_quotation/widgets/matching/product_quote_detail_modal.dart` | 6 | MODIFY (animaciones + pulido) |

> [!IMPORTANT]
> **La Fase 1 es bloqueante y debe ejecutarse primero.** La contaminación del `InventoryProvider` por parte del modal de búsqueda es la causa raíz del Bug 1 (pérdida de interactividad) y del Bug 6 (dependencia). Resolverla primero garantiza estabilidad para las demás fases. Las fases 2 a 6 pueden ejecutarse en cualquier orden tras la Fase 1.

> [!WARNING]
> **Riesgo de la Fase 2:** Al cambiar el `product_name` guardado para items de bundle, las cotizaciones **existentes** (ya guardadas con el nombre de producto individual) seguirán mostrando el falso positivo hasta que el usuario pulse "Corregir y Actualizar Todo". Solo las **nuevas** cotizaciones se guardarán correctamente. Esto es aceptable y no requiere migración.
