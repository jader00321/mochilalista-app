# Análisis y Plan de Trabajo: Mejoras en Créditos y Notificaciones (Versión 2.3)

Este plan aborda las inconsistencias al vender a crédito con descuentos globales/adelantos, y el rediseño integral del sistema de notificaciones.

## Análisis de los Problemas

### 1. Inconsistencias en el Cálculo de Cuotas (Caja y Cierre)
- **Problema de origen:** Cuando el usuario aplica un "Descuento Extra" en la vista principal (`CheckoutSummaryCard`), el `totalToPay` cambia y se pasa a `PaymentConfigCard`, pero este componente no está escuchando (`didUpdateWidget`) ese cambio para recalcular las cuotas (`_installments`). Lo mismo sucede cuando el usuario ingresa un adelanto: la deuda base disminuye, pero las cuotas no se regeneran a menos que el usuario presione explícitamente "Generar Cronograma".
- **Impacto:** Permite finalizar ventas donde la suma de las cuotas + adelantos no coincide con la deuda final real tras los descuentos.
- **Solución Propuesta:** 
  1. Implementar `didUpdateWidget` en `PaymentConfigCard`. Si `totalAmount` cambia y ya existen cuotas generadas, se recalculará automáticamente el cronograma conservando la fecha de vencimiento configurada.
  2. Implementar un retardo (debounce) en el `_amountPaidCtrl` de manera que si el usuario escribe un nuevo adelanto, el cronograma se regenere automáticamente a los 500ms para cuadrar la deuda, evitando que envíen datos inconsistentes.
  3. Deshabilitar el botón "COBRAR" si la suma total de las cuotas + el pago inicial es diferente a la deuda final (para brindar seguridad estricta al flujo de caja).

### 2. Modernización del Sistema de Notificaciones
- **Problemas Actuales:** Diseño básico; la notificación de cuota vencida muestra un texto estático ("El cliente X tiene la cuota..."); no se diferencian notificaciones activas de las ya resueltas (lo que genera un historial desorganizado); faltan notificaciones de éxito (ej. Cuota Pagada).
- **Impacto:** Dificulta el control y seguimiento por parte del negocio.
- **Soluciones Propuestas:**
  1. **Rediseño de la Vista:** `NotificationsScreen` se renovará con filtros ("Todas", "Pendientes", "Resueltas") mediante `ChoiceChips`.
  2. **Historial de Notificaciones Resueltas:** Se añadirá una bandera booleana temporal (o visual) para clasificar las alertas. Como no se puede modificar fácilmente la base de datos sin una migración estricta, utilizaremos el campo `isRead` o añadiremos un estado lógico derivado: si la alerta es de `cuota_vencida`, el sistema consultará en vivo si la cuota ya fue pagada. Si fue pagada, la alerta se categorizará como "Resuelta".
  3. **Modal Dinámico de Cuota Vencida:** En lugar de abrir un modal genérico, se creará un `showModalBottomSheet` rico en información que consultará en vivo los datos del cliente y de la cuota usando `SalesService`. Mostrará el estado real de la deuda y tendrá un botón directo "Ver Perfil del Cliente".
  4. **Nuevas Notificaciones:** Se agregará lógica para disparar una notificación de éxito ("Cuota Pagada") al momento de registrar el pago en el sistema.

---

## User Review Required

Por favor, revisa este análisis. ¿Estás de acuerdo con el enfoque de bloquear el botón "COBRAR" si el usuario modificó manualmente las cuotas y los números no cuadran con la deuda total, obligándolo a recalcular el cronograma?

## Proposed Changes

### [Caja y Cierre - Créditos]

#### [MODIFY] [payment_config_card.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/checkout/payment_config_card.dart)
- Agregar `didUpdateWidget` para detectar cambios en `totalAmount` y recalcular `_installments`.
- Automatizar la llamada a `_generateInstallments` con un debouncer en el listener de `_amountPaidCtrl`.
- Exponer el total sumado de cuotas para que la vista padre lo valide.

#### [MODIFY] [sales_checkout_screen.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/sales_checkout_screen.dart)
- Agregar validación en el botón "COBRAR" para que solo esté habilitado si `(_paidAmount + suma_de_cuotas) == totalToPay`.

### [Sistema de Notificaciones]

#### [MODIFY] [notifications_screen.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/profile/screens/notifications_screen.dart)
- Rediseñar UI con pestañas/chips: "Pendientes", "Resueltas".
- Implementar `_showCuotaVencidaModal` con interfaz dinámica y botón de redirección al cliente.
- Resolver el estado "Resuelto" verificando si el texto incluye "vencida" pero la cuota ya está pagada.

#### [MODIFY] [notification_provider.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/providers/notification_provider.dart)
- Implementar lógica auxiliar para separar y gestionar las notificaciones resueltas.

#### [MODIFY] [sales_service.dart](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/sales_service.dart)
- Agregar método `getCuotaConCliente(int cuotaId)` para traer los detalles vivos de la cuota a usar en el modal.

## Verification Plan

### Automated Tests
- Ninguna, pero se compilará con `flutter analyze` y se verificará el árbol de widgets.

### Manual Verification
1. Hacer una venta, darle a crédito, luego ingresar un "Descuento Extra". Confirmar que las cuotas se recalculan.
2. Escribir un adelanto de 50 soles. Confirmar que el cronograma ajusta sus montos dinámicamente.
3. Forzar una cuota vencida (cambiando fecha) o usar una existente, abrir la pestaña de notificaciones, presionar la notificación y validar que se abra el modal dinámico con botón para ir al perfil.
