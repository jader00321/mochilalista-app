import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/features/scanner/providers/scanner_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/matching_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/smart_quotation_provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/core/widgets/floating_dock_session_state.dart';
import 'package:app_movil/core/widgets/deep_nav_return_pill.dart';
import 'package:app_movil/features/smart_quotation/models/matching_model.dart';
import 'package:app_movil/features/scanner/models/scanner_models.dart';

// Mocks ultraligeros para pruebas deterministas
class _MockAuthProvider extends ChangeNotifier implements AuthProvider {
  bool _active = true;
  void setActive(bool val) {
    _active = val;
    notifyListeners();
  }

  @override
  bool get hasActiveContext => _active;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockQuickSaleProvider extends ChangeNotifier implements QuickSaleProvider {
  List<MatchedProduct> _items = [];
  void setItems(List<MatchedProduct> items) {
    _items = items;
    notifyListeners();
  }

  @override
  List<MatchedProduct> get cartItems => _items;

  @override
  double get totalToPay => 25.50;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockScannerProvider extends ChangeNotifier implements ScannerProvider {
  @override
  StagingResponse? get stagingData => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockMatchingProvider extends ChangeNotifier implements MatchingProvider {
  @override
  List<MatchPair> get pairs => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockSmartQuotationProvider extends ChangeNotifier implements SmartQuotationProvider {
  bool _hasDraft = false;
  void setDraft(bool val) {
    _hasDraft = val;
    notifyListeners();
  }

  @override
  bool get hasManualDraft => _hasDraft;

  @override
  List<MatchedProduct>? get draftManualItems => _hasDraft
      ? [
          MatchedProduct(
            productId: 1,
            presentationId: 1,
            fullName: 'Item 1',
            price: 10.0,
            stock: 10,
          )
        ]
      : null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockInventoryProvider extends ChangeNotifier implements InventoryProvider {
  @override
  bool get hasCreationDraft => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _MockAuthProvider mockAuth;
  late _MockQuickSaleProvider mockQuickSale;
  late _MockScannerProvider mockScanner;
  late _MockMatchingProvider mockMatching;
  late _MockSmartQuotationProvider mockSmartQuote;
  late _MockInventoryProvider mockInventory;

  setUp(() {
    SecondaryBubbleSessionState.reset();
    FloatingDockSessionState.reset();

    mockAuth = _MockAuthProvider();
    mockQuickSale = _MockQuickSaleProvider();
    mockScanner = _MockScannerProvider();
    mockMatching = _MockMatchingProvider();
    mockSmartQuote = _MockSmartQuotationProvider();
    mockInventory = _MockInventoryProvider();
  });

  Widget createTestWidget({String? currentScreenId}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
        ChangeNotifierProvider<QuickSaleProvider>.value(value: mockQuickSale),
        ChangeNotifierProvider<ScannerProvider>.value(value: mockScanner),
        ChangeNotifierProvider<MatchingProvider>.value(value: mockMatching),
        ChangeNotifierProvider<SmartQuotationProvider>.value(value: mockSmartQuote),
        ChangeNotifierProvider<InventoryProvider>.value(value: mockInventory),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              DeepNavReturnPill(
                isBottom: true,
                currentScreenId: currentScreenId,
              ),
            ],
          ),
        ),
      ),
    );
  }

  MatchedProduct createDummyCartItem() {
    return MatchedProduct(
      productId: 1,
      presentationId: 1,
      fullName: 'Cuaderno Standford',
      price: 5.0,
      stock: 100,
    );
  }

  group('FASE 1: Desacoplamiento e Independencia Total de SecondaryBubbleSessionState', () {
    test('SecondaryBubbleSessionState y FloatingDockSessionState son 100% independientes', () {
      FloatingDockSessionState.isLeftEdge = true;
      FloatingDockSessionState.panBottom = 88.0;
      FloatingDockSessionState.isEdgeTucked = true;
      FloatingDockSessionState.selectedTaskIndex = 1;

      SecondaryBubbleSessionState.isLeftEdge = false;
      SecondaryBubbleSessionState.panBottom = 160.0;
      SecondaryBubbleSessionState.isEdgeTucked = false;
      SecondaryBubbleSessionState.selectedTaskIndex = 3;

      expect(FloatingDockSessionState.isLeftEdge, isTrue);
      expect(FloatingDockSessionState.panBottom, equals(88.0));
      expect(FloatingDockSessionState.isEdgeTucked, isTrue);
      expect(FloatingDockSessionState.selectedTaskIndex, equals(1));

      expect(SecondaryBubbleSessionState.isLeftEdge, isFalse);
      expect(SecondaryBubbleSessionState.panBottom, equals(160.0));
      expect(SecondaryBubbleSessionState.isEdgeTucked, isFalse);
      expect(SecondaryBubbleSessionState.selectedTaskIndex, equals(3));

      SecondaryBubbleSessionState.reset();
      expect(SecondaryBubbleSessionState.isLeftEdge, isFalse);
      expect(SecondaryBubbleSessionState.panBottom, isNull);
      expect(SecondaryBubbleSessionState.isEdgeTucked, isFalse);
      expect(SecondaryBubbleSessionState.selectedTaskIndex, equals(0));

      // FloatingDockSessionState debe conservar intactos sus valores
      expect(FloatingDockSessionState.isLeftEdge, isTrue);
      expect(FloatingDockSessionState.panBottom, equals(88.0));
      expect(FloatingDockSessionState.isEdgeTucked, isTrue);
      expect(FloatingDockSessionState.selectedTaskIndex, equals(1));
    });

    test('Reactividad con listeners en SecondaryBubbleSessionState para IndexedStack', () {
      int notifyCount = 0;
      void listener() => notifyCount++;

      SecondaryBubbleSessionState.addListener(listener);

      SecondaryBubbleSessionState.updatePosition(
        isLeftEdge: true,
        isEdgeTucked: true,
        panX: 30.0,
        panBottom: 90.0,
        selectedTaskIndex: 2,
      );

      expect(notifyCount, equals(1));
      expect(SecondaryBubbleSessionState.isLeftEdge, isTrue);
      expect(SecondaryBubbleSessionState.isEdgeTucked, isTrue);
      expect(SecondaryBubbleSessionState.panX, equals(30.0));
      expect(SecondaryBubbleSessionState.panBottom, equals(90.0));
      expect(SecondaryBubbleSessionState.selectedTaskIndex, equals(2));

      SecondaryBubbleSessionState.removeListener(listener);
      SecondaryBubbleSessionState.isLeftEdge = false;
      expect(notifyCount, equals(1)); // No debe recibir más notificaciones
    });
  });

  group('FASE 2: Visibilidad Garantizada sin canPop y Auto-Ocultamiento Limpio', () {
    testWidgets('DeepNavReturnPill aparece en ruta raíz (canPop == false) cuando hay tareas', (tester) async {
      mockQuickSale.setItems([createDummyCartItem()]);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Debe mostrarse visiblemente con la etiqueta "Caja Rápida"
      expect(find.byType(DeepNavReturnPill), findsOneWidget);
      expect(find.text('Caja Rápida'), findsOneWidget);
    });

    testWidgets('DeepNavReturnPill se oculta limpiamente si no hay tareas activas', (tester) async {
      mockQuickSale.setItems([]); // Sin tareas

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // No debe renderizar el texto de la burbuja
      expect(find.text('Caja Rápida'), findsNothing);
      expect(find.byType(AnimatedPositioned), findsNothing);
    });

    testWidgets('DeepNavReturnPill se oculta si hasActiveContext es false', (tester) async {
      mockQuickSale.setItems([createDummyCartItem()]);
      mockAuth.setActive(false);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Caja Rápida'), findsNothing);
    });

    testWidgets('DeepNavReturnPill se oculta si el usuario ya está en la única tarea activa', (tester) async {
      mockQuickSale.setItems([createDummyCartItem()]);

      // Pasamos currentScreenId: 'quick_sale'
      await tester.pumpWidget(createTestWidget(currentScreenId: 'quick_sale'));
      await tester.pumpAndSettle();

      expect(find.text('Caja Rápida'), findsNothing);
    });
  });

  group('FASE 3 & 4: Rediseño Visual Compacto y Cero Flecha (>)', () {
    testWidgets('La cápsula no tiene flecha derecha (>) ni montos largos en soles', (tester) async {
      mockQuickSale.setItems([createDummyCartItem()]);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Enunciado conciso presente
      expect(find.text('Caja Rápida'), findsOneWidget);

      // Cero flechas / chevrons a la derecha
      expect(find.byIcon(Icons.arrow_forward_ios_rounded), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsNothing);

      // Cero montos en soles en subtítulos
      expect(find.textContaining('S/'), findsNothing);

      // Ícono semántico en contenedor circular presente
      expect(find.byIcon(Icons.point_of_sale_rounded), findsOneWidget);
    });

    testWidgets('Muestra contador discreto cuando hay múltiples tareas activas', (tester) async {
      mockQuickSale.setItems([createDummyCartItem()]);
      mockSmartQuote.setDraft(true); // 2 tareas: Caja Rápida + Cotización

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Debe mostrar el contador 1/2
      expect(find.text('1/2'), findsOneWidget);
    });
  });

  group('FASE 5: Máquina de Gestos Reactivos (4 Interacciones Perfeccionadas)', () {
    testWidgets('Gesto 2: Pulsación estacionaria de 450ms rota la tarea activa sin navegar', (tester) async {
      mockQuickSale.setItems([createDummyCartItem()]);
      mockSmartQuote.setDraft(true); // 2 tareas

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Caja Rápida'), findsOneWidget);
      expect(SecondaryBubbleSessionState.selectedTaskIndex, equals(0));

      // Iniciar pulsación fija (down) sin mover el dedo
      final pillFinder = find.text('Caja Rápida');
      final gesture = await tester.startGesture(tester.getCenter(pillFinder));
      await tester.pump(const Duration(milliseconds: 500)); // Supera los 450ms estacionarios

      // Soltar el dedo
      await gesture.up();
      await tester.pumpAndSettle();

      // Debe haber conmutado a la siguiente tarea activa (Cotización)
      expect(SecondaryBubbleSessionState.selectedTaskIndex, equals(1));
      expect(find.text('Cotización'), findsOneWidget);
    });

    testWidgets('Gesto 3: Arrastre libre mayor a 8px cancela el long-press estacionario', (tester) async {
      mockQuickSale.setItems([createDummyCartItem()]);
      mockSmartQuote.setDraft(true);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final pillFinder = find.text('Caja Rápida');
      final gesture = await tester.startGesture(tester.getCenter(pillFinder));
      await tester.pump(const Duration(milliseconds: 100));

      // Mover el dedo más de 8px hacia el centro (lejos de las zonas de tuck) antes de los 450ms
      await gesture.moveBy(const Offset(-80, -20));
      await tester.pump(const Duration(milliseconds: 400)); // tiempo adicional

      // Soltar
      await gesture.up();
      await tester.pumpAndSettle();

      // NO debió rotar de tarea porque se movió (fue arrastre, no long-press estacionario)
      expect(SecondaryBubbleSessionState.selectedTaskIndex, equals(0));
      expect(SecondaryBubbleSessionState.isEdgeTucked, isFalse);
      expect(find.text('Caja Rápida'), findsOneWidget);
    });

    testWidgets('Gesto 4: Arrastre hacia el borde izquierdo retrae a pestaña edge-peek al ras (left: 0.0)', (tester) async {
      mockQuickSale.setItems([createDummyCartItem()]);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final pillFinder = find.text('Caja Rápida');
      // Arrastrar hacia la extrema izquierda cubriendo el ancho completo de la pantalla de prueba
      await tester.drag(pillFinder, const Offset(-700, 0));
      await tester.pumpAndSettle();

      // Debe estar retraída en el borde izquierdo
      expect(SecondaryBubbleSessionState.isEdgeTucked, isTrue);
      expect(SecondaryBubbleSessionState.isLeftEdge, isTrue);

      // Debe mostrar el ícono de chevron para desplegar
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

      // Tocar la pestaña para desplegarla nuevamente
      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await tester.pumpAndSettle();

      expect(SecondaryBubbleSessionState.isEdgeTucked, isFalse);
      expect(find.text('Caja Rápida'), findsOneWidget);
    });

    testWidgets('Gesto 4: Arrastre hacia el borde derecho retrae a pestaña edge-peek en el borde derecho', (tester) async {
      mockQuickSale.setItems([createDummyCartItem()]);

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final pillFinder = find.text('Caja Rápida');
      // Arrastrar hacia la extrema derecha
      await tester.drag(pillFinder, const Offset(400, 0));
      await tester.pumpAndSettle();

      // Debe estar retraída en el borde derecho
      expect(SecondaryBubbleSessionState.isEdgeTucked, isTrue);
      expect(SecondaryBubbleSessionState.isLeftEdge, isFalse);

      // Debe mostrar el ícono de chevron izquierdo para desplegar hacia adentro
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);

      // Tocar para desplegar
      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await tester.pumpAndSettle();

      expect(SecondaryBubbleSessionState.isEdgeTucked, isFalse);
      expect(find.text('Caja Rápida'), findsOneWidget);
    });
  });
}
