# PLAN DE TRABAJO MAESTRO: REINGENIERÍA DEL MOTOR DE SIMILITUD INTELIGENTE, CONTROL DE STOCK (SOBRANTE VS. DÉFICIT) Y SINCRONIZACIÓN EN CLASIFICAR Y CONFIRMAR

**Proyecto:** Mochila Lista — Aplicación Móvil POS / CRM / Analítica (Módulo Escáner IA)  
**Documento:** Plan de Trabajo Detallado, Auditoría Forense y Arquitectura de Solución  
**Ruta:** `analisis_proyecto/PLAN_REINGENIERIA_CLASIFICAR_CONFIRMAR_SIMILITUD_Y_CONTROL_STOCK.md`  
**Metodología:** Loop Autónomo Continuo + Árbitro Interno Adversarial  
**Estado:** Pendiente de Aprobación por el Usuario  

---

## 1. RESUMEN EJECUTIVO Y OBJETIVOS ESTRATÉGICOS

A partir de la inspección exhaustiva del código fuente del módulo de escáner (`lib/features/scanner/`) y del análisis forense de las **5 capturas de pantalla reales adjuntas** tomadas durante pruebas profundas en la ventana **`Clasificar y Confirmar`** y en el modal **`Control de Variante`**, se ha detectado una triple desconexión funcional y matemática:

1. **Falsos Positivos de Alerta en el Motor de Similitud (`Imágenes 4 y 5`):**
   * El sistema vincula correctamente el producto padre con su variante en inventario, pero dispara advertencias intrusivas de **`⚠️ ⚠️ Similitud parcial (73%)`** o **`(55%)`** en ítems que son **100% idénticos** al inventario (`Bloques Lógicos - Nº 7 Taper Grueso`, `Fomi Escarchado - 100cm x 100cm`, `Bloques de Construcción - MDJ049`).
   * **Causa raíz:** El comparador actual evalúa la descripción completa de la factura únicamente contra el campo `producto.nombre`. Por tanto, los tokens correspondientes a la **variante** (`N° 7 Taper Grueso`, `100cm x 100cm`), la **marca** (`Edukt Plastic`) o las **medidas** penalizan severamente el score de similitud. Además, carece de normalización de abreviaturas comerciales en Perú (`No`, `Nro`, `Num`, `N°`, `#`, medidas `100cm x 100cm`) y de **Prefix Stemming** para palabras recortadas por imprenta POS (`ESCARCH` $\rightarrow$ `Escarchado`, `LATINOAM` $\rightarrow$ `Latinoamericana`, `CONSTR` $\rightarrow$ `Construcción`). Visualmente, el banner duplica el icono (`⚠️ ⚠️`) y carece de botones de confirmación rápida (`"✓ Sí es el mismo"`) o de re-búsqueda (`"🔍 Buscar otro"`).
2. **Contradicción Matemática Aberrante de Stock Sobrante vs. Déficit en `Control de Variante` (`Imágenes 2 y 3`):**
   * En `Gestión de Stock` (`Imagen 3`), un producto tiene **4 unid. base en inventario actual**, ingresan **4 unid. base de la factura** y el modo es **`Sumar al Existente`**. El factor de venta configurado en `Venta y Precios` (`Imagen 2`) es **`½ Docena` (factor 6)**.
   * El recuadro verde suma correctamente $4 + 4 = 8\text{ unid. base}$, calcula $8 \div 6$ y muestra orgulloso: **`1 ½ Docena + 2 unid. sueltas`**.
   * **¡Sin embargo, el cuadro inferior rojo dice textualmente:** `❗ Déficit detectado: El lote de compra (4 unid.) no alcanza para formar 1 paquete de ½ Docena (x6). Faltan 2 unidades`!
   * Y para empeorar la confusión, en `Venta y Precios` (`Imagen 2`), el recuadro dice: `Stock Físico Base: 4 unid. | Disponible en Venta: 0 ½ Docenas` (ignorando completamente las unidades ya existentes en base de datos).
   * **Causa raíz:** Cada sección y widget calcula su propio stock de forma aislada e inconsistente. El validador de déficit utiliza únicamente el lote de la factura ignorando el inventario previo, confundiendo un **sobrante vendible** ($8$ unidades totales $= 1$ paquete completo $+ 2$ unidades sueltas) con un **déficit**.
3. **Desincronización de Avisos y Bloqueo Inflexible en `Clasificar y Confirmar` (`Imagen 1`):**
   * Tras guardar una decisión en `Control de Variante` (cambiando la unidad de venta a `½ Docena`), la tarjeta principal de la ventana madre sigue mostrando `Se venderá por: Unidad (x1)` y `Stock cuadra perfectamente`, mientras que el botón inferior principal se bloquea en naranja con la leyenda **`VER ERRORES DE STOCK`**.
   * La tarjeta madre no expone con claridad si sobran o faltan unidades ni provee botones de acción rápida en 1 toque (ej. enviar el sobrante a una variante unitaria o adaptar la unidad).
   * Al pulsar el botón inferior de errores, el usuario no es llevado a la tarjeta causante ni se le resalta visualmente cuál de los múltiples productos presenta el conflicto.

```
┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                        ARQUITECTURA OBJETIVO DEL SISTEMA CLASIFICAR Y CONFIRMAR                        │
├───────────────────────────────┬───────────────────────────────┬────────────────────────────────────────┤
│ 1. MOTOR MULTI-CAMPO Y        │ 2. BASE ÚNICA DE VERDAD:      │ 3. SINCRONIZACIÓN REACTIVA             │
│    SIMILITUD INTELIGENTE      │    STOCK SOBRANTE VS DÉFICIT  │    Y ACCIONES RÁPIDAS EN TARJETAS      │
├───────────────────────────────┼───────────────────────────────┼────────────────────────────────────────┤
│ • ScannerMatchingEngine:      │ • TotalBaseResultante unificado:│ • VariantEditorRow actualizado con los │
│   Evaluación contra:          │   (Sumar: BD + Factura)       │   valores guardados vigentes           │
│   [Nombre + Variante +        │   (Reemplazar: Factura)       │   (no los estáticos de BD).            │
│    Marca + SKU].              │   (Nuevo: Factura).           │ • Banner de Similitud limpio:          │
│ • CommercialNormalizer PE:    │ • Caso SOBRANTE (Pkgs >= 1,   │   Icono único + Identidad completa +   │
│   Prefix Stemming (>= 5 let): │   Sueltas > 0):               │   [✓ Sí es el mismo] + [🔍 Buscar].    │
│   ESCARCH -> Escarchado       │   - Jamás rotular como déficit│ • Bloque de Alerta/Acción en Tarjeta:  │
│   Símbolos: N°, No, Nro -> n  │   - [➕ Enviar a Unidad x1]   │   [➕ Crear/Sumar Unidad x1]           │
│   Medidas: 100cm x 100cm      │   - [🔄 Divisor exacto]       │   [✓ Conservar en reserva]             │
│ • Scoring multi-campo:        │   - [📥 Conservar en reserva] │   [⚡ Adaptar unidad / Corregir].       │
│   Si tokens se justifican en  │ • Caso DÉFICIT REAL (Pkgs == 0):│ • Botón VER ERRORES DE STOCK (X):    │
│   nombre + variante + marca,  │   - Alerta roja real          │   Auto-scroll a la 1ra tarjeta con     │
│   score sube a >= 90%.        │   - [⚡ Adaptar unidad]        │   conflicto + pulso visual animado.    │
└───────────────────────────────┴───────────────────────────────┴────────────────────────────────────────┘
```

---

## 2. DIAGNÓSTICO FORENSE LÍNEA POR LÍNEA Y ANÁLISIS DE EVIDENCIAS

### 2.1. Bloque 1: Motor de Comparación y Similitud Parcial Errónea (`Imágenes 4 y 5`)

* **Archivos Involucrados:**
  * `app_movil/lib/features/scanner/services/scanner_matching_engine.dart` (Líneas 63–140, 170–245, 388–456)
  * `app_movil/lib/features/scanner/services/spanish_lemmatizer.dart` (Líneas 1–84)
  * `app_movil/lib/features/scanner/widgets/staging/staging_product_group_card.dart` (Líneas 583–658)

* **Evidencias en Capturas 4 y 5:**
  * **Imagen 4 (`5:19 AM`):** Factura indica `"BLOQUES LOGICOS No 7 TAPER (GRUESO)"`. Inventario muestra solo `"Bloques Lógicos"`, cuando el producto en inventario ya tiene la variante **`N° 7 Taper Grueso`**. El sistema marca **`Similitud parcial (73%) — Verificar`**.
  * **Imagen 5 (`5:19 AM`):** Factura indica `"FOMI ESCARCH 100cm x 100cm"`. Inventario muestra solo `"Fomi Escarchado"`, cuando el producto en inventario ya tiene la variante **`100cm x 100cm`**. El sistema marca **`Similitud parcial (55%) — Verificar`**.
  * **Caso Bloques de Construcción:** Factura indica `"BLOQUES CONSTRUCCION EDUKT PLASTIC"`. Inventario tiene el producto `"Bloques de Construcción"`, su marca es `"Edukt Plastic"` y su variante es `"MDJ049"`. El sistema marca **`60%`**.
  * **Icono Duplicado:** En ambas capturas se aprecia `⚠️ ⚠️ Similitud parcial...` (un icono widget de Flutter y un emoji `⚠️` hardcodeado en la cadena de texto).

* **Causa Raíz en Código:**
  1. En `scanner_matching_engine.dart:118-123`:
     ```dart
     // 1. Nombre Principal (50% max) -> _calculateSimilarity returns 0-100.
     int nameSim = _calculateSimilarity(
       searchName,
       candidate['nombre'] as String,
     );
     score += (nameSim * 0.50).toInt();
     ```
     `searchName` es `item.productoPadreEstimado ?? item.descripcion`. En facturas electrónicas del Perú, la glosa del producto viene unificada: `"FOMI ESCARCH 100cm x 100cm"`. El código toma toda esa glosa y la compara **únicamente** contra `candidate['nombre']` (`"Fomi Escarchado"`).
     `tokensA`: `["fomi", "escarch", "100cm", "x", "100cm"]` (5 tokens).
     `tokensB`: `["fomi", "escarchado"]` (2 tokens).
     Como 3 de los 5 tokens de la factura corresponden en realidad a la variante (`100cm x 100cm`) y uno viene abreviado (`ESCARCH`), el ratio `matchingTokenCount / tokensA.length` se derrumba, activando además la penalización por "baja cobertura" de las líneas 442–446 (`baseScore * 0.4`), arrojando un paupérrimo `55%` o `73%`.
  2. En `scanner_matching_engine.dart:172-184`:
     La variante se evalúa después de manera aislada (`variantToMatch = item.varianteDetectada ?? item.descripcion`), pero los tokens de la variante ya destruyeron la puntuación del nombre padre. **No existe una evaluación de cobertura holística o multi-campo.**
  3. En `spanish_lemmatizer.dart`:
     No existe soporte para abreviaturas comerciales comunes en Perú:
     * Abreviaturas de numeración: `"No"`, `"Nro"`, `"Num"`, `"N°"`, `"#"` no se normalizan al estándar unificado `"n"`.
     * Formatos de dimensiones: `"100cm x 100cm"`, `"100 x 100 cm"`, `"100x100 cm"` se procesan como tokens dispares.
     * Carencia de **Prefix Stemming**: Si una palabra tiene $\ge 5$ caracteres (como `"ESCARCH"` de 7 letras o `"LATINOAM"` de 8 letras), debe compararse contra el prefijo de palabras del inventario (`"Escarchado"`, `"Latinoamericana"`). Si `palabraLargaInventario.startsWith(tokenFactura)`, la similitud debe ser del 100%.
  4. En `staging_product_group_card.dart:606-616`:
     ```dart
     Icon(
       isLow ? Icons.error_outline : Icons.warning_amber_rounded,
       color: isDark ? color[300] : color[800],
       size: 20,
     ),
     const SizedBox(width: 8),
     Expanded(
       child: Text(
         isLow
             ? "⚠️ Similitud baja ($confianza%) — Verificar"
             : "⚠️ Similitud parcial ($confianza%) — Verificar",
     ```
     El icono de Flutter se dibuja junto a un emoji `⚠️` en el texto, generando la duplicación visual `⚠️ ⚠️`. Además, la tarjeta solo ofrece el botón `"No es el mismo — Desvincular"`, omitiendo la acción más frecuente: confirmar que sí es el producto correcto o buscar un reemplazo inmediato.

---

### 2.2. Bloque 2: Contradicción Matemática en Control de Variante (`Imágenes 2 y 3`)

* **Archivos Involucrados:**
  * `app_movil/lib/features/scanner/widgets/staging/comparative_modal/ui/modal_stock_section.dart` (Líneas 52–186, 236–292, 302–395)
  * `app_movil/lib/features/scanner/widgets/staging/comparative_modal/ui/modal_sale_section.dart` (Líneas 11–17, 136–167)
  * `app_movil/lib/features/scanner/widgets/staging/comparative_modal/comparative_update_modal.dart` (Líneas 484–533, 535–557)
  * `app_movil/lib/core/services/unit_catalog_service.dart` (Líneas 163–193)

* **Evidencias en Capturas 2 y 3:**
  * **Imagen 3 (`5:21 AM` - Gestión de Stock):**
    * En Inventario Actual: **`4 unid. base`** ($= 0\text{ ½ Docenas}$).
    * Nuevo Ingreso Factura: **`4 unid. base`** ($= +0\text{ ½ Docenas}$).
    * Operación seleccionada: **`⊕ Sumar al Existente`**.
    * Recuadro verde superior: **`1 ½ Docena + 2 unid. sueltas`** (Total físico: 8 unid. base $\div$ factor 6).
    * Recuadro rojo inferior: **`❗ Déficit detectado: El lote de compra (4 unid.) no alcanza para formar 1 paquete de ½ Docena (x6). Faltan 2 unidades.`**
  * **Imagen 2 (`5:22 AM` - Venta y Precios):**
    * Configuración: `U. Venta`: **`½ Docena`**, `Factor V.`: **`6`**.
    * Recuadro de Stock: **`Stock Físico Base: 4 unid. | Disponible en Venta: 0 ½ Docenas`**.

* **Causa Raíz en Código:**
  1. En `modal_stock_section.dart:303-314`:
     ```dart
     int factor = _activeFactorVenta;
     double cantComprada = double.tryParse(_cantidadUmpCtrl.text) ?? widget.variant.cantidadUmpComprada;
     int unidLote = int.tryParse(_unidLoteCtrl.text) ?? widget.variant.unidadesPorLote;
     
     int totalUnidadesBase = int.tryParse(_stockIngresanteCtrl.text) ?? (cantComprada * unidLote).toInt();
     
     var validation = UnitCatalogService.validateStockForUnit(
       totalUnitsBase: totalUnidadesBase,
       presentationFactor: factor,
       baseUnitCost: 0.0, 
       unitName: _activeUnidadVenta,
     );
     ```
     ¡`_buildLeftoverWarning()` calcula la validación pasando en `totalUnitsBase` exclusivamente `_stockIngresanteCtrl.text` ($4$ unidades)!
     Ignora por completo el stock que ya existe en inventario (`stockBD = 4`) y la variable `isSumar`. Al recibir $4$ unidades con un factor de $6$, `UnitCatalogService.validateStockForUnit` calcula $4 \div 6 = 0$ paquetes enteros y residuo de $4$, clasificándolo erróneamente como `StockValidationStatus.deficit` con un faltante de $2$ unidades.
  2. En `modal_sale_section.dart:11-16`:
     ```dart
     double cantComprada = double.tryParse(_cantidadUmpCtrl.text) ?? widget.variant.cantidadUmpComprada;
     int unidPorLote = int.tryParse(_unidLoteCtrl.text) ?? widget.variant.unidadesPorLote;
     int totalUnidadesBase = (cantComprada * unidPorLote).toInt();
     
     int factorVenta = _activeFactorVenta;
     int stockFinal = factorVenta > 0 ? (totalUnidadesBase ~/ factorVenta) : 0;
     ```
     La sección `Venta y Precios` vuelve a calcular `totalUnidadesBase` de manera aislada basándose únicamente en la compra de la factura ($4$), ignorando la existencia de inventario previo en SQLite y el modo de suma. Muestra `Stock Físico Base: 4 unid.` y `Disponible en Venta: 0 ½ Docenas`.

---

### 2.3. Bloque 3: Desincronización y Bloqueo en Clasificar y Confirmar (`Imagen 1`)

* **Archivos Involucrados:**
  * `app_movil/lib/features/scanner/widgets/staging/variant_editor_row.dart` (Líneas 420–475)
  * `app_movil/lib/features/scanner/providers/scanner_provider.dart` (Líneas 97–137, 669–725)
  * `app_movil/lib/features/scanner/screens/invoice_staging_screen.dart` (Líneas 206–246, 662–708)

* **Evidencias en Captura 1:**
  * **Imagen 1 (`5:22 AM`):**
    * Tarjeta `Biblia Latinoamericana - Latinoamericana`: El usuario acaba de guardar en `Control de Variante` la presentación `½ Docena (x6)`.
    * Sin embargo, la tarjeta madre sigue diciendo: `Se venderá por: Unidad (x1)` e `Ingresarán al Stock: +4 Unid.` con el badge verde `Stock cuadra perfectamente`.
    * El botón principal inferior está en color naranja diciendo: **`VER ERRORES DE STOCK`**.
    * Al usuario no se le indica en la tarjeta cuál es el conflicto ni se le ofrecen botones para resolverlo.

* **Causa Raíz en Código:**
  1. En `variant_editor_row.dart:430-452`:
     ```dart
     Text(
       "Se venderá por: ${widget.variant.matchPresentacion.datos?.unidadVenta ?? 'Unidad'} (x${widget.variant.matchPresentacion.datos?.unidadesPorVenta ?? 1})", 
       style: ...
     ),
     ...
     var validation = UnitCatalogService.validateStockForUnit(
       totalUnitsBase: totalUnidadesBase,
       presentationFactor: widget.variant.matchPresentacion.datos?.unidadesPorVenta ?? 1,
       baseUnitCost: costoBaseIndiv,
       unitName: widget.variant.matchPresentacion.datos?.unidadVenta ?? 'Unidad',
     );
     ```
     La tarjeta madre lee de `widget.variant.matchPresentacion.datos?.unidadesPorVenta` (los datos congelados de SQLite que decían `Unidad x1`), en lugar de leer de `widget.variant.unidadesPorVenta` y `widget.variant.unidadVenta` (los campos editados y confirmados en el modal). Por ende, la tarjeta madre muestra `Unidad (x1)` y cree que cuadra al 100%, mientras que el provider global sabe que la variante tiene factor 6 y bloquea la pantalla.
  2. En `scanner_provider.dart:103-134` (`hasUnresolvedStock`):
     ```dart
     int totalUnidadesBase = v.stockIngresanteOverride ?? (v.cantidadUmpComprada * v.unidadesPorLote).toInt();
     ```
     El validador global tampoco toma en cuenta el inventario previo (`stockBD`) cuando la operación es `sumar`. Además, cuando hay sobrantes (`StockValidationStatus.hasLeftover`), exige estrictamente que existan variantes hijas que absorban el 100% del sobrante. Si el usuario desea mantener esas unidades en reserva o venderlas como fracciones, el sistema no tiene ningún mecanismo para registrar ese consentimiento y bloquea permanentemente el botón de guardado.
  3. En `invoice_staging_screen.dart:662-708`:
     Al pulsar `VER ERRORES DE STOCK`, se abre un modal pasivo que lista los errores, pero **no realiza auto-scroll a la lista de tarjetas**, ni resalta la tarjeta conflictiva, obligando al usuario a recorrer manualmente una factura que puede tener decenas de renglones.

---

## 3. ARQUITECTURA TÉCNICA Y REGLAS DE NEGOCIO MATEMÁTICAS INDESTRUCTIBLES

### 3.1. Reestructuración del Motor de Matching y Similitud Multi-Campo

#### A. Evaluación Multi-Campo Compuesta (`Composite Multi-Field Scoring`)
En las facturas peruanas, un renglón es una concatenación de datos: `[Nombre del Producto] + [Variante / Medida / Color] + [Marca] + [Código / SKU]`.
Para evitar que la presencia de la variante o marca castigue la similitud del nombre:
1. Se tokeniza la descripción completa de la factura: $T_{\text{factura}} = \{t_1, t_2, \dots, t_n\}$.
2. Para cada producto candidato en SQLite, se construye su **universo léxico**:
   * $T_{\text{padre}} = \text{tokens}(p.\text{nombre})$
   * $T_{\text{variantes}} = \bigcup_{v \in \text{variantes}} \text{tokens}(v.\text{nombre\_especifico} \cup v.\text{unidad\_venta})$
   * $T_{\text{marca}} = \text{tokens}(m.\text{nombre})$
   * $T_{\text{sku}} = \text{tokens}(p.\text{codigo\_barras} \cup v.\text{codigo\_barras})$
   * $U_{\text{producto}} = T_{\text{padre}} \cup T_{\text{variantes}} \cup T_{\text{marca}} \cup T_{\text{sku}}$
3. Se calcula la **cobertura de tokens de la factura**:
   $$\text{Cobertura} = \frac{|T_{\text{factura}} \cap U_{\text{producto}}|}{|T_{\text{factura}}|}$$
   * Si todos los tokens de la factura se justifican entre el nombre del producto, sus variantes y su marca (como en `"BLOQUES LOGICOS No 7 TAPER (GRUESO)"` donde `"Bloques Lógicos"` es el padre y `"N° 7 Taper Grueso"` es la variante en BD), la cobertura es del **100%**.
   * El score final será una combinación ponderada con bonificación de coincidencia de variante:
     $$\text{Score} = (\text{Similitud}(NombrePadre) \times 0.45) + (\text{MatchVariante} \times 0.35) + (\text{MatchMarca} \times 0.20) + \text{BonusCobertura}(15)$$
   * Esto elevará la confianza de estos casos de **55%–73% a más de 92%**, eliminando falsas alarmas.

#### B. Normalizador Comercial de Facturación Peruana (`CommercialInvoiceNormalizer`)
Se implementará un componente especializado que preprocesa tokens:
1. **Normalización de Símbolos y Abreviaturas:**
   * Numeraciones: `["no", "nro", "num", "n°", "#", "n."]` $\longrightarrow$ `"n"`
   * Medidas y dimensiones: `"100cm x 100cm"`, `"100 x 100 cm"`, `"100x100 cm"` $\longrightarrow$ `"100x100cm"`
   * Empaques y unidades: `"und"`, `"unid"`, `"uni"` $\longrightarrow$ `"unidad"`; `"doc"`, `"dzn"` $\longrightarrow$ `"docena"`; `"pq"`, `"pqt"`, `"paq"` $\longrightarrow$ `"paquete"`.
2. **Prefix Stemming para Palabras Truncadas ($\ge 5$ letras):**
   * En puntos de venta e impresiones matriciales, las palabras se cortan por límite de columnas: `"ESCARCH"`, `"LATINOAM"`, `"CONSTR"`.
   * Si un token tiene $\ge 5$ caracteres y coincide con el inicio de una palabra del inventario (`"escarchado".startsWith("escarch")`), se considera **coincidencia exacta (100%)**.

#### C. Rediseño del Banner de Similitud en Tarjeta
1. **Iconografía Limpia:** Eliminar el emoji `⚠️` del texto para dejar únicamente el `Icon(Icons.warning_amber_rounded)` nativo.
2. **Identidad Completa:** Mostrar la variante detectada:
   `Inventario: "Bloques Lógicos • Var: N° 7 Taper Grueso"`.
3. **Acciones Rápidas:**
   * **`[✓ Sí es el mismo]`**: Marca `isMatchVerified = true`, eleva la confianza visual al 100% y colapsa/oculta la advertencia.
   * **`[🔍 Buscar otro]`**: Abre inmediatamente el modal `ManualProductSearch` para reasignar el producto sin pasos intermedios.
   * **`[🔗 Desvincular]`**: Desvincula el ítem para tratarlo como producto nuevo.

---

### 3.2. Reglas Matemáticas Indestructibles de Stock (Base Única de Verdad)

#### Regla 1 — Base Única de Verdad (`totalUnidadesBaseResultantes`)
Todos los componentes (`modal_stock_section.dart`, `modal_sale_section.dart`, `variant_editor_row.dart`, `scanner_provider.dart`) deben consultar el mismo getter centralizado en `StagingVariant`:

$$\text{stockIngresanteBase} = \text{stockIngresanteOverride} \;\;?\?\;\; (\text{cantidadUmpComprada} \times \text{unidadesPorLote}).\text{toInt}()$$

$$\text{totalBaseResultante} = \begin{cases} 
\text{stockActualBD} + \text{stockIngresanteBase} & \text{si es variante existente y modo = 'sumar'} \\
\text{stockIngresanteBase} & \text{si es variante existente y modo = 'reemplazar'} \\
\text{stockIngresanteBase} & \text{si es producto nuevo o nueva variante ('+ Crear Nueva')}
\end{cases}$$

A partir de $\text{totalBaseResultante}$ y el $\text{factorVenta}$:
* $\text{presentacionesCompletas} = \text{totalBaseResultante} \sim/ \text{factorVenta}$
* $\text{unidadesSobrantes} = \text{totalBaseResultante} \;\%\; \text{factorVenta}$

#### Regla 2 — Caso SOBRANTE (`presentacionesCompletas >= 1` y `unidadesSobrantes > 0`)
*(Ejemplo de Captura 3: 4 actuales + 4 nuevas = 8 unid. base totales con Factor 6 $\rightarrow$ 1 ½ Docena y sobran 2 unid.)*
* **Prohibición:** Jamás rotular como "Déficit".
* **Mensaje:** `"⚠️ Atención: Sobran 2 unidades base sueltas fuera de ½ Docena (x6)"`.
  `"Con las 8 unid. totales se forma 1 ½ Docena (6 unid.) y quedan 2 unidades sueltas que no alcanzan para otra ½ Docena."`
* **Acciones de 1 toque (el usuario decide):**
  1. **`[➕ Enviar 2 unid. a variante 'Unidad (x1)']` (Recomendada):**
     * Si el grupo ya posee una variante con factor 1 (ej: `Unidad`), le transfiere las 2 unidades a su ingreso con costo proporcional.
     * Si no existe, crea una nueva variante `Unidad (x1)` con las 2 unidades sobrantes.
     * La variante principal queda con las 6 unidades base exactas para formar 1 ½ Docena.
  2. **`[🔄 Divisores Exactos]`:** Chips sugeridos que dividan exactamente las 8 unidades: `[Unidad (x1) -> 8 unid.]`, `[Par (x2) -> 4 pares]`, `[Pack (x4) -> 2 packs]`.
  3. **`[📥 Conservar en reserva base]`:** Botón/switch explícito que marca `allowLeftoverInReserve = true`. Permite registrar las 8 unidades en esta variante sabiendo que 2 quedan como reserva para compras futuras, **desbloqueando el guardado**.

#### Regla 3 — Caso FALTANTE / DÉFICIT REAL (`presentacionesCompletas == 0`, es decir `totalBase < factorVenta`)
*(Ejemplo: Total base 4 unidades y Factor 6 $\rightarrow$ 0 paquetes posibles).*
* **Alerta Crítica:** `"🚨 Stock Insuficiente: No alcanza para 1 [Unidad de Venta] (x[Factor])"`.
* **Acciones de 1 toque:**
  1. **`[⚡ Adaptar a Unidad (x1)]`:** Cambia el factor a 1 de inmediato (`4 Unidades`).
  2. **`[✏️ Completar lote a 1 paquete (6 unid.)]`:** Ajusta el ingreso de compra a 6 unidades base con costo prorrateado.
  3. **`[🔓 Autorizar registro en 0]`:** Switch consciente que marca `allowDeficitApproved = true`, permitiendo registrar las 4 unidades base acumuladas en espera de una compra posterior.

#### Regla 4 — Sincronización en `Venta y Precios`
En `modal_sale_section.dart`:
* **`Stock Base Total: 8 unid.`**
* **`Disponible para Venta: 1 ½ Docena (+2 sueltas)`**
Eliminando cualquier cifra de `0 ½ Docenas` cuando en realidad hay mercadería vendible.

---

### 3.3. Sincronización Total en `Clasificar y Confirmar` y Navegación Inteligente

#### A. Persistencia Inmediata tras `GUARDAR DECISIÓN`
Al pulsar `GUARDAR DECISIÓN` en el modal:
1. Se transfieren a `widget.variant` los valores de `unidadVenta`, `unidadesPorVenta`, `stockOperation`, `stockIngresanteOverride`, `allowLeftoverInReserve` y `allowDeficitApproved`.
2. Se marca `variant.updateUnidadVenta = true`.
3. `VariantEditorRow` lee directamente de `variant.unidadVenta` y `variant.unidadesPorVenta`, reflejando al milisegundo la unidad de venta real configurada (`½ Docena x6`).

#### B. Panel de Alerta y Solución Rápida Directamente en la Tarjeta Madre
Tanto para productos vinculados (`EN INVENTARIO`) como para productos nuevos (`NUEVO PRODUCTO`):
* Si una variante tiene sobrante:
  La tarjeta muestra un banner naranja estilizado:
  `⚠️ Sobran X unid. sueltas fuera de [Unidad] (x[Factor])`
  Con dos botones directos:
  `[ ➕ Enviar X a Unidad (x1) ]`  `[ ✓ Aceptar en reserva ]`
* Si una variante tiene déficit:
  La tarjeta muestra un banner rojo:
  `🚨 Stock total (X unid.) no alcanza para 1 [Unidad] (x[Factor])`
  Con botones directos:
  `[ 🔄 Cambiar a Unidad (x1) ]`  `[ ⚙️ Corregir en Control de Variante ]`

#### C. Comportamiento Inteligente del Botón `VER ERRORES DE STOCK (X)`
1. El botón inferior muestra el conteo exacto de inconsistencias: `VER ERRORES DE STOCK (2)`.
2. Al presionarlo:
   * Identifica el índice del primer producto con error de stock no resuelto.
   * Ejecuta un **auto-scroll suave** (`_scrollController.animateTo(...)` o `Scrollable.ensureVisible`).
   * Activa una **animación de resaltado (pulso visual de borde naranja/rojo por 1.5 segundos)** en la tarjeta objetivo.
   * Muestra un snackbar discreto: `"Mostrando ítem 1 de 2 con observación de stock"`.

---

## 4. PLAN DE TRABAJO PASO A PASO POR FASES

### Fase 1: Perfeccionamiento del Motor de Similitud y Normalizador Comercial
* **Objetivo:** Erradicar falsas alertas de similitud parcial (73%, 55%, 60%) en productos idénticos y limpiar la interfaz del banner.
* **Acciones:**
  1. Crear `lib/features/scanner/services/commercial_invoice_normalizer.dart` con soporte de abreviaturas peruanas, unificación de medidas y prefix stemming ($\ge 5$ letras).
  2. Modificar `scanner_matching_engine.dart` para implementar el algoritmo de coincidencia multi-campo compuesto (`Nombre + Variante + Marca + SKU`), otorgando bonificaciones de cobertura global.
  3. Actualizar `staging_product_group_card.dart`:
     - Retirar el emoji duplicado `⚠️` del texto del banner.
     - Mostrar la identidad completa de inventario con variante (`Inventario: "Bloques Lógicos • Var: N° 7 Taper Grueso"`).
     - Incorporar botones `[✓ Sí es el mismo]` y `[🔍 Buscar otro en inventario]`.
     - Añadir propiedad `isMatchVerified` a `StagingProductGroup`.

### Fase 2: Unificación Matemática del Stock (Base Única de Verdad)
* **Objetivo:** Unificar la fórmula de stock en todos los widgets y erradicar contradicciones en `Control de Variante`.
* **Acciones:**
  1. Extender `StagingVariant` en `scanner_models.dart`:
     - Añadir getter `int calculateTotalUnitsBase({required int stockActualBD})`.
     - Añadir campos `bool allowLeftoverInReserve` y `bool allowDeficitApproved`.
  2. Modificar `modal_stock_section.dart`:
     - Hacer que `_buildLeftoverWarning()` use la Base Única de Verdad (`stockFinalResultante`).
     - Separar tajantemente la lógica de **Sobrante** (`presentaciones >= 1`, `sobrante > 0`) de la de **Déficit Real** (`presentaciones == 0`, `sobrante > 0`).
  3. Modificar `modal_sale_section.dart`:
     - Calcular `Stock Físico Base` y `Disponible en Venta` utilizando `stockFinalResultante`. Mostrar `1 ½ Docena (+2 sueltas)`.

### Fase 3: Opciones de 1 Toque para Sobrante y Faltante
* **Objetivo:** Proveer soluciones directas e intuitivas sin atrapar al usuario.
* **Acciones:**
  1. En `modal_stock_section.dart`:
     - **Para Sobrantes:** Implementar el botón `[➕ Enviar a variante Unidad (x1)]` (que busca variante x1 existente o crea una nueva con costo proporcional), chips de divisores exactos y botón `[📥 Conservar en reserva]`.
     - **Para Déficit:** Implementar `[⚡ Adaptar Unidad a disponible]`, `[✏️ Completar lote a 1 paquete]` y `[🔓 Autorizar registro en 0]`.
  2. En `scanner_provider.dart`:
     - Refactorizar `createLeftoverVariant`: si ya existe una variante con factor 1 en el grupo, sumarle el stock suelto en vez de duplicar variantes inútilmente.
     - Actualizar `hasUnresolvedStock`: si `allowLeftoverInReserve == true` o `allowDeficitApproved == true`, no considerarlo error.

### Fase 4: Sincronización en Clasificar y Confirmar y Auto-Scroll Inteligente
* **Objetivo:** Sincronizar las tarjetas de la pantalla madre y guiar al usuario directamente al error.
* **Acciones:**
  1. En `variant_editor_row.dart`:
     - Corregir el binding para que lea `widget.variant.unidadVenta` y `widget.variant.unidadesPorVenta` vigentes.
     - Implementar el bloque de alerta y acciones rápidas directamente en la tarjeta (tanto para productos en inventario como para nuevos).
  2. En `invoice_staging_screen.dart`:
     - Actualizar el botón inferior `VER ERRORES DE STOCK (X)` con el contador dinámico.
     - Al presionarlo, buscar el primer `GlobalKey` o índice con error, realizar auto-scroll animado y activar destello de pulso en la tarjeta.

### Fase 5: Pruebas Automatizadas y Validación Integral
* **Objetivo:** Garantizar 0 regresiones y validar exhaustivamente los casos de las 5 capturas.
* **Acciones:**
  1. Crear `app_movil/test/scanner_similarity_and_stock_refinement_test.dart`.
  2. Probar tests unitarios de matching multi-campo:
     - `"BLOQUES LOGICOS No 7 TAPER (GRUESO)"` vs `"Bloques Lógicos" [N° 7 Taper Grueso]`.
     - `"FOMI ESCARCH 100cm x 100cm"` vs `"Fomi Escarchado" [100cm x 100cm]`.
     - `"BLOQUES CONSTRUCCION EDUKT PLASTIC"` vs `"Bloques de Construcción" [Edukt Plastic / MDJ049]`.
  3. Probar tests de stock sobrante vs déficit:
     - Stock BD: 4, Ingreso: 4, Modo: Sumar, Factor: 6 $\rightarrow$ Total: 8, 1 paquete, 2 sueltas $\rightarrow$ Estado: Sobrante (NO Déficit).
     - Comprobar que al pulsar "Conservar en reserva", `hasUnresolvedStock` sea `false`.
     - Comprobar que al pulsar "Enviar a Unidad x1", se cree/asigne la variante de 2 unidades y la principal quede en 6.
  4. Ejecutar `flutter analyze` y asegurar cero advertencias o errores.

---

## 5. PROTOCOLOS DE AUDITORÍA DEL ÁRBITRO INTERNO ADVERSARIAL

El Árbitro Interno Adversarial someterá la solución a pruebas extremas antes de dar la tarea por concluida:

1. **Prueba de Resistencia de Tokens Incompletos y Abreviados:**
   * ¿Qué sucede si la factura dice `"B. LOGICOS N7 TAPER GRU"`? El normalizador debe resolver abreviaturas de 1 o 2 letras reconocidas y prefijos sin lanzar excepciones.
2. **Prueba de Invarianza de Costo al Crear Variante Sobrante:**
   * Al transferir 2 unidades sobrantes a la variante `Unidad (x1)`, ¿el costo total de la factura sigue cuadrando al céntimo? (Verificar que `costoUnitario * unidadesTransferidas` no altere el costo de la factura).
3. **Prueba de Persistencia en Reemplazo de Inventario:**
   * Si el usuario cambia el modo a `Reemplazar Inventario`, ¿`totalBaseResultante` se recalcula instantáneamente como 4 unidades, cambiando automáticamente el estado de Sobrante a Déficit (ya que 4 < 6)?
4. **Prueba de Doble Entrada en Clasificar y Confirmar:**
   * Si el usuario abre el modal, cambia a ½ Docena, guarda, luego vuelve a abrir y regresa a Unidad (x1), ¿la tarjeta madre y el botón inferior se actualizan sin retraso ni necesidad de recargar la pantalla?
5. **Prueba de Foco y Scroll Seguro:**
   * El auto-scroll al presionar `VER ERRORES DE STOCK` no debe colisionar con teclados abiertos ni causar desbordes de viewport en pantallas de 5 pulgadas.

---

## 6. MATRIZ DE RIESGO Y MITIGACIÓN

| Riesgo Técnico Identificado | Nivel | Estrategia de Mitigación Inmediata |
| :--- | :---: | :--- |
| **Falsos positivos de alta confianza en productos no relacionados** | Medio | Exigir que al menos el token raíz del nombre padre tenga coincidencia $\ge 80\%$ antes de aplicar bonificación de variantes o marca. |
| **Pérdida de decimales en costos prorrateados de sobrantes** | Bajo | Utilizar cálculo directo `totalPago / totalUnidades` y redondeo contable a 2 decimales solo para la UI, preservando precisión flotante en cálculos. |
| **Ruptura de modelos serializados (`StagingResponse.fromJson`)** | Bajo | Todos los nuevos campos de `StagingVariant` (`allowLeftoverInReserve`, etc.) serán opcionales con valores predeterminados seguros (`false`). |
| **Desfase de GlobalKeys en ListView al agregar productos dinámicos** | Medio | Utilizar índices relativos o búsqueda por `uuidTemporal` en lugar de posiciones estáticas de lista. |
