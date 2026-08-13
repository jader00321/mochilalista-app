# 📱 Mochilalista (Mobile Client)

Este directorio contiene el código fuente principal (Flutter/Dart) de la aplicación **Mochilalista v4.0**.

> ⚠️ **Documentación Principal:** Para ver las instrucciones de instalación, flujos del sistema y diagramas de arquitectura (Mermaid), por favor dirígete al [README raíz del proyecto](../README.md) y a la carpeta [docs/](../docs/).

## Estructura de Directorios (`lib/`)

El proyecto sigue una arquitectura Modular Feature-Driven (por funcionalidades). 

* `core/`: Componentes comunes, widgets reutilizables, constantes, temas, utils y servicios compartidos (Auth, Local DB, Master Data).
* `features/`: Lógica de negocio dividida por módulos:
  * `analytics/`: Dashboards, métricas, alertas de stock.
  * `auth/`: Flujo de inicio de sesión, creación de negocio, perfiles.
  * `catalog/`: Gestión CRUD del inventario, productos, marcas, categorías.
  * `profile/`: Configuración de negocio, gestión de backup y base de datos local.
  * `scanner/`: Integración con Google Gemini AI para extraer comprobantes.
  * `smart_quotation/`: Motor de presupuestos, vinculación AI ↔ Catálogo y generación de PDFs.
* `main.dart`: Punto de entrada, inyección de dependencias y Provider Tree principal.

## Guía Rápida para Desarrolladores

Asegúrate de ejecutar siempre la limpieza y los formateadores antes de hacer commits:

```bash
# Limpiar dependencias cacheadas
flutter clean
flutter pub get

# Aplicar fix del linter (Asegura importaciones absolutas 'package:')
dart fix --apply
```
