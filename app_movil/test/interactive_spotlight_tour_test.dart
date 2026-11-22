import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';
import 'package:app_movil/core/widgets/tour/coach_card_widget.dart';
import 'package:app_movil/core/widgets/tour/interactive_tour_overlay.dart';
import 'package:app_movil/core/widgets/tour/spotlight_painter.dart';
import 'package:app_movil/core/services/tour/interactive_tour_service.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    InteractiveTourService.autoTriggerOverrideForTesting = null;
    InteractiveTourService.resetRuntimeLockForTesting();
  });

  tearDown(() {
    InteractiveTourService.autoTriggerOverrideForTesting = null;
    InteractiveTourService.resetRuntimeLockForTesting();
  });

  group('1. Matemática Pura y Responsividad de Tarjeta / Flecha (0px Overflow)', () {
    test('Calculador de layout decide placement below cuando hay espacio inferior', () {
      final res = CoachCardLayoutCalculator.compute(
        viewportSize: const Size(360, 640),
        viewPadding: const EdgeInsets.only(top: 24, bottom: 48),
        viewInsets: EdgeInsets.zero,
        targetRect: const Rect.fromLTWH(20, 60, 120, 40),
      );

      expect(res.placement, equals(CoachCardPlacement.below));
      expect(res.showArrow, isTrue);
      expect(res.cardTop, greaterThan(100.0));
      expect(res.arrowCenterX, inInclusiveRange(res.cardLeft + 24.0, res.cardLeft + res.cardWidth - 24.0));
    });

    test('Calculador de layout decide placement above cuando el target está abajo', () {
      final res = CoachCardLayoutCalculator.compute(
        viewportSize: const Size(360, 640),
        viewPadding: const EdgeInsets.only(top: 24, bottom: 48),
        viewInsets: EdgeInsets.zero,
        targetRect: const Rect.fromLTWH(20, 520, 120, 40),
      );

      expect(res.placement, equals(CoachCardPlacement.above));
      expect(res.showArrow, isTrue);
      expect(res.cardTop, lessThan(520.0));
      expect(res.arrowCenterX, inInclusiveRange(res.cardLeft + 24.0, res.cardLeft + res.cardWidth - 24.0));
    });

    test('Calculador decide centerOverlay sin flecha cuando el target abarca la pantalla', () {
      final res = CoachCardLayoutCalculator.compute(
        viewportSize: const Size(360, 640),
        viewPadding: const EdgeInsets.only(top: 24, bottom: 48),
        viewInsets: EdgeInsets.zero,
        targetRect: const Rect.fromLTWH(20, 120, 320, 400),
      );

      expect(res.placement, equals(CoachCardPlacement.centerOverlay));
      expect(res.showArrow, isFalse);
    });

    test('Flecha direccional se acota estrictamente dentro de los márgenes de la tarjeta', () {
      // Target muy a la izquierda
      final resLeft = CoachCardLayoutCalculator.compute(
        viewportSize: const Size(360, 640),
        viewPadding: const EdgeInsets.only(top: 24, bottom: 48),
        viewInsets: EdgeInsets.zero,
        targetRect: const Rect.fromLTWH(2, 60, 20, 40),
      );
      expect(resLeft.arrowCenterX, equals(resLeft.cardLeft + 24.0));

      // Target muy a la derecha
      final resRight = CoachCardLayoutCalculator.compute(
        viewportSize: const Size(360, 640),
        viewPadding: const EdgeInsets.only(top: 24, bottom: 48),
        viewInsets: EdgeInsets.zero,
        targetRect: const Rect.fromLTWH(340, 60, 20, 40),
      );
      expect(resRight.arrowCenterX, equals(resRight.cardLeft + resRight.cardWidth - 24.0));
    });

    // Pruebas de 0px overflow en pantallas reales con text scaling 1.3
    final testSizes = [
      const Size(320, 568),
      const Size(360, 640),
      const Size(412, 915),
    ];

    for (final size in testSizes) {
      testWidgets('CoachCardWidget renderiza sin overflow en ${size.width}x${size.height} con escala 1.3', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final step = TourStep(
          id: 'test_step',
          targetKey: GlobalKey(),
          title: 'Título Completo de Prueba para Evaluación de Responsividad',
          description:
              'Descripción detallada y extensa para verificar que el contenido se envuelve en un scroll seguro y los botones de acción nunca se cortan ni generan desbordamientos gráficos.',
          tip: 'Consejo importante con texto explicativo para el usuario del negocio.',
          icon: Icons.storefront_rounded,
        );

        final layout = CoachCardLayoutCalculator.compute(
          viewportSize: size,
          viewPadding: const EdgeInsets.only(top: 24, bottom: 48),
          viewInsets: EdgeInsets.zero,
          targetRect: Rect.fromLTWH(size.width / 2.0 - 50, 100, 100, 50),
        );

        await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(1.3),
              viewPadding: EdgeInsets.only(bottom: 48),
            ),
            child: Scaffold(
              body: CoachCardWidget(
                step: step,
                currentIndex: 1, // Verifica con botón Anterior y Siguiente simultáneamente
                totalSteps: 3,
                layout: layout,
                onPrevious: () {},
                onNext: () {},
                onClose: () {},
              ),
            ),
          ),
        ));

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('2 / 3'), findsOneWidget);
        expect(find.text('Anterior'), findsOneWidget);
        expect(find.text('Siguiente'), findsOneWidget);
      });
    }
  });

  group('2. Flujo de Bienvenida, Navegación y Supresión en InteractiveTourOverlay', () {
    testWidgets('Modal de bienvenida permite "Omitir" marcando la pantalla como vista', (tester) async {
      final config = ScreenTourConfig(
        screenId: 'test_screen',
        screenTitle: 'Pantalla de Prueba',
        welcomeSummary: 'Resumen conciso del objetivo de la pantalla para nuevos comerciantes.',
        steps: [
          TourStep(
            id: 's1',
            targetKey: GlobalKey(),
            title: 'Paso 1',
            description: 'Desc 1',
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () => InteractiveTourOverlay.showWelcomeModal(ctx, config),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.text('Bienvenido a Pantalla de Prueba'), findsOneWidget);
      expect(find.text('Guíame'), findsOneWidget);

      // Tocar Omitir
      await tester.tap(find.text('Omitir'));
      await tester.pumpAndSettle();

      // Verificar que SharedPreferences guardó la pantalla como vista
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('tour_screen_seen_test_screen'), isTrue);
    });

    testWidgets('Enlace "Omitir todas las guías" desactiva los recorridos globales', (tester) async {
      final config = ScreenTourConfig(
        screenId: 'test_screen_global',
        screenTitle: 'Pantalla',
        welcomeSummary: 'Resumen',
        steps: [
          TourStep(id: 's1', targetKey: GlobalKey(), title: 'P1', description: 'D1'),
        ],
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () => InteractiveTourOverlay.showWelcomeModal(ctx, config),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Omitir todas las guías automáticas'));
      await tester.pumpAndSettle();

      final enabled = await InteractiveTourService.areAutomaticToursEnabled();
      expect(enabled, isFalse);
    });

    testWidgets('Recorrido paso a paso: avanza con Siguiente, retrocede con Anterior y cierra con ¡Listo!', (tester) async {
      final key1 = GlobalKey(debugLabel: 'k1');
      final key2 = GlobalKey(debugLabel: 'k2');
      bool completed = false;

      final config = ScreenTourConfig(
        screenId: 'nav_screen',
        screenTitle: 'Nav Screen',
        welcomeSummary: 'Summary',
        steps: [
          TourStep(
            id: 'step_1',
            targetKey: key1,
            title: 'Primer Elemento',
            description: 'Descripción del primer paso',
          ),
          TourStep(
            id: 'step_2',
            targetKey: key2,
            title: 'Segundo Elemento',
            description: 'Descripción del segundo paso',
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Container(key: key1, width: 100, height: 40, color: Colors.blue),
              const SizedBox(height: 50),
              Container(key: key2, width: 100, height: 40, color: Colors.green),
              Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => InteractiveTourOverlay.startTour(
                    ctx,
                    config,
                    onCompleted: () => completed = true,
                  ),
                  child: const Text('Iniciar Tour'),
                ),
              ),
            ],
          ),
        ),
      ));

      await tester.tap(find.text('Iniciar Tour'));
      await tester.pumpAndSettle();

      // Paso 1
      expect(find.text('Primer Elemento'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
      expect(find.text('Anterior'), findsNothing);

      // Avanzar al paso 2
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();

      // Paso 2 (último paso)
      expect(find.text('Segundo Elemento'), findsOneWidget);
      expect(find.text('2 / 2'), findsOneWidget);
      expect(find.text('Anterior'), findsOneWidget);
      expect(find.text('¡Listo!'), findsOneWidget);

      // Retroceder al paso 1
      await tester.tap(find.text('Anterior'));
      await tester.pumpAndSettle();
      expect(find.text('Primer Elemento'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);

      // Avanzar de nuevo y finalizar
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('¡Listo!'));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('tour_screen_seen_nav_screen'), isTrue);
    });
  });

  group('3. Hooks Dinámicos de Ciclo de Vida (onBeforeStep / onAfterStep)', () {
    testWidgets('Ejecuta onBeforeStep al enfocar y onAfterStep al avanzar', (tester) async {
      final key1 = GlobalKey();
      final key2 = GlobalKey();
      bool isSectionExpanded = false;

      final config = ScreenTourConfig(
        screenId: 'hooks_screen',
        screenTitle: 'Hooks',
        welcomeSummary: 'Summary',
        steps: [
          TourStep(
            id: 'step_accordion',
            targetKey: key1,
            title: 'Sección Colapsable',
            description: 'Esta sección se expande al enfocarla.',
            onBeforeStep: () async {
              isSectionExpanded = true;
            },
            onAfterStep: () async {
              isSectionExpanded = false;
            },
          ),
          TourStep(
            id: 'step_next',
            targetKey: key2,
            title: 'Siguiente Elemento',
            description: 'Sección final.',
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(key: key1, width: 80, height: 40),
              SizedBox(key: key2, width: 80, height: 40),
              Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => InteractiveTourOverlay.startTour(ctx, config),
                  child: const Text('Start'),
                ),
              ),
            ],
          ),
        ),
      ));

      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      // Al entrar al paso 1, onBeforeStep se ejecutó
      expect(isSectionExpanded, isTrue);

      // Al avanzar al paso 2, onAfterStep debió restaurar
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();
      expect(isSectionExpanded, isFalse);

      await tester.tap(find.text('¡Listo!'));
      await tester.pumpAndSettle();
    });
  });

  group('4. Supresión tras Restore vs Activación Manual en InfoTooltipButton', () {
    test('suppressAutomaticToursAfterRestore() suprime el disparo automático', () async {
      InteractiveTourService.autoTriggerOverrideForTesting = true;

      // Inicialmente debería permitir mostrar
      expect(await InteractiveTourService.shouldAutoShowTour('home_screen'), isTrue);

      // Simular restauración exitosa de respaldo
      await InteractiveTourService.suppressAutomaticToursAfterRestore();

      // Ya no debe mostrarse automáticamente
      expect(await InteractiveTourService.shouldAutoShowTour('home_screen'), isFalse);
    });

    testWidgets('InfoTooltipButton despliega "Iniciar guía interactiva paso a paso" y lanza el tour en vivo', (tester) async {
      bool tourLaunched = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: InfoTooltipButton(
              title: 'Ayuda de la Pantalla',
              description: 'Explicación general.',
              onStartInteractiveTour: () {
                tourLaunched = true;
              },
            ),
          ),
        ),
      ));

      // Tocar el botón de información ℹ️
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();

      expect(find.text('Ayuda de la Pantalla'), findsOneWidget);
      expect(find.text('Iniciar guía interactiva paso a paso'), findsOneWidget);

      // Tocar el botón de iniciar guía interactiva
      await tester.tap(find.text('Iniciar guía interactiva paso a paso'));
      await tester.pumpAndSettle();

      expect(tourLaunched, isTrue);
    });
  });

  group('5. Guardia de Tests de Entorno Seguro', () {
    test('En entorno de flutter_test normal sin override, shouldAutoShowTour es siempre false', () async {
      InteractiveTourService.autoTriggerOverrideForTesting = null;
      final result = await InteractiveTourService.shouldAutoShowTour('any_screen');
      expect(result, isFalse);
    });
  });

  group('6. Certificación Fase 1 - Mutex Atómico, Tarjeta-Flecha Soldada, Omisión 0x0 y Spotlight Acotado', () {
    testWidgets('Mutex Global Atómico continuo retiene candado desde bienvenida hasta ¡Listo! y bloquea tours concurrentes', (tester) async {
      InteractiveTourService.autoTriggerOverrideForTesting = true;
      InteractiveTourService.resetRuntimeLockForTesting();

      final keyA = GlobalKey();
      final keyB = GlobalKey();

      final configA = ScreenTourConfig(
        screenId: 'screen_a',
        screenTitle: 'Pantalla A',
        welcomeSummary: 'Summary A',
        steps: [
          TourStep(id: 'sA1', targetKey: keyA, title: 'Elemento A', description: 'Desc A'),
        ],
      );

      final configB = ScreenTourConfig(
        screenId: 'screen_b',
        screenTitle: 'Pantalla B',
        welcomeSummary: 'Summary B',
        steps: [
          TourStep(id: 'sB1', targetKey: keyB, title: 'Elemento B', description: 'Desc B'),
        ],
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SizedBox(key: keyA, width: 80, height: 40),
              SizedBox(key: keyB, width: 80, height: 40),
              Builder(
                builder: (ctx) => Column(
                  children: [
                    ElevatedButton(
                      onPressed: () => InteractiveTourService.maybeStartAutomaticTour(ctx, configA),
                      child: const Text('Launch A'),
                    ),
                    ElevatedButton(
                      onPressed: () => InteractiveTourService.maybeStartAutomaticTour(ctx, configB),
                      child: const Text('Launch B'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ));

      // 1. Disparar Screen A
      await tester.tap(find.text('Launch A'));
      await tester.pumpAndSettle();

      // Debe estar abierto el modal A y el candado activo
      expect(find.text('Bienvenido a Pantalla A'), findsOneWidget);
      expect(InteractiveTourService.isTourActive, isTrue);

      // 2. Intentar disparar Screen B concurrentemente (simulando IndexedStack en segundo plano)
      await InteractiveTourService.maybeStartAutomaticTour(
        tester.element(find.byType(Scaffold)),
        configB,
      );
      await tester.pumpAndSettle();

      // Modal B NO debe abrirse jamás porque el candado está retenido
      expect(find.text('Bienvenido a Pantalla B'), findsNothing);
      expect(find.text('Bienvenido a Pantalla A'), findsOneWidget);

      // 3. Tocar "Guíame" en A
      await tester.tap(find.text('Guíame'));
      await tester.pumpAndSettle();

      // El modal desaparece, el overlay se monta
      expect(find.text('Bienvenido a Pantalla A'), findsNothing);
      expect(find.text('Elemento A'), findsOneWidget);

      // CRÍTICO: El mutex DEBE seguir activo durante todo el recorrido
      expect(InteractiveTourService.isTourActive, isTrue);

      // Reintentar disparar B durante el recorrido activo
      await InteractiveTourService.maybeStartAutomaticTour(
        tester.element(find.byType(Scaffold)),
        configB,
      );
      await tester.pumpAndSettle();
      expect(find.text('Bienvenido a Pantalla B'), findsNothing);

      // 4. Cerrar el recorrido con ¡Listo!
      await tester.tap(find.text('¡Listo!'));
      await tester.pumpAndSettle();

      // Una vez cerrado, el candado se libera
      expect(InteractiveTourService.isTourActive, isFalse);
    });

    testWidgets('Bloque Soldado Tarjeta-Flecha en placement above elimina separación de 432px y se pega al target', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final step = TourStep(
        id: 'above_step',
        targetKey: GlobalKey(),
        title: 'Barra de Navegación Inferior',
        description: 'Explicación del elemento inferior.',
        icon: Icons.navigation_rounded,
      );

      // Target situado cerca del borde inferior (e.g. y = 520, height = 50)
      const targetRect = Rect.fromLTWH(30, 520, 100, 50);

      final layout = CoachCardLayoutCalculator.compute(
        viewportSize: const Size(360, 640),
        viewPadding: const EdgeInsets.only(top: 24, bottom: 48),
        viewInsets: EdgeInsets.zero,
        targetRect: targetRect,
      );

      expect(layout.placement, equals(CoachCardPlacement.above));
      expect(layout.showArrow, isTrue);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CoachCardWidget(
            step: step,
            currentIndex: 0,
            totalSteps: 1,
            layout: layout,
            onNext: () {},
            onClose: () {},
          ),
        ),
      ));

      await tester.pumpAndSettle();

      final cardFinder = find.byKey(const ValueKey('coach_card_body'));
      final arrowFinder = find.byKey(const ValueKey('coach_card_arrow'));

      expect(cardFinder, findsOneWidget);
      expect(arrowFinder, findsOneWidget);

      final cardRect = tester.getRect(cardFinder);
      final arrowRect = tester.getRect(arrowFinder);

      // 1. Cero separación entre cuerpo y flecha: (arrowRect.top - cardRect.bottom) <= 2px
      final gap = (arrowRect.top - cardRect.bottom).abs();
      expect(gap, lessThanOrEqualTo(2.0), reason: 'La flecha no puede desprenderse de la tarjeta');

      // 2. Ambos deben ubicarse por encima del targetRect.top (y = 520)
      expect(arrowRect.bottom, lessThanOrEqualTo(targetRect.top));
      expect(cardRect.bottom, lessThanOrEqualTo(targetRect.top));
    });

    testWidgets('Bloque Soldado Tarjeta-Flecha en placement below mantiene unión sólida', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final step = TourStep(
        id: 'below_step',
        targetKey: GlobalKey(),
        title: 'Elemento Superior',
        description: 'Explicación del elemento superior.',
        icon: Icons.star_rounded,
      );

      // Target situado arriba (e.g. y = 60, height = 40)
      const targetRect = Rect.fromLTWH(30, 60, 100, 40);

      final layout = CoachCardLayoutCalculator.compute(
        viewportSize: const Size(360, 640),
        viewPadding: const EdgeInsets.only(top: 24, bottom: 48),
        viewInsets: EdgeInsets.zero,
        targetRect: targetRect,
      );

      expect(layout.placement, equals(CoachCardPlacement.below));
      expect(layout.showArrow, isTrue);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CoachCardWidget(
            step: step,
            currentIndex: 0,
            totalSteps: 1,
            layout: layout,
            onNext: () {},
            onClose: () {},
          ),
        ),
      ));

      await tester.pumpAndSettle();

      final cardFinder = find.byKey(const ValueKey('coach_card_body'));
      final arrowFinder = find.byKey(const ValueKey('coach_card_arrow'));

      final cardRect = tester.getRect(cardFinder);
      final arrowRect = tester.getRect(arrowFinder);

      // Unión sólida en below: (cardRect.top - arrowRect.bottom) <= 2px
      final gap = (cardRect.top - arrowRect.bottom).abs();
      expect(gap, lessThanOrEqualTo(2.0));

      // Ambos deben ubicarse por debajo del targetRect.bottom (y = 100)
      expect(arrowRect.top, greaterThanOrEqualTo(targetRect.bottom));
      expect(cardRect.top, greaterThanOrEqualTo(targetRect.bottom));
    });

    testWidgets('Omisión automática de widgets invisibles o de dimensión < 12x12 (sin círculo vacío)', (tester) async {
      final keyInvisible = GlobalKey();
      final keyValid = GlobalKey();

      final config = ScreenTourConfig(
        screenId: 'skip_screen',
        screenTitle: 'Skip Screen',
        welcomeSummary: 'Summary',
        steps: [
          TourStep(
            id: 'step_zero',
            targetKey: keyInvisible,
            title: 'Elemento Invisible',
            description: 'No debe mostrarse',
          ),
          TourStep(
            id: 'step_valid',
            targetKey: keyValid,
            title: 'Elemento Válido',
            description: 'Debe enfocarse de inmediato',
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              SizedBox.shrink(key: keyInvisible), // 0x0
              Container(key: keyValid, width: 100, height: 40, color: Colors.blue),
              Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => InteractiveTourOverlay.startTour(ctx, config),
                  child: const Text('Start'),
                ),
              ),
            ],
          ),
        ),
      ));

      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();

      // El paso invisible debe omitirse automáticamente y caer de inmediato en el válido
      expect(find.text('Elemento Invisible'), findsNothing);
      expect(find.text('Elemento Válido'), findsOneWidget);
    });

    testWidgets('Acotamiento inteligente de spotlights gigantes a máximo 55% de la altura útil', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final keyGiant = GlobalKey();

      final config = ScreenTourConfig(
        screenId: 'giant_screen',
        screenTitle: 'Giant Screen',
        welcomeSummary: 'Summary',
        steps: [
          TourStep(
            id: 'step_giant',
            targetKey: keyGiant,
            title: 'Contenedor Gigante',
            description: 'Supera el 55% del viewport',
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(
              children: [
                Builder(
                  builder: (ctx) => ElevatedButton(
                    onPressed: () => InteractiveTourOverlay.startTour(ctx, config),
                    child: const Text('Start Giant'),
                  ),
                ),
                Container(
                  key: keyGiant,
                  width: 300,
                  height: 900, // Contenedor muy alto
                  color: Colors.purple,
                ),
              ],
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Start Giant'));
      await tester.pumpAndSettle();

      // Encontrar el CustomPaint con SpotlightPainter
      final customPaintFinder = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is SpotlightPainter,
      );
      expect(customPaintFinder, findsOneWidget);

      final customPaint = tester.widget<CustomPaint>(customPaintFinder);
      final painter = customPaint.painter as SpotlightPainter;

      // El targetRect iluminado no debe superar el 55% de la altura (600 * 0.55 = 330)
      expect(painter.targetRect.height, lessThanOrEqualTo(600 * 0.55));
    });

    testWidgets('Título de CoachCardWidget soporta maxLines: 2 sin overflow ni truncado anticipado', (tester) async {
      final step = TourStep(
        id: 'multiline_title',
        targetKey: GlobalKey(),
        title: 'Respaldo Seguro en Google Drive y Cifrado AES-256',
        description: 'Verificando que los títulos largos no se corten con elipsis en la primera línea.',
        icon: Icons.cloud_done_rounded,
      );

      final layout = CoachCardLayoutCalculator.compute(
        viewportSize: const Size(360, 640),
        viewPadding: const EdgeInsets.only(top: 24, bottom: 48),
        viewInsets: EdgeInsets.zero,
        targetRect: const Rect.fromLTWH(50, 100, 100, 40),
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: CoachCardWidget(
            step: step,
            currentIndex: 0,
            totalSteps: 1,
            layout: layout,
            onNext: () {},
            onClose: () {},
          ),
        ),
      ));

      await tester.pumpAndSettle();

      // Verificar que el widget Text del título tiene maxLines == 2
      final titleFinder = find.text('Respaldo Seguro en Google Drive y Cifrado AES-256');
      expect(titleFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(titleFinder);
      expect(textWidget.maxLines, equals(2));
    });
  });
}
