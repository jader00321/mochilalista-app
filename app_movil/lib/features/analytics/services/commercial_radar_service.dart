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

part 'commercial_radar_sources.dart';
part 'commercial_radar_scoring.dart';
part 'commercial_radar_persistence.dart';

class CommercialRadarService {
  static const String _cacheKeyPrefix = 'commercial_radar_cache_v5_';
  static const String _cacheTimestampPrefix = 'commercial_radar_time_v5_';
  static const String _cacheDatePrefix = 'commercial_radar_date_v5_';
  static const Duration _cacheDuration = Duration(hours: 4);

  /// Claves heredadas (globales) y bandera de migración única (Plan Maestro 21 - Pilar 3)
  static const String legacyLocationJsonPrefKey =
      'commercial_radar_selected_location_json';
  static const String legacyRegionPrefKey = 'commercial_radar_selected_region';
  static const String legacySavedNewsPrefKey =
      'commercial_radar_bookmarked_items_json';
  static const String legacyMigratedPrefKey =
      'commercial_radar_legacy_migrated_v21';
  static const String _savedTableName = 'radar_noticias_guardadas';

  /// Cliente HTTP inyectable para pruebas unitarias sin tráfico real de red
  static http.Client? customHttpClient;

  /// Mock inyectable para emular el enriquecimiento Gemini en pruebas automatizadas
  static Future<List<CommercialNewsItem>> Function(
    List<Map<String, dynamic>>,
    String,
  )? geminiCuratorMock;

  /// Modo del origen del último feed emitido
  static RadarFeedSourceMode lastSourceMode = RadarFeedSourceMode.liveRssWithAi;

  /// Cantidad de nuevas señales incorporadas en el último refresco intradía
  static int lastNewSignalsCount = 0;

  /// Caché estática en memoria para 0ms de latencia y 0 saltos de renderizado
  static final Map<String, List<CommercialNewsItem>> _memoryCache = {};

  /// Lock de coalescencia para evitar migraciones concurrentes dentro del mismo frame
  static Future<void>? _activeLegacyMigration;

  /// Instancia de LinkHealthVerifier vinculada al cliente HTTP configurado
  static LinkHealthVerifier get _linkVerifier =>
      LinkHealthVerifier(client: customHttpClient);

  /// Fecha del día para control de caducidad matutina (yyyy-MM-dd)
  static String getTodayDateStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Clave de SharedPreferences para ubicación JSON estructurada aislada por perfil
  static String locationJsonPrefKey(int? profileId) => profileId != null
      ? 'commercial_radar_profile_${profileId}_location_json'
      : legacyLocationJsonPrefKey;

  /// Clave de SharedPreferences para etiqueta de región aislada por perfil
  static String regionPrefKey(int? profileId) => profileId != null
      ? 'commercial_radar_profile_${profileId}_region'
      : legacyRegionPrefKey;

  /// Clave de SharedPreferences para noticias guardadas aisladas por perfil
  static String savedNewsPrefKey(int? profileId) => profileId != null
      ? 'commercial_radar_saved_profile_$profileId'
      : legacySavedNewsPrefKey;

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
  static List<CommercialNewsItem> interleaveCategories(
    List<CommercialNewsItem> items,
  ) =>
      _radarInterleaveCategories(items);

  /// Fusión intradía inteligente: agrega nuevas noticias sin borrar las anteriores del día
  static List<CommercialNewsItem> mergeNewsItems(
    List<CommercialNewsItem> existing,
    List<CommercialNewsItem> incoming,
  ) =>
      _radarMergeNewsItems(existing, incoming);

  /// Saneamiento y actualización de noticias cacheadas o guardadas a rutas canónicas gob.pe
  static CommercialNewsItem sanitizeAndUpgradeNewsItem(
    CommercialNewsItem item, {
    String region = 'Talara / Piura',
  }) =>
      _radarSanitizeAndUpgradeNewsItem(item, region: region);

  /// Migra preferencias globales heredadas hacia el primer perfil activo una sola vez
  static Future<void> migrateLegacyToProfileIfNeeded({
    required int profileId,
  }) =>
      _radarMigrateLegacyToProfileIfNeeded(profileId: profileId);

  /// Carga la ubicación estructurada del Radar para el perfil indicado
  static Future<RadarLocation> loadLocationForProfile({
    int? profileId,
    required RadarLocation fallback,
  }) =>
      _radarLoadLocationForProfile(profileId: profileId, fallback: fallback);

  /// Persiste la ubicación estructurada del Radar para el perfil indicado
  static Future<void> saveLocationForProfile(
    RadarLocation location, {
    int? profileId,
  }) =>
      _radarSaveLocationForProfile(location, profileId: profileId);

  /// Carga la etiqueta de región para la tarjeta del Radar aislada por perfil
  static Future<String> loadRegionLabelForProfile({
    int? profileId,
    required String defaultRegion,
  }) =>
      _radarLoadRegionLabelForProfile(
        profileId: profileId,
        defaultRegion: defaultRegion,
      );

  /// Persiste la etiqueta de región sincronizando su JSON de perfil
  static Future<void> saveRegionLabelForProfile(
    String regionLabel, {
    int? profileId,
  }) =>
      _radarSaveRegionLabelForProfile(regionLabel, profileId: profileId);

  /// Obtiene todas las noticias guardadas permanentemente por el perfil activo
  static Future<List<CommercialNewsItem>> getSavedNews({int? profileId}) =>
      _radarGetSavedNews(profileId: profileId);

  /// Guarda permanentemente una noticia aislada por perfil (y SQLite solo sin perfil)
  static Future<void> saveNewsItem(
    CommercialNewsItem item, {
    int? profileId,
  }) =>
      _radarSaveNewsItem(item, profileId: profileId);

  /// Elimina una noticia guardada para el perfil indicado
  static Future<void> removeSavedNews(String id, {int? profileId}) =>
      _radarRemoveSavedNews(id, profileId: profileId);

  /// Verifica si una noticia está guardada para el perfil indicado
  static Future<bool> isNewsSaved(String id, {int? profileId}) =>
      _radarIsNewsSaved(id, profileId: profileId);

  /// Obtiene las noticias curadas progresivamente con Fusión Intradía y Caducidad Matutina
  static Stream<CommercialNewsItem> streamCuratedNews({
    String region = 'Talara / Piura',
    RadarLocation? location,
    bool forceRefresh = false,
  }) =>
      _radarStreamCuratedNews(
        region: region,
        location: location,
        forceRefresh: forceRefresh,
      );

  /// Parser público de RSS XML en Dart puro (sin librerías externas)
  static List<Map<String, dynamic>> parseRssXml(
    String xml, {
    RadarNewsScope scope = RadarNewsScope.nacional,
    String scopeLabel = 'Nacional • Perú',
    String regionName = 'Perú',
    int limit = 10,
  }) =>
      _radarParseRssXml(
        xml,
        scope: scope,
        scopeLabel: scopeLabel,
        regionName: regionName,
        limit: limit,
      );

  /// Parser público seguro de fechas RFC-822 / RFC-1123 de feeds RSS
  static DateTime parseRssPubDate(String rawDate) =>
      _radarParseRssPubDate(rawDate);

  /// Expuesto para pruebas unitarias de verificación de fuentes y catálogo de señales
  static List<CommercialNewsItem> getOfflineFallbackSignals({
    String region = 'Talara / Piura',
  }) =>
      _radarGetOfflineFallbackSignals(region: region);
}
