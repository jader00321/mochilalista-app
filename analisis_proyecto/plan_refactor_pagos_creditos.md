# Plan de Refactorización Integral: Pagos, Créditos y Logística

## 1. Análisis del Problema y Diagnóstico Profundo

Al someter el módulo a un análisis exhaustivo que incluye todas las interacciones posibles del usuario, se identifican las siguientes vulnerabilidades críticas:

### A. Desfases Complejos (Descuentos, Intereses y Cuotas Manuales)
- **Situación:** En `payment_config_card.dart`, el usuario puede agregar un porcentaje de interés que aumenta la deuda base, y también puede editar manualmente el valor individual de cada cuota.
- **El Bug:** Si el usuario realiza toda la configuración (con intereses y montos de cuotas personalizados) y *luego* retrocede para cambiar el Descuento Global o modificar el Abono Inicial, el sistema no fuerza un recálculo obligatorio. Al presionar "Vender", la aplicación guarda la venta original pero conserva la lista de cuotas desfasadas.
- **Consecuencia:** La base de datos registra una Venta con un saldo X, pero las cuotas registradas suman un saldo Y, generando incongruencias catastróficas al intentar cobrar posteriormente. Además, el porcentaje de interés no se está persistiendo aisladamente en la venta, lo que dificulta la auditoría financiera.

### B. Sobrescritura Destructiva del Abono Inicial
- **Situación:** En `client_service.dart`, la función de sincronización de pagos actualiza el `monto_pagado` de una venta sumando **exclusivamente** el `monto_pagado` de cada cuota.
- **Consecuencia:** El Abono Inicial (que se da al instante de la venta y no forma parte de las "cuotas") es aniquilado y sobrescrito. La venta aparenta tener una deuda mayor a la real y se pierde el historial financiero del abono inicial.

### C. Falla en el Sistema de Entregas (Logística)
- **Situación:** Cuando se crea una venta con estado distinto a "entregado", el sistema suma `+1` al contador `entregas_pendientes` del Cliente.
- **El Bug:** En `sales_service.dart`, el método `updateDeliveryStatus` actualiza el estado de la venta a "entregado" (desde el modal de detalles de venta), **pero jamás actualiza ni resta el contador en la tabla del Cliente**.
- **Consecuencia:** Los clientes acumulan `entregas_pendientes` fantasmas de forma irreversible, mostrando datos erróneos en el CRM y en la interfaz general.

---

## 2. Propuesta de Arquitectura de Base de Datos

Para que el sistema sea inteligente, robusto y preparado para cualquier escenario futuro, proponemos las siguientes modificaciones a la tabla `ventas` en SQLite (`local_db.dart`):

**Nuevas Columnas a Añadir:**
1. `abono_inicial REAL DEFAULT 0.0`
2. `porcentaje_interes REAL DEFAULT 0.0`

**Lógica Matemática Inquebrantable:**
- `Deuda Real = (Monto Total - Abono Inicial) * (1 + (Porcentaje Interes / 100))`
- Al sincronizar pagos: `Monto Pagado Total = Abono Inicial + SUMA(cuotas.monto_pagado)`
Esto asegura que ni el abono inicial ni los intereses queden "al aire" y siempre puedan recalcularse de forma exacta.

---

## 3. Flujo del Validador Inteligente (Auto-Fix UI)

El botón "Vender" en `sales_checkout_screen.dart` contará con un "Guard Clause" financiero que blindará la base de datos contra inconsistencias.

**Algoritmo del Validador Pre-Venta:**
1. Si el pago es "Crédito":
2. El sistema captura las variables actuales de la UI: `Total Venta`, `Abono Inicial (paid)`, `Interés (%)`.
3. Calcula: `Deuda Exacta = (Total Venta - Abono Inicial) * (1 + (Interés / 100))`
4. Calcula: `Suma Cuotas Ingresadas = SUMA(cuota.monto)`
5. **Evaluación Estricta:** Si `abs(Deuda Exacta - Suma Cuotas Ingresadas) > 0.01`:
   - **Bloqueo Activo:** Se detiene el guardado y se abre un Modal de Alerta Crítica.
   - **Diagnóstico Visual:** El modal explicará que los valores de las cuotas no coinciden con los últimos descuentos o abonos aplicados.
   - **Auto-Fix (Recalcular):** Se presentará un botón primario "Solucionar Automáticamente". Al presionarlo, el sistema redistribuirá la `Deuda Exacta` entre el número de cuotas actuales, cerrará el modal y permitirá continuar con la venta asegurando perfección matemática.

---

## 4. Sugerencias y Mejoras Adicionales

- **Interfaz de Finanzas (`sale_financial_detail_screen.dart`):** Añadiremos un "chip" visual o una fila informativa que muestre el `porcentaje_interes` explícitamente (ej. "Interés aplicado: 5.0%"). Si es `0.0`, se ocultará para mantener un diseño limpio.
- **Recálculo Logístico (`recalculateClientDeliveries`):** Al igual que existe un método para recalcular la deuda del cliente desde cero sumando todas sus ventas, crearemos uno para recalcular sus entregas. Así, al cambiar el estado de entrega a "Entregado", el sistema hará un conteo real en SQLite y actualizará el perfil del cliente asegurando cero desfases.

---

## 5. Plan de Trabajo Detallado Expandido

1. **FASE 1: Migración de Base de Datos**
   - Modificar `local_db.dart` añadiendo `abono_inicial` y `porcentaje_interes` al esquema de `ventas`.
   - Incluir los `ALTER TABLE` necesarios en la lógica de actualización para evitar borrar bases de datos existentes.

2. **FASE 2: Inyección de Datos y Modelos**
   - Actualizar `SaleModel` en `crm_models.dart` para parsear y guardar `abonoInicial` y `porcentajeInteres`.
   - Modificar `sales_service.dart` (`createSale`) para extraer estos datos de `saleData` e inyectarlos correctamente en SQLite, separando el concepto del pago inicial.

3. **FASE 3: Sincronización Blindada de Pagos**
   - En `client_service.dart`, modificar el recálculo `vNewPagadoCents`. Sumar el `abono_inicial` al total de cuotas pagadas, preservando permanentemente este valor histórico.

4. **FASE 4: Validador Pre-Venta (Inteligencia en UI)**
   - Implementar el algoritmo de validación en `sales_checkout_screen.dart`.
   - Crear el `AlertDialog` de Incongruencia con su lógica de Auto-Fix que recalcula distribuyendo los montos, soportando decimales y ajustes de centavos en la última cuota.

5. **FASE 5: Interfaz Financiera (Transparencia)**
   - Modificar `sale_financial_detail_screen.dart` para leer `porcentajeInteres`. Mostrar un indicador elegante de "Sobrecargo por Interés" dentro de la tarjeta de resumen financiero.

6. **FASE 6: Refactorización de Logística (Bug de Entregas)**
   - En `client_service.dart`, crear `recalculateClientDeliveries(int clientId)`.
   - Modificar `sales_service.dart` (`updateDeliveryStatus`) para que dispare esta función tras cada cambio de estado, solucionando las entregas fantasma.
