import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/providers/notification_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/workbench_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/core/services/lifecycle_resume_coordinator.dart';
import 'package:app_movil/core/services/splash_prewarm_coordinator.dart';
import 'package:app_movil/core/services/splash_rotation_manager.dart';
import 'package:app_movil/core/widgets/brand/mochila_brand_medallion.dart';
import 'package:app_movil/core/screens/splash/cold_start_splash_screen.dart';
import 'package:app_movil/core/widgets/home/dashboard_header.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    LifecycleResumeCoordinator.instance.resetForTesting();
    SplashPrewarmCoordinator.instance.resetForTesting();
    await SplashRotationManager.instance.resetForTesting();
  });

  group('TEST 1: LifecycleResumeCoordinator - Cooldown, Diferimiento y Gestión de Tickers', () {
    testWidgets('Respeta el cooldown de 30s: No dispara sincronización si estuvo en background < 30s', (tester) async {
      final coordinator = LifecycleResumeCoordinator.instance;
      bool syncTriggered = false;

      // Iniciar app en un contexto de widget mínimo
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  // Pausado hace 10 segundos (< 30s)
                  coordinator.setPausedTimeForTesting(DateTime.now().subtract(const Duration(seconds: 10)));
                  coordinator.onAppResumed(
                    context,
                    onPostTransitionSync: () {
                      syncTriggered = true;
                    },
                  );
                },
                child: const Text('Resume'),
              );
            },
          ),
        ),
      );

      // Simular resumed
      await tester.tap(find.text('Resume'));
      await tester.pump();

      // Avanzar el diferimiento post-transición (450ms)
      await tester.pump(const Duration(milliseconds: 500));

      expect(syncTriggered, isFalse, reason: 'No debe disparar sync si la pausa fue menor a 30s');
    });

    testWidgets('Difiere a 450ms y dispara sincronización si estuvo en background >= 30s', (tester) async {
      final coordinator = LifecycleResumeCoordinator.instance;
      bool syncTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  // Pausado hace 35 segundos (>= 30s)
                  coordinator.setPausedTimeForTesting(DateTime.now().subtract(const Duration(seconds: 35)));
                  coordinator.onAppResumed(
                    context,
                    onPostTransitionSync: () {
                      syncTriggered = true;
                    },
                  );
                },
                child: const Text('Resume'),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('Resume'));
      await tester.pump();

      // Antes de los 450ms: la sincronización no debe haberse ejecutado aún
      await tester.pump(const Duration(milliseconds: 200));
      expect(syncTriggered, isFalse, reason: 'Debe estar diferido durante la animación de ventana');

      // Después de los 450ms: la sincronización debe haberse ejecutado
      await tester.pump(const Duration(milliseconds: 300));
      expect(syncTriggered, isTrue, reason: 'Debe disparar sync tras concluir los 450ms');
    });

    testWidgets('Pausa AnimationControllers en onAppPaused y los reanuda a los 450ms de onAppResumed', (tester) async {
      final coordinator = LifecycleResumeCoordinator.instance;
      late AnimationController testController;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return _TickerTestWidget(
                onControllerCreated: (c) {
                  testController = c;
                  coordinator.registerController(c);
                },
              );
            },
          ),
        ),
      );

      expect(testController.isAnimating, isTrue);

      // Pausar
      final element = tester.element(find.byType(_TickerTestWidget));
      coordinator.onAppPaused(element);
      expect(testController.isAnimating, isFalse, reason: 'Debe pausarse inmediatamente al pasar a background');

      // Reanudar (hace 5 segundos)
      coordinator.setPausedTimeForTesting(DateTime.now().subtract(const Duration(seconds: 5)));
      coordinator.onAppResumed(element);

      // Aún no reanuda antes de 450ms
      await tester.pump(const Duration(milliseconds: 200));
      expect(testController.isAnimating, isFalse);

      // Reanuda pasados los 450ms
      await tester.pump(const Duration(milliseconds: 300));
      expect(testController.isAnimating, isTrue, reason: 'Debe volver a animar pasados los 450ms');

      coordinator.unregisterController(testController);
    });

    test('Caché en RAM de configuración de PIN se actualiza y mantiene sin IPC nativo', () {
      final coordinator = LifecycleResumeCoordinator.instance;
      expect(coordinator.cachedPinDelayMinutes, equals(1));

      coordinator.updateCachedPinDelay(5);
      expect(coordinator.cachedPinDelayMinutes, equals(5));

      coordinator.updateCachedPinDelay(0);
      expect(coordinator.cachedPinDelayMinutes, equals(0));
    });

    test('prefetchPinConfig precarga configuración de PIN desde SharedPreferences a RAM', () async {
      final coordinator = LifecycleResumeCoordinator.instance;
      SharedPreferences.setMockInitialValues({'pin_delay_minutes': 15});

      await coordinator.prefetchPinConfig();
      expect(coordinator.cachedPinDelayMinutes, equals(15));
    });
  });

  group('TEST 2: Estabilidad de Altura (0.0px de Variación) en DashboardHeader', () {
    testWidgets('DashboardHeader memoriza _stableTopInset y mantiene exactamente la misma altura cuando padding.top varía de 44 a 0', (tester) async {
      // 1. Primer render con barra de estado activa (padding.top = 44.0)
      tester.view.padding = const FakeViewPadding(top: 44.0, bottom: 20.0);
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AuthProvider()),
            ChangeNotifierProvider(create: (_) => NotificationProvider()),
            ChangeNotifierProvider(create: (_) => WorkbenchProvider()),
            ChangeNotifierProvider(create: (_) => SaleProvider()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: DashboardHeader(),
            ),
          ),
        ),
      );
      await tester.pump();

      final firstHeaderFinder = find.byType(DashboardHeader);
      expect(firstHeaderFinder, findsOneWidget);
      final double initialHeight = tester.getSize(firstHeaderFinder).height;
      expect(initialHeight, greaterThan(100.0));

      // 2. Simular cambio métrico de Android en Multitarea (padding.top = 0.0)
      tester.view.padding = const FakeViewPadding(top: 0.0, bottom: 0.0);
      await tester.pump();

      final double recentAppsHeight = tester.getSize(firstHeaderFinder).height;

      // 🛡️ REGLA DE ORO: Altura exactamente idéntica, 0.0px de fluctuación
      expect(
        recentAppsHeight,
        equals(initialHeight),
        reason: 'DashboardHeader debe memorizar _stableTopInset y no variar ni 0.1px en Multitarea',
      );

      // Restaurar padding
      addTearDown(() {
        tester.view.resetPadding();
        tester.view.resetPhysicalSize();
      });
    });
  });

  group('TEST 3: SplashRotationManager - Garantía Doble Nivel (6 Arquetipos y 18 Variaciones Únicas)', () {
    test('En 6 aperturas consecutivas entrega los 6 Arquetipos Base sin repetición', () async {
      final manager = SplashRotationManager.instance;
      await manager.resetForTesting();

      final Set<int> seenArchetypes = {};
      for (int i = 0; i < 6; i++) {
        final config = await manager.selectNextVariant();
        expect(
          seenArchetypes.contains(config.archetypeIndex),
          isFalse,
          reason: 'El arquetipo ${config.archetypeIndex} se repitió en la ronda de 6 aperturas',
        );
        seenArchetypes.add(config.archetypeIndex);
      }

      expect(seenArchetypes.length, equals(6));
      expect(seenArchetypes, equals({1, 2, 3, 4, 5, 6}));
    });

    test('En 18 aperturas consecutivas entrega las 18 variaciones únicas sin exclusiones (1A a 6C)', () async {
      final manager = SplashRotationManager.instance;
      await manager.resetForTesting();

      final Set<String> seenTokens = {};
      for (int i = 0; i < 18; i++) {
        final config = await manager.selectNextVariant();
        expect(
          seenTokens.contains(config.token),
          isFalse,
          reason: 'La variación ${config.token} se repitió antes de agotar las 18',
        );
        seenTokens.add(config.token);
      }

      expect(seenTokens.length, equals(18));
      expect(seenTokens, containsAll(SplashRotationManager.all18Tokens));
    });
  });

  group('TEST 4: Priorización Contextual y Píldora Informativa con Propósito Real', () {
    test('Prioriza Matriz Logística o Radar cuando hay alertas de stock activas', () async {
      final manager = SplashRotationManager.instance;
      await manager.resetForTesting();

      const snapshot = HomePrewarmSnapshot(
        activeAlertCount: 14,
        pendingQuotesCount: 0,
        todaySalesTotal: 0.0,
        hasActiveContext: true,
        isReady: true,
      );

      final config = await manager.selectNextVariant(snapshot: snapshot);
      expect(config.archetypeIndex == 3 || config.archetypeIndex == 1, isTrue);
      expect(config.capsuleText, contains('14 alertas de stock'));
      expect(config.capsuleText.contains('⚠️'), isFalse, reason: 'Debe usar iconos vectoriales y 0 emojis');
    });

    test('Prioriza Ecosistema o Escáner IA cuando hay cotizaciones pendientes', () async {
      final manager = SplashRotationManager.instance;
      await manager.resetForTesting();

      const snapshot = HomePrewarmSnapshot(
        activeAlertCount: 0,
        pendingQuotesCount: 7,
        todaySalesTotal: 0.0,
        hasActiveContext: true,
        isReady: true,
      );

      final config = await manager.selectNextVariant(snapshot: snapshot);
      expect(config.archetypeIndex == 6 || config.archetypeIndex == 4, isTrue);
      expect(config.capsuleText, contains('7 cotizaciones'));
    });
  });

  group('TEST 5: Renderizado y Zero-Overflows en 18 Variaciones de ColdStartSplashScreen y MochilaBrandMedallion', () {
    for (final token in SplashRotationManager.all18Tokens) {
      testWidgets('Renderiza sin overflow variante $token en pantalla compacta (320x568 dp)', (tester) async {
        tester.view.physicalSize = const Size(320 * 2.0, 568 * 2.0);
        tester.view.devicePixelRatio = 2.0;

        await tester.pumpWidget(
          MaterialApp(
            home: ColdStartSplashScreen(
              forcedToken: token,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // Verificar que el Medallón y el título existen
        expect(find.byType(MochilaBrandMedallion), findsOneWidget);
        expect(find.text("MochilaLista"), findsOneWidget);

        // Verificar que no hay errores de desbordamiento (OverflowBox o A RenderFlex overflowed)
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('MochilaBrandMedallion se renderiza nítidamente a 104dp sin parches rectangulares', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: MochilaBrandMedallion(
                size: 104,
                accentColor: Color(0xFF38BDF8),
                isDark: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(MochilaBrandMedallion), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}

class _TickerTestWidget extends StatefulWidget {
  final ValueChanged<AnimationController> onControllerCreated;

  const _TickerTestWidget({required this.onControllerCreated});

  @override
  State<_TickerTestWidget> createState() => _TickerTestWidgetState();
}

class _TickerTestWidgetState extends State<_TickerTestWidget> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
    widget.onControllerCreated(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox();
  }
}
