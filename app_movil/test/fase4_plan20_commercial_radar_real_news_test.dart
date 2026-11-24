import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_movil/features/analytics/models/commercial_radar_model.dart';
import 'package:app_movil/features/analytics/services/commercial_radar_service.dart';
import 'package:app_movil/features/analytics/services/link_health_verifier.dart';
import 'package:app_movil/features/analytics/data/peru_ubigeo_catalog.dart';
import 'package:app_movil/features/analytics/screens/commercial_radar_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CommercialRadarService.clearMemoryCache();
    CommercialRadarService.customHttpClient = null;
    CommercialRadarService.geminiCuratorMock = null;
    LinkHealthVerifier.clearCache();
  });

  tearDown(() {
    CommercialRadarService.clearMemoryCache();
    CommercialRadarService.customHttpClient = null;
    CommercialRadarService.geminiCuratorMock = null;
    LinkHealthVerifier.clearCache();
  });

  group('1. Catálogo Geográfico Oficial del Perú y Modelo RadarLocation', () {
    test('Contiene exactamente las 25 regiones oficiales y 196 provincias del Perú', () {
      final depts = PeruUbigeoCatalog.departments;
      expect(depts.length, equals(25), reason: 'Deben existir 24 departamentos + Callao');

      int totalProvincias = 0;
      for (final d in depts) {
        expect(d.name.isNotEmpty, isTrue);
        expect(d.mainCorridor.isNotEmpty, isTrue);
        expect(d.provinces.isNotEmpty, isTrue);
        totalProvincias += d.provinces.length;
      }
      expect(totalProvincias, equals(196), reason: 'El Perú cuenta con 196 provincias oficiales');
    });

    test('Búsqueda por provincia y departamento en PeruUbigeoCatalog', () {
      final deptTrujillo = PeruUbigeoCatalog.findDepartmentByProvince('Trujillo');
      expect(deptTrujillo?.name, equals('La Libertad'));

      final deptTalara = PeruUbigeoCatalog.findDepartmentByProvince('Talara');
      expect(deptTalara?.name, equals('Piura'));

      final deptCusco = PeruUbigeoCatalog.findDepartment('Cusco');
      expect(deptCusco?.provinces.any((p) => p.name == 'Cusco'), isTrue);
    });

    test('RadarLocation soporta distrito urbano y rural, labels, serialización y migración', () {
      // 1. Distrito urbano (Lima > Lima > San Juan de Lurigancho)
      const locUrbano = RadarLocation(
        department: 'Lima',
        province: 'Lima',
        district: 'San Juan de Lurigancho',
        corridor: 'Panamericana / Eje Central',
      );
      expect(locUrbano.district, equals('San Juan de Lurigancho'));
      expect(locUrbano.shortLabel, equals('San Juan de Lurigancho, Lima'));
      expect(locUrbano.displayName, equals('San Juan de Lurigancho, Lima (Lima)'));
      expect(locUrbano.isNational, isFalse);

      final jsonUrbano = locUrbano.toJson();
      final fromJsonUrbano = RadarLocation.fromJson(jsonUrbano);
      expect(fromJsonUrbano, equals(locUrbano));

      // 2. Distrito rural (Piura > Huancabamba > Sondorillo)
      const locRural = RadarLocation(
        department: 'Piura',
        province: 'Huancabamba',
        district: 'Sondorillo',
        corridor: 'Eje Andino Norte',
      );
      expect(locRural.district, equals('Sondorillo'));
      expect(locRural.shortLabel, equals('Sondorillo, Huancabamba'));
      expect(locRural.displayName, equals('Sondorillo, Huancabamba (Piura)'));

      // copyWith con clearDistrict
      final withoutDistrict = locRural.copyWith(clearDistrict: true);
      expect(withoutDistrict.district, isNull);
      expect(withoutDistrict.shortLabel, equals('Huancabamba'));

      // Migración desde legacy string con formato distrito
      final fromLegacyWithDistrict = RadarLocation.fromLegacyString('Sondorillo, Huancabamba (Piura)');
      expect(fromLegacyWithDistrict.department, equals('Piura'));
      expect(fromLegacyWithDistrict.province, equals('Huancabamba'));
      expect(fromLegacyWithDistrict.district, equals('Sondorillo'));

      // Migración legacy provincia / departamento
      final fromLegacyProv = RadarLocation.fromLegacyString('Talara / Piura');
      expect(fromLegacyProv.department, equals('Piura'));
      expect(fromLegacyProv.province, equals('Talara'));
      expect(fromLegacyProv.district, isNull);

      final fromNational = RadarLocation.fromLegacyString('Todo el Perú');
      expect(fromNational.isNational, isTrue);
    });

    test('Distritos sugeridos en PeruUbigeoCatalog para Lima, Callao, Piura y Huancabamba', () {
      final distsLima = PeruUbigeoCatalog.getSuggestedDistricts('Lima', 'Lima');
      expect(distsLima.contains('San Juan de Lurigancho'), isTrue);
      expect(distsLima.contains('Miraflores'), isTrue);

      final distsCallao = PeruUbigeoCatalog.getSuggestedDistricts('Callao', 'Callao');
      expect(distsCallao.first, equals('Ventanilla'));

      final distsHuancabamba = PeruUbigeoCatalog.getSuggestedDistricts('Piura', 'Huancabamba');
      expect(distsHuancabamba.contains('Sondorillo'), isTrue);
      expect(distsHuancabamba.contains('Huancabamba'), isTrue);
    });
  });

  group('2. Parser RSS XML en Dart puro y normalización editorial', () {
    test('Parsea titulares, links, fuentes, CDATA y entidades HTML sin dependencias externas', () {
      const mockXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Google News</title>
    <item>
      <title><![CDATA[MTC coordina reapertura de badenes en Panamericana Norte - Diario Correo]]></title>
      <link>https://news.google.com/rss/articles/CBMiRGh0dHBzOi8vZGlhcmlvY29ycmVvLnBlL2VkY2lvbi9waXVyYS9tdGMtYmFkZW5lcy1wYW5hbWVyaWNhbmEtbm9ydGUv0gEA?oc=5</link>
      <pubDate>Mon, 24 Nov 2026 14:30:00 GMT</pubDate>
      <source url="https://diariocorreo.pe">Diario Correo</source>
    </item>
    <item>
      <title>SUNAT aprueba nuevo estándar de facturación electrónica &amp; guías de remisión - El Peruano</title>
      <link>https://news.google.com/rss/articles/CBMiS2h0dHBzOi8vZWxwZXJ1YW5vLnBlL25vdGljaWEtc3VuYXQtZmFjdHVyYWNpb24tZ3VpYXMtcmVtaXNpb24v0gEA?oc=5</link>
      <pubDate>Mon, 24 Nov 2026 10:15:00 GMT</pubDate>
      <source url="https://elperuano.pe">El Peruano</source>
    </item>
  </channel>
</rss>
''';

      final items = CommercialRadarService.parseRssXml(
        mockXml,
        scope: RadarNewsScope.local,
        scopeLabel: 'Local • Piura',
        regionName: 'Piura',
      );

      expect(items.length, equals(2));

      // Item 1
      expect(items[0]['title'], equals('MTC coordina reapertura de badenes en Panamericana Norte'));
      expect(items[0]['source'], equals('Diario Correo'));
      expect(items[0]['scope'], equals(RadarNewsScope.local));
      expect(items[0]['scopeLabel'], equals('Local • Piura'));

      // Item 2
      expect(items[1]['title'], contains('facturación electrónica & guías de remisión'));
      expect(items[1]['source'], equals('El Peruano'));
    });

    test('Parsea fechas RFC 822 / 1123 correctamente', () {
      final date = CommercialRadarService.parseRssPubDate('Mon, 24 Nov 2026 14:30:00 GMT');
      expect(date.year, equals(2026));
      expect(date.month, equals(11));
      expect(date.day, equals(24));
      expect(date.hour, equals(14));
      expect(date.minute, equals(30));
    });
  });

  group('3. LinkHealthVerifier: Manejo de 200, 301, 302, 405 y Descarte de Errores', () {
    test('Valida enlaces 200 OK y redirecciones 301/302 de Google News', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString().contains('redirect301')) {
          return http.Response('', 301, headers: {'location': 'https://noticia-final.pe'});
        }
        if (request.url.toString().contains('valid200')) {
          return http.Response('OK', 200);
        }
        return http.Response('Not Found', 404);
      });

      final verifier = LinkHealthVerifier(client: mockClient);

      expect(await verifier.verifyLink('https://news.google.com/redirect301'), isTrue);
      expect(await verifier.verifyLink('https://diario.pe/valid200'), isTrue);
      expect(await verifier.verifyLink('https://diario.pe/broken404'), isFalse);
    });

    test('Fallback a GET cuando el servidor rechaza HEAD con 405 Method Not Allowed', () async {
      final mockClient = MockClient((request) async {
        if (request.method == 'HEAD') {
          return http.Response('Method Not Allowed', 405);
        }
        if (request.method == 'GET') {
          return http.Response('Contenido liviano', 200);
        }
        return http.Response('Bad Request', 400);
      });

      final verifier = LinkHealthVerifier(client: mockClient);
      final isValid = await verifier.verifyLink('https://portal-estricto.gob.pe/alerta');
      expect(isValid, isTrue, reason: 'Debe recuperarse con GET ante 405 en HEAD');
    });

    test('Descarte de errores fatales de red y resolución de working URL hacia gob.pe', () async {
      final mockClient = MockClient((request) async {
        if (request.url.toString().contains('emergenciasviales') || request.url.toString().contains('nxdomain')) {
          throw Exception('Failed host lookup: emergenciasviales.proviasnac.gob.pe');
        }
        return http.Response('OK', 200);
      });

      final verifier = LinkHealthVerifier(client: mockClient);
      const brokenUrl = 'https://emergenciasviales.proviasnac.gob.pe/alerta';
      const fallbackUrl = 'https://www.gob.pe/sutran';

      final resolved = await verifier.resolveWorkingUrl(brokenUrl, fallbackUrl: fallbackUrl);
      expect(resolved, equals(fallbackUrl));
    });
  });

  group('4. Erradicación Total de URLs Rotas y 100% Rutas Canónicas gob.pe en Modo Offline', () {
    test('100% de señales offline utilizan rutas canónicas de https://www.gob.pe/...', () {
      final fallbackList = CommercialRadarService.getOfflineFallbackSignals();
      expect(fallbackList.isNotEmpty, isTrue);

      for (final item in fallbackList) {
        expect(
          item.sourceUrl.startsWith('https://www.gob.pe/'),
          isTrue,
          reason: 'La señal ${item.title} debe usar ruta canónica https://www.gob.pe/..., URL: ${item.sourceUrl}',
        );
        expect(item.sourceUrl.contains('emergenciasviales.proviasnac.gob.pe'), isFalse);
        expect(item.sourceUrl.contains('gis.sutran.gob.pe'), isFalse);
        expect(item.sourceUrl.contains('cpe.sunat.gob.pe'), isFalse);
        expect(item.sourceUrl.contains('sistemas.midagri.gob.pe'), isFalse);
        expect(item.isOfflineGuide, isTrue);
        expect(item.isLive, isFalse);
        expect(item.displayDateOrBadge, equals('Guía Permanente'));
      }
    });

    test('sanitizeAndUpgradeNewsItem reemplaza dominios rotos por portal canónico de SUTRAN / Provías', () {
      final oldItem = CommercialNewsItem(
        id: 'legacy_broken_item',
        title: 'Reporte vial antiguo',
        summary: 'Resumen',
        actionableAdvice: 'Recomendación',
        category: 'Clima y Rutas',
        sourceName: 'Provías Nacional',
        sourceUrl: 'https://emergenciasviales.proviasnac.gob.pe/976451.aspx',
        publishedAt: DateTime.now(),
        region: 'Trujillo',
      );

      final upgraded = CommercialRadarService.sanitizeAndUpgradeNewsItem(oldItem);
      expect(upgraded.sourceUrl, equals('https://www.gob.pe/sutran'));
      expect(upgraded.sourceName, equals('Provías Nacional / SUTRAN'));
    });
  });

  group('5. Cascada Territorial y Analizador de Noticias Reales', () {
    test('Cascada emite noticias con scope Local, Regional y Nacional', () async {
      final mockClient = MockClient((request) async {
        final query = request.url.query;
        String title = 'Noticia Nacional de Abastecimiento';
        if (query.contains('Trujillo')) {
          title = 'Muelle de Salaverry en Trujillo reporta dinamismo comercial';
        } else if (query.contains('La Libertad')) {
          title = 'Rutas de La Libertad mantienen tránsito fluido';
        }

        final xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <item>
      <title>$title - RPP Noticias</title>
      <link>https://rpp.pe/noticia-comercial-test</link>
      <pubDate>Mon, 24 Nov 2026 12:00:00 GMT</pubDate>
      <source url="https://rpp.pe">RPP Noticias</source>
    </item>
  </channel>
</rss>''';
        return http.Response(xml, 200);
      });

      CommercialRadarService.customHttpClient = mockClient;

      const loc = RadarLocation(
        department: 'La Libertad',
        province: 'Trujillo',
        corridor: 'Panamericana Norte',
      );

      final stream = CommercialRadarService.streamCuratedNews(location: loc, forceRefresh: true);
      final emitted = await stream.toList();

      expect(emitted.isNotEmpty, isTrue);
      expect(
        CommercialRadarService.lastSourceMode == RadarFeedSourceMode.liveRssLocalAnalysis ||
            CommercialRadarService.lastSourceMode == RadarFeedSourceMode.liveRssWithAi,
        isTrue,
      );

      final scopes = emitted.map((e) => e.scope).toSet();
      expect(scopes.contains(RadarNewsScope.local) || scopes.contains(RadarNewsScope.regional), isTrue);
    });

    test('Cascada territorial prioriza distrito local y etiqueta con Local • <Distrito>', () async {
      final interceptedQueries = <String>[];
      final mockClient = MockClient((request) async {
        interceptedQueries.add(request.url.query);
        final query = request.url.query;
        String title = 'Noticia Regional Piura';
        if (query.contains('Sondorillo')) {
          title = 'Comuneros de Sondorillo en Huancabamba rehabilitan vía vecinal';
        }

        final xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <item>
      <title>$title - El Tiempo Piura</title>
      <link>https://eltiempo.pe/noticia-sondorillo</link>
      <pubDate>Mon, 24 Nov 2026 15:00:00 GMT</pubDate>
      <source url="https://eltiempo.pe">El Tiempo</source>
    </item>
  </channel>
</rss>''';
        return http.Response(xml, 200);
      });

      CommercialRadarService.customHttpClient = mockClient;

      const loc = RadarLocation(
        department: 'Piura',
        province: 'Huancabamba',
        district: 'Sondorillo',
        corridor: 'Eje Andino Norte',
      );

      final stream = CommercialRadarService.streamCuratedNews(location: loc, forceRefresh: true);
      final emitted = await stream.toList();

      expect(emitted.isNotEmpty, isTrue);
      final sondorilloItem = emitted.firstWhere((e) => e.title.contains('Sondorillo'));
      expect(sondorilloItem.scopeLabel, equals('Local • Sondorillo'));
      expect(interceptedQueries.any((q) => q.contains('Sondorillo') && q.contains('Huancabamba')), isTrue);
    });

    test('Fallback determinista local asigna impacto y categoría ante ausencia de Gemini', () async {
      final mockClient = MockClient((request) async {
        const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <item>
      <title>Lluvias y vientos en carretera causan demoras preventivas - SENAMHI</title>
      <link>https://www.gob.pe/senamhi/aviso-test</link>
      <pubDate>Mon, 24 Nov 2026 12:00:00 GMT</pubDate>
      <source url="https://www.gob.pe/senamhi">SENAMHI Alertas</source>
    </item>
  </channel>
</rss>''';
        return http.Response(xml, 200);
      });

      CommercialRadarService.customHttpClient = mockClient;

      final stream = CommercialRadarService.streamCuratedNews(
        location: RadarLocation.defaultLocation,
        forceRefresh: true,
      );
      final emitted = await stream.toList();

      expect(emitted.isNotEmpty, isTrue);
      final item = emitted.firstWhere((e) => e.title.contains('Lluvias y vientos'));
      expect(item.category, equals('Clima y Rutas'));
      expect(item.impactAnalysis.isNotEmpty, isTrue);
      expect(item.actionableAdvice.isNotEmpty, isTrue);
    });
  });

  group('6. Pruebas de Widget en CommercialRadarScreen y 0px Overflow', () {
    Widget buildTestScreen({TextScaler textScaler = TextScaler.noScaling, Size size = const Size(360, 640)}) {
      return MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: size, textScaler: textScaler),
          child: const CommercialRadarScreen(initialRegion: 'Trujillo'),
        ),
      );
    }

    testWidgets('Header muestra indicador dinámico y ubicación seleccionada', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      await tester.pumpWidget(buildTestScreen());
      await tester.pump();

      // Selector de ubicación en AppBar o header
      expect(find.textContaining('Trujillo'), findsWidgets);

      // Indicador dinámico de estado (sin el texto fijo "IA EN VIVO")
      expect(find.text('Monitoreo Logístico y Comercial'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is Icon && w.icon == Icons.radar_rounded && w.size == 24),
        findsOneWidget,
      );
    });

    testWidgets('Selector geográfico abre modal interactivo y permite búsqueda', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      await tester.pumpWidget(buildTestScreen());
      await tester.pump();

      // Abrir selector de región
      final locationButton = find.byWidgetPredicate(
        (w) => w is InkWell && w.child is Container && find.descendant(of: find.byWidget(w), matching: find.byIcon(Icons.location_on)).evaluate().isNotEmpty,
      );
      if (locationButton.evaluate().isNotEmpty) {
        await tester.tap(locationButton.first);
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Enfoque Geográfico del Radar'), findsOneWidget);
        expect(find.byType(TextField), findsWidgets);
      }
    });

    testWidgets('Selector interactivo de 3 niveles: navegación Piura > Huancabamba > Sondorillo y botones', (tester) async {
      RadarLocation? selectedOutput;

      await tester.binding.setSurfaceSize(const Size(412, 915));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: ctx,
                    isScrollControlled: true,
                    builder: (sheetCtx) => LocationPickerSheet(
                      isDark: true,
                      sheetBg: const Color(0xFF1E293B),
                      currentLocation: const RadarLocation(
                        department: 'Lima',
                        province: 'Lima',
                        corridor: 'Panamericana / Eje Central',
                      ),
                      onLocationSelected: (loc) {
                        selectedOutput = loc;
                        Navigator.pop(sheetCtx);
                      },
                    ),
                  );
                },
                child: const Text('Abrir Selector'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // 1. Abrir modal
      await tester.tap(find.text('Abrir Selector'));
      await tester.pumpAndSettle();

      expect(find.text('Enfoque Geográfico del Radar'), findsOneWidget);

      // 2. Filtrar por Huancabamba
      await tester.enterText(find.byType(TextField).first, 'Huancabamba');
      await tester.pumpAndSettle();

      // 3. Tocar la provincia Huancabamba en la lista
      final huancabambaTile = find.widgetWithText(ListTile, 'Huancabamba');
      expect(huancabambaTile, findsOneWidget);
      await tester.tap(huancabambaTile);
      await tester.pumpAndSettle();

      // 4. Verificar Paso 3 y chip de Sondorillo
      expect(find.textContaining('Paso 3 de 3'), findsOneWidget);
      expect(find.text('Sondorillo'), findsOneWidget);

      // 5. Tocar chip Sondorillo
      await tester.tap(find.text('Sondorillo'));
      await tester.pumpAndSettle();

      // 6. Tocar botón Aplicar con Distrito/Localidad (asegurando visibilidad en scroll)
      final applyBtn = find.byKey(const ValueKey('btn_apply_district'));
      expect(applyBtn, findsOneWidget);
      await tester.ensureVisible(applyBtn);
      await tester.tap(applyBtn);
      await tester.pumpAndSettle();

      // 7. Validar emisión con Sondorillo
      expect(selectedOutput, isNotNull);
      expect(selectedOutput!.department, equals('Piura'));
      expect(selectedOutput!.province, equals('Huancabamba'));
      expect(selectedOutput!.district, equals('Sondorillo'));

      // 8. Reabrir para probar botón 'Usar toda la provincia'
      await tester.tap(find.text('Abrir Selector'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Huancabamba');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Huancabamba'));
      await tester.pumpAndSettle();

      final wholeProvBtn = find.byKey(const ValueKey('btn_use_province'));
      expect(wholeProvBtn, findsOneWidget);
      await tester.ensureVisible(wholeProvBtn);
      await tester.tap(wholeProvBtn);
      await tester.pumpAndSettle();

      expect(selectedOutput!.district, isNull);
      expect(selectedOutput!.province, equals('Huancabamba'));
      expect(selectedOutput!.department, equals('Piura'));
    });

    testWidgets('0px Overflow a escala 1.3x en viewports 320x568, 360x640 y 412x915', (tester) async {
      final viewports = [
        const Size(320, 568),
        const Size(360, 640),
        const Size(412, 915),
      ];

      for (final vp in viewports) {
        await tester.binding.setSurfaceSize(vp);
        await tester.pumpWidget(
          buildTestScreen(
            size: vp,
            textScaler: const TextScaler.linear(1.3),
          ),
        );
        await tester.pump();

        expect(tester.takeException(), isNull, reason: 'No debe haber overflow en $vp con escala 1.3x');
      }
    });

    testWidgets('0px Overflow en selector de 3 niveles a escala 1.3x en viewports reducidos', (tester) async {
      final viewports = [
        const Size(320, 568),
        const Size(360, 640),
        const Size(412, 915),
      ];

      final deptPiura = PeruUbigeoCatalog.findDepartment('Piura')!;
      final provHuancabamba = deptPiura.provinces.firstWhere((p) => p.name == 'Huancabamba');

      for (final vp in viewports) {
        await tester.binding.setSurfaceSize(vp);
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(size: vp, textScaler: const TextScaler.linear(1.3)),
              child: Scaffold(
                body: LocationPickerSheet(
                  isDark: true,
                  sheetBg: const Color(0xFF1E293B),
                  initialStagedDepartment: deptPiura,
                  initialStagedProvince: provHuancabamba,
                  currentLocation: const RadarLocation(
                    department: 'Piura',
                    province: 'Huancabamba',
                    district: 'Sondorillo',
                    corridor: 'Eje Andino Norte',
                  ),
                  onLocationSelected: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('Paso 3 de 3'), findsOneWidget);
        expect(find.text('Sondorillo'), findsWidgets);
        expect(tester.takeException(), isNull, reason: 'No debe haber overflow en $vp con escala 1.3x en Paso 3');
      }
    });
  });
}
