import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/core/widgets/smart_dropdown_search.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('🛡️ BLINDAJE DE MODALES: SafeArea, Ghost Bar y Espacio Inferior Defensivo', () {
    test('Constantes de blindaje cumplen cotas mínimas de seguridad ergonómica', () {
      expect(InteractiveSheetWrapper.kMinDefensiveBottomClearance, equals(28.0));
      expect(InteractiveSheetWrapper.kModalScrollBottomClearance, equals(40.0));
    });

    testWidgets('1. ESCENARIO BARRA FANTASMA: getEffectiveBottomPadding inyecta 28.0dp cuando SO reporta 0.0dp', (tester) async {
      double resolvedPadding = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              padding: EdgeInsets.zero,
              viewPadding: EdgeInsets.zero,
              viewInsets: EdgeInsets.zero,
            ),
            child: Builder(
              builder: (context) {
                resolvedPadding = InteractiveSheetWrapper.getEffectiveBottomPadding(context);
                return const Scaffold(body: SizedBox());
              },
            ),
          ),
        ),
      );

      expect(resolvedPadding, equals(InteractiveSheetWrapper.kMinDefensiveBottomClearance));
      expect(resolvedPadding, equals(28.0));
    });

    testWidgets('2. ESCENARIO BARRA FÍSICA 48dp: getEffectiveBottomPadding no duplica inset (Cero Doble Padding)', (tester) async {
      double resolvedPadding = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              padding: EdgeInsets.only(bottom: 48.0),
              viewPadding: EdgeInsets.only(bottom: 48.0),
              viewInsets: EdgeInsets.zero,
            ),
            child: Builder(
              builder: (context) {
                resolvedPadding = InteractiveSheetWrapper.getEffectiveBottomPadding(context);
                return const Scaffold(body: SizedBox());
              },
            ),
          ),
        ),
      );

      // Debe ser exactamente 48.0 (máximo entre 28.0 y 48.0), SIN duplicar a 96.0dp
      expect(resolvedPadding, equals(48.0));
    });

    testWidgets('3. STICKY FOOTER BLINDADO: bottomAction recibe defensiveBottom incluso si applyEffectiveBottomPadding es false', (tester) async {
      // Configuramos una pantalla con barra fantasma (0.0dp)
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(400, 800),
              padding: EdgeInsets.zero,
              viewPadding: EdgeInsets.zero,
              viewInsets: EdgeInsets.zero,
            ),
            child: Scaffold(
              body: InteractiveSheetWrapper(
                title: "Modal con Footer Fijo",
                applyEffectiveBottomPadding: false, // ⚠️ El child no debe tener spacer
                bottomAction: ElevatedButton(
                  key: const Key('btn_guardar_decision'),
                  onPressed: () {},
                  child: const Text("GUARDAR DECISIÓN"),
                ),
                child: const SizedBox(
                  height: 150,
                  child: Text("Contenido del Modal"),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verificar que el botón existe
      expect(find.byKey(const Key('btn_guardar_decision')), findsOneWidget);

      // Buscar el Container que envuelve al bottomAction
      final bottomActionFinder = find.ancestor(
        of: find.byKey(const Key('btn_guardar_decision')),
        matching: find.byType(Container),
      ).first;

      final containerWidget = tester.widget<Container>(bottomActionFinder);
      final padding = containerWidget.padding as EdgeInsets;

      // El bottom padding del contenedor debe ser al menos kMinDefensiveBottomClearance (28.0)
      expect(padding.bottom, greaterThanOrEqualTo(28.0));
      expect(padding.bottom, equals(28.0));
    });

    testWidgets('4. RESGUARDO ANTE TECLADO: viewInsets.bottom > 0 compacta el padding inferior a 12dp', (tester) async {
      double resolvedWithKeyboard = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(400, 800),
              padding: EdgeInsets.only(bottom: 48.0),
              viewPadding: EdgeInsets.only(bottom: 48.0),
              viewInsets: EdgeInsets.only(bottom: 300.0), // Teclado abierto
            ),
            child: Material(
              child: Builder(
                builder: (ctx) {
                  resolvedWithKeyboard = InteractiveSheetWrapper.getEffectiveBottomPadding(ctx, includeKeyboard: true);
                  return InteractiveSheetWrapper(
                    title: "Modal con Teclado",
                    bottomAction: ElevatedButton(
                      key: const Key('btn_teclado_action'),
                      onPressed: () {},
                      child: const Text("ENVIAR"),
                    ),
                    child: const SizedBox(
                      height: 100,
                      child: Text("Formulario"),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // getEffectiveBottomPadding con includeKeyboard = true debe reportar 308dp (300 + 8)
      expect(resolvedWithKeyboard, equals(308.0));

      final bottomActionFinder = find.ancestor(
        of: find.byKey(const Key('btn_teclado_action')),
        matching: find.byType(Container),
      ).first;

      final containerWidget = tester.widget<Container>(bottomActionFinder);
      final padding = containerWidget.padding as EdgeInsets;

      // Con teclado abierto, el AnimatedPadding exterior ya absorbe los 300dp,
      // por lo que el padding del action bar se compacta a 12.0dp ergonómicos
      expect(padding.bottom, equals(12.0));
    });

    testWidgets('5. SCROLL BOTTOM CLEARANCE: scrollable content permite sobre-desplazamiento con kModalScrollBottomClearance', (tester) async {
      final scrollController = ScrollController();

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(400, 600),
            padding: EdgeInsets.zero,
            viewPadding: EdgeInsets.zero,
            viewInsets: EdgeInsets.zero,
          ),
          child: MaterialApp(
            home: Scaffold(
              body: InteractiveSheetWrapper(
                title: "Lista con Clearance",
                scrollController: scrollController,
                child: ListView.builder(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  padding: const EdgeInsets.only(bottom: InteractiveSheetWrapper.kModalScrollBottomClearance),
                  itemCount: 20,
                  itemBuilder: (context, index) => ListTile(
                    key: Key('item_$index'),
                    title: Text('Elemento $index'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Desplazarse hasta el final
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pumpAndSettle();

      // El último elemento debe ser visible
      expect(find.byKey(const Key('item_19')), findsOneWidget);
    });

    testWidgets('6. INVOCACIÓN INTERACTIVESHEETWRAPPER.SHOW: useSafeArea es true por defecto', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const Key('btn_open_sheet'),
                onPressed: () {
                  InteractiveSheetWrapper.show(
                    context: ctx,
                    builder: (sheetCtx) => InteractiveSheetWrapper(
                      title: "Sheet Dinámico",
                      child: const SizedBox(height: 100, child: Text("Contenido")),
                    ),
                  );
                },
                child: const Text("Abrir"),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn_open_sheet')));
      await tester.pumpAndSettle();

      // Debe encontrarse el SafeArea inyectado por showModalBottomSheet(useSafeArea: true)
      expect(find.byType(SafeArea), findsWidgets);
      expect(find.text("Sheet Dinámico"), findsOneWidget);
    });

    testWidgets('7. SMART DROPDOWN SEARCH: modal cuenta con useSafeArea y padding defensivo', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartDropdownSearch<String>(
              label: "Categoría",
              items: const ["Categoría A", "Categoría B", "Categoría C"],
              itemAsString: (item) => item,
              onChanged: (_) {},
              onAddNew: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Abrir modal de búsqueda
      await tester.tap(find.byType(SmartDropdownSearch<String>));
      await tester.pumpAndSettle();

      // Verificar que el modal se abrió y tiene campo de búsqueda
      expect(find.text("Seleccionar Categoría"), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text("Categoría A"), findsOneWidget);
    });

    testWidgets('8. APERTURA REAL MODAL EN BARRA FANTASMA (0.0dp): Botón inferior a >= 28dp y scroll con clearance 40dp', (tester) async {
      final scrollCtrl = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: const MediaQueryData(
              size: Size(400, 800),
              padding: EdgeInsets.zero,
              viewPadding: EdgeInsets.zero,
              viewInsets: EdgeInsets.zero,
            ),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const Key('btn_open_ghost_sheet'),
                onPressed: () {
                  InteractiveSheetWrapper.show(
                    context: ctx,
                    useSafeArea: true,
                    builder: (sheetCtx) => InteractiveSheetWrapper(
                      title: "Modal Barra Fantasma",
                      scrollController: scrollCtrl,
                      bottomAction: ElevatedButton(
                        key: const Key('btn_ghost_action'),
                        onPressed: () {},
                        child: const Text("ACCION FANTASMA"),
                      ),
                      child: ListView.builder(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.only(bottom: InteractiveSheetWrapper.kModalScrollBottomClearance),
                        itemCount: 15,
                        itemBuilder: (_, i) => ListTile(title: Text("Elemento $i")),
                      ),
                    ),
                  );
                },
                child: const Text("Abrir Fantasma"),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn_open_ghost_sheet')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('btn_ghost_action')), findsOneWidget);

      // 1. Verificar el padding inferior del container del botón
      final bottomActionFinder = find.ancestor(
        of: find.byKey(const Key('btn_ghost_action')),
        matching: find.byType(Container),
      ).first;
      final containerWidget = tester.widget<Container>(bottomActionFinder);
      final padding = containerWidget.padding as EdgeInsets;

      expect(padding.bottom, greaterThanOrEqualTo(InteractiveSheetWrapper.kMinDefensiveBottomClearance));
      expect(padding.bottom, equals(28.0));

      // 2. Verificar que la cota inferior del botón dista al menos 28dp del fondo de la pantalla (800)
      final btnBottom = tester.getBottomRight(find.byKey(const Key('btn_ghost_action'))).dy;
      expect(btnBottom, lessThanOrEqualTo(800.0 - 28.0));

      // 3. Verificar scroll con holgura kModalScrollBottomClearance = 40.0dp
      final listView = tester.widget<ListView>(find.byType(ListView));
      final listPadding = listView.padding as EdgeInsets;
      expect(listPadding.bottom, equals(InteractiveSheetWrapper.kModalScrollBottomClearance));
    });

    testWidgets('9. APERTURA REAL MODAL EN BARRA NORMAL 48dp CON useSafeArea: true: CERO DOBLE PADDING (NO se duplica a 96dp)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: const MediaQueryData(
              size: Size(400, 800),
              padding: EdgeInsets.only(bottom: 48.0),
              viewPadding: EdgeInsets.only(bottom: 48.0),
              viewInsets: EdgeInsets.zero,
            ),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                key: const Key('btn_open_normal_sheet'),
                onPressed: () {
                  InteractiveSheetWrapper.show(
                    context: ctx,
                    useSafeArea: true,
                    builder: (sheetCtx) => InteractiveSheetWrapper(
                        title: "Modal Barra Normal 48dp",
                      bottomAction: ElevatedButton(
                        key: const Key('btn_normal_action'),
                        onPressed: () {},
                        child: const Text("GUARDAR NORMAL"),
                      ),
                      child: const SizedBox(height: 120, child: Text("Contenido Normal")),
                    ),
                  );
                },
                child: const Text("Abrir Normal"),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('btn_open_normal_sheet')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('btn_normal_action')), findsOneWidget);

      // 1. Verificar el padding inferior del container del botón
      // Al haber sido consumido por SafeArea (Estado C), NO debe agregar 48dp de nuevo, sino un respiro compacto de 16.0dp
      final bottomActionFinder = find.ancestor(
        of: find.byKey(const Key('btn_normal_action')),
        matching: find.byType(Container),
      ).first;
      final containerWidget = tester.widget<Container>(bottomActionFinder);
      final padding = containerWidget.padding as EdgeInsets;

      // El padding interno es exactamente 16.0dp (Estado C compacto), NO 48.0dp ni 96.0dp
      expect(padding.bottom, equals(16.0));
      expect(padding.bottom, isNot(equals(48.0)));
      expect(padding.bottom, isNot(equals(96.0)));

      // 2. La posición absoluta del botón respecto al fondo de pantalla (800):
      // SafeArea del modal consume 48dp + 16dp de respiro = 64dp desde el fondo de la pantalla
      // NUNCA 96dp ni 112dp (que ocurriría si sumáramos 48dp dos veces)
      final btnBottom = tester.getBottomRight(find.byKey(const Key('btn_normal_action'))).dy;
      expect(btnBottom, lessThanOrEqualTo(800.0 - 48.0 - 16.0));
    });
  });
}
