<p align="center">
  <img src="app_movil/assets/logo.png" alt="Mochilalista Logo" width="200">
</p>

<h1 align="center">Mochilalista App v4.0 (Offline-First)</h1>

<p align="center">
  <strong>Plataforma Inteligente para la Gestión de Ventas, CRM y Automatización de Inventarios.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart">
  <img src="https://img.shields.io/badge/SQLite-003B57?style=for-the-badge&logo=sqlite&logoColor=white" alt="SQLite">
  <img src="https://img.shields.io/badge/Gemini_AI-8E75B2?style=for-the-badge&logo=google&logoColor=white" alt="Gemini">
  <img src="https://img.shields.io/badge/Version-4.0.0-success?style=for-the-badge" alt="Version 4.0">
</p>

---

## 🚀 Resumen del Proyecto

**Mochilalista** es una solución empresarial integral y de vanguardia, diseñada para revolucionar el flujo de trabajo de negocios minoristas y mayoristas. Con la llegada de la versión 4.0, la aplicación ha perfeccionado su arquitectura **100% Offline-First**, garantizando un rendimiento ultra rápido, robustez en el código (con importaciones absolutas y tipado fuerte) y autonomía total, centralizando la base de datos y la Inteligencia Artificial (procesamiento on-device) sin dependencia de servidores intermedios.

## ✨ Funcionalidades Estrella (Módulos Principales)

* **🧠 Smart Scanner (IA On-Device):** Módulo impulsado por Google Gemini AI que extrae datos de comprobantes físicos y manuscritos (facturas/listas) con un nivel de precisión asombroso.
* **🛒 Smart Quotation (Cotización Inteligente):** Matcher en tiempo real que vincula textos escaneados con tu inventario mediante un algoritmo avanzado de `string_similarity`. Generación inmediata de PDFs y compartición vía WhatsApp.
* **📦 Control de Catálogo e Inventario:** Gestión profunda de Productos, Categorías, Marcas y Variantes (presentaciones múltiples). Todo sincronizado y respaldado en local.
* **📊 Analytics Dashboard:** Paneles estadísticos en tiempo real con alertas de falta de stock (Restock), productos sin movimiento (Dead Stock), KPIs de ventas y top de clientes.
* **💾 Backup & Sync:** Respaldo completo de la base de datos (SQLite) cifrada hacia WhatsApp, almacenamientos locales y nube.

---

## 🧠 Arquitectura General (High-Level)

> Para detalles técnicos a profundidad sobre la base de datos y flujos, consulta la [Documentación de Arquitectura Completa](docs/ARCHITECTURE.md).

Mochilalista está estructurada siguiendo una filosofía **Modular Feature-Driven**. Cada capacidad del negocio vive en un módulo aislado, garantizando alta cohesión y bajo acoplamiento.

```mermaid
graph TD
    UI[Flutter UI Layer] --> State(State Management: Provider)
    State --> Features
    
    subgraph Features [Módulos Principales (Features)]
        F1[Auth & Profile]
        F2[Catalog & Inventory]
        F3[Smart Scanner AI]
        F4[Smart Quotation]
        F5[Analytics]
    end
    
    Features --> CoreServices{Capa Core & Servicios}
    CoreServices --> DB[(SQLite Local DB)]
    CoreServices --> API((Google Gemini API))
    CoreServices --> Files[Almacenamiento Local (PDF, Images)]
```

## 🛠️ Entorno de Desarrollo Local

### Pre-requisitos
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (versión estable, >3.19.0 recomendada).
* Configuración para compilación Android (Android Studio / SDK).

### Pasos para Ejecutar

1. **Clonar el proyecto:**
   ```bash
   git clone https://github.com/tu-usuario/mochilalista-app.git
   cd mochilalista-app/app_movil
   ```

2. **Configuración de Seguridad y Entorno:**
   Mochilalista utiliza un sistema de inyección de secretos para Gemini AI.
   ```bash
   cp .env.example .env
   # Abre .env y coloca tu clave de Google AI Studio en GOOGLE_API_KEY
   ```

3. **Instalación de dependencias y ejecución:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

### 🔨 Comandos Útiles

* **Generar APK para Producción:**
  ```bash
  flutter build apk --release
  ```
* **Corregir Linting e Imports:**
  El proyecto utiliza estrictamente _package imports_.
  ```bash
  dart fix --apply
  ```

---

*Nota Arquitectónica: Desde la v2.0 se deprecó el backend externo en Python para favorecer la escalabilidad en áreas remotas. La v4.0 consolida esta visión mediante un código refactorizado y unificado bajo las mejores prácticas de Dart.*
