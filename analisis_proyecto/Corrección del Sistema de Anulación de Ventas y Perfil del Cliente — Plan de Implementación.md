# Corrección del Sistema de Anulación de Ventas y Perfil del Cliente — Plan de Implementación

## Descripción del Problema

He analizado a fondo todo el flujo de anulación de ventas usando las capturas proporcionadas y el código fuente. Identifiqué **3 problemas principales**, uno de los cuales es una vulnerabilidad financiera crítica:

---

## 🔬 Análisis Profundo del Sistema de Anulación

### Lo que el sistema hace CORRECTAMENTE hoy:

1. ✅ **Deuda del cliente**: `recalculateClientDebt()` usa `WHERE is_archived = 0`, por lo que al anular una venta, la deuda pendiente de esa venta **ya se elimina correctamente** del cálculo de deuda global.
2. ✅ **Stock**: El stock de los productos se devuelve correctamente al inventario dentro de la transacción.
3. ✅ **Entregas pendientes**: Se resta correctamente del contador del cliente.
4. ✅ **Cotización**: Se marca como `ANNULLED` para que no aparezca en el Workbench.
5. ✅ **Ledger (Estado de Cuenta)**: La consulta `getClientLedger()` filtra ventas con `WHERE is_archived = 0`, por lo que **los cargos de ventas anuladas ya se excluyen** del timeline.

### Lo que el sistema hace INCORRECTAMENTE:

#### 🔴 Problema Crítico: Saldo a Favor huérfano tras anulación

**Situación detectada en las capturas:**
- Una venta #69 de S/ 17,06 se realizó con el cliente "Luz Elena Navarro".
- El cliente pagó en 3 cuotas, y la última cuota generó un excedente de S/ 0,94 que se convirtió en "Saldo a Favor".
- Al anular la venta #69, el sistema:
  - ✅ Eliminó la deuda (correcto).
  - ✅ Excluyó el cargo de la venta del ledger (correcto).
  - ❌ **NO eliminó los pagos asociados a esa venta del ledger** → Los registros `pagos` siguen existiendo en la base de datos con `venta_id = 69`, y como el filtro de pagos en `getClientLedger()` usa `LEFT JOIN ventas v ON p.venta_id = v.id WHERE (v.is_archived IS NULL OR v.is_archived = 0)`, los pagos de la venta anulada **SÍ se filtran** del ledger.
  - ❌ **PERO** el pago de "Conversión a Saldo a favor" tiene `venta_id = NULL` (porque fue un excedente que no pertenece a ninguna venta), por lo que **pasa el filtro** `v.is_archived IS NULL` y se muestra en el ledger como un movimiento vigente con saldo a favor de S/ 0,94.

**El saldo a favor se queda "flotando" sin origen:**
La función `recalculateClientSaldoAFavor()` calcula:
```sql
SUM(CASE WHEN nota = 'Conversión a Saldo a favor' THEN monto ELSE 0 END) as total_a_favor
SUM(CASE WHEN metodo_pago = 'saldo_a_favor' AND (v.is_archived IS NULL OR v.is_archived = 0) THEN monto ELSE 0 END) as total_gastado
```
Esto significa que:
- La "conversión a saldo a favor" se cuenta **siempre** (no tiene filtro por `is_archived`).
- El "gasto del saldo" solo se cuenta en ventas activas.
- **Resultado**: Cuando se anula la venta que generó el excedente, el saldo a favor permanece como S/ 0,94 sin que haya una venta vigente que lo justifique.

### 🧠 Análisis de Todas las Situaciones Posibles

| Situación | ¿Qué pasa hoy? | ¿Qué debería pasar? |
|---|---|---|
| **Venta anulada con deuda pendiente** | ✅ La deuda se elimina correctamente | Correcto |
| **Venta anulada con pagos parciales (sin excedente)** | ⚠️ Los pagos quedan en la BD pero no se muestran en el ledger | El dinero que el cliente ya pagó de esa venta se debería **convertir en saldo a favor** (ese dinero ya fue cobrado y debería devolverse) |
| **Venta anulada con excedente convertido en saldo a favor** | ❌ El saldo queda huérfano | El saldo debe ser **recalculado** considerando que los pagos de la venta anulada se convierten en crédito |
| **El saldo a favor ya fue usado en otra venta** | ⚠️ `recalculateClientSaldoAFavor()` lo descuenta, pero no vincula con el origen del saldo | Se debe recalcular neto: (todo lo que generó saldo) - (todo lo que gastó en ventas activas) |
| **Venta anulada es la 3ra de 20 ventas** | ✅ Las demás ventas no se afectan (cada venta tiene sus propios pagos y cuotas) | Correcto — cada venta es independiente en el sistema de cuotas |
| **Venta anulada usó saldo a favor para pagar parte de su deuda** | ⚠️ El pago con `metodo_pago = 'saldo_a_favor'` se vincula a la venta con `venta_id`, y al anularla, el filtro lo excluye del "total_gastado" en `recalculateClientSaldoAFavor()` — esto **devuelve el saldo automáticamente** | ✅ Correcto, pero solo funciona bien si se ejecuta `recalculateClientSaldoAFavor()` después de la anulación (y sí se ejecuta) |

### Solución Propuesta para el Saldo a Favor

La lógica de `recalculateClientSaldoAFavor()` necesita una corrección. El cálculo actual considera **todas las "Conversiones a Saldo a favor"** incluyendo las que vienen de ventas anuladas. La solución correcta es:

**Al anular una venta:**
1. Todos los pagos de esa venta (cuotas pagadas) representan dinero real que el cliente ya entregó.
2. Si la venta se anula, ese dinero cobrado se convierte automáticamente en **crédito del cliente** (saldo a favor).
3. Debemos recalcular el saldo como: `(Total pagado en ventas anuladas) + (Excedentes de ventas activas) - (Pagos con saldo_a_favor en ventas activas)`.

Esto se puede simplificar modificando `recalculateClientSaldoAFavor()` para que:

```sql
-- Total que generó saldo a favor (excedentes)
SUM(CASE WHEN nota = 'Conversión a Saldo a favor' THEN monto ELSE 0 END) as excedentes,
-- Total pagado en ventas anuladas (dinero que debe devolverse como crédito)
SUM(CASE WHEN v.is_archived = 1 AND nota IS NULL AND metodo_pago != 'saldo_a_favor' THEN monto ELSE 0 END) as refund_from_voided,
-- Total gastado como saldo en ventas activas
SUM(CASE WHEN metodo_pago = 'saldo_a_favor' AND (v.is_archived IS NULL OR v.is_archived = 0) THEN monto ELSE 0 END) as gastado

-- Saldo = excedentes + refund_from_voided - gastado
```

> [!IMPORTANT]
> **Decisión clave**: Esta corrección implica que al anular una venta **completamente pagada** (como la venta #69 de S/ 17,06), el cliente acumulará S/ 17,06 de saldo a favor (los S/ 16,12 de cuotas pagadas + los S/ 0,94 de excedente). Esto es financieramente correcto: el dinero ya fue cobrado y debe devolverse como crédito al cliente. ¿Estás de acuerdo con esta lógica?

---

## Problema 2: Botón "Ver Analítica" Duplicado

### Análisis
En [`client_stats_header.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/crm/client_stats_header.dart), el método `build()` (línea 24-31) llama a:
1. `_buildProfileHeader(context)` → que en la línea 80 ya llama a `_buildFullStatsButton(context)` dentro de un `Row` junto al badge de confianza.
2. `_buildFullStatsButton(context)` → que se llama **otra vez** como un hijo directo de la `Column` en `build()` (línea 28).

Resultado: **el botón se renderiza 2 veces**. El segundo aparece debajo del botón "Ir a Caja Rápida".

### Solución
Eliminar la llamada duplicada de `_buildFullStatsButton(context)` en el método `build()` (línea 28), dejando únicamente la que está dentro del `Row` del header (línea 80).

---

## Problema 3: Botones sin feedback interactivo

### Análisis
En el header del perfil del cliente, los botones de acción (WhatsApp, Llamar, badge de confianza, "Ver Analítica") carecen de indicadores visuales claros que comuniquen que son interactivos. El botón `_buildSmallActionButton` (WhatsApp/Llamar) usa un `InkWell` pero con un `Container` que no tiene estados visuales de `splash` o `highlight`. El botón "Ver Analítica" usa `TextButton` que sí tiene ripple nativo, pero el color semi-transparente lo hace lucir como una etiqueta pasiva.

### Cambios Propuestos
1. **Botones de WhatsApp y Llamar**: Agregar una animación de escala (`_AnimatedActionButton`) que haga un "bounce" al ser presionados.
2. **Botón "Ver Analítica"**: Agregar un icono de chevron/flecha que indique que es accionable, y aplicar una animación sutil de pulso (`pulse`) intermitente para atraer la atención del usuario la primera vez que entra al perfil.
3. **Botón "Ir a Caja Rápida"**: Ya tiene buen feedback nativo del `ElevatedButton`, pero agregar un efecto de escala al presionar para coherencia visual.

---

## Fases de Implementación

### Fase 1: Corrección del Saldo a Favor tras Anulación
**Archivo**: [`client_service.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/client_service.dart)
- Modificar `recalculateClientSaldoAFavor()` para considerar los pagos de ventas anuladas como crédito devuelto.
- Filtrar los excedentes ("Conversión a Saldo a favor") que provienen de ventas anuladas para evitar doble conteo.

### Fase 2: Limpieza del Ledger tras Anulación
**Archivo**: [`client_service.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/client_service.dart)
- Modificar `getClientLedger()` para que los pagos cuyo `venta_id` apunta a una venta anulada **no aparezcan en el timeline como movimientos regulares**, sino que se reemplacen por un único registro consolidado de "Devolución por anulación de Venta #X".
- Mantener el "Saldo a Favor" resultante visible cuando sea > 0.

### Fase 3: Eliminación del Botón Duplicado
**Archivo**: [`client_stats_header.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/crm/client_stats_header.dart)
- Eliminar la línea 28 (`_buildFullStatsButton(context)`) del método `build()`.

### Fase 4: Mejora de Interactividad de Botones
**Archivo**: [`client_stats_header.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/crm/client_stats_header.dart)
- Crear un widget `_AnimatedActionButton` con efecto de escala al presionar.
- Agregar un ícono de flecha al botón "Ver Analítica" para indicar que es accionable.
- Convertir el `ClientStatsHeader` en `StatefulWidget` para manejar las animaciones.

---

## Verificación

### Verificación Automatizada
- Ejecutar `flutter analyze` para confirmar cero errores.

### Verificación Manual
1. **Flujo de anulación completo**: Crear una venta con cuotas → Pagar todas las cuotas con excedente → Anular la venta → Verificar que el saldo a favor refleje el total pagado (cuotas + excedente).
2. **Ledger**: Verificar que al anular una venta, el Estado de Cuenta muestre un registro consolidado de devolución en lugar de los pagos individuales huérfanos.
3. **Botón duplicado**: Verificar que solo aparece un botón "Ver Analítica" en el perfil.
4. **Botones interactivos**: Verificar el feedback visual al presionar cada botón.

---

## Open Questions

> [!IMPORTANT]
> **Sobre la conversión del dinero cobrado en saldo a favor**: Cuando se anula una venta que ya fue completamente pagada (ej: S/ 17,06), el sistema calculará S/ 17,06 de saldo a favor para el cliente. Esto es correcto financieramente (el dinero ya fue cobrado y debe devolverse como crédito), pero ¿prefieres que el sistema genere un registro explícito de "Devolución" en el ledger, o que simplemente recalcule el saldo a favor sin crear un registro nuevo?

> [!WARNING]
> **Sobre las "Conversiones a Saldo a favor" existentes**: Los registros de "Conversión a Saldo a favor" que ya existen en la BD (como el de S/ 0,94 en las capturas) **no se eliminarán**. La nueva lógica simplemente los incluirá dentro del recálculo global. Si un usuario ve el ledger de una venta ya anulada, verá un registro consolidado de devolución que incluye ese monto.

