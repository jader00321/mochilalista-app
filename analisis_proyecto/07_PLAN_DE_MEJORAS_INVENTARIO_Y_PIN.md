# Plan de Trabajo - Mejoras de Inventario y PIN de Seguridad

## 1. Análisis de Problemas

### Problema 1: Los productos no cargan en el Inventario, Catálogo ni Cotizaciones
**Causa Raíz:**
Tras una revisión profunda del código, el problema no está en el parseo de datos ni en el modelo `Product`, sino en la consulta SQL principal ubicada en `database/product_queries.dart`. La consulta intenta hacer un cruce de datos (JOIN) con una tabla llamada `marcas_producto`. Sin embargo, en la estructura de la base de datos local (`local_db.dart`), la tabla fue creada bajo el nombre **`marcas`**. 
Al intentar consultar una tabla que no existe, SQLite rechaza la operación, causando que el sistema devuelva una lista vacía de productos de manera silenciosa (bloqueando el inventario, catálogo, ventas rápidas y cotizaciones IA).

### Problema 2: Falta de opción "Ninguno" en Formularios de Producto
**Causa Raíz:**
Actualmente, los campos desplegables (Dropdowns) para seleccionar "Proveedor", "Categoría" y "Marca" exigen escoger una de las opciones existentes o se muestran vacíos de manera confusa si no hay datos.
No existe una opción explícita "Ninguno" (o "Sin Seleccionar") que permita al usuario dejar intencionalmente esos datos como nulos o vacíos al momento de crear o editar.

### Problema 3: Confusión en el comportamiento de "Desactivar PIN"
**Causa Raíz:**
La lógica interna actual del sistema al presionar "Desactivar PIN" es eliminar por completo la contraseña registrada (`""`). Sin embargo, el texto "Desactivar" sugiere que el PIN se apaga temporalmente y se puede volver a prender sin reconfigurarlo. Como el modal se recarga mostrando la pantalla de "Crear PIN" de nuevo, genera confusión en la experiencia de usuario.

---

## 2. Plan de Ejecución (Soluciones Propuestas)

### Fase 1: Restaurar Carga de Productos (Crítico)
* **Archivo a modificar:** `lib/database/product_queries.dart`
* **Acción:** Corregir la constante `selectInventoryCols`. Cambiar la línea `LEFT JOIN marcas_producto m` por `LEFT JOIN marcas m`. 
* **Impacto:** Esto restaurará instantáneamente la visibilidad de los productos en el inventario, ventas rápidas, catálogo y módulo de cotizaciones IA.

### Fase 2: Flexibilidad en los Formularios (Opción "Ninguno")
* **Archivos a modificar:** 
  - `lib/features/inventory/screens/product_create_screen.dart`
  - `lib/features/inventory/screens/product_edit_screen.dart`
* **Acción:** Encanar la lista de Categorías, Marcas y Proveedores para inyectar dinámicamente un ítem inicial llamado **"Ninguno"** (cuyo valor interno sea `null` o `0`). Ajustar la validación para que estos campos no sean estrictamente requeridos si se selecciona "Ninguno" (dejando la llave foránea como nula en la DB).

### Fase 3: Claridad en el Modal de Seguridad PIN
* **Archivo a modificar:** `lib/features/profile/widgets/change_pin_modal.dart`
* **Acción:**
  - Cambiar el texto del botón rojo de "Desactivar PIN" a **"Eliminar PIN"**.
  - Cambiar los mensajes descriptivos del modal para explicar: *"Actualiza tu PIN actual o elimínalo por completo para dejar tu cuenta sin protección."*
  - Ajustar el "CustomSnackBar" al borrar el PIN para que diga: *"PIN de seguridad eliminado correctamente. Tu cuenta ya no tiene bloqueo."*

---

## 3. Aprobación Requerida
Antes de proceder, requiero tu confirmación. ¿Estás de acuerdo con cambiar "Desactivar PIN" por "Eliminar PIN" (Fase 3), y con la forma en que aplicaremos las soluciones? Si estás de acuerdo, presiona 'Proceder'.
