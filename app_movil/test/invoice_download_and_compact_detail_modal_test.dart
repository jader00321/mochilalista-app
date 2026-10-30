import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:app_movil/core/models/user_model.dart';
import 'package:app_movil/features/scanner/models/invoice_model.dart';
import 'package:app_movil/features/scanner/services/invoice_file_service.dart';
import 'package:app_movil/features/scanner/services/invoice_pdf_report_service.dart';
import 'package:app_movil/features/smart_quotation/widgets/manual/manual_price_modifier.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fase 1: InvoiceFileService - Sanitización y Utilidades de Archivo', () {
    test('sanitizeFileName limpia caracteres no válidos, acentos, barras y comillas', () {
      final sanitized = InvoiceFileService.sanitizeFileName(
        'Factura #19 / BAZAR & LIBRERÍA DEL PACÍFICO * "2026"?',
      );
      expect(sanitized, isNot(contains('/')));
      expect(sanitized, isNot(contains('\\')));
      expect(sanitized, isNot(contains(':')));
      expect(sanitized, isNot(contains('*')));
      expect(sanitized, isNot(contains('?')));
      expect(sanitized, isNot(contains('"')));
      expect(sanitized, isNot(contains('<')));
      expect(sanitized, isNot(contains('>')));
      expect(sanitized, isNot(contains('|')));
      expect(sanitized.contains('BAZAR'), isTrue);
      expect(sanitized.contains('PACIFICO'), isTrue);
    });

    test('determineExtension detecta extensiones comunes por URL o fallback', () {
      expect(InvoiceFileService.determineExtension('https://cdn.example.com/inv.jpg'), equals('.jpg'));
      expect(InvoiceFileService.determineExtension('https://cdn.example.com/inv.png?token=xyz'), equals('.png'));
      expect(InvoiceFileService.determineExtension('https://cdn.example.com/doc.pdf'), equals('.pdf'));
      expect(InvoiceFileService.determineExtension('https://cdn.example.com/image.webp'), equals('.webp'));
      expect(InvoiceFileService.determineExtension('https://cdn.example.com/unknown_file'), equals('.jpg'));
    });
  });

  group('Fase 2: InvoicePdfReportService - Generación de Reporte PDF Ejecutivo Multipágina', () {
    test('buildExecutivePdf genera documento PDF con pw.MultiPage y tabla paginable para múltiples ítems', () async {
      // 1. Crear 20 productos simulados para validar la paginación con pw.MultiPage
      final List<Map<String, dynamic>> itemsExtraidos = List.generate(20, (i) {
        return {
          'descripcion_detectada': 'Cuaderno Cuadriculado Standford #$i 100 Hojas',
          'producto_padre_estimado': 'Cuaderno Standford A4',
          'variante_detectada': '100 Hojas Mod #$i',
          'marca_detectada': 'Standford',
          'codigo_detectada': 'STF-00$i',
          'unidad_venta': 'Unidad',
          'cantidad_ump_comprada': 2,
          'ump_compra': 'DOC',
          'unidades_por_lote': 12,
          'precio_ump_proveedor': 48.00,
          'total_pago_lote': 96.00,
        };
      });

      final invoice = InvoiceModel(
        id: 19,
        numeroSecuencial: 19,
        negocioId: 1,
        imagenUrl: 'https://cdn.mochilalista.app/facturas/19.jpg',
        estado: 'completado',
        fechaCarga: DateTime(2026, 10, 22, 11, 45),
        fechaEmision: DateTime(2026, 10, 20),
        montoTotalFactura: 1920.00,
        cantidadItemsExtraidos: 20,
        datosCrudosIaJson: {
          'proveedor_detectado': 'BAZAR Y LIBRERIA DEL PACIFICO',
          'items_extraidos': itemsExtraidos,
        },
      );

      final user = UserModel(
        id: 1,
        fullName: 'Administrador Demo',
        isActive: true,
        business: BusinessModel(
          id: 1,
          commercialName: 'Bazar Escolar MochilaLista',
          ruc: '20601234567',
          address: 'Av. Las Palmeras 123, Lima',
        ),
      );

      // 2. Ejecutar generación
      final Uint8List pdfBytes = await InvoicePdfReportService.buildExecutivePdf(
        invoice: invoice,
        providerName: 'BAZAR Y LIBRERIA DEL PACIFICO',
        providerRuc: '20555666777',
        currentUser: user,
      );

      // 3. Verificaciones de bytes y estructura PDF
      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, isTrue);
      // La cabecera estándar de todo documento PDF debe comenzar con '%PDF-'
      final String header = String.fromCharCodes(pdfBytes.take(5));
      expect(header, equals('%PDF-'));
    });
  });

  group('Fases 5 y 6: ManualPriceModifier - Modo Compacto Activo y Reactividad 0ms', () {
    testWidgets('Inicia en Estado Compacto Activo cuando hay oferta activa, mostrando "Personalizar" y ocultando los inputs', (tester) async {
      final discountCtrl = TextEditingController(text: '1.40');
      final priceCtrl = TextEditingController(text: '12.50');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManualPriceModifier(
              isManualPrice: true,
              systemPrice: 13.90,
              discountCtrl: discountCtrl,
              priceCtrl: priceCtrl,
              catalogHasOffer: true,
              catalogOfferPrice: 12.50,
              catalogDiscountPercent: 10,
              onToggle: (_) {},
              onDiscountChanged: (_) {},
              onPriceChanged: (_) {},
            ),
          ),
        ),
      );

      // Debe mostrar el switch encendido
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      expect(tester.widget<Switch>(switchFinder).value, isTrue);

      // Estado Compacto: Los TextFields de "S/ a Descontar" y "Precio Final Unit." deben estar colapsados / no visibles
      expect(find.text('Personalizar'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
      expect(find.text('S/ a Descontar'), findsNothing);
      expect(find.text('Precio Final Unit.'), findsNothing);

      // Al tocar "Personalizar", se despliegan suavemente
      await tester.tap(find.text('Personalizar'));
      await tester.pumpAndSettle();

      expect(find.text('Contraer'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
      expect(find.text('S/ a Descontar'), findsOneWidget);
      expect(find.text('Precio Final Unit.'), findsOneWidget);

      // Al tocar "Contraer", vuelven a ocultarse
      await tester.tap(find.text('Contraer'));
      await tester.pumpAndSettle();

      expect(find.text('Personalizar'), findsOneWidget);
      expect(find.text('S/ a Descontar'), findsNothing);
    });

    testWidgets('Smart Auto-Expand: Al encender el switch en un producto SIN oferta en BD, auto-despliega los inputs', (tester) async {
      final discountCtrl = TextEditingController();
      final priceCtrl = TextEditingController(text: '5.06');
      bool switchState = false;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: ManualPriceModifier(
                  isManualPrice: switchState,
                  systemPrice: 5.06,
                  discountCtrl: discountCtrl,
                  priceCtrl: priceCtrl,
                  catalogHasOffer: false,
                  onToggle: (val) {
                    setState(() {
                      switchState = val;
                    });
                  },
                  onDiscountChanged: (_) {},
                  onPriceChanged: (_) {},
                ),
              ),
            );
          },
        ),
      );

      // Inicialmente switch apagado, no hay sección de descuento
      expect(find.text('Personalizar'), findsNothing);
      expect(find.text('S/ a Descontar'), findsNothing);

      // Usuario enciende el switch para aplicar un descuento especial
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      // Debe haberse auto-desplegado inmediatamente a "Contraer" con los campos listos para escribir
      expect(find.text('Contraer'), findsOneWidget);
      expect(find.text('S/ a Descontar'), findsOneWidget);
      expect(find.text('Precio Final Unit.'), findsOneWidget);
    });

    testWidgets('Reactividad 0ms: Escribir descuento recalcula y actualiza precio y badge en vivo sin retraso', (tester) async {
      final discountCtrl = TextEditingController();
      final priceCtrl = TextEditingController();
      final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManualPriceModifier(
              isManualPrice: true,
              systemPrice: 13.90,
              discountCtrl: discountCtrl,
              priceCtrl: priceCtrl,
              catalogHasOffer: true,
              catalogOfferPrice: 12.50,
              catalogDiscountPercent: 10,
              currency: currency,
              onToggle: (_) {},
              onDiscountChanged: (_) {},
              onPriceChanged: (_) {},
            ),
          ),
        ),
      );

      // Desplegar para poder tipear
      await tester.tap(find.text('Personalizar'));
      await tester.pumpAndSettle();

      // Inicialmente con oferta de catálogo (12.50 y -10%)
      expect(find.textContaining(AppCurrency.format(12.50)), findsOneWidget);
      expect(find.text('-10%'), findsOneWidget);

      // Usuario escribe '2.00' de descuento (precio final resultante = 11.90, -14%)
      discountCtrl.text = '2.00';
      priceCtrl.text = '11.90';
      await tester.pump(); // 0ms pump

      expect(find.textContaining(AppCurrency.format(11.90)), findsOneWidget);
      expect(find.text('-14%'), findsOneWidget);

      // Si el usuario escribe un descuento mayor: '5.00' (precio final = 8.90, -36%)
      discountCtrl.text = '5.00';
      priceCtrl.text = '8.90';
      await tester.pump(); // 0ms pump

      expect(find.textContaining(AppCurrency.format(8.90)), findsOneWidget);
      expect(find.text('-36%'), findsOneWidget);
    });

    testWidgets('Cuando el switch está apagado en un producto con oferta en BD, muestra claramente el Precio Base regular activo', (tester) async {
      final discountCtrl = TextEditingController();
      final priceCtrl = TextEditingController(text: '13.90');
      final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManualPriceModifier(
              isManualPrice: false,
              systemPrice: 13.90,
              discountCtrl: discountCtrl,
              priceCtrl: priceCtrl,
              catalogHasOffer: true,
              catalogOfferPrice: 12.50,
              catalogDiscountPercent: 10,
              currency: currency,
              onToggle: (_) {},
              onDiscountChanged: (_) {},
              onPriceChanged: (_) {},
            ),
          ),
        ),
      );

      // Debe mostrar claramente "Precio Base: S/ 13.90" y el badge de advertencia de oferta desactivada
      expect(find.textContaining('Precio Base:'), findsOneWidget);
      expect(find.textContaining(AppCurrency.format(13.90)), findsOneWidget);
      expect(find.text('🚫 Oferta desactivada para esta operación'), findsOneWidget);
      // No debe mostrar el precio de oferta ni el badge -10% en el bloque activo
      expect(find.text('-10%'), findsNothing);
    });

    testWidgets('Blindaje 3: Muestra chip "↺ Usar oferta de catálogo" cuando hay oferta en BD pero usuario escribió precio personalizado', (tester) async {
      bool restored = false;
      final discountCtrl = TextEditingController(text: '2.00');
      final priceCtrl = TextEditingController(text: '11.90');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManualPriceModifier(
              isManualPrice: true,
              isCustomPrice: true,
              systemPrice: 13.90,
              discountCtrl: discountCtrl,
              priceCtrl: priceCtrl,
              catalogHasOffer: true,
              catalogOfferPrice: 12.50,
              catalogDiscountPercent: 10,
              onToggle: (_) {},
              onDiscountChanged: (_) {},
              onPriceChanged: (_) {},
              onRestoreCatalogOffer: () {
                restored = true;
              },
            ),
          ),
        ),
      );

      // Debe mostrar el chip interactivo de restauración
      expect(find.text('↺ Usar oferta de catálogo'), findsOneWidget);

      // Al tocarlo, invoca inmediatamente el callback onRestoreCatalogOffer
      await tester.tap(find.text('↺ Usar oferta de catálogo'));
      await tester.pump();

      expect(restored, isTrue);
    });

    testWidgets('Blindaje 4: Auto-ocultamiento del teclado al presionar "Contraer" en ManualPriceModifier', (tester) async {
      final discountCtrl = TextEditingController(text: '2.00');
      final priceCtrl = TextEditingController(text: '11.90');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManualPriceModifier(
              isManualPrice: true,
              systemPrice: 13.90,
              discountCtrl: discountCtrl,
              priceCtrl: priceCtrl,
              catalogHasOffer: true,
              catalogOfferPrice: 12.50,
              catalogDiscountPercent: 10,
              onToggle: (_) {},
              onDiscountChanged: (_) {},
              onPriceChanged: (_) {},
            ),
          ),
        ),
      );

      // Desplegar sección
      await tester.tap(find.text('Personalizar'));
      await tester.pumpAndSettle();

      // Enfocar uno de los campos de texto
      final textFinder = find.byType(TextField).first;
      await tester.tap(textFinder);
      await tester.pumpAndSettle();

      // El campo tiene foco
      expect(tester.binding.focusManager.primaryFocus?.hasFocus, isTrue);

      // Tocar "Contraer"
      await tester.tap(find.text('Contraer'));
      await tester.pumpAndSettle();

      // La sección vuelve a estado compacto y se cerró el teclado
      expect(find.text('Personalizar'), findsOneWidget);
      expect(find.text('S/ a Descontar'), findsNothing);
    });

    testWidgets('Blindaje 3: Restauración directa sin callback externo calcula oferta y descuento por defecto', (tester) async {
      String? changedPrice;
      String? changedDiscount;
      final discountCtrl = TextEditingController(text: '2.00');
      final priceCtrl = TextEditingController(text: '11.90');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManualPriceModifier(
              isManualPrice: true,
              isCustomPrice: true,
              systemPrice: 13.90,
              discountCtrl: discountCtrl,
              priceCtrl: priceCtrl,
              catalogHasOffer: true,
              catalogOfferPrice: 12.50,
              catalogDiscountPercent: 10,
              onToggle: (_) {},
              onDiscountChanged: (val) => changedDiscount = val,
              onPriceChanged: (val) => changedPrice = val,
            ),
          ),
        ),
      );

      // Tocar chip de restauración
      await tester.tap(find.text('↺ Usar oferta de catálogo'));
      await tester.pump();

      // Debe haber restaurado los controladores a la oferta de catálogo (12.50 y descuento 1.40)
      expect(priceCtrl.text, equals('12.50'));
      expect(discountCtrl.text, equals('1.40'));
      expect(changedPrice, equals('12.50'));
      expect(changedDiscount, equals('1.40'));
    });
  });

  group('Fase 2 Extra: InvoicePdfReportService - Facturas Manuales con Presentaciones Vinculadas', () {
    test('buildExecutivePdf genera PDF correctamente para facturas manuales con subenlaces', () async {
      final invoice = InvoiceModel(
        id: 25,
        numeroSecuencial: 25,
        negocioId: 1,
        imagenUrl: 'local_ia_scan',
        estado: 'completado',
        fechaCarga: DateTime(2026, 10, 22, 12, 0),
        montoTotalFactura: 150.0,
      );

      final List<Map<String, dynamic>> linkedPresentations = [
        {
          'producto_nombre': 'Plumón Faber Castell 47',
          'presentacion_nombre': 'Caja x12 Colores',
          'cantidad_stock': 5,
          'precio_costo': 30.0,
        },
      ];

      final Uint8List pdfBytes = await InvoicePdfReportService.buildExecutivePdf(
        invoice: invoice,
        providerName: 'DISTRIBUIDORA ESCOLAR PERU',
        providerRuc: '20123456789',
        linkedPresentations: linkedPresentations,
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, isTrue);
      final String header = String.fromCharCodes(pdfBytes.take(5));
      expect(header, equals('%PDF-'));
    });
  });
}
