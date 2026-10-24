import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_movil/features/smart_quotation/models/pdf_config_model.dart';
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/features/smart_quotation/utils/pdf_generator.dart';
import 'package:app_movil/features/smart_quotation/utils/pdf_image_helper.dart';
import 'package:app_movil/features/smart_quotation/services/pdf_preferences_service.dart';
import 'package:app_movil/core/models/user_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('⚖️ FASE 1 & FASE 2: PdfConfig, Preferencias y PdfImageHelper', () {
    test('1.1. Serialización y deserialización de PdfConfig conserva nuevos campos', () {
      final config = PdfConfig(
        theme: PdfTheme.emerald,
        pageSize: PdfPageSize.ticket80,
        showImages: true,
        documentTitle: "NOTA DE VENTA",
        customClientName: "Comercializadora del Norte",
        footerNote: "Validez 15 días",
        showPaymentAccounts: true,
        showStatusStamp: true,
      );

      final json = config.toJson();
      final restored = PdfConfig.fromJson(json);

      expect(restored.theme, equals(PdfTheme.emerald));
      expect(restored.pageSize, equals(PdfPageSize.ticket80));
      expect(restored.showImages, isTrue);
      expect(restored.documentTitle, equals("NOTA DE VENTA"));
      expect(restored.customClientName, equals("Comercializadora del Norte"));
      expect(restored.footerNote, equals("Validez 15 días"));
      expect(restored.showPaymentAccounts, isTrue);
      expect(restored.showStatusStamp, isTrue);
    });

    test('1.2. PdfPreferencesService preserva estrictamente el documentTitle contextual', () async {
      SharedPreferences.setMockInitialValues({});
      
      // El usuario guarda sus preferencias desde una Cotización
      final userFavConfig = PdfConfig(
        theme: PdfTheme.dark,
        pageSize: PdfPageSize.ticket80,
        showImages: true,
        documentTitle: "COTIZACIÓN", // Título de la pantalla anterior
        footerNote: "Condiciones especiales",
      );
      await PdfPreferencesService.saveDefaultConfig(userFavConfig);

      // Ahora se abre un Comprobante de Venta con título contextual inicial "COMPROBANTE DE PAGO"
      final initialSaleConfig = PdfConfig(
        documentTitle: "COMPROBANTE DE PAGO",
        theme: PdfTheme.modern,
        pageSize: PdfPageSize.a4,
      );

      final applied = await PdfPreferencesService.applySavedPreferences(initialSaleConfig);

      // Verificamos que se adopte el tema y tamaño guardado, pero NO se sobreescriba el título contextual
      expect(applied.theme, equals(PdfTheme.dark));
      expect(applied.pageSize, equals(PdfPageSize.ticket80));
      expect(applied.showImages, isTrue);
      expect(applied.documentTitle, equals("COMPROBANTE DE PAGO"), reason: "Debe preservar el título de la operación en curso");
    });

    test('2.1. PdfImageHelper maneja nulos y extrae iniciales simétricas', () async {
      PdfImageHelper.clearCache();

      // Rutas nulas o inválidas retornan null sin lanzar excepción
      final nullImg = await PdfImageHelper.resolveImage(null);
      final emptyImg = await PdfImageHelper.resolveImage("");
      final stringNullImg = await PdfImageHelper.resolveImage("null");

      expect(nullImg, isNull);
      expect(emptyImg, isNull);
      expect(stringNullImg, isNull);

      // Extracción de iniciales simétricas
      expect(PdfImageHelper.extractInitials("Shampoo Romero"), equals("SR"));
      expect(PdfImageHelper.extractInitials("Cuaderno Standford"), equals("CS"));
      expect(PdfImageHelper.extractInitials("Lapicero"), equals("LA"));
      expect(PdfImageHelper.extractInitials(""), equals("PR"));
    });
  });

  group('⚖️ FASE 3: Filtro Anti-Códigos Internos y Generación de PDF', () {
    test('3.1. isInternalDraftCode bloquea borradores y códigos de sistema', () {
      // Códigos autogenerados que JAMÁS deben mostrarse como clientes
      expect(PdfGenerator.isInternalDraftCode("Cotización Manual #21-1749"), isTrue);
      expect(PdfGenerator.isInternalDraftCode("cotizacion #000006"), isTrue);
      expect(PdfGenerator.isInternalDraftCode("Venta #1234"), isTrue);
      expect(PdfGenerator.isInternalDraftCode("Borrador #44"), isTrue);
      expect(PdfGenerator.isInternalDraftCode("Cliente General"), isTrue);
      expect(PdfGenerator.isInternalDraftCode("Sin cliente"), isTrue);
      expect(PdfGenerator.isInternalDraftCode("Venta de Mostrador"), isTrue);
      expect(PdfGenerator.isInternalDraftCode(null), isTrue);
      expect(PdfGenerator.isInternalDraftCode(""), isTrue);

      // Clientes reales legítimos
      expect(PdfGenerator.isInternalDraftCode("Carlos Mendoza"), isFalse);
      expect(PdfGenerator.isInternalDraftCode("Librería Bazar Luzam"), isFalse);
      expect(PdfGenerator.isInternalDraftCode("Colegio San Carlos"), isFalse);
    });

    test('3.2. Generación exitosa de Cotización Formal en Formato A4', () async {
      final quotation = SmartQuotationModel(
        id: 6,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        totalAmount: 14.46,
        totalSavings: 1.64,
        status: 'READY',
        type: 'manual',
        clientName: "Colegio San Carlos",
        createdAt: DateTime.now().toIso8601String(),
        items: [
          QuotationItem(
            id: 1,
            productName: "Shampoo Romero Anticaída Sachet",
            salesUnit: "Unidad",
            quantity: 2,
            unitPriceApplied: 1.00,
            originalUnitPrice: 1.20,
          ),
          QuotationItem(
            id: 2,
            productName: "Jekeke Color",
            brandName: "San Carlos",
            salesUnit: "Par",
            quantity: 1,
            unitPriceApplied: 12.46,
            originalUnitPrice: 13.90,
          ),
        ],
      );

      final user = UserModel(
        id: 1,
        fullName: "Administrador Luzam",
        phone: "976644890",
        isActive: true,
        business: BusinessModel(
          id: 1,
          commercialName: "Librería Bazar Luzam",
          ruc: "10456789012",
          address: "Talara Centro",
          paymentInfo: "Yape: 976644890 / BCP: 123-456",
        ),
      );

      final config = PdfConfig(
        theme: PdfTheme.modern,
        pageSize: PdfPageSize.a4,
        showImages: true,
        showPaymentAccounts: true,
        footerNote: "Cotización válida por 7 días calendario.",
      );

      final Uint8List pdfBytes = await PdfGenerator.generatePdf(
        quotation: quotation,
        ownerInfo: user,
        config: config,
      );

      expect(pdfBytes, isNotEmpty);
      // Validar firma de archivo PDF (%PDF-)
      final header = String.fromCharCodes(pdfBytes.sublist(0, 5));
      expect(header.startsWith('%PDF'), isTrue);
    });

    test('3.3. Generación exitosa en Formato Ticket Térmico 80mm continuo', () async {
      final quotation = SmartQuotationModel(
        id: 10,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        totalAmount: 25.50,
        totalSavings: 2.00,
        status: 'READY',
        type: 'manual',
        createdAt: DateTime.now().toIso8601String(),
        items: [
          QuotationItem(
            id: 1,
            productName: "Cuaderno Cuadriculado 100h",
            quantity: 3,
            unitPriceApplied: 8.50,
            originalUnitPrice: 9.00,
          ),
        ],
      );

      final config = PdfConfig(
        theme: PdfTheme.emerald,
        pageSize: PdfPageSize.ticket80, // Ticket térmico
        showImages: false,
      );

      final Uint8List ticketBytes = await PdfGenerator.generatePdf(
        quotation: quotation,
        ownerInfo: null,
        config: config,
      );

      expect(ticketBytes, isNotEmpty);
      final header = String.fromCharCodes(ticketBytes.sublist(0, 5));
      expect(header.startsWith('%PDF'), isTrue);
    });

    test('3.4. Verdad contable en Venta a Crédito con Saldo Deudor y Cuotas', () async {
      final quotation = SmartQuotationModel(
        id: 15,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        totalAmount: 100.00,
        totalSavings: 0.0,
        status: 'SOLD',
        type: 'manual',
        createdAt: DateTime.now().toIso8601String(),
        items: [
          QuotationItem(
            id: 1,
            productName: "Mochila Escolar Reforzada",
            quantity: 1,
            unitPriceApplied: 100.00,
            originalUnitPrice: 100.00,
          ),
        ],
      );

      final saleData = {
        'id': 15,
        'fecha_venta': DateTime.now().toIso8601String(),
        'monto_total': 100.00,
        'monto_pagado': 40.00, // Abonó 40, debe 60
        'metodo_pago': 'credito',
        'cliente_nombre': 'María Rodríguez',
        'cliente_telefono': '987654321',
        'cuotas': [
          {
            'numero_cuota': 1,
            'monto': 30.00,
            'fecha_vencimiento': '2026-11-01',
            'estado': 'pendiente',
          },
          {
            'numero_cuota': 2,
            'monto': 30.00,
            'fecha_vencimiento': '2026-12-01',
            'estado': 'pendiente',
          },
        ],
      };

      final config = PdfConfig(
        theme: PdfTheme.dark,
        pageSize: PdfPageSize.a4,
        showTransactionDetails: true,
        showInstallments: true,
        showStatusStamp: true,
      );

      final Uint8List creditBytes = await PdfGenerator.generatePdf(
        quotation: quotation,
        ownerInfo: null,
        config: config,
        saleData: saleData,
      );

      expect(creditBytes, isNotEmpty);
      final header = String.fromCharCodes(creditBytes.sublist(0, 5));
      expect(header.startsWith('%PDF'), isTrue);
    });

    test('3.5. Verdad contable en Préstamo Personal', () async {
      final quotation = SmartQuotationModel(
        id: 20,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        totalAmount: 500.00,
        totalSavings: 0.0,
        status: 'SOLD',
        type: 'manual',
        createdAt: DateTime.now().toIso8601String(),
        items: [],
      );

      final loanData = {
        'id': 20,
        'origen_venta': 'prestamo_personal',
        'fecha_venta': DateTime.now().toIso8601String(),
        'monto_total': 500.00, // Capital
        'monto_interes': 50.00, // Interés acordado
        'monto_pagado': 200.00, // Ha pagado 200 de los 550
        'metodo_pago': 'efectivo',
        'cliente_nombre': 'Roberto Gómez',
      };

      final config = PdfConfig(
        theme: PdfTheme.classic,
        pageSize: PdfPageSize.ticket80,
      );

      final Uint8List loanBytes = await PdfGenerator.generatePdf(
        quotation: quotation,
        ownerInfo: null,
        config: config,
        saleData: loanData,
      );

      expect(loanBytes, isNotEmpty);
      final header = String.fromCharCodes(loanBytes.sublist(0, 5));
      expect(header.startsWith('%PDF'), isTrue);
    });
  });
}
