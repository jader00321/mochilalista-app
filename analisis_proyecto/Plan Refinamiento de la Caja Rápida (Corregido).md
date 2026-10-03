# Plan: Refinamiento de la Caja Rápida (Corregido)

Gracias por las capturas y la corrección. Ahora entiendo exactamente el origen de los problemas visuales que reportas. 

## Diagnóstico Exacto
1. **El Ícono de Tres Líneas (Menú Hamburguesa):** El solapamiento a la derecha del buscador no es con el botón de borrar ("X"), sino con el botón automático de "Menú" (tres líneas) que abre el panel de notas. Esto ocurre porque el componente `SliverAppBar` que contiene al buscador inserta automáticamente este botón al detectar que hay un menú lateral oculto, provocando que se monte sobre el ícono del QR.
2. **La Marca Oculta:** Efectivamente, en el archivo `quick_sale_cart_item.dart` existe una validación que dice "si el nombre del producto ya contiene la marca, ocúltala". Además, actualmente se muestra dentro de una "cajita morada" pequeña.
3. **Jerarquía Visual Desigual:** Los tamaños de letra actuales (`fontSize`) varían entre 10, 13 y 16, lo que hace que se vea desordenado.
4. **Comportamiento del Teclado (Unfocus):** Faltaba el detector de toques en el fondo del listado.

## Propuesta de Solución Definitiva

### Fase 1: Limpieza del Buscador y Unfocus Inteligente
**Archivo:** `quick_sale_screen.dart`
- **Quitar Ícono de Tres Líneas:** Bloquearé explícitamente la aparición automática de este ícono en el `SliverAppBar` inyectando un bloque `actions: [SizedBox.shrink()]`. De este modo, el usuario aún podrá abrir las notas con el ícono principal superior, pero la barra de búsqueda quedará completamente limpia, mostrando solo tu ícono QR y (cuando escribas) la "X" para borrar.
- **Unfocus:** Envolveré el `CustomScrollView` (la zona de los productos) con un `GestureDetector` que atrape toques simples (`onTap`) y cierre el teclado, respetando que al deslizar el dedo (*scroll*) no suceda nada extraño.

### Fase 2: Rediseño Jerárquico de la Tarjeta del Producto
**Archivos:** `quick_sale_cart_item.dart` y `quick_search_result_tile.dart` (para que sean consistentes).
- **Mostrar Siempre la Marca:** Eliminaré la condición restrictiva para forzar a que la marca SIEMPRE aparezca, pase lo que pase.
- **Nuevo Estilo Tipográfico (Professional Look):**
  - **Marca:** Remuevo la "cajita" de fondo. Será puro texto en la parte superior, de tamaño 14 (`fontSize: 14`), en color azulado (`Colors.blue[700]` en tema claro, `Colors.blue[300]` en oscuro) y con grosor `FontWeight.w900` para que destaque sin estorbar.
  - **Nombre del Producto:** Tamaño 14, color principal (blanco/negro) y grosor fuerte (`FontWeight.bold`).
  - **Variante:** Tamaño 14, color grisáceo o secundario para acompañar, con grosor regular.
  Al tener los 3 textos a tamaño 14, la alineación será perfectamente cuadriculada y profesional.

## Revisión
He entendido exactamente el problema gracias a tus indicaciones sobre el botón de tres líneas y la marca. Si este plan corregido se alinea perfectamente con lo que buscas, por favor apruébalo para iniciar de inmediato con los cambios en el código.
