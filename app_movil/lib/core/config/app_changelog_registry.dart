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
  // 🚀 NOVEDADES ACTIVAS DE LA VERSIÓN ACTUAL (v9.33.0+77)
  // Perfeccionamiento UX, Solicitud de Planes, Activación Blindada y Google Drive Estilo WhatsApp
  // =========================================================================
  static const List<AppChangelogItem> activeChangelog = [
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
