# Diagnóstico y Plan: Pérdida de Datos en Variantes de Cotización

## 1. Hipótesis Técnica (Mapeo de Datos y Reactividad)
El problema principal radica en cómo se maneja el estado de `initialCustomName` dentro de `ManualQuoteDetailModal` y su posterior impacto en el renderizado de `ManualQuoteItemCard`.

**Análisis del flujo de error:**
1. **Origen del problema:** Al buscar y seleccionar un producto en `CatalogSearchModal`, el sistema le asigna un nombre compuesto (`fullNameBuilder`) y lo pasa forzosamente como `initialCustomName` hacia el modal de detalles.
2. **El estado estancado:** Cuando el usuario abre el modal de un producto ya listado y **cambia de variante** (ej. de Unidad a Caja), el método `_updateVariant` construye un nuevo objeto con los datos correctos de la nueva presentación. **Sin embargo**, el modal jamás actualiza ni descarta la variable `widget.initialCustomName`.
3. **El retorno erróneo:** Al darle a "Guardar Cambios", el modal devuelve la nueva variante pero la acompaña con el nombre "custom" de la presentación vieja. `ManualQuotationScreen` recibe esto y lo almacena en su mapa de estados `_customNames`.
4. **La consecuencia en la UI (`ManualQuoteItemCard`):** Al dibujar la tarjeta, evalúa si existe un `customName` que difiera del nombre de la nueva variante. Como detecta esta diferencia (por el arrastre del nombre viejo), activa el modo de **renderizado de "Nombre Personalizado"** (`hasCustomName = true`).
5. **El síntoma crítico:** Este modo de renderizado está diseñado para ítems manuales fuera de catálogo, por lo que **omite intencionalmente dibujar la Marca y el nombre específico estructurado**. Simplemente dibuja el texto viejo almacenado en el `customName`, dando la ilusión de que se perdió la marca, que el nombre no se actualizó y que la unidad principal está corrupta.

## 2. Cómo se solucionará el paso de datos
Para que el estado fluya correctamente desde el modal hasta la tarjeta listada y finalmente hacia la base de datos, aplicaremos el principio de **"Single Source of Truth" (Única fuente de verdad)** para el nombre de los productos del catálogo.

1. **Desacoplar el Custom Name en el Modal:** Haremos que el `ManualQuoteDetailModal` sea reactivo a los cambios. Si la presentación seleccionada cambia respecto a la original, el modal limpiará automáticamente cualquier "nombre personalizado" residual, devolviendo el control al nombre estructurado de la nueva variante.
2. **Limpiar la inyección en el Catálogo:** En `CatalogSearchModal`, dejaremos de inyectar `initialCustomName` para productos regulares del catálogo. Al dejarlo como `null`, la tarjeta utilizará automáticamente su layout profesional que incluye la Marca en texto destacado y los nombres específicos.
3. **Limpieza del Estado Global:** Garantizaremos que cuando el modal devuelva un nombre personalizado `null`, el `ManualQuotationScreen` remueva la llave correspondiente de su mapa `_customNames`, asegurando que la data guardada en SQLite dependa estrictamente de las columnas `product_name`, `brand_name` y `specific_name`.

## 3. Plan de Trabajo Detallado (Paso a Paso)

### Paso 1: Refactorización en `ManualQuoteDetailModal`
- Convertiremos el manejo del `initialCustomName` a una variable de estado reactiva (`_currentCustomName`).
- En el método `_updateVariant(ProductPresentation pres)`, añadiremos lógica para que, al detectar un cambio de variante (ID diferente al original), se asigne `_currentCustomName = null;`.
- En el método `_confirm()`, devolveremos este `_currentCustomName` reactivo en lugar de la variable estática del widget.

### Paso 2: Optimización de origen en `CatalogSearchModal`
- Modificaremos el método `_openDetail`. Actualmente inyecta `initialCustomName: fullNameBuilder`. Lo cambiaremos a `initialCustomName: null` para todos los productos de catálogo, permitiendo que la tarjeta procese la metadata real. (Mantendremos el custom name solo para "Paquetes Especiales" si aplica).

### Paso 3: Validación del Guardado en `ManualQuotationScreen`
- Modificaremos el callback `onConfirm`. Si la nueva variante reemplaza a la antigua y el `newName` devuelto es `null`, usaremos `_customNames.remove(newProd.presentationId);` para limpiar explícitamente el estado basura de la memoria y permitir un renderizado limpio.

### Paso 4: Pruebas y Verificación
- **Escenario 1:** Añadir producto A (Variante Unidad) -> Reabrir Modal -> Cambiar a Variante Caja -> Guardar. **Resultado esperado:** La tarjeta muestra la Marca, el nombre actualizado de la caja y no hay pérdida de datos.
- **Escenario 2:** Guardar la lista de cotización en borrador local y recargar la pantalla. **Resultado esperado:** Los datos se reconstruyen correctamente sin corrupción en la unidad.
