import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:googleai_dart/googleai_dart.dart';
import 'package:sqflite/sqflite.dart';

import 'package:app_movil/core/config/api_constants.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/features/analytics/models/commercial_radar_model.dart';
import 'package:app_movil/features/analytics/data/peru_ubigeo_catalog.dart';
import 'package:app_movil/features/analytics/services/link_health_verifier.dart';

class _CurateResult {
  final List<CommercialNewsItem> items;
  final RadarFeedSourceMode mode;

  const _CurateResult({required this.items, required this.mode});
}

class CommercialRadarService {
  static const String _cacheKeyPrefix = 'commercial_radar_cache_v5_';
  static const String _cacheTimestampPrefix = 'commercial_radar_time_v5_';
  static const String _cacheDatePrefix = 'commercial_radar_date_v5_';
  static const Duration _cacheDuration = Duration(hours: 4);

  /// Claves heredadas (globales) y bandera de migración única (Plan Maestro 21 - Pilar 3)
  static const String legacyLocationJsonPrefKey = 'commercial_radar_selected_location_json';
  static const String legacyRegionPrefKey = 'commercial_radar_selected_region';
  static const String legacySavedNewsPrefKey = 'commercial_radar_bookmarked_items_json';
  static const String legacyMigratedPrefKey = 'commercial_radar_legacy_migrated_v21';

  /// Cliente HTTP inyectable para pruebas unitarias sin tráfico real de red
  static http.Client? customHttpClient;

  /// Mock inyectable para emular el enriquecimiento Gemini en pruebas automatizadas
  static Future<List<CommercialNewsItem>> Function(List<Map<String, dynamic>>, String)? geminiCuratorMock;

  /// Modo del origen del último feed emitido
  static RadarFeedSourceMode lastSourceMode = RadarFeedSourceMode.liveRssWithAi;

  /// Cantidad de nuevas señales incorporadas en el último refresco intradía
  static int lastNewSignalsCount = 0;

  /// Caché estática en memoria para 0ms de latencia y 0 saltos de renderizado
  static final Map<String, List<CommercialNewsItem>> _memoryCache = {};

  /// Lock de coalescencia para evitar migraciones concurrentes dentro del mismo frame
  static Future<void>? _activeLegacyMigration;

  /// Instancia de LinkHealthVerifier vinculada al cliente HTTP configurado
  static LinkHealthVerifier get _linkVerifier => LinkHealthVerifier(client: customHttpClient);

  /// Fecha del día para control de caducidad matutina (yyyy-MM-dd)
  static String getTodayDateStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Clave de SharedPreferences para ubicación JSON estructurada aislada por perfil
  static String locationJsonPrefKey(int? profileId) =>
      profileId != null ? 'commercial_radar_profile_${profileId}_location_json' : legacyLocationJsonPrefKey;

  /// Clave de SharedPreferences para etiqueta de región aislada por perfil
  static String regionPrefKey(int? profileId) =>
      profileId != null ? 'commercial_radar_profile_${profileId}_region' : legacyRegionPrefKey;

  /// Clave de SharedPreferences para noticias guardadas aisladas por perfil
  static String savedNewsPrefKey(int? profileId) =>
      profileId != null ? 'commercial_radar_saved_profile_$profileId' : legacySavedNewsPrefKey;

  /// Clave de caché territorial diferenciada por departamento, provincia y distrito
  static String buildCacheKey(RadarLocation loc) {
    if (loc.isNational) return 'Todo el Perú';
    final dist = (loc.district ?? '').trim();
    return '${loc.department.trim()}_${loc.province.trim()}_$dist';
  }

  /// Obtiene la lista completa de noticias en memoria para una ubicación estructurada
  static List<CommercialNewsItem>? getCachedNewsForLocation(RadarLocation loc) {
    return _memoryCache[buildCacheKey(loc)];
  }

  /// Obtiene la lista completa de noticias en memoria si ya existen
  static List<CommercialNewsItem>? getCachedNews(String region) {
    final direct = _memoryCache[region];
    if (direct != null) return direct;
    return _memoryCache[buildCacheKey(RadarLocation.fromLegacyString(region))];
  }

  /// Limpia la memoria si se requiere
  static void clearMemoryCache() {
    _memoryCache.clear();
  }

  /// Algoritmo de Balanceo e Intercalado Temático (Interleaving)
  /// Alterna equitativamente las 5 categorías comerciales para evitar feeds monotemáticos
  static List<CommercialNewsItem> interleaveCategories(List<CommercialNewsItem> items) {
    if (items.length <= 2) return items;

    final Map<String, List<CommercialNewsItem>> buckets = {
      'clima': [],
      'proveedores': [],
      'sunat': [],
      'region': [],
      'campanas': [],
      'otros': [],
    };

    for (var item in items) {
      final cat = item.category.toLowerCase();
      if (cat.contains('clima') || cat.contains('ruta')) {
        buckets['clima']!.add(item);
      } else if (cat.contains('proveedor') || cat.contains('abastecimiento')) {
        buckets['proveedores']!.add(item);
      } else if (cat.contains('ley') || cat.contains('sunat')) {
        buckets['sunat']!.add(item);
      } else if (cat.contains('campaña') || cat.contains('campana') || cat.contains('fecha')) {
        buckets['campanas']!.add(item);
      } else if (cat.contains('región') || cat.contains('region')) {
        buckets['region']!.add(item);
      } else {
        buckets['otros']!.add(item);
      }
    }

    final List<CommercialNewsItem> result = [];
    final keys = ['clima', 'proveedores', 'sunat', 'region', 'campanas', 'otros'];

    bool hasRemaining = true;
    while (hasRemaining) {
      hasRemaining = false;
      for (final key in keys) {
        final bucket = buckets[key]!;
        if (bucket.isNotEmpty) {
          result.add(bucket.removeAt(0));
          if (bucket.isNotEmpty) {
            hasRemaining = true;
          }
        }
      }
    }

    return result;
  }

  /// Fusión intradía inteligente: agrega nuevas noticias sin borrar las anteriores del día
  static List<CommercialNewsItem> mergeNewsItems(
    List<CommercialNewsItem> existing,
    List<CommercialNewsItem> incoming,
  ) {
    final Map<String, CommercialNewsItem> mergedMap = {};
    for (var item in existing) {
      mergedMap[item.id] = item;
    }

    int newlyAdded = 0;
    for (var item in incoming) {
      if (!mergedMap.containsKey(item.id)) {
        newlyAdded++;
      }
      mergedMap[item.id] = item;
    }

    lastNewSignalsCount = newlyAdded;

    final list = mergedMap.values.toList();
    list.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
    return interleaveCategories(list);
  }

  // ==========================================
  // PERSISTENCIA DE NOTICIAS GUARDADAS (SQLITE + PREFS)
  // ==========================================

  static const String _savedTableName = 'radar_noticias_guardadas';

  static Future<void> _ensureSavedTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_savedTableName (
        id TEXT PRIMARY KEY,
        json_data TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  /// Saneamiento y actualización de noticias cacheadas o guardadas para garantizar
  /// URLs 100% verídicas, activas y sin dominios caídos como emergenciasviales.proviasnac.gob.pe
  static CommercialNewsItem sanitizeAndUpgradeNewsItem(
    CommercialNewsItem item, {
    String region = 'Talara / Piura',
  }) {
    // 1. Si coincide con un ID del catálogo de respaldo oficial actualizado
    final fallbackList = _getOfflineFallback(RadarLocation.fromLegacyString(region));
    for (final fb in fallbackList) {
      if (fb.id == item.id) {
        return item.copyWith(
          sourceName: fb.sourceName,
          sourceUrl: fb.sourceUrl,
          isLive: false,
          isOfflineGuide: true,
        );
      }
    }

    // 2. Erradicación de URLs rotas o desactualizadas conocidas a rutas canónicas gob.pe
    String updatedUrl = item.sourceUrl.trim();
    String updatedSource = item.sourceName.trim();

    if (updatedUrl.contains('emergenciasviales.proviasnac.gob.pe') ||
        updatedUrl.contains('976451.aspx') ||
        updatedUrl.contains('alerta_sutran')) {
      updatedUrl = 'https://www.gob.pe/sutran';
      updatedSource = 'Provías Nacional / SUTRAN';
    } else if (updatedUrl.contains('sunat') || updatedUrl.contains('guias-de-remision-electronica')) {
      updatedUrl = 'https://www.gob.pe/sunat';
      updatedSource = 'SUNAT Portal Oficial';
    } else if (updatedUrl.contains('senamhi')) {
      updatedUrl = 'https://www.gob.pe/senamhi';
      updatedSource = 'SENAMHI Alertas';
    } else if (updatedUrl.contains('midagri') || updatedUrl.contains('sisap')) {
      updatedUrl = 'https://www.gob.pe/midagri';
      updatedSource = 'MIDAGRI Oficial';
    } else if (updatedUrl.contains('produce') || updatedUrl.contains('tuempresa')) {
      updatedUrl = 'https://www.gob.pe/tuempresa';
      updatedSource = 'PRODUCE / Tu Empresa MYPE';
    } else if (updatedUrl.contains('indecopi')) {
      updatedUrl = 'https://www.gob.pe/indecopi';
      updatedSource = 'INDECOPI Oficial';
    } else if (updatedUrl.contains('provias')) {
      updatedUrl = 'https://www.gob.pe/proviasnacional';
      updatedSource = 'Provías Nacional';
    } else if (updatedSource.contains('Cámara de Comercio') && updatedUrl.contains('gestion.pe')) {
      updatedUrl = CommercialNewsItem.buildVerifiedSearchUrl(item.cleanTitle, mediaDomain: 'lacamara.pe');
      updatedSource = 'Cámara de Comercio de Lima';
    }

    return item.copyWith(
      sourceUrl: updatedUrl,
      sourceName: updatedSource,
    );
  }

  /// Migra de forma atómica y por única vez preferencias globales heredadas (ubicación y noticias
  /// guardadas) hacia el primer perfil activo cuando `commercial_radar_legacy_migrated_v21` no
  /// ha sido marcado todavía. Los perfiles subsecuentes comienzan limpios con su configuración base.
  static Future<void> migrateLegacyToProfileIfNeeded({required int profileId}) async {
    final inFlight = _activeLegacyMigration;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final future = _runLegacyMigrationIfNeeded(profileId: profileId);
    _activeLegacyMigration = future;
    try {
      await future;
    } finally {
      if (identical(_activeLegacyMigration, future)) {
        _activeLegacyMigration = null;
      }
    }
  }

  static Future<void> _runLegacyMigrationIfNeeded({required int profileId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(legacyMigratedPrefKey) == true) return;

      final targetLocKey = locationJsonPrefKey(profileId);
      final targetRegKey = regionPrefKey(profileId);
      final targetSavedKey = savedNewsPrefKey(profileId);

      if (!prefs.containsKey(targetLocKey) && !prefs.containsKey(targetRegKey)) {
        final legacyJson = prefs.getString(legacyLocationJsonPrefKey);
        final legacyReg = prefs.getString(legacyRegionPrefKey);

        if (legacyJson != null && legacyJson.trim().isNotEmpty) {
          await prefs.setString(targetLocKey, legacyJson);
          try {
            final parsed = RadarLocation.fromJson(jsonDecode(legacyJson) as Map<String, dynamic>);
            await prefs.setString(
              targetRegKey,
              (legacyReg != null && legacyReg.trim().isNotEmpty) ? legacyReg : parsed.displayName,
            );
          } catch (_) {
            if (legacyReg != null && legacyReg.trim().isNotEmpty) {
              await prefs.setString(targetRegKey, legacyReg);
            }
          }
        } else if (legacyReg != null && legacyReg.trim().isNotEmpty) {
          await prefs.setString(targetRegKey, legacyReg);
          final parsed = RadarLocation.fromLegacyString(legacyReg);
          await prefs.setString(targetLocKey, jsonEncode(parsed.toJson()));
        }
      }

      if (!prefs.containsKey(targetSavedKey)) {
        final legacySaved = await _readLegacySavedNews(prefs: prefs);
        if (legacySaved.isNotEmpty) {
          await prefs.setString(
            targetSavedKey,
            jsonEncode(legacySaved.map((e) => e.toJson()).toList()),
          );
        }
      }

      await prefs.setBool(legacyMigratedPrefKey, true);
    } catch (_) {}
  }

  /// Carga la ubicación estructurada del Radar para el perfil indicado (o modo global si es null)
  static Future<RadarLocation> loadLocationForProfile({
    int? profileId,
    required RadarLocation fallback,
  }) async {
    try {
      if (profileId != null) {
        await migrateLegacyToProfileIfNeeded(profileId: profileId);
      }
      final prefs = await SharedPreferences.getInstance();
      final savedLocJson = prefs.getString(locationJsonPrefKey(profileId));
      if (savedLocJson != null && savedLocJson.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(savedLocJson) as Map<String, dynamic>;
          return RadarLocation.fromJson(decoded);
        } catch (_) {}
      }
      final savedReg = prefs.getString(regionPrefKey(profileId));
      if (savedReg != null && savedReg.trim().isNotEmpty) {
        return RadarLocation.fromLegacyString(savedReg);
      }
    } catch (_) {}
    return fallback;
  }

  /// Persiste la ubicación estructurada del Radar para el perfil indicado
  static Future<void> saveLocationForProfile(
    RadarLocation location, {
    int? profileId,
  }) async {
    try {
      if (profileId != null) {
        await migrateLegacyToProfileIfNeeded(profileId: profileId);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(locationJsonPrefKey(profileId), jsonEncode(location.toJson()));
      await prefs.setString(regionPrefKey(profileId), location.displayName);
    } catch (_) {}
  }

  /// Carga la etiqueta de región para la tarjeta del Radar aislada por perfil
  static Future<String> loadRegionLabelForProfile({
    int? profileId,
    required String defaultRegion,
  }) async {
    try {
      if (profileId != null) {
        await migrateLegacyToProfileIfNeeded(profileId: profileId);
      }
      final prefs = await SharedPreferences.getInstance();
      final savedReg = prefs.getString(regionPrefKey(profileId));
      if (savedReg != null && savedReg.trim().isNotEmpty) {
        return savedReg;
      }
      final savedLocJson = prefs.getString(locationJsonPrefKey(profileId));
      if (savedLocJson != null && savedLocJson.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(savedLocJson) as Map<String, dynamic>;
          return RadarLocation.fromJson(decoded).displayName;
        } catch (_) {}
      }
    } catch (_) {}
    return defaultRegion;
  }

  /// Persiste la etiqueta de región desde la tarjeta del Radar sincronizando su JSON de perfil
  static Future<void> saveRegionLabelForProfile(
    String regionLabel, {
    int? profileId,
  }) async {
    try {
      if (profileId != null) {
        await migrateLegacyToProfileIfNeeded(profileId: profileId);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(regionPrefKey(profileId), regionLabel);
      final parsed = RadarLocation.fromLegacyString(regionLabel);
      await prefs.setString(locationJsonPrefKey(profileId), jsonEncode(parsed.toJson()));
    } catch (_) {}
  }

  static Future<List<CommercialNewsItem>> _readLegacySavedNews({
    SharedPreferences? prefs,
  }) async {
    List<CommercialNewsItem> items = [];
    try {
      final db = await LocalDatabase.instance.database;
      await _ensureSavedTable(db);
      final rows = await db.query(_savedTableName, orderBy: 'created_at DESC');
      if (rows.isNotEmpty) {
        items = rows.map((r) {
          if (r.containsKey('json_data') && r['json_data'] != null) {
            final jsonMap = jsonDecode(r['json_data'] as String) as Map<String, dynamic>;
            return CommercialNewsItem.fromJson(jsonMap);
          } else {
            return CommercialNewsItem(
              id: (r['id'] ?? '') as String,
              title: (r['title'] ?? '') as String,
              summary: (r['summary'] ?? '') as String,
              actionableAdvice: (r['actionable_advice'] ?? '') as String,
              category: (r['category'] ?? 'Mi Región') as String,
              sourceName: (r['source_name'] ?? '') as String,
              sourceUrl: (r['source_url'] ?? '') as String,
              publishedAt: DateTime.tryParse((r['published_at'] ?? '').toString()) ?? DateTime.now(),
              region: (r['region'] ?? 'Perú') as String,
              impactAnalysis: (r['estimated_impact'] ?? '') as String,
            );
          }
        }).toList();
      }
    } catch (_) {}

    if (items.isEmpty) {
      try {
        final sp = prefs ?? await SharedPreferences.getInstance();
        final str = sp.getString(legacySavedNewsPrefKey);
        if (str != null && str.isNotEmpty) {
          final List<dynamic> list = jsonDecode(str);
          items = list.map((e) => CommercialNewsItem.fromJson(e as Map<String, dynamic>)).toList();
        }
      } catch (_) {}
    }

    return items;
  }

  /// Obtiene todas las noticias guardadas permanentemente por el perfil activo
  static Future<List<CommercialNewsItem>> getSavedNews({int? profileId}) async {
    List<CommercialNewsItem> items = [];

    if (profileId != null) {
      await migrateLegacyToProfileIfNeeded(profileId: profileId);
      try {
        final prefs = await SharedPreferences.getInstance();
        final str = prefs.getString(savedNewsPrefKey(profileId));
        if (str != null && str.isNotEmpty) {
          final List<dynamic> list = jsonDecode(str);
          items = list.map((e) => CommercialNewsItem.fromJson(e as Map<String, dynamic>)).toList();
        }
      } catch (_) {}
    } else {
      items = await _readLegacySavedNews();
    }

    if (items.isEmpty) return [];

    bool hasChanges = false;
    final List<CommercialNewsItem> upgraded = [];
    for (final it in items) {
      final up = sanitizeAndUpgradeNewsItem(it);
      if (up.sourceUrl != it.sourceUrl || up.sourceName != it.sourceName) {
        hasChanges = true;
      }
      upgraded.add(up);
    }

    if (hasChanges) {
      unawaited(_persistUpgradedSavedNews(upgraded, profileId: profileId));
    }

    return upgraded;
  }

  static Future<void> _persistUpgradedSavedNews(
    List<CommercialNewsItem> items, {
    int? profileId,
  }) async {
    if (profileId == null) {
      try {
        final db = await LocalDatabase.instance.database;
        await _ensureSavedTable(db);
        final batch = db.batch();
        for (final item in items) {
          batch.insert(
            _savedTableName,
            {
              'id': item.id,
              'json_data': jsonEncode(item.toJson()),
              'created_at': DateTime.now().toIso8601String(),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      } catch (_) {}
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        savedNewsPrefKey(profileId),
        jsonEncode(items.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }

  /// Guarda permanentemente una noticia aislada por perfil (y SQLite solo en modo sin perfil)
  static Future<void> saveNewsItem(
    CommercialNewsItem item, {
    int? profileId,
  }) async {
    final sanitizedItem = sanitizeAndUpgradeNewsItem(item);
    if (profileId != null) {
      await migrateLegacyToProfileIfNeeded(profileId: profileId);
    } else {
      try {
        final db = await LocalDatabase.instance.database;
        await _ensureSavedTable(db);
        final jsonStr = jsonEncode(sanitizedItem.toJson());
        await db.insert(
          _savedTableName,
          {
            'id': sanitizedItem.id,
            'json_data': jsonStr,
            'created_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } catch (_) {}
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await getSavedNews(profileId: profileId);
      if (!current.any((i) => i.id == sanitizedItem.id)) {
        current.insert(0, sanitizedItem);
      }
      await prefs.setString(
        savedNewsPrefKey(profileId),
        jsonEncode(current.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }

  /// Elimina una noticia guardada para el perfil indicado
  static Future<void> removeSavedNews(
    String id, {
    int? profileId,
  }) async {
    if (profileId != null) {
      await migrateLegacyToProfileIfNeeded(profileId: profileId);
    } else {
      try {
        final db = await LocalDatabase.instance.database;
        await _ensureSavedTable(db);
        await db.delete(_savedTableName, where: 'id = ?', whereArgs: [id]);
      } catch (_) {}
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await getSavedNews(profileId: profileId);
      current.removeWhere((i) => i.id == id);
      await prefs.setString(
        savedNewsPrefKey(profileId),
        jsonEncode(current.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }

  /// Verifica si una noticia está guardada para el perfil indicado
  static Future<bool> isNewsSaved(
    String id, {
    int? profileId,
  }) async {
    if (profileId != null) {
      final current = await getSavedNews(profileId: profileId);
      return current.any((i) => i.id == id);
    }
    try {
      final db = await LocalDatabase.instance.database;
      await _ensureSavedTable(db);
      final rows = await db.query(_savedTableName, where: 'id = ?', whereArgs: [id], limit: 1);
      return rows.isNotEmpty;
    } catch (_) {
      final current = await getSavedNews();
      return current.any((i) => i.id == id);
    }
  }

  // ==========================================
  // OBTENCIÓN Y STREAMING CON FUSIÓN INTRADÍA Y CASCADA REAL
  // ==========================================

  /// Obtiene las noticias curadas progresivamente una a una con Fusión Intradía y Caducidad Matutina
  static Stream<CommercialNewsItem> streamCuratedNews({
    String region = 'Talara / Piura',
    RadarLocation? location,
    bool forceRefresh = false,
  }) async* {
    final loc = location ?? RadarLocation.fromLegacyString(region);
    final cacheKey = buildCacheKey(loc);
    final todayStr = getTodayDateStr();

    // 1. Memoria rápida si no es recarga forzada
    if (!forceRefresh && _memoryCache.containsKey(cacheKey) && _memoryCache[cacheKey]!.isNotEmpty) {
      final balanced = interleaveCategories(_memoryCache[cacheKey]!);
      for (var item in balanced) {
        yield item;
      }
      return;
    }

    // 2. Caché persistente del mismo día
    if (!forceRefresh) {
      final cached = await _loadFromCache(cacheKey, todayStr, location: loc);
      if (cached != null && cached.isNotEmpty) {
        lastSourceMode = RadarFeedSourceMode.cachedRecent;
        final balanced = interleaveCategories(cached);
        _memoryCache[cacheKey] = balanced;
        for (var item in balanced) {
          yield item;
        }
        return;
      }
    }

    // 3. Preparar lista base existente para fusión intradía
    List<CommercialNewsItem> existingOfDay = [];
    if (forceRefresh) {
      final currentInMem = _memoryCache[cacheKey];
      if (currentInMem != null && currentInMem.isNotEmpty) {
        existingOfDay = List.from(currentInMem);
      } else {
        final fromDisk = await _loadFromCache(cacheKey, todayStr, location: loc);
        if (fromDisk != null) existingOfDay = fromDisk;
      }
    }

    // 4. Intentar obtener noticias en vivo vía RSS Google News Perú + Curaduría Gemini o Análisis Local
    List<CommercialNewsItem> newlyFetched = [];
    RadarFeedSourceMode determinedMode = RadarFeedSourceMode.liveRssWithAi;

    try {
      final rawRssItems = await _fetchGoogleNewsRssCascade(loc);
      if (rawRssItems.isNotEmpty) {
        final verifiedRssItems = await _verifyRssLinks(rawRssItems);
        final curateResult = await _curateRssItems(verifiedRssItems, loc);
        newlyFetched = curateResult.items;
        determinedMode = curateResult.mode;
      }
    } catch (_) {
      // Fallback ante fallo de red
    }

    // 5. Contingencia si no se obtuvieron noticias de red
    if (newlyFetched.isEmpty) {
      final fromDisk = await _loadFromCache(cacheKey, todayStr, location: loc);
      if (fromDisk != null && fromDisk.isNotEmpty) {
        newlyFetched = fromDisk;
        determinedMode = RadarFeedSourceMode.cachedRecent;
      } else {
        final allFallback = _getOfflineFallback(loc);
        newlyFetched = allFallback;
        determinedMode = RadarFeedSourceMode.offlineGuide;
      }
    }

    lastSourceMode = determinedMode;

    // 6. Aplicar Fusión Intradía
    List<CommercialNewsItem> finalFeed;
    if (existingOfDay.isNotEmpty && determinedMode != RadarFeedSourceMode.offlineGuide) {
      finalFeed = mergeNewsItems(existingOfDay, newlyFetched);
    } else {
      lastNewSignalsCount = newlyFetched.length;
      finalFeed = interleaveCategories(newlyFetched);
    }

    _memoryCache[cacheKey] = finalFeed;
    await _saveToCache(cacheKey, finalFeed, todayStr);

    for (var item in finalFeed) {
      yield item;
    }
  }

  // ==========================================
  // INGESTA RSS EN CASCADA (LOCAL -> REGIONAL -> NACIONAL)
  // ==========================================

  /// Consulta RSS de Google News Perú con cascada territorial y filtro anti-ruido
  static Future<List<Map<String, dynamic>>> _fetchGoogleNewsRssCascade(RadarLocation loc) async {
    final client = customHttpClient ?? http.Client();
    final bool isOwnedClient = customHttpClient == null;
    final List<Map<String, dynamic>> collectedItems = [];

    const antiNoise = ' NOT (fútbol OR soccer OR partido OR liga OR torneo OR gol OR club OR farándula OR espectáculo OR cantante OR concierto)';

    try {
      if (loc.isNational) {
        // Nivel Nacional directo
        final qNacional = '(Perú AND (comercio OR "mercado mayorista" OR fletes OR transporte OR abastecimiento OR SUNAT OR INDECOPI OR carreteras OR SENAMHI))$antiNoise';
        final itemsNacional = await _fetchRssQuery(
          client,
          qNacional,
          scope: RadarNewsScope.nacional,
          scopeLabel: 'Nacional • Perú',
          regionName: 'Perú',
          limit: 12,
        );
        collectedItems.addAll(itemsNacional);
      } else {
        // Cascada Nivel 1: Local (Distrito / Localidad prioritaria + Complemento Provincial)
        List<Map<String, dynamic>> itemsLocal = [];

        if (loc.district != null && loc.district!.isNotEmpty) {
          final qDistrict = '("${loc.district}" "${loc.province}" AND (comercio OR transporte OR carreteras OR fletes OR abastecimiento OR lluvias OR SENAMHI))$antiNoise';
          final districtItems = await _fetchRssQuery(
            client,
            qDistrict,
            scope: RadarNewsScope.local,
            scopeLabel: 'Local • ${loc.district}',
            regionName: loc.district!,
            limit: 4,
          );
          itemsLocal.addAll(districtItems);
        }

        // Si el distrito es pequeño o devuelve pocas noticias locales (< 2), complementar con la provincia
        if (itemsLocal.length < 2) {
          final qProv = '("${loc.province}" AND (comercio OR transporte OR carreteras OR fletes OR abastecimiento OR lluvias OR SENAMHI))$antiNoise';
          final provItems = await _fetchRssQuery(
            client,
            qProv,
            scope: RadarNewsScope.local,
            scopeLabel: loc.district != null && loc.district!.isNotEmpty
                ? 'Local • ${loc.district}'
                : 'Local • ${loc.province}',
            regionName: loc.province,
            limit: 4 - itemsLocal.length,
          );
          itemsLocal.addAll(provItems);
        }
        collectedItems.addAll(itemsLocal);

        // Cascada Nivel 2: Regional (Departamento + Corredor Logístico Estratégico)
        final qRegional = '("${loc.department}" AND (rutas OR carreteras OR comercio OR transporte OR abastecimiento OR fletes OR "${loc.corridor}" OR SENAMHI))$antiNoise';
        final itemsRegional = await _fetchRssQuery(
          client,
          qRegional,
          scope: RadarNewsScope.regional,
          scopeLabel: 'Regional • ${loc.department}',
          regionName: loc.department,
          limit: 4,
        );
        collectedItems.addAll(itemsRegional);

        // Cascada Nivel 3: Nacional complementaria
        final qNacional = '(Perú AND (SUNAT OR abastecimiento OR fletes OR "mercado mayorista" OR INDECOPI OR "campaña comercial"))$antiNoise';
        final itemsNacional = await _fetchRssQuery(
          client,
          qNacional,
          scope: RadarNewsScope.nacional,
          scopeLabel: 'Nacional • Perú',
          regionName: 'Perú',
          limit: 4,
        );
        collectedItems.addAll(itemsNacional);
      }
    } finally {
      if (isOwnedClient) {
        client.close();
      }
    }

    return collectedItems;
  }

  static Future<List<Map<String, dynamic>>> _fetchRssQuery(
    http.Client client,
    String query, {
    required RadarNewsScope scope,
    required String scopeLabel,
    required String regionName,
    int limit = 6,
  }) async {
    try {
      final url = Uri.parse(
        'https://news.google.com/rss/search?q=${Uri.encodeComponent(query)}&hl=es-419&gl=PE&ceid=PE:es-419',
      );
      final response = await client.get(
        url,
        headers: {'User-Agent': LinkHealthVerifier.userAgent},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return [];

      return parseRssXml(
        response.body,
        scope: scope,
        scopeLabel: scopeLabel,
        regionName: regionName,
        limit: limit,
      );
    } catch (_) {
      return [];
    }
  }

  /// Parser público de RSS XML en Dart puro (sin librerías externas)
  static List<Map<String, dynamic>> parseRssXml(
    String xml, {
    RadarNewsScope scope = RadarNewsScope.nacional,
    String scopeLabel = 'Nacional • Perú',
    String regionName = 'Perú',
    int limit = 10,
  }) {
    List<Map<String, dynamic>> items = [];
    final itemRegex = RegExp(r'<item>([\s\S]*?)<\/item>', caseSensitive: false);
    final titleRegex = RegExp(r'<title>([\s\S]*?)<\/title>', caseSensitive: false);
    final linkRegex = RegExp(r'<link>([\s\S]*?)<\/link>', caseSensitive: false);
    final pubDateRegex = RegExp(r'<pubDate>([\s\S]*?)<\/pubDate>', caseSensitive: false);
    final sourceRegex = RegExp(r'<source[^>]*>([\s\S]*?)<\/source>', caseSensitive: false);
    final imgRegex = RegExp(r'<img[^>]+src="([^">]+)"', caseSensitive: false);

    for (var match in itemRegex.allMatches(xml)) {
      if (items.length >= limit) break;
      final content = match.group(1) ?? '';

      String rawTitle = titleRegex.firstMatch(content)?.group(1) ?? '';
      rawTitle = _cleanCdataAndEntities(rawTitle);

      String rawLink = linkRegex.firstMatch(content)?.group(1) ?? '';
      rawLink = _cleanCdataAndEntities(rawLink);

      String rawPubDate = pubDateRegex.firstMatch(content)?.group(1) ?? '';
      rawPubDate = _cleanCdataAndEntities(rawPubDate);

      String rawSource = sourceRegex.firstMatch(content)?.group(1) ?? 'Prensa Nacional';
      rawSource = _cleanCdataAndEntities(rawSource);

      String? imgUrl = imgRegex.firstMatch(content)?.group(1);

      if (rawTitle.isNotEmpty && rawLink.isNotEmpty) {
        String title = rawTitle;
        if (title.contains(' - ')) {
          final parts = title.split(' - ');
          if (parts.length > 1) {
            final extractedSource = parts.last.trim();
            if (extractedSource.isNotEmpty && extractedSource.length < 35) {
              rawSource = extractedSource;
            }
            title = parts.sublist(0, parts.length - 1).join(' - ').trim();
          }
        }

        final verifiedSource = _cleanEditorialSource(rawSource, title);
        final parsedDate = parseRssPubDate(rawPubDate);

        items.add({
          'id': 'rss_${scope.code}_${items.length}_${DateTime.now().millisecondsSinceEpoch}',
          'title': title,
          'link': rawLink,
          'source': verifiedSource,
          'pubDate': parsedDate,
          'imageUrl': imgUrl,
          'scope': scope,
          'scopeLabel': scopeLabel,
          'region': regionName,
        });
      }
    }

    return items;
  }

  /// Limpia y normaliza el medio de comunicación
  static String _cleanEditorialSource(String rawSource, String title) {
    String s = rawSource.trim();
    if (s.toLowerCase() == 'facebook' || s.startsWith('http') || s.isEmpty) {
      final tLower = title.toLowerCase();
      if (tLower.contains('tiempo piura') || tLower.contains('el tiempo')) return 'El Tiempo Piura';
      if (tLower.contains('rpp')) return 'RPP Noticias';
      if (tLower.contains('gestión') || tLower.contains('gestion')) return 'Gestión';
      if (tLower.contains('andina')) return 'Andina Noticias';
      if (tLower.contains('correo')) return 'Diario Correo';
      if (tLower.contains('república') || tLower.contains('republica')) return 'La República';
      if (tLower.contains('comercio')) return 'El Comercio';
      if (tLower.contains('senamhi')) return 'SENAMHI Alertas';
      if (tLower.contains('sunat')) return 'SUNAT Prensa';
      if (tLower.contains('peruano')) return 'El Peruano';
      return 'Prensa Regional';
    }
    return s;
  }

  /// Parser público seguro de fechas RFC-822 / RFC-1123 de feeds RSS
  static DateTime parseRssPubDate(String rawDate) {
    if (rawDate.isEmpty) return DateTime.now();
    try {
      final parsed = DateTime.tryParse(rawDate);
      if (parsed != null) return parsed;

      final regex = RegExp(
        r'(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+(\d{2}):(\d{2}):(\d{2})',
      );
      final match = regex.firstMatch(rawDate);
      if (match != null) {
        final day = int.parse(match.group(1)!);
        final monthStr = match.group(2)!.toLowerCase();
        final year = int.parse(match.group(3)!);
        final hour = int.parse(match.group(4)!);
        final min = int.parse(match.group(5)!);
        final sec = int.parse(match.group(6)!);

        const months = {
          'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
          'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
        };
        final month = months[monthStr] ?? 1;
        return DateTime(year, month, day, hour, min, sec);
      }
    } catch (_) {}
    return DateTime.now();
  }

  static String _cleanCdataAndEntities(String text) {
    return text
        .replaceAll('<![CDATA[', '')
        .replaceAll(']]>', '')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }

  /// Verifica la salud de los links extraídos del RSS usando LinkHealthVerifier
  static Future<List<Map<String, dynamic>>> _verifyRssLinks(
    List<Map<String, dynamic>> items,
  ) async {
    final List<Map<String, dynamic>> verified = [];
    final verifier = _linkVerifier;

    for (var item in items) {
      final originalLink = item['link'] as String? ?? '';
      final title = item['title'] as String? ?? '';
      final workingUrl = await verifier.resolveWorkingUrl(
        originalLink,
        fallbackUrl: CommercialNewsItem.buildVerifiedSearchUrl(title),
      );

      final copy = Map<String, dynamic>.from(item);
      copy['link'] = workingUrl;
      verified.add(copy);
    }

    return verified;
  }

  // ==========================================
  // CURADURÍA GEMINI (ANALIZADOR DE TITULARES REALES) Y FALLBACK DETERMINISTA
  // ==========================================

  static Future<_CurateResult> _curateRssItems(
    List<Map<String, dynamic>> rawItems,
    RadarLocation loc,
  ) async {
    if (geminiCuratorMock != null) {
      try {
        final mocked = await geminiCuratorMock!(rawItems, loc.displayName);
        if (mocked.isNotEmpty) {
          return _CurateResult(items: mocked, mode: RadarFeedSourceMode.liveRssWithAi);
        }
      } catch (_) {}
    }

    final promptBuffer = StringBuffer();
    promptBuffer.writeln(
      "Eres el analista jefe de Inteligencia Comercial y Logística para dueños de negocios, bodegas, distribuidoras y mypes en Perú (Ubicación del usuario: ${loc.displayName}, Corredor logístico: ${loc.corridor}).",
    );
    promptBuffer.writeln(
      "Analiza los siguientes titulares de NOTICIAS REALES recién ocurridas y para cada una genera un análisis comercial estrictamente en JSON:",
    );
    promptBuffer.writeln("- id (mantén exactamente el mismo id provisto)");
    promptBuffer.writeln("- category ('Clima y Rutas', 'Mi Región', 'Leyes y SUNAT', 'Proveedores y Abastecimiento' o 'Fechas y Campañas')");
    promptBuffer.writeln("- summary (1 o 2 líneas concisas explicando qué ocurre comercial o logísticamente)");
    promptBuffer.writeln("- impactAnalysis (Explicación concreta de cómo afecta las carreteras, transporte de mercadería, fletes, clientes o cobros del negocio)");
    promptBuffer.writeln("- actionableAdvice (Medidas preventivas concretas sugeridas: compras anticipadas, stock de seguridad, coordinaciones con proveedores)");
    promptBuffer.writeln("\nNOTICIAS REALES PROVISTAS:");

    for (var item in rawItems) {
      promptBuffer.writeln("ID: ${item['id']}");
      promptBuffer.writeln("Título: ${item['title']}");
      promptBuffer.writeln("Fuente: ${item['source']}\n");
    }

    promptBuffer.writeln("IMPORTANTE: NO inventes noticias adicionales ni modifiques los IDs. Devuelve exclusivamente un array JSON válido con los campos id, category, summary, impactAnalysis, actionableAdvice.");

    for (String model in ApiConstants.cascadeModels) {
      GoogleAIClient? client;
      try {
        client = ApiConstants.createAIClient(timeout: const Duration(seconds: 20));
        final response = await client.models.generateContent(
          model: model,
          request: GenerateContentRequest(
            contents: [
              Content.user([Part.text(promptBuffer.toString())]),
            ],
            generationConfig: const GenerationConfig(
              responseMimeType: 'application/json',
              temperature: 0.2,
            ),
          ),
        );

        if (response.text != null && response.text!.isNotEmpty) {
          final decoded = jsonDecode(_sanitizeResponse(response.text!));
          if (decoded is List) {
            Map<String, dynamic> aiMap = {
              for (var row in decoded) row['id'].toString(): row
            };

            List<CommercialNewsItem> curated = [];
            for (var raw in rawItems) {
              final ai = aiMap[raw['id']] ?? {};
              curated.add(CommercialNewsItem(
                id: raw['id'],
                title: raw['title'],
                summary: ai['summary'] ?? "Noticia verificada con impacto potencial en abastecimiento o comercio en ${loc.displayName}.",
                impactAnalysis: ai['impactAnalysis'] ?? "Puede generar demoras en los despachos mayoristas o alterar el flujo habitual de clientes.",
                actionableAdvice: ai['actionableAdvice'] ?? "Adelanta tus pedidos clave de alta rotación y confirma con tus proveedores el estado de sus rutas.",
                category: ai['category'] ?? (raw['scope'] == RadarNewsScope.local ? 'Mi Región' : 'Proveedores y Abastecimiento'),
                sourceName: raw['source'],
                sourceUrl: raw['link'],
                imageUrl: raw['imageUrl'],
                publishedAt: raw['pubDate'] is DateTime ? raw['pubDate'] : DateTime.now(),
                region: raw['region'] ?? loc.displayName,
                isLive: true,
                scope: raw['scope'] ?? RadarNewsScope.nacional,
                scopeLabel: raw['scopeLabel'],
                isOfflineGuide: false,
              ));
            }
            return _CurateResult(items: curated, mode: RadarFeedSourceMode.liveRssWithAi);
          }
        }
      } catch (_) {
        // Conmutar al siguiente modelo en la cascada
      } finally {
        client?.close();
      }
    }

    // Fallback determinista local en español si Gemini no estuvo disponible
    final localAnalyzed = _analyzeLocally(rawItems, loc);
    return _CurateResult(items: localAnalyzed, mode: RadarFeedSourceMode.liveRssLocalAnalysis);
  }

  /// Analizador determinista local para noticias reales en caso de fallo o timeout de Gemini
  static List<CommercialNewsItem> _analyzeLocally(
    List<Map<String, dynamic>> rawItems,
    RadarLocation loc,
  ) {
    return rawItems.map((raw) {
      String cat = 'Mi Región';
      final lower = raw['title'].toString().toLowerCase();

      String summary;
      String impact;
      String advice;

      if (lower.contains('clima') || lower.contains('lluvia') || lower.contains('carretera') || lower.contains('ruta') || lower.contains('senamhi') || lower.contains('tránsito')) {
        cat = 'Clima y Rutas';
        summary = "Reporte vial y meteorológico en curso con impacto en el tránsito y transporte de carga.";
        impact = "Riesgo de retrasos en fletes interprovinciales por controles o condiciones de ruta en ${loc.corridor}.";
        advice = "Coordina despachos con 24h de holgura y valida itinerarios con tus transportistas.";
      } else if (lower.contains('sunat') || lower.contains('ley') || lower.contains('tribut') || lower.contains('factura') || lower.contains('boleta') || lower.contains('indecopi')) {
        cat = 'Leyes y SUNAT';
        summary = "Actualización normativa o tributaria aplicable al comercio y facturación formal en Perú.";
        impact = "Exigencias de cumplimiento en comprobantes electrónicos y guías de remisión para transporte de mercadería.";
        advice = "Revisa que tus comprobantes de venta y compras cumplan con los requisitos vigentes.";
      } else if (lower.contains('proveedor') || lower.contains('abastecimiento') || lower.contains('precio') || lower.contains('almacén') || lower.contains('mercado mayorista')) {
        cat = 'Proveedores y Abastecimiento';
        summary = "Movimiento en mercados mayoristas o cadenas de suministro de insumos y mercadería.";
        impact = "Posibles variaciones en costos de adquisición o disponibilidad de productos de alta rotación.";
        advice = "Revisa tus existencias mínimas en Mesa de Trabajo y adelanta pedidos ante alzas.";
      } else if (lower.contains('oferta') || lower.contains('campaña') || lower.contains('navidad') || lower.contains('madre') || lower.contains('escolar') || lower.contains('feriado')) {
        cat = 'Fechas y Campañas';
        summary = "Señal comercial clave para temporadas de alta demanda y promociones al consumidor.";
        impact = "Incremento esperado en la afluencia de clientes y oportunidad para elevar el ticket promedio.";
        advice = "Configura promociones por volumen y combos sugeridos en tu inventario.";
      } else {
        cat = raw['scope'] == RadarNewsScope.local ? 'Mi Región' : 'Proveedores y Abastecimiento';
        summary = "Hecho noticioso con implicancia comercial para negocios y distribuidores en ${loc.displayName}.";
        impact = "Variación potencial en la dinámica de compra local o en tiempos de reabastecimiento.";
        advice = "Supervisa tus saldos de caja y mantén comunicación fluida con proveedores clave.";
      }

      return CommercialNewsItem(
        id: raw['id'],
        title: raw['title'],
        summary: summary,
        impactAnalysis: impact,
        actionableAdvice: advice,
        category: cat,
        sourceName: raw['source'],
        sourceUrl: raw['link'],
        imageUrl: raw['imageUrl'],
        publishedAt: raw['pubDate'] is DateTime ? raw['pubDate'] : DateTime.now(),
        region: raw['region'] ?? loc.displayName,
        isLive: true,
        scope: raw['scope'] ?? RadarNewsScope.nacional,
        scopeLabel: raw['scopeLabel'],
        isOfflineGuide: false,
      );
    }).toList();
  }

  static String _sanitizeResponse(String raw) {
    String clean = raw.trim();
    if (clean.startsWith('```json')) {
      clean = clean.substring(7);
    } else if (clean.startsWith('```')) {
      clean = clean.substring(3);
    }
    if (clean.endsWith('```')) {
      clean = clean.substring(0, clean.length - 3);
    }
    return clean.trim();
  }

  /// Caché local por región con verificación estricta de fecha del día (Caducidad Matutina)
  static Future<List<CommercialNewsItem>?> _loadFromCache(
    String cacheKey,
    String currentTodayStr, {
    RadarLocation? location,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_cacheKeyPrefix$cacheKey';
      final timeKey = '$_cacheTimestampPrefix$cacheKey';
      final dateKey = '$_cacheDatePrefix$cacheKey';

      final savedDate = prefs.getString(dateKey);
      if (savedDate == null || savedDate != currentTodayStr) {
        return null;
      }

      final timestamp = prefs.getInt(timeKey);
      if (timestamp == null) return null;
      final savedTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      if (DateTime.now().difference(savedTime) > _cacheDuration) return null;

      final jsonStr = prefs.getString(key);
      if (jsonStr == null || jsonStr.isEmpty) return null;

      final List<dynamic> list = jsonDecode(jsonStr);
      return list.map((e) {
        final it = CommercialNewsItem.fromJson(e as Map<String, dynamic>);
        return sanitizeAndUpgradeNewsItem(it, region: location?.displayName ?? cacheKey);
      }).toList();
    } catch (_) {
      return null;
    }
  }

  static Future<void> _saveToCache(String cacheKey, List<CommercialNewsItem> items, String todayStr) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_cacheKeyPrefix$cacheKey';
      final timeKey = '$_cacheTimestampPrefix$cacheKey';
      final dateKey = '$_cacheDatePrefix$cacheKey';

      final jsonStr = jsonEncode(items.map((e) => e.toJson()).toList());
      await prefs.setString(key, jsonStr);
      await prefs.setInt(timeKey, DateTime.now().millisecondsSinceEpoch);
      await prefs.setString(dateKey, todayStr);
    } catch (_) {}
  }

  // ==========================================
  // CATÁLOGO DE REFERENCIA OFICIAL PERMANENTE OFFLINE (HONESTIDAD TOTAL)
  // Erradicación completa de emergenciasviales.proviasnac.gob.pe
  // Fechas permanentes fijas e isOfflineGuide: true
  // ==========================================

  /// Expuesto para pruebas unitarias de verificación de fuentes y catálogo de señales
  static List<CommercialNewsItem> getOfflineFallbackSignals({String region = 'Talara / Piura'}) {
    return _getOfflineFallback(RadarLocation.fromLegacyString(region));
  }

  static List<CommercialNewsItem> _getOfflineFallback(RadarLocation loc) {
    final bool isNorth = loc.department.toLowerCase().contains('piura') ||
        loc.department.toLowerCase().contains('tumbes') ||
        loc.department.toLowerCase().contains('lambayeque');
    final staticRefDate = DateTime(2026, 1, 1);

    return [
      // CATEGORÍA 1: Clima y Rutas (Portales Oficiales Canónicos gob.pe)
      CommercialNewsItem(
        id: 'fallback_cr_1',
        title: isNorth
            ? "MTC y Provías activan monitoreo permanente en Panamericana Norte tramo Talara-Piura"
            : "SUTRAN y Provías refuerzan fiscalización y monitoreo de transitabilidad en vías nacionales",
        summary: isNorth
            ? "Trabajos preventivos de encauzamiento y limpieza de badenes en la ruta costera norte."
            : "Controles continuos de pesaje y alertas de paso en los principales corredores logísticos.",
        impactAnalysis: isNorth
            ? "Camiones pesados desde Lima hacia el norte podrían registrar demoras de 4 a 8 horas por tránsito restringido."
            : "Posibles demoras preventivas en garitas de control interregional para carga pesada.",
        actionableAdvice:
            "Coordina tus despachos con 24 a 48 horas de holgura y asegura stock de seguridad en productos de primera necesidad.",
        category: 'Clima y Rutas',
        sourceName: 'Provías Nacional / SUTRAN',
        sourceUrl: 'https://www.gob.pe/sutran',
        publishedAt: staticRefDate,
        region: loc.displayName,
        isLive: false,
        isOfflineGuide: true,
        scope: RadarNewsScope.regional,
        scopeLabel: 'Regional • ${loc.department}',
      ),
      CommercialNewsItem(
        id: 'fallback_cr_2',
        title: "SENAMHI emite aviso meteorológico sobre variaciones térmicas y vientos en la costa",
        summary: "Incremento de vientos y bancos de niebla matutina afecta visibilidad en carreteras interprovinciales.",
        impactAnalysis: "Reducción de velocidad en fletes nocturnos y mayor consumo de combustible en transporte de mercancías.",
        actionableAdvice: "Solicita a transportistas confirmación de itinerarios de llegada antes de pactar entregas con clientes finales.",
        category: 'Clima y Rutas',
        sourceName: 'SENAMHI Alertas',
        sourceUrl: 'https://www.gob.pe/senamhi',
        publishedAt: staticRefDate,
        region: 'Perú',
        isLive: false,
        isOfflineGuide: true,
        scope: RadarNewsScope.nacional,
        scopeLabel: 'Nacional • Perú',
      ),
      CommercialNewsItem(
        id: 'fallback_cr_3',
        title: "SUTRAN: Reporte de puntos de control vial y mapa interactivo para transportistas",
        summary: "Monitoreo en tiempo real de incidentes viales y desvíos programados en la red nacional.",
        impactAnalysis: "Tramos con mantenimiento preventivo pueden sumar entre 1 y 3 horas a los fletes entre departamentos.",
        actionableAdvice: "Verifica el mapa de alertas viales antes de despachar pedidos de alto valor o productos perecibles.",
        category: 'Clima y Rutas',
        sourceName: 'SUTRAN Alerta Vial',
        sourceUrl: 'https://www.gob.pe/sutran',
        publishedAt: staticRefDate,
        region: 'Perú',
        isLive: false,
        isOfflineGuide: true,
        scope: RadarNewsScope.nacional,
        scopeLabel: 'Nacional • Perú',
      ),
      CommercialNewsItem(
        id: 'fallback_cr_4',
        title: "Provías Nacional: Mantenimiento vial rutinario en puentes y badenes interregionales",
        summary: "Cuadrillas técnicas ejecutan conservación de carpeta asfáltica en los principales corredores del país.",
        impactAnalysis: "Paso alternado por un solo carril en zonas de obras durante horas diurnas.",
        actionableAdvice: "Programa traslados de mercadería en horarios de menor congestión para evitar demoras innecesarias.",
        category: 'Clima y Rutas',
        sourceName: 'Provías Nacional',
        sourceUrl: 'https://www.gob.pe/proviasnacional',
        publishedAt: staticRefDate,
        region: loc.department,
        isLive: false,
        isOfflineGuide: true,
        scope: RadarNewsScope.regional,
        scopeLabel: 'Regional • ${loc.department}',
      ),

      // CATEGORÍA 2: Leyes y SUNAT (Portales Canónicos gob.pe)
      CommercialNewsItem(
        id: 'fallback_ls_1',
        title: "SUNAT: Obligatoriedad de Guías de Remisión Electrónicas (GRE) para traslado de bienes",
        summary: "Transportistas y remitentes deben emitir GRE Remitente y Transportista de forma digital con código QR.",
        impactAnalysis: "Multas e incautación preventiva de mercadería en garitas si no se cuenta con la GRE validada.",
        actionableAdvice: "Verifica que tus facturas de compra cuenten con su GRE respectiva antes de autorizar la carga al camión.",
        category: 'Leyes y SUNAT',
        sourceName: 'SUNAT Portal Oficial GRE',
        sourceUrl: 'https://www.gob.pe/sunat',
        publishedAt: staticRefDate,
        region: 'Perú',
        isLive: false,
        isOfflineGuide: true,
        scope: RadarNewsScope.nacional,
        scopeLabel: 'Nacional • Perú',
      ),
      CommercialNewsItem(
        id: 'fallback_ls_2',
        title: "SUNAT: Cronograma de vencimientos mensuales para declaraciones de IGV y Renta",
        summary: "Fechas límite escalonadas según el último dígito del RUC para evitar multas por declaración tardía.",
        impactAnalysis: "El retraso en la declaración genera intereses moratorios y pérdida de beneficios de buen contribuyente.",
        actionableAdvice: "Organiza tus comprobantes de venta y compras con tu contador 5 días antes de tu fecha límite.",
        category: 'Leyes y SUNAT',
        sourceName: 'SUNAT Cronograma Oficial',
        sourceUrl: 'https://www.gob.pe/sunat',
        publishedAt: staticRefDate,
        region: 'Perú',
        isLive: false,
        isOfflineGuide: true,
        scope: RadarNewsScope.nacional,
        scopeLabel: 'Nacional • Perú',
      ),
      CommercialNewsItem(
        id: 'fallback_ls_3',
        title: "INDECOPI: Derechos del consumidor y fiscalización de precios visibles en mostradores",
        summary: "Comercios minoristas deben exhibir precios finales en moneda nacional incluyendo todos los tributos.",
        impactAnalysis: "Sanciones administrativas y clausuras temporales ante denuncias de cobros no informados o redondeos indebidos.",
        actionableAdvice: "Revisa que todos tus productos en estantería tengan etiquetas de precio claras y coincidan con tu sistema.",
        category: 'Leyes y SUNAT',
        sourceName: 'INDECOPI Oficial',
        sourceUrl: 'https://www.gob.pe/indecopi',
        publishedAt: staticRefDate,
        region: 'Perú',
        isLive: false,
        isOfflineGuide: true,
        scope: RadarNewsScope.nacional,
        scopeLabel: 'Nacional • Perú',
      ),

      // CATEGORÍA 3: Proveedores y Abastecimiento (Portales Canónicos gob.pe)
      CommercialNewsItem(
        id: 'fallback_pa_1',
        title: "MIDAGRI: Reporte de abastecimiento y precios mayoristas en mercados de abasto",
        summary: "Ingreso regular de hortalizas, legumbres, tubérculos y frutas a los centros de distribución mayorista.",
        impactAnalysis: "Estabilidad en precios base de alimentos permite proyectar márgenes sin sobresaltos para la semana.",
        actionableAdvice: "Consulta el boletín de precios mayoristas antes de negociar pedidos semanales con tus distribuidores.",
        category: 'Proveedores y Abastecimiento',
        sourceName: 'MIDAGRI Oficial',
        sourceUrl: 'https://www.gob.pe/midagri',
        publishedAt: staticRefDate,
        region: 'Perú',
        isLive: false,
        isOfflineGuide: true,
        scope: RadarNewsScope.nacional,
        scopeLabel: 'Nacional • Perú',
      ),
      CommercialNewsItem(
        id: 'fallback_pa_2',
        title: "PRODUCE Tu Empresa: Programas de articulación comercial y digitalización para mypes",
        summary: "Iniciativas para conectar pequeños negocios con cadenas productivas y capacitación en gestión comercial.",
        impactAnalysis: "Acceso a ferias de proveedores formales y líneas de financiamiento respaldadas por el Estado.",
        actionableAdvice: "Aprovecha los talleres virtuales gratuitos de PRODUCE para capacitar a tu personal en ventas y cobros.",
        category: 'Proveedores y Abastecimiento',
        sourceName: 'PRODUCE Tu Empresa',
        sourceUrl: 'https://www.gob.pe/tuempresa',
        publishedAt: staticRefDate,
        region: 'Perú',
        isLive: false,
        isOfflineGuide: true,
        scope: RadarNewsScope.nacional,
        scopeLabel: 'Nacional • Perú',
      ),

      // CATEGORÍA 4: Mi Región (Contextualizada con loc.displayName)
      CommercialNewsItem(
        id: 'fallback_mr_1',
        title: loc.district != null
            ? "Actividad Comercial y Flujo de Clientes en ${loc.district} (${loc.province}, ${loc.department})"
            : "Actividad Comercial y Flujo de Clientes en ${loc.province} (${loc.department})",
        summary: "Comercios locales reportan dinamismo continuo y preferencia creciente por pagos digitales con QR.",
        impactAnalysis: "Más del 65% de los clientes en zonas urbanas prefieren cancelar mediante billeteras electrónicas.",
        actionableAdvice: "Mantén visible tu código QR de Yape y Plin en el mostrador para evitar pérdidas de venta rápida.",
        category: 'Mi Región',
        sourceName: 'PRODUCE Tu Empresa',
        sourceUrl: 'https://www.gob.pe/tuempresa',
        publishedAt: staticRefDate,
        region: loc.displayName,
        isLive: false,
        isOfflineGuide: true,
        scope: RadarNewsScope.local,
        scopeLabel: loc.district != null ? 'Local • ${loc.district}' : 'Local • ${loc.province}',
      ),
      CommercialNewsItem(
        id: 'fallback_mr_2',
        title: "Corredor Logístico ${loc.corridor}: Transitabilidad y transporte de abarrotes",
        summary: "Flujo sostenido de unidades de distribución de mercancías y paquetería hacia los distritos comerciales.",
        impactAnalysis: "Tiempos regulares de arribo de camiones mayoristas aseguran stock continuo en almacenes.",
        actionableAdvice: "Programa recepción de mercadería en horas matutinas para verificar cantidades antes de la apertura.",
        category: 'Mi Región',
        sourceName: 'Observatorio Logístico Regional',
        sourceUrl: 'https://www.gob.pe/sutran',
        publishedAt: staticRefDate,
        region: loc.department,
        isLive: false,
        isOfflineGuide: true,
        scope: RadarNewsScope.regional,
        scopeLabel: 'Regional • ${loc.department}',
      ),

      // CATEGORÍA 5: Fechas y Campañas
      CommercialNewsItem(
        id: 'fallback_fc_1',
        title: "Campañas Comerciales del Año: Planificación de surtido para temporadas de alta rotación",
        summary: "Fechas clave del calendario peruano dinamizan el consumo familiar y la venta de artículos escolares y festivos.",
        impactAnalysis: "Los comercios que adelantan su abastecimiento capturan las primeras compras con márgenes superiores.",
        actionableAdvice: "Organiza tus pedidos con 30 días de anticipación y arma combos temáticos atractivos.",
        category: 'Fechas y Campañas',
        sourceName: 'PRODUCE Calendario MYPE',
        sourceUrl: 'https://www.gob.pe/tuempresa',
        publishedAt: staticRefDate,
        region: 'Perú',
        isLive: false,
        isOfflineGuide: true,
        scope: RadarNewsScope.nacional,
        scopeLabel: 'Nacional • Perú',
      ),
    ];
  }
}
