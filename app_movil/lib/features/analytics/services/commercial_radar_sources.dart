part of 'commercial_radar_service.dart';

/// Consulta RSS de Google News Perú con cascada territorial y filtro anti-ruido
Future<List<Map<String, dynamic>>> _radarFetchGoogleNewsRssCascade(
  RadarLocation loc,
) async {
  final client = CommercialRadarService.customHttpClient ?? http.Client();
  final bool isOwnedClient = CommercialRadarService.customHttpClient == null;
  final List<Map<String, dynamic>> collectedItems = [];

  const antiNoise =
      ' NOT (fútbol OR soccer OR partido OR liga OR torneo OR gol OR club OR farándula OR espectáculo OR cantante OR concierto)';

  try {
    if (loc.isNational) {
      final qNacional =
          '(Perú AND (comercio OR "mercado mayorista" OR fletes OR transporte OR abastecimiento OR SUNAT OR INDECOPI OR carreteras OR SENAMHI))$antiNoise';
      final itemsNacional = await _radarFetchRssQuery(
        client,
        qNacional,
        scope: RadarNewsScope.nacional,
        scopeLabel: 'Nacional • Perú',
        regionName: 'Perú',
        limit: 12,
      );
      collectedItems.addAll(itemsNacional);
    } else {
      List<Map<String, dynamic>> itemsLocal = [];

      if (loc.district != null && loc.district!.isNotEmpty) {
        final qDistrict =
            '("${loc.district}" "${loc.province}" AND (comercio OR transporte OR carreteras OR fletes OR abastecimiento OR lluvias OR SENAMHI))$antiNoise';
        final districtItems = await _radarFetchRssQuery(
          client,
          qDistrict,
          scope: RadarNewsScope.local,
          scopeLabel: 'Local • ${loc.district}',
          regionName: loc.district!,
          limit: 4,
        );
        itemsLocal.addAll(districtItems);
      }

      if (itemsLocal.length < 2) {
        final qProv =
            '("${loc.province}" AND (comercio OR transporte OR carreteras OR fletes OR abastecimiento OR lluvias OR SENAMHI))$antiNoise';
        final provItems = await _radarFetchRssQuery(
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

      final qRegional =
          '("${loc.department}" AND (rutas OR carreteras OR comercio OR transporte OR abastecimiento OR fletes OR "${loc.corridor}" OR SENAMHI))$antiNoise';
      final itemsRegional = await _radarFetchRssQuery(
        client,
        qRegional,
        scope: RadarNewsScope.regional,
        scopeLabel: 'Regional • ${loc.department}',
        regionName: loc.department,
        limit: 4,
      );
      collectedItems.addAll(itemsRegional);

      final qNacional =
          '(Perú AND (SUNAT OR abastecimiento OR fletes OR "mercado mayorista" OR INDECOPI OR "campaña comercial"))$antiNoise';
      final itemsNacional = await _radarFetchRssQuery(
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

Future<List<Map<String, dynamic>>> _radarFetchRssQuery(
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
    final response = await client
        .get(url, headers: {'User-Agent': LinkHealthVerifier.userAgent})
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) return [];

    return _radarParseRssXml(
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

List<Map<String, dynamic>> _radarParseRssXml(
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
  final pubDateRegex = RegExp(
    r'<pubDate>([\s\S]*?)<\/pubDate>',
    caseSensitive: false,
  );
  final sourceRegex = RegExp(
    r'<source[^>]*>([\s\S]*?)<\/source>',
    caseSensitive: false,
  );
  final imgRegex = RegExp(r'<img[^>]+src="([^">]+)"', caseSensitive: false);

  for (var match in itemRegex.allMatches(xml)) {
    if (items.length >= limit) break;
    final content = match.group(1) ?? '';

    String rawTitle = _radarCleanCdataAndEntities(
      titleRegex.firstMatch(content)?.group(1) ?? '',
    );
    String rawLink = _radarCleanCdataAndEntities(
      linkRegex.firstMatch(content)?.group(1) ?? '',
    );
    String rawPubDate = _radarCleanCdataAndEntities(
      pubDateRegex.firstMatch(content)?.group(1) ?? '',
    );
    String rawSource = _radarCleanCdataAndEntities(
      sourceRegex.firstMatch(content)?.group(1) ?? 'Prensa Nacional',
    );
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

      final verifiedSource = _radarCleanEditorialSource(rawSource, title);
      final parsedDate = _radarParseRssPubDate(rawPubDate);

      items.add({
        'id':
            'rss_${scope.code}_${items.length}_${DateTime.now().millisecondsSinceEpoch}',
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

String _radarCleanEditorialSource(String rawSource, String title) {
  String s = rawSource.trim();
  if (s.toLowerCase() == 'facebook' || s.startsWith('http') || s.isEmpty) {
    final tLower = title.toLowerCase();
    if (tLower.contains('tiempo piura') || tLower.contains('el tiempo')) {
      return 'El Tiempo Piura';
    }
    if (tLower.contains('rpp')) return 'RPP Noticias';
    if (tLower.contains('gestión') || tLower.contains('gestion')) {
      return 'Gestión';
    }
    if (tLower.contains('andina')) return 'Andina Noticias';
    if (tLower.contains('correo')) return 'Diario Correo';
    if (tLower.contains('república') || tLower.contains('republica')) {
      return 'La República';
    }
    if (tLower.contains('comercio')) return 'El Comercio';
    if (tLower.contains('senamhi')) return 'SENAMHI Alertas';
    if (tLower.contains('sunat')) return 'SUNAT Prensa';
    if (tLower.contains('peruano')) return 'El Peruano';
    return 'Prensa Regional';
  }
  return s;
}

DateTime _radarParseRssPubDate(String rawDate) {
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

String _radarCleanCdataAndEntities(String text) {
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

Future<List<Map<String, dynamic>>> _radarVerifyRssLinks(
  List<Map<String, dynamic>> items,
) async {
  final List<Map<String, dynamic>> verified = [];
  final verifier = CommercialRadarService._linkVerifier;

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

List<CommercialNewsItem> _radarGetOfflineFallbackSignals({
  String region = 'Talara / Piura',
}) {
  return _radarGetOfflineFallback(RadarLocation.fromLegacyString(region));
}

List<CommercialNewsItem> _radarGetOfflineFallback(RadarLocation loc) {
  final bool isNorth = loc.department.toLowerCase().contains('piura') ||
      loc.department.toLowerCase().contains('tumbes') ||
      loc.department.toLowerCase().contains('lambayeque');
  final staticRefDate = DateTime(2026, 1, 1);

  return [
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
      title:
          "SENAMHI emite aviso meteorológico sobre variaciones térmicas y vientos en la costa",
      summary:
          "Incremento de vientos y bancos de niebla matutina afecta visibilidad en carreteras interprovinciales.",
      impactAnalysis:
          "Reducción de velocidad en fletes nocturnos y mayor consumo de combustible en transporte de mercancías.",
      actionableAdvice:
          "Solicita a transportistas confirmación de itinerarios de llegada antes de pactar entregas con clientes finales.",
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
      title:
          "SUTRAN: Reporte de puntos de control vial y mapa interactivo para transportistas",
      summary:
          "Monitoreo en tiempo real de incidentes viales y desvíos programados en la red nacional.",
      impactAnalysis:
          "Tramos con mantenimiento preventivo pueden sumar entre 1 y 3 horas a los fletes entre departamentos.",
      actionableAdvice:
          "Verifica el mapa de alertas viales antes de despachar pedidos de alto valor o productos perecibles.",
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
      title:
          "Provías Nacional: Mantenimiento vial rutinario en puentes y badenes interregionales",
      summary:
          "Cuadrillas técnicas ejecutan conservación de carpeta asfáltica en los principales corredores del país.",
      impactAnalysis:
          "Paso alternado por un solo carril en zonas de obras durante horas diurnas.",
      actionableAdvice:
          "Programa traslados de mercadería en horarios de menor congestión para evitar demoras innecesarias.",
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
    CommercialNewsItem(
      id: 'fallback_ls_1',
      title:
          "SUNAT: Obligatoriedad de Guías de Remisión Electrónicas (GRE) para traslado de bienes",
      summary:
          "Transportistas y remitentes deben emitir GRE Remitente y Transportista de forma digital con código QR.",
      impactAnalysis:
          "Multas e incautación preventiva de mercadería en garitas si no se cuenta con la GRE validada.",
      actionableAdvice:
          "Verifica que tus facturas de compra cuenten con su GRE respectiva antes de autorizar la carga al camión.",
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
      title:
          "SUNAT: Cronograma de vencimientos mensuales para declaraciones de IGV y Renta",
      summary:
          "Fechas límite escalonadas según el último dígito del RUC para evitar multas por declaración tardía.",
      impactAnalysis:
          "El retraso en la declaración genera intereses moratorios y pérdida de beneficios de buen contribuyente.",
      actionableAdvice:
          "Organiza tus comprobantes de venta y compras con tu contador 5 días antes de tu fecha límite.",
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
      title:
          "INDECOPI: Derechos del consumidor y fiscalización de precios visibles en mostradores",
      summary:
          "Comercios minoristas deben exhibir precios finales en moneda nacional incluyendo todos los tributos.",
      impactAnalysis:
          "Sanciones administrativas y clausuras temporales ante denuncias de cobros no informados o redondeos indebidos.",
      actionableAdvice:
          "Revisa que todos tus productos en estantería tengan etiquetas de precio claras y coincidan con tu sistema.",
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
    CommercialNewsItem(
      id: 'fallback_pa_1',
      title:
          "MIDAGRI: Reporte de abastecimiento y precios mayoristas en mercados de abasto",
      summary:
          "Ingreso regular de hortalizas, legumbres, tubérculos y frutas a los centros de distribución mayorista.",
      impactAnalysis:
          "Estabilidad en precios base de alimentos permite proyectar márgenes sin sobresaltos para la semana.",
      actionableAdvice:
          "Consulta el boletín de precios mayoristas antes de negociar pedidos semanales con tus distribuidores.",
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
      title:
          "PRODUCE Tu Empresa: Programas de articulación comercial y digitalización para mypes",
      summary:
          "Iniciativas para conectar pequeños negocios con cadenas productivas y capacitación en gestión comercial.",
      impactAnalysis:
          "Acceso a ferias de proveedores formales y líneas de financiamiento respaldadas por el Estado.",
      actionableAdvice:
          "Aprovecha los talleres virtuales gratuitos de PRODUCE para capacitar a tu personal en ventas y cobros.",
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
    CommercialNewsItem(
      id: 'fallback_mr_1',
      title: loc.district != null
          ? "Actividad Comercial y Flujo de Clientes en ${loc.district} (${loc.province}, ${loc.department})"
          : "Actividad Comercial y Flujo de Clientes en ${loc.province} (${loc.department})",
      summary:
          "Comercios locales reportan dinamismo continuo y preferencia creciente por pagos digitales con QR.",
      impactAnalysis:
          "Más del 65% de los clientes en zonas urbanas prefieren cancelar mediante billeteras electrónicas.",
      actionableAdvice:
          "Mantén visible tu código QR de Yape y Plin en el mostrador para evitar pérdidas de venta rápida.",
      category: 'Mi Región',
      sourceName: 'PRODUCE Tu Empresa',
      sourceUrl: 'https://www.gob.pe/tuempresa',
      publishedAt: staticRefDate,
      region: loc.displayName,
      isLive: false,
      isOfflineGuide: true,
      scope: RadarNewsScope.local,
      scopeLabel: loc.district != null
          ? 'Local • ${loc.district}'
          : 'Local • ${loc.province}',
    ),
    CommercialNewsItem(
      id: 'fallback_mr_2',
      title:
          "Corredor Logístico ${loc.corridor}: Transitabilidad y transporte de abarrotes",
      summary:
          "Flujo sostenido de unidades de distribución de mercancías y paquetería hacia los distritos comerciales.",
      impactAnalysis:
          "Tiempos regulares de arribo de camiones mayoristas aseguran stock continuo en almacenes.",
      actionableAdvice:
          "Programa recepción de mercadería en horas matutinas para verificar cantidades antes de la apertura.",
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
    CommercialNewsItem(
      id: 'fallback_fc_1',
      title:
          "Campañas Comerciales del Año: Planificación de surtido para temporadas de alta rotación",
      summary:
          "Fechas clave del calendario peruano dinamizan el consumo familiar y la venta de artículos escolares y festivos.",
      impactAnalysis:
          "Los comercios que adelantan su abastecimiento capturan las primeras compras con márgenes superiores.",
      actionableAdvice:
          "Organiza tus pedidos con 30 días de anticipación y arma combos temáticos atractivos.",
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
