# Plan: Cotización Inteligente — Estado Visual, Población de Datos y Resiliencia del Modal

---

## Diagnóstico Técnico Profundo

### Archivos Analizados

| Archivo | Propósito | Líneas Clave |
|---|---|---|
| [`matching_item_row.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/matching/matching_item_row.dart) | Widget de la fila de matching (Swipe, Expand/Collapse) | L35-53, L86-121 |
| [`matching_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/matching_screen.dart) | Pantalla que orquesta el modal y los callbacks | L430-512, L736-761 |
| [`matching_provider.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/providers/matching_provider.dart) | Lógica de estado: `unmatchItem`, `updatePairProduct` | L262-307 |
| [`product_quote_detail_modal.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/matching/product_quote_detail_modal.dart) | Modal de detalle del producto | L44-133 |
| [`matching_model.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/models/matching_model.dart) | Modelo `MatchedProduct` | L10-99 |
| [`matching_service.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/matching_service.dart) | Servicio de matching (construcción de `MatchedProduct`) | L140-163 |
| [`inventory_provider.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/catalog/providers/inventory_provider.dart) | Provider de inventario: `products`, `getFullProduct`, `getFullProductWithFallback` | L145, L190-237 |

---

### 🔴 Hallazgo 1: Desincronización de Estado Visual (Swipe Atascado)

> [!WARNING]
> El `didUpdateWidget` de `matching_item_row.dart` (L45-53) **sí intenta colapsar** la tarjeta cuando el producto se desvincula. El problema es que la condición `oldWidget.pair.selectedProduct != null && widget.pair.selectedProduct == null` solo cubre el caso de "producto → null", pero **no fuerza un `setState`** al resetear `_isExpanded`. La variable se modifica directamente sin `setState(() => ...)`, lo que significa que Flutter NO repinta el widget. El `AnimatedContainer` del lado izquierdo (L86-91) que controla el ancho (`_isExpanded ? 50.0 : width * 0.30`) se queda atascado en `50.0` (modo expandido) incluso después de que el producto fue removido.
>
> **Resultado visual:** La tarjeta izquierda se queda comprimida a 50px, el placeholder rojo de "Tocar para vincular" aparece dentro de un espacio estrecho, y el layout entero colapsa.

### 🔴 Hallazgo 2: Modal Bloqueado — `products` No Contiene el Producto

> [!IMPORTANT]
> **Aquí está la raíz del bug grave.** En `matching_screen.dart` (L438), la función `_openDetailsModal` intenta:
> ```dart
> fullProduct = inventoryProv.products.firstWhere((p) => p.id == pair.selectedProduct!.productId);
> ```
> El getter `products` (L145 de `inventory_provider.dart`) devuelve:
> ```dart
> List<Product> get products => _inventoryItems.map((e) => e.product).toSet().toList();
> ```
> Esto **solo contiene los productos cargados en memoria** (la página actualmente visible del inventario). Si el usuario abrió la pantalla de matching directamente sin haber cargado todo su catálogo en la pantalla de inventario, los productos encontrados por el `MatchingService` (que busca en la BD) **no están en `_inventoryItems`**. 
>
> **El `firstWhere` lanza una excepción**, y el `catch` genera un `Product` de fallback **SIN presentaciones pobladas desde la BD** (L440-453). Sin embargo, este fallback sí crea UNA presentación. El verdadero problema ocurre cuando el `Product` SÍ se encuentra en `inventoryProv.products` pero con `presentaciones` vacías (porque ese getter construye `Product` desde `InventoryWrapper` que solo tiene UNA presentación descompuesta, no la lista completa). Cuando `fullProduct.presentaciones.isEmpty` es `true` (L456), se muestra el error rojo.
>
> **Ya existe una solución en el código:** `getFullProductWithFallback(productId)` (L229-237) que primero busca en memoria con ALL presentaciones, y si falla, hace fetch a la BD. Sin embargo, `_openDetailsModal` **NO lo usa**. Usa el getter `products` directo que es incompleto.

---

## Plan de Trabajo por Fases

### Fase 1: Estabilización de Estado Visual (Reset Forzado de `_isExpanded`)

#### [MODIFY] [`matching_item_row.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/matching/matching_item_row.dart) (L44-53)

El fix es envolver la mutación de `_isExpanded` dentro de un `setState` para que Flutter realmente repinte el widget:

```diff
  @override
  void didUpdateWidget(MatchingItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);
-   if (oldWidget.pair.selectedProduct != null && widget.pair.selectedProduct == null) {
-     // Force collapse when product is unlinked
-     if (_isExpanded) {
-       _isExpanded = false;
-     }
-   }
+   if (oldWidget.pair.selectedProduct != null && widget.pair.selectedProduct == null) {
+     // Force collapse when product is unlinked — MUST use setState to trigger rebuild
+     if (_isExpanded) {
+       setState(() {
+         _isExpanded = false;
+       });
+     }
+   }
  }
```

**Impacto:** Las animaciones (`AnimatedContainer`, `AnimatedCrossFade`, `AnimatedSwitcher`) que dependen de `_isExpanded` ahora recibirán correctamente el estado actualizado y harán la transición suave de vuelta al estado colapsado.

### Fase 2: Reparación de Población de Datos (Eager Loading con `getFullProductWithFallback`)

#### [MODIFY] [`matching_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/matching_screen.dart) (L430-460)

Reemplazar la estrategia de búsqueda síncrona (que falla para productos no cargados en memoria) por la función `getFullProductWithFallback` que YA EXISTE en el código pero no se usa:

```diff
- void _openDetailsModal(BuildContext context, MatchPair pair) {
+ Future<void> _openDetailsModal(BuildContext context, MatchPair pair) async {
    if (pair.selectedProduct == null) return;
    
    try {
      final inventoryProv = Provider.of<InventoryProvider>(context, listen: false);
-     Product? fullProduct;
-     
-     try {
-       fullProduct = inventoryProv.products.firstWhere((p) => p.id == pair.selectedProduct!.productId);
-     } catch (_) {
-       fullProduct = Product(
-         id: pair.selectedProduct!.productId, nombre: pair.selectedProduct!.productName, ...
-         presentaciones: [ ProductPresentation(...) ]
-       );
-     }
+     Product? fullProduct = await inventoryProv.getFullProductWithFallback(pair.selectedProduct!.productId);
```

**Impacto:** `getFullProductWithFallback` primero intenta reconstruir el `Product` con TODAS sus presentaciones desde la memoria (`_inventoryItems`), y si no encuentra nada, hace `fetchProductById` directo a la BD SQLite. Esto garantiza que los productos de coincidencias parciales (amarillos), repetidos (azules) y cualquier otro tipo siempre tengan sus presentaciones completas.

### Fase 3: Resiliencia del Modal (Fallback de Presentación por Defecto)

#### [MODIFY] [`matching_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/matching_screen.dart) (L456-459)

Si después de usar `getFullProductWithFallback`, el producto sigue sin presentaciones (caso extremo de BD corrupta), en lugar de mostrar un error rojo, inyectar una presentación por defecto basada en los datos del `MatchedProduct`:

```diff
      if (fullProduct.presentaciones.isEmpty) {
-       CustomSnackBar.show(context, message: "Error: El producto no tiene presentaciones válidas.", isError: true);
-       return;
+       // FALLBACK: Inyectar presentación por defecto desde los datos del MatchedProduct
+       fullProduct = Product(
+         id: fullProduct.id,
+         nombre: fullProduct.nombre,
+         marcaId: fullProduct.marcaId,
+         categoriaId: fullProduct.categoriaId,
+         imagenUrl: fullProduct.imagenUrl ?? pair.selectedProduct!.imageUrl,
+         presentaciones: [
+           ProductPresentation(
+             id: pair.selectedProduct!.presentationId,
+             unidadVenta: pair.selectedProduct!.unit,
+             nombreEspecifico: pair.selectedProduct!.specificName,
+             precioVentaFinal: pair.selectedProduct!.price,
+             precioOferta: pair.selectedProduct!.offerPrice,
+             stockActual: pair.selectedProduct!.stock,
+             unidadesPorLote: pair.selectedProduct!.conversionFactor,
+             imagenUrl: pair.selectedProduct!.imageUrl,
+           )
+         ],
+       );
      }
```

**Impacto:** El modal SIEMPRE se abrirá. En el peor de los casos (sin datos en memoria NI en BD), el sistema construye una presentación mínima desde los datos que ya tiene el `MatchedProduct`. El usuario podrá ver y editar el producto sin bloqueos.

---

## Verificación

- Compilación limpia: `flutter analyze` con 0 errores.
- **Test visual 1:** Desvincular un producto expandido → la tarjeta debe volver instantáneamente a su ancho original (no quedarse comprimida).
- **Test visual 2:** Tap en producto amarillo/azul → el modal DEBE abrirse correctamente mostrando las presentaciones.
- **Test visual 3:** Si un producto no existe en BD, el modal debe abrirse igualmente con la presentación base (fallback).
