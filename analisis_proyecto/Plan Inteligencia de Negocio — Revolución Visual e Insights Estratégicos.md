# Plan: Inteligencia de Negocio — Revolución Visual e Insights Estratégicos

## Contexto del Problema

El módulo de Analytics presenta tres problemas detectados en QA visual:
1. **Overflow en tarjeta principal**: El headline "Negocio saludable y con potencial 💪" se corta porque un `Row` interior contiene un `Expanded` anidado dentro de otro `Row` sin restricciones, provocando desborde cuando el texto + emoji exceden el ancho.
2. **Gráfico estático en Categorías**: La sección "Categorías Más Rentables" solo muestra un `LinearProgressIndicator` con unidades vendidas (volumen). No hay forma de ver la dimensión financiera (ingresos en S/) de cada categoría.
3. **Ausencia de cruce inteligente**: No existe lógica que compare el ranking por volumen vs. el ranking por ingresos para detectar anomalías estratégicas (ej: una categoría vende mucho pero genera poco dinero).

> [!NOTE]
> El gráfico de "Análisis Financiero Detallado" (modal) **ya usa `fl_chart` con `BarChart` interactivo y `BarTouchTooltip`**. No requiere reemplazo. La Fase 2 se centrará en mejorar lo existente y no en duplicar trabajo.

---

## Fase 1: Corrección Responsiva de la Tarjeta Principal

### Diagnóstico del Bug

En [`financial_summary_card.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/widgets/dashboard/financial_summary_card.dart#L300-L316), el `Row` del headline tiene esta estructura problemática:

```dart
Row(
  children: [
    Row(               // ← Row sin restricción dentro de Row
      children: [
        Icon(...),
        Expanded(...)  // ← Expanded dentro de Row no restringido = OVERFLOW
      ],
    ),
    Container(...)     // ← Botón "touch_app"
  ],
)
```

El `Row` hijo no tiene `Expanded` como padre, por lo que el `Expanded` interior no funciona correctamente y el texto se desborda.

#### [MODIFY] [`financial_summary_card.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/widgets/dashboard/financial_summary_card.dart)

- **Líneas 300-323**: Reestructurar el `Row` del headline:
  - Eliminar el `Row` hijo innecesario.
  - Usar `Expanded` directamente en el `Row` padre para que el ícono + texto compartan el espacio con el botón `touch_app`.
  - Envolver el `Text` del headline con `Flexible` + `overflow: TextOverflow.ellipsis` para que escale sin romper el layout.

**Estructura corregida:**
```dart
Row(
  children: [
    const Icon(Icons.account_balance_wallet, color: Colors.white70, size: 20),
    const SizedBox(width: 8),
    Expanded(
      child: Text(
        headline,
        style: ...,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
    const SizedBox(width: 8),
    Container(...touch_app icon...),
  ],
)
```

---

## Fase 2: Mejora del Gráfico Financiero Existente

> [!IMPORTANT]
> El modal de "Análisis Financiero Detallado" **ya implementa `fl_chart` con `BarChart`** y `BarTouchTooltip`. No es necesario crear un gráfico nuevo desde cero. Lo que haremos es pulir la experiencia existente.

#### [MODIFY] [`financial_summary_card.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/widgets/dashboard/financial_summary_card.dart)

- **Líneas 92-139** (Sección del `BarChart` en el modal):
  - Añadir `swapAnimationDuration: const Duration(milliseconds: 600)` al `BarChart` para que las barras se animen suavemente al abrir el modal.
  - Añadir un `gradient` vertical a cada `BarChartRodData` (en lugar de un color sólido) para un efecto visual más premium:
    - Ingresos: gradiente de `Colors.blue[400]` a `Colors.blue[700]`.
    - Costos: gradiente de `Colors.red[300]` a `Colors.red[600]`.
    - Ganancia: gradiente de `Colors.green[300]` a `Colors.green[600]`.
  - Agregar `borderRadius: BorderRadius.vertical(top: Radius.circular(8))` para darle forma redondeada superior a las barras.
  - En el `BarTouchTooltipData`, añadir color de fondo translúcido oscuro: `tooltipBgColor` o equivalente para que el tooltip no se confunda con el fondo.

---

## Fase 3: Ecosistema Dual de Categorías (Volumen vs. Ingresos)

Esta es la fase más importante. Transformaremos la tarjeta de categorías de ser unidimensional (solo volumen) a ser un panel de doble perspectiva.

### 3.1. Modificación de la Query SQL

#### [MODIFY] [`analytics_provider.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/providers/analytics_provider.dart#L302-L314)

- **Líneas 302-314**: Modificar la query `topCategoriesQuery` para que también extraiga ingresos:

```sql
SELECT c.nombre, 
       SUM(vi.cantidad) as total_vendido,
       SUM(vi.cantidad * vi.precio_unitario) as total_ingresos
FROM venta_items vi
JOIN ventas v ON vi.venta_id = v.id
JOIN presentaciones_producto pp ON vi.presentation_id = pp.id
JOIN productos p ON pp.producto_id = p.id
JOIN categorias c ON p.categoria_id = c.id
WHERE v.negocio_id = ? AND v.is_archived = 0
GROUP BY c.id
ORDER BY total_vendido DESC
LIMIT 5
```

Ahora cada entrada en `topCategories` contendrá tanto `total_vendido` (unidades) como `total_ingresos` (S/).

### 3.2. Rediseño del Widget de Categorías

#### [MODIFY] [`top_categories_card.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/widgets/dashboard/top_categories_card.dart)

- Añadir una variable de estado: `bool _showByRevenue = false;`.
- **Encabezado**: Reemplazar el título estático "Categorías Más Rentables" por un `Row` con:
  - Título dinámico: `"Categorías por ${_showByRevenue ? 'Ingresos (S/)' : 'Unidades'}"`.
  - Un toggle (`AnimatedContainer` + `GestureDetector`) con dos opciones:
    - 🏷️ "Unidades" (default).
    - 💰 "Ingresos".
  - Al alternar, se intercambian los datos mostrados y las barras se reaniman.
- **Barras de progreso**: La lógica de `pct` (proporción) ahora tomará:
  - Si `_showByRevenue == false`: usa `total_vendido` (comportamiento actual).
  - Si `_showByRevenue == true`: usa `total_ingresos`.
- **Etiquetas**: Cada fila mostrará:
  - Modo Unidades: `"124 unid."` (como ahora).
  - Modo Ingresos: `"S/ 1,234.56"` (formateado con `NumberFormat.currency`).
- **Colores diferenciados**:
  - Barras en modo Unidades: Indigo (actual).
  - Barras en modo Ingresos: Amber/Gold.
- **Animación**: Envolver los cambios con `AnimatedSwitcher` para que la transición sea suave.

---

## Fase 4: Motor de Interpretación (Smart Insights Engine)

### 4.1. Nuevo Algoritmo en el Provider

#### [MODIFY] [`analytics_provider.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/providers/analytics_provider.dart)

- Crear una nueva propiedad en `AnalyticsData`: `String? categoryInsight`.
- Después de obtener `topCategoriesQuery`, añadir la siguiente lógica:

```dart
// Smart Insight: Volumen vs. Valor
String? categoryInsight;
if (topCategoriesQuery.length >= 2) {
  // Top 1 por volumen (ya ordenado por total_vendido DESC)
  String topByVolume = topCategoriesQuery.first['nombre'];
  
  // Top 1 por ingresos (reordenar temporalmente)
  var sortedByRevenue = List<Map<String, dynamic>>.from(topCategoriesQuery)
    ..sort((a, b) => ((b['total_ingresos'] as num?) ?? 0)
        .compareTo((a['total_ingresos'] as num?) ?? 0));
  String topByRevenue = sortedByRevenue.first['nombre'];
  
  if (topByVolume != topByRevenue) {
    categoryInsight = "💡 Tu categoría '$topByVolume' atrae más clientes "
        "(mayor volumen de unidades), pero '$topByRevenue' es la que más "
        "ingresos te genera. ¡Asegura siempre el stock de ambas!";
  } else {
    categoryInsight = "⭐ Tu categoría '$topByVolume' lidera tanto en "
        "volumen como en ingresos. Es tu pilar financiero. "
        "Expande su catálogo para maximizar resultados.";
  }
}
```

### 4.2. Renderizado del Insight en la UI

#### [MODIFY] [`top_categories_card.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/widgets/dashboard/top_categories_card.dart)

- Debajo del listado de categorías, agregar un `Container` condicional que muestre el `categoryInsight` si no es null:
  - Fondo: gradiente sutil azul/púrpura translúcido.
  - Ícono: `Icons.auto_awesome` (✨) en dorado.
  - Texto del insight con `height: 1.5` para legibilidad.
  - Borde redondeado con animación de entrada (`AnimatedOpacity` o `AnimatedContainer`).

---

## Resumen de Archivos Afectados

| Archivo | Tipo | Cambios |
|---------|------|---------|
| [`financial_summary_card.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/widgets/dashboard/financial_summary_card.dart) | MODIFY | Fix overflow Row + mejora gradientes BarChart |
| [`analytics_provider.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/providers/analytics_provider.dart) | MODIFY | Query con `total_ingresos` + lógica Smart Insight |
| [`top_categories_card.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/widgets/dashboard/top_categories_card.dart) | MODIFY | Toggle dual + UI insight + formatCurrency param |
| [`analytics_dashboard_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/screens/analytics_dashboard_screen.dart) | MODIFY | Pasar `formatCurrency` a `TopCategoriesCard` |

---

## Verificación

### Compilación
```bash
flutter analyze
```

### Visual
- Verificar que la tarjeta principal no desborde en pantallas de 360px de ancho.
- Verificar que el toggle de categorías alterne suavemente entre vistas.
- Verificar que el insight aparezca correctamente debajo del listado de categorías.
