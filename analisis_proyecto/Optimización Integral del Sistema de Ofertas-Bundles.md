# Optimización Integral del Sistema de Ofertas/Bundles

Plan detallado para resolver bugs críticos, mejorar la UX y expandir la funcionalidad del ecosistema de promociones.

---

## 🔴 SECCIÓN CRÍTICA: Bug de Stock en Ventas de Cotizaciones con Bundles

> [!CAUTION]
> **Bug encontrado**: Al vender una lista cotizada que contiene un paquete/oferta, el stock NO se descuenta del inventario. Esto se debe a DOS fallas encadenadas en el flujo de datos.

### Diagnóstico Raíz

**Falla 1: `bundle_id` no se persiste al guardar la cotización**
- En [quotation_service.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/quotation_service.dart#L176-L190), el método `saveManualQuotation` inserta items en `smart_quotation_items` pero **NO incluye** el campo `bundle_id` en el INSERT, a pesar de que:
  - La tabla `smart_quotation_items` SÍ tiene la columna `bundle_id` (definida en el schema)
  - El payload del item SÍ contiene `bundle_id` (viene desde `manual_quotation_screen.dart` línea 533)
- **Resultado**: El `bundle_id` se pierde al guardar y queda como `NULL` en la base de datos.

**Falla 2: El servicio de ventas no puede hacer un-kitting sin `bundle_id`**
- En [sales_service.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/sales_service.dart#L46-L69), cuando una venta proviene de una cotización (`cotizacion_id != null`), los items se cargan desde `smart_quotation_items`.
- Como el `bundle_id` quedó como `NULL`, la lógica de un-kitting (líneas 76-103) que descompone el paquete en sus productos individuales para descontar stock **nunca se ejecuta**.
- El item tampoco tiene `presentation_id` (es `NULL` para bundles), así que la lógica de descuento de stock regular (líneas 104-167) también se salta con `continue`.
- **Resultado**: No se descuenta stock de ningún producto del paquete.

**Falla 3: `validateIntegrity` no valida bundles**
- En [quotation_service.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/quotation_service.dart#L61), la línea `if (item['presentation_id'] == null) continue;` ignora completamente los items de bundles durante la validación de integridad, por lo que la pantalla de detalle de cotización no muestra alertas de stock para paquetes.

---

## Plan de Cambios Organizados por Componente

### Fase 1: Corrección Crítica del Bug de Stock

---

#### [MODIFY] [quotation_service.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/quotation_service.dart)

1. **Persistir `bundle_id` al guardar items de cotización** (línea ~188):
   - Agregar `'bundle_id': item['bundle_id']` en el INSERT de `smart_quotation_items` dentro de `saveManualQuotation`.

2. **Validar stock de bundles en `validateIntegrity`** (línea ~60-141):
   - En lugar de hacer `continue` cuando `presentation_id == null`, verificar si `bundle_id != null`.
   - Si es un bundle, cargar los `items_paquete` del bundle y validar el stock de cada componente multiplicado por la cantidad solicitada.
   - Generar `StockWarning` apropiados si algún componente no tiene stock suficiente.

---

#### [MODIFY] [sales_service.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/sales_service.dart)

3. **Asegurar que `bundle_id` se propague desde `smart_quotation_items`** (línea ~54-69):
   - Verificar que el campo `'bundle_id': e['bundle_id']` ya se incluye en el mapeo de items desde la cotización. **Confirmado**: Sí se incluye en línea 66. El problema está únicamente en que el dato era `NULL` por la falla 1. Una vez corregida la falla 1, este flujo funcionará correctamente.

---

### Fase 2: Mejoras en la Pestaña de Ofertas (Insights/Sugerencias)

---

#### [MODIFY] [offers_tab.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/promotions/screens/offers_tab.dart)

4. **Lista de sugerencias retráctil con contador**:
   - Convertir `OffersTab` de `StatelessWidget` a `StatefulWidget` para manejar estado de expansión.
   - Reemplazar la renderización directa de `_buildInsights` por un panel colapsable (`ExpansionTile` o implementación custom).
   - Mostrar el panel retraído por defecto al entrar a la pestaña.
   - Mostrar un badge numérico junto al título indicando cuántas sugerencias hay (ej: "Insights & Sugerencias (3)").

5. **Indicador visual para productos con ofertas activas**:
   - Cruzar los productos sugeridos (`slowMovers`) con `promoProv.getBundlesForPresentation(p.presentation.id)`.
   - Si un producto ya tiene paquete activo, cambiar el estilo visual: borde y fondo diferente (ej: azul/verde en vez de naranja), agregar un chip/badge que diga "Ya tiene oferta activa".
   - Mantener el botón "Crear Promoción Relámpago" pero indicar visualmente que ya existe una.

6. **Nombre completo del producto en sugerencias**:
   - Reemplazar `p.product.nombre` (línea 308) con el nombre completo incluyendo marca y presentación.
   - Usar la lógica: `[Marca] Nombre - Presentación` (similar a `_fullName` de `BundleBuilderScreen`).

7. **Lógica de sugerencias mejorada: recomendar tipos de promoción existentes**:
   - Analizar cada producto sugerido contra los tipos de promoción disponibles (`_promoTypes` de `BundleBuilderScreen`).
   - Criterios de recomendación:
     - **Stock alto (>20 uds) + días sin rotar >30**: Sugerir "Liquidez" o "2x1".
     - **Stock medio (10-20) + días sin rotar 20-30**: Sugerir "Flash" o "Paquete Fusión" (combinar con otro producto de baja rotación).
     - **Stock bajo (5-10) + días sin rotar >20**: Sugerir "Mayoreo" con descuento por volumen.
   - Al presionar el botón de aplicar, navegar a `BundleBuilderScreen` con `initialTipoPromocion` configurado al tipo sugerido.

---

### Fase 3: Mejora del Campo de Precio de Venta en BundleBuilderScreen

---

#### [MODIFY] [bundle_builder_screen.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/promotions/screens/bundle_builder_screen.dart)

8. **Rediseño del campo de precio de venta total**:
   - **Problema actual**: El precio de venta es un `TextFormField` genérico con estilo de formulario básico, compartiendo fila con el switch de "Activo". Queda opacado por la sección de "Análisis de Rentabilidad" que es mucho más visual.
   - **Solución propuesta**: Crear un componente visual prominente tipo "hero card" para el precio:
     - Container con gradiente sutil (del color del tipo de promoción).
     - Mostrar el símbolo de moneda "S/" grande a la izquierda.
     - El precio editable en un estilo de texto grande y bold (fontSize ~28-32).
     - Debajo del precio, mostrar como texto secundario el "Valor original" tachado (el total sin descuento) para contexto visual inmediato.
     - AnimatedSwitcher para que cuando cambie el monto haya una micro-animación de transición.
     - Icono de edición (lápiz) que indique visualmente que es editable.
     - Botón de recalcular integrado visualmente.
     - Chip con el porcentaje de ahorro al cliente al lado del precio.
   - Mover el switch de "Activo" fuera de la fila del precio (reposicionar cerca del título o junto a fecha de campaña).
   - **Responsividad**: Usar `LayoutBuilder` para adaptar el tamaño del texto y distribución según el ancho disponible.

9. **Hacer responsive todos los componentes del modal**:
   - El selector de tipo de promoción: usar `LayoutBuilder` para calcular `width` dinámicamente en vez de la fórmula fija `(MediaQuery.of(context).size.width - 48) / 3`.
   - Los campos de fecha: permitir que se apilen verticalmente en pantallas muy pequeñas.
   - El análisis de rentabilidad: adaptar a columna en pantallas estrechas.
   - Los items del paquete: que la imagen, nombre y controles se adapten.

---

### Fase 4: Mostrar Descripción de Ofertas en Todas las Ventanas

---

#### [MODIFY] [catalog_screen.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/catalog/screens/catalog/catalog_screen.dart)

10. **Mostrar descripción del paquete en el catálogo**:
    - Agregar una fila debajo del nombre del paquete con `bundle.descripcion` en texto gris/secundario, truncado a 2 líneas.
    - Si la descripción está vacía, no mostrar nada adicional.

11. **Agregar funcionalidad de agregar a Lista cotizada desde el catálogo**:
    - **Problema actual**: Solo tiene botón `add_shopping_cart` que agrega al carrito (caja rápida).
    - **Solución**: Cambiar el `IconButton` singular por dos botones o un menú popup:
      - Botón principal de carrito (caja rápida) - color verde.
      - Botón secundario de lista (cotización manual) - color naranja.
    - Reutilizar la lógica de `mockWrapper` pero agregar a `provider.addToUtilityList()` en vez de `provider.addToCart()`.

---

#### [MODIFY] [quick_sale_provider.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/providers/quick_sale_provider.dart)

12. **Incluir la descripción del bundle en `MatchedProduct` al agregar un bundle**:
    - En `addBundleToCart` (línea 130-142), agregar la descripción del bundle en algún campo que se propague (podemos usar `specificName` para contener la descripción corta del paquete en vez de simplemente "Paquete").
    - Esto permitirá que la descripción llegue a los items de venta.

---

#### [MODIFY] [quick_checkout_modal.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/quick_sale/quick_checkout_modal.dart)

13. **Propagar `specific_name` (descripción) del bundle al detalle de venta**:
    - Verificar que `specific_name` del item del bundle se propague correctamente en el payload de `detalleVenta`.

---

#### [MODIFY] [sale_history_detail_screen.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/sale_history_detail_screen.dart) y widgets relacionados

14. **Mostrar descripción del bundle en el detalle de venta**:
    - Verificar el widget `SaleItemsList` para que cuando un item tenga `specific_name` (que contendrá "Incluye: X, Y, Z"), se muestre debajo del nombre.

---

#### [MODIFY] [pdf_generator.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/utils/pdf_generator.dart)

15. **Mostrar descripción del bundle en PDF**:
    - En la sección de bundles (línea ~303-317), después de la etiqueta "PAQUETE" y el nombre, agregar la descripción (`specificName`) como texto secundario en tamaño menor.

---

#### [MODIFY] Widgets de WhatsApp

16. **Incluir descripción del bundle en mensajes de WhatsApp**:
    - Buscar el widget/servicio que genera el texto de WhatsApp.
    - Para items tipo bundle, incluir la descripción debajo del nombre del producto.

---

### Fase 5: Integración de Ofertas en Matching Screen (Cotización IA)

---

#### [MODIFY] [matching_screen.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/matching_screen.dart)

17. **Mostrar descripción de bundles en la pantalla de matching IA**:
    - En la sección donde se renderizan los bundles agrupados (líneas 578-590), agregar la descripción del bundle debajo del nombre.

---

### Fase 6: Mejoras de UI en Modales de Cotización Manual

---

#### [MODIFY] [manual_quotation_screen.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/manual_quotation_screen.dart)

18. **Mostrar nombre + descripción en los items de bundle dentro de la cotización manual**:
    - Cuando un item tiene `bundleId != null`, mostrar debajo del nombre la descripción (que está en `specificName`).
    - Agregar un badge "PAQUETE" con icono para diferenciarlo visualmente.

---

## Verificación y Pruebas

### Pruebas del Bug Crítico (Fase 1)
1. Crear un paquete/bundle con 2+ productos.
2. Agregar ese paquete a una cotización manual y guardarla.
3. Verificar en la BD que `smart_quotation_items` tiene el campo `bundle_id` correcto (no NULL).
4. Editar la cotización → verificar que la validación de integridad muestre alertas si un componente del bundle no tiene stock.
5. Ir a vender la cotización → verificar que el stock de cada componente del paquete se descuente correctamente.
6. Comparar con el flujo de caja rápida (que ya funciona correctamente) para asegurar paridad de comportamiento.

### Pruebas de UI/UX (Fases 2-6)
- Verificar que las sugerencias se muestran colapsadas al entrar a la pestaña de ofertas.
- Verificar que los productos con oferta activa se distinguen visualmente.
- Verificar que el campo de precio de venta es prominente y responsive.
- Verificar que la descripción de ofertas aparece en: catálogo, caja rápida, cotización manual, matching IA, detalle de venta, PDF y WhatsApp.
- Verificar que desde el catálogo se pueden agregar ofertas tanto al carrito como a la lista.

---

## Orden de Ejecución Propuesto

| Prioridad | Fase | Descripción | Archivos Principales |
|-----------|------|-------------|---------------------|
| 🔴 P0 | 1 | Bug crítico de stock en bundles | `quotation_service.dart`, `sales_service.dart` |
| 🟡 P1 | 2 | Mejoras en sugerencias | `offers_tab.dart` |
| 🟡 P1 | 3 | Rediseño precio de venta | `bundle_builder_screen.dart` |
| 🟢 P2 | 4 | Descripción en todas las ventanas | Múltiples archivos |
| 🟢 P2 | 5 | Integración matching IA | `matching_screen.dart` |
| 🟢 P2 | 6 | UI cotización manual | `manual_quotation_screen.dart` |

---

## Open Questions

> [!IMPORTANT]
> 1. **Sobre las sugerencias mejoradas**: ¿Quieres que el sistema sugiera automáticamente combinar dos o más productos de baja rotación en un "Paquete Fusión"? Esto implicaría un análisis cruzado entre productos, analizando cuáles serían complementarios basándose en categorías similares o compras históricas. ¿O prefieres que las sugerencias se limiten a un solo producto con recomendación de tipo de promoción?

> [!IMPORTANT]
> 2. **Sobre la descripción en WhatsApp**: ¿La descripción del paquete debería aparecer como subtexto debajo de cada item tipo bundle en el mensaje, o prefieres un formato especial que resalte qué contiene el paquete (por ejemplo, con viñetas o emojis)?

> [!IMPORTANT]
> 3. **Sobre el diseño del precio**: ¿Prefieres que el nuevo diseño "hero" del precio de venta esté ARRIBA de la sección de Análisis de Rentabilidad (para darle protagonismo), o INTEGRADO dentro de ella formando una sola sección visual unificada de "Precio & Rentabilidad"?
