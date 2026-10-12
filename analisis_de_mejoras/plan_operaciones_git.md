# 🔧 PLAN DE OPERACIONES GIT — Organización de Ramas y Respaldo

> **Fecha:** 12 de Octubre 2026  
> **Repositorio:** https://github.com/jader00321/mochilalista-app

---

## 📋 ESTADO ACTUAL DEL REPOSITORIO

| Elemento | Valor |
|----------|-------|
| **Rama actual** | `v2.0-app-offline` |
| **Ramas existentes** | `v2.0-app-offline` (actual), `feature/version-offline`, `main` |
| **Último commit** | `a988130` — "fix: migrar SDK de IA - google_generative_ai → googleai_dart v12" |
| **Cambios sin commit** | 13 archivos modificados + 3 directorios nuevos (`analisis_de_mejoras/`, `app_movil/lib/features/auth/screens/onboarding/widgets/`, `informe_proyecto/`) |
| **Remote** | `origin` → `https://github.com/jader00321/mochilalista-app` |

---

## 🗂️ PLAN DE OPERACIONES (6 Pasos)

### PASO 1: Commit de todos los cambios actuales en `v2.0-app-offline`
```
git add .
git commit -m "chore: análisis de mejoras, informes de diagnóstico y plan de trabajo maestro para BAZAR LUZAM"
```
**Incluye:** Los 13 archivos modificados + los 3 directorios nuevos (análisis de mejoras, informes del proyecto, widgets de onboarding)

### PASO 2: Push a GitHub de la rama `v2.0-app-offline` actualizada
```
git push origin v2.0-app-offline
```
**Resultado:** El repositorio en GitHub queda actualizado con la última versión completa

### PASO 3: Crear nueva rama de respaldo `mochilaLista-v8.6-offline-funcional`
```
git checkout -b mochilaLista-v8.6-offline-funcional
```
**Resultado:** Se crea la nueva rama copiando el estado exacto de `v2.0-app-offline`

### PASO 4: Modificar README.md en la rama de respaldo
**Cambios en README.md:**
- Indicar que es la **versión offline v8.5 funcional**
- Indicar la **fecha de esta versión** (12 de Octubre 2026)
- Indicar que es la **versión base ANTES de implementar** las modificaciones del plan de mejoras, el futuro modelo de comercialización y el sistema de seguridad planificado
- Hacer commit y push de estos cambios en la rama de respaldo

```
git add README.md
git commit -m "docs: marcar rama como versión offline v8.5 funcional - respaldo pre-mejoras"
git push -u origin mochilaLista-v8.6-offline-funcional
```

### PASO 5: Regresar a la rama de trabajo original
```
git checkout v2.0-app-offline
```

### PASO 6: Renombrar la rama de trabajo a un nombre que indique su propósito experimental
**Nombre propuesto:** `dev/mejoras-v9.0-comercializacion-seguridad`

Este nombre indica:
- `dev/` → Es una rama de desarrollo experimental
- `mejoras-v9.0` → Se está trabajando hacia la versión 9.0
- `comercializacion-seguridad` → Incluye el nuevo modelo de comercialización y mejoras de seguridad

**Operaciones para renombrar:**
```
git branch -m v2.0-app-offline dev/mejoras-v9.0-comercializacion-seguridad
git push origin dev/mejoras-v9.0-comercializacion-seguridad
git push origin --delete v2.0-app-offline
git push origin -u dev/mejoras-v9.0-comercializacion-seguridad
```

---

## 🏁 RESULTADO FINAL

Después de ejecutar los 6 pasos, el repositorio tendrá esta estructura de ramas:

| Rama | Propósito | Estado |
|------|-----------|--------|
| `main` | Rama principal del repositorio | Sin cambios |
| `feature/version-offline` | Rama histórica | Sin cambios |
| `mochilaLista-v8.6-offline-funcional` | **🔒 RESPALDO** — Versión offline v8.5 funcional ANTES de las mejoras. No se tocará | Nueva ✅ |
| `dev/mejoras-v9.0-comercializacion-seguridad` | **🔧 TRABAJO ACTIVO** — Aquí se implementarán todas las mejoras del plan maestro, modelo de comercialización y seguridad | Renombrada ✅ |

### Diagrama visual:
```
main ────────────────────────────────── (rama principal)

feature/version-offline ──────────────── (histórica)

mochilaLista-v8.6-offline-funcional ──── (🔒 respaldo v8.5 intacto)
         │
         └── Copia exacta del estado actual + README marcado

dev/mejoras-v9.0-comercializacion-seguridad ── (🔧 trabajo activo)
         │
         └── Aquí se ejecutarán las 5 fases del Plan de Trabajo Maestro
             + Modelo de comercialización
             + Sistema de seguridad
```

---

## ⚠️ CONFIRMACIÓN REQUERIDA

Antes de ejecutar, necesito tu confirmación sobre:

1. **¿El nombre de la rama de respaldo** `mochilaLista-v8.6-offline-funcional` es correcto? (Tú mencionaste v8.6 pero indicas que es v8.5 funcional — ¿cuál prefieres?)
2. **¿El nombre de la rama de trabajo** `dev/mejoras-v9.0-comercializacion-seguridad` te parece adecuado? ¿O prefieres otro nombre?
3. **¿Eliminar la rama remota `v2.0-app-offline`** del repositorio al renombrarla? (Se reemplaza por el nuevo nombre)
4. **¿El mensaje del commit** es adecuado?

**Una vez confirmes, ejecuto los 6 pasos en secuencia.**
