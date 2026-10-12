# 📋 Plan de Trabajo — Mejoras en la Ventana de Selección de Perfiles

> **Proyecto:** MochilaLista App  
> **Fecha:** 04 de Octubre, 2026  
> **Archivo principal afectado:** `profile_selection_screen.dart`  
> **Objetivo:** Transformar la ventana de selección de perfiles en una interfaz más funcional, útil y profesional, incorporando reordenamiento por arrastre, un modal flotante de gestión centralizada (backup y eliminación) y eliminando redundancias en la interfaz actual.

---

## 📑 Índice

1. [Resumen Ejecutivo](#1-resumen-ejecutivo)
2. [Análisis del Estado Actual](#2-análisis-del-estado-actual)
3. [Arquitectura de la Solución](#3-arquitectura-de-la-solución)
4. [Fases de Implementación](#4-fases-de-implementación)
   - [Fase 1: Limpieza y Preparación](#fase-1-limpieza-y-preparación)
   - [Fase 2: Reordenamiento por Arrastre (Drag & Drop)](#fase-2-reordenamiento-por-arrastre-drag--drop)
   - [Fase 3: Modal Flotante de Gestión](#fase-3-modal-flotante-de-gestión)
   - [Fase 4: Flujo de Backup por Perfil Específico](#fase-4-flujo-de-backup-por-perfil-específico)
   - [Fase 5: Flujo de Backup del Sistema Completo](#fase-5-flujo-de-backup-del-sistema-completo)
   - [Fase 6: Flujo de Eliminación de Perfil](#fase-6-flujo-de-eliminación-de-perfil)
   - [Fase 7: Modo Selección — Interfaz Alternativa](#fase-7-modo-selección--interfaz-alternativa)
   - [Fase 8: Animaciones, Pulido y Pruebas](#fase-8-animaciones-pulido-y-pruebas)
5. [Diagrama de Flujos de Navegación](#5-diagrama-de-flujos-de-navegación)
6. [Archivos Afectados](#6-archivos-afectados)
7. [Riesgos y Consideraciones](#7-riesgos-y-consideraciones)

---

## 1. Resumen Ejecutivo

Se implementarán las siguientes mejoras en la pantalla `ProfileSelectionScreen`:

| # | Mejora | Descripción |
|---|--------|-------------|
| 1 | **Reordenamiento por arrastre** | Mantener presionado un perfil permite deslizarlo para cambiar su posición en la lista |
| 2 | **Modal flotante de gestión** | Un nuevo botón abre un modal con opciones centralizadas: "Crear Backup" y "Eliminar Perfil" |
| 3 | **Backup por perfil específico** | Flujo completo: seleccionar perfil → confirmar → animación → volver a la normalidad |
| 4 | **Backup del sistema completo** | Flujo directo: confirmar → animación → volver a la normalidad |
| 5 | **Eliminación de perfil vía modal** | Seleccionar perfil → confirmación con la palabra "ELIMINAR" → eliminación → actualización |
| 6 | **Modo selección** | Interfaz alternativa de la ventana para seleccionar perfiles (sin botones de crear/restaurar, con indicador check profesional) |
| 7 | **Eliminación del botón de basura** | Se remueve el `IconButton` de tacho de basura de cada tarjeta de perfil individual |

---

## 2. Análisis del Estado Actual

### Archivos clave analizados:

| Archivo | Ubicación | Rol |
|---------|-----------|-----|
| `profile_selection_screen.dart` | `features/auth/screens/onboarding/` | Pantalla principal de listado y selección de perfiles |
| `delete_business_modal.dart` | `features/profile/widgets/` | Modal existente de confirmación para eliminar (requiere escribir "ELIMINAR" o PIN) |
| `business_backup_service.dart` | `features/profile/services/` | Servicio de exportación e importación de backups por negocio (.mlb) |
| `backup_provider.dart` | `core/providers/` | Provider que gestiona backups globales (.db/.mlbg) y automáticos |
| `auth_provider.dart` | `core/providers/` | Provider de autenticación que gestiona perfiles locales (`localProfiles`) |
| `user_model.dart` | `core/models/` | Modelo `UserModel` con `BusinessModel` anidado |
| `auth_background.dart` | `core/widgets/` | Widget de fondo con gradiente y animaciones de la pantalla de perfiles |
| `backup_manager.dart` | `core/utils/` | Utilidad para exportación/restauración global de la base de datos |

### Estado actual de `ProfileSelectionScreen`:

- **Lista de perfiles:** Se renderizan con `ListView.builder` dentro de un `Container` con bordes redondeados.
- **Cada tarjeta de perfil** contiene:
  - Avatar (logo del negocio o iniciales con gradiente)
  - Nombre del negocio
  - Nombre del usuario
  - **Botón de eliminar** (tacho de basura `Icons.delete_outline` en rojo) → **SE ELIMINARÁ**
  - Indicador de flecha para entrar al perfil
- **Botones inferiores:** "CREAR NUEVO NEGOCIO" y "¿Tienes un backup? Restaurar aquí"
- **Widget `_AnimatedProfileCard`:** Maneja animaciones de entrada y escala al presionar
- **Gradientes de avatar:** Lista `_avatarGradients` con 5 combinaciones de colores

### Lógica de eliminación existente:
- `_showDeleteBusinessModal()` verifica si el perfil tiene PIN, luego muestra `DeleteBusinessModal`
- `DeleteBusinessModal` pide escribir "ELIMINAR" (o PIN si tiene) para confirmar
- Muestra barra de progreso animada durante la eliminación
- Al completar, retorna `true` y se refresca el estado con `auth.checkInitialState()`

### Lógica de backup existente:
- `BusinessBackupService.exportBusinessToFile()` exporta un negocio específico como archivo `.mlb`
- `BackupProvider.backupToDownloads()` exporta toda la base de datos como backup global
- `BackupManager.exportToDownloads()` es la utilidad subyacente para exportación global

---

## 3. Arquitectura de la Solución

### 3.1 Nuevos estados de la ventana

Se introducirá una máquina de estados para controlar la interfaz de la ventana:

```
┌───────────────────────┐
│   MODO NORMAL         │  ← Estado por defecto (lista de perfiles + botones)
│   (Vista actual)      │
└─────────┬─────────────┘
          │
          │ Presionar botón "⚙️ Gestionar"
          ▼
┌───────────────────────┐
│   MODAL FLOTANTE      │  ← Modal central con opciones
│   • Crear Backup      │
│   • Eliminar Perfil   │
└─────────┬─────────────┘
          │
     ┌────┴────┐
     ▼         ▼
┌─────────┐ ┌─────────────┐
│ MODO    │ │ MODO        │
│SELECCIÓN│ │ SELECCIÓN   │
│(BACKUP) │ │(ELIMINACIÓN)│
└─────────┘ └─────────────┘
```

### 3.2 Nuevo estado en el StatefulWidget

```dart
enum ProfileScreenMode {
  normal,              // Vista estándar de perfiles
  selectForBackup,     // Modo selección para backup específico
  selectForDelete,     // Modo selección para eliminación
}
```

### 3.3 Nuevo almacenamiento para el orden de perfiles

Se usará `SharedPreferences` para persistir el orden de los perfiles con una lista de IDs:
```
Clave: 'profile_order'
Valor: '[3, 1, 5, 2]'  // Lista de user IDs en el orden deseado
```

---

## 4. Fases de Implementación

---

### Fase 1: Limpieza y Preparación

**Objetivo:** Preparar el código existente eliminando elementos que serán reemplazados y crear la estructura base para los nuevos estados.

**Tareas:**

| # | Tarea | Detalle |
|---|-------|---------|
| 1.1 | **Eliminar el botón de basura** de cada tarjeta de perfil | Remover el `IconButton` con `Icons.delete_outline` (líneas 398-403 de `profile_selection_screen.dart`) |
| 1.2 | **Agregar variable de estado `_screenMode`** | Tipo `ProfileScreenMode`, inicializada en `ProfileScreenMode.normal` |
| 1.3 | **Agregar variable `_selectedProfileId`** | `int?` para rastrear qué perfil se seleccionó en modo selección |
| 1.4 | **Agregar variable `_isProcessing`** | `bool` para controlar la animación de procesamiento (backup en progreso) |
| 1.5 | **Agregar variable `_processingMessage`** | `String` para mostrar el mensaje durante la animación de procesamiento |

**Archivos modificados:**
- `profile_selection_screen.dart`

---

### Fase 2: Reordenamiento por Arrastre (Drag & Drop)

**Objetivo:** Permitir al usuario mantener presionado un perfil y arrastrarlo para cambiar su posición en la lista.

**Tareas:**

| # | Tarea | Detalle |
|---|-------|---------|
| 2.1 | **Reemplazar `ListView.builder` por `ReorderableListView.builder`** | Flutter tiene un widget nativo `ReorderableListView` que soporta drag-and-drop. Se usará su variante `.builder` para rendimiento óptimo |
| 2.2 | **Implementar callback `onReorder`** | Función que recibe `oldIndex` y `newIndex`, reordena la lista local de perfiles y persiste el nuevo orden |
| 2.3 | **Persistir el orden en `SharedPreferences`** | Guardar lista de IDs como JSON string con la clave `'profile_order'` |
| 2.4 | **Cargar el orden al iniciar** | En `initState`, leer el orden guardado y reordenar `auth.localProfiles` según corresponda |
| 2.5 | **Adaptar la animación de la tarjeta** | El `_AnimatedProfileCard` debe funcionar correctamente dentro de `ReorderableListView`, usando la propiedad `key` correcta (ValueKey basado en `p.id`) |
| 2.6 | **Feedback visual del arrastre** | Al mantener presionado, la tarjeta se eleva visualmente (sombra más pronunciada, ligero aumento de escala) para indicar que se está arrastrando. Se usará el `proxyDecorator` del `ReorderableListView` |

**Consideraciones técnicas:**
- `ReorderableListView` requiere que cada hijo tenga un `key` único → Se usará `ValueKey(p.id)`
- El arrastre funciona con long-press por defecto, que es exactamente lo que se solicita
- El orden se persiste localmente y no afecta la base de datos ni el `AuthProvider`
- Al crear o eliminar un perfil, el orden se recalcula automáticamente

**Archivos modificados:**
- `profile_selection_screen.dart`

---

### Fase 3: Modal Flotante de Gestión

**Objetivo:** Crear un botón en la ventana que abra un modal flotante (dialog) con las opciones de "Crear Backup" y "Eliminar Perfil".

**Tareas:**

| # | Tarea | Detalle |
|---|-------|---------|
| 3.1 | **Agregar botón de gestión** | Un `IconButton` o botón con icono (⚙️ engranaje o ⋯ tres puntos) ubicado en la esquina superior derecha del contenedor principal de perfiles, visible solo cuando hay perfiles |
| 3.2 | **Crear método `_showManagementModal()`** | Muestra un `showDialog` con diseño glassmorphism/premium que presenta dos opciones |
| 3.3 | **Diseño del modal** | El modal tendrá: icono decorativo superior, título "Gestión de Perfiles", y dos tarjetas/botones para cada opción |
| 3.4 | **Opción "Crear Backup"** | Icono `Icons.backup_rounded`, color azul/índigo. Al presionar, cierra el modal y abre un segundo modal con sub-opciones de backup |
| 3.5 | **Opción "Eliminar Perfil"** | Icono `Icons.delete_forever_rounded`, color rojo. Al presionar, cierra el modal y cambia `_screenMode` a `selectForDelete` |
| 3.6 | **Sub-modal de tipo de backup** | Método `_showBackupTypeModal()` que muestra otro dialog con dos opciones: "Backup de un perfil específico" y "Backup del sistema completo" |

**Flujo de navegación del modal:**
```
Botón ⚙️ → Modal Gestión
              ├── "Crear Backup" → Sub-Modal Tipo Backup
              │                        ├── "Perfil específico" → Modo Selección (Backup)
              │                        └── "Sistema completo" → Animación → Normal
              └── "Eliminar Perfil" → Modo Selección (Eliminación)
```

**Archivos creados/modificados:**
- `profile_selection_screen.dart` (todos los métodos nuevos se agregan en el mismo archivo)

---

### Fase 4: Flujo de Backup por Perfil Específico

**Objetivo:** Cuando el usuario elige crear un backup de un perfil específico, la ventana cambia a modo selección, permite elegir un perfil, confirma la selección y ejecuta el backup.

**Tareas:**

| # | Tarea | Detalle |
|---|-------|---------|
| 4.1 | **Cambiar a modo selección al elegir "Perfil específico"** | Cerrar el sub-modal de tipo backup, establecer `_screenMode = ProfileScreenMode.selectForBackup` |
| 4.2 | **Al tocar un perfil en modo selección** | Se establece `_selectedProfileId = p.id` y se muestra un modal de confirmación |
| 4.3 | **Modal de confirmación de perfil** | `_showBackupConfirmationModal()`: Muestra el nombre del usuario y negocio seleccionado, con botón "Confirmar" y botón "Volver" (para elegir otro perfil) |
| 4.4 | **Al confirmar** | Cerrar modal, establecer `_isProcessing = true`, `_processingMessage = "Creando backup de [nombre]..."` |
| 4.5 | **Ejecutar el backup** | Llamar a `BusinessBackupService.exportBusinessToFile()` con el `negocioId` del perfil seleccionado |
| 4.6 | **Al completar** | Establecer `_isProcessing = false`, `_screenMode = ProfileScreenMode.normal`, mostrar `CustomSnackBar` de éxito/error |
| 4.7 | **Botón "Volver" en confirmación** | Cierra el modal de confirmación y vuelve al modo selección para elegir otro perfil. El `_selectedProfileId` se resetea a `null` |

**Archivos modificados:**
- `profile_selection_screen.dart`

---

### Fase 5: Flujo de Backup del Sistema Completo

**Objetivo:** Cuando el usuario elige crear un backup del sistema completo, se ejecuta directamente sin seleccionar perfil.

**Tareas:**

| # | Tarea | Detalle |
|---|-------|---------|
| 5.1 | **Al elegir "Sistema completo" en el sub-modal** | Cerrar el modal, establecer `_isProcessing = true`, `_processingMessage = "Creando backup del sistema completo..."` |
| 5.2 | **Ejecutar el backup global** | Llamar a `BackupProvider.backupToDownloads()` o directamente `BackupManager.exportToDownloads()` |
| 5.3 | **Al completar** | Establecer `_isProcessing = false`, mostrar `CustomSnackBar` de éxito/error. La ventana ya está en modo `normal` |

**Archivos modificados:**
- `profile_selection_screen.dart`

---

### Fase 6: Flujo de Eliminación de Perfil

**Objetivo:** Cuando el usuario elige eliminar un perfil, la ventana cambia a modo selección, permite elegir un perfil y abre el modal de eliminación existente.

**Tareas:**

| # | Tarea | Detalle |
|---|-------|---------|
| 6.1 | **Cambiar a modo selección al elegir "Eliminar Perfil"** | Cerrar el modal de gestión, establecer `_screenMode = ProfileScreenMode.selectForDelete` |
| 6.2 | **Al tocar un perfil en modo selección (eliminar)** | Se establece `_selectedProfileId = p.id` y se abre el `DeleteBusinessModal` existente |
| 6.3 | **Reutilizar `DeleteBusinessModal`** | Se llama exactamente al mismo `_showDeleteBusinessModal()` existente que ya verifica PIN y muestra el flujo de confirmación con la palabra "ELIMINAR" |
| 6.4 | **Al completar la eliminación** | Establecer `_screenMode = ProfileScreenMode.normal`, `_selectedProfileId = null`, y ejecutar `auth.checkInitialState()` para refrescar la lista sin el perfil eliminado. Actualizar el orden guardado en SharedPreferences removiendo el ID eliminado |
| 6.5 | **Si el usuario cancela la eliminación** | Volver al modo selección para elegir otro perfil o usar el botón cancelar para volver a modo normal |

**Archivos modificados:**
- `profile_selection_screen.dart`

---

### Fase 7: Modo Selección — Interfaz Alternativa

**Objetivo:** Cuando la ventana entra en modo selección (ya sea para backup o eliminación), la interfaz debe transformarse para facilitar la selección, ocultando elementos innecesarios y añadiendo indicadores visuales.

**Tareas:**

| # | Tarea | Detalle |
|---|-------|---------|
| 7.1 | **Ocultar botones inferiores** | En modo selección, los botones "CREAR NUEVO NEGOCIO" y "¿Tienes un backup? Restaurar aquí" no se muestran |
| 7.2 | **Ocultar botón de gestión ⚙️** | El botón que abre el modal de gestión tampoco se muestra en modo selección |
| 7.3 | **Mostrar barra superior de contexto** | En la parte superior del contenedor de perfiles, mostrar un texto indicativo como: "Selecciona un perfil para backup" o "Selecciona un perfil para eliminar", con el color apropiado (azul para backup, rojo para eliminación) |
| 7.4 | **Botón "Cancelar" en modo selección** | En la parte inferior (donde estaban los botones), mostrar un botón "Cancelar" que devuelve al modal flotante de gestión correspondiente. Si la acción viene del flujo de backup → muestra el sub-modal de tipo backup. Si viene del flujo de eliminación → regresa a modo normal |
| 7.5 | **Indicador visual Check en cada tarjeta** | Al lado derecho de cada tarjeta de perfil, en lugar de la flecha `arrow_forward_ios`, mostrar un **círculo de selección** (estilo radio button/check). Cuando está sin seleccionar: círculo vacío con borde. Cuando se selecciona: círculo relleno con check ✓ animado |
| 7.6 | **Diseño del indicador Check** | - Sin seleccionar: `Container` circular con borde de 2px (gris claro). - Seleccionado: `Container` circular con fondo azul (backup) o rojo (eliminación) y un `Icon(Icons.check)` blanco. - Transición animada con `AnimatedContainer` y `AnimatedSwitcher` |
| 7.7 | **Remover el arrastre en modo selección** | El `ReorderableListView` se convierte en un `ListView` estándar cuando estamos en modo selección para evitar conflictos con el tap de selección |
| 7.8 | **Cambiar el subtitle del header** | En modo selección, el texto "Selecciona tu espacio de trabajo" del header cambia a "Selecciona un perfil" con un tono visual diferente |
| 7.9 | **Adaptación visual por contexto** | - Para **backup**: El indicador check y los acentos usan color azul/índigo - Para **eliminación**: El indicador check y los acentos usan color rojo/naranja |

**Diseño visual del indicador check:**

```
┌───────────────────────────────────────────┐
│  [Avatar]  Nombre del Negocio      ( )    │  ← Sin seleccionar
│            Nombre del usuario             │
└───────────────────────────────────────────┘

┌───────────────────────────────────────────┐
│  [Avatar]  Nombre del Negocio      (✓)    │  ← Seleccionado
│            Nombre del usuario             │     (con animación)
└───────────────────────────────────────────┘
```

**Archivos modificados:**
- `profile_selection_screen.dart`

---

### Fase 8: Animaciones, Pulido y Pruebas

**Objetivo:** Asegurar que todas las transiciones sean fluidas, las animaciones sean coherentes con el diseño existente y que no haya bugs.

**Tareas:**

| # | Tarea | Detalle |
|---|-------|---------|
| 8.1 | **Animación de overlay de procesamiento** | Cuando `_isProcessing == true`, mostrar un overlay centrado sobre la ventana con: fondo semi-transparente oscuro, contenedor con bordes redondeados, `CircularProgressIndicator` animado, texto descriptivo. Similar al que ya existe en `BackupScreen` (líneas 717-734) |
| 8.2 | **Transición de modo normal → selección** | Usar `AnimatedSwitcher` o `AnimatedCrossFade` para la transición suave entre los botones inferiores y el botón "Cancelar" |
| 8.3 | **Transición del header** | El texto del subtítulo cambia con animación de fade cuando cambia el modo |
| 8.4 | **Feedback háptico** | Agregar `HapticFeedback.mediumImpact()` al iniciar un arrastre y al completar el reordenamiento |
| 8.5 | **Verificar flujo completo de backup** | Probar que el archivo `.mlb` se genera correctamente al seleccionar un perfil específico |
| 8.6 | **Verificar flujo completo de eliminación** | Probar que el `DeleteBusinessModal` funciona correctamente cuando se invoca desde el nuevo flujo |
| 8.7 | **Verificar que el orden persistido sobrevive** | Cerrar y reabrir la app, verificar que el orden de los perfiles se mantiene |
| 8.8 | **Verificar caso sin perfiles** | Si se eliminan todos los perfiles, la pantalla debe mostrar el estado vacío sin errores |
| 8.9 | **Verificar compatibilidad con modo oscuro** | Todos los nuevos elementos deben respetar el tema dark/light existente |

**Archivos modificados:**
- `profile_selection_screen.dart`

---

## 5. Diagrama de Flujos de Navegación

### 5.1 Flujo de Backup por Perfil Específico

```
[Ventana Normal]
      │
      ▼ (Presiona botón ⚙️)
[Modal: Gestión de Perfiles]
      │
      ▼ (Elige "Crear Backup")
[Modal: Tipo de Backup]
      │
      ▼ (Elige "Perfil específico")
      │  ← Modal se cierra
      ▼
[Ventana en MODO SELECCIÓN (backup)]
  • Botones crear/restaurar ocultos
  • Cada perfil tiene indicador check (azul)
  • Botón "Cancelar" visible en la parte inferior
      │
      ├── (Presiona "Cancelar") ──────► [Modal: Tipo de Backup] (regresa al modal)
      │
      ▼ (Selecciona un perfil)
[Modal: Confirmar Perfil]
  "¿Deseas crear un backup de:
   Negocio: [nombre_negocio]
   Usuario: [nombre_usuario]?"
      │
      ├── (Presiona "Volver") ──────► [Ventana en MODO SELECCIÓN] (elegir otro)
      │
      ▼ (Presiona "Confirmar")
      │  ← Modal se cierra
      ▼
[Ventana Normal + Overlay de Procesamiento]
  • Animación de carga centrada
  • "Creando backup de [nombre]..."
      │
      ▼ (Backup completado)
[Ventana Normal]
  • SnackBar de éxito/error
  • Todo vuelve a como estaba al inicio
```

### 5.2 Flujo de Backup del Sistema Completo

```
[Ventana Normal]
      │
      ▼ (Presiona botón ⚙️)
[Modal: Gestión de Perfiles]
      │
      ▼ (Elige "Crear Backup")
[Modal: Tipo de Backup]
      │
      ▼ (Elige "Sistema completo")
      │  ← Modal se cierra
      ▼
[Ventana Normal + Overlay de Procesamiento]
  • Animación de carga centrada
  • "Creando backup del sistema completo..."
      │
      ▼ (Backup completado)
[Ventana Normal]
  • SnackBar de éxito/error
```

### 5.3 Flujo de Eliminación de Perfil

```
[Ventana Normal]
      │
      ▼ (Presiona botón ⚙️)
[Modal: Gestión de Perfiles]
      │
      ▼ (Elige "Eliminar Perfil")
      │  ← Modal se cierra
      ▼
[Ventana en MODO SELECCIÓN (eliminación)]
  • Botones crear/restaurar ocultos
  • Cada perfil tiene indicador check (rojo)
  • Botón "Cancelar" visible en la parte inferior
      │
      ├── (Presiona "Cancelar") ──────► [Ventana Normal] (regresa al estado normal)
      │
      ▼ (Selecciona un perfil)
[Modal: DeleteBusinessModal (existente)]
  • "¿Eliminar Definitivamente?"
  • Campo para escribir "ELIMINAR" o ingresar PIN
      │
      ├── (Presiona "Cancelar") ──────► [Ventana MODO SELECCIÓN] (elegir otro)
      │
      ▼ (Escribe "ELIMINAR" y confirma)
  • Barra de progreso animada (existente)
  • Eliminación en progreso...
      │
      ▼ (Eliminación completada)
[Ventana Normal]
  • Lista actualizada SIN el perfil eliminado
  • SnackBar de confirmación
  • Orden persistido actualizado
```

---

## 6. Archivos Afectados

### Archivos que se MODIFICAN:

| Archivo | Cambios |
|---------|---------|
| `features/auth/screens/onboarding/profile_selection_screen.dart` | **Archivo principal.** Se modifica extensamente: se agrega enum `ProfileScreenMode`, variables de estado, se reemplaza `ListView` por `ReorderableListView`, se agrega botón de gestión ⚙️, se crean métodos para modales (gestión, tipo backup, confirmación), se implementa modo selección con indicadores check, se agrega overlay de procesamiento, se elimina botón de basura de las tarjetas |

### Archivos que NO se modifican:

| Archivo | Razón |
|---------|-------|
| `delete_business_modal.dart` | Se **reutiliza** tal cual. No necesita cambios porque su interfaz y lógica son autónomos |
| `business_backup_service.dart` | Se **reutiliza** el método `exportBusinessToFile()` existente |
| `backup_provider.dart` | Se **reutiliza** el método `backupToDownloads()` existente |
| `auth_provider.dart` | Se **reutiliza** `checkInitialState()`, `localProfiles`, `deleteProfileAndDataWithProgress()` |
| `backup_manager.dart` | Se **reutiliza** `exportToDownloads()` existente |
| `auth_background.dart` | Sin cambios, la estructura visual del fondo se mantiene |
| `user_model.dart` | Sin cambios al modelo de datos |

> **Nota importante:** Al concentrar todos los cambios en un solo archivo (`profile_selection_screen.dart`) se minimiza el riesgo de romper otras funcionalidades del sistema. Los servicios y providers existentes se invocan sin modificaciones.

---

## 7. Riesgos y Consideraciones

### 7.1 Riesgos Identificados

| Riesgo | Impacto | Mitigación |
|--------|---------|------------|
| `ReorderableListView` podría causar conflictos con las animaciones existentes de `_AnimatedProfileCard` | Medio | Se mantendrán las animaciones de entrada pero se adaptará el `GestureDetector` para no interferir con el long-press del reorder |
| El orden persistido podría desincronizarse si se crean/eliminan perfiles | Bajo | Al cargar el orden, se filtran IDs que ya no existen y se agregan nuevos perfiles al final |
| El backup podría fallar silenciosamente | Bajo | Se capturan excepciones y se muestran en `CustomSnackBar` con `isError: true` |
| Conflicto entre modo selección y tap normal para entrar al perfil | Medio | En modo selección, el tap **NO** navega al perfil, solo lo selecciona. El comportamiento del tap se controla según `_screenMode` |

### 7.2 Consideraciones de UX

- **Accesibilidad del botón ⚙️:** Se posicionará de forma visible pero no intrusiva, usando un `IconButton` con tooltip descriptivo.
- **Feedback visual claro:** Los colores (azul para backup, rojo para eliminación) comunican inmediatamente el contexto de la acción.
- **Prevención de errores:** La confirmación de backup muestra el nombre completo del perfil. La eliminación requiere escribir "ELIMINAR" (mecanismo ya existente y probado).
- **Cancelación sencilla:** En todo momento el usuario puede cancelar y volver al estado anterior sin consecuencias.

### 7.3 Coherencia con el Sistema Existente

- Los modales nuevos siguen el mismo patrón visual de los modales existentes (bordes redondeados de 24px, colores adaptados a dark/light mode, iconos decorativos).
- La animación de procesamiento replica el diseño del overlay de `BackupScreen`.
- El `CustomSnackBar` existente se reutiliza para todos los mensajes de feedback.
- El flujo de eliminación reutiliza exactamente el `DeleteBusinessModal` existente, manteniendo la consistencia y la seguridad del flujo actual.

---

> **Estado:** ✅ Plan listo para revisión  
> **Siguiente paso:** Revisión y aprobación del usuario antes de proceder con la implementación
