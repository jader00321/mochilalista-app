import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_movil/features/scanner/models/scanner_models.dart';
import 'package:app_movil/features/scanner/providers/scanner_provider.dart';
import 'package:app_movil/features/scanner/widgets/staging/comparative_modal/comparative_update_modal.dart';
import 'package:app_movil/features/scanner/widgets/staging/variant_editor_row.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ÁRBITRO ADVERSARIAL: Auditoría Tipográfica y Pluralización', () {
    test('1.1 Pluralización limpia sin sufijos rotos (Pack -> Packs, nunca Packes)', () {
      expect(ComparativeUpdateModal.formatUnitLabelForTest(1, 'Pack'), equals('1 Pack'));
      expect(ComparativeUpdateModal.formatUnitLabelForTest(2, 'Pack'), equals('2 Packs'));
      expect(ComparativeUpdateModal.formatUnitLabelForTest(5, 'pack'), equals('5 Packs'));
    });

    test('1.2 Pluralización de unidades compuestas con paréntesis (Pack (x4) -> Packs (x4))', () {
      expect(ComparativeUpdateModal.formatUnitLabelForTest(1, 'Pack (x4)'), equals('1 Pack (x4)'));
      expect(ComparativeUpdateModal.formatUnitLabelForTest(2, 'Pack (x4)'), equals('2 Packs (x4)'));
      expect(ComparativeUpdateModal.formatUnitLabelForTest(3, 'Set (x6)'), equals('3 Sets (x6)'));
      expect(ComparativeUpdateModal.formatUnitLabelForTest(4, 'Kit (x2)'), equals('4 Kits (x2)'));
    });

    test('1.3 No duplicar números en strings que ya tienen prefijo numérico (1/2 Docena, 1 Par)', () {
      expect(ComparativeUpdateModal.formatUnitLabelForTest(1, '½ Docena'), equals('1 ½ Docena'));
      expect(ComparativeUpdateModal.formatUnitLabelForTest(1, '1 Par'), equals('1 Par'));
      expect(ComparativeUpdateModal.formatUnitLabelForTest(2, '1 Par'), equals('2 Pares'));
    });

    test('1.4 Formato exacto de moneda AppCurrency.format', () {
      expect(AppCurrency.format(0.0), equals('S/ 0.00'));
      expect(AppCurrency.format(45.5), equals('S/ 45.50'));
      expect(AppCurrency.format(1250.75), equals('S/ 1,250.75'));
    });
  });

  group('ÁRBITRO ADVERSARIAL: Creación Proporcional de Variante Sobrante', () {
    test('2.1 Cálculo proporcional real de compra para variante creada por sobrante', () {
      final provider = ScannerProvider();
      
      // Creamos un producto madre con 1 caja de 100 unidades que costó S/ 450.00 (Costo unitario = S/ 4.50)
      final madre = StagingVariant(
        uuidTemporal: 'var-madre-001',
        nombreEspecifico: 'Lapicero Azul',
        unidadVenta: 'Docena',
        unidadesPorVenta: 12,
        umpCompra: 'Caja',
        cantidadUmpComprada: 1.0,
        unidadesPorLote: 100,
        precioUmpProveedor: 450.0,
        totalPagoLote: 450.0,
        costoUnitarioSugerido: 54.0, // 4.50 * 12
        precioVentaSugerido: 72.90,
        factorGananciaVentaSugerido: 1.35,
        matchPresentacion: MatchResult(
          estado: 'MATCH_EXACTO',
          confianza: 100,
          datos: MatchData(
            id: 10,
            nombre: 'Lapicero Azul Docena',
            unidadVenta: 'Docena',
            unidadesPorVenta: 12,
            stockActual: 0,
            precioVentaFinal: 72.90,
          ),
        ),
      );

      final group = StagingProductGroup(
        uuidTemporal: 'group-001',
        nombrePadre: 'Lapicero Faber-Castell',
        marcaTexto: 'Faber-Castell',
        matchProducto: MatchResult(estado: 'MATCH_EXACTO', confianza: 100),
        matchMarca: MatchResult(estado: 'MATCH_EXACTO', confianza: 100),
        variantes: [madre],
      );

      provider.setStagingDataForTesting(
        StagingResponse(
          proveedorMatch: MatchResult(estado: 'MATCH_EXACTO', confianza: 100),
          proveedorTexto: 'Distribuidora Faber',
          productosAgrupados: [group],
        ),
      );

      // 100 unidades ÷ 12 = 8 docenas (96 unid.) + 4 sobrantes
      final newVariantUuid = provider.createLeftoverVariant(madre.uuidTemporal, 4);

      expect(newVariantUuid, isNotNull);
      expect(group.variantes.length, equals(2));

      final sobranteVar = group.variantes.firstWhere((v) => v.uuidTemporal == newVariantUuid);

      // Verificación de datos de compra proporcionales reales (NUNCA 0)
      expect(sobranteVar.sourceVariantUuid, equals(madre.uuidTemporal));
      expect(sobranteVar.unidadVenta, equals('Unidad'));
      expect(sobranteVar.unidadesPorVenta, equals(1));
      expect(sobranteVar.umpCompra, equals('Unidad'));
      expect(sobranteVar.cantidadUmpComprada, equals(4.0));
      expect(sobranteVar.unidadesPorLote, equals(1));
      expect(sobranteVar.costoUnitarioSugerido, equals(4.50));
      expect(sobranteVar.precioUmpProveedor, equals(4.50));
      expect(sobranteVar.totalPagoLote, equals(18.00)); // 4 * 4.50
      expect(sobranteVar.precioVentaSugerido, greaterThan(4.50));
      expect(sobranteVar.stockIngresanteOverride, equals(4));

      // Verificación de que la variante madre ajustó su stock restante (100 - 4 = 96)
      expect(madre.stockIngresanteOverride, equals(96));
      expect(madre.allowLeftoverInReserve, isFalse);
    });
  });

  group('ÁRBITRO ADVERSARIAL: Bloqueo Estricto de Déficit en Modal', () {
    testWidgets('3.1 Botón GUARDAR DECISIÓN queda deshabilitado ante déficit', (tester) async {
      final provider = ScannerProvider();

      // Variante que se vende por Docena (factor 12) pero solo ingresaron 5 unidades (déficit de 7)
      final variant = StagingVariant(
        uuidTemporal: 'var-deficit-001',
        nombreEspecifico: 'Lapicero Rojo',
        unidadVenta: 'Docena',
        unidadesPorVenta: 12,
        umpCompra: 'Unidad',
        cantidadUmpComprada: 5.0,
        unidadesPorLote: 1,
        precioUmpProveedor: 2.0,
        totalPagoLote: 10.0,
        costoUnitarioSugerido: 24.0,
        precioVentaSugerido: 32.40,
        factorGananciaVentaSugerido: 1.35,
        matchPresentacion: MatchResult(
          estado: 'MATCH_EXACTO',
          confianza: 100,
          datos: MatchData(
            id: 20,
            nombre: 'Lapicero Rojo Docena',
            unidadVenta: 'Docena',
            unidadesPorVenta: 12,
            stockActual: 0,
            precioVentaFinal: 32.40,
          ),
        ),
      );

      final group = StagingProductGroup(
        uuidTemporal: 'group-002',
        nombrePadre: 'Lapicero Rojo',
        marcaTexto: 'Generica',
        matchProducto: MatchResult(estado: 'MATCH_EXACTO', confianza: 100),
        matchMarca: MatchResult(estado: 'MATCH_EXACTO', confianza: 100),
        variantes: [variant],
      );

      provider.setStagingDataForTesting(
        StagingResponse(
          proveedorMatch: MatchResult(estado: 'MATCH_EXACTO', confianza: 100),
          proveedorTexto: 'Distribuidora Lapiceros',
          productosAgrupados: [group],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ComparativeUpdateModal(
              variant: variant,
              group: group,
              dbData: {
                'id': 20,
                'nombre_especifico': 'Lapicero Rojo Docena',
                'unidad': 'Docena',
                'factor_conversion': 12,
                'stock_actual': 0,
                'precio_costo': 24.0,
                'precio_venta': 32.40,
              },
              isDark: false,
              provider: provider,
              onConfirm: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // El botón debe mostrar "SOLUCIONA EL STOCK FALTANTE" y estar deshabilitado
      final botonGuardar = find.widgetWithText(ElevatedButton, 'SOLUCIONA EL STOCK FALTANTE');
      expect(botonGuardar, findsOneWidget);

      final elevatedBtn = tester.widget<ElevatedButton>(botonGuardar);
      expect(elevatedBtn.onPressed, isNull); // 🛡️ REGLA 1: ESTRICTAMENTE DESHABILITADO

      // Verificamos que se muestre la alerta de stock insuficiente
      expect(find.textContaining('Stock Insuficiente: No alcanza para 1 Docena'), findsOneWidget);

      // Ahora pulsamos "Adaptar a Unidad (x1)" dentro del modal
      final btnAdaptar = find.widgetWithText(ElevatedButton, 'Adaptar a Unidad (x1)');
      expect(btnAdaptar, findsOneWidget);
      await tester.ensureVisible(btnAdaptar);
      await tester.tap(btnAdaptar);
      await tester.pumpAndSettle();

      // Al cambiar a factor 1 (Unidad), el déficit desaparece y el botón se habilita
      final botonHabilitado = find.widgetWithText(ElevatedButton, 'GUARDAR DECISIÓN');
      expect(botonHabilitado, findsOneWidget);
      final elevatedBtnHabilitado = tester.widget<ElevatedButton>(botonHabilitado);
      expect(elevatedBtnHabilitado.onPressed, isNotNull);
    });
  });

  group('ÁRBITRO ADVERSARIAL: Tarjeta Vinculada y Panel 100% de Ancho a 320dp', () {
    testWidgets('4.1 Renderizado de VariantEditorRow sin desbordamiento a 320dp (Modo Oscuro)', (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 800 * 2.0);
      tester.view.devicePixelRatio = 2.0;

      final provider = ScannerProvider();
      final variant = StagingVariant(
        uuidTemporal: 'var-layout-001',
        nombreEspecifico: 'Edición Pastoral',
        unidadVenta: 'Unidad',
        unidadesPorVenta: 1,
        umpCompra: 'Caja',
        cantidadUmpComprada: 2.0,
        unidadesPorLote: 10,
        precioUmpProveedor: 180.0,
        totalPagoLote: 360.0,
        costoUnitarioSugerido: 18.0,
        precioVentaSugerido: 25.0,
        factorGananciaVentaSugerido: 1.38,
        matchPresentacion: MatchResult(
          estado: 'MATCH_EXACTO',
          confianza: 100,
          datos: MatchData(
            id: 30,
            nombre: 'Edición Pastoral',
            unidadVenta: 'Unidad',
            unidadesPorVenta: 1,
            stockActual: 15,
            precioVentaFinal: 25.0,
          ),
        ),
      );

      final group = StagingProductGroup(
        uuidTemporal: 'group-003',
        nombrePadre: 'Biblia Latinoamericana',
        marcaTexto: 'Editorial San Pablo',
        matchProducto: MatchResult(estado: 'MATCH_EXACTO', confianza: 100),
        matchMarca: MatchResult(estado: 'MATCH_EXACTO', confianza: 100),
        variantes: [variant],
      );

      provider.setStagingDataForTesting(
        StagingResponse(
          proveedorMatch: MatchResult(estado: 'MATCH_EXACTO', confianza: 100),
          proveedorTexto: 'Editorial San Pablo',
          productosAgrupados: [group],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: VariantEditorRow(
                variant: variant,
                group: group,
                isDark: true,
                provider: provider,
                onDelete: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Debe mostrar el panel de balance de 3 columnas
      expect(find.text('Stock Actual'), findsOneWidget);
      expect(find.text('Ingreso Factura'), findsOneWidget);
      expect(find.text('Nuevo Total'), findsOneWidget);
      expect(find.text('Control de Variante'), findsOneWidget);

      // Verificamos que no haya ningún desbordamiento (overflow)
      expect(tester.takeException(), isNull);

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });
  });
}
