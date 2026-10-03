# Plan: Clasificar y Confirmar — Refactorización Integral de UX/UI

## Diagnóstico Completo

He analizado en profundidad las 5 capturas proporcionadas y los 6 archivos clave del módulo:
- [`scanner_matching_engine.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/services/scanner_matching_engine.dart) — Donde se asigna `nombrePadre`
- [`staging_product_group_card.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/staging_product_group_card.dart) — Tarjeta principal del producto
- [`variant_editor_row.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_editor_row.dart) — Carrusel + diseño de variante existente/nueva
- [`variant_price_calculator.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_price_calculator.dart) — Modal Comparativo completo (953 líneas)
- [`invoice_staging_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/screens/invoice_staging_screen.dart) — Pantalla contenedora
- [`scanner_models.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/models/scanner_models.dart) — Modelos con snapshot/restore

---

## Fase 1: Corrección del Campo "Nombre Principal" en Productos Nuevos

### Problema Identificado
En [`scanner_matching_engine.dart` L273](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/services/scanner_matching_engine.dart#L273):
```dart
nombrePadre: item.productoPadreEstimado ?? item.descripcion,
```
El fallback es `item.descripcion`, que contiene **toda la línea cruda de la factura** (ej: "BLOQUES LOGICOS No 7 TAPER GRUESO"). Cuando la IA no separa correctamente `productoPadreEstimado`, el campo del nombre principal recibe todo el texto concatenado.

### Solución

#### [MODIFY] [`scanner_matching_engine.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/services/scanner_matching_engine.dart#L273)
- Cuando `productoPadreEstimado` sea `null` o vacío, **limpiar `item.descripcion`** removiendo la marca y la variante detectadas antes de asignarla como `nombrePadre`:
```dart
String cleanedNombrePadre = item.productoPadreEstimado ?? item.descripcion;
// Si la IA no separó bien, limpiar manualmente
if (item.productoPadreEstimado == null || item.productoPadreEstimado!.isEmpty) {
  String raw = item.descripcion;
  if (item.marcaDetectada != null && item.marcaDetectada!.isNotEmpty) {
    raw = raw.replaceAll(RegExp(item.marcaDetectada!, caseSensitive: false), '').trim();
  }
  if (item.varianteDetectada != null && item.varianteDetectada!.isNotEmpty) {
    raw = raw.replaceAll(RegExp(item.varianteDetectada!, caseSensitive: false), '').trim();
  }
  cleanedNombrePadre = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
}
```
- Esto garantiza que el campo editable de "Nombre Producto Principal" en la tarjeta nueva solo contenga el nombre limpio.

### Verificación de datos en variante nueva
Revisando L280 del mismo archivo:
```dart
nombreEspecifico: item.varianteDetectada ?? item.descripcion,
```
- Aquí, `nombreEspecifico` tiene el mismo problema de fallback. Aplicar la misma limpieza: si `varianteDetectada` es nulo, asignar un string genérico en lugar de la descripción cruda completa.

---

## Fase 2: Eliminación de Unidad Duplicada en Carruseles

### Problema Identificado
Hay **dos carruseles** independientes:
1. **Carrusel de la tarjeta principal** ([`variant_editor_row.dart` L354-L458](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_editor_row.dart#L354-L458))
2. **Carrusel dentro del Modal** ([`variant_price_calculator.dart` L217-L325](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_price_calculator.dart#L217-L325))

#### Problema en Carrusel 1 (tarjeta)
En L403-L406:
```dart
String pName = p['nombre_completo']?.toString() ?? ...;
String unit = p['unidad_venta']?.toString() ?? ...;
pName = '[$unit] - $pName'; // ← DUPLICA la unidad
```
El campo `nombre_completo` ya contiene la unidad (fue construido como `"${unidad_venta} ${nombre_especifico}"`). Al prefijar `[$unit]`, se genera: **`[Unidad] - Unidad Nueva presentación`**.

#### Problema en Carrusel 2 (modal)
En L272-L273:
```dart
String pName = p['nombre_completo']?.toString() ?? ...;
```
Aquí `nombre_completo` = `"Unidad Nueva presentación"` que ya incluye la unidad al inicio.

### Solución

#### [MODIFY] [`variant_editor_row.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_editor_row.dart#L401-L455)
- **Eliminar** el prefijo `[$unit] - ` del nombre del chip.
- Usar solo `nombre_especifico` como nombre principal del chip.
- Mostrar la unidad de venta **debajo** del nombre, en tipografía más pequeña y distinta, igual que ya lo hace el carrusel del modal (L309): `Text("${p['unidad'] ?? 'Ud.'} (x${p['factor_conversion'] ?? 1})")`.
- Aumentar la `height` del contenedor del carrusel de `70` a `80` para dar espacio a la línea extra.

#### [MODIFY] [`variant_price_calculator.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_price_calculator.dart#L270-L320)
- Cambiar `pName` para que use solo `nombre_especifico` en lugar de `nombre_completo`.
- La unidad ya se muestra correctamente en L309 como etiqueta discreta debajo. Solo verificar que no se duplique.

#### [MODIFY] [`staging_product_group_card.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/staging_product_group_card.dart#L150-L158)
- En el título del producto vinculado (L157), la concatenación `" - $variantName"` actualmente usa `matchPresentacion.datos?.nombre`, que viene del campo `nombre_especifico` del engine. Verificar que no incluya unidad prefijada. Si lo hace, limpiar.

#### [MODIFY] [`variant_editor_row.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_editor_row.dart#L250-L254)
- En la sección de "VARIANTE EXISTENTE" (L250-L254), el nombre de la variante se muestra con:
  ```dart
  Text(widget.variant.matchPresentacion.datos?.nombre ?? "")
  ```
  Este campo `nombre` también es `nombre_especifico` del engine. Si contiene la unidad prefijada, separar. Debajo del nombre, mostrar la unidad de venta como etiqueta discreta (ya existe en L256-L258, solo asegurar que no se repita arriba).

---

## Fase 3: Rediseño del Modal Comparativo — Sección Superior Retráctil

### Problema Identificado
La tarjeta con los datos del producto + su carrusel ocupa ~40% del espacio del modal, dejando las secciones de comparación en un espacio muy estrecho e incómodo para interactuar.

### Solución

#### [MODIFY] [`variant_price_calculator.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_price_calculator.dart#L328-L452)

**Reestructurar el layout del modal:**

1. **Convertir toda la estructura a un `CustomScrollView` con `SliverAppBar`-like behavior**: En lugar de un `Column` fijo con `Expanded(SingleChildScrollView)`, envolver la tarjeta del producto y el carrusel dentro del `SingleChildScrollView` para que se desplacen junto con las secciones de comparación.

2. **Implementación concreta**: Mover la tarjeta info del producto (L382-L406) y el carrusel (L408) **dentro** del `SingleChildScrollView` (L411). Así, al hacer scroll hacia abajo para navegar las secciones comparativas, la tarjeta superior se desplaza fuera de la pantalla, liberando todo el espacio.

3. **Mantener siempre visible**: Solo el **título "Gestión del Producto"** y los botones de restablecer (L347-L379) quedarán fijos en la parte superior, junto con el handle del modal y el botón "GUARDAR DECISIÓN" en la parte inferior.

4. **Resultado visual**: Al abrir el modal, se ve la tarjeta completa del producto + carrusel. Al desplazarse, se oculta automáticamente dando espacio completo a las secciones de comparativa.

---

## Fase 4: Checkboxes Independientes en Comparativa de Compra

### Problema Identificado
En [`variant_price_calculator.dart` L485-L526](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_price_calculator.dart#L485-L526), las 5 filas de la sección "Comparativa de Compra" comparten una **sola variable booleana** `widget.variant.updateDatosCompra`. Al marcar cualquier fila, se marcan **todas** simultáneamente.

### Solución

#### [MODIFY] [`scanner_models.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/models/scanner_models.dart#L202-L207)
- Reemplazar `bool updateDatosCompra` por campos individuales:
```dart
bool updateUmpCompra = false;
bool updateCantidadUmp = false;
bool updatePrecioUmp = false;
bool updatePagoTotal = false;
bool updateUnidLote = false;
```
- Agregar getter de conveniencia: `bool get updateDatosCompra => updateUmpCompra || updateCantidadUmp || updatePrecioUmp || updatePagoTotal || updateUnidLote;`
- Agregar setter para "seleccionar todo": `set updateDatosCompraAll(bool v) { updateUmpCompra = v; updateCantidadUmp = v; updatePrecioUmp = v; updatePagoTotal = v; updateUnidLote = v; }`
- Actualizar los snapshots y restore para incluir estos nuevos campos.

#### [MODIFY] [`variant_price_calculator.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_price_calculator.dart#L455-L530)
- Cada `_buildCompareRow` usará su propio campo booleano.
- Agregar un **checkbox "Seleccionar todo"** en el header de la sección, al lado del título "Comparativa de Compra (Proveedor)".

#### [MODIFY] [`variant_price_calculator.dart` `_applyChanges`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_price_calculator.dart#L179-L215)
- Actualizar la lógica de `_applyChanges` para que aplique cada campo de compra individualmente basándose en su checkbox correspondiente.

---

## Fase 5: Unificación de Botones de Restablecer

### Problema Identificado
Existen **dos botones** de restaurar en paralelo:
1. **Azul (`Icons.undo`)**: "Deshacer cambios del modal" — Restaura al snapshot antes de abrir el modal. **Aparece intermitentemente** porque depende de `hasSnapshotBeenModified`, que a veces no se activa correctamente si el snapshot no fue tomado.
2. **Naranja (`Icons.restore`)**: "Restaurar valores de factura" — Restaura a los valores originales absolutos de la IA. **Siempre funciona** pero sin feedback visual claro.

Estos botones aparecen tanto en la tarjeta principal (L204-L227 de `variant_editor_row.dart`) como dentro del modal (L354-L376 de `variant_price_calculator.dart`).

### Solución

#### Decisión: Mantener únicamente el botón naranja (`restoreOriginals`)
Razonamiento:
- Es el que el usuario confirma que funciona correctamente.
- Su lógica restaura a los valores absolutos de la factura, que es el punto de referencia más útil.
- El botón azul (snapshot) es confuso y su aparición intermitente genera desconfianza.

#### [MODIFY] [`variant_editor_row.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_editor_row.dart#L201-L230)
- **Eliminar** el `IconButton` azul de `undo` (L204-L215).
- **Mejorar** el botón naranja de `restore`:
  - Agregar una animación `AnimatedSwitcher` con `ScaleTransition` para que aparezca/desaparezca suavemente.
  - Agregar un `SnackBar` o tooltip visual que confirme: "✅ Valores de factura restablecidos" al presionar.
  - Solo mostrar el botón cuando `hasBeenModified == true`.

#### [MODIFY] [`variant_price_calculator.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_price_calculator.dart#L351-L377)
- **Eliminar** el `TextButton.icon` azul de "Deshacer Modal" (L354-L364).
- **Mejorar** el `IconButton` naranja: mismo tratamiento visual que en la tarjeta, con animación y feedback al presionar.

---

## Fase 6: Cierre del Modal al Crear Nueva Variante

### Problema Identificado
Al presionar "Crear Nueva" en el carrusel del modal, la variante se cambia a `NUEVO_EN_PADRE` pero el modal permanece abierto, mostrando secciones de comparación que ya no aplican.

### Solución

#### [MODIFY] [`variant_price_calculator.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_price_calculator.dart#L238-L245)
- En el `onTap` del botón "Crear Nueva" del carrusel del modal, después de llamar a `switchVariantToNew`, ejecutar `Navigator.pop(context)` para cerrar el modal y mostrar la tarjeta actualizada con el formulario de variante nueva.

---

## Fase 7: Comportamiento Inteligente del Teclado

### Problema Identificado
Al presionar un campo de texto y luego tocar otra parte de la pantalla, el teclado permanece activo. Esto ocurre porque no hay un `GestureDetector` que capture los taps fuera de los campos para cerrar el teclado.

### Solución

#### [MODIFY] [`invoice_staging_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/screens/invoice_staging_screen.dart)
- Envolver el `body` del `Scaffold` en un `GestureDetector` con `behavior: HitTestBehavior.translucent`:
```dart
GestureDetector(
  onTap: () => FocusScope.of(context).unfocus(),
  behavior: HitTestBehavior.translucent,
  child: /* body actual */,
)
```
- **Importante**: Usar `onTap` y NO `onPanDown` ni interceptar el scroll (`onVerticalDragDown`). De esta forma:
  - **Tap** en cualquier área vacía → cierra el teclado ✅
  - **Scroll/deslizar** por la lista → NO cierra el teclado ✅
  - **Tap** en otro campo de texto → el Flutter framework automáticamente cambia el foco al nuevo campo ✅

#### [MODIFY] [`variant_price_calculator.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_price_calculator.dart)
- Aplicar el mismo patrón `GestureDetector + FocusScope.unfocus()` al contenedor principal del modal, para que el comportamiento sea consistente dentro y fuera del modal.

---

## Fase 8: Refinamiento Visual General

### Mejoras en la Tarjeta de Variante Nueva
#### [MODIFY] [`variant_editor_row.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_editor_row.dart#L281-L348)
- Reorganizar los campos en secciones visuales claras con separadores titulados:
  - **Sección 1 "Identidad"**: Nombre específico + Unidad de venta (ya existe, solo agregar un mini-título).
  - **Sección 2 "Datos de Compra"**: Empaque, Unid x Empaque, Compró, P. Total (ya existe).
  - **Sección 3 "Cálculo de Venta"**: Factor venta, Margen, P. Venta Final (ya existe).
- Los mini-títulos usarán tipografía sutil: `fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 0.5`

### Economización de espacio en secciones del modal
#### [MODIFY] [`variant_price_calculator.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_price_calculator.dart)
- Reducir `padding` de las secciones de comparativa de `16` a `12`.
- Reducir `margin.bottom` de las secciones de `16`/`12` a `10`.
- Hacer más compacta la cabecera de "Datos extraídos de Factura" (reducir `SizedBox(height: 4)` a `SizedBox(height: 2)`).
- Reducir el `const Divider(height: 24)` entre bloques a `const Divider(height: 16)`.

---

## Resumen de Archivos Afectados

| Archivo | Fases | Cambios Principales |
|---------|-------|---------------------|
| [`scanner_matching_engine.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/services/scanner_matching_engine.dart) | 1 | Limpieza de `nombrePadre` y `nombreEspecifico` en fallback |
| [`scanner_models.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/models/scanner_models.dart) | 4, 5 | Checkboxes individuales de compra + limpieza de snapshot azul |
| [`staging_product_group_card.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/staging_product_group_card.dart) | 2 | Limpieza de unidad duplicada en título |
| [`variant_editor_row.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_editor_row.dart) | 2, 5, 8 | Carrusel limpio + botón restore mejorado + secciones tituladas |
| [`variant_price_calculator.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_price_calculator.dart) | 2, 3, 4, 5, 6, 7, 8 | Modal retráctil + checkboxes independientes + cierre al crear nueva + keyboard + economizar espacio |
| [`invoice_staging_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/screens/invoice_staging_screen.dart) | 7 | GestureDetector para cerrar teclado |

---

## Verificación

### Compilación
```bash
flutter analyze
```

### Funcional
- Escanear una factura con productos nuevos y verificar que el campo "Nombre Producto Principal" solo contiene el nombre limpio.
- Verificar que los chips del carrusel muestran solo el nombre de la variante, con la unidad debajo.
- Verificar que el modal se desplaza liberando espacio al scroll.
- Verificar que los checkboxes de compra son independientes.
- Verificar que solo existe el botón naranja de restablecer y que muestra feedback visual.
- Verificar que al presionar "Crear Nueva" en el modal, este se cierra.
- Verificar que el teclado se cierra al tocar fuera de un campo pero NO al hacer scroll.
