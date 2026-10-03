# Corrección de Datos Pegajosos al Desvincular y Control del Teclado Persistente

## Contexto del Problema

Se han detectado dos fallos críticos de experiencia de usuario en la ventana de "Clasificar y Confirmar" (Staging) y en las pantallas de Crear/Editar producto:

### Problema 1: Datos "Pegajosos" al Desvincular un Producto

**Descripción del fallo:**
Cuando el usuario vincula manualmente un producto de la factura con un producto del inventario (o el sistema lo vincula automáticamente), y luego lo **desvincula**, la marca del producto del inventario se queda "pegada" en el grupo de la factura. El producto desvinculado debería volver a mostrar la marca original que la IA detectó de la factura (o vacío/Genérica si no se detectó ninguna).

**Análisis de la causa raíz:**

He trazado el flujo completo del dato `marcaTexto` en el código:

1. **Creación inicial** ([`scanner_matching_engine.dart:293`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/services/scanner_matching_engine.dart#L293)): El `marcaTexto` se establece desde `item.marcaDetectada` (lo que la IA leyó de la factura).

2. **Vinculación manual** ([`scanner_provider.dart:432`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/providers/scanner_provider.dart#L432)): Cuando `manualLinkProductGroup()` se ejecuta, **sobreescribe** `marcaTexto` con `product['marca_nombre']` del producto del inventario vinculado.

3. **Desvinculación** ([`scanner_provider.dart:514-533`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/providers/scanner_provider.dart#L514-L533)): `unlinkProductGroup()` restaura `nombrePadre` desde `nombreOriginalFactura`, pero **NUNCA restaura `marcaTexto`** ni `matchMarca` ni `categoriaSugeridaId`. Estos quedan contaminados con los datos del producto del inventario que ya no tiene relación.

**Datos afectados (confirmados):**
| Dato | ¿Se restaura al desvincular? | Estado |
|------|------|--------|
| `nombrePadre` | ✅ Sí (desde `nombreOriginalFactura`) | OK |
| `marcaTexto` | ❌ **NO** | **BUG CRÍTICO** |
| `matchMarca` | ❌ **NO** | **BUG** (queda con el match del inventario) |
| `categoriaSugeridaId` | ❌ **NO** | **BUG** (queda con la categoría del inventario) |

> [!CAUTION]
> El modelo `StagingProductGroup` tiene un backup de `nombreOriginalFactura` pero **NO tiene un backup de la marca original de la factura**. Esto significa que al desvincular, el sistema no tiene de dónde recuperar la marca correcta. Se necesita agregar un campo `marcaOriginalFactura` al modelo.

---

### Problema 2: Teclado que se Activa Constantemente

**Descripción del fallo:**
El teclado del dispositivo se abre de forma inoportuna e inesperada al:
- Cerrar el modal de comparación (Variant Price Calculator)
- Cerrar el modal de búsqueda manual de productos
- Navegar entre tarjetas de productos en la pantalla de Staging
- Trabajar en las pantallas de Crear y Editar producto

**Análisis de la causa raíz:**

He identificado el mecanismo exacto del problema:

1. **En la pantalla de Staging:** Cuando un producto está **desvinculado** (estado "NUEVO"), la tarjeta muestra campos editables (`TextFormField` en [`staging_product_group_card.dart:173`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/staging_product_group_card.dart#L173) y múltiples `MiniInput`/`TextField` en [`variant_editor_row.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_editor_row.dart)). Cuando Flutter reconstruye el widget tree tras cerrar un modal, el framework intenta **restaurar el foco** al primer campo de texto visible que esté en la jerarquía de widgets. Esto provoca que el teclado se abra automáticamente.

2. **El `GestureDetector` en [`invoice_staging_screen.dart:196-198`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/screens/invoice_staging_screen.dart#L196-L198)** ya tiene un `onTap: () => FocusScope.of(context).unfocus()`, pero esto solo funciona cuando el usuario toca un área vacía. No protege contra la restauración automática del foco al cerrar modales.

3. **En las pantallas de Crear/Editar:** No tienen **ningún** mecanismo de `GestureDetector` con `unfocus`. El `SingleChildScrollView` directamente contiene los campos de texto sin protección.

4. **Los modales de búsqueda** (`manual_product_search.dart:145`) usan `autofocus: true`, lo cual es correcto para su propósito. Pero al cerrarse, Flutter devuelve el foco al nodo anterior en el árbol, que resulta ser un `TextField` del staging, provocando que el teclado se vuelva a abrir.

---

## Cambios Propuestos

### Fase 1: Corrección de Datos Pegajosos al Desvincular

#### [MODIFY] [`scanner_models.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/models/scanner_models.dart)

En la clase `StagingProductGroup`:
- Agregar campo `String? marcaOriginalFactura` para guardar la marca original detectada por la IA.
- Este campo se establecerá en el constructor y en `fromJson` (igual que `nombreOriginalFactura`).

#### [MODIFY] [`scanner_matching_engine.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/services/scanner_matching_engine.dart)

- Al crear el `StagingProductGroup` en la línea 290, pasar también `marcaOriginalFactura: item.marcaDetectada ?? ""`.

#### [MODIFY] [`scanner_provider.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/providers/scanner_provider.dart)

En `unlinkProductGroup()`:
- **Restaurar `marcaTexto`** desde `marcaOriginalFactura` (o cadena vacía si es nulo).
- **Resetear `matchMarca`** a `MatchResult(estado: "NUEVO", confianza: 0)` para que la marca quede libre.
- **Limpiar `categoriaSugeridaId`** a `null` para no arrastrar la categoría del producto del inventario desvinculado.
- Ajustar la llamada a `_cleanAndCapitalizeName()` para usar `marcaOriginalFactura` en vez de `marcaTexto` (ya que `marcaTexto` aún tiene la marca del inventario en ese momento).

En `addNewProductGroup()`:
- Verificar que el nuevo grupo también establezca `marcaOriginalFactura` correctamente (como cadena vacía, ya que es producto agregado manualmente).

---

### Fase 2: Control del Teclado Persistente

#### [MODIFY] [`variant_editor_row.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_editor_row.dart)

En el `_openComparativeModal()`:
- **Antes** de abrir el modal, llamar `FocusScope.of(context).unfocus()` para quitar el foco de cualquier campo activo.
- En el cierre del modal (después de `Navigator.pop`), llamar `FocusScope.of(context).unfocus()` para evitar que el foco regrese a un campo de la tarjeta.

En el widget `MiniInput`:
- Agregar la propiedad `FocusNode` como parámetro opcional, para poder controlar el foco externamente si es necesario en el futuro.

#### [MODIFY] [`staging_product_group_card.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/staging_product_group_card.dart)

En `_showProductSearchModal()`:
- **Antes** de abrir el modal, llamar `FocusScope.of(context).unfocus()`.
- Después de cerrar el modal (dentro del callback `.then()` o en el `onSelect`), asegurar que el foco se limpia.

En el `TextFormField` del nombre del producto padre (línea 173):
- Agregar `autofocus: false` explícitamente para prevenir que el framework auto-enfoque este campo.

#### [MODIFY] [`variant_price_calculator.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/scanner/widgets/staging/variant_price_calculator.dart)

En el método `onConfirm` y en el botón de "Cancelar":
- Antes de hacer `Navigator.pop()`, llamar `FocusScope.of(context).unfocus()` para limpiar el foco dentro del modal, evitando que Flutter transfiera el foco a un campo de la pantalla padre.

#### [MODIFY] [`product_create_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/catalog/screens/product_create_screen.dart)

En el widget `body`:
- Envolver el `SingleChildScrollView` con un `GestureDetector` que llame a `FocusScope.of(context).unfocus()` en `onTap`, con `behavior: HitTestBehavior.translucent`. Esto permite al usuario cerrar el teclado tocando cualquier área vacía de la pantalla.

#### [MODIFY] [`product_edit_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/catalog/screens/product_edit_screen.dart)

En el widget `body`:
- Misma solución que en `product_create_screen.dart`: envolver con `GestureDetector` + `unfocus`.

---

## Verificación

### Pruebas Manuales
Después de implementar los cambios, verificar los siguientes escenarios:

1. **Datos Pegajosos:**
   - Escanear una factura → Vincular manualmente un producto con otro del inventario → Desvincular → Verificar que la marca vuelve a la original de la factura (o "Genérica" si no tenía marca).
   - Repetir el ciclo vincular/desvincular varias veces para asegurar que no se acumulan datos residuales.

2. **Teclado:**
   - Abrir modal de comparación → Cerrar → Verificar que el teclado NO se abre automáticamente.
   - Abrir modal de búsqueda de productos → Seleccionar o cerrar → Verificar que el teclado no se reactiva.
   - Navegar por la pantalla de Staging scrolleando → Verificar que ningún campo gana foco automáticamente.
   - En Crear Producto: tocar un área vacía → Verificar que el teclado se cierra correctamente.
   - En Editar Producto: tocar un área vacía → Verificar que el teclado se cierra correctamente.

### Compilación
- Ejecutar `flutter analyze` para verificar que no hay errores de compilación ni warnings.
