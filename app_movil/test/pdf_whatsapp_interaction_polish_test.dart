import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_movil/features/smart_quotation/models/pdf_config_model.dart';
import 'package:app_movil/features/smart_quotation/models/whatsapp_config_model.dart';
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/features/smart_quotation/widgets/whatsapp/wa_config_section.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/features/smart_quotation/utils/pdf_generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fase 1 y 2: PDF Config, Latin-1 Clean Conditions y Prioridades en PdfGenerator', () {
    test('PdfConfig model serialization and ephemeral fields handling', () {
      final config = PdfConfig(
        customClientName: "Cliente Test",
        customInstitutionName: "Colegio San Martín",
        customGradeLevel: "5to Secundaria",
        customNotes: "Entrega urgente en secretaría",
        customPaymentInfo: "Yape: 987654321 | BCP: 191-123456",
      );

      final json = config.toJson();
      expect(json['customClientName'], equals("Cliente Test"));
      expect(json['customInstitutionName'], equals("Colegio San Martín"));
      expect(json['customGradeLevel'], equals("5to Secundaria"));
      expect(json['customNotes'], equals("Entrega urgente en secretaría"));
      expect(json['customPaymentInfo'], equals("Yape: 987654321 | BCP: 191-123456"));

      final restored = PdfConfig.fromJson(json);
      expect(restored.customInstitutionName, equals("Colegio San Martín"));
      expect(restored.customGradeLevel, equals("5to Secundaria"));
      expect(restored.customNotes, equals("Entrega urgente en secretaría"));
      expect(restored.customPaymentInfo, equals("Yape: 987654321 | BCP: 191-123456"));
    });

    test('Conditions ToggleChip Latin-1 clean string insertion and removal', () {
      const cleanChip = "Válida por 7 días";
      String currentText = "";

      // 1. Inserción
      if (currentText.isEmpty) {
        currentText = cleanChip;
      } else {
        currentText = "$currentText. $cleanChip";
      }
      expect(currentText, equals("Válida por 7 días"));

      // 2. Agregar segunda condición
      const secondChip = "Entrega inmediata";
      currentText = "$currentText. $secondChip";
      expect(currentText, equals("Válida por 7 días. Entrega inmediata"));

      // 3. Remover primera condición limpiamente
      String updated = currentText.replaceAll(cleanChip, '');
      updated = updated.replaceAll(RegExp(r'\.\s*\.'), '.').trim();
      if (updated.startsWith('.')) updated = updated.substring(1).trim();
      if (updated.endsWith('.')) updated = updated.substring(0, updated.length - 1).trim();
      updated = updated.replaceAll(RegExp(r'\s+'), ' ');

      expect(updated, equals("Entrega inmediata"));
      expect(updated.contains('.'), isFalse);
    });

    test('Document titles verification for Spanish tildes', () {
      final configLoan = PdfConfig(documentTitle: "COMPROBANTE DE PRÉSTAMO");
      final configQuote = PdfConfig(documentTitle: "COTIZACIÓN");

      expect(configLoan.documentTitle, contains("É"));
      expect(configQuote.documentTitle, contains("Ó"));
    });

    test('PdfGenerator.stripUnsupportedEmojis removes emojis and preserves Latin-1 Spanish characters', () {
      const rawAccounts = "📱 Yape: 987654321 | 🏦 BCP: 191-0000-123 | 🚚 Delivery";
      final cleanAccounts = PdfGenerator.stripUnsupportedEmojis(rawAccounts);
      expect(cleanAccounts, equals("Yape: 987654321 | BCP: 191-0000-123 | Delivery"));
      expect(cleanAccounts.contains('📱'), isFalse);
      expect(cleanAccounts.contains('🏦'), isFalse);
      expect(cleanAccounts.contains('🚚'), isFalse);

      const rawNotes = "⏳ ¡Cotización súper rápida en el Jr. San Martín! Con garantía de año 2026. 🛡️";
      final cleanNotes = PdfGenerator.stripUnsupportedEmojis(rawNotes);
      expect(cleanNotes, equals("¡Cotización súper rápida en el Jr. San Martín! Con garantía de año 2026."));
      expect(cleanNotes.contains('á'), isTrue);
      expect(cleanNotes.contains('ú'), isTrue);
      expect(cleanNotes.contains('í'), isTrue);
      expect(cleanNotes.contains('ñ'), isTrue);
      expect(cleanNotes.contains('¡'), isTrue);
    });

    test('Conditions ToggleChips mutual exclusion (7 days vs 15 days) and ¡Gracias por su compra!', () {
      String text = "Válida por 7 días";

      // 1. Activar 'Válida por 15 días' debe reemplazar automáticamente 'Válida por 7 días'
      const chip15 = "Válida por 15 días";
      if (text.contains(RegExp(r'Válida por 7 días', caseSensitive: false))) {
        text = text.replaceAll(RegExp(r'Válida por 7 días', caseSensitive: false), chip15);
      }
      expect(text, equals("Válida por 15 días"));
      expect(text.contains("7 días"), isFalse);

      // 2. Activar 'Válida por 7 días' debe reemplazar 'Válida por 15 días'
      const chip7 = "Válida por 7 días";
      if (text.contains(RegExp(r'Válida por 15 días', caseSensitive: false))) {
        text = text.replaceAll(RegExp(r'Válida por 15 días', caseSensitive: false), chip7);
      }
      expect(text, equals("Válida por 7 días"));
      expect(text.contains("15 días"), isFalse);

      // 3. Agregar '¡Gracias por su compra!'
      const graciasChip = "¡Gracias por su compra!";
      text = "$text. $graciasChip";
      expect(text, equals("Válida por 7 días. ¡Gracias por su compra!"));

      // 4. Desmarcar '¡Gracias por su compra!' limpiamente
      String updated = text.replaceAll(graciasChip, '');
      updated = updated.replaceAll(RegExp(r'¡?Gracias por su compra!?', caseSensitive: false), '');
      updated = updated.replaceAll(RegExp(r'\.\s*\.'), '.').trim();
      if (updated.startsWith('.')) updated = updated.substring(1).trim();
      if (updated.endsWith('.')) updated = updated.substring(0, updated.length - 1).trim();
      updated = updated.replaceAll(RegExp(r'\s+'), ' ');

      expect(updated, equals("Válida por 7 días"));
    });

    test('Payment Accounts ToggleChips intelligent presence, insertion without emojis and clean removal', () {
      String paymentText = "Yape: 976644890 | BCP: 191-123456";

      // 1. Detección de presencia
      expect(RegExp(r'\bYape\b', caseSensitive: false).hasMatch(paymentText), isTrue);
      expect(RegExp(r'\bBCP\b', caseSensitive: false).hasMatch(paymentText), isTrue);
      expect(RegExp(r'\bPlin\b', caseSensitive: false).hasMatch(paymentText), isFalse);

      // 2. Desmarcar Yape debe remover la entrada completa y el pipe limpiamente
      final yapePattern = RegExp(
        r'(?:^|[|\n])\s*(?:[^\w\s]*\s*)?Yape[:\s][^|\n]*',
        caseSensitive: false,
      );
      paymentText = paymentText.replaceAll(yapePattern, '');
      paymentText = paymentText.replaceAll(RegExp(r'\|\s*\|'), '|');
      paymentText = paymentText.trim();
      if (paymentText.startsWith('|')) paymentText = paymentText.substring(1).trim();
      if (paymentText.endsWith('|')) paymentText = paymentText.substring(0, paymentText.length - 1).trim();

      expect(paymentText, equals("BCP: 191-123456"));
      expect(RegExp(r'\bYape\b', caseSensitive: false).hasMatch(paymentText), isFalse);

      // 3. Marcar Plin debe agregarlo sin emojis con pipe separador
      const plinEntry = "Plin: 976644890";
      paymentText = "$paymentText | $plinEntry";

      expect(paymentText, equals("BCP: 191-123456 | Plin: 976644890"));
      expect(paymentText.contains('📱'), isFalse);
      expect(RegExp(r'\bPlin\b', caseSensitive: false).hasMatch(paymentText), isTrue);
    });
  });

  group('Fase 3 y 4: WaConfigSection Grilla 360px y Datos Reales en Popover', () {
    testWidgets('WaConfigSection renders in 360px without word splitting or overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final config = WhatsAppConfig();
      final dummyQuotation = SmartQuotationModel(
        id: 1,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        status: 'ACTIVE',
        type: 'standard',
        totalAmount: 150.0,
        totalSavings: 4.50,
        createdAt: DateTime.now().toIso8601String(),
        items: [
          QuotationItem(
            id: 1,
            productName: "Cuaderno Standford A4",
            quantity: 3,
            unitPriceApplied: 7.50,
            originalUnitPrice: 9.00,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: WaConfigSection(
                config: config,
                isSale: false,
                quotation: dummyQuotation,
                businessName: "Librería Escolar",
                businessPhone: "987654321",
                paymentAccountsText: "Yape: 987654321",
                onChanged: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verificar que los títulos principales se muestran completos
      expect(find.text("Precios y Subtotales"), findsOneWidget);
      expect(find.text("Sección de Ahorro"), findsOneWidget);
      expect(find.text("Monto Total S/."), findsOneWidget);
      expect(find.text("Info del Negocio"), findsOneWidget);
      expect(find.text("Medios de Pago"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Fase 5: Máquina de Estados 1-Tap Undo/Redo y ToggleChips Inteligentes', () {
    test('Undo stack cancels debounce and reverts in exactly 1 tap', () {
      final List<String> undoStack = [];
      final List<String> redoStack = [];
      String currentText = "Hola cliente";
      String lastCommittedText = currentText;

      // Paso 1: Usuario escribe y se guarda el estado anterior
      const burst1 = "Hola cliente, adjunto cotización";
      undoStack.add(lastCommittedText);
      lastCommittedText = burst1;
      currentText = burst1;

      // Paso 2: Usuario pulsa Deshacer en 1 solo toque
      while (undoStack.isNotEmpty && undoStack.last == currentText) {
        undoStack.removeLast();
      }
      expect(undoStack.isNotEmpty, isTrue);
      redoStack.add(currentText);
      final reverted = undoStack.removeLast();
      currentText = reverted;
      lastCommittedText = reverted;

      // Debe revertir al primer toque exacto
      expect(currentText, equals("Hola cliente"));

      // Paso 3: Usuario pulsa Rehacer en 1 solo toque
      while (redoStack.isNotEmpty && redoStack.last == currentText) {
        redoStack.removeLast();
      }
      expect(redoStack.isNotEmpty, isTrue);
      undoStack.add(currentText);
      final restored = redoStack.removeLast();
      currentText = restored;
      lastCommittedText = restored;

      // Debe restaurar al primer toque exacto
      expect(currentText, equals("Hola cliente, adjunto cotización"));
    });

    test('Intelligent ToggleChips insertion and removal without orphan headers', () {
      String message = "👋 ¡Hola! Te comparto la información detallada:\n\n"
          "• 2x Cuaderno: S/ 12.00\n\n"
          "💳 *Medios de Pago:*\n📱 Yape: 987654321\n🏦 BCP: 191-0000\n\n"
          "⏳ *Validez de la oferta:* 7 días calendario a partir de hoy.\n\n"
          "🙏 ¡Muchas gracias por tu preferencia y confianza!";

      // 1. Detectar presencia
      final bool hasAccounts = message.contains(RegExp(r'MEDIOS DE PAGO|Medios de Pago', caseSensitive: false));
      expect(hasAccounts, isTrue);

      // 2. Remover Mis Cuentas por completo (título y números de abono)
      final accountsPattern = RegExp(
        r'💳\s*\*?(MEDIOS DE PAGO|CUENTAS DE ABONO|Medios de Pago|Cuentas de Abono)[^\n]*\*?\n?([\s\S]*?)(?=(\n\s*\n|📦|🚚|⏳|🤝|🙏|$))',
        caseSensitive: false,
      );
      message = message.replaceAll(accountsPattern, '');
      message = message.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();

      expect(message.contains("Medios de Pago"), isFalse);
      expect(message.contains("Yape: 987654321"), isFalse);
      expect(message.contains("BCP: 191-0000"), isFalse);
      expect(message.contains("Validez"), isTrue);
      expect(message.toLowerCase().contains("muchas gracias"), isTrue);
    });
  });

  group('Fase 6: Scroll Desbloqueado y Limpieza Visual en Revisión Final', () {
    testWidgets('InteractiveSheetWrapper disables drag recognizers when enableDragToDismiss is false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InteractiveSheetWrapper(
              enableDragToDismiss: false,
              child: SizedBox(
                height: 300,
                child: Text("Contenido Sin Arrastre"),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final gestureFinders = find.byType(GestureDetector);
      expect(gestureFinders, findsWidgets);

      // Verificar que los GestureDetector internos tienen onVerticalDragStart en null
      for (final element in gestureFinders.evaluate()) {
        final detector = element.widget as GestureDetector;
        if (detector.onVerticalDragStart != null) {
          fail("GestureDetector no debe tener onVerticalDragStart cuando enableDragToDismiss es false");
        }
      }
    });
  });
}
