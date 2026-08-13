# Plan de Integración del Ecosistema de Promociones

Tras un análisis profundo de la arquitectura actual (`matching_provider`, `quick_sale_screen`, `print_service`, y `local_db`), presento el plan estructurado para integrar el nuevo sistema de promociones en toda la app sin alterar ni corromper los flujos actuales.

## User Review Required

> [!IMPORTANT]
> **Agrupación de Cotizaciones IA (Proporcionalidad de Precios)**  
> Dado que la base de datos de cotizaciones empareja "1 Ítem Escaneado -> 1 Producto Físico", la forma más segura de implementar la agrupación en Paquetes es **distribuir el descuento proporcionalmente** entre los productos que conforman el paquete, y asignarles su `bundle_id`. 
> *Ejemplo:* Si el Lápiz y el Borrador valen S/ 10 cada uno (S/ 20 total), pero forman el "Pack Escolar" a S/ 15, asignaremos internamente un precio de venta de S/ 7.50 a cada uno, pero visualmente el cliente verá "Pack Escolar: S/ 15".  
> **¿Estás de acuerdo con este enfoque de distribución matemática para mantener íntegra la base de datos?**

## Open Questions

1. **Diseño del Ticket:** Para mostrar el ahorro en el comprobante impreso, añadiré una línea al final (antes del total) que diga: `Ahorro por Promociones: S/ XX.XX`. ¿Te gustaría que se incluyera también un mensaje de agradecimiento personalizado en el ticket como "¡Gracias por ahorrar con nosotros!"?
2. **Dashboard Analytics:** Crearé un nuevo KPI para medir la "Liquidez Recuperada" (sumatoria del dinero que ingresó producto de ventas con promociones tipo `liquidez_costo`). ¿Dónde prefieres ver este KPI: en la pestaña principal de inicio del administrador o en la ventana específica de Estadísticas?

---

## Proposed Changes

### 1. Validación de Fechas en Caja y Catálogo
Evitar que se vendan promociones expiradas o futuras.

#### [MODIFY] [quick_sale_screen.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/quick_sale_screen.dart)
- Agregar validación lógica en el renderizado de `🔥 Paquetes Disponibles`:
  ```dart
  if (bundle.fechaFin != null && bundle.fechaFin!.isBefore(DateTime.now())) return SizedBox();
  ```
- Añadir insignias visuales (badges) dinámicas según el `tipo_promocion` (Ej. Etiqueta ⚡Flash, 💧Liquidez, 📦Fusión).

### 2. Agrupación Inteligente en Cotizaciones IA (Smart Quotation)
Automatizar la detección de paquetes cuando se escanea una lista, permitiendo agrupar/desagrupar a voluntad.

#### [MODIFY] [matching_provider.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/providers/matching_provider.dart)
- Crear una función `_detectAndApplyBundles()` que corra al finalizar el escaneo. Buscará si dentro de los `MatchPair` hay productos que completan un `BundleModel` activo.
- Si hay coincidencia, agrupará visualmente los `MatchPair`, les asignará el `bundle_id` correspondiente y modificará su `overridePrice` (aplicando el descuento del paquete).
- Crear función `toggleBundleGrouping(int bundleId, bool group)`: Permitirá al usuario **desagrupar** (retornar a los precios individuales originales) o volver a **agrupar** si se arrepiente, otorgando total flexibilidad para cada cliente.

#### [MODIFY] [matching_screen.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/matching_screen.dart)
- Modificar el `ListView` de resultados para que, si varios productos pertenecen a un mismo paquete, se dibujen dentro de una tarjeta destacada (Ej. Borde dorado) indicando: `"✨ Agrupados en [Nombre Paquete] - Ahorro: S/ X.XX"`.
- Añadir un botón `Desarmar Paquete` y `Armar Paquete` en cada grupo.

### 3. Impacto Visual en Comprobantes (Print Service)
Fidelizar al cliente demostrando su ahorro.

#### [MODIFY] [print_service.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/core/services/print_service.dart)
- Recorrer los `venta_items`. Si existen ítems donde `original_unit_price > precio_unitario`, sumar la diferencia.
- Imprimir una línea destacada en el ticket bluetooth antes del Gran Total: `AHORRO TOTAL: S/ XX.XX`.

### 4. Indicadores Clave en Dashboard (KPIs)
Medir el impacto de la herramienta "Liquidez a Costo".

#### [MODIFY] [dashboard_provider.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/providers/dashboard_provider.dart)
- Agregar un cálculo para extraer `liquidezRecuperada` buscando ventas que contengan `bundle_id` cuyo `tipo_promocion == 'liquidez_costo'`.
- Mostrar este KPI en el Dashboard para que el dueño sepa exactamente cuánto "Stock Muerto" logró convertir en efectivo durante el mes.

---

## Verification Plan

### Manual Verification
1. **Validación de Fechas:** Crearé un paquete con fecha de fin "Ayer". Revisaré que no aparezca en Caja Rápida.
2. **Escaneo IA:** Escanearé una lista (o haré un test en el ambiente de pruebas de IA) que contenga 2 productos pertenecientes a un "Paquete". 
   - Validaré que el sistema los encierre en un cuadro verde.
   - Validaré que el precio total baje automáticamente.
   - Presionaré "Desarmar Paquete" y validaré que regresen a su precio individual.
3. **Ticket de Venta:** Generaré una venta con promoción y simularé la impresión en pantalla/consola, comprobando que diga "Ahorro total".
