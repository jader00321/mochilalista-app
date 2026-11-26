part of 'commercial_radar_service.dart';

Future<void> _radarEnsureSavedTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS ${CommercialRadarService._savedTableName} (
      id TEXT PRIMARY KEY,
      json_data TEXT NOT NULL,
      created_at TEXT NOT NULL
    )
  ''');
}

Future<void> _radarMigrateLegacyToProfileIfNeeded({
  required int profileId,
}) async {
  final inFlight = CommercialRadarService._activeLegacyMigration;
  if (inFlight != null) {
    await inFlight;
    return;
  }

  final future = _radarRunLegacyMigrationIfNeeded(profileId: profileId);
  CommercialRadarService._activeLegacyMigration = future;
  try {
    await future;
  } finally {
    if (identical(CommercialRadarService._activeLegacyMigration, future)) {
      CommercialRadarService._activeLegacyMigration = null;
    }
  }
}

Future<void> _radarRunLegacyMigrationIfNeeded({
  required int profileId,
}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(CommercialRadarService.legacyMigratedPrefKey) == true) {
      return;
    }

    final targetLocKey = CommercialRadarService.locationJsonPrefKey(profileId);
    final targetRegKey = CommercialRadarService.regionPrefKey(profileId);
    final targetSavedKey = CommercialRadarService.savedNewsPrefKey(profileId);

    if (!prefs.containsKey(targetLocKey) &&
        !prefs.containsKey(targetRegKey)) {
      final legacyJson =
          prefs.getString(CommercialRadarService.legacyLocationJsonPrefKey);
      final legacyReg =
          prefs.getString(CommercialRadarService.legacyRegionPrefKey);

      if (legacyJson != null && legacyJson.trim().isNotEmpty) {
        await prefs.setString(targetLocKey, legacyJson);
        try {
          final parsed = RadarLocation.fromJson(
            jsonDecode(legacyJson) as Map<String, dynamic>,
          );
          await prefs.setString(
            targetRegKey,
            (legacyReg != null && legacyReg.trim().isNotEmpty)
                ? legacyReg
                : parsed.displayName,
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
      final legacySaved = await _radarReadLegacySavedNews(prefs: prefs);
      if (legacySaved.isNotEmpty) {
        await prefs.setString(
          targetSavedKey,
          jsonEncode(legacySaved.map((e) => e.toJson()).toList()),
        );
      }
    }

    await prefs.setBool(CommercialRadarService.legacyMigratedPrefKey, true);
  } catch (_) {}
}

Future<RadarLocation> _radarLoadLocationForProfile({
  int? profileId,
  required RadarLocation fallback,
}) async {
  try {
    if (profileId != null) {
      await _radarMigrateLegacyToProfileIfNeeded(profileId: profileId);
    }
    final prefs = await SharedPreferences.getInstance();
    final savedLocJson = prefs.getString(
      CommercialRadarService.locationJsonPrefKey(profileId),
    );
    if (savedLocJson != null && savedLocJson.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(savedLocJson) as Map<String, dynamic>;
        return RadarLocation.fromJson(decoded);
      } catch (_) {}
    }
    final savedReg = prefs.getString(
      CommercialRadarService.regionPrefKey(profileId),
    );
    if (savedReg != null && savedReg.trim().isNotEmpty) {
      return RadarLocation.fromLegacyString(savedReg);
    }
  } catch (_) {}
  return fallback;
}

Future<void> _radarSaveLocationForProfile(
  RadarLocation location, {
  int? profileId,
}) async {
  try {
    if (profileId != null) {
      await _radarMigrateLegacyToProfileIfNeeded(profileId: profileId);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      CommercialRadarService.locationJsonPrefKey(profileId),
      jsonEncode(location.toJson()),
    );
    await prefs.setString(
      CommercialRadarService.regionPrefKey(profileId),
      location.displayName,
    );
  } catch (_) {}
}

Future<String> _radarLoadRegionLabelForProfile({
  int? profileId,
  required String defaultRegion,
}) async {
  try {
    if (profileId != null) {
      await _radarMigrateLegacyToProfileIfNeeded(profileId: profileId);
    }
    final prefs = await SharedPreferences.getInstance();
    final savedReg = prefs.getString(
      CommercialRadarService.regionPrefKey(profileId),
    );
    if (savedReg != null && savedReg.trim().isNotEmpty) {
      return savedReg;
    }
    final savedLocJson = prefs.getString(
      CommercialRadarService.locationJsonPrefKey(profileId),
    );
    if (savedLocJson != null && savedLocJson.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(savedLocJson) as Map<String, dynamic>;
        return RadarLocation.fromJson(decoded).displayName;
      } catch (_) {}
    }
  } catch (_) {}
  return defaultRegion;
}

Future<void> _radarSaveRegionLabelForProfile(
  String regionLabel, {
  int? profileId,
}) async {
  try {
    if (profileId != null) {
      await _radarMigrateLegacyToProfileIfNeeded(profileId: profileId);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      CommercialRadarService.regionPrefKey(profileId),
      regionLabel,
    );
    final parsed = RadarLocation.fromLegacyString(regionLabel);
    await prefs.setString(
      CommercialRadarService.locationJsonPrefKey(profileId),
      jsonEncode(parsed.toJson()),
    );
  } catch (_) {}
}

Future<List<CommercialNewsItem>> _radarReadLegacySavedNews({
  SharedPreferences? prefs,
}) async {
  List<CommercialNewsItem> items = [];
  try {
    final db = await LocalDatabase.instance.database;
    await _radarEnsureSavedTable(db);
    final rows = await db.query(
      CommercialRadarService._savedTableName,
      orderBy: 'created_at DESC',
    );
    if (rows.isNotEmpty) {
      items = rows.map((r) {
        if (r.containsKey('json_data') && r['json_data'] != null) {
          final jsonMap =
              jsonDecode(r['json_data'] as String) as Map<String, dynamic>;
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
            publishedAt:
                DateTime.tryParse((r['published_at'] ?? '').toString()) ??
                    DateTime.now(),
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
      final str = sp.getString(CommercialRadarService.legacySavedNewsPrefKey);
      if (str != null && str.isNotEmpty) {
        final List<dynamic> list = jsonDecode(str);
        items = list
            .map((e) => CommercialNewsItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
  }

  return items;
}

Future<List<CommercialNewsItem>> _radarGetSavedNews({int? profileId}) async {
  List<CommercialNewsItem> items = [];

  if (profileId != null) {
    await _radarMigrateLegacyToProfileIfNeeded(profileId: profileId);
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(
        CommercialRadarService.savedNewsPrefKey(profileId),
      );
      if (str != null && str.isNotEmpty) {
        final List<dynamic> list = jsonDecode(str);
        items = list
            .map((e) => CommercialNewsItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
  } else {
    items = await _radarReadLegacySavedNews();
  }

  if (items.isEmpty) return [];

  bool hasChanges = false;
  final List<CommercialNewsItem> upgraded = [];
  for (final it in items) {
    final up = _radarSanitizeAndUpgradeNewsItem(it);
    if (up.sourceUrl != it.sourceUrl || up.sourceName != it.sourceName) {
      hasChanges = true;
    }
    upgraded.add(up);
  }

  if (hasChanges) {
    unawaited(_radarPersistUpgradedSavedNews(upgraded, profileId: profileId));
  }

  return upgraded;
}

Future<void> _radarPersistUpgradedSavedNews(
  List<CommercialNewsItem> items, {
  int? profileId,
}) async {
  if (profileId == null) {
    try {
      final db = await LocalDatabase.instance.database;
      await _radarEnsureSavedTable(db);
      final batch = db.batch();
      for (final item in items) {
        batch.insert(
          CommercialRadarService._savedTableName,
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
      CommercialRadarService.savedNewsPrefKey(profileId),
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  } catch (_) {}
}

Future<void> _radarSaveNewsItem(
  CommercialNewsItem item, {
  int? profileId,
}) async {
  final sanitizedItem = _radarSanitizeAndUpgradeNewsItem(item);
  if (profileId != null) {
    await _radarMigrateLegacyToProfileIfNeeded(profileId: profileId);
  } else {
    try {
      final db = await LocalDatabase.instance.database;
      await _radarEnsureSavedTable(db);
      final jsonStr = jsonEncode(sanitizedItem.toJson());
      await db.insert(
        CommercialRadarService._savedTableName,
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
    final current = await _radarGetSavedNews(profileId: profileId);
    if (!current.any((i) => i.id == sanitizedItem.id)) {
      current.insert(0, sanitizedItem);
    }
    await prefs.setString(
      CommercialRadarService.savedNewsPrefKey(profileId),
      jsonEncode(current.map((e) => e.toJson()).toList()),
    );
  } catch (_) {}
}

Future<void> _radarRemoveSavedNews(String id, {int? profileId}) async {
  if (profileId != null) {
    await _radarMigrateLegacyToProfileIfNeeded(profileId: profileId);
  } else {
    try {
      final db = await LocalDatabase.instance.database;
      await _radarEnsureSavedTable(db);
      await db.delete(
        CommercialRadarService._savedTableName,
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (_) {}
  }

  try {
    final prefs = await SharedPreferences.getInstance();
    final current = await _radarGetSavedNews(profileId: profileId);
    current.removeWhere((i) => i.id == id);
    await prefs.setString(
      CommercialRadarService.savedNewsPrefKey(profileId),
      jsonEncode(current.map((e) => e.toJson()).toList()),
    );
  } catch (_) {}
}

Future<bool> _radarIsNewsSaved(String id, {int? profileId}) async {
  if (profileId != null) {
    final current = await _radarGetSavedNews(profileId: profileId);
    return current.any((i) => i.id == id);
  }
  try {
    final db = await LocalDatabase.instance.database;
    await _radarEnsureSavedTable(db);
    final rows = await db.query(
      CommercialRadarService._savedTableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isNotEmpty;
  } catch (_) {
    final current = await _radarGetSavedNews();
    return current.any((i) => i.id == id);
  }
}

Future<List<CommercialNewsItem>?> _radarLoadFromCache(
  String cacheKey,
  String currentTodayStr, {
  RadarLocation? location,
}) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final key = '${CommercialRadarService._cacheKeyPrefix}$cacheKey';
    final timeKey = '${CommercialRadarService._cacheTimestampPrefix}$cacheKey';
    final dateKey = '${CommercialRadarService._cacheDatePrefix}$cacheKey';

    final savedDate = prefs.getString(dateKey);
    if (savedDate == null || savedDate != currentTodayStr) {
      return null;
    }

    final timestamp = prefs.getInt(timeKey);
    if (timestamp == null) return null;
    final savedTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    if (DateTime.now().difference(savedTime) >
        CommercialRadarService._cacheDuration) {
      return null;
    }

    final jsonStr = prefs.getString(key);
    if (jsonStr == null || jsonStr.isEmpty) return null;

    final List<dynamic> list = jsonDecode(jsonStr);
    return list.map((e) {
      final it = CommercialNewsItem.fromJson(e as Map<String, dynamic>);
      return _radarSanitizeAndUpgradeNewsItem(
        it,
        region: location?.displayName ?? cacheKey,
      );
    }).toList();
  } catch (_) {
    return null;
  }
}

Future<void> _radarSaveToCache(
  String cacheKey,
  List<CommercialNewsItem> items,
  String todayStr,
) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final key = '${CommercialRadarService._cacheKeyPrefix}$cacheKey';
    final timeKey = '${CommercialRadarService._cacheTimestampPrefix}$cacheKey';
    final dateKey = '${CommercialRadarService._cacheDatePrefix}$cacheKey';

    final jsonStr = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(key, jsonStr);
    await prefs.setInt(timeKey, DateTime.now().millisecondsSinceEpoch);
    await prefs.setString(dateKey, todayStr);
  } catch (_) {}
}
