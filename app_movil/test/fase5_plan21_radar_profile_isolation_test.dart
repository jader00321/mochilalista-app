import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/features/analytics/data/peru_ubigeo_catalog.dart';
import 'package:app_movil/features/analytics/models/commercial_radar_model.dart';
import 'package:app_movil/features/analytics/screens/commercial_radar_screen.dart';
import 'package:app_movil/features/analytics/services/commercial_radar_service.dart';
import 'package:app_movil/features/analytics/services/link_health_verifier.dart';
import 'package:app_movil/features/analytics/widgets/dashboard/commercial_radar_card.dart';

class _RadarMockAuthProvider extends ChangeNotifier implements AuthProvider {
  int? _activeUserId;

  _RadarMockAuthProvider(this._activeUserId);

  @override
  int? get activeUserId => _activeUserId;

  void switchProfile(int? nextProfileId) {
    _activeUserId = nextProfileId;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CommercialNewsItem _buildSampleNews({
  required String id,
  required String title,
  String region = 'Piura',
}) {
  return CommercialNewsItem(
    id: id,
    title: title,
    summary: 'Resumen de prueba para $title.',
    impactAnalysis: 'Impacto operativo controlado.',
    actionableAdvice: 'Mantener monitoreo local.',
    category: 'Mi Región',
    sourceName: 'PRODUCE Tu Empresa',
    sourceUrl: 'https://www.gob.pe/tuempresa',
    publishedAt: DateTime(2026, 3, 1, 9, 0),
    region: region,
    isLive: false,
    isOfflineGuide: true,
    scope: RadarNewsScope.local,
    scopeLabel: 'Local • $region',
  );
}

Future<void> _pumpAsyncFrames(WidgetTester tester) async {
  for (int i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CommercialRadarService.clearMemoryCache();
    // Evitar cualquier intento real de tráfico de red durante widget/unit tests
    CommercialRadarService.customHttpClient = MockClient(
      (_) async => throw const SocketException('Offline en entorno de prueba'),
    );
    CommercialRadarService.geminiCuratorMock = null;
    LinkHealthVerifier.clearCache();
  });

  tearDown(() {
    CommercialRadarService.clearMemoryCache();
    CommercialRadarService.customHttpClient = null;
    CommercialRadarService.geminiCuratorMock = null;
    LinkHealthVerifier.clearCache();
  });

  group('Plan 21 - Pilar 3: Aislamiento de Radar Comercial por profile_id', () {
    test('Ubicación independiente por profileId (sin contaminación cruzada)', () async {
      const locP1 = RadarLocation(
        department: 'Piura',
        province: 'Piura',
        district: 'Castilla',
        corridor: 'Panamericana Norte',
      );
      const locP2 = RadarLocation(
        department: 'Lima',
        province: 'Lima',
        district: 'Miraflores',
        corridor: 'Eje Central',
      );

      await CommercialRadarService.saveLocationForProfile(locP1, profileId: 1);
      await CommercialRadarService.saveLocationForProfile(locP2, profileId: 2);

      final loadedP1 = await CommercialRadarService.loadLocationForProfile(
        profileId: 1,
        fallback: RadarLocation.defaultLocation,
      );
      final loadedP2 = await CommercialRadarService.loadLocationForProfile(
        profileId: 2,
        fallback: RadarLocation.defaultLocation,
      );
      final loadedP3 = await CommercialRadarService.loadLocationForProfile(
        profileId: 3,
        fallback: RadarLocation.defaultLocation,
      );

      expect(loadedP1, equals(locP1));
      expect(loadedP2, equals(locP2));
      expect(loadedP3, equals(RadarLocation.defaultLocation));

      // Sincronización equivalente desde CommercialRadarCard (etiquetas de región)
      await CommercialRadarService.saveRegionLabelForProfile('Cusco', profileId: 10);
      await CommercialRadarService.saveRegionLabelForProfile('Arequipa', profileId: 20);

      expect(
        await CommercialRadarService.loadRegionLabelForProfile(
          profileId: 10,
          defaultRegion: 'Talara / Piura',
        ),
        equals('Cusco'),
      );
      expect(
        await CommercialRadarService.loadRegionLabelForProfile(
          profileId: 20,
          defaultRegion: 'Talara / Piura',
        ),
        equals('Arequipa'),
      );
      expect(
        await CommercialRadarService.loadRegionLabelForProfile(
          profileId: 30,
          defaultRegion: 'Talara / Piura',
        ),
        equals('Talara / Piura'),
      );
    });

    test('Migración única heredada (commercial_radar_legacy_migrated_v21) y cohorte limpia para nuevos perfiles', () async {
      const legacyLoc = RadarLocation(
        department: 'Arequipa',
        province: 'Arequipa',
        district: 'Yanahuara',
        corridor: 'Corredor Sur',
      );
      final legacyBookmark = _buildSampleNews(
        id: 'legacy_bm_1',
        title: 'Alerta heredada Arequipa',
        region: 'Yanahuara, Arequipa (Arequipa)',
      );

      SharedPreferences.setMockInitialValues({
        CommercialRadarService.legacyLocationJsonPrefKey: jsonEncode(legacyLoc.toJson()),
        CommercialRadarService.legacyRegionPrefKey: legacyLoc.displayName,
        CommercialRadarService.legacySavedNewsPrefKey: jsonEncode([legacyBookmark.toJson()]),
      });

      // Primer perfil activo absorbe la preferencia y noticias heredadas
      final p1Loc = await CommercialRadarService.loadLocationForProfile(
        profileId: 1,
        fallback: RadarLocation.defaultLocation,
      );
      final p1Saved = await CommercialRadarService.getSavedNews(profileId: 1);

      expect(p1Loc, equals(legacyLoc));
      expect(p1Saved.length, equals(1));
      expect(p1Saved.first.id, equals('legacy_bm_1'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(CommercialRadarService.legacyMigratedPrefKey), isTrue);

      // Perfil 2 inicia con ubicación limpia por defecto y 0 noticias heredadas
      final p2Loc = await CommercialRadarService.loadLocationForProfile(
        profileId: 2,
        fallback: RadarLocation.defaultLocation,
      );
      final p2Saved = await CommercialRadarService.getSavedNews(profileId: 2);

      expect(p2Loc, equals(RadarLocation.defaultLocation));
      expect(p2Saved, isEmpty);
    });

    test('Claves de caché diferenciadas por distrito (Castilla vs Catacaos en Piura)', () async {
      const locCastilla = RadarLocation(
        department: 'Piura',
        province: 'Piura',
        district: 'Castilla',
        corridor: 'Panamericana Norte',
      );
      const locCatacaos = RadarLocation(
        department: 'Piura',
        province: 'Piura',
        district: 'Catacaos',
        corridor: 'Panamericana Norte',
      );
      const locProv = RadarLocation(
        department: 'Piura',
        province: 'Piura',
        district: null,
        corridor: 'Panamericana Norte',
      );

      expect(
        CommercialRadarService.buildCacheKey(locCastilla),
        equals('Piura_Piura_Castilla'),
      );
      expect(
        CommercialRadarService.buildCacheKey(locCatacaos),
        equals('Piura_Piura_Catacaos'),
      );
      expect(
        CommercialRadarService.buildCacheKey(locProv),
        equals('Piura_Piura_'),
      );

      final itemsCastilla = await CommercialRadarService.streamCuratedNews(
        location: locCastilla,
      ).toList();
      final itemsCatacaos = await CommercialRadarService.streamCuratedNews(
        location: locCatacaos,
      ).toList();

      expect(
        itemsCastilla.any((i) => i.title.contains('Castilla')),
        isTrue,
      );
      expect(
        itemsCatacaos.any((i) => i.title.contains('Catacaos')),
        isTrue,
      );
      expect(
        CommercialRadarService.getCachedNewsForLocation(locCastilla)!
            .any((i) => i.title.contains('Castilla')),
        isTrue,
      );
      expect(
        CommercialRadarService.getCachedNewsForLocation(locCatacaos)!
            .any((i) => i.title.contains('Catacaos')),
        isTrue,
      );
    });

    test('Noticias guardadas aisladas por profileId en save/remove/isNewsSaved', () async {
      final newsA = _buildSampleNews(id: 'n_101', title: 'Noticia Perfil 10');
      final newsB = _buildSampleNews(id: 'n_202', title: 'Noticia Perfil 20');

      await CommercialRadarService.saveNewsItem(newsA, profileId: 10);
      await CommercialRadarService.saveNewsItem(newsB, profileId: 20);

      expect(await CommercialRadarService.isNewsSaved('n_101', profileId: 10), isTrue);
      expect(await CommercialRadarService.isNewsSaved('n_101', profileId: 20), isFalse);
      expect(await CommercialRadarService.isNewsSaved('n_202', profileId: 20), isTrue);
      expect(await CommercialRadarService.isNewsSaved('n_202', profileId: 10), isFalse);

      await CommercialRadarService.removeSavedNews('n_101', profileId: 10);
      expect(await CommercialRadarService.getSavedNews(profileId: 10), isEmpty);
      expect((await CommercialRadarService.getSavedNews(profileId: 20)).length, equals(1));
    });

    testWidgets('CommercialRadarScreen reacciona en vivo al cambiar AuthProvider.activeUserId', (
      WidgetTester tester,
    ) async {
      const locP1 = RadarLocation(
        department: 'Piura',
        province: 'Piura',
        district: 'Catacaos',
        corridor: 'Panamericana Norte',
      );
      const locP2 = RadarLocation(
        department: 'Lima',
        province: 'Lima',
        district: 'Miraflores',
        corridor: 'Eje Central',
      );
      final bmP1 = _buildSampleNews(id: 'bm_p1', title: 'Noticia Guardada P1');

      SharedPreferences.setMockInitialValues({
        CommercialRadarService.legacyMigratedPrefKey: true,
        CommercialRadarService.locationJsonPrefKey(1): jsonEncode(locP1.toJson()),
        CommercialRadarService.regionPrefKey(1): locP1.displayName,
        CommercialRadarService.savedNewsPrefKey(1): jsonEncode([bmP1.toJson()]),
        CommercialRadarService.locationJsonPrefKey(2): jsonEncode(locP2.toJson()),
        CommercialRadarService.regionPrefKey(2): locP2.displayName,
      });

      final mockAuth = _RadarMockAuthProvider(1);

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: mockAuth,
          child: const MaterialApp(
            home: CommercialRadarScreen(autoTriggerTour: false),
          ),
        ),
      );
      await _pumpAsyncFrames(tester);

      expect(find.textContaining('Catacaos, Piura (Piura)'), findsAtLeastNWidgets(1));
      expect(find.text('Guardadas (1)'), findsOneWidget);

      // Cambiar de negocio activo en caliente -> Perfil 2
      mockAuth.switchProfile(2);
      await _pumpAsyncFrames(tester);

      expect(find.textContaining('Miraflores, Lima (Lima)'), findsAtLeastNWidgets(1));
      expect(find.text('Guardadas (0)'), findsOneWidget);
      expect(find.textContaining('Catacaos, Piura (Piura)'), findsNothing);
    });

    testWidgets('CommercialRadarCard reacciona en vivo al cambiar AuthProvider.activeUserId', (
      WidgetTester tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        CommercialRadarService.legacyMigratedPrefKey: true,
        CommercialRadarService.regionPrefKey(1): 'Cusco',
        CommercialRadarService.regionPrefKey(2): 'Lima',
      });

      final mockAuth = _RadarMockAuthProvider(1);

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthProvider>.value(
          value: mockAuth,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: CommercialRadarCard(isDark: true),
              ),
            ),
          ),
        ),
      );
      await _pumpAsyncFrames(tester);

      expect(find.text('Cusco'), findsAtLeastNWidgets(1));

      mockAuth.switchProfile(2);
      await _pumpAsyncFrames(tester);

      expect(find.text('Lima'), findsAtLeastNWidgets(1));
      expect(find.text('Cusco'), findsNothing);
    });

    testWidgets('Cero overflow en CommercialRadarScreen y CommercialRadarCard a 1.3x (320/360/412dp)', (
      WidgetTester tester,
    ) async {
      const longLoc = RadarLocation(
        department: 'Lima',
        province: 'Lima',
        district: 'San Juan de Lurigancho',
        corridor: 'Panamericana / Eje Central',
      );
      SharedPreferences.setMockInitialValues({
        CommercialRadarService.legacyMigratedPrefKey: true,
        CommercialRadarService.locationJsonPrefKey(7): jsonEncode(longLoc.toJson()),
        CommercialRadarService.regionPrefKey(7): longLoc.displayName,
      });

      final List<FlutterErrorDetails> errors = [];
      final prevOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        errors.add(details);
      };

      final viewports = [
        const Size(320, 568),
        const Size(360, 640),
        const Size(412, 915),
      ];

      try {
        for (final size in viewports) {
          await tester.binding.setSurfaceSize(size);

          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) {
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(1.3),
                  ),
                  child: child!,
                );
              },
              home: const CommercialRadarScreen(
                autoTriggerTour: false,
                profileId: 7,
              ),
            ),
          );
          await _pumpAsyncFrames(tester);
          expect(errors, isEmpty, reason: 'Sin overflows en Screen para $size @ 1.3x');

          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) {
                return MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(1.3),
                  ),
                  child: child!,
                );
              },
              home: const Scaffold(
                body: SingleChildScrollView(
                  child: CommercialRadarCard(
                    isDark: false,
                    profileId: 7,
                  ),
                ),
              ),
            ),
          );
          await _pumpAsyncFrames(tester);
          expect(errors, isEmpty, reason: 'Sin overflows en Card para $size @ 1.3x');
        }
      } finally {
        await tester.binding.setSurfaceSize(null);
        FlutterError.onError = prevOnError;
      }
    });
  });
}
