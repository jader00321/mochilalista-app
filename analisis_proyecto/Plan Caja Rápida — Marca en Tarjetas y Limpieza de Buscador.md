# Plan: Caja Rápida — Marca en Tarjetas y Limpieza de Buscador

---

## Diagnóstico Técnico

### Archivos Analizados

| Archivo | Propósito | Líneas Clave |
|---|---|---|
| [`quick_sale_cart_item.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/quick_sale/quick_sale_cart_item.dart) | Widget de la tarjeta de cada producto en el carrito | L38-60, L112-160 |
| [`quick_sale_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/quick_sale_screen.dart) | Pantalla principal con el buscador y el `suffixIcon` | L317-340 |
| [`quick_sale_header.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/quick_sale/quick_sale_header.dart) | Widget de "Datos del Cliente" (no contiene el buscador de productos) | Completo |

### Hallazgo 1: La Marca YA se Calcula, pero se Muestra como Texto Plano

> [!IMPORTANT]
> **Buena noticia:** El widget `quick_sale_cart_item.dart` **ya extrae y calcula la marca** correctamente (líneas 38-46). Obtiene el `brandName` del `InventoryProvider` y tiene una variable `showBrand` (línea 60) que decide si mostrarla o no. El problema **NO** es que la marca no se extrae, sino que **se muestra como un simple texto en MAYÚSCULAS con estilo `indigo`** (líneas 116-125), sin el formato de **badge/etiqueta** que sí aparece en el recibo y en el modal de detalles.
>
> La inconsistencia es puramente **visual/estilística**: el recibo muestra "CAMY" dentro de un chip con fondo coloreado, mientras la tarjeta del carrito lo muestra como texto plano sin fondo.

### Hallazgo 2: El Buscador Solo Tiene UN Icono

> [!NOTE]
> Tras analizar exhaustivamente el código del `suffixIcon` del buscador (líneas 331-340 de `quick_sale_screen.dart`), confirmo que **actualmente solo existe un IconButton**: `Icons.qr_code_scanner`. Lo que puede verse como un "segundo ícono de tres líneas" en la captura es en realidad la composición visual del propio icono `qr_code_scanner` de Material Design, cuyas barras internas simulan un ícono separado. Sin embargo, el ícono `Icons.qr_code_scanner` tiene barras de escaneo integradas que sobresaturan visualmente el campo cuando se combinan con el `Icons.clear` o el `CircularProgressIndicator`.
>
> **El ícono del `endDrawer` ("Nota de Venta") NO está en el buscador**, sino en el `AppBar` principal (línea 279: `Icons.event_note / note_add`).

---

## Plan de Trabajo por Fases

### Fase 1: Consistencia Visual en la Tarjeta de Carrito (Badge de Marca)

#### [MODIFY] [`quick_sale_cart_item.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/quick_sale/quick_sale_cart_item.dart) (Líneas 116-125)

Reemplazar el texto plano de la marca por un **badge/chip estilizado** que coincida con el diseño del recibo:

```diff
                        if (showBrand)
-                          Padding(
-                            padding: const EdgeInsets.only(bottom: 2),
-                            child: Text(
-                              brandName.toUpperCase(), 
-                              style: TextStyle(color: isDark ? Colors.indigo[300] : Colors.indigo[700], fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5),
-                              maxLines: 1,
-                              overflow: TextOverflow.ellipsis,
-                            ),
-                          ),
+                          Container(
+                            margin: const EdgeInsets.only(bottom: 4),
+                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
+                            decoration: BoxDecoration(
+                              color: isDark ? Colors.purple.withValues(alpha: 0.25) : Colors.purple[50],
+                              borderRadius: BorderRadius.circular(6),
+                              border: Border.all(
+                                color: isDark ? Colors.purple.withValues(alpha: 0.4) : Colors.purple.withValues(alpha: 0.3),
+                              ),
+                            ),
+                            child: Text(
+                              brandName.toUpperCase(),
+                              style: TextStyle(
+                                color: isDark ? Colors.purple[300] : Colors.purple[700],
+                                fontWeight: FontWeight.w900,
+                                fontSize: 10,
+                                letterSpacing: 0.5,
+                              ),
+                              maxLines: 1,
+                              overflow: TextOverflow.ellipsis,
+                            ),
+                          ),
```

> **Referencia de diseño:** Se utiliza exactamente el mismo patrón de colores (`purple`) y estructura (`Container` con `BoxDecoration` + `borderRadius: 6`) que ya se usa en el badge "OFERTA" (líneas 147-159) del mismo widget, garantizando coherencia intra-componente.

### Fase 2: Limpieza Visual del Buscador

#### [MODIFY] [`quick_sale_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/quick_sale_screen.dart) (Líneas 331-340)

Dado que solo hay un ícono (`qr_code_scanner`) y no dos, la "limpieza" consistirá en mejorar la **estética y espaciado** del `suffixIcon` para que no se vea sobrecargado:

1. Envolver el ícono del escáner en un `Container` con padding adecuado y separación visual del borde.
2. Asegurar que cuando el `Icons.clear` y el escáner aparecen juntos, la separación sea limpia con un `SizedBox` entre ellos.

```diff
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (searchProv.isSearching) 
                                  Transform.scale(scale: 0.5, child: const CircularProgressIndicator(color: Colors.white))
                                else if (_searchCtrl.text.isNotEmpty) 
                                  IconButton(icon: const Icon(Icons.clear, color: Colors.white), onPressed: () { _searchCtrl.clear(); _searchFocus.requestFocus(); searchProv.clearSearch(); }),
-                               IconButton(icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 26), onPressed: _scanBarcode),
+                               Container(
+                                 margin: const EdgeInsets.only(right: 4),
+                                 decoration: BoxDecoration(
+                                   color: Colors.white.withValues(alpha: 0.15),
+                                   borderRadius: BorderRadius.circular(10),
+                                 ),
+                                 child: IconButton(
+                                   icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 24),
+                                   onPressed: _scanBarcode,
+                                   tooltip: "Escanear código",
+                                 ),
+                               ),
                              ],
                            )
```

---

## Verificación
- **Visual:** Compilar y verificar que la marca aparece como badge/chip en las tarjetas del carrito, coherente con el recibo.
- **Funcional:** Verificar que el escáner sigue funcionando correctamente con su nuevo contenedor.
- `flutter analyze` para confirmar 0 errores.
