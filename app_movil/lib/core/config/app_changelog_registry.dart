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
  // 🚀 NOVEDADES ACTIVAS DE LA VERSIÓN ACTUAL (v9.31.0+75)
  // Redacción oficial en beneficios comerciales (sin tecnicismos crípticos).
  // =========================================================================
  static const List<AppChangelogItem> activeChangelog = [
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
    /*
    '9.23.0+73': const [
      AppChangelogItem(
        icon: Icons.offline_bolt_rounded,
        title: "Motor de Licencias Seguro",
        description: "Renovación acumulativa sin pérdida de días y activación 100% offline.",
      ),
      AppChangelogItem(
        icon: Icons.shield_rounded,
        title: "Respaldos Locales Cifrados",
        description: "Protección contra clonación y exportación directa de respaldos.",
      ),
      AppChangelogItem(
        icon: Icons.auto_awesome_rounded,
        title: "Cotizaciones Escolares con IA",
        description: "Cuota de escaneos incluida y clave propia Google AI Studio.",
      ),
      AppChangelogItem(
        icon: Icons.verified_user_rounded,
        title: "Migración Automática de Base de Datos",
        description: "Actualización segura de tablas con copia de seguridad instantánea.",
      ),
    ],
    */
  };
}
