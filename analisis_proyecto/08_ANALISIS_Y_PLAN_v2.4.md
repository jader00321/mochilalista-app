# 08 — Análisis Profundo y Plan de Trabajo v2.4
## Correcciones de Interfaz, Marca de Producto, y Auditoría de Regresiones

**Fecha:** 06 de Agosto de 2026  
**Alcance:** Problemas de UI/UX reportados post v2.3 + auditoría de cambios previos (v2.2 y v2.3)

---

## PARTE 1: ANÁLISIS DE PROBLEMAS REPORTADOS

### 🔴 Problema 1 — Ventana "Configura tu Negocio" (Onboarding)

**Archivos Involucrados:**
- [`onboarding_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/screens/onboarding/onboarding_screen.dart)
- [`auth_background.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/widgets/auth_background.dart)

**Diagnóstico:**
El componente `AuthBackground` utiliza un `Stack` donde la cabecera se posiciona con `Positioned(top: padding.top + 20)` y el contenido del formulario se posiciona con `Align(alignment: bottomCenter)` con una altura fija de `size.height * 0.70`. El problema es que en pantallas pequeñas (< 6 pulgadas), el formulario que ocupa el 70% de la pantalla se superpone con el área del header (que incluye el título "Configura tu Negocio" y el subtítulo "Solo te tomará un minuto"), tapando el texto informativo.

**Causa raíz:** La altura del contenido está calculada con un porcentaje fijo (`0.70`) que no se adapta al tamaño de la cabecera. En pantallas pequeñas, el header y el formulario compiten por el mismo espacio vertical.

**Solución Propuesta:**
1. En `auth_background.dart`: Cambiar de un `Stack` con alturas rígidas a un `Column` o `CustomScrollView` que permita que la cabecera y el formulario fluyan de manera natural y secuencial, sin superposición.
2. Alternativamente, convertir todo el `Stack` en un `SingleChildScrollView` con una `Column` donde el header y el formulario sean hermanos verticales. El gradiente decorativo se mantendría con un `Container` posicionado absolutamente en el fondo.
3. Reducir un poco el tamaño de la cabecera en el onboarding para darle más espacio al formulario.

---

### 🔴 Problema 2 — Lógica del Campo de Teléfono (Onboarding)

**Archivo:**
- [`onboarding_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/screens/onboarding/onboarding_screen.dart) — Línea 156-159

**Diagnóstico:**
Actualmente el campo de teléfono usa `TextInputType.phone` pero no tiene ninguna lógica de:
- **Formato visual** (no agrega guiones ni espacios para facilitar la lectura).
- **Validación inteligente** (solo valida que no esté vacío, no valida longitud mínima ni máxima de dígitos reales).
- **Restricción de caracteres** (permite letras ya que no tiene `inputFormatters`).

**Solución Propuesta:**
1. Agregar `inputFormatters` con `FilteringTextInputFormatter.digitsOnly` para restringir a solo dígitos.
2. Añadir un formateador personalizado que vaya insertando espacios cada 3 dígitos (ej: `999 999 999`) para facilitar la lectura.
3. Mejorar el `validator` para que exija un mínimo de 7 y un máximo de 15 dígitos (estándar internacional).
4. Agregar un prefijo visual del código de país seleccionable o fijo según la moneda elegida.

---

### 🔴 Problema 3 — Etiqueta "DUEÑO DE NEGOCIO" en el Home

**Archivo:**
- [`dashboard_header.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/widgets/home/dashboard_header.dart) — Líneas 63-141

**Diagnóstico:**
En la línea 66, se construye la etiqueta `"DUEÑO DE NEGOCIO"` y se muestra en un contenedor fijo al lado del nombre de usuario. Esta etiqueta:
1. Ocupa espacio horizontal valioso que comprime el nombre del usuario.
2. El nombre del usuario ya de por sí está truncado a la primera palabra (`userName.split(' ')[0]` en línea 63), lo cual corta nombres compuestos.
3. La etiqueta "DUEÑO DE NEGOCIO" es redundante dado que en una app offline personal el usuario siempre es el dueño.

**Solución Propuesta:**
1. **Eliminar** la etiqueta "DUEÑO DE NEGOCIO" del Row (solo mantener la etiqueta "MODO INVITADO" cuando aplique).
2. **Cambiar** `userName.split(' ')[0]` por `auth.userName` completo para mostrar el nombre sin truncar.
3. Ajustar el `maxLines` a 2 para nombres largos que necesiten más de una línea.

---

### 🔴 Problema 4 — Ventana de Selección de Perfiles (Usuarios Creados)

**Archivo:**
- [`profile_selection_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/screens/onboarding/profile_selection_screen.dart) — Líneas 149-190

**Diagnóstico:**
Las tarjetas de usuario en la lista de selección de perfiles tienen dos problemas:
1. **Imagen "Sin imagen" por default:** Cuando el negocio no tiene logo, el componente `UniversalImage` muestra un ícono de "imagen no soportada" con el texto "Sin imagen", lo cual se ve poco profesional y genera desconfianza visual.
2. **Diseño simple:** Las tarjetas usan un `ListTile` básico con una estructura minimalista que no transmite la sensación premium de la app.

**Solución Propuesta:**
1. **Reemplazar** el `UniversalImage` cuando no hay logo por un `CircleAvatar` con las iniciales del nombre del negocio estilizadas (patrón común en apps modernas como Gmail, Slack, etc.). Cada negocio tendría un color único derivado de su `id`.
2. **Mejorar el diseño** de la tarjeta con gradientes sutiles, sombras suaves, e indicadores de estado (ej: un ícono de candado si tiene PIN activo, un badge "Activo" verde).
3. **Agregar información adicional** como la fecha de último acceso o la moneda del negocio.

---

### 🔴 Problema 5 — La Marca del Producto NO se Guarda ni se Muestra en Cotizaciones/Ventas

**Archivos Involucrados (RAÍZ DEL PROBLEMA):**
- [`matching_service.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/matching_service.dart) — Línea 41-53
- [`quick_sale_provider.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/providers/quick_sale_provider.dart) — Línea 97, 254, 258

**Diagnóstico Profundo:**
He rastreado **toda la cadena de datos** desde la base de datos hasta la pantalla y encontré lo siguiente:

#### a) El modelo `MatchedProduct` tiene un campo `brand` (tipo `String?`) — ✅ Correcto
#### b) El modelo `QuotationItem` tiene `brandName` — ✅ Correcto  
#### c) El `toQuotationItemJson()` del `MatchingPair` pasa `brand_name: selectedProduct.brand` — ✅ Correcto
#### d) El `quotation_service.dart` guarda `brand_name` en SQLite — ✅ Correcto
#### e) El `QuotationItem.fromJson` lee `json['brand_name']` — ✅ Correcto
#### f) La UI (`quote_item_list_row.dart`) muestra `item.brandName` — ✅ Correcto

**⚠️ ENTONCES ¿DÓNDE ESTÁ EL FALLO?**

El fallo ocurre en los **puntos donde se CREA** el `MatchedProduct`. Hay 3 focos principales:

1. **`matching_service.dart` línea 41-53:** Cuando el sistema de IA hace el match automático, crea un `MatchedProduct` **SIN PASAR el campo `brand`**. El `product.marcaNombre` está disponible (viene del JOIN SQL en `product_queries.dart`), pero simplemente no se incluye en el constructor. **Esta es la raíz principal del problema para cotizaciones por IA.**

2. **`quick_sale_provider.dart` línea 258:** En la función de carga masiva de carrito, pasa `brand: prod.marcaId?.toString()`, lo cual guarda **el ID numérico de la marca** (ej: "3") en vez del **nombre** (ej: "Artesco"). La pantalla de detalle de venta (`sale_history_detail_screen.dart` línea 602) tiene una protección que filtra valores numéricos (`int.tryParse(item['brand_name'].toString()) == null`), por eso la marca no se muestra cuando es un número.

3. **`quick_sale_provider.dart` línea 103:** En la función `addToCart`, se usa `brand: itemWrapper.product.marcaNombre ?? itemWrapper.product.marcaId?.toString()`. Esto es semi-correcto (intentó usar `marcaNombre` primero), pero si por alguna razón `marcaNombre` es null, cae de vuelta al ID numérico.

**Solución Propuesta:**
1. **`matching_service.dart`:** Agregar `brand: product.marcaNombre` en la línea 47 (entre `specificName` y `price`).
2. **`quick_sale_provider.dart` línea 258:** Cambiar `brand: prod.marcaId?.toString()` por `brand: prod.marcaNombre`.
3. **`quick_sale_provider.dart` línea 103:** Cambiar para solo usar `marcaNombre` sin fallback a ID: `brand: itemWrapper.product.marcaNombre`.
4. Asegurarnos de que `image_url` también se pase al `toQuotationItemJson()` y al `toSqlite()` del `QuotationItem` para que las imágenes se persistan correctamente.

---

### 🔴 Problema 6 — Mejorar las Tarjetas de Producto en Detalle/Edición/Venta

**Archivos:**
- [`quote_item_list_row.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/detalle/quote_item_list_row.dart) — Tarjetas en el detalle de cotización
- [`sale_history_detail_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/sale_history_detail_screen.dart) — Tarjetas en historial de venta
- [`sale_client_detail_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/sale_client_detail_screen.dart) — Tarjetas para el cliente

**Diagnóstico:**
- La imagen del producto ya se muestra en `quote_item_list_row.dart` (línea 76-78 con `UniversalImage`), pero NO se guarda la `image_url` en el `toSqlite()` del `QuotationItem` (línea 194-211), lo cual significa que al recargar la cotización, la imagen se pierde.
- En `sale_history_detail_screen.dart` la imagen sí intenta mostrar, pero depende de lo que se haya guardado en el campo de la DB.
- Los campos de marca, unidad, y datos de producto sí están bien renderizados en `quote_item_list_row`, pero la cadena de datos se rompe antes (Problema 5).

**Solución Propuesta:**
1. Agregar `'image_url': imageUrl` en el `toSqlite()` del `QuotationItem`.
2. Verificar que la tabla `smart_quotation_items` tenga una columna `image_url` (de lo contrario, agregar la migración o usar un campo existente).
3. Asegurar que cuando se edita una cotización y se re-guarda, la imagen se preserve.
4. Mejorar visualmente las tarjetas en los 3 archivos con un diseño más consistente y premium.

---

## PARTE 2: AUDITORÍA DE MODIFICACIONES v2.2 y v2.3

### ✅ Cambios v2.2 — Estado: Verificados
| Cambio | Estado | Observación |
|--------|--------|-------------|
| PIN de seguridad | ✅ OK | Se verificó que la detección de PIN existente funciona correctamente |
| Exportación a nube | ✅ OK | Se cambió a `Share` nativo, que funciona sin Google Drive |
| Notificaciones de éxito al crear PIN | ✅ OK | Muestra PIN enmascarado |

### ✅ Cambios v2.3 — Estado: Verificados con Observaciones
| Cambio | Estado | Observación |
|--------|--------|-------------|
| Fix SQL `marcas` (inventario) | ✅ OK | Corrección correcta: `LEFT JOIN marcas m` |
| Opción "Ninguno" en dropdowns | ✅ OK | Funcional para Marca, Categoría, Proveedor |
| `categoriaId` nullable | ✅ OK | Propagado correctamente a service/provider |
| Texto "Eliminar PIN" | ✅ OK | Texto y notificaciones actualizados |

### ⚠️ Regresiones Potenciales Detectadas

1. **`quick_sale_provider.dart` línea 258:** El campo `brand` usa `marcaId?.toString()` (un número como "3") en vez de `marcaNombre` (el nombre como "Artesco"). Esto NO es una regresión nueva — este bug ya existía desde antes de v2.2, pero merece corrección porque rompe la visualización.

2. **`matching_service.dart` línea 41-53:** El `brand` nunca se pasó al `MatchedProduct` en las cotizaciones por IA. Bug preexistente pero no fue detectado por los agentes anteriores.

3. **`toSqlite()` de `QuotationItem`:** No persiste `image_url`. Esto no es una regresión, pero causa que las imágenes no sobrevivan al recargar la cotización.

4. **`sale_history_detail_screen.dart` línea 602:** Tiene un filtro que evita mostrar marcas numéricas (`int.tryParse == null`). Esto es correcto como protección, pero evidencia que el sistema sabe que hay datos incorrectos guardándose (IDs en vez de nombres). Una vez corregidas las fuentes (Problema 5), este filtro seguirá siendo útil como safeguard.

---

## PARTE 3: PLAN DE TRABAJO DETALLADO

### Fase 1 — Correcciones Críticas de Datos (Marca y Imagen)

#### [MODIFY] [`matching_service.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/matching_service.dart)
- Línea 47: Agregar `brand: product.marcaNombre,` al constructor de `MatchedProduct`.

#### [MODIFY] [`quick_sale_provider.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/providers/quick_sale_provider.dart)
- Línea 103: Cambiar a `brand: itemWrapper.product.marcaNombre,`
- Línea 258: Cambiar a `brand: prod.marcaNombre,`

#### [MODIFY] [`smart_quotation_model.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/models/smart_quotation_model.dart)
- En `toSqlite()`: Agregar `'image_url': imageUrl,` para persistir la imagen.

#### [MODIFY] [`quotation_service.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/services/quotation_service.dart)
- Asegurar que `image_url` se guarde al insertar items.

---

### Fase 2 — Interfaz del Onboarding

#### [MODIFY] [`auth_background.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/widgets/auth_background.dart)
- Rediseñar el layout para que use un diseño fluido (scroll) en vez de un `Stack` con alturas rígidas. Esto resolverá el problema de superposición en pantallas pequeñas.
- Mantener el gradiente decorativo como fondo pero sin bloquear la scrollabilidad.

#### [MODIFY] [`onboarding_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/screens/onboarding/onboarding_screen.dart)
- Mejorar el campo de teléfono: agregar `inputFormatters` para solo dígitos, formato de lectura (espacios), validador de longitud (7-15 dígitos).

---

### Fase 3 — Interfaz del Home y Perfiles

#### [MODIFY] [`dashboard_header.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/widgets/home/dashboard_header.dart)
- Eliminar la etiqueta "DUEÑO DE NEGOCIO" (mantener solo "MODO INVITADO" si aplica).
- Cambiar `userName.split(' ')[0]` a `auth.userName` completo.
- Incrementar `maxLines` de 1 a 2 para nombres largos.

#### [MODIFY] [`profile_selection_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/screens/onboarding/profile_selection_screen.dart)
- Reemplazar `UniversalImage` por un `CircleAvatar` con las iniciales del negocio (ej: "ML" para "MochilaLista") cuando no haya logo.
- Mejorar el diseño visual de las tarjetas de perfil (bordes más elegantes, sombras, indicadores de estado).
- Color del avatar calculado dinámicamente desde el `id` del perfil.

---

### Fase 4 — Mejoras Visuales en Tarjetas de Productos

#### [MODIFY] [`quote_item_list_row.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/detalle/quote_item_list_row.dart)
- Verificar y mejorar el diseño de la tarjeta de producto en el detalle de la cotización.
- Asegurar que la imagen se muestre con el placeholder correcto si no existe.

#### [MODIFY] [`sale_history_detail_screen.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/screens/sale_history_detail_screen.dart)
- Asegurar que la marca se muestre correctamente (ahora que la fuente de datos estará arreglada).

---

## PARTE 4: VERIFICACIÓN

### Verificación Automática
- `flutter analyze` para asegurar cero errores rojos.

### Verificación Manual Recomendada
1. Crear un producto con marca → hacer cotización manual → verificar que la marca aparezca en el detalle.
2. Crear cotización por IA → verificar que la marca se muestre en el detalle.
3. Vender una cotización → verificar que la marca y la imagen del producto estén visibles en el historial de ventas.
4. Probar la pantalla de "Configura tu Negocio" en un celular con pantalla pequeña (< 5.5") y confirmar que no se superpone el texto.
5. Verificar que el número de teléfono solo acepte dígitos.
6. Verificar que en el Home se muestre el nombre completo del usuario sin "DUEÑO DE NEGOCIO".
7. Verificar que en la selección de perfiles, los negocios sin logo muestren iniciales en vez de "Sin imagen".

---

## Prioridad de Ejecución

| Prioridad | Fase | Impacto |
|-----------|------|---------|
| 🔴 Alta | Fase 1 (Marca/Imagen) | Sin esto, los datos de marca no se guardan y todas las cotizaciones/ventas se ven incompletas |
| 🟡 Media | Fase 2 (Onboarding) | UI tapada en pantallas pequeñas |
| 🟡 Media | Fase 3 (Home/Perfiles) | Mejoras de legibilidad y diseño |
| 🟢 Baja | Fase 4 (Tarjetas) | Pulido visual final |
