# Plan de Trabajo: Depuración y Rediseño del Escáner + Clasificación

## Resumen del Diagnóstico

Se auditaron **12 archivos** del flujo completo de escaneo de facturas y clasificación. Los hallazgos se organizan en 4 problemas distintos, cada uno con su raíz técnica identificada.

---

## 🔴 PROBLEMA #1: Caracteres Rotos (Encoding UTF-8)

**Evidencia visual**: "T◆tere Escolar", "Espa◆ola", "Peluche Econ◆mico"

**Raíz del problema**: Se encuentra en [`scanner_ai_service.dart` L90-101](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/services/scanner_ai_service.dart#L90-L101).

El método `_sanitizeResponse()` ejecuta una **doble decodificación destructiva**:
```dart
final bytes = text.codeUnits;          // ← Toma los codeUnits (UTF-16 en Dart)
text = utf8.decode(bytes, allowMalformed: true);  // ← Los interpreta como bytes UTF-8
```

Cuando el SDK de Gemini (`google_generative_ai`) devuelve `response.text`, este String **ya está correctamente decodificado en UTF-8 nativo de Dart**. Al pasar `codeUnits` (que son puntos de código UTF-16) por `utf8.decode`, los caracteres multibyte como `ñ`, `á`, `é`, `í`, `ó`, `ú`, `ü` se corrompen porque sus codepoints no coinciden con secuencias UTF-8 válidas.

El `allowMalformed: true` enmascara el error: en lugar de lanzar una excepción, inserta el carácter de reemplazo Unicode `U+FFFD` (`◆` en la pantalla).

**Los `replaceAll` de Unicode** (líneas 104-116) tampoco funcionan porque buscan literales escapados `\\u00f1` cuando `json.decode()` ya los convierte automáticamente.

> [!CAUTION]
> **Hallazgo adicional**: En [`staging_product_group_card.dart` L266](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/staging_product_group_card.dart#L266), el label dice `"CategorÃ­a"` en lugar de `"Categoría"`. Esto indica que **el propio archivo fuente** tiene un encoding incorrecto (fue guardado con encoding Latin-1/CP-1252 en vez de UTF-8). Esto no es un bug de runtime sino de encoding del archivo.

---

## 🔴 PROBLEMA #2: Bug de Estado en el Switcher de Variantes

**Evidencia**: El usuario selecciona "Crear Nueva Variante" correctamente, pero no puede volver a seleccionar la variante existente original. El Dropdown queda atascado.

**Raíz del problema**: Se encuentra en [`variant_editor_row.dart` L322-360](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_editor_row.dart#L322-L360).

```dart
int? dropdownValue = widget.variant.matchPresentacion.estado == "NUEVO_EN_PADRE" ? -1 : dbData?.id;
if (dropdownValue != -1 && dropdownValue != null && !alternatives.any((p) => p['id'] == dropdownValue)) dropdownValue = null; 
```

Cuando el usuario cambia a "Crear Nueva Variante":
1. `switchVariantToNew()` en el provider establece `estado = "NUEVO_EN_PADRE"` y `datos.id = -1`.
2. El `dropdownValue` correctamente se pone a `-1`.

Cuando intenta **volver a una existente**, el `onChanged` llama a `switchVariantLink()`:
1. Este método busca la presentación en `currentMatchData.availablePresentations`.
2. **PERO** `currentMatchData` ahora es el `MatchData` del estado `NUEVO_EN_PADRE` (con `id: -1`, `nombre: "Nueva Variante"`).
3. `switchVariantLink()` verifica: `if (variant == null || currentMatchData == null || currentMatchData.availablePresentations == null) return;`
4. Aunque `availablePresentations` se preserva en `switchVariantToNew()` (L485), el problema es que `switchVariantLink` busca dentro de `currentMatchData.availablePresentations` la presentación seleccionada. **Si `availablePresentations` se corrompió o se vació durante el cambio, la función hace `return` silenciosamente.**

Además hay un problema secundario: después del cambio, `_initControllers()` se llama con un `Future.delayed(100ms)` (L355), pero si el widget aún no se ha reconstruido con el nuevo estado del Provider, los controladores se inicializan con datos antiguos.

> [!IMPORTANT]
> La función `switchVariantLink()` usa `currentMatchData` que apunta al estado `NUEVO_EN_PADRE` en vez de buscar los siblings desde el grupo padre. Cuando el `MatchData` tiene `id: -1`, el lookup puede fallar por validaciones internas.

---

## 🟡 PROBLEMA #3: UI Sobrecargada en el Modal Comparativo

**Evidencia**: Captura 2 — La sección "Cálculos y Forma de Venta" es densa y confusa.

**Archivos afectados**:
- [`variant_price_calculator.dart` L156-231](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_price_calculator.dart#L156-L231) — `_buildGroupedSaleRow()`

**Problemas específicos**:
1. Las columnas "Actual (BD)" y "Nuevo (A Guardar)" no están alineadas como una tabla — son dos `Column` dentro de un `Row` sin consistencia visual.
2. Los checkboxes de Costo y Precio están mezclados con los inputs editables, creando confusión sobre qué controla qué.
3. No hay título descriptivo que explique al usuario: *"Selecciona qué datos del inventario quieres actualizar"*.
4. El espaciado entre filas es de apenas 4-6px, causando que todo se comprima.
5. La flecha `→` central queda a veces desalineada verticalmente.

---

## 🟡 PROBLEMA #4: Falta de Responsividad

**Evidencia**: Captura 1 — AppBar dice "Revisión de Co..." cortado.

**Archivo afectado**: [`invoice_review_screen.dart` L196-201](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/screens/invoice_review_screen.dart#L196-L201)

```dart
const Text("Revisión de Compras", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
```
El título tiene un `fontSize: 16` fijo sin adaptación. En pantallas angostas (como la de las capturas, ~360dp) colisiona con los `actions` (botón `<>` y `Resumen`).

Nota: `ExtractionResultScreen` ya tiene `FittedBox` en su AppBar (L118). Este patrón necesita replicarse en `InvoiceReviewScreen` y `InvoiceStagingScreen`.

**Componentes adicionales sin responsividad**:
- Los `ReviewItemCard` tienen `fontSize` fijos que no escalan.
- Los botones del bottomNavigationBar tienen textos largos que podrían cortarse.
- En `InvoiceStagingScreen`, los chips de estadísticas (`_buildStatChip`) no tienen `FittedBox`.

---

## Propuesta de Implementación por Fases

### Fase 1: Corrección de Encoding UTF-8

#### 1.1 — Eliminar la Doble Decodificación Destructiva

**Archivo**: [`scanner_ai_service.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/services/scanner_ai_service.dart)

**Cambio**: Simplificar drásticamente `_sanitizeResponse()`:
- **Eliminar** el bloque `utf8.decode(text.codeUnits)` (líneas 95-101). El SDK de Gemini ya devuelve UTF-8 válido.
- **Eliminar** los `replaceAll` de secuencias Unicode escapadas (líneas 104-116). `json.decode()` ya las resuelve automáticamente.
- Conservar únicamente la limpieza de marcadores markdown (L92).

#### 1.2 — Corregir Encoding del Archivo Fuente

**Archivo**: [`staging_product_group_card.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/staging_product_group_card.dart)

**Cambio**: Reemplazar `"CategorÃ­a"` → `"Categoría"` en línea 266. Verificar que no haya otros strings con encoding roto en el proyecto.

---

### Fase 2: Responsividad del AppBar y Componentes

#### 2.1 — AppBar de InvoiceReviewScreen

**Archivo**: [`invoice_review_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/screens/invoice_review_screen.dart)

**Cambio**: Envolver el `title` en un `FittedBox(fit: BoxFit.scaleDown)` igual que ya se hace en `ExtractionResultScreen`. Reducir ligeramente los `fontSize` de los actions para pantallas pequeñas.

#### 2.2 — AppBar de InvoiceStagingScreen

**Archivo**: [`invoice_staging_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/screens/invoice_staging_screen.dart)

**Cambio**: Aplicar el mismo patrón `FittedBox` al título "Clasificar y Confirmar".

#### 2.3 — Componentes internos responsivos

**Archivos**: `review_item_card.dart`, `invoice_staging_screen.dart`, `variant_editor_row.dart`

**Cambios**:
- Envolver textos largos en `FittedBox` o usar `AutoSizeText`.
- Usar `MediaQuery.of(context).size.width` para ajustar paddings en pantallas <360dp.
- Envolver los labels de `MiniInput` en `FittedBox` para evitar overflow.
- Envolver el texto del botón del `bottomNavigationBar` en `FittedBox`.
- Los chips de estadísticas (`_buildStatChip`) recibirán `Flexible` + `FittedBox`.

---

### Fase 3: Depuración del Bug de Variantes

#### 3.1 — Corregir `switchVariantLink()` en el Provider

**Archivo**: [`scanner_provider.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/providers/scanner_provider.dart)

**Cambio**: La función `switchVariantLink()` actualmente depende de `currentMatchData.availablePresentations`. Cuando el estado es `NUEVO_EN_PADRE`, el `currentMatchData` puede tener datos incompletos. Se debe:
- Buscar `availablePresentations` desde el **grupo padre** (`StagingProductGroup`) en vez de depender del `MatchData` actual de la variante.
- Garantizar que la lista de siblings se preserve siempre como fuente de verdad en el grupo, no en el MatchData individual de cada variante.

#### 3.2 — Corregir el `_buildVariantSwitcher()` en el Widget

**Archivo**: [`variant_editor_row.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_editor_row.dart)

**Cambio**:
- Eliminar el `Future.delayed(100ms)` para `_initControllers()` — es frágil e impredecible. Usar `WidgetsBinding.instance.addPostFrameCallback` o simplemente llamar `setState` después de la actualización del Provider.
- Validar que `dropdownValue` siempre corresponda a un item real del Dropdown para evitar el error de Flutter "There should be exactly one item with [DropdownButton]'s value".

---

### Fase 4: Rediseño del Modal Comparativo ("Clasificar y Confirmar")

#### 4.1 — Sección "Cálculos y Forma de Venta"

**Archivo**: [`variant_price_calculator.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_price_calculator.dart)

**Cambios**:
- **Separar visualmente** las secciones en bloques distintos con títulos descriptivos claros.
- Reformatear la comparativa como una **tabla visual** con dos columnas perfectamente alineadas, en vez de dos `Column` genéricas dentro de un `Row`.
- **Agregar subtítulo explicativo**: *"Selecciona qué datos del inventario actual deseas actualizar con los nuevos valores de esta factura"*.
- **Aumentar espaciado** entre filas de al menos 12px (actualmente 4-6px).
- Mover los checkboxes de Costo y Precio a una posición más clara (como headers de sección) para que sea evidente qué controlan.
- Agregar un borde o fondo diferenciado para cada fila de datos para mejorar la legibilidad.

#### 4.2 — Mejoras Generales de UX en el Modal

- Mejorar la jerarquía visual del header (imagen del producto, nombre, marca).
- Agregar **animaciones de transición** al activar/desactivar checkboxes (los campos se desvanecen o se iluminan).
- Agrupar conceptualmente: primero Identificación (Nombre), después Costos (Costo + Margen + Precio), después Stock.

---

## Resumen de Archivos Afectados

| Archivo | Fase | Tipo de Cambio |
|---|---|---|
| [`scanner_ai_service.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/services/scanner_ai_service.dart) | Fase 1 | Eliminar doble decodificación |
| [`staging_product_group_card.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/staging_product_group_card.dart) | Fase 1 | Corregir string hardcoded |
| [`invoice_review_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/screens/invoice_review_screen.dart) | Fase 2 | Responsividad AppBar |
| [`invoice_staging_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/screens/invoice_staging_screen.dart) | Fase 2 | Responsividad AppBar + chips |
| [`review_item_card.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/review/review_item_card.dart) | Fase 2 | FittedBox en labels |
| [`variant_editor_row.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_editor_row.dart) | Fase 2, 3 | Responsividad + bug de variantes |
| [`scanner_provider.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/providers/scanner_provider.dart) | Fase 3 | Corregir switchVariantLink |
| [`variant_price_calculator.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_price_calculator.dart) | Fase 4 | Rediseño del modal comparativo |

---

## Verificación

### Automated Tests
- `flutter analyze` para verificar compilación limpia.

### Manual Verification
- **Escenario A**: Escanear una factura con productos que contengan ñ/tildes → Verificar que se muestren correctamente en los campos de texto.
- **Escenario B**: En la pantalla de Clasificación, vincular un producto, seleccionar "Crear Nueva Variante", luego seleccionar la variante existente de nuevo → Debe funcionar sin bloqueo.
- **Escenario C**: Abrir InvoiceReviewScreen en un teléfono con pantalla angosta → El título no debe cortarse.
- **Escenario D**: Abrir el modal "Clasificar y Confirmar" → La sección de Cálculos debe verse limpia, espaciada y con instrucciones claras.

---

## Open Questions

> [!IMPORTANT]
> **¿Deseas que también busque y corrija TODOS los strings con encoding roto en todo el proyecto?** En la auditoría encontré `"CategorÃ­a"` en `staging_product_group_card.dart` L266. Podría haber más archivos afectados. ¿Hago un grep completo del proyecto buscando patrones de mojibake como `Ã¡`, `Ã©`, `Ã­`, etc.?
