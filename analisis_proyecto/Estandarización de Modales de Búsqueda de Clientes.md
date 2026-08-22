# Estandarización de Modales de Búsqueda de Clientes

## Diagnóstico de la Auditoría

### Modal de Referencia (✅ Funciona bien)
**Archivo:** [`client_search_modal.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/manual/client_search_modal.dart) (Cotización Manual)

- Usa `ClientService.getRecentClients()` en `initState` → carga 5 clientes recientes al abrir.
- Usa `FutureBuilder` con un `Future` que se reasigna en cada búsqueda.
- Filtra clientes "Caja Rápida -" del resultado.
- Diseño: `DraggableScrollableSheet`, botón verde "Asignar", avatar con inicial.

### Modal Roto #1 — Caja Rápida
**Archivo:** [`quick_sale_header.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/quick_sale/quick_sale_header.dart) (clase `_ClientSearchModal`, línea 244)

> [!CAUTION]
> **Causa raíz identificada:** El `initState` (línea 256) llama a `_loadRecentClients()`, que internamente invoca `SaleProvider.searchClients("")`. Pero [`SaleProvider.searchClients`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/providers/sale_provider.dart#L255-L263) tiene un **guard explícito**: `if (query.isEmpty) return []`. Por lo tanto, la carga inicial siempre devuelve una lista vacía, y el modal muestra "Empieza a escribir para buscar...".

**Otros hallazgos:**
- El modal sí tiene debounce (500ms) y botón de limpiar búsqueda → bien diseñado en interacción.
- El diseño de tarjetas incluye badges "APP", deuda y saldo → más rico que el de referencia.
- Falta el botón verde "Asignar" como trailing; en su lugar usa `onTap` en el `ListTile` completo → menos intuitivo visualmente.

### Modal Roto #2 — Caja y Cierre
**Archivo:** [`client_bottom_sheet.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/checkout/client_bottom_sheet.dart)

> [!CAUTION]
> **Causa raíz #1 (No Auto-Load):** No existe `initState` ni ningún mecanismo de carga inicial. El método `_search()` (línea 46) tiene su propio guard: `if (query.isNotEmpty)` → si el query está vacío, limpia resultados en vez de cargar recientes. El modal siempre arranca mostrando "Busca un cliente para asignarlo".

> [!CAUTION]
> **Causa raíz #2 (Focus Trap):** Usa `DefaultTabController` (línea 83) sin crear un `TabController` explícito con listener. El `TextField` del buscador tiene `autofocus: true` (línea 119). Al cambiar a la pestaña "Crear Nuevo", el foco queda atrapado en el `TextField` invisible de la pestaña "Buscar Existente", y cualquier tecla que se presione va al buscador en lugar de al campo "Nombre Completo".

**Otros hallazgos:**
- El avatar del `ListTile` usa un `Icon(Icons.person)` genérico en lugar de la inicial del nombre → inconsistente.
- El botón del Tab "Crear Nuevo" dice "ASIGNAR PARA LA VENTA" (mayúsculas, verde oscuro) vs el "Asignar" del Tab 1 → inconsistencia.
- No tiene badge "APP" ni indicadores de deuda/saldo como el de Caja Rápida.

---

## Propuesta de Cambios

### Fase 1: Corrección de Auto-Load

#### [MODIFY] [`quick_sale_header.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/quick_sale/quick_sale_header.dart)
**Problema:** `_loadRecentClients()` llama a `SaleProvider.searchClients("")` que retorna `[]`.
**Solución:** Reemplazar la llamada por `ClientService().getRecentClients(negocioId)` directo (patrón idéntico al modal de referencia). Esto evita depender del guard del provider.

```dart
// ANTES (línea 274):
final results = await Provider.of<SaleProvider>(context, listen: false).searchClients("");

// DESPUÉS:
final clientService = ClientService();
final authProv = Provider.of<AuthProvider>(context, listen: false);
final results = await clientService.getRecentClients(authProv.activeBusinessId!);
```

- Se añade `import` de `ClientService`.
- Se mantiene el debounce y el `_search()` existente para búsquedas del usuario.

#### [MODIFY] [`client_bottom_sheet.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/checkout/client_bottom_sheet.dart)
**Problema:** No existe `initState` ni carga inicial.
**Solución:** Añadir `initState` con `addPostFrameCallback` que llame a un nuevo método `_loadRecentClients()` usando `ClientService.getRecentClients()`.

```dart
@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _loadRecentClients();
  });
}

void _loadRecentClients() async {
  setState(() => _isSearching = true);
  final saleProv = Provider.of<SaleProvider>(context, listen: false);
  // Acceder al negocioId via SaleProvider (ya inicializado en el árbol)
  final results = await ClientService().getRecentClients(saleProv.negocioId!);
  if (mounted) {
    setState(() { _searchResults = results; _isSearching = false; });
  }
}
```

- Modificar `_search()` para que cuando el query esté vacío, llame a `_loadRecentClients()` en vez de limpiar la lista.

> [!NOTE]
> Verificaré que `SaleProvider` exponga `negocioId` (o usaré `AuthProvider.activeBusinessId` directamente, que es el patrón del modal de referencia).

---

### Fase 2: Gestión de FocusNode (Fix Focus Trap)

#### [MODIFY] [`client_bottom_sheet.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/checkout/client_bottom_sheet.dart)

**Cambios de arquitectura:**

1. **Reemplazar `DefaultTabController` por `TabController` explícito:**
   - Añadir `with TickerProviderStateMixin` al State.
   - Crear `late TabController _tabController` en `initState`.
   - Añadir listener al `_tabController` para reaccionar al cambio de pestaña.

2. **Crear FocusNodes dedicados:**
   ```dart
   final FocusNode _searchFocusNode = FocusNode();
   final FocusNode _nameFocusNode = FocusNode();
   ```

3. **Implementar listener del TabController:**
   ```dart
   _tabController.addListener(() {
     if (_tabController.indexIsChanging) return; // Evitar doble disparo
     if (_tabController.index == 0) {
       // Tab "Buscar Existente": foco al buscador
       _nameFocusNode.unfocus();
       Future.delayed(const Duration(milliseconds: 100), () {
         if (mounted) _searchFocusNode.requestFocus();
       });
     } else {
       // Tab "Crear Nuevo": quitar foco del buscador → ponerlo en "Nombre"
       _searchFocusNode.unfocus();
       Future.delayed(const Duration(milliseconds: 100), () {
         if (mounted) _nameFocusNode.requestFocus();
       });
     }
   });
   ```

4. **Asignar los FocusNodes a los TextFields correspondientes:**
   - `_searchCtrl` → `focusNode: _searchFocusNode`
   - `_nameCtrl` → `focusNode: _nameFocusNode`

5. **Eliminar `autofocus: true`** del TextField del buscador y reemplazarlo por el `_searchFocusNode.requestFocus()` controlado desde el listener (solo se activa si el tab activo es 0).

6. **Dispose correcto:**
   ```dart
   @override
   void dispose() {
     _tabController.dispose();
     _searchFocusNode.dispose();
     _nameFocusNode.dispose();
     // ... otros controllers
     super.dispose();
   }
   ```

---

### Fase 3: Estandarización y Pulido UI

#### [MODIFY] [`client_bottom_sheet.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/checkout/client_bottom_sheet.dart)

| Elemento | Estado Actual | Propuesta |
|---|---|---|
| **Avatar del ListTile** | `Icon(Icons.person)` genérico | Inicial del nombre (`c.fullName[0].toUpperCase()`) como en los otros modales |
| **Indicadores financieros** | Ninguno | Mostrar deuda (`totalDebt`) y saldo a favor (`saldoAFavor`) como trailing, idéntico al modal de Caja Rápida |
| **Badge "APP"** | Ausente | Añadir badge si `c.usuarioVinculadoId != null` |
| **Botón Tab 2** | "ASIGNAR PARA LA VENTA" (mayúsculas, verde oscuro `#2E7D32`) | Cambiar a "Asignar para la Venta" (capitalización normal), mismo verde `Colors.green` del botón "Asignar" |
| **Texto vacío Tab 1** | "Busca un cliente para asignarlo" | Reemplazar por indicador de carga durante `initState`, luego mostrar la lista de recientes |

#### [MODIFY] [`quick_sale_header.dart`](file:///c:/Users/vjuli/Documents/mochilalista-app/app_movil/lib/features/smart_quotation/widgets/quick_sale/quick_sale_header.dart)

| Elemento | Estado Actual | Propuesta |
|---|---|---|
| **Selección de cliente** | `onTap` en todo el `ListTile` (sin botón visible) | Añadir trailing `ElevatedButton "Asignar"` verde, como en el modal de referencia |
| **Texto vacío** | "Empieza a escribir para buscar..." (ya no aparecerá tras Fase 1) | Mantener como fallback de seguridad si `_results` sigue vacío |

---

## Verificación

### Comprobaciones post-implementación
1. **Auto-Load:** Abrir cada modal y verificar que muestra la lista de clientes recientes sin escribir.
2. **Focus Trap:** En "Caja y Cierre", cambiar entre pestañas y verificar que el cursor se posiciona correctamente en el campo activo.
3. **Consistencia Visual:** Comparar lado a lado los tres modales y verificar que avatares, botones, badges y colores sean uniformes.
4. **Regresión:** Buscar un cliente, asignarlo, desvincular, y volver a abrir el modal para asegurar que la carga inicial sigue funcionando.
