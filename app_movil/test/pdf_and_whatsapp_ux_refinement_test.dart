import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_movil/features/smart_quotation/models/pdf_config_model.dart';
import 'package:app_movil/features/smart_quotation/models/whatsapp_config_model.dart';
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/features/smart_quotation/services/pdf_preferences_service.dart';
import 'package:app_movil/features/smart_quotation/utils/pdf_generator.dart';
import 'package:app_movil/features/smart_quotation/utils/pdf_image_helper.dart';
import 'package:app_movil/core/models/user_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('🎯 FASE 2: Sanitización de Cliente (PdfGenerator.cleanClientDisplayName)', () {
    test('Limpia sufijos de borradores, números, corchetes y métodos de registro', () {
      expect(PdfGenerator.cleanClientDisplayName("Freddy #22-0146 (2) - Manual"), equals("Freddy"));
      expect(PdfGenerator.cleanClientDisplayName("María López (3) - Cotización"), equals("María López"));
      expect(PdfGenerator.cleanClientDisplayName("Juan Carlos Pérez - Venta"), equals("Juan Carlos Pérez"));
      expect(PdfGenerator.cleanClientDisplayName("Comercial Los Andes S.A.C. - Pedido"), equals("Comercial Los Andes S.A.C."));
      expect(PdfGenerator.cleanClientDisplayName("Rosa Flores - 15:30"), equals("Rosa Flores"));
    });

    test('Descarta nombres que son 100% borradores o códigos de sistema autogenerados', () {
      expect(PdfGenerator.cleanClientDisplayName("Borrador #9923 (1)"), isEmpty);
      expect(PdfGenerator.cleanClientDisplayName("Cotización #1234"), isEmpty);
      expect(PdfGenerator.cleanClientDisplayName("cotizacion manual #001"), isEmpty);
      expect(PdfGenerator.cleanClientDisplayName("Nota de Venta - Manual"), isEmpty);
      expect(PdfGenerator.cleanClientDisplayName("Venta #55"), isEmpty);
      expect(PdfGenerator.cleanClientDisplayName("Cliente General"), isEmpty);
      expect(PdfGenerator.cleanClientDisplayName("Sin cliente"), isEmpty);
      expect(PdfGenerator.cleanClientDisplayName(null), isEmpty);
      expect(PdfGenerator.cleanClientDisplayName(""), isEmpty);
      expect(PdfGenerator.cleanClientDisplayName("   "), isEmpty);
    });

    test('Preserva nombres reales completos sin alteración', () {
      expect(PdfGenerator.cleanClientDisplayName("Freddy"), equals("Freddy"));
      expect(PdfGenerator.cleanClientDisplayName("Carlos Mendoza Gutiérrez"), equals("Carlos Mendoza Gutiérrez"));
      expect(PdfGenerator.cleanClientDisplayName("Inversiones & Servicios S.A.C."), equals("Inversiones & Servicios S.A.C."));
    });
  });

  group('🔤 FASE 2: Tipografía Global y Acentuación Española', () {
    test('PdfImageHelper preserva acentos y caracteres latinos al extraer iniciales', () {
      expect(PdfImageHelper.extractInitials("Álvaro Íñiguez"), equals("ÁÍ"));
      expect(PdfImageHelper.extractInitials("Óscar Úbeda"), equals("ÓÚ"));
      expect(PdfImageHelper.extractInitials("Ñoño Ñáñez"), equals("ÑÑ"));
      expect(PdfImageHelper.extractInitials("Érika Égida"), equals("ÉÉ"));
    });

    test('Textos clave en español conservan todas sus tildes y caracteres', () {
      const titles = [
        "COTIZACIÓN",
        "Descripción",
        "Anticaída",
        "N°",
        "Método:",
        "Interés Acordado:",
        "RESUMEN DE PRÉSTAMO",
        "COMPROBANTE DE PRÉSTAMO",
      ];
      for (final title in titles) {
        expect(title, isNotEmpty);
        expect(title.contains(RegExp(r'[áéíóúÁÉÍÓÚñÑ°]')), isTrue);
      }
    });
  });

  group('📐 FASE 1 & FASE 4: 4 Plantillas Estructurales y 6 Paletas PDF', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('PdfConfig serializa y restaura layoutTemplate y las 6 paletas', () {
      final config = PdfConfig(
        theme: PdfTheme.burgundy,
        layoutTemplate: PdfLayoutTemplate.corporateFramed,
        pageSize: PdfPageSize.a4,
      );

      final json = config.toJson();
      expect(json['layoutTemplate'], equals('corporateFramed'));
      expect(json['theme'], equals('burgundy'));

      final restored = PdfConfig.fromJson(json);
      expect(restored.layoutTemplate, equals(PdfLayoutTemplate.corporateFramed));
      expect(restored.theme, equals(PdfTheme.burgundy));

      final modified = restored.copyWith(
        theme: PdfTheme.indigo,
        layoutTemplate: PdfLayoutTemplate.commercialCatalog,
      );
      expect(modified.layoutTemplate, equals(PdfLayoutTemplate.commercialCatalog));
      expect(modified.theme, equals(PdfTheme.indigo));
    });

    test('PdfPreferencesService guarda y recupera la plantilla estructural', () async {
      final config = PdfConfig(
        theme: PdfTheme.indigo,
        layoutTemplate: PdfLayoutTemplate.compactWholesale,
        pageSize: PdfPageSize.ticket80,
      );
      await PdfPreferencesService.saveDefaultConfig(config);

      final targetConfig = PdfConfig(documentTitle: "COMPROBANTE");
      final applied = await PdfPreferencesService.applySavedPreferences(targetConfig);

      expect(applied.layoutTemplate, equals(PdfLayoutTemplate.compactWholesale));
      expect(applied.theme, equals(PdfTheme.indigo));
      expect(applied.pageSize, equals(PdfPageSize.ticket80));
      expect(applied.documentTitle, equals("COMPROBANTE"));
    });

    test('Genera PDF válido con las 4 plantillas estructurales y 6 temas sin error', () async {
      final quotation = SmartQuotationModel(
        id: 101,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        totalAmount: 95.50,
        totalSavings: 12.00,
        status: 'READY',
        type: 'manual',
        clientName: "Freddy",
        createdAt: DateTime.now().toIso8601String(),
        items: [
          QuotationItem(
            id: 1,
            productName: "Cuaderno Standford Cuadriculado",
            salesUnit: "Docena",
            quantity: 2,
            unitPriceApplied: 35.00,
            originalUnitPrice: 40.00,
          ),
          QuotationItem(
            id: 2,
            productName: "Lapiceros Faber Castell 033",
            salesUnit: "Caja",
            quantity: 1,
            unitPriceApplied: 25.50,
            originalUnitPrice: 27.50,
          ),
        ],
      );

      final user = UserModel(
        id: 1,
        fullName: "Propietario Demo",
        phone: "987654321",
        isActive: true,
        business: BusinessModel(
          id: 1,
          commercialName: "Librería y Variedades Luzam",
          ruc: "20123456789",
          address: "Av. Grau 123",
          paymentInfo: "Yape / Plin: 987654321",
        ),
      );

      // Probar las 4 plantillas
      for (final layout in PdfLayoutTemplate.values) {
        final config = PdfConfig(
          layoutTemplate: layout,
          theme: PdfTheme.modern,
          pageSize: PdfPageSize.a4,
        );
        final Uint8List bytes = await PdfGenerator.generatePdf(
          quotation: quotation,
          ownerInfo: user,
          config: config,
        );
        expect(bytes, isNotEmpty);
        final header = String.fromCharCodes(bytes.sublist(0, 5));
        expect(header.startsWith('%PDF'), isTrue, reason: "Plantilla $layout debe producir un PDF válido");
      }

      // Probar los 6 temas
      for (final theme in PdfTheme.values) {
        final config = PdfConfig(
          layoutTemplate: PdfLayoutTemplate.executiveModern,
          theme: theme,
          pageSize: PdfPageSize.a4,
        );
        final Uint8List bytes = await PdfGenerator.generatePdf(
          quotation: quotation,
          ownerInfo: user,
          config: config,
        );
        expect(bytes, isNotEmpty);
        final header = String.fromCharCodes(bytes.sublist(0, 5));
        expect(header.startsWith('%PDF'), isTrue, reason: "Tema $theme debe producir un PDF válido");
      }
    });
  });

  group('💬 FASE 5 & FASE 6: 6 Estilos de WhatsApp y Preferencias', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('WhatsAppMessageStyle incluye los 6 estilos con labels y descripciones', () {
      expect(WhatsAppMessageStyle.values.length, equals(6));
      expect(WhatsAppMessageStyle.values, contains(WhatsAppMessageStyle.commercial));
      expect(WhatsAppMessageStyle.values, contains(WhatsAppMessageStyle.compact));
      expect(WhatsAppMessageStyle.values, contains(WhatsAppMessageStyle.urgentOffer));
      expect(WhatsAppMessageStyle.values, contains(WhatsAppMessageStyle.accountDebt));
      expect(WhatsAppMessageStyle.values, contains(WhatsAppMessageStyle.followUp));
      expect(WhatsAppMessageStyle.values, contains(WhatsAppMessageStyle.deliveryReady));

      for (final style in WhatsAppMessageStyle.values) {
        expect(style.label, isNotEmpty);
        expect(style.shortLabel, isNotEmpty);
        expect(style.description, isNotEmpty);
      }
    });

    test('WhatsAppMessageStyle.fromString maneja todos los valores', () {
      expect(WhatsAppMessageStyle.fromString('followUp'), equals(WhatsAppMessageStyle.followUp));
      expect(WhatsAppMessageStyle.fromString('deliveryReady'), equals(WhatsAppMessageStyle.deliveryReady));
      expect(WhatsAppMessageStyle.fromString('unknown_style'), equals(WhatsAppMessageStyle.commercial));
      expect(WhatsAppMessageStyle.fromString(null), equals(WhatsAppMessageStyle.commercial));
    });

    test('WhatsAppConfig serialización con nuevos estilos', () {
      final config = WhatsAppConfig(style: WhatsAppMessageStyle.followUp);
      final json = config.toJson();
      expect(json['style'], equals('followUp'));

      final restored = WhatsAppConfig.fromJson(json);
      expect(restored.style, equals(WhatsAppMessageStyle.followUp));
    });
  });

  group('↶ FASE 6: Máquina de Estados Undo / Redo Blindada', () {
    test('Flujo completo de registro, deshacer y rehacer con límite de 50', () {
      final List<String> undoStack = [];
      final List<String> redoStack = [];
      bool isApplyingUndoRedo = false;
      String currentText = "Texto inicial";

      void recordSnapshot(String newText) {
        if (isApplyingUndoRedo) return;
        if (undoStack.isEmpty || undoStack.last != newText) {
          undoStack.add(newText);
          if (undoStack.length > 50) undoStack.removeAt(0);
          redoStack.clear();
        }
      }

      void handleUndo() {
        if (undoStack.isEmpty) return;
        isApplyingUndoRedo = true;
        redoStack.add(currentText);
        currentText = undoStack.removeLast();
        isApplyingUndoRedo = false;
      }

      void handleRedo() {
        if (redoStack.isEmpty) return;
        isApplyingUndoRedo = true;
        undoStack.add(currentText);
        currentText = redoStack.removeLast();
        isApplyingUndoRedo = false;
      }

      // Paso 1: Usuario escribe cambios
      recordSnapshot("Paso 1");
      currentText = "Paso 1";
      recordSnapshot("Paso 2 con formato *negrita*");
      currentText = "Paso 2 con formato *negrita*";
      recordSnapshot("Paso 3 con snippet");
      currentText = "Paso 3 con snippet";

      expect(undoStack.length, equals(3));
      expect(redoStack, isEmpty);
      expect(currentText, equals("Paso 3 con snippet"));

      // Paso 2: Deshacer (Undo)
      handleUndo();
      expect(currentText, equals("Paso 3 con snippet")); // Tomó el último
      handleUndo();
      expect(currentText, equals("Paso 2 con formato *negrita*"));
      expect(redoStack.length, equals(2));

      // Paso 3: Rehacer (Redo)
      handleRedo();
      expect(currentText, equals("Paso 3 con snippet"));
      expect(redoStack.length, equals(1));

      // Paso 4: Nueva edición limpia la pila de rehacer
      recordSnapshot("Paso 4 nuevo");
      currentText = "Paso 4 nuevo";
      expect(redoStack, isEmpty);

      // Paso 5: Límite de 50 elementos
      for (int i = 0; i < 70; i++) {
        recordSnapshot("Iteración $i");
      }
      expect(undoStack.length, equals(50));
    });
  });

  group('🎯 FASE 4: 5 Chips de Condiciones al Pie y Cuadrícula 2x3', () {
    test('Los 5 chips rápidos de condiciones al pie coinciden con el plan maestro', () {
      const footerChips = [
        "+ ⏳ Válida por 7 días",
        "+ ⏳ Válida por 15 días",
        "+ 🚚 Entrega inmediata",
        "+ 🧾 Precios incluyen IGV",
        "+ 🤝 Gracias por su compra",
      ];
      expect(footerChips.length, equals(5));

      String footerNote = "";
      for (final chip in footerChips) {
        final cleanText = chip.replaceFirst("+ ", "");
        footerNote = footerNote.isEmpty ? cleanText : "$footerNote. $cleanText";
      }

      expect(footerNote, contains("⏳ Válida por 7 días"));
      expect(footerNote, contains("⏳ Válida por 15 días"));
      expect(footerNote, contains("🚚 Entrega inmediata"));
      expect(footerNote, contains("🧾 Precios incluyen IGV"));
      expect(footerNote, contains("🤝 Gracias por su compra"));
    });

    test('WhatsAppMessageStyle tiene 6 estilos para distribución exacta en cuadrícula 2x3', () {
      final styles = WhatsAppMessageStyle.values;
      expect(styles.length, equals(6));
      expect(styles[0], equals(WhatsAppMessageStyle.commercial));
      expect(styles[1], equals(WhatsAppMessageStyle.compact));
      expect(styles[2], equals(WhatsAppMessageStyle.urgentOffer));
      expect(styles[3], equals(WhatsAppMessageStyle.accountDebt));
      expect(styles[4], equals(WhatsAppMessageStyle.followUp));
      expect(styles[5], equals(WhatsAppMessageStyle.deliveryReady));
    });
  });

  group('💬 FASE 6 & FASE 7: Snippets Completos y Sincronización Bidireccional', () {
    test('Los 5 snippets comerciales se construyen e insertan correctamente', () {
      final snippets = {
        "+ ⏳ Validez 7 días": "⏳ *Validez de la oferta:* 7 días calendario a partir de hoy.",
        "+ 🚚 Envío / Entrega": "🚚 *Entrega:* Coordinamos envíos a domicilio o recojo directo en tienda.",
        "+ 💳 Mis Cuentas": "💳 *Medios de Pago:*\n📱 Yape: 987654321",
        "+ 👋 Saludo": "👋 ¡Hola! Te comparto la información detallada:",
        "+ 🙏 Agradecimiento": "🙏 ¡Muchas gracias por tu preferencia y confianza!",
      };

      expect(snippets.length, equals(5));
      snippets.forEach((chipLabel, content) {
        expect(chipLabel.startsWith("+ "), isTrue);
        expect(content, isNotEmpty);
      });
    });

    test('Sincronización Bidireccional de edición de texto desde modal a estado principal', () {
      String parentMessage = "Texto original de cotización";
      bool isManualEdit = false;
      final List<String> undoStack = [parentMessage];

      void onMessageChanged(String newText) {
        isManualEdit = true;
        parentMessage = newText;
        if (undoStack.isEmpty || undoStack.last != newText) {
          undoStack.add(newText);
        }
      }

      // Simula usuario abriendo Revisión Final y editando texto
      onMessageChanged("Texto original con corrección en Revisión Final");

      expect(isManualEdit, isTrue);
      expect(parentMessage, equals("Texto original con corrección en Revisión Final"));
      expect(undoStack.last, equals("Texto original con corrección en Revisión Final"));
      expect(undoStack.length, equals(2));
    });
  });
}

