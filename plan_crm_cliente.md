# Diagnóstico y Plan: Mejora del Perfil de Cliente (CRM)

## 1. Propuesta para mejorar la lógica del Nivel de Confianza y CRM

### A. Diagnóstico de la Lógica Actual
Actualmente, el "Nivel de Confianza" es simplemente una cadena de texto manual seleccionable desde un Dropdown en el modal de edición (`"excelente", "bueno", "regular", "moroso"`). Esto permite **incongruencias graves**: un vendedor podría marcar a un cliente como "Excelente" a pesar de que el cliente tiene deudas vencidas de más de 30 días, o marcar como "Moroso" a alguien que solo compra de contado y no debe nada.

### B. Propuesta de Refactorización Lógica (Sistema Realista)
Propongo implementar un **Motor de Sugerencia/Validación** o automatizar el nivel en base al comportamiento real del cliente:
1. **Excelente (VIP):** El cliente tiene `totalDebt == 0` (o todas sus cuotas al día), y su `totalComprado` o cantidad de compras está en un percentil alto.
2. **Bueno (Confiable):** El cliente no tiene cuotas vencidas (`overdueCount == 0`), realiza compras regulares, pero su volumen de compra es estándar.
3. **Regular (Observado):** El cliente tiene 1 o 2 cuotas vencidas recientes (retraso menor a 15-30 días), lo que genera una alerta de riesgo bajo/medio.
4. **Moroso (Crítico):** El cliente tiene cuotas con más de 30 días de retraso (`maxDaysOverdue > 30`) o un alto volumen de deuda impaga. En este estado, el sistema debería sugerir (o forzar) que solo se le venda al contado.

*Solución UI sugerida para esta lógica:* En lugar de ser solo un campo que el usuario elige a ciegas, el sistema **evaluará al cliente al abrir el modal** y, si el usuario intenta elegir un nivel incongruente (ej. poner "Excelente" a alguien con deudas vencidas), el sistema mostrará una advertencia dinámica indicando la realidad financiera del cliente.

### C. Nuevos Datos Sugeridos para el Perfil (CRM Avanzado)
Para que el usuario conozca a profundidad a su cliente, sugiero calcular y añadir las siguientes métricas en el perfil (`ClientStatsHeader`):
*   **Ticket Promedio:** `(Total Comprado / N° de Compras)`. Indica cuánto gasta el cliente en promedio por visita.
*   **Tasa de Cumplimiento:** Porcentaje del monto pagado versus el total histórico comprado.
*   **Última Compra:** Los días transcurridos desde su última transacción, útil para estrategias de retención y seguimiento.

---

## 2. Diagnóstico del Desbordamiento (Overflow) en el Modal

### ¿Por qué ocurre?
En Flutter, el widget `DropdownButtonFormField` intenta empaquetar su contenido (`shrink-wrap`). Las opciones actuales como *"Regular (Observado, atrasos ocasionales)"* son cadenas de texto muy largas. En pantallas móviles pequeñas, el texto supera el ancho máximo del contenedor del Dropdown, y al no tener restricciones de expansión ni de recorte (`ellipsis`), provoca el error visual de `Overflow` en los píxeles derechos.

### ¿Cómo hacerlo 100% Responsivo?
Un menú desplegable (Dropdown) **no es la mejor práctica de UX/UI móvil** para opciones largas con descripciones.
**Solución propuesta:** Reemplazar el `DropdownButtonFormField` por una cuadrícula (`Wrap`) de tarjetas seleccionables (`ChoiceChips` o contenedores personalizados). 
- Esto permite que cada opción de confianza se adapte al ancho de la pantalla, usando múltiples líneas de texto de manera elegante sin desbordarse.
- Si por diseño se exige mantener el Dropdown, se aplicará `isExpanded: true` al Dropdown y un `TextOverflow.ellipsis` apoyado de `maxLines: 2` en el texto, obligando al widget a respetar los márgenes. (Recomiendo firmemente la primera opción por ser más premium).

---

## 3. Plan de Trabajo Detallado (Paso a Paso)

### Paso 1: Visibilidad Inmediata del Nivel de Confianza (UI Principal)
*   **Archivo:** `client_stats_header.dart`.
*   **Acción:** Agregar un "Badge" o "Píldora" visual debajo del nombre del cliente y su número de teléfono.
*   **Diseño:** Este componente cambiará de color dinámicamente: Verde brillante (Excelente), Azul (Bueno), Naranja (Regular), y Rojo (Moroso), permitiendo al usuario conocer el estatus a simple vista.

### Paso 2: Corrección del Overflow Visual en el Modal
*   **Archivo:** `client_profile_editor.dart`.
*   **Acción:** Eliminar el `DropdownButtonFormField` problemático.
*   **Implementación:** Crear un diseño responsivo basado en `Wrap` o `Column` con tarjetas (Cards) táctiles. Cada tarjeta mostrará el título del Nivel de Confianza y su descripción en texto más pequeño, adaptándose al 100% de cualquier tamaño de pantalla.

### Paso 3: Implementación de la Lógica y Refactorización del CRM
*   **Archivos:** `client_profile_editor.dart` y `client_stats_header.dart`.
*   **Acción:**
    1.  Escribir un método de validación que cruce `client.totalDebt`, las cuotas vencidas (del `TrackingProvider`) y el volumen de compras.
    2.  Si el usuario intenta asignar un nivel incongruente en el modal, mostrar un `Warning` debajo de la selección.
    3.  Añadir el cálculo matemático del **Ticket Promedio** y la fecha de **Última Compra** dentro de las estadísticas circulares o en carrusel del encabezado principal.

### Paso 4: Revisión General y Pruebas (Análisis de Código)
*   **Acción:** Ejecutar `flutter analyze` para verificar que la refactorización y adición de métricas no introduzca errores de tipado o conflictos en los demás archivos que consumen los modelos del cliente.
