# 🐛 INFORME 2: Problemas Técnicos Detectados y Correcciones Necesarias

> **Contexto:** Este informe detalla los bugs y problemas técnicos encontrados al analizar el backup del negocio "BAZAR LUZAM" y la revisión del código fuente del servicio de backup/restauración.

---

## 1. 🔴 BUG CRÍTICO: Historial de Facturas Vacío tras Restaurar Backup

### Descripción del problema:
Al importar el backup (.mlb) en la app, al revisar el historial de facturas escaneadas, solo la **última factura escaneada** (#19) muestra datos. Las demás 18 facturas aparecen sin datos registrados.

### Causa raíz identificada:

Hay **dos problemas combinados**:

#### Problema A: Facturas manuales sin `datos_crudos_ia_json`

De las 19 facturas en el backup:
- **17 facturas** (IDs 1-17) tienen `datos_crudos_ia_json = null` y `cantidad_items_extraidos = null`
- **Solo 2 facturas** (IDs 18 y 19) tienen datos IA completos

La vista del historial de facturas probablemente depende de `datos_crudos_ia_json` para mostrar los ítems de cada factura. Cuando este campo es `null` (facturas ingresadas manualmente), la factura aparece "vacía".

**Sin embargo, los ítems SÍ existen en la tabla `presentaciones_producto`**, vinculados a través del campo `factura_carga_id`. Por ejemplo:
- Factura #6 tiene presentaciones 58, 59, 60 con `factura_carga_id = 6`
- Factura #7 tiene presentaciones 63, 64 con `factura_carga_id = 7`
- Factura #8 tiene presentaciones 65, 66, 67, 68 con `factura_carga_id = 8`

#### Problema B: No todas las presentaciones tienen `factura_carga_id`

De las 89 presentaciones del backup:
- Muchas tienen `factura_carga_id = null` — fueron registradas manualmente sin vincularlas a una factura específica.
- Esto ocurre cuando el usuario ingresa datos manualmente y el sistema no asocia automáticamente la presentación a la factura.

### Solución propuesta:

```dart
// En la vista del historial de facturas, al mostrar los ítems:
// ANTES (probablemente):
final items = jsonDecode(factura.datos_crudos_ia_json); // Falla si es null

// DESPUÉS (solución):
List<Map<String, dynamic>> items;
if (factura.datos_crudos_ia_json != null) {
  // Factura escaneada con IA - usar datos crudos
  items = jsonDecode(factura.datos_crudos_ia_json)['items'];
} else {
  // Factura manual - reconstruir desde presentaciones_producto
  items = await db.rawQuery('''
    SELECT pp.*, p.nombre as producto_nombre, m.nombre as marca_nombre
    FROM presentaciones_producto pp
    LEFT JOIN productos p ON pp.producto_id = p.id
    LEFT JOIN marcas m ON p.marca_id = m.id
    WHERE pp.factura_carga_id = ?
  ''', [factura.id]);
}
```

Además, durante la exportación en `business_backup_service.dart`, se debería **generar un `datos_crudos_ia_json` retroactivo** para las facturas manuales al momento de exportar, reconstruyéndolo desde las presentaciones vinculadas.

---

## 2. 🟡 BUG MEDIO: Marcas Duplicadas No Detectadas

### Descripción:
El sistema permite crear marcas con el mismo nombre exacto o con variaciones menores de capitalización/acentuación sin advertir al usuario.

### Casos encontrados:
| Duplicado | IDs |
|-----------|-----|
| Sedal / Sedal | 27, 38 |
| Winters / Winter's | 17, 51 |
| vizzio / Vizzio | 43, 48 |
| teresita / Teresita | 42, 49 |

### Solución propuesta:
Implementar una validación al crear marcas que compare el nombre en minúsculas y sin caracteres especiales:

```dart
// Antes de insertar una nueva marca:
final existentes = await db.query(
  'marcas',
  where: 'LOWER(TRIM(nombre)) = ? AND negocio_id = ?',
  whereArgs: [nombreNuevo.toLowerCase().trim(), negocioId],
);
if (existentes.isNotEmpty) {
  // Mostrar warning: "Ya existe una marca similar: ${existentes.first['nombre']}"
  // Preguntar si desea usar la existente o crear una nueva
}
```

---

## 3. 🟡 BUG MEDIO: Proveedores Duplicados por RUC

### Descripción:
El proveedor "PUNTO BLANCO" existe duplicado con el mismo RUC (20105367407) pero con nombres ligeramente diferentes:
- ID 8: "PUNTO BLANCO SAC"
- ID 9: "PUNTO BLANCO S.A.C."

### Impacto:
- Las facturas se distribuyen entre dos registros del mismo proveedor
- Estadísticas de compras por proveedor son incorrectas
- Factura #10 vinculada al ID 8, Facturas #11 y #16 vinculadas al ID 9

### Solución propuesta:
1. **Prevención:** Validar el RUC al crear un proveedor. Si ya existe un proveedor con ese RUC, mostrar advertencia.
2. **Corrección:** Implementar función de "fusionar proveedores duplicados".

```dart
// Validación al crear proveedor:
if (ruc != null && ruc.isNotEmpty) {
  final existentes = await db.query(
    'proveedores',
    where: 'ruc = ? AND negocio_id = ?',
    whereArgs: [ruc, negocioId],
  );
  if (existentes.isNotEmpty) {
    // "Ya existe el proveedor: ${existentes.first['nombre_empresa']} con este RUC"
  }
}
```

---

## 4. 🟡 BUG MEDIO: Productos Duplicados Permitidos

### Descripción:
Se encontraron 5 grupos de productos con nombres idénticos que coexisten en la base de datos:
- "Suavizante de Telas Complete" (IDs 22, 23)
- "Yogurt Battimix" (IDs 29, 30)
- "Yogurt Parcialmente Descremado" (IDs 31, 32)
- "Toallas Higiénicas" (IDs 68, 69, 70) — ¡3 registros!
- "Limpiador Multiuso" (IDs 53, 54, 55, 56) — ¡4 registros!

### Causa probable:
- El usuario escaneó la misma factura más de una vez
- El sistema creó nuevos productos sin verificar duplicados
- O el usuario ingresó manualmente productos que ya existían

### Solución propuesta:
1. **Prevención:** Al crear un producto, buscar productos con nombre similar y sugerir usar el existente.
2. **Herramienta de limpieza:** Crear una vista de "productos duplicados" donde el usuario pueda fusionar registros.
3. **En el escáner IA:** El matching engine debería detectar que el producto ya existe antes de crear uno nuevo.

---

## 5. 🟡 BUG MEDIO: Fecha Inválida en Factura

### Descripción:
La factura #2 (ATUQ DEX S.A.C.) tiene `fecha_emision = "2024-08-14"`, que es 2 años antes del uso de la app.

### Solución propuesta:
1. **Validación:** Al ingresar fechas de factura, validar que no sean futuras ni demasiado antiguas (p.ej. máximo 1 año atrás).
2. **Advertencia visual:** Si la fecha parece inusual, mostrar un warning amarillo en la UI.

```dart
// Validación de fecha:
final now = DateTime.now();
if (fechaEmision.isAfter(now)) {
  showWarning('La fecha de emisión es futura');
} else if (now.difference(fechaEmision).inDays > 365) {
  showWarning('La fecha de emisión tiene más de 1 año de antigüedad. ¿Es correcta?');
}
```

---

## 6. 🟡 BUG MEDIO: Inconsistencia en UMPs

### Descripción:
Se encontraron **28 variaciones diferentes** de unidades de medida de compra. Muchas representan lo mismo con diferente formato:
- `UND` vs `unidad` (2 variantes de "Unidad")
- `PAQ` vs `paquete` (2 variantes de "Paquete")
- `BOL` vs `bolsa` (2 variantes de "Bolsa")
- `CJ` vs `CJA` vs `CJT` (3 variantes de "Caja")
- `DIS` vs `DSP` (2 variantes de "Display")

### Impacto:
- Reportes de inventario inconsistentes
- Imposibilidad de agrupar compras por tipo de empaque
- Confusión para el usuario

### Solución propuesta:
Usar un **catálogo cerrado de UMPs** con selector dropdown en lugar de campo de texto libre. Ya existe el servicio `unit_catalog_service.dart` — asegurar que SIEMPRE se use y que normalice las entradas del escáner IA.

---

## 7. 🟢 BUG MENOR: Todos los Proveedores sin Datos de Contacto

### Descripción:
Los 11 proveedores registrados tienen `contacto_nombre = null`, `telefono = null`, `email = null`.

### Impacto:
- No se puede contactar rápidamente a los proveedores desde la app
- Limita futuras funciones de reabastecimiento automático

### Solución:
- Hacer los campos de contacto más visibles/accesibles en el formulario de proveedor
- Sugerir completar datos después de registrar un proveedor

---

## 8. 🟢 BUG MENOR: Negocio sin Datos Importantes

### Descripción:
El negocio no tiene: RUC, logo, configuración de impresora, ni coordenadas GPS.

### Solución:
- Implementar un **indicador de "perfil completo"** (barra de progreso) en la pantalla de perfil
- Mostrar tooltips o banners que recuerden completar estos campos

---

## 9. 🔴 PROBLEMA EN LA LÓGICA DE IMPORTACIÓN/EXPORTACIÓN

### Análisis del archivo `business_backup_service.dart`:

#### 9.1 Problema detectado: Remapeo de IDs en stock_ledger
En el método `importBusiness()`, al insertar registros de `stock_ledger`, se remapea `presentation_id` pero el campo `origen_id` **NO se remapea**:

```dart
// Línea 791-797 del business_backup_service.dart:
for (var item in data['stock_ledger'] ?? []) {
  item = Map<String, dynamic>.from(item);
  item.remove('id');
  item['negocio_id'] = targetNegocioId;
  if (item['presentation_id'] != null) item['presentation_id'] = presentationIdMap[item['presentation_id']];
  // ⚠️ FALTA: remapear 'origen_id' según 'tipo_transaccion'
  await txn.insert('stock_ledger', item);
}
```

**El campo `origen_id` debería remapearse según el tipo de transacción:**
- Si `tipo_transaccion = 'COMPRA_LOTE'`, `origen_id` referencia a `facturas_carga.id` → usar `invoiceIdMap`
- Si `tipo_transaccion = 'VENTA'`, `origen_id` referencia a `ventas.id` → usar `saleIdMap`
- Si `tipo_transaccion = 'AJUSTE_INVENTARIO'`, `origen_id` es `null` → no requiere remapeo

**Corrección necesaria:**
```dart
for (var item in data['stock_ledger'] ?? []) {
  item = Map<String, dynamic>.from(item);
  item.remove('id');
  item['negocio_id'] = targetNegocioId;
  if (item['presentation_id'] != null) {
    item['presentation_id'] = presentationIdMap[item['presentation_id']];
  }
  // Remapear origen_id según tipo de transacción
  if (item['origen_id'] != null) {
    switch (item['tipo_transaccion']) {
      case 'COMPRA_LOTE':
        item['origen_id'] = invoiceIdMap[item['origen_id']];
        break;
      case 'VENTA':
        item['origen_id'] = saleIdMap[item['origen_id']];
        break;
      // AJUSTE_INVENTARIO: origen_id ya es null, no necesita mapeo
    }
  }
  await txn.insert('stock_ledger', item);
}
```

#### 9.2 Problema potencial: product_history sin remapeo de presentaciones
En las líneas 800-808, el `product_history` solo remapea IDs de tipo `'producto'`, pero si hubiera registros de tipo `'presentacion'`, no se remapearían correctamente.

#### 9.3 Código duplicado entre exportBusiness y exportBusinessToFile
Los métodos `exportBusiness()` (líneas 146-293) y `exportBusinessToFile()` (líneas 297-442) contienen código casi idéntico (~300 líneas duplicadas). Esto es un problema de mantenibilidad: cualquier bug corregido en uno debe replicarse en el otro.

**Solución:** Extraer la lógica de recopilación de datos a un método privado compartido:
```dart
static Future<Map<String, dynamic>> _collectBackupData(int negocioId, {bool includeSecurityPin = false}) async {
  // Toda la lógica de consultas aquí...
}
```

---

## 10. RESUMEN DE PRIORIDADES DE CORRECCIÓN

| # | Problema | Severidad | Esfuerzo | Prioridad |
|---|----------|-----------|----------|-----------|
| 1 | Facturas sin datos en historial | 🔴 CRÍTICO | MEDIO | **P0 - Urgente** |
| 9.1 | origen_id sin remapear en stock_ledger | 🔴 CRÍTICO | BAJO | **P0 - Urgente** |
| 2 | Marcas duplicadas | 🟡 MEDIO | BAJO | P1 - Alta |
| 3 | Proveedores duplicados por RUC | 🟡 MEDIO | BAJO | P1 - Alta |
| 4 | Productos duplicados | 🟡 MEDIO | MEDIO | P1 - Alta |
| 5 | Fecha inválida permitida | 🟡 MEDIO | BAJO | P2 - Media |
| 6 | UMPs inconsistentes | 🟡 MEDIO | MEDIO | P2 - Media |
| 9.3 | Código duplicado en backup | 🟢 MENOR | MEDIO | P3 - Baja |
| 7 | Proveedores sin contacto | 🟢 MENOR | BAJO | P3 - Baja |
| 8 | Negocio sin datos completos | 🟢 MENOR | BAJO | P3 - Baja |
