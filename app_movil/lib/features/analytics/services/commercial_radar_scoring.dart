part of 'commercial_radar_service.dart';

class _CurateResult {
  final List<CommercialNewsItem> items;
  final RadarFeedSourceMode mode;

  const _CurateResult({required this.items, required this.mode});
}

List<CommercialNewsItem> _radarInterleaveCategories(
  List<CommercialNewsItem> items,
) {
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
    } else if (cat.contains('campaña') ||
        cat.contains('campana') ||
        cat.contains('fecha')) {
      buckets['campanas']!.add(item);
    } else if (cat.contains('región') || cat.contains('region')) {
      buckets['region']!.add(item);
    } else {
      buckets['otros']!.add(item);
    }
  }

  final List<CommercialNewsItem> result = [];
  final keys = [
    'clima',
    'proveedores',
    'sunat',
    'region',
    'campanas',
    'otros',
  ];

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

List<CommercialNewsItem> _radarMergeNewsItems(
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

  CommercialRadarService.lastNewSignalsCount = newlyAdded;

  final list = mergedMap.values.toList();
  list.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
  return _radarInterleaveCategories(list);
}

CommercialNewsItem _radarSanitizeAndUpgradeNewsItem(
  CommercialNewsItem item, {
  String region = 'Talara / Piura',
}) {
  final fallbackList = _radarGetOfflineFallback(
    RadarLocation.fromLegacyString(region),
  );
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

  String updatedUrl = item.sourceUrl.trim();
  String updatedSource = item.sourceName.trim();

  if (updatedUrl.contains('emergenciasviales.proviasnac.gob.pe') ||
      updatedUrl.contains('976451.aspx') ||
      updatedUrl.contains('alerta_sutran')) {
    updatedUrl = 'https://www.gob.pe/sutran';
    updatedSource = 'Provías Nacional / SUTRAN';
  } else if (updatedUrl.contains('sunat') ||
      updatedUrl.contains('guias-de-remision-electronica')) {
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
  } else if (updatedSource.contains('Cámara de Comercio') &&
      updatedUrl.contains('gestion.pe')) {
    updatedUrl = CommercialNewsItem.buildVerifiedSearchUrl(
      item.cleanTitle,
      mediaDomain: 'lacamara.pe',
    );
    updatedSource = 'Cámara de Comercio de Lima';
  }

  return item.copyWith(sourceUrl: updatedUrl, sourceName: updatedSource);
}

Stream<CommercialNewsItem> _radarStreamCuratedNews({
  String region = 'Talara / Piura',
  RadarLocation? location,
  bool forceRefresh = false,
}) async* {
  final loc = location ?? RadarLocation.fromLegacyString(region);
  final cacheKey = CommercialRadarService.buildCacheKey(loc);
  final todayStr = CommercialRadarService.getTodayDateStr();

  if (!forceRefresh &&
      CommercialRadarService._memoryCache.containsKey(cacheKey) &&
      CommercialRadarService._memoryCache[cacheKey]!.isNotEmpty) {
    final balanced = _radarInterleaveCategories(
      CommercialRadarService._memoryCache[cacheKey]!,
    );
    for (var item in balanced) {
      yield item;
    }
    return;
  }

  if (!forceRefresh) {
    final cached = await _radarLoadFromCache(cacheKey, todayStr, location: loc);
    if (cached != null && cached.isNotEmpty) {
      CommercialRadarService.lastSourceMode = RadarFeedSourceMode.cachedRecent;
      final balanced = _radarInterleaveCategories(cached);
      CommercialRadarService._memoryCache[cacheKey] = balanced;
      for (var item in balanced) {
        yield item;
      }
      return;
    }
  }

  List<CommercialNewsItem> existingOfDay = [];
  if (forceRefresh) {
    final currentInMem = CommercialRadarService._memoryCache[cacheKey];
    if (currentInMem != null && currentInMem.isNotEmpty) {
      existingOfDay = List.from(currentInMem);
    } else {
      final fromDisk = await _radarLoadFromCache(
        cacheKey,
        todayStr,
        location: loc,
      );
      if (fromDisk != null) existingOfDay = fromDisk;
    }
  }

  List<CommercialNewsItem> newlyFetched = [];
  RadarFeedSourceMode determinedMode = RadarFeedSourceMode.liveRssWithAi;

  try {
    final rawRssItems = await _radarFetchGoogleNewsRssCascade(loc);
    if (rawRssItems.isNotEmpty) {
      final verifiedRssItems = await _radarVerifyRssLinks(rawRssItems);
      final curateResult = await _radarCurateRssItems(verifiedRssItems, loc);
      newlyFetched = curateResult.items;
      determinedMode = curateResult.mode;
    }
  } catch (_) {}

  if (newlyFetched.isEmpty) {
    final fromDisk = await _radarLoadFromCache(
      cacheKey,
      todayStr,
      location: loc,
    );
    if (fromDisk != null && fromDisk.isNotEmpty) {
      newlyFetched = fromDisk;
      determinedMode = RadarFeedSourceMode.cachedRecent;
    } else {
      newlyFetched = _radarGetOfflineFallback(loc);
      determinedMode = RadarFeedSourceMode.offlineGuide;
    }
  }

  CommercialRadarService.lastSourceMode = determinedMode;

  List<CommercialNewsItem> finalFeed;
  if (existingOfDay.isNotEmpty &&
      determinedMode != RadarFeedSourceMode.offlineGuide) {
    finalFeed = _radarMergeNewsItems(existingOfDay, newlyFetched);
  } else {
    CommercialRadarService.lastNewSignalsCount = newlyFetched.length;
    finalFeed = _radarInterleaveCategories(newlyFetched);
  }

  CommercialRadarService._memoryCache[cacheKey] = finalFeed;
  await _radarSaveToCache(cacheKey, finalFeed, todayStr);

  for (var item in finalFeed) {
    yield item;
  }
}

Future<_CurateResult> _radarCurateRssItems(
  List<Map<String, dynamic>> rawItems,
  RadarLocation loc,
) async {
  if (CommercialRadarService.geminiCuratorMock != null) {
    try {
      final mocked = await CommercialRadarService.geminiCuratorMock!(
        rawItems,
        loc.displayName,
      );
      if (mocked.isNotEmpty) {
        return _CurateResult(
          items: mocked,
          mode: RadarFeedSourceMode.liveRssWithAi,
        );
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
  promptBuffer.writeln(
    "- category ('Clima y Rutas', 'Mi Región', 'Leyes y SUNAT', 'Proveedores y Abastecimiento' o 'Fechas y Campañas')",
  );
  promptBuffer.writeln(
    "- summary (1 o 2 líneas concisas explicando qué ocurre comercial o logísticamente)",
  );
  promptBuffer.writeln(
    "- impactAnalysis (Explicación concreta de cómo afecta las carreteras, transporte de mercadería, fletes, clientes o cobros del negocio)",
  );
  promptBuffer.writeln(
    "- actionableAdvice (Medidas preventivas concretas sugeridas: compras anticipadas, stock de seguridad, coordinaciones con proveedores)",
  );
  promptBuffer.writeln("\nNOTICIAS REALES PROVISTAS:");

  for (var item in rawItems) {
    promptBuffer.writeln("ID: ${item['id']}");
    promptBuffer.writeln("Título: ${item['title']}");
    promptBuffer.writeln("Fuente: ${item['source']}\n");
  }

  promptBuffer.writeln(
    "IMPORTANTE: NO inventes noticias adicionales ni modifiques los IDs. Devuelve exclusivamente un array JSON válido con los campos id, category, summary, impactAnalysis, actionableAdvice.",
  );

  for (String model in ApiConstants.cascadeModels) {
    GoogleAIClient? client;
    try {
      client = ApiConstants.createAIClient(
        timeout: const Duration(seconds: 20),
      );
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
        final decoded = jsonDecode(_radarSanitizeResponse(response.text!));
        if (decoded is List) {
          Map<String, dynamic> aiMap = {
            for (var row in decoded) row['id'].toString(): row,
          };

          List<CommercialNewsItem> curated = [];
          for (var raw in rawItems) {
            final ai = aiMap[raw['id']] ?? {};
            curated.add(
              CommercialNewsItem(
                id: raw['id'],
                title: raw['title'],
                summary:
                    ai['summary'] ??
                    "Noticia verificada con impacto potencial en abastecimiento o comercio en ${loc.displayName}.",
                impactAnalysis:
                    ai['impactAnalysis'] ??
                    "Puede generar demoras en los despachos mayoristas o alterar el flujo habitual de clientes.",
                actionableAdvice:
                    ai['actionableAdvice'] ??
                    "Adelanta tus pedidos clave de alta rotación y confirma con tus proveedores el estado de sus rutas.",
                category:
                    ai['category'] ??
                    (raw['scope'] == RadarNewsScope.local
                        ? 'Mi Región'
                        : 'Proveedores y Abastecimiento'),
                sourceName: raw['source'],
                sourceUrl: raw['link'],
                imageUrl: raw['imageUrl'],
                publishedAt: raw['pubDate'] is DateTime
                    ? raw['pubDate']
                    : DateTime.now(),
                region: raw['region'] ?? loc.displayName,
                isLive: true,
                scope: raw['scope'] ?? RadarNewsScope.nacional,
                scopeLabel: raw['scopeLabel'],
                isOfflineGuide: false,
              ),
            );
          }
          return _CurateResult(
            items: curated,
            mode: RadarFeedSourceMode.liveRssWithAi,
          );
        }
      }
    } catch (_) {
    } finally {
      client?.close();
    }
  }

  final localAnalyzed = _radarAnalyzeLocally(rawItems, loc);
  return _CurateResult(
    items: localAnalyzed,
    mode: RadarFeedSourceMode.liveRssLocalAnalysis,
  );
}

List<CommercialNewsItem> _radarAnalyzeLocally(
  List<Map<String, dynamic>> rawItems,
  RadarLocation loc,
) {
  return rawItems.map((raw) {
    String cat = 'Mi Región';
    final lower = raw['title'].toString().toLowerCase();

    String summary;
    String impact;
    String advice;

    if (lower.contains('clima') ||
        lower.contains('lluvia') ||
        lower.contains('carretera') ||
        lower.contains('ruta') ||
        lower.contains('senamhi') ||
        lower.contains('tránsito')) {
      cat = 'Clima y Rutas';
      summary =
          "Reporte vial y meteorológico en curso con impacto en el tránsito y transporte de carga.";
      impact =
          "Riesgo de retrasos en fletes interprovinciales por controles o condiciones de ruta en ${loc.corridor}.";
      advice =
          "Coordina despachos con 24h de holgura y valida itinerarios con tus transportistas.";
    } else if (lower.contains('sunat') ||
        lower.contains('ley') ||
        lower.contains('tribut') ||
        lower.contains('factura') ||
        lower.contains('boleta') ||
        lower.contains('indecopi')) {
      cat = 'Leyes y SUNAT';
      summary =
          "Actualización normativa o tributaria aplicable al comercio y facturación formal en Perú.";
      impact =
          "Exigencias de cumplimiento en comprobantes electrónicos y guías de remisión para transporte de mercadería.";
      advice =
          "Revisa que tus comprobantes de venta y compras cumplan con los requisitos vigentes.";
    } else if (lower.contains('proveedor') ||
        lower.contains('abastecimiento') ||
        lower.contains('precio') ||
        lower.contains('almacén') ||
        lower.contains('mercado mayorista')) {
      cat = 'Proveedores y Abastecimiento';
      summary =
          "Movimiento en mercados mayoristas o cadenas de suministro de insumos y mercadería.";
      impact =
          "Posibles variaciones en costos de adquisición o disponibilidad de productos de alta rotación.";
      advice =
          "Revisa tus existencias mínimas en Mesa de Trabajo y adelanta pedidos ante alzas.";
    } else if (lower.contains('oferta') ||
        lower.contains('campaña') ||
        lower.contains('navidad') ||
        lower.contains('madre') ||
        lower.contains('escolar') ||
        lower.contains('feriado')) {
      cat = 'Fechas y Campañas';
      summary =
          "Señal comercial clave para temporadas de alta demanda y promociones al consumidor.";
      impact =
          "Incremento esperado en la afluencia de clientes y oportunidad para elevar el ticket promedio.";
      advice =
          "Configura promociones por volumen y combos sugeridos en tu inventario.";
    } else {
      cat = raw['scope'] == RadarNewsScope.local
          ? 'Mi Región'
          : 'Proveedores y Abastecimiento';
      summary =
          "Hecho noticioso con implicancia comercial para negocios y distribuidores en ${loc.displayName}.";
      impact =
          "Variación potencial en la dinámica de compra local o en tiempos de reabastecimiento.";
      advice =
          "Supervisa tus saldos de caja y mantén comunicación fluida con proveedores clave.";
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
      publishedAt: raw['pubDate'] is DateTime
          ? raw['pubDate']
          : DateTime.now(),
      region: raw['region'] ?? loc.displayName,
      isLive: true,
      scope: raw['scope'] ?? RadarNewsScope.nacional,
      scopeLabel: raw['scopeLabel'],
      isOfflineGuide: false,
    );
  }).toList();
}

String _radarSanitizeResponse(String raw) {
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
