import 'dart:convert';

import '../apk/apk_models.dart';
import '../core/path_security.dart';
import 'config_defaults.dart';

/// Normalizador de esquemas legados, propagación de identidad legal y sanitizador de `owner_config.json`.
class ConfigNormalizer {
  ConfigNormalizer._();

  /// Normaliza en memoria configuraciones históricas leídas desde disco sin sobrescribir datos del usuario.
  static void normalizeLoadedConfig(
    Map<String, dynamic> merged,
    Map<String, dynamic> rawParsed,
  ) {
    normalizeCatalogEntries(
      merged,
      rawCatalog:
          rawParsed['catalog'] is Map ? rawParsed['catalog'] as Map : null,
    );
    normalizeTemplatesMap(merged, rawParsed['templates'] as Map?);
    normalizeSystemPreferences(merged);
  }

  /// Propaga cambios de `legal_identity` hacia `receipt_config` cuando los campos
  /// de boleta aún reflejaban la identidad anterior o venían vacíos.
  static void propagateLegalIdentityToReceiptConfig(
    Map<String, dynamic> target, {
    required Map<String, dynamic> prevLegal,
  }) {
    final newLegal =
        (target['legal_identity'] as Map?)?.cast<String, dynamic>() ?? {};
    final rcRaw = target['receipt_config'];
    if (rcRaw is! Map) return;
    final rc = Map<String, dynamic>.from(rcRaw);

    final prevAuthor = (prevLegal['author_full_name'] as String? ?? '').trim();
    final newAuthor = (newLegal['author_full_name'] as String? ?? '').trim();
    final curIssuer = (rc['issuer_name'] as String? ?? '').trim();
    if (newAuthor.isNotEmpty &&
        (curIssuer.isEmpty || curIssuer == prevAuthor)) {
      rc['issuer_name'] = newAuthor;
    }

    final prevBrand = (prevLegal['commercial_name'] as String? ??
            prevLegal['brand_name'] as String? ??
            '')
        .trim();
    final newBrand = (newLegal['commercial_name'] as String? ??
            newLegal['brand_name'] as String? ??
            '')
        .trim();
    final curComm = (rc['commercial_name'] as String? ?? '').trim();
    if (newBrand.isNotEmpty && (curComm.isEmpty || curComm == prevBrand)) {
      rc['commercial_name'] = newBrand;
    }

    final curSig = (rc['signature_text'] as String? ?? '').trim();
    if (newBrand.isNotEmpty &&
        (curSig.isEmpty || curSig == 'Administración Comercial — $prevBrand')) {
      rc['signature_text'] = 'Administración Comercial — $newBrand';
    }

    final prevPhone = (prevLegal['support_phone'] as String? ?? '').trim();
    final newPhone = (newLegal['support_phone'] as String? ?? '').trim();
    final curPhone = (rc['issuer_phone'] as String? ?? '').trim();
    if (newPhone.isNotEmpty && (curPhone.isEmpty || curPhone == prevPhone)) {
      rc['issuer_phone'] = newPhone;
    }

    target['receipt_config'] = rc;
  }

  static void normalizeCatalogEntries(
    Map<String, dynamic> target, {
    Map? rawCatalog,
  }) {
    final defaultsCatalog =
        (ConfigDefaults.getDefaultConfig()['catalog'] as Map)
            .cast<String, dynamic>();
    final rawTargetCat = target['catalog'];
    final catalogMap = rawTargetCat is Map
        ? Map<String, dynamic>.from(rawTargetCat)
        : <String, dynamic>{};

    catalogMap.forEach((k, v) {
      if (v is Map) {
        final vMap = Map<String, dynamic>.from(v);
        final rawEntry = rawCatalog != null && rawCatalog[k] is Map
            ? rawCatalog[k] as Map
            : null;
        final defEntry = defaultsCatalog[k] is Map
            ? defaultsCatalog[k] as Map
            : null;

        if (vMap.containsKey('price')) {
          final p = (vMap['price'] as num?)?.toDouble() ?? 0.0;
          vMap['price'] = p < 0 ? 0.0 : p;
        }
        if (vMap.containsKey('days')) {
          final d = (vMap['days'] as num?)?.toInt() ?? 0;
          vMap['days'] = d < 0 ? 0 : d;
        }
        if (vMap.containsKey('ai_credits')) {
          final c = (vMap['ai_credits'] as num?)?.toInt() ?? 0;
          vMap['ai_credits'] = c < 0 ? 0 : c;
        }

        // Unificación bidireccional updates_window_months <-> updates_months
        int? resolvedUpdates;
        if (rawEntry != null && rawEntry.containsKey('updates_window_months')) {
          resolvedUpdates =
              (rawEntry['updates_window_months'] as num?)?.toInt() ?? 0;
        } else if (rawEntry != null && rawEntry.containsKey('updates_months')) {
          resolvedUpdates = (rawEntry['updates_months'] as num?)?.toInt() ?? 0;
        } else if (vMap.containsKey('updates_window_months')) {
          resolvedUpdates =
              (vMap['updates_window_months'] as num?)?.toInt() ?? 0;
        } else if (vMap.containsKey('updates_months')) {
          resolvedUpdates = (vMap['updates_months'] as num?)?.toInt() ?? 0;
        } else if (defEntry != null) {
          resolvedUpdates =
              (defEntry['updates_window_months'] as num?)?.toInt() ??
                  (defEntry['updates_months'] as num?)?.toInt() ??
                  0;
        }
        final defUpdates = defEntry != null
            ? ((defEntry['updates_window_months'] as num?)?.toInt() ??
                (defEntry['updates_months'] as num?)?.toInt() ??
                0)
            : 0;
        var safeUpdates =
            (resolvedUpdates ?? 0) < 0 ? 0 : (resolvedUpdates ?? 0);
        // Saneamiento de raíz: en productos con ventana oficial > 0 se sanea <= 0 a 12 meses.
        if (defUpdates > 0 && safeUpdates <= 0) {
          safeUpdates = defUpdates;
        }
        vMap['updates_window_months'] = safeUpdates;
        vMap['updates_months'] = safeUpdates;

        final curDesc = (vMap['description'] as String? ?? '').trim();
        if (curDesc.isNotEmpty) {
          vMap['description'] = curDesc;
        } else if (defEntry != null && defEntry['description'] is String) {
          vMap['description'] = defEntry['description'];
        } else {
          vMap['description'] = '';
        }

        catalogMap[k] = vMap;
      }
    });
    target['catalog'] = catalogMap;
  }

  static void normalizeTemplatesMap(
    Map<String, dynamic> target,
    Map? rawTemplates,
  ) {
    final rawTargetTpl = target['templates'];
    final tplMap = rawTargetTpl is Map
        ? Map<String, dynamic>.from(rawTargetTpl)
        : <String, dynamic>{};

    const aliasToCanon = {
      'welcome': 'trial_welcome',
      'expiring': 'expiring_reminder',
      'license': 'license_issued',
      'update': 'apk_update_eligible',
    };

    aliasToCanon.forEach((alias, canon) {
      final hasRawAlias =
          rawTemplates != null && rawTemplates.containsKey(alias);
      final hasRawCanon =
          rawTemplates != null && rawTemplates.containsKey(canon);
      final rawAliasVal = hasRawAlias ? rawTemplates[alias]?.toString() : null;
      final rawCanonVal = hasRawCanon ? rawTemplates[canon]?.toString() : null;

      if (hasRawAlias && (rawAliasVal?.trim().isNotEmpty ?? false)) {
        tplMap[alias] = rawAliasVal;
        if (!hasRawCanon || (rawCanonVal?.trim().isEmpty ?? true)) {
          tplMap[canon] = rawAliasVal;
        }
      } else if (hasRawCanon &&
          (rawCanonVal?.trim().isNotEmpty ?? false) &&
          tplMap.containsKey(alias)) {
        tplMap[alias] = rawCanonVal;
      } else if (tplMap.containsKey(alias)) {
        final curCanon = tplMap[canon]?.toString() ?? '';
        final curAlias = tplMap[alias]?.toString() ?? '';
        if (curAlias.isNotEmpty && curCanon.isEmpty) {
          tplMap[canon] = curAlias;
        } else if (curCanon.isNotEmpty && curAlias != curCanon) {
          tplMap[alias] = curCanon;
        }
      }
    });

    target['templates'] = tplMap;
  }

  static void normalizeSystemPreferences(Map<String, dynamic> target) {
    final sys = target['system'] is Map
        ? Map<String, dynamic>.from(target['system'] as Map)
        : <String, dynamic>{};

    final rawMode =
        (sys['default_mode'] as String? ?? 'sandbox').trim().toLowerCase();
    sys['default_mode'] = rawMode == 'prod' ? 'prod' : 'sandbox';

    final rawTheme = (sys['theme'] as String? ?? 'dark').trim().toLowerCase();
    sys['theme'] = rawTheme == 'light' ? 'light' : 'dark';

    final rawDensity =
        (sys['table_density'] as String? ?? 'comfortable').trim().toLowerCase();
    sys['table_density'] = rawDensity == 'compact' ? 'compact' : 'comfortable';

    final rawRev = (sys['commercial_sync_revision'] as num?)?.toInt() ?? 0;
    sys['commercial_sync_revision'] = rawRev < 0 ? 0 : rawRev;

    target['system'] = sys;
  }

  /// Sanitiza y valida la configuración entrante preservando `apk_library_dir` y `apk_search_dirs`.
  static Map<String, dynamic> sanitizeConfig(
    Map<String, dynamic> raw, {
    required Map<String, dynamic> currentConfig,
    required Map<String, dynamic> currentLegalIdentity,
    required Map<String, dynamic> currentSystem,
    required bool Function(String) isForbiddenSearchDir,
  }) {
    final prevLegal = Map<String, dynamic>.from(currentLegalIdentity);
    final prevSystem = Map<String, dynamic>.from(currentSystem);
    final prevRev =
        (prevSystem['commercial_sync_revision'] as num?)?.toInt() ?? 0;
    final merged =
        ConfigDefaults.deepMerge(ConfigDefaults.getDefaultConfig(), raw);

    final rawSystem = raw['system'];
    final hasRawSystemLib = rawSystem is Map &&
        rawSystem.containsKey('apk_library_dir') &&
        (rawSystem['apk_library_dir']?.toString().trim().isNotEmpty ?? false);
    final hasRawSearchDirs = rawSystem is Map &&
        rawSystem.containsKey('apk_search_dirs') &&
        rawSystem['apk_search_dirs'] is List &&
        (rawSystem['apk_search_dirs'] as List).isNotEmpty;

    final sysMap = merged['system'] is Map
        ? Map<String, dynamic>.from(merged['system'] as Map)
        : <String, dynamic>{};

    // Guardián anti-downgrade de commercial_sync_revision
    final incomingRev =
        (sysMap['commercial_sync_revision'] as num?)?.toInt() ?? 0;
    final safePrevRev = prevRev < 0 ? 0 : prevRev;
    final safeIncomingRev = incomingRev < 0 ? 0 : incomingRev;
    sysMap['commercial_sync_revision'] =
        safePrevRev > safeIncomingRev ? safePrevRev : safeIncomingRev;

    if (!hasRawSystemLib &&
        raw['apk_library_dir'] is String &&
        (raw['apk_library_dir'] as String).trim().isNotEmpty) {
      sysMap['apk_library_dir'] = (raw['apk_library_dir'] as String).trim();
      merged.remove('apk_library_dir');
    } else if (!hasRawSystemLib &&
        prevSystem['apk_library_dir'] is String &&
        (prevSystem['apk_library_dir'] as String).trim().isNotEmpty) {
      sysMap['apk_library_dir'] =
          (prevSystem['apk_library_dir'] as String).trim();
    }

    if (!hasRawSearchDirs &&
        prevSystem['apk_search_dirs'] is List &&
        (prevSystem['apk_search_dirs'] as List).isNotEmpty) {
      sysMap['apk_search_dirs'] =
          jsonDecode(jsonEncode(prevSystem['apk_search_dirs']));
    }

    if (!hasRawSearchDirs && sysMap['apk_search_dirs'] is List) {
      final newLib = (sysMap['apk_library_dir'] as String? ?? '').trim();
      final updatedList = <Map<String, dynamic>>[];
      for (final item in (sysMap['apk_search_dirs'] as List)) {
        if (item is Map) {
          final m = Map<String, dynamic>.from(item);
          if (m['kind'] == 'official_library' && newLib.isNotEmpty) {
            m['path'] = newLib;
          }
          updatedList.add(m);
        }
      }
      sysMap['apk_search_dirs'] = updatedList;
    }

    if (sysMap['apk_search_dirs'] is List) {
      final rawList = sysMap['apk_search_dirs'] as List;
      final cleanDirs = <Map<String, dynamic>>[];
      final seen = <String>{};
      for (final item in rawList) {
        ApkSearchDirConfig? cfg;
        if (item is Map) {
          cfg = ApkSearchDirConfig.fromJson(Map<String, dynamic>.from(item));
        } else if (item is String && item.trim().isNotEmpty) {
          cfg = ApkSearchDirConfig(
            path: item.trim(),
            label: 'Carpeta Personalizada',
          );
        }
        if (cfg == null ||
            cfg.path.isEmpty ||
            isForbiddenSearchDir(cfg.path)) {
          continue;
        }
        final canon = PathSecurity.canonicalizePath(cfg.path);
        final key = PathSecurity.cacheKeyForPath(canon);
        if (seen.add(key)) {
          cleanDirs.add(cfg.toJson());
          if (cfg.kind == 'official_library' && !hasRawSystemLib) {
            sysMap['apk_library_dir'] = cfg.path;
          }
        }
      }
      sysMap['apk_search_dirs'] = cleanDirs;
    }

    merged['system'] = sysMap;
    normalizeSystemPreferences(merged);

    normalizeCatalogEntries(
      merged,
      rawCatalog: raw['catalog'] is Map ? raw['catalog'] as Map : null,
    );

    final rawCat = merged['catalog'] as Map<String, dynamic>;
    if (rawCat['HARDWARE_MIGRATION_FEE'] is Map) {
      merged['migration_fee'] =
          (rawCat['HARDWARE_MIGRATION_FEE']['price'] as num?)?.toDouble() ??
              40.0;
    }

    normalizeTemplatesMap(
      merged,
      raw['templates'] is Map ? raw['templates'] as Map : null,
    );

    if (currentConfig.isNotEmpty) {
      propagateLegalIdentityToReceiptConfig(merged, prevLegal: prevLegal);
    }

    if (merged.containsKey('receipt_config') &&
        merged['receipt_config'] is Map) {
      final rc = Map<String, dynamic>.from(merged['receipt_config'] as Map);
      for (final key in const [
        'next_correlative',
        'sandbox_next_correlative',
        'next_invoice_correlative',
        'sandbox_next_invoice_correlative',
      ]) {
        if (rc.containsKey(key)) {
          final v = (rc[key] as num?)?.toInt() ?? 1;
          rc[key] = v < 1 ? 1 : v;
        }
      }
      merged['receipt_config'] = rc;
    }

    return merged;
  }
}
