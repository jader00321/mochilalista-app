# Plan: Mejora de Navegación en Directorio de Clientes

He analizado la pantalla de "Directorio de Clientes" (`client_tracking_screen.dart`) y he diseñado una solución elegante y profesional para ambos problemas que describes.

## Diagnóstico del Problema

1. **La Sección de Filtros no "Flota" al subir:**
   - **Causa Técnica:** Actualmente, el panel de filtros y ordenamiento está configurado como un `SliverPersistentHeader` donde la altura mínima (`minExtent`) es `0.0`. Esto hace que Flutter *aplaste* o "comprima" el contenedor en lugar de deslizarlo. Al tener este comportamiento de compresión manual, cuando intentas hacer *scroll* hacia arriba un poco, el sistema se confunde al recalcular el tamaño y no lo desliza de vuelta como debería.
   - **Solución:** Cambiaremos el comportamiento para que tenga un tamaño fijo (`minExtent == maxExtent`), pero manteniendo `floating: true` y `pinned: false`. De esta manera, Flutter dejará de intentar "aplastarlo" y en su lugar **deslizará la barra entera hacia arriba y hacia abajo suavemente** ni bien detecte el movimiento de tu dedo, logrando el efecto de reaparición rápida que buscas.

2. **El Teclado no se oculta (Buscador "Atascado"):**
   - **Causa Técnica:** La pantalla carece de un detector de toques en el fondo. Además, los listados por defecto no saben cuándo quieres interactuar con el fondo o cuándo quieres hacer *scroll*.
   - **Solución:** Implementaremos la misma lógica exitosa que usamos en la "Caja Rápida". Envolveremos el cuerpo principal de la lista de clientes (`CustomScrollView`) en un detector de gestos (`GestureDetector`).
     - Al detectar un **Tap** (presionar cualquier área vacía o tarjeta), el buscador se desactivará (`FocusScope.of(context).unfocus()`) y el teclado se ocultará.
     - Al detectar un **Drag/Scroll** (deslizar el dedo), el gesto de toque será ignorado, permitiéndote bajar por la lista de clientes **sin que el teclado se cierre**, tal cual lo solicitaste.

## Fases de Ejecución

### Fase 1: Efecto Flotante del Panel de Filtros
- Archivo: `client_tracking_screen.dart`
- Se refactorizará el widget `_ClientFloatingFilterDelegate`.
- Se igualará `minExtent` y `maxExtent` a 125.0 (su altura real).
- Se eliminará la lógica manual de compresión (`OverflowBox` y `ClipRect`) permitiendo que Flutter se encargue del efecto de cortina (deslizamiento natural).

### Fase 2: Unfocus Inteligente del Teclado
- Archivo: `client_tracking_screen.dart`
- Se envolverá el `CustomScrollView` dentro de un `GestureDetector(onTap: () => FocusScope.of(context).unfocus(), behavior: HitTestBehavior.translucent)`.
- Se mantendrá el teclado activo intencionalmente al hacer *scroll* por la lista.

## Open Questions
- En la Fase 1, el panel reaparecerá tan pronto deslices hacia arriba (incluso si estás a mitad de la lista). ¿Estás de acuerdo con este comportamiento nativo de cortina flotante? 
- Revisa el plan y confírmame si puedo proceder con los cambios.
