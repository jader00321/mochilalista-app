# 📋 Plan de Trabajo: Mejoras de Catálogo, Ordenamiento y Pagos

He analizado a profundidad tus tres requerimientos. Aquí tienes el diagnóstico y el plan detallado para llevar estos componentes al siguiente nivel, corrigiendo los errores visuales y mejorando la experiencia de usuario (UX).

---

## 🎯 FASE 1: Sistema de Ordenamiento Inteligente (Catálogo e Inventario)

**El Problema Actual:** El sistema ordena alfabéticamente de forma estricta. Eso significa que un producto llamado `(Caja) Leche` se agrupa bajo el símbolo `(`, y si tiene mayúsculas/minúsculas diferentes, puede romperse el orden esperado.
**La Solución Premium:** Implementaremos un **algoritmo de "Ordenamiento Natural"**.
1. Al momento de ordenar, el sistema internamente creará una versión "limpia" del nombre del producto, ignorando mayúsculas.
2. **Recomendación Profesional:** Eliminaremos los símbolos iniciales (como `(`, `[`, `-`, `*`) y los números iniciales sueltos para efectos exclusivos de ordenamiento. Es decir, `(Pack) Gaseosa` o `12x Gaseosa` se ordenarán en la letra **G**, no en los símbolos ni números.
3. Se aplicará este algoritmo en: Productos, Categorías, Marcas y Proveedores (`inventory_provider.dart`).

---

## 🖼️ FASE 2: Adaptabilidad del Modal de Detalles del Catálogo

**El Problema Actual:** El modal usa un componente llamado `DraggableScrollableSheet` configurado al 75% de la pantalla. Esto hace que en pantallas grandes quede demasiado espacio vacío abajo, y en pantallas pequeñas los textos puedan desbordarse.
**La Solución Elegante:**
1. Cambiaremos el contenedor rígido por un **Contenedor Adaptativo (`mainAxisSize.min`)**.
2. El modal ahora solo ocupará exactamente el espacio que necesite el producto. Si el producto no tiene descripción, el modal será pequeño; si tiene mucha descripción, el modal crecerá hasta un máximo seguro (90% de la pantalla).
3. Haremos que la imagen del producto tenga una altura máxima controlada (`maxHeight: 250`), para que en celulares pequeños la imagen no empuje los botones de "Agregar" fuera de la pantalla.
4. Todo estará envuelto en un `SafeArea` para respetar los bordes curvos y la cámara frontal (notch) de cualquier dispositivo.

---

## 💳 FASE 3: Rediseño del Modal de Pago Rápido

**El Problema Actual:** Las etiquetas de pago (Efectivo, Yape, Plin) usan el componente `ChoiceChip`. Cuando seleccionas uno, este componente muestra un ícono de un "check" (✓), lo cual empuja el texto, cambia el tamaño del botón y rompe por completo la cuadrícula (el efecto "salto" que se ve muy feo).
**La Solución Visual (Siguiente Nivel):**
1. Reemplazaré esos *Chips* inestables por un **Grid Estático (Cuadrícula 2x2)**, poniendo exactamente 2 opciones por fila de manera uniforme y simétrica.
2. Las opciones (Efectivo, Yape, Plin, Tarjeta, Saldo) tendrán un diseño premium:
   - Tarjetas planas redondeadas.
   - En lugar de saltar, cuando las toques tendrán una **Micro-animación de color y escala** (un suave efecto de iluminación o sombreado al estilo de las apps de banca modernas).
   - El texto estará siempre centrado y estático. Nunca se moverá al seleccionarlo.

---

## ❓ Pregunta para ti (Opcional)

Para el ordenamiento (Fase 1), al ignorar los números al principio: un producto llamado `7Up` se ordenará en la letra **U** (ignorando el 7). ¿Estás de acuerdo con ignorar los números iniciales para el ordenamiento, o prefieres que los números sí se tomen en cuenta (y se agrupen antes de la A)? *Recomiendo agrupar los números antes de la A, pero ignorando siempre los símbolos.*

---

**Si estás de acuerdo con este plan de ejecución, haz clic en "Proceed" (Proceder) o indícame si deseas ajustar alguna de mis recomendaciones.**
