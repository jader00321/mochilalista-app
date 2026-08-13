# 📊 Plan de Trabajo: Correcciones Financieras y Mejoras de Exportación (PDF y WhatsApp)

## 1. Auditoría Matemática y Correcciones

He analizado el código fuente de la aplicación, específicamente `pdf_generator.dart` y `whatsapp_preview_screen.dart`, y he identificado la causa de los bugs mencionados:

### Bug en PDF: "Subtotal muestra el Total"
**Causa:**
En `pdf_generator.dart`, la variable `finalTotal` obtiene el `monto_total` de la base de datos (que **ya incluye** el interés aplicado). Luego se calcula exitosamente el valor del interés retroactivamente (`interestVal`). Sin embargo, la variable `baseTotalBeforeInterest` se inicializa como igual a `finalTotal` y nunca se le resta el interés calculado. 
Como resultado, la fila "Subtotal" imprime el total final con interés, confundiendo al cliente.
**Solución:**
Actualizar la lógica para que el Subtotal sea la resta del total final menos el interés calculado:
`double baseTotalBeforeInterest = finalTotal - interestVal;`

### Bug en WhatsApp: "Interés Duplicado"
**Causa:**
En `whatsapp_preview_screen.dart`, el código obtiene el `finalTotal` (que repetimos, ya tiene el interés desde la BD). Sin embargo, luego calcula nuevamente el interés sobre la deuda restante y **se lo suma otra vez** a `finalTotal` (`finalTotal = finalTotal + (debt * (interest / 100));`), cobrando doble interés.
**Solución:**
Eliminar por completo la suma adicional de interés a `finalTotal` en la pantalla de previsualización de WhatsApp. El `monto_total` que viene de la base de datos ya es la fuente de la verdad absoluta.

---

## 2. Propuesta de Copywriting y Mejoras de Diseño (PDF y WhatsApp)

### Corrección de Diseño (PDF): Desbordamiento de Texto
El texto actual: `"Interés por cuotas generadas (X.X%):"` es demasiado largo para el contenedor de 240px reservado para los totales.
**Propuesta:**
Reducirlo a un formato más profesional y conciso: `"Interés por financiamiento (X.X%):"` o simplemente `"Interés (X.X%):"`.

### Nueva Función: Detalle de Cuotas

Para lograr esto, primero agregaremos una nueva variable booleana en los modelos de configuración (`showInstallmentDetails` en WhatsApp y `showInstallments` en PDF) para que puedan ser activados o desactivados desde la pestaña de "Personalizar".

#### A) En WhatsApp (Copywriting)
Se agregará una sección condicional cuando la venta sea a crédito y existan cuotas programadas. 
**Plantilla propuesta:**
```text
Hola *[Nombre del Cliente]* 👋,

¡Gracias por tu compra! Aquí tienes el detalle de tu estado financiero.

📚 *DETALLE DE PRODUCTOS:*
▪ Mochila Azul (x1) -> *S/ 80.00*
▪ Cartuchera (x2) -> *S/ 20.00*

💰 *IMPORTE TOTAL: S/ 100.00*
💳 *PAGADO: S/ 40.00*
⚠️ *SALDO PENDIENTE: S/ 60.00*

📅 *CRONOGRAMA DE PAGOS (2 Cuotas):*
▪ Cuota 1: S/ 30.00 (Vence: 12/08/2026) - ✅ PAGADO
▪ Cuota 2: S/ 30.00 (Vence: 12/09/2026) - ⏳ PENDIENTE

📍 *Visítanos en Mi Negocio*
```
*Mejora:* Se ha separado visualmente el total, lo pagado y la deuda pendiente, seguido del cronograma exacto para máxima claridad.

#### B) En el PDF (Diseño de Cuotas)
Se creará un nuevo bloque visual debajo (o adyacente, dependiendo del espacio) del "Detalle de Transacción". 
Se renderizará una lista compacta si hay cuotas disponibles:
```text
PLAN DE PAGOS (X Cuotas)
--------------------------------------
Cuota 1: S/ XX.XX | Vence: DD/MM/AAAA | [PAGADO]
Cuota 2: S/ XX.XX | Vence: DD/MM/AAAA | [PENDIENTE]
```
Se utilizarán colores semánticos (verde para pagado, rojo/naranja para pendiente) respetando el tema clásico o moderno del PDF.

---

## 3. Plan de Trabajo Paso a Paso

1. **Paso 1: Actualizar Modelos de Configuración:**
   - Modificar `pdf_config_model.dart` para incluir `showInstallments` (por defecto `true`).
   - Modificar `whatsapp_config_model.dart` para incluir `showInstallmentDetails` (por defecto `true`).
   - Asegurar que `fromJson` y `toJson` estén actualizados en ambos archivos para persistir las opciones.

2. **Paso 2: Actualizar la UI de Configuración (Personalizar):**
   - Modificar los widgets de configuración en pantalla (como `wa_config_section.dart` y el widget equivalente para PDF) para añadir un control (SwitchListTile o Checkbox) que permita al usuario activar o desactivar la vista de cuotas.

3. **Paso 3: Reparar Errores Matemáticos y Diseño en PDF:**
   - En `pdf_generator.dart`: Modificar el cálculo añadiendo `baseTotalBeforeInterest = finalTotal - interestVal`.
   - Reemplazar el texto "Interés por cuotas generadas..." por "Interés por financiamiento...".

4. **Paso 4: Implementar Visualización de Cuotas en PDF:**
   - En `pdf_generator.dart`, verificar si `saleData['cuotas']` no está vacío. Si existe y la configuración de mostrar cuotas está activa, inyectar un nuevo `pw.Widget` mostrando un resumen de los pagos, fechas de vencimiento (formateadas) y montos.

5. **Paso 5: Reparar Bug Matemático y Aplicar Copywriting en WhatsApp:**
   - En `whatsapp_preview_screen.dart`: Eliminar la redundante multiplicación y suma de interés a `finalTotal` (ya que el backend ya nos envía el `monto_total` completo con intereses).
   - Refactorizar la lógica del método `_regenerateMessage` para generar el texto de cuotas propuesto iterando por la lista de `_saleData!['cuotas']`, añadiendo símbolos para ayudar al entendimiento de pagos terminados o pendientes.

---
> **IMPORTANTE:** Por favor revisa este plan de diagnóstico. Si estás de acuerdo con la auditoría y la propuesta, confírmalo para empezar la ejecución técnica.
