# Plan de Implementación: Corrección de Modales de Detalles y Sincronización de Variantes

## Resumen del Análisis y Comprensión del Problema

He analizado a profundidad el flujo de datos de los modales de "Cotización Manual" y "Caja Rápida", así como la forma en la que se comunican con sus respectivos proveedores (Providers). 

He identificado exactamente el origen de los **5 problemas** que me has reportado:

1. **Pérdida del Monto al Desactivar/Reactivar Descuento:** Cuando se apaga el switch (toggle) del descuento, el código limpia los controladores (`_discountCtrl.text = ""`). El problema ocurre al reactivarlo: el código simplemente prende la variable `_isManualPrice = true` pero **nunca** intenta volver a leer el descuento original de la base de datos (`offerPrice`).
2. **Activación Fantasma ("Ghost Toggle") en Variantes Sin Descuento:** En el evento inicial (`initState`), el código evalúa si se debe activar el switch de descuento. Actualmente lo activa si `initialOverridePrice != null`. Sin embargo, la pantalla anterior **siempre** envía este valor (incluso si es el precio normal sin descuento), haciendo que el switch se prenda aunque el monto a descontar sea nulo/vacío, causando gran confusión.
3. **El "Fix" de Navegar entre Variantes:** Al cambiar de variante, se dispara la función `_updateVariant`, la cual sí está correctamente programada para leer el descuento base del inventario. Por eso, ir a otra variante y regresar funciona como un parche temporal.
4. **Bloqueo en Productos de Una Sola Variante:** Como en estos productos no hay "chips" para cambiar de variante, no se puede disparar `_updateVariant`, haciendo imposible recuperar el descuento si el switch se apagó accidentalmente.
5. **Fallo al Guardar Variante en Caja Rápida:** Cuando cambias la variante en el modal de Caja Rápida y presionas "Guardar", la nueva variante tiene un ID distinto (`presentationId`). El problema crítico es que el `QuickSaleProvider` intenta buscar el **nuevo ID** dentro del carrito para actualizarlo, pero en el carrito todavía está el **viejo ID**. Al no encontrarlo (el índice devuelve `-1`), la función aborta en silencio y no guarda nada.

---

## Modificaciones Consideradas y Propuestas

El enfoque principal no será reescribir la UI, sino arreglar la lógica del manejo del estado y la forma en la que los Providers buscan y actualizan los datos.

### Archivos Involucrados:
- `manual_quote_detail_modal.dart`
- `quick_sale_detail_modal.dart`
- `quick_sale_screen.dart`
- `quick_sale_provider.dart`

---

## Fases del Procedimiento

### Fase 1: Corrección de la Inicialización Fantasma (Ambos Modales)
- **Acción:** Modificar el `initState` en ambos modales.
- **Detalle:** Cambiaremos la lógica para que el switch de descuento **solo** se active inicialmente si la diferencia matemática (el descuento real) es mayor a 0. Esto evitará que variantes sin descuento muestren el toggle activado por error.

### Fase 2: Recuperación Automática del Descuento (Ambos Modales)
- **Acción:** Modificar el evento de activación del Toggle (`onToggle` / `onChanged`).
- **Detalle:** Añadiré una lógica que detecte cuándo el usuario reactiva el switch. Si el sistema detecta que esa variante en particular *sí* posee un `offerPrice` (precio de oferta en inventario base), rellenará automáticamente el campo del monto a descontar y recalculará el precio final. Ya no se quedará en blanco.

### Fase 3: Reparación del Cambio de Variante (Caja Rápida)
- **Acción:** Modificar la lógica de `QuickSaleProvider` y el Callback de `quick_sale_screen.dart`.
- **Detalle:** 
  - Se modificará la firma de `updateItemFromModal` en el Provider para que reciba también el `oldPresentationId` (El ID original antes de abrir el modal).
  - Al presionar "Guardar Cambios", el provider usará este `oldPresentationId` para ubicar con exactitud qué elemento del carrito se está reemplazando, y lo sobreescribirá correctamente con las propiedades de la nueva variante.
  - Se actualizará también el diccionario de cantidades y de sobreescritura de precios. 

## User Review Required

Por favor revisa este plan. Aborda y da solución lógica exacta a cada uno de los puntos que encontraste en la auditoría. Si estás de acuerdo con la estrategia propuesta, haz clic en **Proceed / Proceder** para que inicie las modificaciones en el código.
