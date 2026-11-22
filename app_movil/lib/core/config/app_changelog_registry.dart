import 'package:flutter/material.dart';
import 'package:app_movil/core/config/owner_legal_identity.dart';

/// Elemento individual de novedad comercial para el comerciante
class AppChangelogItem {
  final IconData icon;
  final String title;
  final String description;

  const AppChangelogItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}

/// Registro centralizado y versionado de novedades de MochilaLista.
/// Única fuente de verdad para el modal post-actualización.
/// Redactado 100% en lenguaje claro y de beneficio directo para dueños de negocio.
class AppChangelogRegistry {
  /// Versión actual activa vinculada al build oficial de la app
  static const String currentVersion = OwnerLegalIdentity.currentAppVersionWithBuild;

  // =========================================================================
  // 🚀 NOVEDADES ACTIVAS DE LA VERSIÓN ACTUAL (v9.36.0+80)
  // Plan Maestro 16: Rediseño UX Perfiles, Escáner QR, Activación y Guía Turística Interactiva
  // =========================================================================
  static const List<AppChangelogItem> activeChangelog = [
    AppChangelogItem(
      icon: Icons.explore_rounded,
      title: "Guía Turística Interactiva Paso a Paso",
      description:
          "Nuevo recorrido guiado interactivo disponible en las 10 pantallas principales de la app. Actívalo cuando desees desde el botón de ayuda (?) o gestiónalo desde tu Perfil.",
    ),
    AppChangelogItem(
      icon: Icons.qr_code_scanner_rounded,
      title: "Escáner QR Profesional con Enfoque y Galería",
      description:
          "Escanea códigos de activación con total comodidad frente a pantallas de PC con controles de zoom, linterna y enfoque táctil, o cárgalos directo desde tu galería de fotos.",
    ),
    AppChangelogItem(
      icon: Icons.cloud_sync_rounded,
      title: "Perfiles y Respaldo Inteligente Rediseñados",
      description:
          "Zona inferior limpia y estilizada, menú de Google Drive y respaldo .mlbg con confirmación animada paso a paso y conteo gramatical exacto de tus negocios.",
    ),
    AppChangelogItem(
      icon: Icons.verified_rounded,
      title: "Activación Visual y Mensajes Amigables",
      description:
          "Nuevo modal interactivo con mensajes claros y humanos al canjear licencias comerciales o bonos de recarga de inteligencia artificial.",
    ),
  ];

  /// Retorna las novedades destacadas de la versión más reciente
  static List<AppChangelogItem> getLatestChangelog() {
    return activeChangelog;
  }

  /// Retorna las novedades de una versión específica o las activas por defecto
  static List<AppChangelogItem> getChangelogForVersion(String version) {
    if (_historicalChangelogs.containsKey(version)) {
      return _historicalChangelogs[version]!;
    }
    return activeChangelog;
  }

  // =========================================================================
  // 📦 HISTORIAL DE NOVEDADES ARCHIVADAS DE VERSIONES ANTERIORES
  // En cada nueva compilación de release, mover aquí el bloque anterior.
  // =========================================================================
  static final Map<String, List<AppChangelogItem>> _historicalChangelogs = {
    '9.35.0+79': const [
      AppChangelogItem(
        icon: Icons.auto_awesome_rounded,
        title: "Bono y Recarga IA Personalizada",
        description:
            "Canjea bonos y recargas de inteligencia artificial con cantidades a tu medida sin alterar la fecha de vencimiento de tu suscripción ni de tu período de prueba.",
      ),
      AppChangelogItem(
        icon: Icons.phonelink_setup_rounded,
        title: "Migración Segura de Dispositivo",
        description:
            "Reactivación fluida al cambiar de celular o restaurar copias de seguridad de Google Drive: cero duplicación de días y preservación íntegra de tu saldo IA.",
      ),
      AppChangelogItem(
        icon: Icons.receipt_long_rounded,
        title: "Comprobantes y Boletas Oficiales",
        description:
            "Soporte administrativo optimizado para control de licencias, renovaciones preventivas y respaldo contable local.",
      ),
      AppChangelogItem(
        icon: Icons.security_rounded,
        title: "Blindaje Criptográfico Anti-Clonación",
        description:
            "Verificación Ed25519 con control de nonces estrictos y protección contra alteración de hora del sistema.",
      ),
      AppChangelogItem(
        icon: Icons.cloud_download_rounded,
        title: "Google Drive en Pantalla Inicial",
        description:
            "Vincula tu cuenta de Google y restaura tus respaldos en la nube directamente desde la pantalla de perfiles inicial, sin crear negocios ficticios.",
      ),
      AppChangelogItem(
        icon: Icons.verified_user_rounded,
        title: "Semáforo de Respaldo y Blindaje SHA-256",
        description:
            "Indicador visual de salud de tus copias (Al día / Atención / Sin copias) y endurecimiento Anti-Tampering con certificado comercial RSA-4096.",
      ),
    ],
    '9.34.0+78': const [
      AppChangelogItem(
        icon: Icons.gavel_rounded,
        title: "EULA Definitivo y Autorreparable",
        description:
            "Los Términos de Licencia se aceptan una sola vez. Al restaurar copias de seguridad de cualquier versión, la app se autorrepara en silencio y no vuelve a pedir el EULA.",
      ),
      AppChangelogItem(
        icon: Icons.cloud_download_rounded,
        title: "Google Drive en Pantalla Inicial",
        description:
            "Vincula tu cuenta de Google y restaura tus respaldos en la nube directamente desde la pantalla de perfiles inicial, sin crear negocios ficticios.",
      ),
      AppChangelogItem(
        icon: Icons.speed_rounded,
        title: "Respaldo Reactivo y Fluido en RAM",
        description:
            "Carga instantánea de copias en memoria y patrón Stale-While-Revalidate: navegación suave sin recargas destructivas ni saltos visuales al hacer scroll.",
      ),
      AppChangelogItem(
        icon: Icons.visibility_rounded,
        title: "Historial Nítido y Fechas Locales",
        description:
            "Barra de estado superior perfectamente legible en cualquier tema, fechas y horas locales completas en tu zona horaria y correo visible al 100%.",
      ),
      AppChangelogItem(
        icon: Icons.touch_app_rounded,
        title: "Solicitud de Planes con Foco Inteligente",
        description:
            "Modal de pedido optimizado con chips compactos, redacción comercial exacta y desenfoque automático al tocar cualquier botón interactivo.",
      ),
      AppChangelogItem(
        icon: Icons.verified_user_rounded,
        title: "Semáforo de Respaldo y Blindaje SHA-256",
        description:
            "Indicador visual de salud de tus copias (Al día / Atención / Sin copias) y endurecimiento Anti-Tampering con certificado comercial RSA-4096.",
      ),
    ],
    '9.33.0+77': const [
      AppChangelogItem(
        icon: Icons.system_update_rounded,
        title: "Actualización Confiable y Segura",
        description:
            "El aviso de bienvenida se presenta únicamente al actualizar de versión, garantizando que restaurar copias de seguridad jamás dispare falsos avisos.",
      ),
      AppChangelogItem(
        icon: Icons.cloud_sync_rounded,
        title: "Respaldo en la Nube Estilo WhatsApp",
        description:
            "Restauración guiada de hasta las 5 copias más recientes al vincular tu cuenta de Google, arranque limpio tras desinstalar y diagnóstico asistido.",
      ),
      AppChangelogItem(
        icon: Icons.shopping_bag_outlined,
        title: "Solicitud de Planes Interactiva",
        description:
            "Nuevo modal de pedido protegido con chips rápidos de personalización, resumen transparente y diseñado a la medida de tu teléfono.",
      ),
      AppChangelogItem(
        icon: Icons.paste_rounded,
        title: "Activación Inteligente de Licencia",
        description:
            "Detección exacta de tokens oficiales al abrir la app, copiado seguro sin duplicaciones y visualización completa y clara de mensajes.",
      ),
      AppChangelogItem(
        icon: Icons.document_scanner_rounded,
        title: "Escaneo Visualmente Renovado",
        description:
            "Pantalla de escaneo de listas escolares rediseñada con mayor espacio, tipografías consistentes e instrucciones directas para agilizar tu venta.",
      ),
      AppChangelogItem(
        icon: Icons.new_releases_rounded,
        title: "Novedades Siempre Disponibles",
        description:
            "Consulta los cambios y mejoras del sistema en cualquier momento desde tu Perfil comercial, con una interfaz limpia y sin opciones duplicadas.",
      ),
    ],
    '9.32.0+76': const [
      AppChangelogItem(
        icon: Icons.sync_rounded,
        title: "Sincronización Reactiva 1:1 de Cuotas IA",
        description:
            "Tu saldo de escaneos IA se actualiza al instante en todas las pantallas tanto en Bolsa Oficial como en Clave Propia (BYOK), sin desincronizaciones.",
      ),
      AppChangelogItem(
        icon: Icons.cloud_done_rounded,
        title: "Google Drive Multi-Perfil y Modo Manual",
        description:
            "Respaldos integrales de todos tus negocios (.mlbg) en la nube, con conmutador explícito Automático/Manual y diagnóstico OAuth transparente.",
      ),
      AppChangelogItem(
        icon: Icons.shopping_bag_outlined,
        title: "Pedido de Licencia Personalizable",
        description:
            "Nuevo modal interactivo al tocar 'Pedir' en cualquier plan: edita tu mensaje antes de enviar, copia al portapapeles o abre WhatsApp directo.",
      ),
      AppChangelogItem(
        icon: Icons.security_rounded,
        title: "Gobernanza Legal y Blindaje de Canje",
        description:
            "Contrato EULA garantizado en instalaciones limpias, acceso permanente a 'Novedades', botones QR simétricos y protección anti-recanje con iat.",
      ),
    ],
    '9.31.0+75': const [
      AppChangelogItem(
        icon: Icons.offline_bolt_rounded,
        title: "Activación 100% Offline sin Internet",
        description:
            "Tu sistema comercial y tus renovaciones funcionan en cualquier lugar sin depender de servidores caídos ni señal móvil.",
      ),
      AppChangelogItem(
        icon: Icons.shield_rounded,
        title: "Copias de Seguridad Blindadas",
        description:
            "Resguarda tu inventario, clientes y ventas en tu celular o compártelo a tu WhatsApp con protección contra robos.",
      ),
      AppChangelogItem(
        icon: Icons.auto_awesome_rounded,
        title: "Escaneo Inteligente de Listas Escolares con IA",
        description:
            "Digitaliza listas de útiles y facturas arrugadas al instante con Inteligencia Artificial y opción de escaneos ilimitados.",
      ),
      AppChangelogItem(
        icon: Icons.verified_user_rounded,
        title: "Protección Automática de tus Datos",
        description:
            "Tus precios, cuentas por cobrar y stock están resguardados con respaldo automático en cada actualización.",
      ),
    ],
  };
}
