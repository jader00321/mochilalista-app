# Plan de Trabajo: Rediseño Revolucionario de la Pantalla de Matching

## Resumen del Diagnóstico

Tras auditar los 7 archivos clave del flujo de matching (`matching_screen.dart`, `matching_item_row.dart`, `product_quote_detail_modal.dart`, `matching_smart_bottom_bar.dart`, `matching_provider.dart`, `matching_model.dart`, `promotion_repository.dart`), he identificado las causas raíz exactas de los 3 problemas reportados.

---

## Diagnóstico Técnico Detallado

### 🔴 Problema 1: Desbordes y Bugs Visuales en Tarjeta Derecha

**Causa raíz:** El layout de la tarjeta derecha (producto vinculado) en [`matching_item_row.dart:96-308`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/matching/matching_item_row.dart#L96-L308) intenta meter **demasiada información** en una columna con `Expanded(flex: 60)`:

1. **Imagen (55x55px)** + **Marca** + **Nombre+Específico** (RichText con 4 maxLines) + **Badges** (Repetido/Agotado/Excede) + **Precio c/u** + **Controles +/-** (SizedBox width:100) → todo esto dentro de un `Row` con `CrossAxisAlignment.start`.

2. El `SizedBox(width: 100)` de los controles `+/-` en la [línea 198](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/matching/matching_item_row.dart#L198) colisiona con la columna de precios (`Expanded`) cuando el nombre del producto es largo. La `Row` en línea 171 intenta repartir espacio entre `Expanded(Column de precios)` y `SizedBox(width:100, Column de controles)`, pero el contenido de la columna de controles (los textos de subtotal, la fila de botones) se apila **verticalmente de forma descontrolada** cuando el `Column` no cabe en los 100px fijos.

3. **Agravante en la captura del #14 ("Block medio 99"):** La tarjeta izquierda (source) tiene `Expanded(flex: 35)` y la derecha `Expanded(flex: 60)`. En pantallas de ~360dp de ancho, esto deja ~210dp para la tarjeta derecha. Restando padding (12+12) y la imagen (55+12), quedan ~120dp para nombre+precios+controles. **No es suficiente**, provocando que los números del precio caigan en vertical (caracteres sueltos apilados).

4. **El SizedBox(width: 45)** del botón eliminar en [`_buildDeleteButton`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/matching/matching_item_row.dart#L342) consume espacio fijo adicional entre las tarjetas.

### 🔴 Problema 2: Interacción Rota (onTap del Modal)

**Causa raíz:** El `InkWell` en [`matching_item_row.dart:99-101`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/matching/matching_item_row.dart#L99-L101) solo envuelve el **`Padding` superior** de la tarjeta (la zona de imagen+nombre+precios), pero:

1. La zona de los **botones `+/-`** está **dentro** de este `InkWell`, y contiene sus propios `InkWell` hijos ([líneas 209, 223](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/matching/matching_item_row.dart#L209)). Esto causa un **conflicto de gestos**: el tap del padre (`onTapProduct`) compite con los taps de los hijos (`+/-`). Flutter resuelve la ambigüedad con su arena de gestos, lo que a menudo **traga el tap del padre** cuando los hijos están en la zona activa.

2. Los botones de acción `Desvincular` y `Cambiar` en [`líneas 256-304`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/matching/matching_item_row.dart#L256-L304) están **fuera** del `InkWell` principal, así que tocar ahí no abre el modal (correcto), pero el usuario intuitivamente toca la tarjeta en cualquier zona y espera que se abra el modal.

3. **Consecuencia visible en captura:** El usuario necesita tocar **precisamente** en la zona de nombre/marca para que funcione, pero la zona de precios/controles está tan apretada que es casi imposible tocar fuera de un elemento interactivo.

### 🔴 Problema 3: Mala Gestión de Ofertas

**Causa raíz:** El sistema de "ofertas" en el Matching Screen opera en **dos niveles totalmente desconectados**:

1. **Nivel de Paquete (Bundles):** [`matching_provider.dart:165-224`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/providers/matching_provider.dart#L165-L224) carga bundles activos y los aplica automáticamente durante `initializeAndMatch()`. El botón global "IA: Promociones analizadas" (visible en [`matching_screen.dart:824-846`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/matching_screen.dart#L824-L846)) solo permite "Re-Agrupar" (re-ejecutar `_detectAndApplyBundles()`) o "Desarmar" por bundle. **No permite al usuario elegir qué bundle aplicar ni ver cuáles están disponibles**.

2. **Nivel de Producto Individual (precioOferta):** Cada `ProductPresentation` puede tener un `precioOferta` (descuento individual configurado en el catálogo). Este se aplica automáticamente vía `effectiveUnitPrice` en [`matching_model.dart:143-146`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/models/matching_model.dart#L143-L146), pero **no hay UI que lo explique ni que le permita al usuario activar/desactivar este descuento individual** desde el matching.

3. **En el modal de detalles** ([`product_quote_detail_modal.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/matching/product_quote_detail_modal.dart)), existe un `SwitchListTile` "Precio Especial al Cliente" (líneas 381-389) para descuento manual, pero **no hay sección que muestre las promociones/bundles disponibles** para ese producto. El usuario no tiene visibilidad ni control.

---

## Propuesta de Cambios por Fases

### Fase 1: Saneamiento y Corrección de Toques

> **Objetivo:** Eliminar los desbordes, hacer que todos los toques funcionen correctamente y estabilizar el layout actual sin cambiar la UX.

#### [MODIFY] [`matching_item_row.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/matching/matching_item_row.dart)

**Correcciones de Layout:**
1. **Quitar la imagen de la tarjeta compacta.** El `Container(width: 55, height: 55)` de la imagen en la tarjeta vinculada ocupa espacio precioso. En el estado compacto la imagen no aporta valor; se mostrará en el modal y en el estado expandido (Fase 3).
2. **Mover controles `+/-` fuera del `InkWell` de detalles.** Reestructurar la tarjeta para separar la "zona de información" (tappable para abrir modal) de la "zona de acciones" (controles +/-, desvincular, cambiar).
3. **Ajustar flex ratios:** Cambiar de `35/60` a `30/65` (más espacio para la tarjeta de producto). Reducir el ancho del botón eliminar de `45` a `36` (icono más pequeño).
4. **Usar `FittedBox` defensivo** en el precio y subtotal para que escalen en lugar de desbordar.

**Correcciones de Toques:**
1. **Separar la zona de tap del modal de la zona de controles `+/-`.** Arquitectura propuesta:
   ```
   Column [
     InkWell(onTap: onTapProduct) -> [Marca, Nombre, Precio, Badge de descuento]
     Row [Controles +/-, Subtotal]
     Divider
     Row [Desvincular | Cambiar]
   ]
   ```
2. **Agregar un `HitTestBehavior.opaque`** al `InkWell` del modal para que no se traguen los taps.

---

### Fase 2: Arquitectura del Estado del Swipe

> **Objetivo:** Crear el gestor de estado local que controla qué filas están expandidas/contraídas.

#### [MODIFY] [`matching_item_row.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/matching/matching_item_row.dart)

- **Convertir** de `StatelessWidget` a `StatefulWidget`.
- Agregar un `bool _isExpanded = false` local al state.
- Agregar un `GestureDetector` con `onHorizontalDragUpdate` y `onHorizontalDragEnd`:
  - **Drag hacia la izquierda** (dx negativo): si `_isExpanded == false`, transicionar a `_isExpanded = true` (contraer tarjeta izquierda, expandir derecha).
  - **Drag hacia la derecha** (dx positivo): si `_isExpanded == true`, transicionar a `_isExpanded = false` (restaurar).
  - **Umbral mínimo**: 40px de desplazamiento para activar el toggle. Esto evita toggles accidentales durante scroll vertical.

#### [MODIFY] [`matching_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/matching_screen.dart)

- Pasar un callback `onExpanded(int index, bool expanded)` al `MatchingItemRow` si se necesita coordinación global (por ejemplo, para colapsar automáticamente las demás filas al expandir una). Sin embargo, según el requerimiento, **cada fila es independiente**, así que el estado local en cada widget es suficiente.

> [!NOTE]
> Se usa estado **local** (`StatefulWidget`) en lugar de estado global (`MatchingProvider`) porque la expansión es puramente visual/de interacción y no afecta los datos del negocio. Esto mantiene el provider limpio y evita rebuilds innecesarios.

---

### Fase 3: Construcción de UI Condicional (Compacta vs Expandida)

> **Objetivo:** Construir las dos vistas de la fila con transiciones fluidas.

#### [MODIFY] [`matching_item_row.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/matching/matching_item_row.dart)

**Estado Compacto (default, `_isExpanded == false`):**
- **Tarjeta Izquierda (flex: 30):** Muestra `#N`, nombre del producto extraído, cantidad/unidad, botón eliminar.
- **Tarjeta Derecha (flex: 65):**
  - Marca + Nombre + Presentación (RichText, maxLines: 2).
  - Precio total de la línea (sin desglose sub-precio). Si `hasDiscount`, mostrar un indicador sutil (ej. un ícono `%` o un badge "Oferta").
  - Cantidad seleccionada como texto estático (solo el número, sin botones `+/-`).
  - Botones `Desvincular`/`Cambiar` **solo con íconos** (sin labels de texto): `🔗💔` y `🔍`.
  - **Sin imagen de producto.**

**Estado Expandido (`_isExpanded == true`):**
- **Tarjeta Izquierda (colapsada, width fijo ~55px):** Solo muestra el badge `#N` centrado.
- **Tarjeta Derecha (ocupa el resto):**
  - Imagen del producto (50x50).
  - Marca + Nombre + Presentación (maxLines: 3).
  - Unidad de venta completa (`"Unidad (x1)"`).
  - Precio detallado con desglose: precio original tachado + precio con descuento + subtotal.
  - **Botones `+`/`-`** completos para editar stock.
  - Botones `Desvincular`/`Cambiar` **con nombres completos**.
  - Indicador de que tiene ofertas vinculadas (si aplica).

**Animaciones:**
- Usar `AnimatedContainer` con `duration: Duration(milliseconds: 250)` y `curve: Curves.easeInOut` para la transición del ancho de las tarjetas.
- Usar `AnimatedCrossFade` para alternar entre el contenido compacto y expandido de la tarjeta derecha.
- Usar `AnimatedOpacity` para el fade-in del contenido adicional (imagen, controles).

---

### Fase 4: Rediseño del Modal e Integración de Ofertas

> **Objetivo:** Eliminar el botón global de ofertas y mover la gestión de ofertas al modal de detalles del producto.

#### [MODIFY] [`product_quote_detail_modal.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/matching/product_quote_detail_modal.dart)

**Nuevo Parámetro:**
- Agregar `List<BundleModel> availableBundles` y `Map<int, List<BundleItemModel>> bundleItemsCache` al constructor (se los pasa el `MatchingScreen`).

**Nueva Sección "Ofertas Vinculadas":**
- Ubicación: **después** del selector de variantes y **antes** del "Precio Especial al Cliente".
- Detecta automáticamente:
  1. ¿El producto actual (`productId`) aparece en algún bundle de `availableBundles`?
  2. ¿El producto tiene `precioOferta` activo?
- **Si hay ofertas disponibles**, renderizar:
  ```
  Container con borde amber, icono `local_offer` y título "Ofertas Disponibles"
  Subtítulo: "Aplica una promoción disponible para este producto"
  
  ListView horizontal con chips/cards:
    - Cada bundle donde aparece el producto, mostrando: nombre del pack, precio del pack, ahorro estimado
    - Si tiene precioOferta individual: chip "Descuento Individual: -X%"
  
  Botón de toggle para activar/desactivar cada oferta.
  ```
- **Si no hay ofertas**, no mostrar nada (la sección desaparece).

#### [MODIFY] [`matching_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/matching_screen.dart)

- En [`_openDetailsModal`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/matching_screen.dart#L430), pasar `matchingProvider.activeBundles` y el cache de items al modal.
- **Eliminar** el banner global de "IA: Promociones analizadas" en [líneas 824-846](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/matching_screen.dart#L824-L846). La gestión de ofertas ahora vive dentro del modal de cada producto.
- Ajustar el `initialChildSize` del modal de `0.55` a `0.70` para acomodar la nueva sección de ofertas.

---

## Verificación

### Pruebas Manuales
1. **Layout:** Verificar con productos de nombre largo (ej. "Block de Cartulina A4 Colors 14 Hojas") que no haya desborde en la tarjeta compacta.
2. **Toques:** Tocar en la zona de nombre del producto → debe abrir el modal. Tocar `+`/`-` (en estado expandido) → debe cambiar cantidad sin abrir modal.
3. **Swipe:** Arrastrar horizontalmente una fila → la tarjeta izquierda colapsa, la derecha se expande. Arrastrar de vuelta → se restaura. Verificar que múltiples filas pueden estar expandidas simultáneamente.
4. **Ofertas en Modal:** Abrir el modal de un producto con `precioOferta` → debe mostrar la sección de ofertas. Abrir un producto sin ofertas → la sección no debe aparecer.
5. **Scroll vertical:** Verificar que el swipe horizontal no interfiere con el scroll vertical de la lista.

### Compilación
- Verificar que la app compile sin errores con `flutter build apk`.

## Open Questions

> [!IMPORTANT]
> **Sobre la imagen:** ¿Prefieres que la imagen se elimine completamente del estado compacto (como propongo), o prefieres que se reduzca a un tamaño más pequeño (ej. 30x30)?

> [!IMPORTANT]
> **Sobre la interacción:** El swipe horizontal puede interferir con el scroll vertical en la lista. ¿Prefieres un **umbral angular** (solo activar si el ángulo de drag es más horizontal que vertical), o prefieres un **botón de toggle** (un ícono de chevron que al tocarlo expande/contrae la fila) en lugar del gesto de swipe?
