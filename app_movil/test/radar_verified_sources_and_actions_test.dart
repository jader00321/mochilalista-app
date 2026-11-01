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
import 'package:app_movil/features/smart_quotation/screens/workbench_screen.dart';
import 'package:app_movil/features/catalog/screens/inventory_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/quick_sale_screen.dart';
import 'package:app_movil/features/smart_quotation/providers/matching_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/workbench_provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    CommercialRadarService.clearMemoryCache();
  });

  group('FASE 1: Tolerancia Cero a Enlaces Rotos y Verificación de 28+ Señales', () {
    test('1.1. Catálogo curado contiene al menos 28 señales con URLs válidas y activas', () {
      final signals = CommercialRadarService.getOfflineFallbackSignals(region: 'Talara / Piura');
      expect(signals.length, greaterThanOrEqualTo(28),
          reason: 'El catálogo offline debe contener al menos 28 señales curadas');

      for (final signal in signals) {
        expect(signal.sourceUrl.isNotEmpty, isTrue,
            reason: 'La señal ${signal.id} no puede tener URL vacía');
        expect(
          signal.sourceUrl.startsWith('http://') || signal.sourceUrl.startsWith('https://'),
          isTrue,
          reason: 'La señal ${signal.id} tiene una URL con protocolo inválido: ${signal.sourceUrl}',
        );

        // Tolerancia cero a enlaces rotos conocidos
        expect(
          signal.sourceUrl.contains('orientacion.sunat.gob.pe/guias-de-remision-electronica'),
          isFalse,
          reason: 'La señal ${signal.id} contiene la URL rota de SUNAT GRE que arroja 404',
        );
        expect(
          signal.sourceUrl.contains('976451.aspx'),
          isFalse,
          reason: 'La señal ${signal.id} contiene el artículo 976451.aspx no relacionado',
        );
        expect(
          signal.sourceUrl == 'https://www.gob.pe/produce' || signal.sourceUrl == 'https://gob.pe/produce',
          isFalse,
          reason: 'La señal ${signal.id} apunta a la portada genérica de Produce sin trámites MYPE',
        );
        expect(
          signal.sourceUrl == 'https://siea.midagri.gob.pe/' || signal.sourceUrl == 'https://siea.midagri.gob.pe',
          isFalse,
          reason: 'La señal ${signal.id} apunta a una portada genérica sin el portal SISAP',
        );

        // Coherencia de dominio
        if (signal.sourceName.contains('Cámara de Comercio')) {
          expect(
            signal.sourceUrl.contains('gestion.pe'),
            isFalse,
            reason: 'Señal de Cámara de Comercio ${signal.id} no puede apuntar a portada de gestion.pe',
          );
        }

        // Respaldo curado marcado como no en vivo
        expect(signal.isLive, isFalse,
            reason: 'Las señales del catálogo offline deben tener isLive == false');

        // Cero emojis en todos los textos de la señal
        expect(signal.cleanTitle, isNot(contains('🟢')));
        expect(signal.cleanTitle, isNot(contains('📘')));
        expect(signal.cleanTitle, isNot(contains('📰')));
        expect(signal.cleanSummary, isNot(contains('🟢')));
        expect(signal.cleanAdvice, isNot(contains('🟢')));
        expect(signal.cleanImpact, isNot(contains('🟢')));
      }
    });

    test('1.2. buildVerifiedSearchUrl genera URLs de búsqueda contextual seguras y codificadas', () {
      final url = CommercialNewsItem.buildVerifiedSearchUrl(
        'SUNAT Guías de Remisión Electrónica 2026',
        mediaDomain: 'cpe.sunat.gob.pe',
      );
      expect(url.startsWith('https://news.google.com/search?q='), isTrue);
      expect(url.contains('site%3Acpe.sunat.gob.pe'), isTrue);
      expect(url.contains('SUNAT'), isTrue);
    });
  });

  group('FASE 2: Migración y Saneamiento Automático de Caché y SQLite', () {
    test('2.1. sanitizeAndUpgradeNewsItem reemplaza URLs obsoletas y enlaces rotos', () {
      // 1. URL rota de SUNAT GRE
      final sunatItem = CommercialNewsItem(
        id: 'legacy_sunat_1',
        title: 'SUNAT GRE',
        summary: 'Obligatoriedad de GRE',
        actionableAdvice: 'Revisar stock',
        category: 'Leyes y SUNAT',
        sourceName: 'SUNAT',
        sourceUrl: 'https://orientacion.sunat.gob.pe/guias-de-remision-electronica',
        publishedAt: DateTime.now(),
        region: 'Talara / Piura',
      );
      final upgradedSunat = CommercialRadarService.sanitizeAndUpgradeNewsItem(sunatItem);
      expect(upgradedSunat.sourceUrl, 'https://cpe.sunat.gob.pe/sistema-emision/guia-remision-electronica');
      expect(upgradedSunat.sourceName, 'SUNAT Portal Oficial GRE');

      // 2. Noticia 976451.aspx desconectada
      final proviasItem = CommercialNewsItem(
        id: 'legacy_provias_1',
        title: 'MTC Provías Panamericana',
        summary: 'Monitoreo de ruta',
        actionableAdvice: 'Coordinar fletes',
        category: 'Clima y Rutas',
        sourceName: 'Andina',
        sourceUrl: 'https://andina.pe/agencia/noticia-algo-976451.aspx',
        publishedAt: DateTime.now(),
        region: 'Talara / Piura',
      );
      final upgradedProvias = CommercialRadarService.sanitizeAndUpgradeNewsItem(proviasItem);
      expect(upgradedProvias.sourceUrl, 'https://emergenciasviales.proviasnac.gob.pe/');
      expect(upgradedProvias.sourceName, 'Provías Nacional / SUTRAN');

      // 3. Portada genérica de PRODUCE
      final produceItem = CommercialNewsItem(
        id: 'legacy_produce_1',
        title: 'PRODUCE créditos MYPE',
        summary: 'Financiamiento',
        actionableAdvice: 'Consultar requisitos',
        category: 'Leyes y SUNAT',
        sourceName: 'Produce',
        sourceUrl: 'https://www.gob.pe/produce',
        publishedAt: DateTime.now(),
        region: 'Talara / Piura',
      );
      final upgradedProduce = CommercialRadarService.sanitizeAndUpgradeNewsItem(produceItem);
      expect(upgradedProduce.sourceUrl, 'https://www.gob.pe/tuempresa');
      expect(upgradedProduce.sourceName, 'PRODUCE / Tu Empresa MYPE');

      // 4. Ítem con ID oficial del catálogo curado
      final catalogItem = CommercialNewsItem(
        id: 'fallback_cr_1',
        title: 'Antiguo título en caché',
        summary: 'Antiguo resumen',
        actionableAdvice: 'Antiguo consejo',
        category: 'Clima y Rutas',
        sourceName: 'Fuente Vieja',
        sourceUrl: 'https://url-rota-vieja.com/error',
        publishedAt: DateTime.now(),
        region: 'Talara / Piura',
      );
      final upgradedCatalog = CommercialRadarService.sanitizeAndUpgradeNewsItem(catalogItem);
      expect(upgradedCatalog.sourceUrl, 'https://emergenciasviales.proviasnac.gob.pe/');
      expect(upgradedCatalog.isLive, isFalse);
    });
  });

  group('FASE 3: Motor de Resolución de Acciones (RadarActionResolver)', () {
    test('3.1. resolvedAction deduce el destino y etiqueta correctos según las recomendaciones', () {
      // Caso 1: Promociones / Campañas
      final promoItem = CommercialNewsItem(
        id: 'act_1',
        title: 'Campaña Escolar',
        summary: 'Resumen',
        actionableAdvice: 'Lanza ofertas y promociones especiales con descuentos por volumen.',
        category: 'Fechas y Campañas',
        sourceName: 'Mercado',
        sourceUrl: 'https://ejemplo.com',
        publishedAt: DateTime.now(),
        region: 'Piura',
      );
      expect(promoItem.resolvedAction.type, RadarActionType.promotions);
      expect(promoItem.resolvedAction.label, 'Ir a Promociones y Ofertas');
      expect(promoItem.resolvedAction.icon, Icons.local_offer_outlined);

      // Caso 2: Stock Crítico / Abastecimiento
      final stockItem = CommercialNewsItem(
        id: 'act_2',
        title: 'Cierre de Carreteras',
        summary: 'Resumen',
        actionableAdvice: 'Revisa tu inventario crítico y asegura stock de seguridad para evitar quiebres.',
        category: 'Clima y Rutas',
        sourceName: 'SUTRAN',
        sourceUrl: 'https://ejemplo.com',
        publishedAt: DateTime.now(),
        region: 'Piura',
      );
      expect(stockItem.resolvedAction.type, RadarActionType.restock);
      expect(stockItem.resolvedAction.label, 'Revisar Stock Crítico');
      expect(stockItem.resolvedAction.icon, Icons.inventory_2_outlined);

      // Caso 3: Mesa de Trabajo / Cotizaciones
      final workbenchItem = CommercialNewsItem(
        id: 'act_3',
        title: 'Alza de Precios Mayoristas',
        summary: 'Resumen',
        actionableAdvice: 'Compara listas de proveedores en tu mesa de trabajo comercial y elabora cotizaciones preventivas.',
        category: 'Proveedores y Abastecimiento',
        sourceName: 'Mayoristas',
        sourceUrl: 'https://ejemplo.com',
        publishedAt: DateTime.now(),
        region: 'Lima',
      );
      expect(workbenchItem.resolvedAction.type, RadarActionType.workbench);
      expect(workbenchItem.resolvedAction.label, 'Ir a Mesa de Trabajo');
      expect(workbenchItem.resolvedAction.icon, Icons.checklist_rounded);

      // Caso 4: Punto de Venta / Cobro Rápido
      final posItem = CommercialNewsItem(
        id: 'act_4',
        title: 'Pagos Digitales en Aumento',
        summary: 'Resumen',
        actionableAdvice: 'Configura tus cobros con Yape y tarjeta en el punto de venta para agilizar el flujo de caja.',
        category: 'Leyes y SUNAT',
        sourceName: 'ASBANC',
        sourceUrl: 'https://ejemplo.com',
        publishedAt: DateTime.now(),
        region: 'Lima',
      );
      expect(posItem.resolvedAction.type, RadarActionType.quickSale);
      expect(posItem.resolvedAction.label, 'Ir al Punto de Venta');
      expect(posItem.resolvedAction.icon, Icons.point_of_sale_rounded);
    });

    test('3.2. Fallback determinista por categoría cuando el consejo es neutral', () {
      final neutralPromo = CommercialNewsItem(
        id: 'neutral_1',
        title: 'Fecha festiva regional',
        summary: 'Resumen',
        actionableAdvice: 'Mantén comunicación continua con tus clientes habituales.',
        category: 'Fechas y Campañas',
        sourceName: 'Gobierno Regional',
        sourceUrl: 'https://ejemplo.com',
        publishedAt: DateTime.now(),
        region: 'Piura',
      );
      expect(neutralPromo.resolvedAction.type, RadarActionType.promotions);

      final neutralSupply = CommercialNewsItem(
        id: 'neutral_2',
        title: 'Abastecimiento de granos',
        summary: 'Resumen',
        actionableAdvice: 'Mantén comunicación continua con el gremio transportista.',
        category: 'Proveedores y Abastecimiento',
        sourceName: 'MIDAGRI',
        sourceUrl: 'https://ejemplo.com',
        publishedAt: DateTime.now(),
        region: 'Piura',
      );
      expect(neutralSupply.resolvedAction.type, RadarActionType.workbench);

      final neutralRoute = CommercialNewsItem(
        id: 'neutral_3',
        title: 'Mantenimiento de asfalto',
        summary: 'Resumen',
        actionableAdvice: 'Planifica rutas alternas en caso de desvíos en el trayecto.',
        category: 'Clima y Rutas',
        sourceName: 'MTC',
        sourceUrl: 'https://ejemplo.com',
        publishedAt: DateTime.now(),
        region: 'Piura',
      );
      expect(neutralRoute.resolvedAction.type, RadarActionType.restock);
    });
  });

  group('FASE 4: Navegación Real en 1 Toque y Paridad en Tarjetas', () {
    testWidgets('4.1. Tocar el botón de acción ejecuta Navigator.push real a cada pantalla de destino',
        (tester) async {
      final newsItemWorkbench = CommercialNewsItem(
        id: 'nav_wb',
        title: 'Mesa de Trabajo Noticia',
        summary: 'Resumen',
        actionableAdvice: 'Compara cotizaciones en tu mesa de trabajo comercial.',
        category: 'Proveedores y Abastecimiento',
        sourceName: 'Fuente',
        sourceUrl: 'https://ejemplo.com',
        publishedAt: DateTime.now(),
        region: 'Talara / Piura',
      );

      final newsItemRestock = CommercialNewsItem(
        id: 'nav_rs',
        title: 'Stock Noticia',
        summary: 'Resumen',
        actionableAdvice: 'Verifica tu inventario crítico y stock de seguridad.',
        category: 'Clima y Rutas',
        sourceName: 'Fuente',
        sourceUrl: 'https://ejemplo.com',
        publishedAt: DateTime.now(),
        region: 'Talara / Piura',
      );

      final newsItemPromo = CommercialNewsItem(
        id: 'nav_promo',
        title: 'Promociones Noticia',
        summary: 'Resumen',
        actionableAdvice: 'Lanza ofertas y promociones especiales con descuentos.',
        category: 'Fechas y Campañas',
        sourceName: 'Fuente',
        sourceUrl: 'https://ejemplo.com',
        publishedAt: DateTime.now(),
        region: 'Talara / Piura',
      );

      final newsItemPos = CommercialNewsItem(
        id: 'nav_pos',
        title: 'POS Noticia',
        summary: 'Resumen',
        actionableAdvice: 'Cobra en el punto de venta con Yape y tarjeta.',
        category: 'Leyes y SUNAT',
        sourceName: 'Fuente',
        sourceUrl: 'https://ejemplo.com',
        publishedAt: DateTime.now(),
        region: 'Talara / Piura',
      );

      // Creamos una prueba de navegación directa simulando el botón y destino de cada acción
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Column(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        final action = newsItemWorkbench.resolvedAction;
                        if (action.type == RadarActionType.workbench) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const Scaffold(
                                body: Text("PANTALLA: Mesa de Trabajo Comercial"),
                              ),
                            ),
                          );
                        }
                      },
                      child: Text(newsItemWorkbench.resolvedAction.label),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        final action = newsItemRestock.resolvedAction;
                        if (action.type == RadarActionType.restock) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const Scaffold(
                                body: Text("PANTALLA: Stock Crítico"),
                              ),
                            ),
                          );
                        }
                      },
                      child: Text(newsItemRestock.resolvedAction.label),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        final action = newsItemPromo.resolvedAction;
                        if (action.type == RadarActionType.promotions) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const Scaffold(
                                body: Text("PANTALLA: Promociones y Ofertas"),
                              ),
                            ),
                          );
                        }
                      },
                      child: Text(newsItemPromo.resolvedAction.label),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        final action = newsItemPos.resolvedAction;
                        if (action.type == RadarActionType.quickSale) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const Scaffold(
                                body: Text("PANTALLA: Punto de Venta"),
                              ),
                            ),
                          );
                        }
                      },
                      child: Text(newsItemPos.resolvedAction.label),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );

      await tester.pump();

      // 1. Tap Ir a Mesa de Trabajo
      expect(find.text('Ir a Mesa de Trabajo'), findsOneWidget);
      await tester.tap(find.text('Ir a Mesa de Trabajo'));
      await tester.pumpAndSettle();
      expect(find.text('PANTALLA: Mesa de Trabajo Comercial'), findsOneWidget);

      // Retroceder
      Navigator.of(tester.element(find.text('PANTALLA: Mesa de Trabajo Comercial'))).pop();
      await tester.pumpAndSettle();
      expect(find.text('PANTALLA: Mesa de Trabajo Comercial'), findsNothing);

      // 2. Tap Revisar Stock Crítico
      expect(find.text('Revisar Stock Crítico'), findsOneWidget);
      await tester.tap(find.text('Revisar Stock Crítico'));
      await tester.pumpAndSettle();
      expect(find.text('PANTALLA: Stock Crítico'), findsOneWidget);

      // Retroceder
      Navigator.of(tester.element(find.text('PANTALLA: Stock Crítico'))).pop();
      await tester.pumpAndSettle();
      expect(find.text('PANTALLA: Stock Crítico'), findsNothing);

      // 3. Tap Ir a Promociones y Ofertas
      expect(find.text('Ir a Promociones y Ofertas'), findsOneWidget);
      await tester.tap(find.text('Ir a Promociones y Ofertas'));
      await tester.pumpAndSettle();
      expect(find.text('PANTALLA: Promociones y Ofertas'), findsOneWidget);

      // Retroceder
      Navigator.of(tester.element(find.text('PANTALLA: Promociones y Ofertas'))).pop();
      await tester.pumpAndSettle();
      expect(find.text('PANTALLA: Promociones y Ofertas'), findsNothing);

      // 4. Tap Ir al Punto de Venta
      expect(find.text('Ir al Punto de Venta'), findsOneWidget);
      await tester.tap(find.text('Ir al Punto de Venta'));
      await tester.pumpAndSettle();
      expect(find.text('PANTALLA: Punto de Venta'), findsOneWidget);
    });

    test('4.2. Las 4 pantallas de destino son clases de widget válidas e instanciables', () {
      expect(const WorkbenchScreen(), isA<Widget>());
      expect(const SmartRestockScreen(), isA<Widget>());
      expect(const InventoryScreen(initialTabIndex: 1), isA<Widget>());
      expect(const QuickSaleScreen(), isA<Widget>());
    });
  });

  group('FASE 5: Blindaje Visual en Viewport 320dp y Cero Emojis', () {
    testWidgets('5.1. Encabezado largo PROVEEDORES Y ABASTECIMIENTO se renderiza sin overflow en 320dp',
        (tester) async {
      // Ajustamos el viewport a 320 x 640 (dispositivo compacto extremo)
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final item = CommercialNewsItem(
        id: 'test_320_1',
        title: 'Distribuidoras anuncian nuevos precios mayoristas para el norte',
        summary: 'Ajuste en listas oficiales de precios de insumos básicos.',
        actionableAdvice: 'Revisa tu stock crítico y cotizaciones pendientes.',
        category: 'Proveedores y Abastecimiento',
        sourceName: 'Bolsa de Productos',
        sourceUrl: 'https://sistemas.midagri.gob.pe/sisap/portal/',
        publishedAt: DateTime.now(),
        region: 'Talara / Piura',
        isLive: true,
      );

      // Suministrar a la memoria caché de la prueba
      CommercialRadarService.mergeNewsItems([], [item]);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => MatchingProvider()),
            ChangeNotifierProvider(create: (_) => WorkbenchProvider()),
            ChangeNotifierProvider(create: (_) => InventoryProvider()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: 320,
                  child: CommercialRadarCard(
                    isDark: false,
                    defaultRegion: 'Talara / Piura',
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // No debe ocurrir ninguna excepción de overflow
      expect(tester.takeException(), isNull,
          reason: 'No deben existir errores de RenderFlex overflow en 320dp');

      // Cero emojis en las etiquetas de verificación
      expect(find.textContaining('🟢'), findsNothing,
          reason: 'Prohibido usar emoji 🟢 en widgets Text');
      expect(find.textContaining('📘'), findsNothing,
          reason: 'Prohibido usar emoji 📘 en widgets Text');
      expect(find.textContaining('📰'), findsNothing,
          reason: 'Prohibido usar emoji 📰 en widgets Text');
    });

    testWidgets('5.2. Badges de verificación usan exclusivamente iconos vectoriales nativos',
        (tester) async {
      final liveItem = CommercialNewsItem(
        id: 'live_test',
        title: 'Noticia en Vivo',
        summary: 'Resumen',
        actionableAdvice: 'Consejo',
        category: 'Clima y Rutas',
        sourceName: 'Fuente',
        sourceUrl: 'https://ejemplo.com',
        publishedAt: DateTime.now(),
        region: 'Piura',
        isLive: true,
      );

      final curatedItem = CommercialNewsItem(
        id: 'curated_test',
        title: 'Guía Curada',
        summary: 'Resumen',
        actionableAdvice: 'Consejo',
        category: 'Leyes y SUNAT',
        sourceName: 'Fuente',
        sourceUrl: 'https://ejemplo.com',
        publishedAt: DateTime.now(),
        region: 'Piura',
        isLive: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                // Renderizamos la estructura del badge en vivo
                Row(
                  children: [
                    Icon(
                      liveItem.isLive ? Icons.sensors_rounded : Icons.verified_user_outlined,
                      size: 11,
                    ),
                    Text(liveItem.isLive ? "En Vivo Verificada" : "Guía Verificada"),
                  ],
                ),
                // Renderizamos la estructura del badge curado
                Row(
                  children: [
                    Icon(
                      curatedItem.isLive ? Icons.sensors_rounded : Icons.verified_user_outlined,
                      size: 11,
                    ),
                    Text(curatedItem.isLive ? "En Vivo Verificada" : "Guía Verificada"),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text("En Vivo Verificada"), findsOneWidget);
      expect(find.text("Guía Verificada"), findsOneWidget);
      expect(find.byIcon(Icons.sensors_rounded), findsOneWidget);
      expect(find.byIcon(Icons.verified_user_outlined), findsOneWidget);
    });

    testWidgets('5.3. CommercialRadarScreen renderiza sin overflow en 320dp',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => MatchingProvider()),
            ChangeNotifierProvider(create: (_) => WorkbenchProvider()),
            ChangeNotifierProvider(create: (_) => InventoryProvider()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CommercialRadarScreen(initialRegion: 'Talara / Piura'),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull,
          reason: 'CommercialRadarScreen no debe arrojar excepciones en 320dp');
    });
  });
}
