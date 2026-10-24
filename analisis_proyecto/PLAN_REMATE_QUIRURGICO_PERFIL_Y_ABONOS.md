# Plan de Remate Quirúrgico: Perfil de Cliente y Abonos
**Documento Técnico de Verificación y Planificación de Ajuste Fino**
*Fecha: 21 de Octubre de 2026 | Rama: CRM Clientes Mobile Awards*

---

## 1. Resumen Ejecutivo y Objetivos

Tras la culminación exitosa de la **Parte 1** (Directorio, Perfil, Alerta Plegable de Vencidas y Pestañas) y la **Parte 2** (Modales Financieros, Prelación FIFO y Sincronización Contable), se procede a planificar quirúrgicamente los últimos **3 detalles de pulido fino** solicitados antes del cierre definitivo del módulo de Clientes:

1. **Contracción Inmediata del `Sticky Mini-Header` y Banner Azul en `"Pago Específico"` (`payment_entry_modal.dart`):**
   Garantizar que al desplegar cualquier acordeón de cuotas (`ExpansionTile`), o al ingresar con una sola deuda activa (`debts.length == 1`), la cabecera completa (>200px) y el banner azul de instrucciones se contraigan instantáneamente a un `Mini-Header` compacto (<48px) y un banner plegado, cediendo más del **85% del viewport vertical** a la visualización y selección de cuotas, incluso en listas cortas sin scroll vertical.
2. **Componente Visual de Comparativa Compras vs. Abonos en `"Ver Analítica"` (`client_full_stats_modal.dart`):**
   Diseñar un indicador visual bicromático de balance comercial que ilustre con barra de progreso el ratio de cumplimiento / amortización (`% pagado vs. % pendiente`), total comprado, total abonado y saldo pendiente comercial del periodo filtrado.
3. **Métricas Avanzadas: Ticket Promedio Jerarquizado y Frecuencia Media de Compra (`client_full_stats_modal.dart`):**
   Incorporar el cálculo y renderizado del **Ticket Promedio** enriquecido y de la **Frecuencia Media de Compra** (cadencia promedio en días entre pedidos consecutivos), indicador actualmente inexistente en el código.

> [!IMPORTANT]
> **Compromiso Estricto:** Este documento constituye un análisis y plan técnico preliminar. **No se modificará ninguna línea de código** hasta recibir la validación y aprobación formal del usuario.

---

## 2. Verificación Técnica en Código Fuente

### 2.1. Diagnóstico en `payment_entry_modal.dart`

* **Ubicación:** `app_movil/lib/features/smart_quotation/widgets/crm/payment_entry_modal.dart`

#### Hallazgos en Código:
1. **Comportamiento de Acordeones (`ExpansionTile`, L722–728):**
   ```dart
   child: ExpansionTile(
     initiallyExpanded: debts.length == 1,
     onExpansionChanged: (expanded) {
       if (expanded && !_isHeaderCollapsed) {
         setState(() => _isHeaderCollapsed = true);
       }
     },
     ...
   ```
   * **Problema con `initiallyExpanded`:** Cuando el cliente tiene 1 sola venta o préstamo pendiente (`debts.length == 1`), Flutter inicializa el acordeón abierto, pero **`onExpansionChanged` no se ejecuta en el montaje inicial**. Por tanto, `_isHeaderCollapsed` permanece en `false`, dejando la cabecera gigante abierta e impidiendo ver las cuotas inferiores.
   * **Interacción al Tocar:** Al tocar una tarjeta para desplegar cuotas, aunque `onExpansionChanged` llama a `setState(() => _isHeaderCollapsed = true)`, el banner azul de instrucciones superior permanece estático y visible.
2. **Banner Azul de Instrucciones Estático (L624–661):**
   ```dart
   Container(
     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
     color: isDark ? Colors.blue.withValues(alpha: 0.1) : Colors.blue[50],
     child: Row(
       children: [
         Icon(Icons.touch_app_outlined, ...),
         Expanded(child: Text("Selecciona la venta o cuota exacta que se amortizará.")),
         if (_selectedTargetId != null) TextButton(...)
       ],
     ),
   )
   ```
   * El banner azul consume entre **44px y 50px de altura vertical**. Se renderiza de forma fija e incondicional justo debajo de los tabs y encima del `ListView`, independientemente de si el mini-header ya se compactó.
   * Al sumarse la cabecera (incluso compactada) + TabBar + Banner azul + Márgenes + Botón inferior (`52px` + padding), el espacio libre para las cuotas en dispositivos móviles estándar se reduce drásticamente.

---

### 2.2. Diagnóstico en `client_full_stats_modal.dart`

* **Ubicación:** `app_movil/lib/features/smart_quotation/widgets/crm/client_full_stats_modal.dart`

#### Hallazgos en Código:
1. **Cálculos Actuales (L373–378):**
   ```dart
   final sales = _filteredSales;
   final double totalComprado = sales.fold(0.0, (sum, sale) => sum + sale.total);
   final double totalPagado = sales.fold(0.0, (sum, sale) => sum + sale.montoPagado);
   final int numCompras = sales.length;
   final double ticketPromedio = numCompras > 0 ? (totalComprado / numCompras) : 0;
   ```
2. **Presentación Visual Actual (L489–502):**
   * Se muestran 4 tarjetas en un `GridView` (2x2):
     * *Total Comprado* (`totalComprado`)
     * *Total Pagado* (`totalPagado`)
     * *Ticket Promedio* (`ticketPromedio`)
     * *N° de Compras* (`numCompras`)
   * Seguido directamente por `ClientComplianceSparkline` con el selector táctil y los chips inferiores `Mínimo / Promedio / Máximo`.
3. **Carencias Detectadas:**
   * **Falta de Comparativa Visual Compras vs. Abonos:** "Total Comprado" y "Total Pagado" se presentan como dos tarjetas independientes sin un vínculo visual directo que evidencie el porcentaje cubierto (ratio de recuperación o efectividad de cobro) ni el saldo amortizado restante en el periodo.
   * **Frecuencia Media de Compra Inexistente:** No existe en ninguna parte de la aplicación el cálculo de la periodicidad promedio con la que el cliente compra (p. ej. "Cada 8 días", "Quincenal", etc.). La única referencia existente es "Última Compra" (hace cuántos días fue el último pedido), lo cual es estático y no refleja el hábito o cadencia recurrente.

---

## 3. Plan de Solución Quirúrgica Detallada

### 3.1. Detalle 1 & 2: Contracción Inmediata del Mini-Header y Banner Colapsable en `"Pago Específico"`

#### A. Detección Inteligente al Cambiar de Pestaña o Cargar Deudas:
* En `_tabController.addListener`:
  ```dart
  if (_tabController.index == 1) {
    // Si hay una sola deuda (se expandirá automáticamente) o ya hay cuota preseleccionada
    if (provider.currentClientDebts.length == 1 || _selectedTargetId != null) {
      _isHeaderCollapsed = true;
    }
  }
  ```
* En el callback de carga de deudas (`loadClientDebts`): si la pestaña activa es `Pago Específico` y `debts.length == 1`, actualizar `_isHeaderCollapsed = true`.

#### B. Respuesta Instantánea al Tocar el Acordeón:
* En `ExpansionTile`:
  ```dart
  onExpansionChanged: (expanded) {
    if (expanded && !_isHeaderCollapsed) {
      setState(() => _isHeaderCollapsed = true);
    }
  }
  ```
  Al tocar la cabecera de la venta, la transición se activa sin requerir desplazamiento de scroll.

#### C. Colapso Suave del Banner Azul de Instrucciones:
* Convertir el banner azul en un widget reactivo que se oculte o comprima suavemente mediante `AnimatedSize` o `AnimatedCrossFade` cuando `_isHeaderCollapsed == true`.
* Cuando `_isHeaderCollapsed == true`:
  * El banner azul desaparece de la vista superior para otorgar **100% de prioridad a las cuotas**.
  * Si hay una cuota o venta seleccionada, el botón `"Limpiar Selección"` se integra limpiamente dentro del `_buildCollapsedStickyMiniHeader` como una acción secundaria junto al botón `"Modificar"`, evitando duplicar controles o consumir filas adicionales.

---

### 3.2. Detalle 3: Completitud Analítica en `"Ver Analítica"` (`client_full_stats_modal.dart`)

#### A. Tarjeta Comparativa Compras vs. Abonos (Balance Comercial):
* **Fórmula de Cumplimiento:**
  ```dart
  final double tasaCobro = totalComprado > 0 
      ? ((totalPagado / totalComprado) * 100).clamp(0.0, 100.0) 
      : 100.0;
  final double saldoPendienteFiltro = (totalComprado - totalPagado).clamp(0.0, double.infinity);
  ```
* **Diseño UI:**
  * Tarjeta contenedora con gradiente sutil y borde refinado.
  * Encabezado: "Balance Comercial del Periodo" con chip de porcentaje: `tasaCobro.toStringAsFixed(1)% Cubierto`.
  * Barra de progreso bicromática horizontal (`ClipRRect` con `LinearProgressIndicator` estilizado en verde y fondo ámbar/azul suave).
  * Fila inferior con 3 columnas simétricas:
    * **Comprado:** `AppCurrency.format(totalComprado)`
    * **Abonado:** `AppCurrency.format(totalPagado)`
    * **Pendiente:** `AppCurrency.format(saldoPendienteFiltro)`

#### B. Cálculo y Presentación de "Frecuencia Media de Compra":
* **Algoritmo Matemático:**
  ```dart
  String calcularFrecuenciaMedia(List<SaleSummary> sales) {
    final salesOnly = sales.where((s) => s.origenVenta != 'prestamo_personal').toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    
    if (salesOnly.length < 2) {
      return salesOnly.isEmpty ? "Sin compras" : "Compra única";
    }

    final firstDate = DateTime.tryParse(salesOnly.first.date);
    final lastDate = DateTime.tryParse(salesOnly.last.date);
    if (firstDate == null || lastDate == null) return "N/A";

    final totalDays = lastDate.difference(firstDate).inDays;
    if (totalDays <= 0) return "Mismo día";

    final double avgDays = totalDays / (salesOnly.length - 1);
    
    if (avgDays < 1.5) return "Diaria (~1 día)";
    if (avgDays >= 6.0 && avgDays <= 8.5) return "Semanal (~7 días)";
    if (avgDays >= 13.0 && avgDays <= 17.0) return "Quincenal (~15 días)";
    if (avgDays >= 28.0 && avgDays <= 33.0) return "Mensual (~30 días)";

    return "Cada ${avgDays.round()} días";
  }
  ```

#### C. Grid de Rendimiento Comercial Renovado (4 KPIs Clave):
1. **Ticket Promedio:** `AppCurrency.format(ticketPromedio)` con icono `Icons.receipt_long`.
2. **Frecuencia Media:** Texto legible ("Cada X días" / "Semanal") con icono `Icons.update_rounded`.
3. **N° de Compras:** `$numCompras compras` con icono `Icons.shopping_bag_outlined`.
4. **Última Compra:** `"Hoy"`, `"Ayer"`, `"Hace X días"` con icono `Icons.event_available`.

*(La comparación macro Compras vs. Abonos pasa a la tarjeta visual superior, liberando el Grid para métricas analíticas de comportamiento puro).*

---

## 4. Matriz de Criterios de Aceptación (Árbitro Adversarial)

| Ítem | Componente | Comportamiento Esperado | Verificación |
| :--- | :--- | :--- | :--- |
| **1.1** | `payment_entry_modal.dart` | Al ingresar a "Pago Específico" con 1 sola venta, la cabecera inicia automáticamente en modo compacto. | Widget Test: `find.text('Modificar')` visible sin requerir scroll. |
| **1.2** | `payment_entry_modal.dart` | Al tocar cualquier `ExpansionTile` para expandir cuotas, `_isHeaderCollapsed` pasa a `true` al instante (0ms). | Widget Test: tap en título de venta colapsa inputs. |
| **1.3** | `payment_entry_modal.dart` | El banner azul de instrucciones se oculta/contrae cuando la cabecera está colapsada, maximizando el espacio de cuotas. | Widget Test: altura del banner colapsado = 0 o chip compacto en mini-header. |
| **2.1** | `client_full_stats_modal.dart` | Muestra la tarjeta visual de "Balance Comercial" con Compras vs. Abonos, % de cobertura y saldo pendiente. | Widget Test: `find.textContaining('Cubierto')` y barra de progreso. |
| **2.2** | `client_full_stats_modal.dart` | Muestra el Ticket Promedio con formato monetario uniforme (`AppCurrency.format`). | Widget Test: `find.text('Ticket Promedio')`. |
| **2.3** | `client_full_stats_modal.dart` | Calcula y muestra la "Frecuencia Media de Compra" ("Cada X días", "Semanal", etc.) según las fechas de compras registradas. | Unit & Widget Test: verificación con 1, 2 y múltiples compras. |
| **3.1** | Integridad General | `flutter analyze` reporta 0 issues y la suite completa de pruebas pasa al 100%. | `flutter test` exitoso. |

---

## 5. Próximos Pasos

1. Presentar este informe y resumen al usuario para su revisión.
2. Esperar la autorización expresa del usuario antes de proceder con las modificaciones de código.
