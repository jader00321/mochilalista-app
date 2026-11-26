import '../core/commercial_constants.dart';
import '../core/time_utils.dart';

/// Validador de esquema, constructor de resúmenes y comparador diff para fichas `MLC1-...`.
class Mlc1PayloadInspector {
  Mlc1PayloadInspector._();

  static const Set<String> allowedTopLevelKeys = {
    'v',
    'ver',
    'iat',
    'sup',
    'yh',
    'yp',
    'bcp',
    'bbva',
    'p',
  };

  static const Set<String> allowedBankKeys = {'h', 'acc', 'cci'};
  static const Set<String> allowedProductKeys = {
    'pr',
    'd',
    'ai',
    'um',
    'lb',
    'ds',
  };

  /// Extrae un resumen diagnóstico tolerante a campos parciales o corruptos (solo lectura).
  static Map<String, dynamic> buildDiagnosticSummaryFromMap(
    Map<String, dynamic> rawMap,
  ) {
    final rev = (rawMap['ver'] is num) ? (rawMap['ver'] as num).toInt() : null;
    final iat = (rawMap['iat'] is num) ? (rawMap['iat'] as num).toInt() : null;
    String? issuedLima;
    if (iat != null && iat > 0) {
      final dt = DateTime.fromMillisecondsSinceEpoch(iat * 1000, isUtc: true);
      issuedLima = PeruTimeHelper.formatLimaDateTime(dt);
    }
    final productsRaw = rawMap['p'];
    final unexpectedKeys = rawMap.keys
        .map((k) => k.toString())
        .where((k) => !allowedTopLevelKeys.contains(k))
        .toList();

    return {
      'revision': rev,
      'schema_version': rawMap['v'],
      'issued_at_lima': issuedLima,
      'support_phone': rawMap['sup']?.toString(),
      'yape_holder': rawMap['yh']?.toString(),
      'yape_phone': rawMap['yp']?.toString(),
      'products_count': productsRaw is Map ? productsRaw.length : 0,
      'unexpected_keys': unexpectedKeys,
    };
  }

  static String _formatBankAccountDisplay(Map? bankMap) {
    if (bankMap == null) return 'Omitido';
    final acc = (bankMap['acc'] ?? '').toString().trim();
    final cci = (bankMap['cci'] ?? '').toString().trim();
    final holder = (bankMap['h'] ?? '').toString().trim();
    if (acc.isEmpty && cci.isEmpty && holder.isEmpty) return 'Omitido';
    final parts = <String>[];
    if (acc.isNotEmpty) parts.add(acc);
    if (cci.isNotEmpty) parts.add('CCI: $cci');
    if (holder.isNotEmpty) parts.add(holder);
    return parts.join(' · ');
  }

  static bool _bankAccountsEqual(Map? a, Map? b) {
    for (final k in const ['h', 'acc', 'cci']) {
      final av = (a?[k] ?? '').toString().trim();
      final bv = (b?[k] ?? '').toString().trim();
      if (av != bv) return false;
    }
    return true;
  }

  /// Compara la ficha `MLC1` decodificada contra la revisión local y `owner_config.json`.
  static Map<String, dynamic> buildCurrentConfigComparison({
    required Map<String, dynamic> decodedPayload,
    required Map<String, dynamic> currentConfig,
    required int localRevision,
    required Map<String, dynamic> Function(
      Map<String, dynamic> config,
      int revision,
    ) buildSnapshot,
    required Map<String, dynamic> Function(Map<String, dynamic> config)
        buildFallbackSnapshot,
  }) {
    final tokenRev = (decodedPayload['ver'] as num?)?.toInt() ?? 0;
    final safeLocalRev = localRevision < 0 ? 0 : localRevision;

    final String revisionStatus;
    final String revisionStatusLabel;
    final String recommendation;
    if (safeLocalRev >= 1 && tokenRev == safeLocalRev) {
      revisionStatus = 'CURRENT';
      revisionStatusLabel = 'Revisión vigente en Admin';
      recommendation =
          'Revisión vigente actual en Admin — Lista para compartir con tus clientes.';
    } else if (tokenRev < safeLocalRev) {
      revisionStatus = 'SUPERSEDED';
      revisionStatusLabel = 'Revisión anterior a la local';
      recommendation =
          'Revisión anterior — Los celulares que ya aplicaron la Rev. #$safeLocalRev la rechazarán por protección anti-downgrade; genera una ficha nueva si deseas actualizarlos.';
    } else {
      revisionStatus = 'AHEAD_OR_EXTERNAL';
      revisionStatusLabel = 'Revisión superior a la local';
      recommendation =
          'Revisión superior a la local — Emitida en otro equipo o antes de restaurar un respaldo.';
    }

    Map<String, dynamic> currentSnapshot;
    try {
      currentSnapshot =
          buildSnapshot(currentConfig, safeLocalRev < 1 ? 1 : safeLocalRev);
    } catch (_) {
      currentSnapshot = buildFallbackSnapshot(currentConfig);
    }

    final tokProducts = decodedPayload['p'] is Map
        ? decodedPayload['p'] as Map
        : const <String, dynamic>{};
    final curProducts = currentSnapshot['p'] is Map
        ? currentSnapshot['p'] as Map
        : const <String, dynamic>{};

    final productsDiff = <Map<String, dynamic>>[];
    int diffCount = 0;

    for (final id in CommercialConstants.catalogSlugToSyncId.values) {
      final tp = tokProducts[id] is Map ? tokProducts[id] as Map : const {};
      final cp = curProducts[id] is Map ? curProducts[id] as Map : const {};

      final tokPr = ((tp['pr'] as num?)?.toDouble() ?? 0.0);
      final tokD = (tp['d'] as num?)?.toInt() ?? 0;
      final tokAi = (tp['ai'] as num?)?.toInt() ?? 0;
      final tokUm = (tp['um'] as num?)?.toInt() ?? 0;
      final tokLb = (tp['lb'] ?? '').toString().trim();

      final curPr = ((cp['pr'] as num?)?.toDouble() ?? 0.0);
      final curD = (cp['d'] as num?)?.toInt() ?? 0;
      final curAi = (cp['ai'] as num?)?.toInt() ?? 0;
      final curUm = (cp['um'] as num?)?.toInt() ?? 0;
      final curLb = (cp['lb'] ?? '').toString().trim();

      final changedFields = <String>[];
      if ((tokPr - curPr).abs() >= 0.005) changedFields.add('pr');
      if (tokD != curD) changedFields.add('d');
      if (tokAi != curAi) changedFields.add('ai');
      if (tokUm != curUm) changedFields.add('um');

      final matches = changedFields.isEmpty;
      if (!matches) diffCount++;

      productsDiff.add({
        'id': id,
        'label': curLb.isNotEmpty ? curLb : (tokLb.isNotEmpty ? tokLb : id),
        'token_label': tokLb,
        'current_label': curLb,
        'token_values': {
          'pr': tokPr,
          'd': tokD,
          'ai': tokAi,
          'um': tokUm,
        },
        'current_values': {
          'pr': curPr,
          'd': curD,
          'ai': curAi,
          'um': curUm,
        },
        'changed_fields': changedFields,
        'matches': matches,
      });
    }

    final tokSup = (decodedPayload['sup'] ?? '').toString().trim();
    final curSup = (currentSnapshot['sup'] ?? '').toString().trim();
    final tokYh = (decodedPayload['yh'] ?? '').toString().trim();
    final curYh = (currentSnapshot['yh'] ?? '').toString().trim();
    final tokYp = (decodedPayload['yp'] ?? '').toString().trim();
    final curYp = (currentSnapshot['yp'] ?? '').toString().trim();
    final tokBcp =
        decodedPayload['bcp'] is Map ? decodedPayload['bcp'] as Map : null;
    final curBcp =
        currentSnapshot['bcp'] is Map ? currentSnapshot['bcp'] as Map : null;
    final tokBbva =
        decodedPayload['bbva'] is Map ? decodedPayload['bbva'] as Map : null;
    final curBbva =
        currentSnapshot['bbva'] is Map ? currentSnapshot['bbva'] as Map : null;

    final channelsDiff = <Map<String, dynamic>>[
      {
        'key': 'sup',
        'label': 'Teléfono Soporte',
        'token_value': tokSup.isEmpty ? 'Omitido' : tokSup,
        'current_value': curSup.isEmpty ? 'Omitido' : curSup,
        'matches': tokSup == curSup,
      },
      {
        'key': 'yh',
        'label': 'Titular Yape / Plin',
        'token_value': tokYh.isEmpty ? 'Omitido' : tokYh,
        'current_value': curYh.isEmpty ? 'Omitido' : curYh,
        'matches': tokYh == curYh,
      },
      {
        'key': 'yp',
        'label': 'Número Yape / Plin',
        'token_value': tokYp.isEmpty ? 'Omitido' : tokYp,
        'current_value': curYp.isEmpty ? 'Omitido' : curYp,
        'matches': tokYp == curYp,
      },
      {
        'key': 'bcp',
        'label': 'Cuenta BCP',
        'token_value': _formatBankAccountDisplay(tokBcp),
        'current_value': _formatBankAccountDisplay(curBcp),
        'matches': _bankAccountsEqual(tokBcp, curBcp),
      },
      {
        'key': 'bbva',
        'label': 'Cuenta BBVA',
        'token_value': _formatBankAccountDisplay(tokBbva),
        'current_value': _formatBankAccountDisplay(curBbva),
        'matches': _bankAccountsEqual(tokBbva, curBbva),
      },
    ];

    for (final ch in channelsDiff) {
      if (ch['matches'] != true) diffCount++;
    }

    return {
      'local_revision': safeLocalRev,
      'token_revision': tokenRev,
      'revision_status': revisionStatus,
      'revision_status_label': revisionStatusLabel,
      'recommendation': recommendation,
      'diff_vs_current': {
        'matches_current': diffCount == 0,
        'total_differences': diffCount,
        'products_diff': productsDiff,
        'channels_diff': channelsDiff,
      },
    };
  }

  /// Valida estrictamente el esquema tipado `v == 1` rechazando claves desconocidas o rangos negativos.
  static String? validateDecodedPayloadSchema(
    dynamic decoded, {
    required int schemaVersion,
  }) {
    if (decoded is! Map) {
      return 'El payload MLC1 debe ser un objeto JSON.';
    }
    final map = decoded;
    for (final k in map.keys) {
      if (!allowedTopLevelKeys.contains(k)) {
        return 'Clave no autorizada en payload MLC1: "$k".';
      }
    }

    if (map['v'] is! int || map['v'] != schemaVersion) {
      return 'Versión de esquema no soportada: ${map['v']}.';
    }
    if (map['ver'] is! int || (map['ver'] as int) < 1) {
      return 'Revisión `ver` inválida en payload MLC1.';
    }
    if (map['iat'] is! int || (map['iat'] as int) <= 0) {
      return 'Timestamp `iat` inválido en payload MLC1.';
    }

    for (final strKey in ['sup', 'yh', 'yp']) {
      if (map[strKey] is! String) {
        return 'Campo textual inválido o faltante: "$strKey".';
      }
    }

    for (final bankKey in ['bcp', 'bbva']) {
      final bankVal = map[bankKey];
      if (bankVal is! Map) {
        return 'Estructura bancaria inválida en "$bankKey".';
      }
      for (final bk in bankVal.keys) {
        if (!allowedBankKeys.contains(bk)) {
          return 'Clave no autorizada en $bankKey: "$bk".';
        }
      }
      for (final reqBank in allowedBankKeys) {
        if (bankVal[reqBank] is! String) {
          return 'Campo bancario "$bankKey.$reqBank" debe ser String.';
        }
      }
    }

    final productsVal = map['p'];
    if (productsVal is! Map) {
      return 'Mapa de productos `p` inválido.';
    }
    for (final pid in CommercialConstants.allowedMlc1ProductIds) {
      if (!productsVal.containsKey(pid)) {
        return 'Falta producto requerido en `p`: "$pid".';
      }
    }
    for (final entry in productsVal.entries) {
      if (!CommercialConstants.allowedMlc1ProductIds.contains(entry.key)) {
        return 'Producto no autorizado en `p`: "${entry.key}".';
      }
      if (entry.value is! Map) {
        return 'Definición inválida de producto "${entry.key}".';
      }
      final prod = entry.value as Map;
      for (final pk in prod.keys) {
        if (!allowedProductKeys.contains(pk)) {
          return 'Clave no autorizada en p.${entry.key}: "$pk".';
        }
      }
      final pr = prod['pr'];
      if (pr is! num ||
          pr.toDouble().isNaN ||
          pr.toDouble().isInfinite ||
          pr < 0) {
        return 'Precio inválido en p.${entry.key}: $pr';
      }
      for (final intField in ['d', 'ai', 'um']) {
        final v = prod[intField];
        if (v is! int || v < 0) {
          return 'Campo entero inválido en p.${entry.key}.$intField: $v';
        }
      }
      if (prod['lb'] is! String || prod['ds'] is! String) {
        return 'Etiqueta/descripción inválida en p.${entry.key}.';
      }
    }
    return null;
  }

  /// Construye un resumen legible para UI desktop (`#modalCommercialConfigSync`) y API.
  static Map<String, dynamic> buildSummaryFromPayload(
    Map<String, dynamic> payload,
  ) {
    final bcp = payload['bcp'] as Map? ?? const {};
    final bbva = payload['bbva'] as Map? ?? const {};
    final products = payload['p'] as Map? ?? const {};
    final orderedPlans = <Map<String, dynamic>>[];

    for (final id in CommercialConstants.catalogSlugToSyncId.values) {
      final p = products[id];
      if (p is Map) {
        orderedPlans.add({
          'id': id,
          'label': p['lb'] ?? id,
          'price': (p['pr'] as num?)?.toDouble() ?? 0.0,
          'days': (p['d'] as num?)?.toInt() ?? 0,
          'ai_credits': (p['ai'] as num?)?.toInt() ?? 0,
          'updates_months': (p['um'] as num?)?.toInt() ?? 0,
          'description': p['ds'] ?? '',
        });
      }
    }

    return {
      'revision': payload['ver'],
      'support_phone': payload['sup'] ?? '',
      'yape_holder': payload['yh'] ?? '',
      'yape_phone': payload['yp'] ?? '',
      'bcp_configured': (bcp['acc']?.toString().trim().isNotEmpty ?? false),
      'bcp': Map<String, dynamic>.from(bcp),
      'bbva_configured': (bbva['acc']?.toString().trim().isNotEmpty ?? false),
      'bbva': Map<String, dynamic>.from(bbva),
      'plans': orderedPlans,
    };
  }
}
