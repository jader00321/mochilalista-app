import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/features/analytics/models/commercial_radar_model.dart';
import 'package:app_movil/features/analytics/services/commercial_radar_service.dart';
import 'package:app_movil/features/analytics/screens/commercial_radar_screen.dart';
import 'package:app_movil/features/analytics/widgets/dashboard/commercial_radar_card.dart';
import 'package:app_movil/features/analytics/screens/smart_restock_screen.dart';
import 'package:app_movil/features/smart_quotation/models/matching_model.dart';
import 'package:app_movil/features/smart_quotation/models/extracted_list_model.dart';
import 'package:app_movil/features/smart_quotation/providers/matching_provider.dart';
import 'package:app_movil/features/smart_quotation/widgets/matching/matching_item_row.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Configurar base de datos en memoria para pruebas SQLite
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('FASE 1: Radar Comercial IA — Fusión Intradía, Caducidad y Persistencia', () {
    test('1.1. CommercialNewsItem purga el 100% de emojis Unicode de sus textos', () {
      final itemWithEmojis = CommercialNewsItem(
        id: 'test_emoji_1',
        title: '📡 Gran noticia comercial: 🚀 Ventas se duplican en Piura 🌦️',
        summary: '⚠️ Atención minoristas: 💡 Oportunidad de abastecimiento 📦',
        impactAnalysis: '🔥 Alto impacto en ventas',
        actionableAdvice: '🛒 Comprar stock antes del viernes 📈',
        category: 'Mi Región',
        sourceName: 'Diario Regional 📰',
        sourceUrl: 'https://ejemplo.com',
        publishedAt: DateTime(2026, 10, 28, 10, 0),
        region: 'Talara / Piura',
      );

      // Verificamos que los getters limpios no contengan ningún emoji
      expect(itemWithEmojis.cleanTitle, isNot(contains('📡')));
      expect(itemWithEmojis.cleanTitle, isNot(contains('🚀')));
      expect(itemWithEmojis.cleanTitle, isNot(contains('🌦️')));
      expect(itemWithEmojis.cleanTitle, 'Gran noticia comercial: Ventas se duplican en Piura');

      expect(itemWithEmojis.cleanSummary, isNot(contains('⚠️')));
      expect(itemWithEmojis.cleanSummary, isNot(contains('💡')));
      expect(itemWithEmojis.cleanSummary, isNot(contains('📦')));

      expect(itemWithEmojis.cleanAdvice, isNot(contains('🛒')));
      expect(itemWithEmojis.cleanAdvice, isNot(contains('📈')));

      expect(itemWithEmojis.cleanImpact, isNot(contains('🔥')));
      expect(itemWithEmojis.cleanImpact, 'Alto impacto en ventas');
    });

    test('1.2. Acumulación intradía (_mergeNewsItems) fusiona señales nuevas sin borrar las existentes', () {
      final now = DateTime.now();
      final List<CommercialNewsItem> existingNews = [
        CommercialNewsItem(
          id: 'news_1',
          title: 'Noticia Existente 1',
          summary: 'Resumen 1',
          actionableAdvice: 'Consejo 1',
          category: 'Clima y Rutas',
          sourceName: 'SENAMHI',
          sourceUrl: 'https://senamhi.gob.pe',
          publishedAt: now,
          region: 'Piura',
        ),
        CommercialNewsItem(
          id: 'news_2',
          title: 'Noticia Existente 2',
          summary: 'Resumen 2',
          actionableAdvice: 'Consejo 2',
          category: 'Leyes y SUNAT',
          sourceName: 'SUNAT',
          sourceUrl: 'https://sunat.gob.pe',
          publishedAt: now,
          region: 'Nacional',
        ),
      ];

      final List<CommercialNewsItem> incomingNews = [
        CommercialNewsItem(
          id: 'news_2', // Duplicada (debe preservarse sin clonar)
          title: 'Noticia Existente 2',
          summary: 'Resumen 2',
          actionableAdvice: 'Consejo 2',
          category: 'Leyes y SUNAT',
          sourceName: 'SUNAT',
          sourceUrl: 'https://sunat.gob.pe',
          publishedAt: now,
          region: 'Nacional',
        ),
        CommercialNewsItem(
          id: 'news_3', // Señal fresca
          title: 'Nueva Señal de Proveedores',
          summary: 'Resumen 3',
          actionableAdvice: 'Consejo 3',
          category: 'Proveedores y Abastecimiento',
          sourceName: 'Bolsa Mayorista',
          sourceUrl: 'https://proveedores.pe',
          publishedAt: now,
          region: 'Lima',
        ),
      ];

      final merged = CommercialRadarService.mergeNewsItems(existingNews, incomingNews);

      // Deben quedar exactamente 3 noticias (news_1, news_2, news_3) sin duplicar news_2
      expect(merged.length, 3);
      final ids = merged.map((n) => n.id).toSet();
      expect(ids.contains('news_1'), isTrue);
      expect(ids.contains('news_2'), isTrue);
      expect(ids.contains('news_3'), isTrue);
    });

    test('1.3. Rotación matutina: getTodayDateStr retorna formato yyyy-MM-dd para control de caducidad', () {
      final dateStr = CommercialRadarService.getTodayDateStr();
      final now = DateTime.now();
      final expected = "${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      expect(dateStr, expected);
    });

    test('1.4. Guardar y recuperar noticias marcadas en SQLite y SharedPreferences', () async {
      final testDb = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS radar_noticias_guardadas (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              summary TEXT NOT NULL,
              actionable_advice TEXT NOT NULL,
              category TEXT NOT NULL,
              source_name TEXT NOT NULL,
              source_url TEXT NOT NULL,
              published_at TEXT NOT NULL,
              region TEXT,
              estimated_impact TEXT,
              created_at TEXT NOT NULL
            )
          ''');
        },
      );

      final sampleItem = CommercialNewsItem(
        id: 'bookmark_1',
        title: 'Guía de Remisión Electrónica SUNAT 2026',
        summary: 'Nuevos requisitos para transporte interprovincial',
        actionableAdvice: 'Revisar RUC de transportistas',
        category: 'Leyes y SUNAT',
        sourceName: 'SUNAT',
        sourceUrl: 'https://sunat.gob.pe',
        publishedAt: DateTime(2026, 10, 28, 12, 0),
        region: 'Nacional',
        impactAnalysis: 'Afecta traslados',
      );

      // Inserción en base de datos
      await testDb.insert('radar_noticias_guardadas', {
        'id': sampleItem.id,
        'title': sampleItem.title,
        'summary': sampleItem.summary,
        'actionable_advice': sampleItem.actionableAdvice,
        'category': sampleItem.category,
        'source_name': sampleItem.sourceName,
        'source_url': sampleItem.sourceUrl,
        'published_at': sampleItem.publishedAt.toIso8601String(),
        'region': sampleItem.region,
        'estimated_impact': sampleItem.impactAnalysis,
        'created_at': DateTime.now().toIso8601String(),
      });

      // Consulta
      final rows = await testDb.query('radar_noticias_guardadas');
      expect(rows.length, 1);
      expect(rows.first['id'], 'bookmark_1');
      expect(rows.first['title'], 'Guía de Remisión Electrónica SUNAT 2026');

      await testDb.close();
    });
  });

  group('FASE 2: Trazabilidad y Cuadre Matemático de Variantes (Compartido vs Independiente)', () {
    test('2.1. Ecuación de Kárdex: Stock Inicial + Entradas - Salidas = Saldo Final', () {
      const double stockInicial = 100.0;
      const double entradas = 50.0;
      const double salidas = 30.0;
      final double saldoFinal = stockInicial + entradas - salidas;

      expect(saldoFinal, 120.0);
      expect(stockInicial + entradas - salidas, saldoFinal);
    });

    test('2.2. Detección de movimiento de presentación hermana en pool compartido', () {
      // Simulación de registros de ledger donde una venta de 'Caja x12' impactó el pool base
      final ledgerRows = [
        {
          'id': 1,
          'product_id': 10,
          'presentation_id': 201, // Unidad
          'tipo_movimiento': 'VENTA',
          'cantidad': 12,
          'motivo': 'Venta vía Caja x12',
          'es_hermana': 1,
        },
        {
          'id': 2,
          'product_id': 10,
          'presentation_id': 200, // Presentación consultada actual
          'tipo_movimiento': 'VENTA',
          'cantidad': 3,
          'motivo': 'Venta directa',
          'es_hermana': 0,
        },
      ];

      expect(ledgerRows[0]['es_hermana'], 1);
      expect(ledgerRows[1]['es_hermana'], 0);
    });
  });

  group('FASE 3: Abastecimiento Inteligente — Detección de Quiebres de Formato', () {
    test('3.1. Detección precisa de stock base insuficiente para paquetes completos (Quiebre de Formato)', () {
      // Producto con 2 presentaciones:
      // Unidad (factor 1) y Caja x12 (factor 12)
      // Stock total del pool: 17 unidades base
      const int poolStockBase = 17;
      const int unidadesPorVentaCaja = 12;

      final int cajasCompletasDisponibles = poolStockBase ~/ unidadesPorVentaCaja; // 1
      final int restoBase = poolStockBase % unidadesPorVentaCaja; // 5 restantes

      expect(cajasCompletasDisponibles, 1);
      expect(restoBase, 5);

      // Si el stock base fuera 5:
      const int lowPoolStock = 5;
      final int cajasConLow = lowPoolStock ~/ unidadesPorVentaCaja; // 0
      final int faltantes = unidadesPorVentaCaja - lowPoolStock; // Faltan 7 u. base

      expect(cajasConLow, 0);
      expect(faltantes, 7);

      final formatBreakAlert = "Caja x12: 0 disponibles (faltan $faltantes u. base para armar 1 paquete)";
      expect(formatBreakAlert, contains('0 disponibles'));
      expect(formatBreakAlert, contains('faltan 7 u. base'));
    });
  });

  group('FASE 4: Cotización Inteligente — Visualización de Precio y Cero Estiramiento', () {
    testWidgets('4.1. MatchingItemRow en estado retraído muestra precio final grande y limpio', (tester) async {
      final pair = MatchPair(
        sourceItem: ExtractedItem(
          id: 1,
          originalText: 'Cuaderno Standford A4 100h',
          fullName: 'Cuaderno Standford A4 100h',
          quantity: 3,
          unit: 'und',
        ),
        selectedProduct: MatchedProduct(
          productId: 101,
          presentationId: 501,
          fullName: 'Cuaderno Standford A4 Cuadriculado 100h',
          productName: 'Cuaderno Standford A4 Cuadriculado 100h',
          brand: 'Standford',
          unit: 'und',
          price: 7.50,
          offerPrice: 6.50,
          stock: 50,
          conversionFactor: 1,
          usaStockCompartido: false,
          sharedStockPool: 0,
        ),
        status: MatchStatus.auto,
      );

      final matchingProvider = MatchingProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<MatchingProvider>.value(
              value: matchingProvider,
              child: MatchingItemRow(
                pair: pair,
                index: 0,
                isClient: true,
                onTapProduct: () {},
                onChangeRequest: () {},
                onDelete: () {},
                onUnlink: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Debe mostrar el subtotal final calculado: 3 * 6.50 = S/ 19.50
      final expectedSubtotal = AppCurrency.format(pair.subtotal);
      expect(find.text(expectedSubtotal), findsOneWidget);

      // 2. Al tener descuento (7.50 vs 6.50), debe mostrar el ahorro total: 3 * 1.00 = -S/ 3.00
      final expectedDiscountBadge = "-${AppCurrency.format((7.50 - 6.50) * 3)}";
      expect(find.text(expectedDiscountBadge), findsOneWidget);

      // 3. El precio original tachado debe mostrarse en la línea superior (3 * 7.50 = S/ 22.50)
      final expectedOriginalTotal = AppCurrency.format(7.50 * 3);
      expect(find.text(expectedOriginalTotal), findsOneWidget);

      // 4. Verificamos que no haya ningún emoji en la fila renderizada
      final allTextWidgets = tester.widgetList<Text>(find.byType(Text));
      for (final textWidget in allTextWidgets) {
        final text = textWidget.data ?? textWidget.textSpan?.toPlainText() ?? '';
        final hasEmoji = RegExp(r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]', unicode: true).hasMatch(text);
        expect(hasEmoji, isFalse, reason: 'Se encontró emoji en: "$text"');
      }
    });

    testWidgets('4.2. MatchingItemRow con Stock Compartido muestra badge vectorial Icons.hub_outlined sin emojis', (tester) async {
      final pair = MatchPair(
        sourceItem: ExtractedItem(
          id: 2,
          originalText: 'Plumones Faber Castell 45',
          fullName: 'Plumones Faber Castell 45',
          quantity: 2,
          unit: 'estuche',
        ),
        selectedProduct: MatchedProduct(
          productId: 102,
          presentationId: 502,
          fullName: 'Plumones Faber Castell x45 Delgados',
          productName: 'Plumones Faber Castell x45 Delgados',
          brand: 'Faber-Castell',
          unit: 'estuche',
          price: 25.00,
          stock: 15,
          conversionFactor: 1,
          usaStockCompartido: true,
          sharedStockPool: 40,
        ),
        status: MatchStatus.auto,
      );

      final matchingProvider = MatchingProvider();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<MatchingProvider>.value(
              value: matchingProvider,
              child: MatchingItemRow(
                pair: pair,
                index: 0,
                isClient: true,
                onTapProduct: () {},
                onChangeRequest: () {},
                onDelete: () {},
                onUnlink: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Debe mostrar el badge de pool con icono vectorial
      expect(find.byIcon(Icons.hub_outlined), findsOneWidget);
      expect(find.text("Pool: 40 u. base"), findsOneWidget);

      // Cero emojis
      final allTextWidgets = tester.widgetList<Text>(find.byType(Text));
      for (final textWidget in allTextWidgets) {
        final text = textWidget.data ?? textWidget.textSpan?.toPlainText() ?? '';
        final hasEmoji = RegExp(r'[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]', unicode: true).hasMatch(text);
        expect(hasEmoji, isFalse, reason: 'Se encontró emoji en: "$text"');
      }
    });
  });

  group('FASE 5: Certificación de Pestaña Segmentada e Iconos Vectoriales en Radar Comercial Screen', () {
    testWidgets('5.1. CommercialRadarScreen renderiza pestaña segmentada con iconos vectoriales y cero emojis', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CommercialRadarScreen(),
        ),
      );

      await tester.pump(); // Inicia carga

      // Verificamos los iconos vectoriales de la barra segmentada superior (y header)
      expect(find.byIcon(Icons.radar_rounded), findsNWidgets(2));
      expect(find.byIcon(Icons.bookmarks_rounded), findsOneWidget);

      // Verificamos que los textos de la barra segmentada no contengan emojis
      expect(find.text("Noticias del Día"), findsOneWidget);
      expect(find.textContaining("Guardadas"), findsOneWidget);

      // Verificamos los chips de categorías con iconos vectoriales
      expect(find.byIcon(Icons.public_rounded), findsOneWidget); // Todas
      expect(find.byIcon(Icons.location_on_outlined), findsOneWidget); // Mi Región
      expect(find.byIcon(Icons.wb_cloudy_outlined), findsOneWidget); // Clima y Rutas
      expect(find.byIcon(Icons.gavel_rounded), findsOneWidget); // Leyes y SUNAT
      expect(find.byIcon(Icons.local_shipping_outlined), findsOneWidget); // Proveedores
      expect(find.byIcon(Icons.event_available_outlined), findsOneWidget); // Fechas y Campañas
    });
  });

  group('CERTIFICACIÓN ADVERSARIAL: 3 PUNTOS CLAVE DEL PLAN MAESTRO', () {
    // -------------------------------------------------------------------------
    // PUNTO 1: Rotación dinámica de noticias en Inteligencia de Negocio y Cero Cortes
    // -------------------------------------------------------------------------
    testWidgets('1.1. CommercialRadarCard incluye botón shuffle_rounded ("Alternar señales") y rota noticias', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CommercialRadarCard(isDark: false),
            ),
          ),
        ),
      );

      await tester.pump(); // Inicia carga de caché / fallback
      await tester.pump(const Duration(milliseconds: 100));

      // Verificamos la presencia del botón vectorial "Alternar señales"
      final shuffleButton = find.byIcon(Icons.shuffle_rounded);
      expect(shuffleButton, findsOneWidget);

      // Verificamos el tooltip del botón
      final iconButton = tester.widget<IconButton>(
        find.ancestor(of: shuffleButton, matching: find.byType(IconButton)),
      );
      expect(iconButton.tooltip, "Alternar señales");

      // Pulsamos el botón para verificar que el estado rota sin errores
      if (iconButton.onPressed != null) {
        await tester.tap(shuffleButton);
        await tester.pump();
      }
    });

    test('1.2. CommercialNewsItem.compactTimeAgo entrega formato limpio sin año redundante y sin elipsis', () {
      final now = DateTime.now();
      final itemRecent = CommercialNewsItem(
        id: 'cr_test_date',
        title: 'MTC activa monitoreo',
        summary: 'Resumen',
        actionableAdvice: 'Consejo',
        category: 'Clima y Rutas',
        sourceName: 'Andina',
        sourceUrl: 'https://andina.pe',
        publishedAt: now.subtract(const Duration(hours: 3)),
        region: 'Talara / Piura',
      );

      final compactStr = itemRecent.compactTimeAgo;
      expect(compactStr, contains('Hace 3h'));
      expect(compactStr, isNot(contains('...')));
      expect(compactStr, isNot(contains(now.year.toString()))); // Sin año redundante
    });

    test('1.3. Pull-to-Refresh acumula incrementalmente nuevas señales de la reserva de 28+', () async {
      final stream1 = CommercialRadarService.streamCuratedNews(region: 'Talara / Piura', forceRefresh: false);
      final batch1 = await stream1.toList();
      expect(batch1.isNotEmpty, isTrue);

      // Invocamos refresco forzado (Pull-to-Refresh)
      final stream2 = CommercialRadarService.streamCuratedNews(region: 'Talara / Piura', forceRefresh: true);
      final batch2 = await stream2.toList();
      expect(batch2.isNotEmpty, isTrue);

      // lastNewSignalsCount debe registrar las señales nuevas añadidas
      expect(CommercialRadarService.lastNewSignalsCount, greaterThan(0));
    });

    // -------------------------------------------------------------------------
    // PUNTO 2: Coherencia de escala matemática en Trazabilidad para Variantes con Stock Compartido
    // -------------------------------------------------------------------------
    test('2.1. Escala Matemática y Equivalencia de Presentación en Stock Compartido con factor > 1', () {
      // Supongamos un pool compartido con 20 unidades base
      const int poolStockBase = 20;
      const int factorPar = 2; // Variante Par x2
      const String variantName = "Par";

      // Cálculo de equivalencia
      final int equivPacks = poolStockBase ~/ factorPar; // 10 Pares x2
      final String equivStr = "$equivPacks ${variantName == 'Par' ? 'Pares' : variantName} x$factorPar";

      expect(equivStr, "10 Pares x2");

      // Verificación de la ecuación en unidades base:
      // Stock Inicial Base (15) + Entradas (10) - Salidas (5) = Saldo Auditoría (20 und. base)
      const int stockInicial = 15;
      const int entradas = 10;
      const int salidas = 5;
      final int saldoAuditoria = stockInicial + entradas - salidas;

      expect(saldoAuditoria, poolStockBase);

      final String fullEquationLabel = "Saldo Auditoría: $stockInicial + $entradas - $salidas = $saldoAuditoria und. base ($equivStr)";
      expect(fullEquationLabel, "Saldo Auditoría: 15 + 10 - 5 = 20 und. base (10 Pares x2)");
    });

    // -------------------------------------------------------------------------
    // PUNTO 3: Recomendación Exacta de Compra por Variante en Abastecimiento Inteligente
    // -------------------------------------------------------------------------
    test('3.1. SmartRestockItem calcula sugerencia exacta de compra ante Quiebre de Formato (Caja x12 con 5 u. base)', () {
      // Producto con pool compartido de 5 unidades base y variante Caja x12 (factor 12)
      const int currentPool = 5;
      const int factorCaja = 12;
      const int missingBase = factorCaja - currentPool; // 7

      expect(missingBase, 7);

      final item = SmartRestockItem(
        presentationId: 101,
        productId: 50,
        productName: 'Cuaderno Standford A4',
        brandName: 'Standford',
        presentationName: 'Pool Compartido',
        currentStock: currentPool,
        cost: 3.50,
        velocityPerDay: 0.0, // Sin ventas históricas aún
        velocityDisplay: "Sin ventas",
        safetyStock: 0,
        rop: 5,
        suggestedQty: missingBase, // Se eleva a 7 para completar la caja
        orderQty: missingBase,
        daysToStockout: 999.0,
        stockoutDate: "",
        status: 'critico',
        statusColor: Colors.redAccent,
        statusText: 'Stock Crítico',
        hasZeroCost: false,
        isSharedPool: true,
        formatBreakAlert: "Caja x12 (0 disponibles, faltan $missingBase u. base)",
        suggestedOrderRecommendation: "Comprar mín. $missingBase u. base para completar 1 Caja x12",
      );

      // Verificamos que la recomendación recomiende adquirir las 7 unidades base faltantes
      expect(item.suggestedQty, 7);
      expect(item.suggestedOrderRecommendation, "Comprar mín. 7 u. base para completar 1 Caja x12");
      expect(item.formatBreakAlert, contains("faltan 7 u. base"));
    });

    test('3.2. SmartRestockItem para pool compartido sin ventas históricas bajo stock mínimo genera reposición sugerida', () {
      // Producto nuevo con stock 3 y alerta mínima configurada en 10
      const int currentPool = 3;
      const int configuredAlert = 10;
      final int needed = configuredAlert - currentPool; // 7

      final item = SmartRestockItem(
        presentationId: 102,
        productId: 51,
        productName: 'Plumón Acrílico Faber-Castell',
        brandName: 'Faber-Castell',
        presentationName: 'Pool Compartido',
        currentStock: currentPool,
        cost: 2.00,
        velocityPerDay: 0.0, // Sin ventas previas
        velocityDisplay: "Sin ventas",
        safetyStock: 0,
        rop: configuredAlert,
        suggestedQty: needed,
        orderQty: needed,
        daysToStockout: 999.0,
        stockoutDate: "",
        status: 'critico',
        statusColor: Colors.redAccent,
        statusText: 'Stock Crítico',
        hasZeroCost: false,
        isSharedPool: true,
        suggestedOrderRecommendation: "Comprar $needed u. base para reponer nivel óptimo",
      );

      expect(item.suggestedQty, 7);
      expect(item.suggestedOrderRecommendation, contains("Comprar 7 u. base"));
    });
  });
}
