# 📋 Plan de Corrección y Diagnóstico: Flujo de Ventas e Intereses

Este documento detalla el diagnóstico técnico de los problemas reportados y el plan de acción estructurado para resolverlos de manera segura.

## 1. Análisis del Bloqueo (Bug Crítico 1 - Frontend UI)
**Síntoma:** Tras finalizar una venta, el backend guarda todo, pero la pantalla se "congela" y nunca muestra el modal de *Venta Exitosa*.
**Diagnóstico (Raíz del Problema):**
En el archivo `checkout_progress_dialog.dart`, la secuencia de operaciones asíncronas es incorrecta. Actualmente, el diálogo de carga se cierra a sí mismo (`Navigator.pop(context)`) **antes** de hacer un llamado asíncrono a la base de datos (`await getQuotationById`). 
Debido a que el widget fue desmontado (`unmounted`) por el `pop`, cuando Dart intenta acceder a las propiedades `widget.quotation` o `widget.parentContext` para mostrar el modal de éxito, se dispara una excepción interna de Flutter (*Cannot access widget of an unmounted State*). 
Al caer en el bloque `catch (e)`, el código verifica `if (mounted)`, el cual evalúa a `false`, provocando que el error sea **tragado en silencio**. El modal de éxito jamás se invoca y el usuario queda atrapado en un estado intermedio.

## 2. Mapeo de Componentes (Bugs 2 y 3 - Intereses y Estadísticas)
**Síntoma:** El detalle de venta, historial y estadísticas (Analytics) muestran el total sin incluir el recargo por interés.
**Diagnóstico (Raíz del Problema):**
En `checkout_action_footer.dart`, el recargo por interés (`interestSurcharge`) se calcula correctamente para el BottomSheet de resumen visual. Sin embargo, al momento de disparar el guardado (`_submitSale`), se pasa la variable `finalTotal` (que es solo subtotal menos descuento), **omitiendo sumar el interés**. 
Como resultado, el backend (`sales_service.dart`) guarda en SQLite el campo `monto_total` sin los intereses.
Dado que los Dashboards de Analytics y el Historial de Ventas consultan directamente mediante SQL (ej. `SUM(monto_total)`), todos heredan este error matemático por defecto.

**Componentes que se arreglarán indirectamente con este fix:**
- `checkout_action_footer.dart` (Origen del problema).
- `analytics_provider.dart` (Métricas y reportes financieros).
- `sale_history_detail_screen.dart` (Visualización de detalle).
- `sales_list_builder.dart` (Tarjetas de historial).
- `success_checkout_modal.dart` (Modal de éxito).

---

## 3. Plan de Trabajo Estructurado

### Paso 1: Resolver el Bloqueo del Modal de Éxito
- **Archivo a editar:** `lib/features/smart_quotation/widgets/checkout/checkout_progress_dialog.dart`
- **Acción:** Reordenar la lógica. El `Navigator.pop(context)` se trasladará para que se ejecute de manera **síncrona** justo antes de invocar `showGeneralDialog`, asegurando que todas las operaciones `await` (como obtener la cotización) sucedan mientras el diálogo de carga sigue vivo y `mounted`.

### Paso 2: Corregir Propagación del Total con Intereses
- **Archivo a editar:** `lib/features/smart_quotation/widgets/checkout/checkout_action_footer.dart`
- **Acción:** Modificar el callback del botón "Confirmar Venta" para que el parámetro `total` inyectado a `_submitSale` sea `finalTotal + interestSurcharge` en lugar de solo `finalTotal`.

### Paso 3: Verificación de Impacto
- **Acción:** Validar de forma estática que `sales_service.dart` esté calculando correctamente la deuda y las cuotas basándose en este nuevo `monto_total`. Dado que las cuotas ya validaban cuadrar con la deuda total, este cambio estabilizará toda la base de datos para ventas a crédito desde este punto en adelante, haciendo que el Dashboard de Analytics sea matemáticamente perfecto de forma automática.

> **Nota para el Usuario:** Quedo a la espera de tu aprobación sobre este plan de diagnóstico. Una vez des el "visto bueno", iniciaré con la escritura de código en los archivos mencionados.
