import '../core/commercial_constants.dart';

/// Generador declarativo completo de `owner_commercial_defaults.dart` para `app_movil/`.
class DartDefaultsExporter {
  DartDefaultsExporter._();

  static String escapeDartSingleQuoted(String raw) {
    return raw
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll(r'$', r'\$')
        .replaceAll('\r', ' ')
        .replaceAll('\n', r'\n');
  }

  static String sanitizeString(dynamic raw, {int maxLength = 240}) {
    final s = (raw?.toString() ?? '').replaceAll('\r', ' ').trim();
    if (s.length > maxLength) {
      return s.substring(0, maxLength).trim();
    }
    return s;
  }

  /// Renderiza el archivo Dart completo `owner_commercial_defaults.dart` listo para
  /// copiar (`Ctrl+A -> Ctrl+V`) o descargar y compilar en nuevas versiones APK.
  static String renderOwnerCommercialDefaultsDartFile({
    required Map<String, dynamic> config,
    required Map<String, dynamic> canonicalPayload,
    required int effectiveRevision,
  }) {
    final li = config['legal_identity'] is Map
        ? Map<String, dynamic>.from(config['legal_identity'] as Map)
        : <String, dynamic>{};
    final pm = config['payment_methods'] is Map
        ? Map<String, dynamic>.from(config['payment_methods'] as Map)
        : <String, dynamic>{};

    final bcp = canonicalPayload['bcp'] as Map<String, dynamic>;
    final bbva = canonicalPayload['bbva'] as Map<String, dynamic>;
    final products = canonicalPayload['p'] as Map<String, dynamic>;

    final author = escapeDartSingleQuoted(
      sanitizeString(
          li['author_full_name'] ?? CommercialConstants.defaultAuthorName),
    );
    final commercialName = escapeDartSingleQuoted(
      sanitizeString(
          li['commercial_name'] ?? CommercialConstants.defaultCommercialName),
    );
    final supportPhone =
        escapeDartSingleQuoted(canonicalPayload['sup'] as String);
    final cleanSupDigits =
        (canonicalPayload['sup'] as String).replaceAll(RegExp(r'[^0-9]'), '');
    final whatsappUrl = escapeDartSingleQuoted(
      cleanSupDigits.isNotEmpty
          ? 'https://wa.me/$cleanSupDigits'
          : sanitizeString(
              li['support_whatsapp_url'] ??
                  CommercialConstants.defaultSupportWhatsAppUrl,
            ),
    );
    final website = escapeDartSingleQuoted(
      sanitizeString(
          li['official_website'] ?? CommercialConstants.defaultOfficialWebsite),
    );
    final legalFramework = escapeDartSingleQuoted(
      sanitizeString(
        li['legal_framework'] ??
            'Protegido por el D.L. 822 (Ley de Derecho de Autor) e INDECOPI',
      ),
    );
    final dataLaw = escapeDartSingleQuoted(
      sanitizeString(
        li['personal_data_law'] ?? CommercialConstants.defaultPersonalDataLaw,
      ),
    );
    final yapeHolder = escapeDartSingleQuoted(canonicalPayload['yh'] as String);
    final yapePhone = escapeDartSingleQuoted(canonicalPayload['yp'] as String);
    final bcpHolder = escapeDartSingleQuoted(bcp['h'] as String);
    final bcpAcc = escapeDartSingleQuoted(bcp['acc'] as String);
    final bcpCci = escapeDartSingleQuoted(bcp['cci'] as String);
    final bbvaHolder = escapeDartSingleQuoted(bbva['h'] as String);
    final bbvaAcc = escapeDartSingleQuoted(bbva['acc'] as String);
    final bbvaCci = escapeDartSingleQuoted(bbva['cci'] as String);

    final buf = StringBuffer()
      ..writeln(
          '// Archivo autogenerado desde MochilaLista Admin (owner_config.json • Revisión MLC1 #$effectiveRevision)')
      ..writeln(
          '// Ruta destino: app_movil/lib/core/config/owner_commercial_defaults.dart')
      ..writeln(
          '// Instrucciones: Ctrl+A -> Ctrl+V o reemplaza este archivo completo antes de compilar.')
      ..writeln('')
      ..writeln(
          '/// Parámetros comerciales compilados por defecto para MochilaLista POS Móvil.')
      ..writeln('///')
      ..writeln(
          '/// Archivo 100 % declarativo y puro (sin dependencias de Flutter UI ni SQLite).')
      ..writeln('class OwnerCommercialDefaults {')
      ..writeln(
          '  static const int commercialSyncDefaultRevision = $effectiveRevision;')
      ..writeln("  static const String authorFullName = '$author';")
      ..writeln("  static const String appCommercialName = '$commercialName';")
      ..writeln(
          "  static const String legalFrameworkNotice = '$legalFramework';")
      ..writeln("  static const String personalDataLawNotice = '$dataLaw';")
      ..writeln("  static const String supportPhone = '$supportPhone';")
      ..writeln("  static const String supportWhatsAppUrl = '$whatsappUrl';")
      ..writeln("  static const String officialWebsite = '$website';")
      ..writeln("  static const String yapePlinHolder = '$yapeHolder';")
      ..writeln("  static const String yapePlinPhone = '$yapePhone';")
      ..writeln("  static const String bcpAccountHolder = '$bcpHolder';")
      ..writeln("  static const String bcpAccountNumber = '$bcpAcc';")
      ..writeln("  static const String bcpCciNumber = '$bcpCci';")
      ..writeln("  static const String bbvaAccountHolder = '$bbvaHolder';")
      ..writeln("  static const String bbvaAccountNumber = '$bbvaAcc';")
      ..writeln("  static const String bbvaCciNumber = '$bbvaCci';")
      ..writeln('')
      ..writeln(
          '  /// Catálogo comercial por defecto compilado para nuevas versiones APK')
      ..writeln(
          '  static const Map<String, Map<String, Object>> defaultCommercialPlans = {');

    for (final id in CommercialConstants.catalogSlugToSyncId.values) {
      final p = products[id] as Map<String, dynamic>;
      final priceStr = ((p['pr'] as num).toDouble()).toStringAsFixed(2);
      final labelEsc = escapeDartSingleQuoted(p['lb'] as String);
      final descEsc = escapeDartSingleQuoted(p['ds'] as String);
      buf
        ..writeln("    '$id': {")
        ..writeln("      'pr': $priceStr,")
        ..writeln("      'd': ${p['d']},")
        ..writeln("      'ai': ${p['ai']},")
        ..writeln("      'um': ${p['um']},")
        ..writeln("      'lb': '$labelEsc',")
        ..writeln("      'ds': '$descEsc',")
        ..writeln('    },');
    }
    buf
      ..writeln('  };')
      ..writeln('}');

    assert(pm.isEmpty || pm.isNotEmpty);
    return buf.toString();
  }
}
