# Plan de Integración Global: Ecosistema de Paquetes (Fase 5)

He analizado profundamente la arquitectura actual para evaluar cómo el nuevo sistema de "Promociones y Paquetes" interactúa con las Cotizaciones Manuales, Cotizaciones por IA, el Checkout de Cotizaciones, el Catálogo, los Modales de Detalles y los Filtros.

Aquí presento el diagnóstico detallado y el plan de acción para garantizar una cobertura total del 100% sin romper ninguna lógica existente.

## Diagnóstico y Análisis Profundo

1. **Cotizaciones Manuales (`manual_quotation_screen.dart`)**
   - **Estado Actual:** No soporta añadir Paquetes (Bundles). El proveedor guarda los datos en base a `presentationId`, pero omite por completo el `bundle_id`.
   - **Solución:** Implementaremos la misma barra deslizante horizontal de "🔥 Paquetes Disponibles" que desarrollamos en la Caja Rápida. Además, actualizaremos la carga útil (payload) de guardado para incluir el `bundle_id`.

2. **Cotizaciones por IA (`matching_screen.dart` y `matching_service.dart`)**
   - **Estado Actual:** La IA busca coincidencias exactas en la tabla de `productos`. Como los "Paquetes" viven en su propia tabla, la IA nunca los asignará automáticamente. 
   - **Solución (Sin romper la IA):** Modificaremos el **Modal de Búsqueda de Productos** (`MatchingProductSearchModal`) para incluir los paquetes. Si la IA extrajo "Pack de 3 útiles" y no encontró nada, el usuario podrá tocar ese ítem y reemplazarlo manualmente por un "Paquete" del sistema.

3. **Conversión de Cotizaciones a Ventas (Checkout)**
   - **Estado Actual:** El `CheckoutProgressDialog` hace una verificación manual del inventario antes de procesar el pago. Como los Paquetes usan un ID falso/negativo, la validación falla silenciosamente (no crashea, pero no verifica).
   - **Solución:** Introducir una regla de exclusión visual (`if item.bundleId != null, saltar verificación individual`). La verdadera validación del stock dinámico ya está protegida en la transacción de base de datos dentro de `sales_service.dart`.

4. **El Catálogo (`catalog_screen.dart`) y Sistemas de Filtros**
   - **Estado Actual:** El catálogo asume que todo ítem es un `InventoryWrapper` (un Producto real con una Presentación real). Los Paquetes son abstracciones virtuales compuestas por múltiples productos.
   - **Análisis Arquitectónico:** **NO es recomendable** forzar la entrada de los Paquetes en el Catálogo principal. El catálogo está diseñado para la gestión de inventario individual (SKUs). Los paquetes no tienen "Categoría" ni "Marca" única, por lo que romperían los sistemas de Filtros.
   - **Solución:** Mantener la separación arquitectónica. Los productos individuales se gestionan en el "Catálogo", y los Paquetes se gestionan en la pestaña "Ofertas / Promociones". Esto garantiza que la lógica CRUD y de filtros del catálogo se mantenga intacta y de alto rendimiento.

5. **Modales de Detalles**
   - **Estado Actual:** En las pantallas de historial y cotizaciones, si tocas un ítem para ver sus detalles, el sistema busca su `product_id`. Como los paquetes usan `product_id: 0`, el modal de detalles se rompe o muestra "Desconocido".
   - **Solución:** Modificar la lógica de apertura de modales. Si el sistema detecta que el ítem tiene un `bundle_id != null`, debe mostrar un modal especial de "Detalle de Paquete" o, alternativamente, mostrar un modal de solo lectura indicando que es una oferta compuesta.

---

## User Review Required
> [!IMPORTANT]
> El enfoque principal de este plan es adaptar las Cotizaciones Manuales y de IA, y proteger el Catálogo manteniendo los Paquetes en su propio módulo. Si estás de acuerdo con este análisis y plan de acción, presiona **Proceed** para comenzar a codificar.

---

## Proposed Changes

### Cotizaciones Manuales
#### [MODIFY] [manual_quotation_screen.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/manual_quotation_screen.dart)
- Inyectar el carrusel de Paquetes Disponibles.
- Enviar el parámetro `bundle_id` al ejecutar `_executeSave`.

#### [MODIFY] [quotation_service.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/quotation_service.dart)
- En `saveManualQuotation`, extraer y persistir el campo `bundle_id` en la base de datos (`smart_quotation_items`).
- En `validateIntegrity`, omitir la alerta de "Producto Desconocido" si el ítem es un paquete.

### Cotizaciones por IA (Matching)
#### [MODIFY] [matching_product_search_modal.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/matching/matching_product_search_modal.dart)
- Incluir un contenedor de "Paquetes Activos" en la búsqueda manual.

#### [MODIFY] [matching_service.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/matching_service.dart)
- En `saveQuotation`, persistir el campo `bundle_id` al guardar los resultados de la IA en la BD local.

### Checkout & Modales
#### [MODIFY] [checkout_progress_dialog.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/checkout/checkout_progress_dialog.dart)
- Agregar un condicional para que la barra de progreso salte inteligentemente la revisión de stock pre-transaccional de los bundles (para evitar falsos errores o cuellos de botella).

## Verification Plan
1. Crear una **Cotización Manual** agregando un paquete desde la nueva barra de acceso rápido.
2. Crear una **Cotización por IA**, reemplazar un ítem reconocido erróneamente por un Paquete.
3. Proceder al pago (Checkout) desde ambas cotizaciones y comprobar que no hay errores de validación y el "Un-kitting" se ejecuta correctamente.
