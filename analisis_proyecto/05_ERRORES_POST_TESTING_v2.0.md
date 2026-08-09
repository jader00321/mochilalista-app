# 05. ANÁLISIS DE ERRORES POST-TESTING v2.0 Y PLAN DE CORRECCIÓN

**Fecha:** 04 de Agosto de 2026  
**Versión analizada:** mochilaLista 2.0 (APK release)  
**Origen:** Pruebas manuales en dispositivo físico Android

---

## RESUMEN EJECUTIVO

Tras instalar y probar la versión 2.0 del APK en un dispositivo real, se han detectado **5 problemas funcionales** y **1 problema visual** que afectan la experiencia de uso. Todos los problemas tienen una raíz común: **la forma en que se cargan, pasan y registran los datos de productos** entre las capas de la aplicación (DB → Providers → Screens → Modals).

---

## DIAGNÓSTICO DETALLADO DE ERRORES

### ERROR 1: Modal de Producto en Inventario no carga datos (stock, precio, botones)

**Síntoma:** Al presionar un producto en la pestaña "Productos" del Inventario, el modal (`ProductActionSheet`) muestra el nombre del producto pero el precio aparece como "S/ 0.0", el stock como "0" y los botones "Ver Detalle" y el switch Público/Privado no funcionan.

**Causa raíz:** El `ProductActionSheet` recibe un objeto `Product` desde `InventoryProvider.items`, pero ese `Product` fue creado por `ProductQueries.parseInventoryRow()` a partir de una consulta SQL tipo JOIN que devuelve **una fila por presentación** (flat row). Cuando `Product.fromJson()` parsea esa fila plana, el campo `json['presentaciones']` es `null` (porque el JOIN no lo incluye como lista anidada), resultando en `presentaciones = []` (lista vacía).

Consecuencias directas:
- `freshProduct.presentaciones.isEmpty` es `true` → se crea un `selectedPresentation` con `id: -1`, `precioVentaFinal: 0.0`, `stockActual: 0`, `estado: 'privado'`.
- Todos los botones verifican `if (selectedPresentation.id == -1) return;` → no hacen nada.
- El switch Público/Privado ejecuta `provider.updatePresentation(selectedPresentation.id!)` pero como `id == -1`, no actualiza nada.

**Solución:** En `InventoryProvider`, al construir la lista de productos para el `ProductActionSheet`, se deben **inyectar las presentaciones reales** al objeto `Product`. Esto implica que cuando se pase un `Product` al `ProductActionSheet`, se recopilen todas las presentaciones de ese producto desde `_inventoryItems` y se le asignen.

---

### ERROR 2: Pantalla de Edición no carga datos del producto

**Síntoma:** Al presionar "Editar Todo" en el modal y navegar a `ProductEditScreen`, solo se muestra el nombre del producto. Los campos de categoría, marca, presentaciones y demás están vacíos.

**Causa raíz:** Es la misma que el Error 1. El `Product` que se pasa a `ProductEditScreen` tiene `presentaciones = []`. La pantalla de edición en `_loadExistingData()` itera sobre `p.presentaciones` (línea 67) para popular los controladores de cada presentación, pero como la lista está vacía, no se genera ningún formulario de presentación. La categoría y marca sí se cargan correctamente del objeto `Product`, pero si el `categoriaId` no coincide con ninguna categoría cargada en el `InventoryProvider`, la selección queda vacía.

**Solución:** Antes de navegar a `ProductEditScreen`, se debe llamar a `fetchProductById()` para obtener el producto completo con todas sus presentaciones desde la base de datos, o bien enriquecer el `Product` con las presentaciones recopiladas del inventario.

---

### ERROR 3: Venta Rápida registra "Producto Desconocido"

**Síntoma:** Al completar una venta rápida en "Caja Rápida", y luego ir al historial de ventas, el recibo muestra "Producto Desconocido" en vez del nombre real del producto vendido.

**Causa raíz:** En `quick_checkout_modal.dart` (línea 68-73), al construir el `detalleVenta` que se envía al `processCheckout`, los items **solo incluyen 3 campos**: `presentation_id`, `quantity` y `unit_price`. No se envía `nombre_producto`, `product_name`, `brand_name`, `specific_name` ni `unidad_medida`.

Luego, en `sales_service.dart` (línea 105-108), al insertar los items en la tabla `venta_items`, se busca el nombre con:
```dart
'nombre_producto': item['nombre_producto'] ?? item['product_name'] ?? 'Producto Desconocido',
```
Como ninguno de esos campos existe en el `detalleVenta`, se usa el fallback `'Producto Desconocido'`.

**Nota:** Las ventas provenientes de cotizaciones inteligentes sí funcionan porque sus items se cargan desde la tabla `smart_quotation_items` que sí tiene el campo `product_name`.

**Solución:** Enriquecer el mapa `detalleVenta` en el `QuickCheckoutModal` para incluir todos los campos que `sales_service.dart` necesita (`nombre_producto`, `brand_name`, `specific_name`, `unidad_medida`, `product_id`, `original_unit_price`, `is_manual_price`).

---

### ERROR 4: Verificación de reducción de stock

**Síntoma:** Potencial fallo en la reducción de stock después de una venta rápida.

**Causa raíz:** Este problema parece funcional. En `sales_service.dart` (línea 88-91), el stock sí se reduce:
```dart
await txn.rawUpdate(
  'UPDATE presentaciones_producto SET stock_actual = stock_actual - ? WHERE id = ?',
  [quantity, presId],
);
```
Sin embargo, la validación del `presId` depende de que `item['presentation_id']` sea correcto. Dado que el `detalleVenta` del checkout rápido SÍ envía `presentation_id`, la reducción de stock debería estar funcionando correctamente. Se verificará durante la implementación.

**Solución:** Validar empíricamente que el stock se reduzca tras la corrección del Error 3. No se espera un cambio de código aquí.

---

### ERROR 5: Toggle de descuento no se puede desactivar (Caja Rápida / Cotización Manual)

**Síntoma:** En el modal detallado del producto (`QuickSaleDetailModal`), al activar el switch "Aplicar Descuento", modificar el precio, y luego intentar desactivar el switch, el descuento parece persistir o la UI no responde al cambio.

**Causa raíz:** En `quick_sale_detail_modal.dart` (líneas 274-277), el `onChanged` del switch hace:
```dart
onChanged: (v) => setState(() {
  _isManualPrice = v;
  if (!v) { _priceCtrl.text = _systemPrice.toStringAsFixed(2); _discountCtrl.text = ""; }
}),
```
El código parece correcto en su lógica directa. Sin embargo, el problema podría estar en que cuando el producto ya tiene un `offerPrice` aplicado del inventario (no manual), la variable `_isManualPrice` se inicializa como `true` en `initState` (línea 55-57) incluso si el descuento proviene del inventario. Al intentar desactivarlo, se restaura `_systemPrice` pero el `_confirm()` pasa `overridePrice: null`, lo cual **elimina el override pero el `offerPrice` del inventario sigue activo**, y el provider lo recalcula como `item.offerPrice ?? item.price`, manteniendo el descuento del sistema.

**Solución:** Agregar una forma de "forzar precio sin descuento" cuando el usuario desactive manualmente el toggle. Esto implica que cuando se desactive, el `overridePrice` se establezca explícitamente al `_systemPrice` (precio base) para sobrescribir cualquier `offerPrice` del inventario.

---

### ERROR 6: Banner rojo permanente en la pantalla Home

**Síntoma:** En la esquina superior de la pantalla "Inicio" (Home), aparece un banner rojo con el texto "Sin conexión a internet" en todo momento, lo cual se ve poco profesional.

**Causa raíz:** En `connectivity_banner.dart` (línea 19), el listener de conectividad recibe un `ConnectivityResult`, pero la API actual de `connectivity_plus` en versiones recientes devuelve un `List<ConnectivityResult>` en vez de un solo `ConnectivityResult`. Esto causa que el tipo del callback no coincida correctamente con lo esperado, y el banner podría estar mostrándose siempre porque `_isConnected` nunca se actualiza a `true`.

Además, en una aplicación **100% Offline-First** donde no se depende de internet para la mayoría de funciones, mostrar un banner permanente de "Sin conexión" es contraproducente. El banner debería mostrarse **solo cuando se necesite internet** (al usar el escáner AI de Gemini, por ejemplo) y no de forma global en el Home.

**Solución:** Actualizar el `ConnectivityBanner` para usar la API correcta de `connectivity_plus`, y limitar su aparición solo a las pantallas que requieran internet (escáner AI), eliminándolo del `HomeScreen`.

---

## PLAN DE CORRECCIÓN

### FASE 1: Corrección de carga de datos del producto (Errores 1 y 2)
> **Prioridad:** CRÍTICA — Afecta la funcionalidad principal del inventario.

**Archivo principal:** `lib/providers/inventory_provider.dart`

#### Paso 1.1: Crear método de enriquecimiento de `Product`
- Crear un nuevo getter o método en `InventoryProvider` que, dado un `productId`, recopile **todas** las `ProductPresentation` de ese producto desde `_inventoryItems` y construya un `Product` completo con su lista `presentaciones` populada.

#### Paso 1.2: Actualizar `ProductActionSheet` 
**Archivo:** `lib/widgets/product_action_sheet.dart`
- Modificar la lógica del `Consumer<InventoryProvider>` para que, en vez de buscar directamente en `provider.items`, utilice el método de enriquecimiento para obtener un `Product` con presentaciones completas.

#### Paso 1.3: Actualizar navegación a `ProductDetailScreen` y `ProductEditScreen`
**Archivos:** `lib/widgets/product_action_sheet.dart`, `lib/screens/tabs/products_tab.dart`
- Asegurar que siempre se pase un `Product` con presentaciones completas a las pantallas de detalle y edición.

---

### FASE 2: Corrección del registro de ventas rápidas (Error 3)
> **Prioridad:** CRÍTICA — Las ventas se registran sin identificación del producto.

**Archivo principal:** `lib/features/smart_quotation/widgets/quick_sale/quick_checkout_modal.dart`

#### Paso 2.1: Enriquecer el mapa `detalleVenta`
- Modificar el bloque de creación del `detalleVenta` (líneas 68-74) para incluir todos los campos necesarios:
  ```dart
  {
    "presentation_id": item.presentationId,
    "product_id": item.productId,
    "quantity": quickProv.getQuantity(item.presentationId),
    "unit_price": quickProv.getEffectivePrice(item.presentationId),
    "original_unit_price": item.price,
    "nombre_producto": item.productName,
    "product_name": item.productName,
    "brand_name": item.brand,
    "specific_name": item.specificName,
    "unidad_medida": item.unit,
    "is_manual_price": quickProv.getEffectivePrice(item.presentationId) != item.price ? 1 : 0,
  }
  ```

#### Paso 2.2: Verificar reducción de stock (Error 4)
- Realizar prueba empírica tras la corrección: crear una venta rápida y verificar en el inventario que el stock se redujo.

---

### FASE 3: Corrección del toggle de descuento (Error 5)
> **Prioridad:** MEDIA — Afecta UX de ventas con descuento.

**Archivo principal:** `lib/features/smart_quotation/widgets/quick_sale/quick_sale_detail_modal.dart`

#### Paso 3.1: Corregir lógica del toggle de descuento
- Cuando el usuario desactive el toggle "Aplicar Descuento", establecer explícitamente el override price al precio base del sistema (`_systemPrice`), para asegurar que se anule cualquier `offerPrice` del inventario:
  ```dart
  onChanged: (v) => setState(() {
    _isManualPrice = v;
    if (!v) {
      _priceCtrl.text = _systemPrice.toStringAsFixed(2);
      _discountCtrl.text = "";
    }
  }),
  ```
- Y modificar `_confirm()` para que cuando `!_isManualPrice` y el producto tenga `offerPrice`, se pase `_systemPrice` como `overridePrice` en vez de `null`.

---

### FASE 4: Corrección del banner rojo (Error 6)
> **Prioridad:** BAJA (Visual) — No afecta funcionalidad, pero degrada la apariencia.

**Archivos:** `lib/widgets/connectivity_banner.dart`, `lib/screens/home_screen.dart`

#### Paso 4.1: Actualizar API de `connectivity_plus`
- Corregir el listener para manejar `List<ConnectivityResult>` en vez de `ConnectivityResult`.

#### Paso 4.2: Remover el banner del Home
- Eliminar el wrapper `ConnectivityBanner` del `HomeScreen` ya que la app es Offline-First y no necesita internet para funcionar normalmente.
- Opcionalmente, mover el banner solo a la pantalla del escáner AI donde sí se necesita conexión.

---

## VERIFICACIÓN POSTERIOR

Tras aplicar las correcciones de cada fase:
1. **Compilar un nuevo APK** (`mochilaLista 2.1`) y guardarlo junto con su changelog en la carpeta `v2.0-app-offline apks/`.
2. **Pruebas en dispositivo:**
   - Abrir un producto desde inventario → confirmar que muestra stock, precio, estado público/privado.
   - Presionar "Ver Detalle" y "Editar Todo" → confirmar que abren con datos completos.
   - Realizar venta rápida → confirmar que el recibo muestra el nombre del producto.
   - Verificar reducción de stock tras venta.
   - Toggle de descuento → confirmar que se puede activar y desactivar sin problemas.
   - Home → confirmar que no hay banner rojo visible.
