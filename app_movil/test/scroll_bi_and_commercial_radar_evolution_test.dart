import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/features/analytics/providers/analytics_provider.dart';
import 'package:app_movil/features/analytics/models/commercial_radar_model.dart';
import 'package:app_movil/features/analytics/models/dashboard_section_config.dart';
import 'package:app_movil/features/analytics/services/commercial_radar_service.dart';
import 'package:app_movil/features/analytics/screens/analytics_dashboard_screen.dart';
import 'package:app_movil/features/analytics/screens/commercial_radar_screen.dart';
import 'package:app_movil/features/analytics/widgets/dashboard/dashboard_customizer_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ÁRBITRO ADVERSARIAL 1: Sanitización Estricta de Emojis e Interleaving Temático', () {
    test('CommercialNewsItem.cleanTitle purga emojis de clima (🌧️, 🌩️, ⛅) y caracteres gráficos residuales', () {
      final item1 = CommercialNewsItem(
        id: 'test_1',
        title: 'Senamhi advierte lluvias en Piura y Tumbes: 🌧️¿qué provincias serán afectadas?',
        summary: 'Resumen de lluvias',
        actionableAdvice: 'Tomar precauciones',
        category: 'Clima y Rutas',
        sourceName: 'SENAMHI',
        sourceUrl: 'https://senamhi.gob.pe',
        publishedAt: DateTime.now(),
        region: 'Talara / Piura',
      );

      expect(item1.cleanTitle.contains('🌧'), isFalse);
      expect(item1.cleanTitle, 'Senamhi advierte lluvias en Piura y Tumbes: ¿qué provincias serán afectadas?');

      final item2 = CommercialNewsItem(
        id: 'test_2',
        title: '🚨⚠️ URGENTE: ⚡ Tormenta eléctrica en el norte y crecida de ríos 🌊',
        summary: 'Alerta',
        actionableAdvice: 'Precaución',
        category: 'Clima y Rutas',
        sourceName: 'SENAMHI',
        sourceUrl: 'https://senamhi.gob.pe',
        publishedAt: DateTime.now(),
        region: 'Talara / Piura',
      );

      expect(item2.cleanTitle.contains('🚨'), isFalse);
      expect(item2.cleanTitle.contains('⚠️'), isFalse);
      expect(item2.cleanTitle.contains('⚡'), isFalse);
      expect(item2.cleanTitle.contains('🌊'), isFalse);
      expect(item2.cleanTitle, 'URGENTE: Tormenta eléctrica en el norte y crecida de ríos');
    });

    test('CommercialRadarService.interleaveCategories alterna equitativamente las categorías comerciales', () {
      final now = DateTime.now();
      // Creamos 6 noticias consecutivas de clima y solo 1 de sunat y 1 de proveedores
      final items = [
        CommercialNewsItem(id: 'c1', title: 'Lluvia 1', summary: 's', actionableAdvice: 'a', category: 'Clima y Rutas', sourceName: 'S', sourceUrl: 'u', publishedAt: now, region: 'P'),
        CommercialNewsItem(id: 'c2', title: 'Lluvia 2', summary: 's', actionableAdvice: 'a', category: 'Clima y Rutas', sourceName: 'S', sourceUrl: 'u', publishedAt: now, region: 'P'),
        CommercialNewsItem(id: 'c3', title: 'Lluvia 3', summary: 's', actionableAdvice: 'a', category: 'Clima y Rutas', sourceName: 'S', sourceUrl: 'u', publishedAt: now, region: 'P'),
        CommercialNewsItem(id: 'c4', title: 'Lluvia 4', summary: 's', actionableAdvice: 'a', category: 'Clima y Rutas', sourceName: 'S', sourceUrl: 'u', publishedAt: now, region: 'P'),
        CommercialNewsItem(id: 's1', title: 'SUNAT GRE', summary: 's', actionableAdvice: 'a', category: 'Leyes y SUNAT', sourceName: 'S', sourceUrl: 'u', publishedAt: now, region: 'P'),
        CommercialNewsItem(id: 'p1', title: 'Precios Arroz', summary: 's', actionableAdvice: 'a', category: 'Proveedores y Abastecimiento', sourceName: 'S', sourceUrl: 'u', publishedAt: now, region: 'P'),
      ];

      final balanced = CommercialRadarService.interleaveCategories(items);
      expect(balanced.length, items.length);

      // Comprobar que no hay 3 noticias de clima consecutivas al inicio
      expect(balanced[0].category, 'Clima y Rutas');
      expect(balanced[1].category, 'Proveedores y Abastecimiento');
      expect(balanced[2].category, 'Leyes y SUNAT');
      expect(balanced[3].category, 'Clima y Rutas');
    });
  });

  group('ÁRBITRO ADVERSARIAL 2: Modal Personalizar Dashboard, Banner Colapsable y Cero Textos Cortados', () {
    testWidgets('DashboardCustomizerModal colapsa banner con ✕ y reabre con ⓘ en la cabecera', (tester) async {
      final sections = DashboardSectionConfig.getDefaultSections();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardCustomizerModal(
              negocioId: 10,
              isDark: true,
              initialSections: sections,
              onSaved: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. El banner azul de instrucciones debe estar visible inicialmente
      final bannerTextFinder = find.textContaining("Mantén presionada una tarjeta para arrastrarla");
      expect(bannerTextFinder, findsOneWidget);

      // 2. Tocamos el botón de cerrar ✕ dentro del banner de ayuda
      final closeFinder = find.descendant(
        of: find.byType(AnimatedSize),
        matching: find.byIcon(Icons.close),
      );
      expect(closeFinder, findsOneWidget);

      await tester.tap(closeFinder);
      await tester.pumpAndSettle();

      // 3. El texto del banner ya no debe mostrarse en pantalla (oculto en SizedBox.shrink)
      expect(bannerTextFinder, findsNothing);

      // 4. Tocamos el icono ⓘ interactivo en la cabecera para reabrirlo
      final infoButtonFinder = find.byTooltip("Mostrar ayuda");
      expect(infoButtonFinder, findsOneWidget);

      await tester.tap(infoButtonFinder);
      await tester.pumpAndSettle();

      // 5. El banner de ayuda reaparece suavemente
      expect(bannerTextFinder, findsOneWidget);
    });

    testWidgets('Tarjeta Radar Comercial & Mercado IA muestra subtítulo completo sin cortes en 360dp', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final sections = DashboardSectionConfig.getDefaultSections();
      // Colocamos commercial_radar al frente para probar directamente su tipografía completa en 360dp
      final radarSection = sections.firstWhere((s) => s.id == 'commercial_radar');
      final testSections = [radarSection, ...sections.where((s) => s.id != 'commercial_radar')];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardCustomizerModal(
              negocioId: 10,
              isDark: false,
              initialSections: testSections,
              onSaved: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Debe mostrar el subtítulo completo sin mutilar la palabra "abastecimiento"
      expect(find.text("Noticias locales, clima, carreteras y consejos de abastecimiento"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('ÁRBITRO ADVERSARIAL 3: Radar Comercial IA - Región Completa, Sticky Header y Semáforo de Pulso', () {
    testWidgets('CommercialRadarScreen muestra "Talara / Piura" completo y Sticky Header con buscador', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CommercialRadarScreen(initialRegion: 'Talara / Piura'),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Región mostrada completa sin "Talara / Pi..."
      expect(find.text("Talara / Piura"), findsWidgets);
      expect(find.textContaining("Talara / Pi..."), findsNothing);

      // 2. Semáforo de Pulso Operativo presente en la cabecera
      expect(find.text("Rutas/Fletes"), findsOneWidget);
      expect(find.text("Abastecimiento"), findsOneWidget);

      // 3. Sticky Header con buscador en tiempo real
      expect(find.byType(SliverPersistentHeader), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text("Buscar noticias, rutas, SUNAT o abastecimiento..."), findsOneWidget);

      // 4. Categorías completas incluyendo pestaña "📌 Guardadas (0)"
      expect(find.text("Todas"), findsOneWidget);
      expect(find.text("📍 Mi Región"), findsOneWidget);
      expect(find.text("🌦️ Clima y Rutas"), findsOneWidget);
      expect(find.text("⚖️ Leyes y SUNAT"), findsOneWidget);
      expect(find.textContaining("📌 Guardadas"), findsOneWidget);

      // 5. Botones de acción directa en tarjetas
      expect(find.text("📦 Revisar Stock Crítico"), findsWidgets);
      expect(find.byIcon(Icons.share_outlined), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('CommercialRadarScreen guarda alertas en SharedPreferences y filtra en "📌 Guardadas"', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CommercialRadarScreen(initialRegion: 'Talara / Piura'),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // 1. Tocamos el botón de guardar en la primera tarjeta de noticias
      final bookmarkButtons = find.byIcon(Icons.bookmark_border);
      expect(bookmarkButtons, findsWidgets);

      await tester.tap(bookmarkButtons.first);
      await tester.pump(const Duration(milliseconds: 300));

      // 2. El chip debe reflejar ahora 📌 Guardadas (1)
      expect(find.text("📌 Guardadas (1)"), findsOneWidget);

      // 3. Tocamos el chip para filtrar exclusivamente las guardadas
      await tester.tap(find.text("📌 Guardadas (1)"), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 300));

      // 4. Verificamos que la tarjeta guardada se mantiene visible con icono relleno
      expect(find.byIcon(Icons.bookmark), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('ÁRBITRO ADVERSARIAL 4: Inteligencia de Negocio - Scroll Desacoplado y Tubito de Burbuja', () {
    testWidgets('AnalyticsDashboardScreen renderiza barra en tubito translúcido sin lanzar excepciones', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => AnalyticsProvider()),
          ],
          child: const MaterialApp(
            home: AnalyticsDashboardScreen(),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 200));

      // La pantalla de inicio (idle) debe renderizar limpiamente
      expect(find.text("Inteligencia de Negocio"), findsOneWidget);
      expect(find.text("Generar Reporte Integral"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AnalyticsDashboardScreen con datos permite navegación libre y 5 saltos consecutivos en cualquier orden', (tester) async {
      final analyticsProvider = AnalyticsProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider.value(value: analyticsProvider),
          ],
          child: const MaterialApp(
            home: AnalyticsDashboardScreen(),
          ),
        ),
      );

      // Ejecutar postFrameCallback inicial
      await tester.pump(const Duration(milliseconds: 100));

      // Inyectar datos simulados para levantar el CustomScrollView
      analyticsProvider.setDataForTesting(
        AnalyticsData(
          totalSales: 2500.0,
          netProfit: 850.0,
          estimatedMarginPercentage: 34.0,
          inventoryTurnoverRatio: 4.2,
          immobilizedCapital: 320.0,
          recoveredLiquidity: 150.0,
          averageTicket: 45.0,
          totalTransactions: 55,
          salesGrowthRate: 12.5,
          inventoryValue: 12000.0,
          deadStockCount: 2,
        ),
      );

      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(milliseconds: 350));

      // 1. Verificar presencia de CustomScrollView y barra de chips en tubito
      expect(find.byType(CustomScrollView), findsOneWidget);
      expect(find.text("Balance Total"), findsWidgets);

      // 2. Verificar chips de salto rápido
      expect(find.text("📊 Resumen"), findsOneWidget);
      expect(find.text("📰 Radar Comercial"), findsOneWidget);
      expect(find.text("📦 Inventario"), findsOneWidget);
      expect(find.text("📈 Gráficos"), findsOneWidget);

      // 3. Prueba de 5 saltos consecutivos en cualquier dirección
      // Salto 1: Radar
      await tester.tap(find.text("📰 Radar Comercial"), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull);

      // Salto 2: Inventario
      await tester.tap(find.text("📦 Inventario"), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull);

      // Salto 3: Gráficos
      await tester.tap(find.text("📈 Gráficos"), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull);

      // Salto 4: Radar (hacia arriba)
      await tester.tap(find.text("📰 Radar Comercial"), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull);

      // Salto 5: Resumen (hacia arriba al inicio)
      await tester.tap(find.text("📊 Resumen"), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull);

      // 4. Prueba de Scroll Manual Libre hacia abajo y hacia arriba
      final scrollableFinder = find.byType(CustomScrollView);
      await tester.drag(scrollableFinder, const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull);

      await tester.drag(scrollableFinder, const Offset(0, 300));
      await tester.pump(const Duration(milliseconds: 350));
      expect(tester.takeException(), isNull);
    });
  });
}

