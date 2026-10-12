# 📊 INFORME 1: Análisis Profundo del Backup y Comportamiento del Usuario

> **Negocio:** librería BAZAR LUZAM  
> **Usuario:** Luz Navarro  
> **Ubicación:** Talara, Perú  
> **Período de análisis:** 14 Ago 2026 – 05 Oct 2026 (~52 días de uso)  
> **Fecha de exportación del backup:** 2026-10-05T14:48:11  
> **Fecha del análisis:** 2026-10-06  

---

## 1. 🏪 PERFIL DEL NEGOCIO

| Campo | Valor | Estado |
|-------|-------|--------|
| Nombre Comercial | librería BAZAR LUZAM | ✅ Registrado |
| RUC | `null` | ⚠️ **NO REGISTRADO** |
| Dirección | Talara | ✅ Registrado |
| Logo | `null` | ⚠️ **NO CONFIGURADO** |
| Configuración Impresora | `null` | ⚠️ **NO CONFIGURADA** |
| Información de Pago | Yape y Plin | ✅ Registrado |
| Moneda | S/ (Soles) | ✅ Correcto |
| Coordenadas GPS | `null` / `null` | ⚠️ **NO REGISTRADAS** |
| PIN de Seguridad | `false` | ⚠️ **NO ACTIVADO** |
| Fecha de creación | 14 Ago 2026 | ✅ |

> **⚠️ Campos críticos sin completar:** El negocio no tiene RUC, logo, configuración de impresora ni coordenadas GPS registradas. Esto limita funciones como facturación formal, branding y geolocalización.

---

## 2. 👤 PERFIL DEL USUARIO

| Campo | Valor | Estado |
|-------|-------|--------|
| Nombre | Luz Navarro | ✅ |
| Teléfono | 976 644 890 | ✅ |
| Email | `null` | ⚠️ **NO REGISTRADO** |
| Código Único | `null` | ⚠️ **NO GENERADO** |

---

## 3. 📈 ESTADÍSTICAS GENERALES DEL BACKUP

### Conteo de registros por tabla (mayor a menor volumen)

| Tabla | Registros | Nivel de Uso |
|-------|-----------|--------------|
| `stock_ledger` | **96** | 🟢 ALTO |
| `presentaciones_producto` | **89** | 🟢 ALTO |
| `productos` | **87** | 🟢 ALTO |
| `marcas` | **48** | 🟢 ALTO |
| `facturas_carga` | **19** | 🟡 MEDIO |
| `proveedores` | **11** | 🟡 MEDIO |
| `notificaciones` | **6** | 🔴 BAJO |
| `cuotas` | **5** | 🔴 BAJO |
| `venta_items` | **2** | 🔴 BAJO |
| `ventas` | **2** | 🔴 BAJO |
| `smart_quotation_items` | **2** | 🔴 BAJO |
| `clientes` | **1** | 🔴 MUY BAJO |
| `smart_quotations` | **1** | 🔴 MUY BAJO |
| `business_snapshots` | **1** | 🔴 MUY BAJO |
| `categorias` | **1** | 🔴 MUY BAJO |
| `pagos` | **1** | 🔴 MUY BAJO |
| `codigos_acceso_negocio` | **0** | ❌ SIN USO |
| `campanas_promocionales` | **0** | ❌ SIN USO |
| `paquetes` | **0** | ❌ SIN USO |
| `items_paquete` | **0** | ❌ SIN USO |
| `reglas_promocion` | **0** | ❌ SIN USO |
| `product_history` | **0** | ❌ SIN USO |

### Observaciones clave del volumen de datos:
1. **El catálogo de productos (87 prod, 89 presentaciones) es la función más utilizada** — El usuario se ha enfocado en cargar su inventario.
2. **Solo 1 categoría creada ("abarrotes")** — Todo el inventario se clasifica bajo una sola categoría genérica.
3. **48 marcas registradas** — Alta diversificación de marcas para una bodega/librería.
4. **Solo 2 ventas y 1 cotización en ~52 días** — El módulo de ventas/cotizaciones está **muy subutilizado**.
5. **0 campañas, 0 paquetes, 0 reglas de promoción** — Las herramientas promocionales no se han explorado.
6. **Solo 1 cliente registrado** — La gestión de clientes está prácticamente sin usar.
7. **6 tablas completamente vacías** — Representan funciones que el usuario no ha descubierto o no comprende.

---

## 4. 🔍 ANÁLISIS DETALLADO DE COMPORTAMIENTO DEL USUARIO

### 4.1 Patrón de Carga de Facturas (Compras)

El usuario cargó **19 facturas** con un total de **S/ 1,241.32** en compras a proveedores.

**Distribución temporal:**
| Mes | Facturas | Monto Total | Observación |
|-----|----------|-------------|-------------|
| Agosto 2026 | 15 | S/ 1,048.97 | 🟢 Alta actividad inicial |
| Septiembre 2026 | 3 | S/ 158.03 | 🟡 Actividad reducida |
| Octubre 2026 | 1 | S/ 34.32 | 🔴 Actividad mínima |

> **Patrón detectado:** El usuario tuvo un arranque entusiasta en agosto (15 facturas en ~17 días), pero la actividad cayó drásticamente a 3 facturas en septiembre y solo 1 en octubre. Esto indica que la carga manual resulta tediosa o que el usuario perdió motivación.

**Distribución por proveedor:**
| Proveedor | Monto | % del Total | Facturas |
|-----------|-------|-------------|----------|
| DISTRIBUIDORA COMERCIAL ALVAREZ BOHL SRL | S/ 357.96 | 28.8% | 5 |
| ATUQ DEX S.A.C. | S/ 188.01 | 15.1% | 2 |
| CODIJISA | S/ 122.18 | 9.8% | 1 |
| CBC MARKET S.A.C. | S/ 95.61 | 7.7% | 1 |
| DISTRIBUCIONES SILVIA EIRL | S/ 91.21 | 7.3% | 1 |
| NO ESPECIFICADO | S/ 75.32 | 6.1% | 1 |
| LECHE GLORIA S.A. | S/ 72.51 | 5.8% | 1 |
| PUNTO BLANCO SAC / S.A.C. (duplicado) | S/ 129.69 | 10.4% | 3 |
| SODALES DISTRIBUIDORES S.C.R.L. | S/ 65.04 | 5.2% | 2 |
| SALEM | S/ 43.79 | 3.5% | 1 |

### 4.2 Patrón de Ventas

**Solo 2 ventas realizadas en ~52 días:**
| # | Cliente | Origen | Total | Pagado | Pendiente | Método | Interés |
|---|---------|--------|-------|--------|-----------|--------|---------|
| 1 | Freddy | smart_quotation | S/ 23.57 | S/ 5.00 | S/ 18.57 | Yape | 5% |
| 2 | Freddy | prestamo_personal | S/ 240.00 | S/ 0.00 | S/ 240.00 | Yape | 20% |

> **⚠️ ALERTA: Deuda total acumulada: S/ 258.57** — Todo del mismo cliente (Freddy), marcado como "VIP". Las 5 cuotas están VENCIDAS con hasta 37 días de atraso. El usuario no ha registrado ningún pago a estas cuotas.

### 4.3 Patrón de Uso de Notificaciones

**6 notificaciones generadas, TODAS sin leer:**
- 1 alerta de stock bajo (Aceite)
- 5 alertas de cuotas vencidas (Cliente Freddy)

> **El usuario NO revisa las notificaciones.** Esto indica que el sistema de notificaciones no es lo suficientemente visible o que el usuario no comprende su importancia.

---

## 5. 🐛 PROBLEMAS DETECTADOS EN LOS DATOS

### 5.1 ⚠️ PROBLEMA CRÍTICO: Facturas sin datos de IA (datos_crudos_ia_json)

| Dato | Valor |
|------|-------|
| Facturas CON datos IA | **2** (solo #18 y #19) |
| Facturas SIN datos IA | **17** (todas las demás) |
| Facturas con imagen real adjunta | **2** (solo #18 y #19) |
| Facturas con `imagen_url = "local_ia_scan"` | **17** |

**Diagnóstico:** Las primeras 17 facturas (#1 a #17) fueron cargadas usando el método de **ingreso manual** (sin escaneo de imagen). Solo las facturas #18 y #19 utilizaron el **escáner de IA con fotografía real**.

**Este es el problema que reportaste:** Al restaurar el backup, el historial de facturas muestra 19 facturas pero solo las últimas 2 (#18 y #19) conservan sus datos completos. Las otras 17 no tienen `datos_crudos_ia_json` ni `cantidad_items_extraidos` porque fueron ingresadas manualmente.

**Causa raíz del problema:**
- Las facturas cargadas manualmente (sin escaneo IA) guardan `imagen_url` como `"local_ia_scan"` y `datos_crudos_ia_json` como `null`.
- Al mostrar el historial de facturas escaneadas, la vista probablemente intenta renderizar los datos crudos del JSON de IA, y al no encontrarlos, muestra la factura "vacía".
- **Los items de esas facturas SÍ existen** en la tabla `presentaciones_producto` (vinculadas por `factura_carga_id`), pero la vista del historial no los está consultando correctamente.

**Propuesta de solución:**
1. **En la vista del historial de facturas**, cuando `datos_crudos_ia_json` es `null`, reconstruir los datos desde las tablas `presentaciones_producto` y `productos` filtrando por `factura_carga_id`.
2. Guardar una versión del JSON de datos incluso para facturas manuales, para tener consistencia en la visualización.
3. Diferenciar visualmente las facturas "manuales" de las "escaneadas con IA" en el historial.

### 5.2 ⚠️ Marcas Duplicadas

Se detectaron las siguientes marcas duplicadas o con variaciones de escritura:

| Marca 1 | Marca 2 | Tipo de duplicación |
|---------|---------|---------------------|
| Sedal (id:27) | Sedal (id:38) | **DUPLICADO EXACTO** |
| Winters (id:17) | Winter's (id:51) | Variación de escritura |
| vizzio (id:43) | Vizzio (id:48) | Variación de mayúsculas |
| teresita (id:42) | Teresita (id:49) | Variación de mayúsculas |
| Nurribella (id:5) | Nutribella (id:6) | Posible error de tipeo |
| desodorante (id:23) | — | **NO ES UNA MARCA**, es un tipo de producto |
| poet (id:24) | — | **NO ES UNA MARCA**, es un nombre de producto |
| quitaesmalte (id:37) | — | **NO ES UNA MARCA**, es un tipo de producto |

> **⚠️ El usuario confunde marcas con categorías/tipos de producto.** "desodorante", "poet", "quitaesmalte" NO son marcas sino tipos de producto. Esto contamina el catálogo.

### 5.3 ⚠️ Proveedores Duplicados

| Proveedor 1 | Proveedor 2 | RUC |
|-------------|-------------|-----|
| PUNTO BLANCO SAC (id:8) | PUNTO BLANCO S.A.C. (id:9) | **20105367407** (mismo RUC) |

Además, existe un proveedor "NO ESPECIFICADO" (id:7) con RUC vacío, que acumula S/ 75.32 en compras.

### 5.4 ⚠️ Productos sin categoría

| ID | Producto |
|----|----------|
| 49 | Shampoo Romero Anticaída Sachet |
| 50 | Shampoo Limpieza Renovadora |
| 51 | Shampoo Suave Manejable 2en1 |

Estos 3 productos no tienen `categoria_id`, probablemente por un error en el escaneo o la asignación manual.

### 5.5 ⚠️ Productos sin marca

**24 de 87 productos** (27.6%) no tienen marca asignada. Ejemplos:
- Mezcla Láctea en Polvo, Máquina de Afeitar, Shampoo Anticomezón, Limpiador Multiuso (x4 duplicados), Lejía, Grated de Atún, Papel Higiénico, etc.

### 5.6 ⚠️ Productos con nombres duplicados

| Producto | IDs duplicados |
|----------|---------------|
| Suavizante de Telas Complete | 22, 23 |
| Yogurt Battimix | 29, 30 |
| Yogurt Parcialmente Descremado | 31, 32 |
| Toallas Higiénicas | 68, 69, 70 (3 registros) |
| Limpiador Multiuso | 53, 54, 55, 56 (4 registros) |

### 5.7 ⚠️ Fecha inválida en factura

La factura **#2** (ATUQ DEX S.A.C.) tiene `fecha_emision = "2024-08-14"`, que es **2 años antes** de la fecha de uso de la app (2026). Esto es claramente un error de digitación por parte del usuario.

### 5.8 ⚠️ Inconsistencias en Unidades de Medida de Compra (UMP)

Se detectaron **28 variaciones diferentes** de UMP de compra, muchas representando lo mismo:
| UMP Similares | Significado |
|---------------|-------------|
| `UND` / `unidad` | Unidad |
| `PAQ` / `paquete` | Paquete |
| `BOL` / `bolsa` | Bolsa |
| `CJ` / `CJA` / `CJT` | Caja |
| `DIS` / `DSP` | Display |
| `BOT` / `FCO` / `LTA` | Botella/Frasco/Lata |
| `TRAx12UND` / `TRAx15UND` / `TRAx6UND` / `TRAX12SCH` | Tiras de distintas cantidades |

> **⚠️ La falta de un catálogo estándar de unidades de medida genera inconsistencias que dificultan los reportes y el análisis de costos.**

### 5.9 ⚠️ Inconsistencias en Unidades de Venta

| Unidad | Frecuencia | Observación |
|--------|-----------|-------------|
| `Unidad` | 84 | Estándar |
| `paquete` | 2 | Debería estandarizarse |
| `duo` | 1 | Unidad personalizada |
| `unidades` | 1 | Variación de "Unidad" |
| `pareja` | 1 | Unidad personalizada |

### 5.10 ⚠️ Presentaciones con precio sospechoso

| Producto | Presentación | Costo | Venta | Margen |
|----------|-------------|-------|-------|--------|
| Bombom Multipack | 320g | S/ 0.49 | S/ 0.50 | **1.3%** (margen insignificante) |
| Leche Condensada Milk | 393g + PRDulcera | S/ 6.35 | S/ 7.00 | **10.2%** (margen muy bajo) |

### 5.11 ⚠️ Ningún producto tiene código de barras a nivel de producto

Los códigos de barras solo están en algunas presentaciones. **0 de 87 productos** tienen `codigo_barras` a nivel de tabla `productos`.

### 5.12 ⚠️ Todas las imágenes ausentes

- **87/87 productos** sin imagen (100%)
- **48/48 marcas** sin imagen (100%)
- Solo 2 facturas tienen imagen de foto real

---

## 6. 💰 ANÁLISIS FINANCIERO

### 6.1 Inventario actual
| Métrica | Valor |
|---------|-------|
| Valor a precio de compra | **S/ 1,370.61** |
| Valor a precio de venta | **S/ 1,758.76** |
| Ganancia potencial del inventario | **S/ 388.15** |
| Margen promedio potencial | **~28.3%** |

### 6.2 Márgenes de ganancia

**Top 5 – Mayor margen:**
| Producto | Costo | Venta | Margen |
|----------|-------|-------|--------|
| Toallas Higiénicas Nocturna x30 | S/ 0.43 | S/ 1.00 | **132%** |
| Máquina de Afeitar (guillette) | S/ 0.23 | S/ 0.50 | **121%** |
| Colombinetas Chococaramel | S/ 0.24 | S/ 0.50 | **104%** |
| Galleta Vainilla | S/ 0.26 | S/ 0.50 | **91%** |
| Ablanda Sazón | S/ 0.21 | S/ 0.40 | **90%** |

**Top 5 – Menor margen (riesgo de pérdida):**
| Producto | Costo | Venta | Margen |
|----------|-------|-------|--------|
| Bombom Multipack 320g | S/ 0.49 | S/ 0.50 | **1.3%** |
| Leche Condensada Milk | S/ 6.35 | S/ 7.00 | **10.2%** |
| Máquina de Afeitar Pivot | S/ 2.72 | S/ 3.00 | **10.5%** |
| Yogurt Battimix | S/ 3.01 | S/ 3.49 | **16.1%** |
| Leche UHT Chocolate | S/ 1.29 | S/ 1.51 | **17.4%** |

### 6.3 Situación de cobros
| Concepto | Monto |
|----------|-------|
| Total vendido | S/ 263.57 |
| Total cobrado | S/ 5.00 |
| **Total pendiente de cobro** | **S/ 258.57** |
| Cuotas vencidas | 5 de 5 (100%) |
| Máximo atraso | 37 días |

> **⚠️ ALERTA FINANCIERA: Solo se ha cobrado el 1.9% de las ventas.** El único cliente (Freddy, etiquetado como "VIP") adeuda S/ 258.57 con todas sus cuotas vencidas. El préstamo personal de S/ 240 con 20% de interés no ha recibido ningún pago.

### 6.4 Snapshot del negocio (único registro: 22 Ago 2026)
| Métrica | Valor |
|---------|-------|
| Ventas totales | S/ 23.57 |
| Ganancia neta | S/ 4.43 |
| Margen | 18.79% |
| Transacciones | 1 |
| Valor inventario | S/ 280.59 |
| Stock muerto | 20 items |

> Solo se generó 1 snapshot en toda la vida del negocio. Esto sugiere que la función de snapshots no se ejecuta con la frecuencia necesaria.

---

## 7. 📱 RESUMEN DE FUNCIONES USADAS vs NO USADAS

### ✅ Funciones que el usuario SÍ utiliza:
1. ✅ Carga de facturas (manual y con IA) — 19 facturas
2. ✅ Registro de productos y presentaciones — 87 productos
3. ✅ Registro de marcas — 48 marcas
4. ✅ Registro de proveedores — 11 proveedores
5. ✅ Cotización inteligente (1 uso)
6. ✅ Registro de ventas (2 ventas)
7. ✅ Sistema de cuotas y pagos (5 cuotas, 1 pago)
8. ✅ Exportación de backup (.mlb)
9. ✅ Etiquetado de clientes (VIP, CLIENTE)
10. ✅ Préstamos personales (1 préstamo)

### ❌ Funciones que el usuario NO utiliza:
1. ❌ Campañas promocionales
2. ❌ Paquetes de productos (bundles)
3. ❌ Reglas de promoción
4. ❌ Códigos de acceso al negocio
5. ❌ Historial de cambios de productos
6. ❌ Ofertas y descuentos en presentaciones
7. ❌ Categorización adecuada (solo 1 categoría genérica)
8. ❌ Imágenes de productos/marcas
9. ❌ Logo del negocio
10. ❌ Configuración de impresora
11. ❌ Lectura de notificaciones (6 sin leer)
12. ❌ Múltiples snapshots del negocio
