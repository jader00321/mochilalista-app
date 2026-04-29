<p align="center">
  <img src="app_movil/assets/logo.png" alt="Mochilalista Logo" width="200">
</p>

<h1 align="center">Mochilalista App v2.0</h1>

<p align="center">
  <strong>Plataforma Full-Stack Inteligente para la Gestión de Ventas, CRM y Automatización de Inventarios.</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter">
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart">
  <img src="https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white" alt="Python">
  <img src="https://img.shields.io/badge/FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white" alt="FastAPI">
  <img src="https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker">
  <img src="https://img.shields.io/badge/PostgreSQL-4169E1?style=for-the-badge&logo=postgresql&logoColor=white" alt="PostgreSQL">
</p>

---

## 🚀 Resumen del Proyecto

**Mochilalista** es una solución empresarial integral diseñada para optimizar el flujo de trabajo de negocios minoristas y mayoristas. El sistema resuelve la problemática de la digitación manual y la gestión de inventarios mediante el uso de **Inteligencia Artificial para el escaneo de comprobantes**, un motor de **Matching Inteligente** y un sistema de cotizaciones dinámico con integración directa a WhatsApp.

Este proyecto representa una arquitectura de software robusta, enfocada en la escalabilidad, la experiencia de usuario (UX) moderna y la eficiencia en el despliegue.

## ✨ Funcionalidades Estrella

* **🧠 Escaneo AI de Listas:** Extracción automatizada de datos desde comprobantes físicos o listas, transformando imágenes en datos estructurados listos para procesar.
* **🛒 Smart Inventory Matcher:** Algoritmo avanzado en el backend que vincula automáticamente los productos detectados por la IA con el catálogo real del negocio.
* **📄 Generador de Cotizaciones PDF:** Creación instantánea de presupuestos profesionales y personalizables en tiempo real.
* **📲 Integración con WhatsApp CRM:** Flujo directo para enviar cotizaciones y realizar seguimiento de clientes sin salir de la app.
* **🏗️ Arquitectura Contenedorizada:** Despliegue seguro, predecible y consistente mediante Docker y Docker Compose.

---

## 📸 Demostración Visual (UX/UI)

| Dashboard Principal | Escaneo Inteligente | Gestión de Inventario |
| :---: | :---: | :---: |
| <img src="URL_DE_TU_CAPTURA_1" width="250" alt="Dashboard"> | <img src="URL_DE_TU_CAPTURA_2" width="250" alt="Scanner IA"> | <img src="URL_DE_TU_CAPTURA_3" width="250" alt="Inventario"> |

---

## 🧠 Arquitectura del Sistema

<details>
<summary><b>Ver detalles del Frontend (Flutter)</b></summary>

<br>

* **Gestión de Estado:** Implementación robusta utilizando `Provider` para un flujo de datos predecible.
* **Arquitectura Modular:** Separación estricta por *features* (`smart_quotation`, `profile`, `scanner`) aislando la capa de presentación (UI), los modelos de datos y los servicios externos.
* **Diseño UI/UX:** Manejo dinámico de temas (Theme Provider) y componentes personalizados.
* **Servicios Externos:** Integración nativa con la cámara del dispositivo, motor de generación de PDFs y *deep linking* hacia WhatsApp Business.

</details>

<details>
<summary><b>Ver detalles del Backend (FastAPI & Python)</b></summary>

<br>

* **Core:** API RESTful asíncrona de alto rendimiento construida con FastAPI.
* **Base de Datos:** Motor PostgreSQL modelado a través de SQLAlchemy (ORM) para garantizar la integridad relacional de catálogos, usuarios y transacciones comerciales.
* **Motor de IA (`ai_extraction_service.py`):** Lógica dedicada para el procesamiento de imágenes y estructuración de diccionarios de datos.
* **Seguridad:** Gestión de autenticación y protección de endpoints mediante JWT y variables de entorno estrictas.

</details>

---

## 🛠️ Entorno de Desarrollo Local (Pruebas)

Este proyecto está diseñado para ser fácilmente replicable. Utiliza Docker para abstraer la complejidad de la infraestructura de la base de datos y el servidor.

<details>
<summary><b>Instrucciones de Despliegue Local</b></summary>

<br>

### Pre-requisitos
* [Docker](https://www.docker.com/) y Docker Compose instalados.
* [Flutter SDK](https://docs.flutter.dev/get-started/install) (versión estable más reciente).

### Pasos para levantar el Backend
1. Clona este repositorio:
   ```bash
   git clone [https://github.com/TU_USUARIO/mochilalista-app.git](https://github.com/TU_USUARIO/mochilalista-app.git)
   ```

2. Navega al directorio del backend y configura el entorno:
    ```bash
    cd mochilalista-app/backend
    ```
    
3. Configuración de Variables: Copia el archivo de ejemplo para crear tus variables locales:
    ```bash
    cp .env.example .env
    (Edita el archivo .env con las credenciales locales de prueba).
    ```
    
4. Levanta los contenedores (FastAPI + PostgreSQL):
    ```bash
    docker-compose up -d --build
    ```
    
Pasos para el Frontend

1. En una nueva terminal, navega a la carpeta de la aplicación móvil:
    ```Bash
    cd mochilalista-app/app_movil
    ```
    
2. Instala las dependencias de Dart:
    ```bash
    flutter pub get
    ```
    
3. Ejecuta la aplicación en tu emulador o dispositivo físico:
    ```bash
    flutter run
    ```
</details>

---

Construido con dedicación para revolucionar la gestión de ventas y procesos comerciales.