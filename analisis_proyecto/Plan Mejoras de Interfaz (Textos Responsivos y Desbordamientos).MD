# Plan: Mejoras de Interfaz (Textos Responsivos y Desbordamientos)

He analizado detalladamente los problemas reportados en las vistas de cotización, tanto el desbordamiento de la etiqueta de ahorro como la legibilidad de los títulos de las cotizaciones en los cabezales.

## Diagnóstico de los Problemas

1. **Desbordamiento de la Etiqueta "Ahorro":**
   - **Causa Técnica:** El cabezal estático de la pantalla de detalles (`SliverPersistentHeader`) tiene un cálculo de altura máxima rígido (`maxExtent`). Cuando la cotización incluye productos en oferta, se renderiza la insignia verde de ahorro. Sin embargo, el delegado no suma el espacio que ocupa esta insignia a su altura total permitida. Al superar el límite vertical del contenedor oscuro, Flutter dibuja la insignia por fuera, quedando visualmente desprendida o sobreponiéndose a elementos inferiores (como el chevron de "Evidencia de Origen").
   - **Solución:** Modificaremos la lógica del `_QuoteHeaderDelegate` en `quotation_detail_screen.dart` para que el cálculo de altura máxima (`maxExtent`) evalúe independientemente el contenido de la columna izquierda (institución/grado) y la columna derecha (precio/ahorro). El contenedor se ajustará al valor máximo de ambas columnas de forma inteligente.

2. **Nombres de Cotización Cortados en el AppBar:**
   - **Causa Técnica:** Actualmente los textos de las barras superiores tienen `overflow: TextOverflow.ellipsis`, por lo que los textos largos se truncan abruptamente ("Cotización Manual #..."), ocultando el identificador único o el nombre del cliente, afectando la experiencia en pantallas pequeñas.
   - **Solución:** Implementaremos un comportamiento **Marquee (Carrusel Automático)**. He diseñado un componente personalizado (`MarqueeText`) que evaluará si el texto supera el ancho de la pantalla. De ser así, se encogerá hasta un mínimo legible y, si aún así no cabe, comenzará a desplazarse automáticamente hacia la izquierda de forma cíclica (con suaves pausas en los extremos), garantizando que todo el nombre pueda ser leído sin importar qué tan largo sea.

## Fases de Ejecución

### Fase 1: Corrección de la Etiqueta "Ahorro" (Header de Detalles)
- **Archivos implicados:** `quotation_detail_screen.dart`
- Refactorizaremos el método `maxExtent` del delegado para que tome en consideración una reserva de altura de `~32px` adicionales si el `totalSavings` es mayor a 0, evitando así los desbordamientos.

### Fase 2: Desarrollo del Componente `MarqueeText`
- **Archivos implicados:** `lib/core/widgets/marquee_text.dart`
- He preparado ya la estructura base del componente `MarqueeText`. Proporciona animaciones de desplazamiento controladas y pausas lógicas que repiten el ciclo visual.

### Fase 3: Integración del Carrusel en Pantallas
- **Archivos implicados:** 
  1. `quotation_detail_screen.dart` (Para "Mi Pedido / Detalle")
  2. `manual_quotation_screen.dart` (Para "Nueva/Editar Cotización")
- Sustituiremos los componentes de texto estáticos en los títulos de los `AppBar` por el nuevo `MarqueeText`.

## Open Questions
- ¿Estás de acuerdo con el comportamiento de carrusel (el texto se moverá automáticamente de derecha a izquierda y luego regresará a su posición original si es demasiado largo)? Revisa este documento y dame tu confirmación para proceder con la inyección de este nuevo comportamiento visual y la corrección de la altura.
