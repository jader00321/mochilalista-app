# 🚀 PLAN MAESTRO DE TRABAJO (PARTE 1): HISTORIAL DE VENTAS, PARIDAD TOTAL HOME, VERDAD CONTABLE, REDISEÑO DE KPIS, FILTROS ERGONÓMICOS Y PROTECCIÓN CONTRA OVERLAYS

**Documento de Especificación Técnica, Diagnóstico Forense y Protocolo Adversarial**  
**Proyecto:** MochilaLista App (Local-First SQLite, 0ms Latency, Flutter)  
**Módulos Involucrados:**
- **Actividad Reciente (Home):** `recent_activity_list.dart` (`lib/core/widgets/home/recent_activity_list.dart`), `home_screen.dart` (`lib/core/widgets/home/home_screen.dart`).
- **Historial de Ventas (Listado y Tarjetas):** `sales_history_screen.dart` (`lib/features/smart_quotation/screens/sales_history_screen.dart`), `sales_list_builder.dart` (`lib/features/smart_quotation/widgets/history/sales_list_builder.dart`), `sale_action_bottom_sheet.dart` (`lib/features/smart_quotation/widgets/history/sale_action_bottom_sheet.dart`).
- **Dashboard de Métricas KPIs:** `history_dashboard_cards.dart` (`lib/features/smart_quotation/widgets/history/history_dashboard_cards.dart`).
- **Filtros de Tiempo, Estado y Ordenamiento:** `history_filter_bar.dart` (`lib/features/smart_quotation/widgets/history/history_filter_bar.dart`), `sale_provider.dart` (`lib/features/smart_quotation/providers/sale_provider.dart`), `sale_repository.dart` (`lib/features/smart_quotation/repositories/sale_repository.dart`).
- **Detalle de Recibo y Préstamos:** `sale_history_detail_screen.dart` (`lib/features/smart_quotation/screens/sale_history_detail_screen.dart`), `detail_status_card.dart` (`lib/features/smart_quotation/widgets/history/detail_widgets/detail_status_card.dart`), `sale_financial_detail_screen.dart` (`lib/features/smart_quotation/screens/crm/sale_financial_detail_screen.dart`).
- **Blindaje y Overlays:** `deep_nav_return_pill.dart` (`lib/core/widgets/deep_nav_return_pill.dart`).
- **Modelos y Datos:** `crm_models.dart` (`lib/features/smart_quotation/models/crm_models.dart`), `client_service.dart` (`lib/features/smart_quotation/services/client_service.dart`), `sales_service.dart` (`lib/features/smart_quotation/services/sales_service.dart`).
**Fecha:** Octubre 2026  
**Metodología:** Loop Autónomo + Árbitro Adversarial Estricto  

---

## 📸 1. AUDITORÍA FORENSE DE LAS 5 CAPTURAS Y DIAGNÓSTICO EN CÓDIGO FUENTE

A partir del análisis exhaustivo de las 5 capturas provistas por el usuario y la inspección rigurosa de los archivos del repositorio, se determinan las causas raíz exactas que originan cada inconsistencia visual, contable y funcional:

| Captura | Pantalla / Componente | Diagnóstico Forense del Problema | Causa Raíz Exacta en Código Fuente |
| :--- | :--- | :--- | :--- |
| **Imagen 1** | **`Actividad Reciente` (Home)** (`recent_activity_list.dart`) | **1. Préstamo Personal camuflado como Venta Directa:** `Préstamo #2` de `Freddy` por `240,00 S/` aparece con etiqueta `"Venta Directa (#2)"` y el ícono verde de caja registradora (`point_of_sale_rounded`), simulando una venta de mostrador inexistente.<br>**2. Ausencia de Estado Financiero Real:** Ninguna de las 3 transacciones (`#3`, `#2`, `#1`) muestra si está `Pagada`, `Parcial` o `Pendiente`, ni cuánto debe el cliente.<br>**3. Falta de Discriminación Semántica entre Caja Rápida y Cotizaciones:** El ícono y color solo bifurcan por `quotationId != null`. | • `recent_activity_list.dart` L66: `final isQuotation = sale.quotationId != null;`<br>• L83-90: Asigna color verde e ícono `point_of_sale_rounded` si no es cotización, ignorando `sale.origenVenta == 'prestamo_personal'`.<br>• L111: Renderiza `"${isQuotation ? "Cotización" : "Venta Directa"} (#${sale.displayId})"`. Como el préstamo no tiene `quotationId`, lo etiqueta erróneamente como `"Venta Directa"`.<br>• No existe badge ni texto que evalúe `sale.paidAmount` vs `sale.totalAmount`. |
| **Imagen 2** | **`Historial de Ventas` (KPIs y Filtros)** (`history_dashboard_cards.dart`, `history_filter_bar.dart`) | **1. Mutilación Horizontal de KPIs:** La primera tarjeta dice `"Ventas Reali..."` (truncado con `...`) y la tercera tarjeta queda cortada fuera de la pantalla a la derecha (`"P... 18,..."`).<br>**2. Filtro `Ordenar` Oculto tras Scroll:** La fila de chips (`Hoy`, `Esta Semana`, `Este Mes`, `6 Meses`...) exige arrastrar horizontalmente para descubrir el botón `Ordenar`.<br>**3. Ausencia de Filtro Rápido por Deuda:** No es posible filtrar ventas con cobro pendiente de un solo toque. | • `history_dashboard_cards.dart` L30-71: Renderiza un `SingleChildScrollView(scrollDirection: Axis.horizontal)` con anchos fijos de 150px, 170px y 170px (total 546px de ancho). En pantallas de 360-412px, la 3ª tarjeta se desborda y la 1ª tarjeta (150px - 32px padding - 26px icono) no tiene espacio para el texto *"Ventas Realizadas"*.<br>• `history_filter_bar.dart` L181-213: `ListView` horizontal que oculta `ActionChip("↕️ Ordenar")` en el extremo derecho inaccesible a simple vista. |
| **Imagen 3** | **`Historial de Ventas` (Superposición Overlay)** (`deep_nav_return_pill.dart`, `sales_history_screen.dart`) | **Obstrucción por Burbuja Flotante `"Caja Rápida (1) S/ 1.00 >"`:**<br>En la esquina inferior izquierda flota la píldora verde del dock de Caja Rápida, tapando las tarjetas de historial y los títulos de préstamos/ventas. | • `sales_history_screen.dart` L431: Declara directamente en el `Stack` del body: `const DeepNavReturnPill(isBottom: true)`.<br>• `DeepNavReturnPill` se diseñó para atajos durante navegación de abastecimiento/catálogo, pero en una pantalla de auditoría e historial contable resulta un estorbo visual invasivo. |
| **Imagen 4** | **`Historial de Ventas` (Tarjetas de Ventas y Préstamos)** (`sales_list_builder.dart`, `crm_models.dart`) | **1. MENTIRA CONTABLE CRÍTICA (`Recibo #1` dice `✅ PAGADO` debiendo S/ 18.57):** La tarjeta de `Recibo #1` (`23,57 S/`) muestra una barra verde `✅ PAGADO`, a pesar de que el cliente solo abonó `5,00 S/` y debe `18,57 S/`.<br>**2. Préstamo Oculta al Cliente `Freddy`:** En `Préstamo #2` el título dice `"Préstamo Personal"` y abajo `"Sin motivo especificado"` (además cortado), borrando el nombre de Freddy.<br>**3. Desaparición del Origen en Ventas:** `Recibo #1` no indica si provino de una Cotización Vendida o de Caja Rápida.<br>**4. Barras Gigantes Desperdiciadas:** Badges ocupan el 100% del ancho como bloques apilados. | • `sales_list_builder.dart` L54: `final isCredit = sale.paymentStatus == 'pendiente';`<br>• L156: `_Badge(text: isCredit ? "CRÉDITO" : "PAGADO", ...)`: Como el estado real de `Recibo #1` es `'parcial'`, `isCredit` evalúa a `false` y **falsamente afirma `PAGADO`**.<br>• L103-113: Para préstamos, fuerza `title = "Préstamo Personal"` ignorando por completo `sale.clientName` (que sí contiene `"Freddy"`).<br>• L105: Muestra `"Sin motivo especificado"` porque `SaleModel.fromJson` busca `json['notas']` en vez del campo de SQLite `json['nota_prestamo']`.<br>• `_Badge` usa `Row` sin `mainAxisSize: MainAxisSize.min`, expandiéndose al 100% de la tarjeta. |
| **Imagen 5** | **`Detalle de Venta` (`Recibo #1`)** (`sale_history_detail_screen.dart`, `detail_status_card.dart`) | **Contradicción entre Detalle e Historial:**<br>El detalle demuestra la verdad contable (`Estado: PARCIAL`, `Importe Total: 23,57 S/`, `Abonado: 5,00 S/`, `Deuda Pendiente: 18,57 S/`), probando que la tarjeta de la `Imagen 4` mentía al usuario. | • `detail_status_card.dart` sí calcula adecuadamente `pendingDebt = totalAmount - paidAmount` y muestra `"Deuda Pendiente: 18,57 S/"`.<br>• La desconexión ocurre porque `sales_list_builder.dart` no utilizaba la matemática real de `paidAmount` y `totalAmount`. |

---

## 🎯 2. OBJETIVOS ARQUITECTURALES Y DE DISEÑO "MOBILE AWARDS"

1. **Paridad Total y Consistencia Conceptual entre Home e Historial:**
   * Cualquier transacción (`Caja Rápida`, `Cotización Vendida`, `Préstamo Personal`) debe identificarse con la misma exactitud, ícono semántico, color temático y badge de origen tanto en la pantalla de inicio como en el listado cronológico de ventas.
   * `Préstamo Personal` debe figurar siempre con el nombre de su cliente vinculado (ej. `Freddy`), su ícono financiero (`account_balance_wallet`), su identificador (`Préstamo #2`) y su motivo real recuperado de SQLite.
2. **Verdad Contable Absoluta en las Tarjetas (Regla Zero-Bullshit):**
   * Queda terminantemente prohibido mostrar `✅ PAGADO` si existe saldo deudor (`deudaPendiente > 0.01`).
   * Estados financieros estrictos:
     * `✅ PAGADO`: `deudaPendiente <= 0.01` y `!isArchived`.
     * `🟠 PAGO PARCIAL · Debe S/ [X]`: `montoPagado > 0.01` y `deudaPendiente > 0.01`.
     * `🔴 PENDIENTE DE COBRO`: `montoPagado <= 0.01` y `deudaPendiente > 0.01`.
     * `🚫 ANULADA`: si la venta o préstamo fue anulado/archivado (`isArchived == true`).
   * Desglose visual en la columna de montos: Mostrar el Total y, en caso de pago parcial o saldo deudor, desglosar en texto compacto: `Abonado: S/ 5.00 · Debe: S/ 18.57`.
3. **Rediseño Compacto y Ergonómico de las Tarjetas de Ventas:**
   * Erradicar las barras gigantes apiladas que ocupaban toda la anchura del card (`Row` con `mainAxisSize: MainAxisSize.min`).
   * Distribuir la información en 3 zonas nítidas:
     1. **Fila Superior:** Identificador (`Recibo #X` / `Préstamo #X`) + **Badge de Origen Explícito** (`⚡ Caja Rápida`, `📋 Cotización Vendida` o `🏦 Préstamo Personal`) + Fecha y hora con formato legible.
     2. **Cuerpo Central:** Avatar temático circular + Nombre del Cliente visible (`Freddy` o `"Cliente eventual"`) + Subtítulo con motivo/resumen + Chip compacto del Método de Pago (`YAPE`, `EFECTIVO`, etc.) sin textos cortados + Columna derecha de importes con tipografía contable de alta jerarquía.
     3. **Fila Inferior:** Badges compactos horizontales (Estado de Pago Real + Estado de Entrega para ventas de productos, omitiéndolo estrictamente en préstamos).
4. **Optimización Espacial de KPIs (Cero Scroll Horizontal y Cero `...`):**
   * Transformar el carrusel desbordado de 546px en un Dashboard Compacto responsivo de 3 columnas proporcionales que aprovecha el 100% del ancho del dispositivo sin scroll horizontal ni truncamiento de textos:
     1. **Operaciones / Ventas:** Conteo de transacciones del filtro.
     2. **Ingresos Cobrados (S/):** Dinero efectivamente cobrado (`total_ingresos`), sin inflarlo con promesas de pago o créditos.
     3. **Por Cobrar / Deuda (S/):** Saldo total pendiente de cobro (`total_deuda`).
5. **Barra Unificada de Control y Filtros (Sin Scroll Oculto):**
   * Reemplazar la lista horizontal ciega por una barra de herramientas accesible de 1 toque:
     * **Selector de Periodo Activo** (Pill interactivo que muestra el periodo actual: `Hoy`, `Esta Semana`, `Este Mes`, `6 Meses`, `Todo` o `Personalizado` y abre un selector modal rápido).
     * **Selector de Ordenamiento Activo** (Pill que muestra el criterio actual: `Recientes`, `Monto`, `Mayor Deuda` y permite conmutar).
     * **Segmento / Filtro Rápido de Estado Financiero** (`Todos`, `Pagados`, `Con Deuda / Parciales`, `Anuladas`).
6. **Limpieza Visual y Blindaje de Overlays:**
   * Retirar `DeepNavReturnPill` de `sales_history_screen.dart` para que la burbuja verde de Caja Rápida jamás invada ni tape los comprobantes.
   * Blindar el padding inferior de `SalesListBuilder` (110px) para que el botón flotante de volver arriba (`↑`) nunca tape información de la última tarjeta.

---

## 🏗️ 3. PLAN DE EJECUCIÓN EN 5 FASES

```mermaid
flowchart TD
    subgraph FASE 1: Integridad del Modelo y Repositorio SQLite
        F1_1[Corregir mapeo de nota_prestamo en SaleModel.fromJson] --> F1_2[Crear getters contables pendingDebt, isFullyPaid, isPartial, isLoan]
        F1_2 --> F1_3[Implementar filtro por estado financiero en SaleRepository]
        F1_3 --> F1_4[Implementar ordenamiento por Mayor Deuda en SQLite]
    end

    subgraph FASE 2: Paridad y Rediseño de Actividad Reciente en el Home
        F2_1[Diferenciar orígenes: Caja Rápida vs Cotización vs Préstamo] --> F2_2[Asignar iconos y paleta semántica específica]
        F2_2 --> F2_3[Integrar nombre de cliente y badge de estado financiero real]
        F2_3 --> F2_4[Enrutar préstamos a su detalle correspondiente]
    end

    subgraph FASE 3: Rediseño Integral de Tarjetas en Historial de Ventas
        F3_1[Crear Cabecera con ID + Badge Origen Explícito + Fecha/Hora] --> F3_2[Mostrar Cliente siempre visible en préstamos y ventas]
        F3_2 --> F3_3[Columna de Importes con Desglose Abonado vs Debe]
        F3_3 --> F3_4[Badges compactos en 1 sola fila horizontal sin barras gigantes]
    end

    subgraph FASE 4: Rediseño Responsivo de KPIs y Barra Unificada de Filtros
        F4_1[Rediseñar HistoryDashboardCards a 3 columnas sin scroll horizontal] --> F4_2[Garantizar textos legibles sin puntos suspensivos]
        F4_2 --> F4_3[Crear barra ergonómica de Periodo y Ordenamiento visible]
        F4_3 --> F4_4[Integrar conmutador rápido de Estado Financiero Todos/Pagados/Deuda]
    end

    subgraph FASE 5: Blindaje de Overlays, Navegación y Batería de Pruebas
        F5_1[Eliminar DeepNavReturnPill de sales_history_screen] --> F5_2[Ajustar padding inferior seguro contra el FAB Back-To-Top]
        F5_2 --> F5_3[Crear suite de pruebas unitarias y de widgets de paridad y finanzas]
        F5_3 --> F5_4[Ejecutar flutter test completo certificando 0 regresiones]
    end

    FASE 1 --> FASE 2 --> FASE 3 --> FASE 4 --> FASE 5
```

---

## 📋 4. DETALLE TÉCNICO PASO A PASO POR FASES

### FASE 1: Integridad del Modelo, Cálculos Contables y Repositorio SQLite
* **Archivos a intervenir:**
  * `lib/features/smart_quotation/models/crm_models.dart`
  * `lib/features/smart_quotation/repositories/sale_repository.dart`
  * `lib/features/smart_quotation/providers/sale_provider.dart`
* **Acciones detalladas:**
  1. **Corrección de Mapeo de Motivo del Préstamo en `SaleModel.fromJson`:**
     * En `crm_models.dart` L344, corregir la deserialización de notas:
       ```dart
       // ANTES (dejaba en null los motivos de préstamos):
       notes: json['notas'],
       // DESPUÉS (recupera la columna real SQLite nota_prestamo):
       notes: json['nota_prestamo'] ?? json['notas'],
       ```
  2. **Getters de Negocio y Finanzas en `SaleModel`:**
     * Agregar getters estandarizados para garantizar una sola fuente de verdad en toda la app:
       ```dart
       double get pendingDebt => (totalAmount - paidAmount) > 0.01 ? (totalAmount - paidAmount) : 0.0;
       bool get isFullyPaid => pendingDebt <= 0.01;
       bool get isPartialPayment => paidAmount > 0.01 && pendingDebt > 0.01;
       bool get isUnpaid => paidAmount <= 0.01 && pendingDebt > 0.01;
       bool get isLoan => origenVenta == 'prestamo_personal';
       bool get isQuickSale => origenVenta == 'pos_rapido';
       bool get isQuotationSale => origenVenta == 'smart_quotation' || quotationId != null;
       ```
  3. **Filtro de Estado Financiero y Ordenamiento por Deuda en `SaleRepository`:**
     * En `SaleRepository.getHistoryRaw`, soportar nuevo parámetro `financialStatus`:
       * `'todos'`: sin condición adicional.
       * `'pagados'`: `AND (v.monto_total - v.monto_pagado <= 0.01 OR v.estado_pago = 'pagado')`.
       * `'con_deuda'`: `AND (v.monto_total - v.monto_pagado > 0.01 AND v.estado_pago != 'pagado')`.
     * En la lista de ordenamiento seguro, agregar soporte para ordenar por deuda descendente:
       * `sortBy == 'deuda_pendiente'`: `ORDER BY (v.monto_total - v.monto_pagado) DESC`.
  4. **Exposición en `SaleProvider`:**
     * Agregar propiedades `financialFilter` (`todos`, `pagados`, `con_deuda`), setter `setFinancialFilter(String filter)` y actualizar `loadFilteredHistory(reset: true)`.

---

### FASE 2: Paridad y Rediseño de `Actividad Reciente` en el Home
* **Archivos a intervenir:**
  * `lib/core/widgets/home/recent_activity_list.dart`
* **Acciones detalladas:**
  1. **Diferenciación Semántica de Origen:**
     * Reemplazar la condición binaria por una evaluación precisa de los 3 tipos de transacciones:
       * **Préstamo Personal (`isLoan`):**
         * Ícono: `Icons.account_balance_wallet_rounded`
         * Color fondo/ícono: Ámbar / Dorado (`Colors.amber`)
         * Etiqueta: `Préstamo (#${sale.displayId})`
       * **Caja Rápida (`isQuickSale`):**
         * Ícono: `Icons.flash_on_rounded` (o `Icons.point_of_sale_rounded`)
         * Color fondo/ícono: Verde Esmeralda (`Color(0xFF2E7D32)`)
         * Etiqueta: `Caja Rápida (#${sale.displayId})`
       * **Cotización Vendida (`isQuotationSale`):**
         * Ícono: `Icons.request_quote_rounded`
         * Color fondo/ícono: Naranja cálido (`Colors.orange`)
         * Etiqueta: `Cotización (#${sale.displayId})`
  2. **Inclusión del Nombre del Cliente y Fecha:**
     * Mostrar siempre el nombre del cliente (`Freddy` o `"Sin cliente"` en cursiva suave).
     * Subtítulo con método de pago formateado y fecha/hora clara.
  3. **Badge Compacto de Estado Financiero Real en el Home:**
     * Junto al importe o debajo de los metadatos, incluir un mini-badge elegante:
       * `Pagado`: Verde discreto.
       * `Parcial · Debe S/ 18.57`: Naranja con el saldo deudor visible.
       * `Pendiente`: Rojo/Ámbar claro con el saldo pendiente.

---

### FASE 3: Rediseño Integral de Tarjetas en `Historial de Ventas`
* **Archivos a intervenir:**
  * `lib/features/smart_quotation/widgets/history/sales_list_builder.dart`
* **Acciones detalladas:**
  1. **Fila Superior (Cabecera):**
     * Izquierda: Identificador en negrita (`Recibo #${sale.displayId}` o `Préstamo #${sale.displayId}`).
     * Centro: **Badge de Origen Explícito** con cápsula redondeada y contraste premium:
       * `⚡ Caja Rápida` (Verde esmeralda / Teal)
       * `📋 Cotización Vendida` (Naranja)
       * `🏦 Préstamo Personal` (Ámbar / Dorado)
     * Derecha: Fecha y hora (`22/08/2026 • 02:14 AM`).
  2. **Cuerpo Central:**
     * **Avatar temático:** Ícono circular diferenciado según el tipo.
     * **Nombre del Cliente:** En préstamos, mostrar obligatoriamente `sale.clientName` (ej. **`Freddy`**). En ventas sin cliente registrado, mostrar `"Cliente eventual"` o `"Venta en mostrador"`. Jamás suprimir el nombre del cliente.
     * **Subtítulo contextual:**
       * Si es préstamo: Mostrar el motivo real (`sale.notes`) y el chip del método de pago (`YAPE`, `EFECTIVO`).
       * Si es venta: Detalle de productos vinculados o nota comercial + chip del método de pago.
     * **Columna Derecha de Importes:**
       * `trueTotalAmount` en tipografía contable destacada (`23,57 S/` o `240,00 S/`).
       * Si hay saldo pendiente (`pendingDebt > 0.01`): Texto compacto inmediatamente debajo:
         * Si es parcial: `Abonado: S/ 5.00` y en rojo `Debe: S/ 18.57`.
         * Si es pendiente total: En rojo/naranja `Saldo: S/ 240.00`.
  3. **Fila Inferior de Estados (Horizontal y Compacta):**
     * Corregir el widget `_Badge` estableciendo `Row(mainAxisSize: MainAxisSize.min)` y márgenes adecuados para que los badges se muestren en una única fila horizontal como píldoras compactas, eliminando las dos barras gigantes que cubrían toda la anchura.
     * **Badge de Pago Real:**
       * `✅ PAGADO`: fondo verde traslúcido, texto verde oscuro/luminoso.
       * `🟠 PAGO PARCIAL · Debe S/ 18.57`: fondo naranja traslúcido, texto ámbar fuerte.
       * `🔴 PENDIENTE DE COBRO`: fondo rojo traslúcido, texto rojo.
       * `🚫 ANULADA`: fondo gris/rojo traslúcido para ventas archivadas.
     * **Badge de Entrega (solo en ventas):**
       * `📦 ENTREGADO` o `🚚 PENDIENTE RECOJO / ENVÍO`.
       * **Regla estricta:** Si `sale.isLoan == true`, **NO renderizar badge de entrega** (un préstamo de dinero no tiene entrega de mercadería física).

---

### FASE 4: Rediseño Responsivo de KPIs y Barra Unificada de Filtros
* **Archivos a intervenir:**
  * `lib/features/smart_quotation/widgets/history/history_dashboard_cards.dart`
  * `lib/features/smart_quotation/widgets/history/history_filter_bar.dart`
  * `lib/features/smart_quotation/screens/sales_history_screen.dart`
* **Acciones detalladas:**
  1. **Rediseño de KPIs sin Desbordamiento Horizontal:**
     * Eliminar el `SingleChildScrollView(scrollDirection: Axis.horizontal)` de `HistoryDashboardCards`.
     * Implementar un contenedor moderno de ancho completo (100% responsive) con `Row` y 3 widgets `Expanded`:
       * **Columna 1: Operaciones / Ventas** (Ícono de recibo, Azul). Muestra la cantidad entera sin cortes.
       * **Columna 2: Ingresos Cobrados** (Ícono de tendencia, Verde). Muestra `S/ [totalIngresos]` con formato de moneda limpio.
       * **Columna 3: Por Cobrar** (Ícono de billetera/reloj, Ámbar). Muestra `S/ [totalDeuda]` claramente visible sin cortes ni saltos fuera de la pantalla.
     * En pestañas archivadas, conmutar títulos y colores correspondientes: `Tickets Anulados`, `Monto Anulado`, `Deuda Anulada`.
  2. **Barra Unificada de Control (Sin Scroll Horizontal Oculto):**
     * Rediseñar `HistoryFilterChips` para presentar una barra de comandos ergonómica y visible de inmediato:
       * **Fila 1:** Buscador con `HistorySearchBar` existente.
       * **Fila 2:** Barra de control de 3 acciones fijas en pantalla:
         * **Botón Pill de Periodo:** Muestra el periodo activo con ícono de calendario (ej. `📅 6 Meses` o `📅 Hoy`). Al tocarlo, despliega un bottom sheet interactivo limpio con las opciones: `Hoy`, `Esta Semana`, `Este Mes`, `6 Meses`, `Todo el Tiempo` y `📅 Rango Personalizado`.
         * **Botón Pill de Orden:** Muestra el criterio activo (ej. `↕️ Recientes`, `↕️ Mayor Deuda`). Al tocarlo, permite elegir: `Más recientes`, `Más antiguos`, `Mayor importe`, `Menor importe` y `Mayor deuda pendiente`.
         * **Selector Rápido de Estado:** Selector de 3 estados contables: `Todos`, `Pagados`, `Con Deuda`.
       * El usuario percibe inmediatamente qué filtros están activos y puede cambiarlos sin desplazarse a ciegas.

---

### FASE 5: Blindaje de Overlays, Navegación y Batería de Pruebas Automatizadas
* **Archivos a intervenir:**
  * `lib/features/smart_quotation/screens/sales_history_screen.dart`
  * `lib/features/smart_quotation/widgets/history/sales_list_builder.dart`
  * `test/sales_history_parity_kpis_and_filters_test.dart` (Nuevo archivo de pruebas)
* **Acciones detalladas:**
  1. **Retiro Definitivo de `DeepNavReturnPill` en Historial:**
     * En `sales_history_screen.dart`, suprimir la línea `const DeepNavReturnPill(isBottom: true)`.
     * Verificar que en pantallas de detalle de venta y préstamo no existan píldoras invasivas flotantes del carrito de Caja Rápida.
  2. **Protección contra el FAB Back-To-Top:**
     * Asegurar que el `ListView.separated` de `SalesListBuilder` mantenga un padding inferior de al menos `110px`, de modo que cuando el usuario haga scroll hasta el final, el botón `↑` no tape ningún badge ni dato de la última tarjeta.
  3. **Batería de Pruebas Automatizadas:**
     * Crear el archivo `test/sales_history_parity_kpis_and_filters_test.dart` cubriendo:
       * **Test 1:** Deserialización de `SaleModel` recuperando `nota_prestamo` y nombre de cliente en préstamos.
       * **Test 2:** Lógica matemática de verdad contable (`pendingDebt`, `isFullyPaid`, `isPartialPayment`, `isUnpaid`).
       * **Test 3:** Validación de que una venta parcial (`total 23.57, pagado 5.00`) genera badge `PAGO PARCIAL` y jamás `PAGADO`.
       * **Test 4:** Validación de que `Actividad Reciente` clasifica correctamente `prestamo_personal`, `pos_rapido` y `smart_quotation`.
       * **Test 5:** Verificación de layout responsivo en KPIs (3 columnas fijas sin desbordamiento horizontal).
       * **Test 6:** Ausencia de `DeepNavReturnPill` en la vista de Historial de Ventas.
     * Ejecutar `flutter test` garantizando 0 errores y 100% de éxito.

---

## 🛡️ 5. MATRIZ DE COBERTURA Y CRITERIOS DE ACEPTACIÓN ADVERSARIAL

| Requerimiento del Usuario | Criterio de Certificación Adversarial | Validación en Pruebas |
| :--- | :--- | :--- |
| **Paridad de Préstamo en Home** | `Préstamo #2` se muestra como `Préstamo (#2)`, con ícono de billetera/préstamo dorado y cliente `Freddy`, jamás como `"Venta Directa"` verde. | Widget test verifica texto `"Préstamo (#2)"`, cliente `"Freddy"` e ícono ámbar. |
| **Badge de Origen en Historial** | Cada tarjeta de historial tiene badge superior inequívoco: `⚡ Caja Rápida`, `📋 Cotización Vendida` o `🏦 Préstamo Personal`. | Widget test verifica presencia del badge según `origenVenta`. |
| **Cliente en Préstamos de Historial** | `Préstamo #2` muestra con claridad `"Freddy"` como cliente principal y su motivo real en subtítulo. | Verificación de que `title == 'Freddy'` y no se sobreescribe con `"Préstamo Personal"`. |
| **Verdad Contable en Tarjetas** | `Recibo #1` (`23,57 S/`, abonado `5,00 S/`) muestra `PAGO PARCIAL · Debe S/ 18.57` y desglose `Abonado: S/ 5.00 · Debe: S/ 18.57`. | Test contable rechaza terminantemente `PAGADO` cuando `pendingDebt > 0.01`. |
| **KPIs sin `...` ni Desbordamiento** | Las 3 tarjetas de métricas se muestran simultáneamente en pantallas de 360px a 412px sin scroll horizontal y sin truncar títulos. | Layout test confirma que las 3 tarjetas se encuentran dentro del viewport visible. |
| **Filtros y Orden sin Scroll Oculto** | El usuario ve el periodo activo, el ordenamiento activo y los filtros de estado sin tener que arrastrar horizontalmente la lista. | Verificación visual de barra unificada fija en pantalla. |
| **Eliminación de Píldora Flotante** | La pantalla de Historial de Ventas no renderiza la burbuja verde `"Caja Rápida (1) S/ 1.00 >"`. | Test confirma ausencia de `DeepNavReturnPill` en el árbol de widgets de `SalesHistoryScreen`. |
