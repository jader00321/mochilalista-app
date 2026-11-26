import '../apk/apk_models.dart';
import '../core/commercial_constants.dart';

/// Valores oficiales de fábrica y alias de plantillas para `owner_config.json`.
class ConfigDefaults {
  ConfigDefaults._();

  static const String defaultFlutterBuildDir =
      '../app_movil/build/app/outputs/flutter-apk';
  static const String defaultWindowsApkLibraryDir =
      r'C:\Users\vjuli\Documents\v-app-offline apks';

  /// Normaliza alias canónicos entre claves de `templates` (`welcome` <-> `trial_welcome`, etc.).
  static String canonicalTemplateKey(String key) {
    switch (key.trim()) {
      case 'welcome':
        return 'trial_welcome';
      case 'expiring':
        return 'expiring_reminder';
      case 'license':
        return 'license_issued';
      case 'update':
        return 'apk_update_eligible';
      default:
        return key.trim();
    }
  }

  /// Construye la lista por defecto de rutas de búsqueda APK a partir de [apkLibraryDir].
  static List<ApkSearchDirConfig> buildDefaultApkSearchDirs({
    required String apkLibraryDir,
    String? defaultBuildOutputDir,
  }) {
    final flutterPath =
        (defaultBuildOutputDir != null && defaultBuildOutputDir.trim().isNotEmpty)
            ? defaultBuildOutputDir.trim()
            : defaultFlutterBuildDir;
    return [
      ApkSearchDirConfig(
        path: apkLibraryDir,
        label: 'Biblioteca Oficial (v-app-offline apks)',
        enabled: true,
        isDefault: true,
        kind: 'official_library',
      ),
      ApkSearchDirConfig(
        path: flutterPath,
        label: 'Compilación Local (app_movil/build)',
        enabled: true,
        isDefault: true,
        kind: 'flutter_build',
      ),
    ];
  }

  /// Helper de fusión profunda recursiva (preserva subclaves por defecto si faltan en el input).
  static Map<String, dynamic> deepMerge(
    Map<String, dynamic> base,
    Map<String, dynamic> overrides,
  ) {
    final result = <String, dynamic>{};
    base.forEach((key, value) {
      if (value is Map) {
        result[key] = deepMerge(Map<String, dynamic>.from(value), {});
      } else {
        result[key] = value;
      }
    });
    overrides.forEach((key, value) {
      if (value is Map && result[key] is Map) {
        result[key] = deepMerge(
          Map<String, dynamic>.from(result[key] as Map),
          Map<String, dynamic>.from(value),
        );
      } else {
        result[key] = value;
      }
    });
    return result;
  }

  /// Retorna la configuración oficial de fábrica completa (10 ítems y 9 plantillas WA).
  static Map<String, dynamic> getDefaultConfig() {
    return {
      'system': {
        'default_mode': 'sandbox',
        'theme': 'dark',
        'table_density': 'comfortable',
        'version': '1.0.0',
        'commercial_sync_revision': 0,
        'apk_library_dir': defaultWindowsApkLibraryDir,
      },
      'legal_identity': {
        'author_full_name': CommercialConstants.defaultAuthorName,
        'commercial_name': CommercialConstants.defaultCommercialName,
        'support_phone': CommercialConstants.defaultSupportPhone,
        'support_whatsapp_url': CommercialConstants.defaultSupportWhatsAppUrl,
        'official_website': CommercialConstants.defaultOfficialWebsite,
        'legal_framework': CommercialConstants.defaultLegalFramework,
        'personal_data_law': CommercialConstants.defaultPersonalDataLaw,
      },
      'payment_methods': {
        'yape_plin_holder': CommercialConstants.defaultAuthorName,
        'yape_plin_phone': CommercialConstants.defaultYapePlinPhone,
        'bcp_account_holder': '',
        'bcp_account_number': '',
        'bcp_cci': '',
        'bbva_account_holder': '',
        'bbva_account_number': '',
        'bbva_cci': '',
      },
      'catalog': {
        'TRIAL': {
          'price': 0.0,
          'days': 30,
          'ai_credits': 50,
          'updates_window_months': 0,
          'updates_months': 0,
          'label': 'Prueba Gratuita',
          'description':
              'Evaluación gratuita de 30 días con funciones POS completas e IA.',
        },
        'MENSUAL': {
          'price': 35.0,
          'days': 30,
          'ai_credits': 50,
          'updates_window_months': 0,
          'updates_months': 0,
          'label': 'Plan Mensual',
          'description':
              'Suscripción mensual flexible 100% offline con respaldo de base local.',
        },
        'TRIMESTRAL': {
          'price': 90.0,
          'days': 90,
          'ai_credits': 180,
          'updates_window_months': 0,
          'updates_months': 0,
          'label': 'Plan Trimestral',
          'description':
              'Suscripción trimestral de 90 días con bolsa IA ampliada (+180 escaneos).',
        },
        'SEMESTRAL': {
          'price': 160.0,
          'days': 180,
          'ai_credits': 450,
          'updates_window_months': 0,
          'updates_months': 0,
          'label': 'Plan Semestral',
          'description':
              'Suscripción semestral de 180 días con +450 escaneos IA acumulados.',
        },
        'ANUAL': {
          'price': 280.0,
          'days': 365,
          'ai_credits': 1200,
          'updates_window_months': 0,
          'updates_months': 0,
          'label': 'Plan Anual',
          'description':
              'Suscripción anual prioritaria con +1,200 escaneos IA vitalicios incluidos.',
        },
        'PERPETUO_LIBERADO': {
          'price': 850.0,
          'days': 99999,
          'ai_credits': 200,
          'updates_window_months': 12,
          'updates_months': 12,
          'label': 'Perpetuo Liberado',
          'description':
              'Licencia vitalicia para tu negocio con 12 meses de actualizaciones incluidos.',
        },
        'PASE_ACTUALIZACION_ANUAL': {
          'price': 150.0,
          'days': 0,
          'updates_window_months': 12,
          'updates_months': 12,
          'ai_credits': 100,
          'label': 'Pase Anual de Updates',
          'description':
              'Renovación anual de versiones APK (+12 meses de actualizaciones y +100 IA).',
        },
        'RECARGA_IA_150': {
          'price': 20.0,
          'days': 0,
          'ai_credits': 150,
          'updates_window_months': 0,
          'updates_months': 0,
          'label': 'Recarga Extra IA (+150)',
          'description':
              'Bolsa adicional de +150 escaneos de IA acumulativos sin vencimiento.',
        },
        'EXTENSION_CORTESIA': {
          'price': 0.0,
          'days': 7,
          'ai_credits': 0,
          'updates_window_months': 0,
          'updates_months': 0,
          'label': 'Extensión de Cortesía',
          'description':
              'Extensión temporal de gracia sin costo (S/ 0.00) por 7 días.',
        },
        'HARDWARE_MIGRATION_FEE': {
          'price': 40.0,
          'days': 0,
          'ai_credits': 0,
          'updates_window_months': 0,
          'updates_months': 0,
          'label': 'Tarifa Técnica de Migración',
          'description':
              'Servicio técnico de traslado y re-emisión de licencia a un nuevo celular.',
        },
      },
      'templates': {
        'license_issued':
            'Hola {titular}, te saluda {autor} de MochilaLista.\n\n'
            '¡Tu licencia para *{negocio}* ha sido emitida exitosamente!\n\n'
            '⭐ *Plan:* {plan} ({dias} días)\n'
            '📱 *Dispositivo Vinculado:* {device_id}\n'
            '📅 *Vigencia hasta:* {vencimiento}\n'
            '⚡ *Escáner IA:* +{creditos_ia} escaneos acumulados acreditados\n\n'
            '🔑 *Tu Código de Activación Oficial:*\n'
            '{codigo}\n\n'
            'Para activarlo en tu app:\n'
            '1. Abre MochilaLista en tu teléfono.\n'
            '2. Ve a Menú > Licencia y Activación.\n'
            '3. Pega el código de arriba o escanea la credencial oficial adjunta.\n\n'
            '¡Gracias por tu confianza y éxito en tus ventas!',
        'expiring_reminder':
            'Hola {titular}, te saluda {autor} de MochilaLista.\n\n'
            'Te recordamos que la licencia de tu negocio *{negocio}* vence en *{dias_restantes} días* ({vencimiento}).\n\n'
            'Para renovar tu servicio sin interrupciones en tus ventas:\n'
            '💳 Yape / Plin: {yape_phone} ({yape_titular}){bloque_banco_bcp}{bloque_banco_bbva}\n\n'
            'Quedo a tu disposición para emitir tu renovación inmediata.',
        'trial_welcome':
            '¡Bienvenido a MochilaLista, {titular}!\n\n'
            'Hemos activado tu periodo de prueba gratuita de 30 días para *{negocio}* con 50 escaneos inteligentes de IA incluidos.\n\n'
            '📱 *Dispositivo:* {device_id}\n'
            '📅 *Vence el:* {vencimiento}\n\n'
            '🔑 *Tu Código de Activación:*\n'
            '{codigo}\n\n'
            '¡Comienza a registrar tus ventas e inventario hoy mismo!',
        'prospect':
            'Hola {titular}, te saluda {autor} de MochilaLista.\n\n'
            'Nos comunicamos para hacer seguimiento a la evaluación del sistema de punto de venta en tu negocio *{negocio}*.\n\n'
            '¿Has tenido oportunidad de revisar las funciones de cobro rápido, inventario e IA offline?\n'
            'Con gusto podemos coordinar una breve demostración o habilitarte una activación personalizada adaptada al ritmo de tu negocio.\n\n'
            'Quedamos a tu orden.',
        'ai_bonus':
            'Hola {titular}, te saluda {autor} de MochilaLista.\n\n'
            'Tu recarga de escaneos de Inteligencia Artificial para *{negocio}* ha sido acreditada con éxito.\n\n'
            '*Detalle de la Recarga:*\n'
            '• Créditos IA Otorgados: +{creditos_ia} escaneos vitalicios\n'
            '• Hardware ID Vinculado: `{device_id}`\n\n'
            '*Token de Activación IA:*\n'
            '{codigo}\n\n'
            'Ingresa este código o escanea el QR en tu app para sumarlos de inmediato a tu saldo disponible.',
        'courtesy_extension':
            'Estimado(a) {titular}, te saluda {autor} de MochilaLista.\n\n'
            'Te confirmamos la habilitación de una extensión de cortesía por *{dias} día(s)* adicionales para *{negocio}*.\n\n'
            '• Nueva vigencia temporal: *{vencimiento}*\n'
            '• Hardware ID: `{device_id}`\n\n'
            '*Código de Activación:*\n'
            '{codigo}\n\n'
            'Ingresa este código en tu aplicación para continuar operando sin interrupciones.',
        'apk_update_eligible':
            'Hola {titular}, te saluda {autor} de MochilaLista.\n\n'
            '¡Tenemos lista una nueva actualización oficial para *{negocio}*!\n\n'
            '📦 *Versión:* MochilaLista v{version}\n'
            '✨ *Novedades:*\n'
            '{changelog}\n\n'
            '📥 *Enlace de Descarga Directa:*\n'
            '{link_descarga}\n\n'
            '🛡️ *Garantía Cero Pérdida:* Al instalar este APK sobre el actual, tu base de datos y productos se mantienen 100% intactos.',
        'apk_update_quote':
            'Hola {titular}, te saluda {autor} de MochilaLista.\n\n'
            'Acabamos de lanzar la versión oficial *v{version}* con mejoras avanzadas.\n'
            'Tu negocio *{negocio}* cuenta con la versión v{version_actual}.\n\n'
            'Para acceder a este paquete de nuevas funciones, puedes adquirir tu *Pase Anual de Actualizaciones* por solo S/ {precio_pase}.\n'
            '¿Deseas que te emita el pase hoy mismo?',
        'device_migration':
            'Hola {titular}, te saluda {autor} de MochilaLista.\n\n'
            'Hemos completado la migración de tu licencia al nuevo teléfono para *{negocio}*.\n\n'
            '📱 *Nuevo Dispositivo:* {device_id}\n'
            '📅 *Vencimiento Preservado:* {vencimiento}\n'
            '⚡ *Saldo IA Preservado:* +{creditos_ia} escaneos disponibles\n\n'
            '🔑 *Tu Nuevo Código de Activación:*\n'
            '{codigo}\n\n'
            'Actívalo en tu nuevo teléfono para continuar operando sin contratiempos.',
      },
      'receipt_config': {
        'title': 'BOLETA DE PAGO ADMINISTRATIVA',
        'commercial_name': CommercialConstants.defaultCommercialName,
        'issuer_name': CommercialConstants.defaultAuthorName,
        'issuer_doc': 'D.N.I. / R.U.C. Registrado',
        'issuer_phone': CommercialConstants.defaultSupportPhone,
        'issuer_city': 'Piura, Perú',
        'show_logo': true,
        'accent_color': '#2563eb',
        'footer_notes':
            'Software de Punto de Venta Offline. Comprobante de control administrativo y soporte técnico.',
        'signature_text': 'Administración Comercial — MochilaLista',
        'next_correlative': 1,
        'sandbox_next_correlative': 1,
        'next_invoice_correlative': 1,
        'sandbox_next_invoice_correlative': 1,
        'show_igv_breakdown': false,
        'show_issuer_doc': true,
        'show_issuer_phone': true,
        'show_client_doc': true,
        'show_hardware_id': true,
        'show_operation_number': true,
        'show_observation': true,
        'show_signature': true,
        'show_footer_notes': true,
      },
    };
  }
}
