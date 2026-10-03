# Plan de Trabajo: Corrección y Refinamiento de la Ventana de Detalles del Producto (v1)

## Comprensión del Requerimiento

He analizado profundamente la ventana `ProductDetailScreen`, las dos capturas proporcionadas y todo el código fuente involucrado. Identifiqué los siguientes problemas y oportunidades de mejora:

---

## 🔴 Problema Crítico 1: Botón del Reloj Navega a Ventana Rota

### Diagnóstico
El botón del reloj (ícono `Icons.history`) en la línea 211 de [product_detail_screen.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/catalog/screens/product_detail_screen.dart#L208-L218) navega a `ProductAuditScreen` con:

```dart
presentationId: _selectedPresentation.id ?? 0
```

El campo `id` en `ProductPresentation` es `int?` (nullable). Cuando `id` es `null`, se envía `0` como `presentationId`, y la consulta SQL en `getAuditTrail()` busca `presentation_id = 0` — que **no existe en la base de datos**. Resultado: pantalla completamente vacía (la captura gris que me mostraste).

Además, existe una **ventana duplicada** más completa y con mejor diseño: [audit_trail_screen.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/analytics/screens/audit_trail_screen.dart) (`AuditTrailScreen`), que incluye:
- Una tarjeta resumen con stock actual (consulta la DB en tiempo real).
- Un diseño de timeline más profesional con `IntrinsicHeight`.
- Un botón de ayuda contextual.

### Solución Propuesta
1. **Reemplazar la navegación** para que el botón del reloj use `AuditTrailScreen` en lugar de `ProductAuditScreen`, ya que es la versión más completa.
2. **Agregar un guard:** Si `_selectedPresentation.id` es `null`, mostrar un `SnackBar` explicativo en lugar de navegar a una pantalla rota.
3. **Eliminar `ProductAuditScreen`** si no se usa en ningún otro lugar (verificaré esto).

### Archivos a Modificar
- [product_detail_screen.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/catalog/screens/product_detail_screen.dart) — Cambiar import y navegación del botón del reloj
- [product_audit_screen.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/catalog/screens/product_audit_screen.dart) — Evaluar eliminación

---

## 🟡 Problema 2: Datos No Se Actualizan al Regresar de Editar

### Diagnóstico
La navegación al editor ([línea 68-79](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/catalog/screens/product_detail_screen.dart#L68-L79)) ya llama a `_refreshData()` al regresar. Sin embargo, `_refreshData()` ejecuta `loadInventory(reset: true)` que recarga **todo** el inventario — operación costosa e innecesaria.

El flujo actual de `_refreshData` es:
1. `loadInventory(reset: true)` — Recarga TODO el inventario (lento).
2. `getFullProductWithFallback` — Busca el producto actualizado (correcto).
3. `setState` — Actualiza la UI (correcto).

### Solución Propuesta
- **Optimizar** `_refreshData()` para que NO recargue todo el inventario, sino solo el producto individual con `getFullProductWithFallback`.
- Mantener el `loadInventory(reset: true)` solo como fallback si el producto individual no se encuentra.

### Archivos a Modificar
- [product_detail_screen.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/catalog/screens/product_detail_screen.dart) — Optimizar `_refreshData()`

---

## 🟢 Fase 3: Refinamiento Visual y UX de Toda la Ventana

### Hallazgos del Análisis Visual

| Elemento | Estado Actual | Mejora Propuesta |
|---|---|---|
| **SliverAppBar (Imagen)** | Sin animación de carga, gradiente genérico | Agregar `Hero` animation y placeholder con shimmer si no hay imagen |
| **Nombre + Badge Público** | El badge "Público/Privado" es grande y compite visualmente con el nombre | Hacerlo más compacto como un chip pequeño |
| **Selector de Variantes** | Funcional pero sin animación de selección | Agregar `AnimatedScale` al chip seleccionado y mejorar el feedback visual |
| **Dashboard Financiero** | Bien estructurado pero estático | Agregar micro-animaciones de entrada (`FadeIn`) a los valores numéricos cuando cambian de variante |
| **Grid de Info (Código, Categoría, etc.)** | Las tarjetas son idénticas visualmente (mismo color teal para todos) | Diferenciar por tipo: código (azul), categoría (púrpura), proveedor (naranja) |
| **Descripción** | Contenedor simple sin interactividad | Si es muy larga, hacerla expandible/colapsable |
| **_InfoCard (widget privado)** | Todos los iconos usan `teal` | Personalizar colores por tipo de información |

### Archivos a Modificar
- [product_detail_screen.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/catalog/screens/product_detail_screen.dart) — Todas las secciones visuales

---

## 📋 Resumen de Fases de Ejecución

| Fase | Descripción | Archivos |
|---|---|---|
| **1** | Corregir botón del reloj (navegar a `AuditTrailScreen`, guard null) | `product_detail_screen.dart` |
| **2** | Optimizar `_refreshData()` para no recargar todo el inventario | `product_detail_screen.dart` |
| **3** | Refinamiento visual: SliverAppBar, variantes, dashboard financiero, grid de info, descripción | `product_detail_screen.dart` |

---

## ✅ Plan de Verificación

### Verificación Manual
1. Abrir detalles de un producto → Presionar el botón del reloj → Verificar que navega a la pantalla de auditoría con datos reales.
2. Editar un producto (cambiar precio/nombre) → Regresar a detalles → Verificar que los cambios se reflejan inmediatamente.
3. Cambiar de variante → Verificar que los datos financieros se actualizan con animación suave.
4. Probar en modo claro y oscuro para verificar contraste y legibilidad.
