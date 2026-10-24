# 🚀 PLAN MAESTRO DE TRABAJO (PARTE 1): DIRECTORIO DE CLIENTES, MODAL CREAR/EDITAR, PERFIL 360°, TRASLADO DE TENDENCIA COMERCIAL, ALERTA INTELIGENTE PLEGABLE Y AUDITORÍA DE PESTAÑAS

**Documento de Especificación Técnica, Diagnóstico Forense y Protocolo Adversarial**  
**Proyecto:** MochilaLista App (Local-First SQLite, 0ms Latency, Flutter)  
**Módulos Involucrados:**
- **Directorio de Clientes (Pantalla y Tarjetas):** `client_tracking_screen.dart` (`lib/features/smart_quotation/screens/crm/client_tracking_screen.dart`), `client_card.dart` (`lib/features/smart_quotation/widgets/crm/client_card.dart`), `client_filter_bar.dart` (`lib/features/smart_quotation/widgets/crm/client_filter_bar.dart`).
- **Modal Registro y Edición:** `client_profile_editor.dart` (`lib/features/smart_quotation/widgets/crm/client_profile_editor.dart`).
- **Perfil del Cliente (Cabecera y Acciones):** `client_detail_screen.dart` (`lib/features/smart_quotation/screens/crm/client_detail_screen.dart`), `client_stats_header.dart` (`lib/features/smart_quotation/widgets/crm/client_stats_header.dart`).
- **Analítica y Tendencia Comercial:** `client_compliance_sparkline.dart` (`lib/features/smart_quotation/widgets/crm/client_compliance_sparkline.dart`), `client_full_stats_modal.dart` (`lib/features/smart_quotation/widgets/crm/client_full_stats_modal.dart`).
- **Pestañas Operativas del Perfil:** `ledger_timeline_tab.dart` (`lib/features/smart_quotation/widgets/crm/ledger_timeline_tab.dart`), `client_sales_history_tab.dart` (`lib/features/smart_quotation/widgets/crm/client_sales_history_tab.dart`), `client_quotations_tab.dart` (`lib/features/smart_quotation/widgets/crm/client_quotations_tab.dart`).
- **Coordinación de Dock y Botones Flotantes:** `deep_nav_return_pill.dart` (`lib/core/widgets/deep_nav_return_pill.dart`), FABs en `client_detail_screen.dart`.
- **Estandarización Monetaria Global:** `currency_formatter.dart` (`lib/core/utils/currency_formatter.dart`).
**Fecha:** Octubre 2026  
**Metodología:** Loop Autónomo + Árbitro Adversarial Estricto  

---

## 📸 1. AUDITORÍA FORENSE DE LAS 5 CAPTURAS Y DIAGNÓSTICO EN CÓDIGO FUENTE

A partir de la inspección de las 5 capturas reales y el análisis línea por línea del código fuente en `app_movil`, se identifican las causas raíz técnicas exactas de cada anomalía:

| Captura | Pantalla / Componente | Diagnóstico Forense del Problema | Causa Raíz Exacta en Código Fuente |
| :--- | :--- | :--- | :--- |
| **Captura 1** | **Directorio de Clientes** (`Directorio de Cl...`) | **1. Mutilación del Título en AppBar:** Dice `"Directorio de Cl..."` por falta de espacio horizontal.<br>**2. Incoherencia Gramatical:** Muestra `"1 clientes"` cuando la regla de español exige singular `"1 cliente"`.<br>**3. Chip de Confianza Cortado:** El chip `"Nivel Confianza"` con ícono de escudo queda mutilado a la derecha en pantallas estándar (~360-390px) y cicla a ciegas al tocarlo.<br>**4. Asfixia Superior de la Primera Tarjeta:** La tarjeta `"Freddy"` está pegada a la barra `"1 clientes \| Ordenar"` sin separación visual.<br>**5. Disparidad Monetaria:** La tarjeta dice `"258,57 S/"` (sufijo) mientras la píldora inferior dice `"S/ 1.00"` (prefijo). | • `client_tracking_screen.dart` L304: `Text("Directorio de Clientes", style: TextStyle(fontSize: 22))` compite con `InfoTooltipButton` + `IconButton` (Nuevo Cliente) sin `FittedBox` ni tamaño elástico.<br>• `client_tracking_screen.dart` L426: String interpolado estático `"${clients.length} clientes"` sin operador ternario para `clients.length == 1`.<br>• `client_filter_bar.dart` L17-41 & L68-114: `ListView` horizontal con ancho excesivo por chip; el chip cicla estados (`excelente -> bueno -> regular -> moroso -> todos`) en un switch en L100 sin desplegar un menú selector accesible.<br>• `client_tracking_screen.dart` L464: `SliverPadding(padding: EdgeInsets.only(top: 12, bottom: 120))` insuficiente sumado a que la barra de ordenamiento no tiene elevación ni margen inferior.<br>• `client_card.dart` L89: `NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ')` que por estándar CLDR en Dart coloca el símbolo al final (`258,57 S/`) si no se fuerza `customPattern: 'S/ #,##0.00'`. |
| **Captura 2** | **Modal Nuevo Cliente** (`Nuevo Cliente`) | **1. Chips de Etiquetas Mutilados Verticalmente:** En `"Perfilamiento CRM (Etiquetas)"`, los chips sugeridos `+ VIP` y `+ Mayorista` aparecen cortados por la mitad justo encima del botón `"GUARDAR CLIENTE"`.<br>**2. Sección Confianza Oculta Arbitrariamente:** Se le prohíbe al usuario asignar Nivel de Confianza al crear un cliente nuevo, obligándolo a crearlo como "bueno" y luego volver a editarlo para cambiarlo. | • `client_profile_editor.dart` L255-278 & L337-345: `height: MediaQuery.of(context).size.height * 0.9` con `Column` y `Expanded(child: ListView(...))` donde el padding inferior no contempla el espacio visual del footer fijo ni la altura mínima de los chips sugeridos.<br>• `client_profile_editor.dart` L300: `if (!widget.isNew) ...` oculta la sección de Nivel de Confianza en modo creación sin fundamento de negocio. |
| **Captura 3** | **Modal Editar Perfil** (`Editar Perfil`) | **Superposición Desprolija de Etiquetas Flotantes:** Los labels `"Nombre Completo / Razón Social *"`, `"Celular"` y `"Dirección Completa"` pisan el borde superior de los rectángulos oscuros (`0xFF14141C`) de los inputs. | • `client_profile_editor.dart` L399-406: `TextField` utiliza `labelText: hint` con `filled: true`, `isDense: true` y `border: OutlineInputBorder(..., borderSide: BorderSide.none)`. Al flotar el label sobre un fondo oscuro plano (`0xFF23232F`), Flutter no recorta el borde del contenedor interior, montando el texto sobre la unión cromática. |
| **Captura 4** | **Perfil del Cliente** (`Perfil del Clie...`) | **1. Colisión de Alerta de Cuotas Vencidas:** En la tarjeta roja `"5 cuota(s) vencida(s)"`, el texto `"Deuda más antigua: hace 47 días"` choca violentamente contra el botón verde `"Recordar"`.<br>**2. Saturación Vertical por "Tendencia Comercial":** El bloque de la sparkline naranja ocupa ~75px en medio de la cabecera mostrando una línea sin ejes, sin fechas ni montos claros, desplazando las pestañas hacia abajo.<br>**3. Título Mutilado:** AppBar muestra `"Perfil del Clie..."`.<br>**4. Bloqueo Invasivo de Filtros por Botones Flotantes:** La píldora de Caja Rápida y los FABs tapan los chips de la pestaña (`Todos 3`, `Cargos 2`, `Abonos 1`). | • `client_stats_header.dart` L392-426: `Row` rígido con `Expanded(child: Column(...))` y `ElevatedButton.icon` de tamaño fijo; en anchos < 380px los textos se quiebran en 3 renglones desbordando el ancho disponible.<br>• `client_stats_header.dart` L174: `ClientComplianceSparkline` embebido incondicionalmente en la cabecera; `client_compliance_sparkline.dart` usa datos simulados si hay pocas ventas.<br>• `client_detail_screen.dart` L249: `Text("Perfil del Cliente", style: TextStyle(fontSize: 20))` sin ajuste elástico ante 3 botones de acción en el AppBar.<br>• Altura total de cabecera > 520px; en pantallas estándar sólo quedan ~180px de viewport, haciendo que los chips caigan en la coordenada exacta de `DeepNavReturnPill` (bottom 80px) y el FAB (bottom 16px). |
| **Captura 5** | **Historial de Compras** (`Historial de Compras`) | **1. Choque Horizontal de Título contra Monto:** El título `"Préstamo Personal"` colisiona casi sin margen contra la caja roja derecha `"Debe 240,00 S/"`.<br>**2. Pestañas del TabBar Mutiladas:** Se lee `"...e Cuenta"`, `"Historial de Compras"`, `"Listas Pe..."` con scroll forzado y texto cortado.<br>**3. Moneda Inconsistente:** Muestra `"240,00 S/"` y `"18,57 S/"` con sufijo.<br>**4. Solapamiento Crítico de FABs sobre Listados:** En la parte inferior, el mini FAB `^` y el botón extendido `"Registrar Abono"` cubren las tarjetas del historial y el enlace `"Detalle >"`. | • `client_sales_history_tab.dart` L71-136: `Row` con `Expanded` en la columna izquierda y `Column` derecha de ancho libre; no existe un `SizedBox(width: 12)` ni restricción de wrapping para el título.<br>• `client_detail_screen.dart` L315-331: `TabBar` tiene `isScrollable: true` con `labelPadding: EdgeInsets.symmetric(horizontal: 20)`, obligando al scroll horizontal y cortando el primer y tercer tab en pantallas normales.<br>• `client_sales_history_tab.dart` L21: `NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ')` sin `customPattern`.<br>• `client_sales_history_tab.dart` L44: `padding: EdgeInsets.fromLTRB(16, 20, 16, 100)`: 100px es insuficiente frente a los 130px combinados que ocupan el FAB extendido (`height: 56`), el mini FAB (`height: 40`), el espacio entre ambos (`16px`) y el padding de seguridad del sistema. |

---

## 🎯 2. OBJETIVOS ARQUITECTURALES Y DE DISEÑO "MOBILE AWARDS"

1. **Estandarización Monetaria Global (Regla de Oro: `S/ #,##0.00`):**
   * Crear el helper centralizado `AppCurrency` en `lib/core/utils/currency_formatter.dart` para que todo el módulo CRM (tarjetas de cliente, estado de cuenta, historial, modales y exportaciones) muestre siempre el formato canónico peruano con prefijo: **`S/ 258.57`**, desterrando el sufijo desordenado `258,57 S/`.
2. **Directorio de Clientes Limpio, Respirable y Ergonómico:**
   * **Separación Visual Perfecta:** Rediseñar la zona superior con `SliverPadding` y márgenes respirables (16px) entre el Buscador, la barra de filtros, el contador de clientes y la primera tarjeta.
   * **Corrección Gramatical Estricta:** Implementar helper pluralizador: `"${clients.length} ${clients.length == 1 ? 'cliente' : 'clientes'}"`.
   * **Selector Accesible de Confianza:** Sustituir el ciclo ciego del chip por un selector modal/bottom-sheet refinado que permita elegir entre `Todos`, `Excelente`, `Bueno`, `Regular` y `Moroso` con sus colores semánticos respectivos.
   * **Evolución de Tarjeta:** Incorporar DNI/RUC y teléfono de forma sutil y legible (sin que las etiquetas CRM oculten el número de contacto), badge discreto si el cliente posee cuotas vencidas (`⚠️ X vencidas`), badges de etiquetas elegantes y botones de acción rápida (`Cobrar`, `WhatsApp`, `Llamar`) con feedback háptico.
3. **Reingeniería del Modal Crear / Editar Perfil:**
   * **Etiquetas Estructuradas Superiores:** Reemplazar el `labelText` flotante por etiquetas fijas limpias situadas por encima de cada caja de texto (`Text` de 13px en semi-bold con color secundario), garantizando que jamás colisionen con los bordes de los campos oscuros.
   * **Sección de Nivel de Confianza Unificada:** Permitir la asignación de Nivel de Confianza tanto en la creación como en la edición con tarjetas táctiles animadas.
   * **Sugerencias CRM y Teclado:** Asegurar que los chips sugeridos (`+ VIP`, `+ Mayorista`) nunca se recorten, utilizando un `SingleChildScrollView` con padding dinámico sensible a `viewInsets.bottom` y physics fluidas.
4. **Descongestión de Cabecera y Traslado de "Tendencia Comercial" a "Ver Analítica":**
   * **Liberación de Espacio en Perfil:** Retirar la sparkline decorativa de la cabecera principal de `ClientDetailScreen`, reduciendo la altura de la cabecera de ~520px a ~260px (liberando más de 250px verticales inmediatos para las pestañas operativas).
   * **Elevación en Modal "Ver Analítica":** Integrar en `ClientFullStatsModal` una visualización comercial de alto nivel, con gráfico interactivo por periodos (`Todo`, `6 Meses`, `Mes`, `Semana`, `Personalizado`), montos reales, comparativa de compras vs pagos, ticket promedio y frecuencia de compra.
5. **Tarjeta de Alerta de "Cuotas Vencidas" Inteligente, Plegable y Responsiva:**
   * **Diseño Responsivo Sin Colisión:** Reestructurar el banner de deuda vencida para que el conteo de cuotas, los días de atraso y el botón `"Recordar"` coexistan armónicamente en cualquier resolución sin encogerse ni pisarse.
   * **Doble Modo con Animación Suave (`AnimatedCrossFade` / `AnimatedSize`):**
     * **Modo 1 — Expandido (Detallado):** Muestra el diagnóstico de atraso, monto vencido, botón de WhatsApp `"Recordar"` y un botón táctil para plegar.
     * **Modo 2 — Retraído (Píldora Discreta):** Un banner ultra-compacto (< 36px) con icono de alerta, texto `"5 cuotas vencidas"` y botón para desplegar o recordar rápidamente.
   * **Memoria Inteligente con Persistencia Local (7 Días o Nueva Cuota):**
     * Guardar en `SharedPreferences` el timestamp de plegado y la cantidad de cuotas vencidas (`client_overdue_dismissed_${client.id}` y `client_overdue_last_count_${client.id}`).
     * La alerta se mantendrá plegada en visitas posteriores si no han transcurrido 7 días Y no ha vencido ninguna cuota nueva.
     * Si transcurren más de 7 días O si la cantidad de cuotas vencidas aumenta (información crítica nueva), se auto-despliega de inmediato.
6. **Perfeccionamiento de las 3 Pestañas y Blindaje Anti-Colisión Flotante:**
   * **TabBar Totalmente Legible:** Ajustar padding y estilo del `TabBar` para que los 3 títulos (`Estado de Cuenta`, `Historial de Compras`, `Listas Pendientes`) se lean íntegros sin recortes.
   * **Tarjetas sin Desbordamiento:** En `ClientSalesHistoryTab`, `LedgerTimelineTab` y `ClientQuotationsTab`, garantizar que los títulos (ej. `"Préstamo Personal"`) y los montos (ej. `"Debe S/ 240.00"`) nunca colisionen.
   * **Clearance Inferior Seguro contra Overlays (140px):** Incrementar el padding inferior de las 3 pestañas a `bottom: 140` para que el listado pueda desplazarse completamente por encima de `DeepNavReturnPill`, el botón `"Registrar Abono"` y el mini FAB de retorno arriba.

---

## 🏗️ 3. PLAN DE EJECUCIÓN EN 5 FASES

```mermaid
flowchart TD
    subgraph FASE 1: Estandarización Monetaria y Directorio de Clientes
        F1_1[Crear AppCurrency centralizado con prefijo S/ #,##0.00] --> F1_2[Corregir gramática 1 cliente vs N clientes]
        F1_2 --> F1_3[Implementar Selector Modal para Nivel de Confianza]
        F1_3 --> F1_4[Rediseñar espaciado superior y primera tarjeta en Directorio]
        F1_4 --> F1_5[Evolucionar ClientCard con DNI/RUC, badges y alerta de cuotas]
    end

    subgraph FASE 2: Reingeniería del Modal Crear / Editar Perfil
        F2_1[Reemplazar labelText flotante por etiquetas fijas limpias superiores] --> F2_2[Habilitar Nivel de Confianza tanto en creación como en edición]
        F2_2 --> F2_3[Corregir padding inferior y evitar recorte de chips CRM sugeridos]
        F2_3 --> F2_4[Garantizar micro-animaciones suaves y manejo impecable de teclado]
    end

    subgraph FASE 3: Reestructuración de Perfil y Traslado de Tendencia Comercial
        F3_1[Eliminar ClientComplianceSparkline de ClientStatsHeader] --> F3_2[Compactar cabecera superior de ClientDetailScreen]
        F3_2 --> F3_3[Corregir título truncado del AppBar con FittedBox / fontSize]
        F3_3 --> F3_4[Integrar gráfico analítico completo e interactivo en ClientFullStatsModal]
    end

    subgraph FASE 4: Alerta de Cuotas Vencidas Responsiva con Memoria Inteligente
        F4_1[Rediseñar layout responsivo del banner de cuotas vencidas] --> F4_2[Construir Modo Expandido y Modo Retraído con AnimatedCrossFade]
        F4_2 --> F4_3[Implementar lógica de memoria en SharedPreferences: 7 días o nueva cuota]
        F4_3 --> F4_4[Conectar acción de plegado manual y auto-despliegue ante eventos]
    end

    subgraph FASE 5: Optimización de Pestañas, Blindaje Flotante y Testing
        F5_1[Ajustar TabBar para lectura completa sin mutilación de títulos] --> F5_2[Resolver colisiones de títulos y montos en las 3 pestañas]
        F5_2 --> F5_3[Establecer bottom padding seguro de 140px contra FABs y Dock]
        F5_3 --> F5_4[Desarrollar suite de pruebas automatizadas y certificar 0 regresiones]
    end

    FASE 1 --> FASE 2 --> FASE 3 --> FASE 4 --> FASE 5
```

---

## 🔬 4. ESPECIFICACIÓN TÉCNICA DETALLADA POR FASE

### FASE 1: Estandarización Monetaria y Pulido del Directorio de Clientes
- **Archivos a modificar/crear:**
  - `lib/core/utils/currency_formatter.dart` *(Nuevo helper estándar)*
  - `lib/features/smart_quotation/screens/crm/client_tracking_screen.dart`
  - `lib/features/smart_quotation/widgets/crm/client_filter_bar.dart`
  - `lib/features/smart_quotation/widgets/crm/client_card.dart`

1. **Helper `AppCurrency`:**
   ```dart
   class AppCurrency {
     static final NumberFormat _formatter = NumberFormat.currency(
       locale: 'es_PE',
       symbol: 'S/ ',
       customPattern: 'S/ #,##0.00',
     );
     static String format(double amount) => _formatter.format(amount);
   }
   ```
2. **Correcciones en `ClientTrackingScreen`:**
   - AppBar: Ajustar título a `FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text("Directorio de Clientes", ...))` con `fontSize: 20`.
   - Pluralización: `"${clients.length} ${clients.length == 1 ? 'cliente' : 'clientes'}"`.
   - Separación y respiración: Ajustar el `SliverAppBar` flotante y el `SliverPadding` de la lista a `padding: const EdgeInsets.only(top: 16, bottom: 120)` con una sutil línea divisoria o tarjeta elevada de ordenamiento para que la primera tarjeta nunca parezca asfixiada.
3. **Selector Modal en `ClientFilterBar`:**
   - Al tocar el chip de Confianza, desplegar un modal/sheet inferior limpio con las 5 opciones: `Todos los niveles`, `Excelente (Verde)`, `Bueno (Azul)`, `Regular (Naranja)`, `Moroso (Rojo)`, con checkmarks y conteo de clientes por nivel.
4. **Evolución de `ClientCard`:**
   - Uso obligatorio de `AppCurrency.format(client.totalDebt)`.
   - Si el cliente tiene cuotas vencidas, mostrar una píldora sutil `⚠️ Cuotas vencidas` con color `Colors.redAccent`.
   - Fila de contacto: Mostrar teléfono y DNI/RUC de manera limpia en una línea secundaria antes o debajo de las etiquetas CRM para no sacrificar el acceso al número.
   - Botonera inferior `Cobrar | WhatsApp | Llamar` con divisores elegantes y feedback háptico.

---

### FASE 2: Reingeniería Estructural y Micro-Animaciones del Modal Crear/Editar Cliente
- **Archivos a modificar:**
  - `lib/features/smart_quotation/widgets/crm/client_profile_editor.dart`

1. **Eliminación del Overlap de Etiquetas Flotantes:**
   - Modificar `_buildTextField` para usar una arquitectura de campo con label superior externo:
   ```dart
   Widget _buildFieldSection({
     required String label,
     required Widget child,
   }) {
     return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: labelColor)),
         const SizedBox(height: 6),
         child,
       ],
     );
   }
   ```
   - El `TextField` llevará `hintText` interno y `border` sin label flotante, erradicando al 100% el defecto visible en la captura donde el texto partía el borde del input.
2. **Habilitación de Nivel de Confianza en Modo Nuevo:**
   - Retirar la condición limitante `if (!widget.isNew)`. Al crear un cliente, el usuario podrá predefinir su nivel de confianza (por defecto `"bueno"` o elegir `"excelente"` si es referido/VIP).
3. **Blindaje de Altura y Recorte de Chips CRM:**
   - Envolver el formulario en un `LayoutBuilder` / `SafeArea` con `SingleChildScrollView(physics: const BouncingScrollPhysics())` y padding inferior dinámico:
     `EdgeInsets.only(left: 24, right: 24, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 90)`.
   - Garantizar que los chips sugeridos `+ VIP`, `+ Mayorista`, etc., tengan espacio completo y se añadan con micro-animación `AnimatedCrossFade`.

---

### FASE 3: Reestructuración del Perfil y Traslado de "Tendencia Comercial" a "Ver Analítica"
- **Archivos a modificar:**
  - `lib/features/smart_quotation/screens/crm/client_detail_screen.dart`
  - `lib/features/smart_quotation/widgets/crm/client_stats_header.dart`
  - `lib/features/smart_quotation/widgets/crm/client_compliance_sparkline.dart`
  - `lib/features/smart_quotation/widgets/crm/client_full_stats_modal.dart`

1. **Retiro de Tendencia Comercial de la Cabecera:**
   - Extraer `ClientComplianceSparkline` de `client_stats_header.dart`.
   - Compactar la cabecera: Avatar, Nombre, Teléfono formateado, botones redondos de WhatsApp y Llamada, Badge de Confianza y botón `"Ver Analítica"`, seguidos de las etiquetas CRM y la fila de accesos (`Caja Rápida`, `Cotizar`, `Finanzas`).
   - Ajustar el AppBar de `client_detail_screen.dart` para evitar `"Perfil del Clie..."` mediante `FittedBox` y fuente elástica (20px -> 18px si es necesario).
2. **Elevación e Integración en `ClientFullStatsModal` ("Ver Analítica"):**
   - Mudar y repotenciar el gráfico comercial dentro del modal analítico:
     - Mostrar una gráfica interactiva de área/barras que responda a los filtros de tiempo (`Todo`, `6 Meses`, `Mes`, `Semana`, `Rango`).
     - Basado en `_filteredSales`: montos reales por fecha, puntos interactivos con tooltip del comprobante, comparativa visual de Compras vs Pagos y ticket promedio dinámico.
     - Indicadores de tendencia comercial calculados con matemática real (tasa de cumplimiento, frecuencia media de compra en días).

---

### FASE 4: Alerta Responsiva de "Cuotas Vencidas" con Doble Modo y Memoria Inteligente
- **Archivos a modificar:**
  - `lib/features/smart_quotation/widgets/crm/client_stats_header.dart`

1. **Rediseño Responsivo del Contenedor de Alerta:**
   - Diseñar el layout con distribución flexible:
     - Izquierda: Icono `warning_amber_rounded` en caja de acento + columna con `Text("⚠️ $overdueCount cuotas vencidas")` y `Text("Atraso máx: $maxDaysOverdue días")`.
     - Derecha: Botón verde `"Recordar"` compacto + Botón icono sutil de repliegue (`keyboard_arrow_up` o `close`).
2. **Doble Modo con `AnimatedCrossFade`:**
   - **Modo Expandido:** Tarjeta completa con detalles, botón "Recordar" y botón de contraer.
   - **Modo Retraído:** Píldora compacta (`height: 34px`) con borde rojo/ámbar:
     `Row(children: [Icon(Icons.warning, size: 16), Text("⚠️ 5 cuotas vencidas"), Spacer(), TextButton("Ver")]),` ocupando espacio vertical mínimo sin estorbar las pestañas.
3. **Algoritmo de Memoria Inteligente (`SharedPreferences`):**
   - Claves:
     - `crm_overdue_folded_ts_${client.id}` (timestamp en milisegundos).
     - `crm_overdue_folded_count_${client.id}` (conteo de cuotas al momento del plegado).
   - Lógica de evaluación en `initState` / `didUpdateWidget`:
     ```dart
     final prefs = await SharedPreferences.getInstance();
     final foldedTs = prefs.getInt('crm_overdue_folded_ts_${widget.client.id}');
     final foldedCount = prefs.getInt('crm_overdue_folded_count_${widget.client.id}') ?? 0;
     
     final now = DateTime.now().millisecondsSinceEpoch;
     final sevenDaysMs = 7 * 24 * 60 * 60 * 1000;
     
     // Regla: Se expande si pasaron 7 días O si hay NUEVAS cuotas vencidas
     if (foldedTs == null || (now - foldedTs) > sevenDaysMs || currentOverdueCount > foldedCount) {
       _isFolded = false; // Desplegar automáticamente
     } else {
       _isFolded = true;  // Mantener plegado respetando la decisión del usuario
     }
     ```
   - Al pulsar el botón de contraer (o al enviar el recordatorio por WhatsApp): guardar `now` y `currentOverdueCount`, y conmutar a plegado con animación suave.

---

### FASE 5: Optimización de las 3 Pestañas, Blindaje Anti-Colisión Flotante y Suite de Pruebas
- **Archivos a modificar/crear:**
  - `lib/features/smart_quotation/screens/crm/client_detail_screen.dart`
  - `lib/features/smart_quotation/widgets/crm/client_sales_history_tab.dart`
  - `lib/features/smart_quotation/widgets/crm/ledger_timeline_tab.dart`
  - `lib/features/smart_quotation/widgets/crm/client_quotations_tab.dart`
  - `test/client_crm_part1_directory_profile_tabs_test.dart` *(Nueva suite de pruebas)*

1. **Optimización del `TabBar`:**
   - Modificar la delegación del persistent header para usar `isScrollable: false` con distribución balanceada, o si es scrollable, reducir `labelPadding` a `EdgeInsets.symmetric(horizontal: 12)` para que en pantallas de 360px los nombres se lean con claridad absoluta sin cortes toscos.
2. **Corrección de Tarjetas en `ClientSalesHistoryTab`:**
   - Envolver el título en `Expanded` con `maxLines: 1, overflow: TextOverflow.ellipsis` y asegurar `SizedBox(width: 8)` de separación fija contra el bloque derecho `Debe S/ 240.00`.
   - Utilizar `AppCurrency.format(...)` para que todos los montos de `Total`, `Pagado` y `Debe` mantengan paridad visual.
3. **Blindaje de Padding Inferior Seguro (140px):**
   - Actualizar el `padding` de los `ListView` en:
     - `LedgerTimelineTab`: `padding: EdgeInsets.only(top: 16, bottom: 140, left: 16, right: 16)`.
     - `ClientSalesHistoryTab`: `padding: EdgeInsets.fromLTRB(16, 16, 16, 140)`.
     - `ClientQuotationsTab`: `padding: EdgeInsets.fromLTRB(16, 16, 16, 140)`.
   - Con 140px de clearance, cualquier tarjeta o chip puede deslizarse completamente por encima del FAB `"Registrar Abono"`, del botón scroll-to-top `^` y de la burbuja flotante del Dock de Caja Rápida sin solapamiento destructivo.

---

## 🛡️ 5. PROTOCOLO DEL ÁRBITRO ADVERSARIAL

Para garantizar calidad de clase mundial y cero defectos visuales o de regresión, se establecen las siguientes reglas innegociables:

### Reglas Inviolables
1. **Regla de Cero Choques de Texto:** Ningún título de comprobante, badge de estado, número telefónico ni fecha puede colisionar con otro widget o desbordar la pantalla en anchos desde 320px hasta 430px.
2. **Regla de Formato Monetario Único:** Queda terminantemente prohibido usar `X,XX S/` o strings manuales. Todo valor monetario debe pasar por `AppCurrency.format(value)` produciendo `S/ #,##0.00`.
3. **Regla de Memoria de Alertas:** Si el usuario pliega manualmente la alerta de cuotas vencidas, el estado retraído debe persistir estrictamente durante 7 días a menos que el número de cuotas vencidas se incremente.
4. **Regla de Libertad Operativa en Pestañas:** Ningún botón flotante (`Registrar Abono`, `Scroll-to-top`, `DeepNavReturnPill`) puede tapar permanentemente la última tarjeta de las listas ni impedir su pulsación.
5. **Regla de Integridad de Compilación:** `flutter test` debe aprobar al 100% sin una sola advertencia ni falla de regresión.

### Gatillos de Falla y Reversión Inmediata
- Si algún label de `client_profile_editor.dart` corta visualmente el borde de un campo de texto.
- Si el título del AppBar en Directorio o Perfil muestra `"..."` en pantallas estándar.
- Si la alerta de cuotas vencidas colisiona con el botón "Recordar" en cualquier resolución.
- Si se rompe algún flujo contable existente en cobros, amortizaciones o creación de clientes.

### Matriz de Casos Borde Auditados
| Caso Borde | Comportamiento Esperado | Verificación |
| :--- | :--- | :--- |
| **0 Clientes Registrados** | Mensaje amigable `"0 clientes"`, ilustración limpia y botón de añadir visible. | Widget Test |
| **1 Cliente Registrado** | Texto exacto `"1 cliente"` en singular (sin `"1 clientes"`). | Widget Test |
| **Cliente con Nombre Extremo (50+ caracteres)** | Avatar con inicial correcta, nombre truncado con elipsis sin desplazar montos. | Widget Test |
| **Cliente sin Teléfono Registrado** | Botones WhatsApp y Llamar deshabilitados o con mensaje `"Sin teléfono"` sin crashear. | Unit/Widget Test |
| **Alerta con 1 Cuota Vencida** | Texto `"⚠️ 1 cuota vencida"` (singular gramatical). | Logic Test |
| **Alerta Plegada + Nueva Cuota Vencida al día siguiente** | Auto-expansión instantánea al detectar incremento de cuotas vencidas. | SharedPreferences Test |
| **Alerta Plegada + 8 Días Transcurridos** | Auto-expansión por vencimiento de la ventana de 7 días. | Mock Clock Test |
| **Teclado Abierto en Formulario** | Todos los campos accesibles con scroll fluido sin `Bottom Overflowed by X pixels`. | Flutter Driver / UI Layout |
| **Tema Claro vs Tema Oscuro** | Contraste perfecto en badges, chips, campos y bordes en ambos modos. | Visual Review |

---

## 🧪 6. ESTRATEGIA DE TESTING Y CERTIFICACIÓN AUTOMATIZADA

Se creará una suite de pruebas completa en:  
`app_movil/test/client_crm_part1_directory_profile_tabs_test.dart`

### Baterías de Prueba Incluidas:
1. **Pruebas de Formato Monetario (`AppCurrency`):**
   - Validación de prefijo `S/ `, separador de miles `,` y decimales `.` en enteros, decimales y ceros (`S/ 0.00`, `S/ 1.00`, `S/ 258.57`, `S/ 1,240.00`).
2. **Pruebas de Pluralización en Directorio:**
   - Validación gramatical: 0 clientes, 1 cliente, 2 clientes, 15 clientes.
3. **Pruebas de Lógica de Memoria de Alerta (7 Días / Nueva Cuota):**
   - Prueba con `SharedPreferences.setMockInitialValues(...)`:
     - Plegar alerta con 5 cuotas -> permanece plegada a los 3 días si siguen siendo 5 cuotas.
     - Plegar alerta con 5 cuotas -> se despliega al día siguiente si ahora son 6 cuotas vencidas.
     - Plegar alerta con 5 cuotas -> se despliega automáticamente tras 8 días aunque sigan siendo 5 cuotas.
4. **Pruebas de Estructura de Widgets:**
   - Verificación de que `ClientProfileEditor` contiene etiquetas fijas superiores no superpuestas.
   - Verificación de que `ClientStatsHeader` no contiene `ClientComplianceSparkline` y su altura se redujo.
   - Verificación de que `ClientFullStatsModal` contiene la analítica de tendencia y comparativa.
   - Verificación de que los `ListView` de las 3 pestañas poseen padding inferior seguro `>= 140px`.
