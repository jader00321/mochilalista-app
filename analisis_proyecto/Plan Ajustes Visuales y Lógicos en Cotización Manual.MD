# Plan: Ajustes Visuales y Lógicos en Cotización Manual

He analizado los problemas descritos con los márgenes de los paquetes especiales y la visualización incorrecta de precios al editar cotizaciones. Aquí tienes mi diagnóstico y la solución propuesta:

## Diagnóstico del Problema

1. **Choque visual del Panel de Paquetes Especiales:**
   - **Causa Técnica:** El contenedor de "Paquetes Especiales" (`_buildOffersPanel`) tiene actualmente un margen superior (`top: 24`), pero **carece de un margen inferior**. Al estar dentro de la cabecera de la lista de productos (`ReorderableListView`), su borde inferior colisiona exactamente con la primera tarjeta de producto listada, creando esa sensación de amontonamiento que mencionas.
   - **Solución:** Reconfigurar los márgenes del contenedor (`AnimatedContainer`). Le asignaré un margen superior ligeramente menor para subirlo visualmente (`top: 16`) y añadiré un margen inferior generoso (`bottom: 24`). Esto separará la sección de paquetes especiales de los productos, dándole respiro a la interfaz.

2. **Pérdida de la visualización del Descuento al Editar:**
   - **Causa Técnica:** Cuando la aplicación carga una cotización guardada desde la base de datos (en el método `_initData`), consulta el catálogo para refrescar los datos del producto. Sin embargo, la lógica actual **sobrescribe** el precio original directamente con el precio de oferta. Esto provoca que el modelo interno (`MatchedProduct`) asuma que el precio "normal" y el precio "final" son idénticos. Como consecuencia, la interfaz asume que no hay ningún descuento porque ambos precios son iguales (ej. Base: 3.46, Final: 3.46).
   - **Solución:** Refactorizaré la extracción de precios en `_initData`. Capturaré el precio de lista (`precioVentaFinal`) por un lado, y el precio de oferta (`precioOferta`) por otro. Se inyectarán ambos valores correctamente al modelo (`price` y `offerPrice`). Así, cuando la interfaz evalúe el producto, sabrá exactamente cuál era el precio original, lo mostrará tachado, y mostrará el precio final en color verde como corresponde.

## Fases de Ejecución

### Fase 1: Corrección Lógica de Precios (Data Layer)
- Archivo: `manual_quote_data_ext.dart`
- En el método `_initData()`, modificaré el bloque que consulta el catálogo (`invProv.fetchProductById`).
- Extraeré explícitamente el `pres.precioVentaFinal` como `currentPrice` y validaré si existe un `pres.precioOferta`.
- Pasaré ambos valores correctamente al instanciar `MatchedProduct`.

### Fase 2: Corrección Visual de Espaciados (UI Layer)
- Archivo: `manual_quote_offers_ext.dart`
- Modificaré la propiedad `margin` del `AnimatedContainer` principal en `_buildOffersPanel`.
- Aplicaré: `margin: const EdgeInsets.only(top: 16, bottom: 24)`.

## Open Questions
- Revisa el plan y avísame si los márgenes propuestos (16 arriba, 24 abajo) te parecen adecuados, o si prefieres que la separación entre los paquetes especiales y las tarjetas de productos sea aún mayor. ¡Confírmame para proceder!
