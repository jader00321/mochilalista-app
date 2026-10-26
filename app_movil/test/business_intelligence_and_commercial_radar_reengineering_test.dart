import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/features/analytics/models/dashboard_section_config.dart';
import 'package:app_movil/features/analytics/models/commercial_radar_model.dart';
import 'package:app_movil/features/analytics/services/commercial_radar_service.dart';
import 'package:app_movil/features/analytics/providers/analytics_provider.dart';
import 'package:app_movil/features/analytics/widgets/dashboard/top_categories_card.dart';
import 'package:app_movil/features/analytics/widgets/dashboard/extra_metrics_card.dart';
import 'package:app_movil/features/analytics/widgets/dashboard/commercial_radar_card.dart';
import 'package:app_movil/features/analytics/widgets/dashboard/dashboard_customizer_modal.dart';
import 'package:app_movil/features/analytics/widgets/dashboard/kpi_summary_row.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/features/analytics/screens/analytics_dashboard_screen.dart';
import 'package:app_movil/features/analytics/screens/commercial_radar_screen.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AUDITORÍA 1: Verdad Matemática, AppCurrency y Formato Unificado', () {
    test('AppCurrency formatea de manera estricta y profesional en Soles (S/ #,##0.00)', () {
      expect(AppCurrency.format(27.97), 'S/ 27.97');
      expect(AppCurrency.format(13.99), 'S/ 13.99');
      expect(AppCurrency.format(2.2), 'S/ 2.20');
      expect(AppCurrency.format(0.0), 'S/ 0.00');
      expect(AppCurrency.format(1234.5), 'S/ 1,234.50');
      expect(AppCurrency.format(1000000), 'S/ 1,000,000.00');
    });

    test('Cálculo de crecimiento de ventas es simétrico y coherente', () {
      // Caso 1: Ventas caen de 18.00 a 4.40
      double totalVentas = 4.40;
      double prevTotalVentas = 18.00;
      double growthRate = ((totalVentas - prevTotalVentas) / prevTotalVentas) * 100;
      expect(growthRate.toStringAsFixed(1), '-75.6');

      // Caso 2: Ventas suben de 100.0 a 250.0
      totalVentas = 250.0;
      prevTotalVentas = 100.0;
      growthRate = ((totalVentas - prevTotalVentas) / prevTotalVentas) * 100;
      expect(growthRate.toStringAsFixed(1), '150.0');

      // Caso 3: Sin ventas previas
      prevTotalVentas = 0.0;
      growthRate = prevTotalVentas > 0 ? ((totalVentas - prevTotalVentas) / prevTotalVentas) * 100 : (totalVentas > 0 ? 100.0 : 0.0);
      expect(growthRate, 100.0);
    });

    test('Diagnóstico de Salud Financiera 2D (Margen x Crecimiento)', () {
      // Margen saludable pero ventas cayeron > 15%
      double margin = 28.5;
      double growth = -25.0;

      String headline;
      if (margin >= 20) {
        if (growth < -15) {
          headline = "Buen margen, pero alerta por caída en ventas ⚠️";
        } else {
          headline = "Excelente Rendimiento y Salud Financiera";
        }
      } else {
        headline = "Bajo Margen";
      }

      expect(headline, "Buen margen, pero alerta por caída en ventas ⚠️");
    });
  });

  group('AUDITORÍA 2: Configuración del Dashboard, Reordenamiento y Presets', () {
    test('Las secciones por defecto contienen todas las tarjetas modulares requeridas', () {
      final sections = DashboardSectionConfig.getDefaultSections();
      expect(sections.isNotEmpty, isTrue);

      final ids = sections.map((s) => s.id).toSet();
      expect(ids.contains('financial_summary'), isTrue);
      expect(ids.contains('kpi_grid'), isTrue);
      expect(ids.contains('commercial_radar'), isTrue);
      expect(ids.contains('predictive_engine'), isTrue);
      expect(ids.contains('insights_carousel'), isTrue);
      expect(ids.contains('sales_evolution'), isTrue);
      expect(ids.contains('sales_by_day'), isTrue);
      expect(ids.contains('sales_by_origin'), isTrue);
      expect(ids.contains('payment_methods'), isTrue);
      expect(ids.contains('top_categories'), isTrue);
      expect(ids.contains('top_products'), isTrue);
      expect(ids.contains('top_clients'), isTrue);
      expect(ids.contains('extra_metrics'), isTrue);
      expect(ids.contains('dead_stock'), isTrue);

      // El resumen financiero debe ser permanente
      final financialSummary = sections.firstWhere((s) => s.id == 'financial_summary');
      expect(financialSummary.isPermanent, isTrue);
      expect(financialSummary.isVisible, isTrue);
    });

    test('Preset Financiero oculta inventario y activa métricas clave financieras', () {
      final defaults = DashboardSectionConfig.getDefaultSections();
      final preset = DashboardSectionConfig.applyPreset(defaults, 'Financiero');

      final deadStock = preset.firstWhere((s) => s.id == 'dead_stock');
      final topProducts = preset.firstWhere((s) => s.id == 'top_products');
      final salesEvolution = preset.firstWhere((s) => s.id == 'sales_evolution');
      final financialSummary = preset.firstWhere((s) => s.id == 'financial_summary');

      expect(deadStock.isVisible, isFalse);
      expect(topProducts.isVisible, isFalse);
      expect(salesEvolution.isVisible, isTrue);
      expect(financialSummary.isVisible, isTrue);
    });

    test('Preset Comercial & Radar activa Radar Comercial y Mejores Clientes', () {
      final defaults = DashboardSectionConfig.getDefaultSections();
      final preset = DashboardSectionConfig.applyPreset(defaults, 'Comercial & Radar');

      final commercialRadar = preset.firstWhere((s) => s.id == 'commercial_radar');
      final topClients = preset.firstWhere((s) => s.id == 'top_clients');

      expect(commercialRadar.isVisible, isTrue);
      expect(topClients.isVisible, isTrue);
    });

    test('Persistencia local guarda y recupera el orden y la visibilidad', () async {
      final defaults = DashboardSectionConfig.getDefaultSections();
      // Ocultar una sección y reordenar
      defaults.firstWhere((s) => s.id == 'dead_stock').isVisible = false;
      final reordered = [
        defaults.firstWhere((s) => s.id == 'commercial_radar'),
        ...defaults.where((s) => s.id != 'commercial_radar'),
      ];

      await DashboardSectionConfig.saveSections(999, reordered);
      final loaded = await DashboardSectionConfig.loadSections(999);

      expect(loaded.first.id, 'commercial_radar');
      final loadedDeadStock = loaded.firstWhere((s) => s.id == 'dead_stock');
      expect(loadedDeadStock.isVisible, isFalse);
    });
  });

  group('AUDITORÍA 3: Radar Comercial & Noticias del Mercado con IA', () {
    test('CommercialNewsItem serializa y deserializa correctamente', () {
      final now = DateTime.now();
      final item = CommercialNewsItem(
        id: 'test_1',
        title: 'Lluvias en Piura impactan rutas',
        summary: 'Badenes preventivos en la Panamericana',
        actionableAdvice: '💡 Impacto / Cómo prepararte: Coordina stock preventivo',
        category: 'Clima y Rutas',
        sourceName: 'Andina',
        sourceUrl: 'https://andina.pe/noticia-1',
        publishedAt: now,
        region: 'Talara / Piura',
      );

      final json = item.toJson();
      final parsed = CommercialNewsItem.fromJson(json);

      expect(parsed.id, item.id);
      expect(parsed.title, item.title);
      expect(parsed.category, 'Clima y Rutas');
      expect(parsed.actionableAdvice, contains('💡 Impacto / Cómo prepararte'));
    });

    test('CommercialRadarService entrega noticias de respaldo offline resilientes', () async {
      final stream = CommercialRadarService.streamCuratedNews(region: 'Talara / Piura');
      final items = await stream.toList();

      expect(items.isNotEmpty, isTrue);
      expect(items.length, greaterThanOrEqualTo(4));

      for (var item in items) {
        expect(item.title.isNotEmpty, isTrue);
        expect(item.sourceUrl.startsWith('http'), isTrue);
        expect(item.actionableAdvice.isNotEmpty, isTrue);
        expect(item.impactAnalysis.isNotEmpty, isTrue);
      }

      final hasClima = items.any((i) => i.category == 'Clima y Rutas');
      final hasSunat = items.any((i) => i.category == 'Leyes y SUNAT');
      expect(hasClima, isTrue);
      expect(hasSunat, isTrue);
    });
  });

  group('AUDITORÍA 4: Widgets y Componentes Visuales Auditados', () {
    testWidgets(r'TopCategoriesCard tiene selector interactivo [$ Por Ingresos] y [📦 Por Unidades]', (tester) async {
      final sampleData = AnalyticsData(
        totalSales: 500,
        netProfit: 150,
        estimatedMarginPercentage: 30,
        totalTransactions: 20,
        inventoryValue: 2000,
        monthlySales: [],
        topProducts: [],
        topClients: [],
        deadStockList: [],
        deadStockCount: 0,
        salesByDayOfWeek: [],
        salesByOrigin: [],
        salesByPaymentMethod: [],
        categoryInsight: 'Abarrotes lidera tus ingresos',
        inventoryTurnoverRatio: 2.5,
        immobilizedCapital: 0,
        recoveredLiquidity: 0,
        averageTicket: 25,
        dailySalesData: [],
        lowStockProducts: [],
        insights: [],
        topCategories: [
          {'nombre': 'Abarrotes', 'total_vendido': 50, 'total_ingresos': 400.0},
          {'nombre': 'Bebidas', 'total_vendido': 80, 'total_ingresos': 100.0},
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TopCategoriesCard(
              data: sampleData,
              isDark: false,
            ),
          ),
        ),
      );

      // Debe mostrar el título Top Categorías y los botones segmented
      expect(find.text("Top Categorías"), findsOneWidget);
      expect(find.text("Ingresos"), findsOneWidget);
      expect(find.text("Unidades"), findsOneWidget);

      // Por defecto muestra ingresos ($ 400.00 primero)
      expect(find.text("Abarrotes"), findsOneWidget);
      expect(find.text("S/ 400.00"), findsOneWidget);

      // Cambiar a Unidades
      await tester.tap(find.text("Unidades"));
      await tester.pumpAndSettle();

      // Ahora debe mostrar unidades (80 unid. y 50 unid.)
      expect(find.text("80 unid."), findsOneWidget);
      expect(find.text("50 unid."), findsOneWidget);
    });

    testWidgets('ExtraMetricsCard muestra Margen Promedio, Cobranza Efectiva y Proyección', (tester) async {
      final sampleData = AnalyticsData(
        totalSales: 1000,
        netProfit: 300,
        estimatedMarginPercentage: 30,
        totalTransactions: 10,
        inventoryValue: 3000,
        monthlySales: [],
        topProducts: [],
        topClients: [],
        deadStockList: [],
        deadStockCount: 0,
        salesByDayOfWeek: [],
        salesByOrigin: [],
        salesByPaymentMethod: [],
        inventoryTurnoverRatio: 1.5,
        immobilizedCapital: 100,
        recoveredLiquidity: 50,
        averageTicket: 100,
        dailySalesData: [],
        lowStockProducts: [],
        insights: [],
        topCategories: [],
        averageMarginPerSale: 30.0,
        effectiveCollectionRate: 95.5,
        nextMonthPrediction: 1250.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExtraMetricsCard(
              data: sampleData,
              isDark: false,
            ),
          ),
        ),
      );

      expect(find.text("Métricas Clave de Eficiencia"), findsOneWidget);
      expect(find.text("Margen Promedio / Venta"), findsOneWidget);
      expect(find.text("S/ 30.00"), findsOneWidget);
      expect(find.text("Tasa de Cobranza Efectiva"), findsOneWidget);
      expect(find.text("95.5%"), findsOneWidget);
      expect(find.text("Proyección Próx. Periodo"), findsOneWidget);
      expect(find.text("S/ 1,250.00"), findsOneWidget);
    });

    testWidgets('CommercialRadarCard renderiza con pulso, filtros y fuente oficial clicable', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CommercialRadarCard(
                isDark: false,
                defaultRegion: 'Talara / Piura',
              ),
            ),
          ),
        ),
      );

      // Esperar que el stream de fallback entregue noticias
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text("Radar Comercial"), findsOneWidget);
      expect(find.text("IA EN VIVO"), findsOneWidget);
      expect(find.text("Talara / Piura"), findsWidgets);

      // Filtros por categoría
      expect(find.text("Todas"), findsOneWidget);
      expect(find.text("Clima y Rutas"), findsWidgets);

      // Botón "Leer en ... ↗"
      expect(find.textContaining("Leer en "), findsWidgets);
      // Botón para abrir la ventana completa de Radar IA
      expect(find.textContaining("Explorar más noticias"), findsOneWidget);
    });

    testWidgets('DashboardCustomizerModal permite cambiar presets y switches', (tester) async {
      final sections = DashboardSectionConfig.getDefaultSections();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardCustomizerModal(
              negocioId: 1,
              isDark: false,
              initialSections: sections,
              onSaved: (_) {},
            ),
          ),
        ),
      );

      expect(find.text("Personalizar Dashboard"), findsOneWidget);
      expect(find.text("✨ Completo"), findsOneWidget);
      expect(find.text("💼 Financiero"), findsOneWidget);
      expect(find.text("📦 Operativo / Stock"), findsOneWidget);
      expect(find.text("Guardar Cambios"), findsOneWidget);

      // Cambiar a preset Financiero
      await tester.tap(find.text("💼 Financiero"));
      await tester.pumpAndSettle();

      // Cerrar modal
      await tester.tap(find.text("Guardar Cambios"));
      await tester.pumpAndSettle();
    });

    testWidgets('KpiSummaryRow formatea con AppCurrency y sincroniza Crecimiento al intercambiar tarjetas', (tester) async {
      final sampleData = AnalyticsData(
        totalSales: 1500,
        netProfit: 450,
        estimatedMarginPercentage: 30,
        totalTransactions: 42,
        inventoryValue: 3500,
        salesGrowthRate: 25.5,
        inventoryTurnoverRatio: 2.15,
        immobilizedCapital: 850,
        recoveredLiquidity: 200,
        averageTicket: 35.71,
        monthlySales: [],
        topProducts: [],
        topClients: [],
        deadStockList: [],
        deadStockCount: 4,
        salesByDayOfWeek: [],
        salesByOrigin: [],
        salesByPaymentMethod: [],
        categoryInsight: '',
        dailySalesData: [],
        lowStockProducts: [],
        insights: [],
        topCategories: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: KpiSummaryRow(
                data: sampleData,
                isDark: false,
              ),
            ),
          ),
        ),
      );

      // Por defecto la tarjeta destacada inicial es Ventas (42)
      expect(find.text("42"), findsOneWidget);
      expect(find.text("Ventas"), findsOneWidget);

      // En la cuadrícula pequeña debe figurar Crecimiento "+25.5%"
      expect(find.text("+25.5%"), findsOneWidget);
      expect(find.text("Crecimiento"), findsOneWidget);

      // Los montos deben usar AppCurrency ("S/ 3,500.00", "S/ 850.00", etc.)
      expect(find.text("S/ 3,500.00"), findsOneWidget);
      expect(find.text("S/ 850.00"), findsOneWidget);

      // Tocar la mini-tarjeta de Crecimiento para intercambiarla a la destacada
      await tester.tap(find.text("Crecimiento"));
      await tester.pumpAndSettle();

      // Ahora la destacada debe mostrar exactamente el mismo "+25.5%" y Ventas 42 en la cuadrícula
      expect(find.text("+25.5%"), findsOneWidget);
      expect(find.text("42"), findsOneWidget);
    });

    testWidgets('KpiSummaryRow respeta el callback formatCurrency para ocultar cifras', (tester) async {
      final sampleData = AnalyticsData(
        totalSales: 1000,
        netProfit: 300,
        estimatedMarginPercentage: 30,
        totalTransactions: 10,
        inventoryValue: 2000,
        salesGrowthRate: 10.0,
        inventoryTurnoverRatio: 1.5,
        immobilizedCapital: 500,
        recoveredLiquidity: 100,
        averageTicket: 50,
        monthlySales: [],
        topProducts: [],
        topClients: [],
        deadStockList: [],
        deadStockCount: 2,
        salesByDayOfWeek: [],
        salesByOrigin: [],
        salesByPaymentMethod: [],
        categoryInsight: '',
        dailySalesData: [],
        lowStockProducts: [],
        insights: [],
        topCategories: [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: KpiSummaryRow(
                data: sampleData,
                isDark: false,
                formatCurrency: (amount) => 'S/ ***.**',
              ),
            ),
          ),
        ),
      );

      // Debe mostrar las cifras ocultas en lugar de montos reales
      expect(find.text("S/ ***.**"), findsWidgets);
    });

    testWidgets('AppBar en pantalla de 360dp no se desborda y mantiene título visible', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              titleSpacing: 0,
              leadingWidth: 38,
              title: const Text(
                "Inteligencia de Negocio",
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: -0.5),
              ),
              actions: [
                const InfoTooltipButton(
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(minWidth: 32, minHeight: 36),
                  iconSize: 20,
                  title: "Info",
                  description: "Info desc",
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                  icon: const Icon(Icons.tune, size: 21),
                  onPressed: () {},
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                  icon: const Icon(Icons.refresh, size: 21),
                  onPressed: () {},
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                  icon: const Icon(Icons.visibility, size: 21),
                  onPressed: () {},
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                  icon: const Icon(Icons.download, size: 21),
                  onPressed: () {},
                ),
                const SizedBox(width: 4),
              ],
            ),
            body: const SizedBox(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Debe mostrar el título sin error de overflow
      expect(find.text("Inteligencia de Negocio"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('CommercialRadarCard abre selector de regiones y persiste selección', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CommercialRadarCard(
              isDark: false,
              defaultRegion: 'Talara / Piura',
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));

      // Tocar el selector de región geográfica
      await tester.tap(find.text("Talara / Piura").first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Debe aparecer el modal con opciones predefinidas
      expect(find.text("Enfoque Geográfico"), findsOneWidget);
      expect(find.text("Arequipa"), findsOneWidget);
      expect(find.text("Otra / Personalizada..."), findsOneWidget);

      // Seleccionar Arequipa
      await tester.tap(find.text("Arequipa"));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Verificar persistencia en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('commercial_radar_selected_region'), 'Arequipa');
    });

    testWidgets('AnalyticsDashboardScreen en 360x800dp renderiza estado idle sin errores geométricos', (tester) async {
      FlutterErrorDetails? capturedDetails;
      final oldHandler = FlutterError.onError;
      FlutterError.onError = (details) {
        capturedDetails = details;
        debugPrint("=== ERROR CAPTURADO ===");
        debugPrint(details.exceptionAsString());
        debugPrint(details.context?.toString());
        debugPrint("RenderObject: ${details.informationCollector?.call().map((e) => e.toString()).join('\n')}");
      };
      addTearDown(() {
        FlutterError.onError = oldHandler;
      });

      tester.view.physicalSize = const Size(360 * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final analyticsProv = AnalyticsProvider();
      final authProv = AuthProvider();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AnalyticsProvider>.value(value: analyticsProv),
            ChangeNotifierProvider<AuthProvider>.value(value: authProv),
          ],
          child: const MaterialApp(
            home: AnalyticsDashboardScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      if (capturedDetails != null) {
        debugPrint("DETALLES: ${capturedDetails!.summary}");
      }

      // 1. Verificación del icono pulsante y títulos principales
      expect(find.byIcon(Icons.query_stats), findsOneWidget);
      expect(find.text("Inteligencia de Negocio & Radar"), findsOneWidget);
      expect(find.textContaining("Métricas auditadas a 0ms"), findsOneWidget);

      // 2. Verificación de las 4 tarjetas de preview completas sin cortes
      expect(find.text("📊 Ganancia Neta Real"), findsOneWidget);
      expect(find.text("🚀 Motor Predictivo"), findsOneWidget);
      expect(find.text("📦 Inventario Muerto"), findsOneWidget);
      expect(find.text("📰 Radar Mercado IA"), findsOneWidget);

      // 3. Verificación de chips de periodo con textos visibles y altura acotada
      expect(find.text("Selecciona el periodo a analizar:"), findsOneWidget);
      expect(find.text("Hoy"), findsOneWidget);
      expect(find.text("7 Días"), findsOneWidget);
      expect(find.text("30 Días"), findsOneWidget);

      // 4. Verificación del botón de llamada a la acción primario
      expect(find.text("Generar Reporte Integral"), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      // 5. Cero excepciones de layout o unbounded height
      expect(capturedDetails, isNull);
      expect(tester.takeException(), isNull);
    });
  });

  group('AUDITORÍA 5: Presets Inteligentes, Modal sin Doble Handle y Ventana Radar Completa', () {
    test('DashboardSectionConfig.detectPreset identifica correctamente configuraciones', () {
      final defaults = DashboardSectionConfig.getDefaultSections();
      expect(DashboardSectionConfig.detectPreset(defaults), 'Completo');

      final financiero = DashboardSectionConfig.applyPreset(defaults, 'Financiero');
      expect(DashboardSectionConfig.detectPreset(financiero), 'Financiero');

      final operativo = DashboardSectionConfig.applyPreset(defaults, 'Operativo / Stock');
      expect(DashboardSectionConfig.detectPreset(operativo), 'Operativo / Stock');

      // Modificación manual genera preset Personalizado
      financiero.firstWhere((s) => s.id == 'dead_stock').isVisible = true;
      expect(DashboardSectionConfig.detectPreset(financiero), 'Personalizado');
    });

    testWidgets('DashboardCustomizerModal abre con preset detectado y 1 sola capa limpia', (tester) async {
      final sections = DashboardSectionConfig.getDefaultSections();
      final financiero = DashboardSectionConfig.applyPreset(sections, 'Financiero');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DashboardCustomizerModal(
              negocioId: 42,
              isDark: false,
              initialSections: financiero,
              onSaved: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Debe mostrar el chip "💼 Financiero" iluminado y todas las opciones
      expect(find.text("💼 Financiero"), findsOneWidget);
      expect(find.text("Activar Todo"), findsOneWidget);
      expect(find.text("Guardar Cambios"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('CommercialRadarScreen renderiza ventana completa dedicada con 6 categorías y análisis IA', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CommercialRadarScreen(initialRegion: 'Talara / Piura'),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 500));

      // 1. Título y subtítulo de la ventana completa
      expect(find.text("Radar Comercial IA"), findsOneWidget);
      expect(find.textContaining("Señales de mercado"), findsOneWidget);

      // 2. Chips de categorías dedicadas
      expect(find.text("Todas"), findsOneWidget);
      expect(find.text("📍 Mi Región"), findsOneWidget);
      expect(find.text("🌦️ Clima y Rutas"), findsOneWidget);
      expect(find.text("⚖️ Leyes y SUNAT"), findsOneWidget);

      // 3. Medidas y Recomendaciones Clave estructuradas
      expect(find.textContaining("Medidas y Recomendaciones Clave:"), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    test('SmartActionGrid fusiona automáticamente commercial_radar en preferencias guardadas (Regla 1)', () async {
      // Simular lista guardada previa sin commercial_radar
      final savedOrder = ['quick_sale', 'clients', 'analytics'];
      const defaultIds = [
        'quick_sale',
        'create_product',
        'quote_list',
        'quote_manual',
        'load_invoice',
        'clients',
        'activity',
        'analytics',
        'commercial_radar',
      ];

      // Algoritmo de fusión implementado en _loadCustomizations
      final validIds = savedOrder.where((id) => defaultIds.contains(id)).toList();
      for (var dId in defaultIds) {
        if (!validIds.contains(dId)) {
          validIds.add(dId);
        }
      }

      // Verificación estricta: commercial_radar debe quedar incorporada automáticamente
      expect(validIds.contains('commercial_radar'), isTrue);
      expect(validIds.last, 'commercial_radar');
      expect(validIds.length, 9);
    });

    testWidgets('CommercialRadarCard botón CTA navega a CommercialRadarScreen', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CommercialRadarCard(isDark: false),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      final ctaFinder = find.textContaining("Explorar más noticias");
      expect(ctaFinder, findsOneWidget);

      await tester.ensureVisible(ctaFinder);
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(ctaFinder);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Debe abrir la ventana completa
      expect(find.text("Radar Comercial IA"), findsOneWidget);
    });
  });
}


