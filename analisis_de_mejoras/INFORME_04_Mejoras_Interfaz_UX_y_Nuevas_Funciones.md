# 🎨 INFORME 4: Mejoras de Interfaz, UX y Nuevas Funciones

> **Objetivo:** Detallar mejoras específicas de interfaz, optimización de flujos existentes y nuevas herramientas basadas en el comportamiento real del usuario del BAZAR LUZAM.

---

# PARTE A: MEJORAS DE INTERFAZ Y UX

## A.1 🎯 Rediseño del Flujo de Onboarding (Primera Vez)

### Problema detectado:
El usuario creó el negocio con datos mínimos (sin RUC, sin logo, sin email, sin PIN). Esto sugiere que el flujo de onboarding no guía suficientemente al usuario a completar toda la información.

### Propuesta:
Convertir el onboarding en un **wizard de 4 pasos** con progreso visual:

```
Paso 1/4: 👤 Tus Datos
┌─────────────────────────────┐
│ Nombre: [Luz Navarro] ✅    │
│ Teléfono: [976644890] ✅    │
│ Email: [________] (opcional)│
│                             │
│ 🔐 ¿Proteger con PIN?      │
│    [Sí, crear PIN] [Después]│
└─────────────────────────────┘
              [Siguiente →]

Paso 2/4: 🏪 Tu Negocio
┌─────────────────────────────┐
│ Nombre: [BAZAR LUZAM] ✅    │
│ RUC: [__________] (11 díg.)│
│ Dirección: [Talara] ✅      │
│ 📷 Foto/Logo: [Subir]      │
│ Tipo: [○Bodega ○Librería   │
│        ○Bazar ○Otro]        │
└─────────────────────────────┘

Paso 3/4: 🏷️ Categorías Iniciales
┌─────────────────────────────┐
│ Selecciona las categorías   │
│ de productos que vendes:    │
│                             │
│ [✅] Abarrotes              │
│ [✅] Bebidas                │
│ [✅] Golosinas y Snacks     │
│ [✅] Cuidado Personal       │
│ [✅] Limpieza del Hogar     │
│ [  ] Útiles Escolares       │
│ [  ] Baterías/Electrónica   │
│ [+ Agregar personalizada]   │
└─────────────────────────────┘

Paso 4/4: 💰 Método de Pago
┌─────────────────────────────┐
│ ¿Cómo te pagan tus clientes?│
│ [✅] Yape                   │
│ [✅] Plin                   │
│ [  ] Efectivo               │
│ [  ] Transferencia          │
│ [  ] Tarjeta                │
│                             │
│ Moneda: [S/ Soles ▼]       │
└─────────────────────────────┘
              [🚀 ¡Empezar!]
```

---

## A.2 📋 Rediseño de la Pantalla del Catálogo

### Problema detectado:
87 productos en 1 sola categoría hacen difícil la navegación. El usuario necesita encontrar productos rápidamente para vender.

### Propuesta de mejoras:

#### A.2.1 Filtros rápidos por categoría (chips horizontales)
```
[Todos (87)] [Abarrotes (84)] [Sin categoría (3)]
```
Cuando se implementen las categorías sugeridas:
```
[Todos] [Lácteos 🥛] [Bebidas 🥤] [Golosinas 🍫] [Limpieza 🧴] [+ más]
```

#### A.2.2 Vista de cuadrícula con imagen placeholder
Cuando no hay imagen del producto, mostrar un placeholder generado con la inicial de la marca y un color basado en la categoría:
```
┌────────┐ ┌────────┐ ┌────────┐
│  [GL]  │ │  [PR]  │ │  [SC]  │
│ Gloria │ │ Primor │ │ S.Crls │
│ Yogurt │ │ Aceite │ │ Aloe V │
│ S/3.49 │ │ S/9.83 │ │ S/3.00 │
│ 📦 3   │ │ 📦 2   │ │ 📦 6   │
└────────┘ └────────┘ └────────┘
```

#### A.2.3 Indicadores visuales de estado
- 🟢 Stock OK (> alerta)
- 🟡 Stock bajo (= alerta)
- 🔴 Sin stock (= 0)
- 💰 Margen indicador (verde si > 20%, amarillo 10-20%, rojo < 10%)

---

## A.3 🧾 Rediseño del Historial de Facturas

### Problema detectado:
Las facturas manuales aparecen vacías en el historial.

### Propuesta de nuevo diseño:

```
┌──────────────────────────────────────┐
│ 📜 Historial de Compras              │
│ Total invertido: S/ 1,241.32         │
│ [Ago ▼] [Todos proveedores ▼] [🔍]  │
├──────────────────────────────────────┤
│                                      │
│ 📷 #19 · SODALES DISTRIB.           │
│ 29 Sep 2026 · S/ 34.32 · 3 items    │
│ [🏷️ Chin Chin Mix] [🏷️ Maxi Maní]  │
│ [🏷️ Maxi Toffee]                    │
│ ✅ Escaneada con IA                  │
│                                      │
│ ───────────────────────────────────  │
│                                      │
│ ✍️ #17 · CBC MARKET S.A.C.          │
│ 04 Sep 2026 · S/ 95.61 · 8 items    │
│ [🏷️ Gaseosa Piña] [🏷️ Gaseosa Fresa│
│ [🏷️ Agua c/gas] [🏷️ Gatorade] +4   │
│ 📝 Ingresada manualmente            │
│                                      │
│ ───────────────────────────────────  │
│                                      │
│ ⚠️ #2 · ATUQ DEX S.A.C.            │
│ 14 Ago 2024 · S/ 87.62 · 7 items    │
│ ⚠️ Fecha inusual (2024)             │
│                                      │
└──────────────────────────────────────┘
```

**Elementos clave del rediseño:**
1. **Íconos diferenciados**: 📷 para escaneadas, ✍️ para manuales
2. **Tags de productos**: Chips con los nombres de los productos de esa factura
3. **Advertencia visual**: Para fechas inusuales o datos inconsistentes
4. **Filtros**: Por mes y por proveedor
5. **Estadística de cabecera**: Total invertido visible

---

## A.4 💳 Rediseño de la Pantalla de Ventas/Cobros

### Problema detectado:
Solo 2 ventas en 52 días. El flujo de venta puede ser demasiado largo o confuso.

### Propuesta: Flujo de venta simplificado en 3 toques

```
TOQUE 1: Agregar productos
┌──────────────────────────────────┐
│ 🛒 Nueva Venta                   │
│ [🔍 Buscar producto...]          │
│                                  │
│ RECIENTES:                       │
│ Aceite Primor 900ml    [+ S/9.83]│
│ Galleta Vainilla       [+ S/0.50]│
│ Yogurt Gloria Fresa    [+ S/1.99]│
│                                  │
│ CARRITO (2 items):               │
│ 1x Aceite Primor        S/ 9.83  │
│ 2x Galleta Vainilla     S/ 1.00  │
│ ──────────────────────────────── │
│ TOTAL:                  S/ 10.83  │
└──────────────────────────────────┘
                    [Continuar →]

TOQUE 2: Seleccionar método y cliente
┌──────────────────────────────────┐
│ 💰 ¿Cómo paga?                   │
│ [💵 Efectivo] [📱 Yape] [🔄 Fiado]│
│                                  │
│ 👤 Cliente: (opcional)            │
│ [Sin cliente] [Freddy ▼] [+ Nuevo]│
└──────────────────────────────────┘
                    [Cobrar S/10.83]

TOQUE 3: Confirmación
┌──────────────────────────────────┐
│ ✅ ¡Venta registrada!            │
│ Ticket #3 · S/ 10.83            │
│                                  │
│ [📋 Ver ticket] [📤 Compartir]   │
│ [🛒 Nueva venta]                 │
└──────────────────────────────────┘
```

---

## A.5 📊 Pantalla de Producto Mejorada

### Problema detectado:
Los productos no tienen imágenes, descripciones ni códigos de barras.

### Propuesta de diseño mejorado:

```
┌──────────────────────────────────┐
│ ← Aceite Premium                 │
├──────────────────────────────────┤
│ ┌──────────┐                     │
│ │  [Foto]  │ Marca: Primor       │
│ │  📷 +    │ Categoría: Abarrotes│
│ └──────────┘ Código: 3101031     │
│                                  │
│ 📦 PRESENTACIONES                │
│ ┌────────────────────────────┐   │
│ │ 900ml                      │   │
│ │ Costo: S/ 8.76 → Venta: S/10.94│
│ │ Stock: 2 ⚠️ (alerta: 5)   │   │
│ │ Margen: 25% 🟢             │   │
│ │ Proveedor: ATUQ DEX       │   │
│ │ Última compra: 21 Ago      │   │
│ └────────────────────────────┘   │
│                                  │
│ 📈 HISTORIAL                     │
│ • 21 Ago: Compra 2 und (Fact #2) │
│ • No se ha vendido aún           │
│                                  │
│ 💡 Sugerencia: Stock por debajo  │
│    del nivel de alerta.          │
│    [Agregar al pedido reabastecer]│
└──────────────────────────────────┘
```

---

# PARTE B: NUEVAS FUNCIONES PROPUESTAS

## B.1 📋 Lista de Compras Inteligente (Reabastecimiento)

### Basado en el análisis:
22 presentaciones están en o por debajo del nivel de alerta. El usuario necesita una forma rápida de saber qué comprar.

### Funcionalidad:
1. **Generación automática**: La app analiza stock actual vs alertas y genera lista de productos a comprar
2. **Agrupación por proveedor**: Agrupa los productos por proveedor para hacer pedidos eficientes
3. **Historial de precios**: Muestra el último precio de compra para cada producto
4. **Compartir por WhatsApp**: Envía la lista al proveedor directamente

```
📋 Lista de Reabastecimiento

🔴 URGENTE (stock < 50% del alerta):
├── ATUQ DEX S.A.C.
│   ├── Aceite Premium 900ml (stock: 2/5) → comprar 3+
│   └── Aceite 900ml (stock: 1/5) → comprar 4+
│
🟡 PRÓXIMO (stock = alerta):
├── DISTRIBUCIONES SILVIA
│   ├── Crema Dental Herbal (stock: 16/5) ← OK pero revisar
│   └── ...
│
[📤 Enviar pedido a ATUQ DEX por WhatsApp]
[📤 Enviar pedido a DISTRIB. SILVIA por WhatsApp]
```

**Mensaje WhatsApp generado:**
```
📦 Pedido de BAZAR LUZAM

Estimado proveedor ATUQ DEX S.A.C.,
necesitamos los siguientes productos:

1. Aceite Premium 900ml - 3 unidades (último precio: S/8.76)
2. Aceite 900ml - 4 unidades (último precio: S/7.87)

Total estimado: S/ 57.76

¡Gracias!
BAZAR LUZAM - Talara
Tel: 976 644 890
```

---

## B.2 💰 Control de Caja Diario

### Basado en el análisis:
El usuario no tiene visibilidad de cuánto efectivo debería tener en caja.

### Funcionalidad:
```
💰 Caja del Día - 06 Oct 2026

Apertura: S/ ___ [Registrar apertura]

Ventas del día:
• Efectivo: S/ 0.00
• Yape/Plin: S/ 0.00
• Fiado: S/ 0.00

Cobros recibidos:
• Ninguno hoy

Gastos:
• Ninguno registrado

─────────────────
Efectivo esperado: S/ ___
[Cerrar caja] → Ingresa cuánto hay realmente
Diferencia: S/ ___ ✅ Cuadra / ⚠️ Descuadre
```

---

## B.3 📊 Comparador de Precios entre Proveedores

### Basado en el análisis:
El usuario compra el mismo tipo de productos de distintos proveedores. Necesita comparar precios.

### Funcionalidad:
```
🔄 Comparador de Precios

Producto: Aceite 900ml
┌─────────────────────────────────────┐
│ Proveedor         │ Precio │ Fecha  │
├───────────────────┼────────┼────────┤
│ ATUQ DEX (Premium)│ S/8.76 │ 21 Ago │
│ ATUQ DEX (Normal) │ S/7.87 │ 21 Ago │
│                   │        │        │
│ 💡 Mejor precio:  │ S/7.87 │ ATUQ   │
│    Ahorro vs peor:│ S/0.89 │ (10%)  │
└─────────────────────────────────────┘
```

---

## B.4 📅 Calendario de Vencimientos

### Basado en el análisis:
Productos perecibles (yogurt, leche, mantequilla) necesitan control de fecha de vencimiento.

### Funcionalidad:
- Campo de "fecha de vencimiento" opcional en presentaciones
- Vista de calendario con productos próximos a vencer
- Notificación automática 7 días antes del vencimiento
- Sugerencia de descuento para productos próximos a vencer

---

## B.5 📈 Alertas de Precio Inteligentes

### Basado en el análisis:
El usuario tiene productos con margen < 5% que probablemente no sabe que están generando casi cero ganancia.

### Funcionalidad:
Al registrar un precio de venta que genere un margen menor al 10%:
```
⚠️ ¡Alerta de Margen Bajo!

Bombom Multipack 320g
• Costo: S/ 0.49
• Precio de venta: S/ 0.50
• Margen: 1.3% ← ¡Muy bajo!

Sugerencia: S/ 0.70 (margen: 42%)

¿Mantener S/ 0.50 o ajustar?
[Mantener] [Ajustar a S/ 0.70] [Otro precio]
```

---

## B.6 🗓️ Historial de Precios de Compra

### Basado en el análisis:
Las facturas muestran que algunos precios cambian entre compras. El usuario necesita ver la evolución.

### Funcionalidad:
En cada presentación, mostrar el historial de precios de compra:
```
📈 Historial de Precios: Aceite Primor 900ml

Fecha       | Proveedor  | Precio UND | Variación
21 Ago 2026 | ATUQ DEX   | S/ 8.76    | —
(futuras)   |            |            | ↑↓ %

Promedio: S/ 8.76
Tendencia: → Estable
```

---

## B.7 🏷️ Etiquetado Inteligente de Productos para Impresión

### Basado en el análisis:
La configuración de impresora está vacía. Pero cuando se configure, el usuario necesitará imprimir etiquetas.

### Funcionalidad:
- Generar etiquetas de precio con nombre, precio, código de barras
- Imprimir etiquetas de estantería
- Actualización masiva de precios con reimpresión automática

---

## B.8 🔔 Sistema de Alertas Contextuales (Smart Alerts)

### Basado en el análisis:
6 notificaciones sin leer. El sistema actual de notificaciones no funciona para este usuario.

### Propuesta de mejora:
En lugar de solo notificaciones pasivas, implementar **alertas contextuales** que aparezcan justo cuando el usuario está en la pantalla relevante:

1. **Al abrir el catálogo**: "⚠️ 3 productos tienen stock bajo"
2. **Al abrir ventas**: "💰 Tienes S/ 258.57 por cobrar"
3. **Al abrir una factura**: "📷 ¿Quieres escanear esta factura con la IA?"
4. **Al crear un producto**: "🏷️ Este producto se parece a uno existente"
5. **Al abrir el perfil**: "📋 Tu perfil está 40% completo"

Las alertas deben ser **banners deslizables** en la parte superior, no popups que interrumpan.

---

# PARTE C: OPTIMIZACIÓN DE FUNCIONES EXISTENTES

## C.1 Optimización del Escáner de Facturas IA

### Mejoras sugeridas:
1. **Guardar siempre `datos_crudos_ia_json`** incluso para facturas manuales (reconstruir desde presentaciones)
2. **Pre-llenar proveedor** si el RUC ya existe en la base de datos
3. **Detectar productos duplicados** antes de crear nuevos durante el escaneo
4. **Modo batch**: Permitir escanear múltiples páginas de una factura

## C.2 Optimización del Sistema de Cuotas

### Mejoras sugeridas:
1. **Pagos parciales** a cuotas (actualmente parece solo todo o nada)
2. **Recordatorio automático** por WhatsApp 3 días antes del vencimiento
3. **Recargo por atraso** configurable (interés moratorio)
4. **Estado visual claro**: Verde (al día), Amarillo (próxima a vencer), Rojo (vencida)

## C.3 Optimización del Backup

### Mejoras sugeridas:
1. **Backup automático** diario a almacenamiento local
2. **Validación al importar**: Verificar integridad de datos antes de restaurar
3. **Resumen de cambios**: Al importar un backup, mostrar qué se va a agregar/modificar
4. **Eliminar código duplicado** entre `exportBusiness` y `exportBusinessToFile`

## C.4 Optimización del Catálogo de UMPs

### Mejoras sugeridas:
1. **Catálogo cerrado** con las UMPs más comunes:
   - UND (Unidad), PAQ (Paquete), CJ (Caja), DSP (Display), BOL (Bolsa)
   - BOT (Botella), SCH (Sachet), TIR (Tira), SRO (Sobre), LTA (Lata)
2. **Normalización automática** de UMPs existentes al importar
3. **Selector dropdown** en lugar de campo de texto libre

---

# RESUMEN EJECUTIVO DE ESTE INFORME

### Lo más importante a implementar PRIMERO (top 5):

| # | Mejora | Razón |
|---|--------|-------|
| 1 | **Globos de información (tooltips)** | El usuario no entiende las funciones → no las usa |
| 2 | **Corregir historial de facturas** | Bug crítico que afecta la confianza en la app |
| 3 | **Dashboard de inicio** | Da al usuario una vista instantánea de su negocio |
| 4 | **Categorías predefinidas** | Organizar 87 productos en 1 categoría es inaceptable |
| 5 | **Recordatorios de cobro por WhatsApp** | S/ 258.57 sin cobrar es dinero perdido |

### Lo más importante para retener al usuario:

| # | Mejora | Razón |
|---|--------|-------|
| 1 | **Simplificar flujo de venta (POS)** | Solo 2 ventas en 52 días = flujo complejo |
| 2 | **Reportes automáticos semanales** | El usuario no genera reportes manualmente |
| 3 | **Alertas contextuales** | Las notificaciones pasivas son ignoradas |
| 4 | **Lista de reabastecimiento** | Automatiza la tarea más tediosa |
| 5 | **Validación de duplicados** | Evita contaminar el catálogo |
