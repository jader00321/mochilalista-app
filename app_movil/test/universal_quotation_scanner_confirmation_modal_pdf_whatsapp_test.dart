import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/models/user_model.dart';
import 'package:app_movil/features/smart_quotation/providers/smart_quotation_provider.dart';
import 'package:app_movil/features/smart_quotation/models/extracted_list_model.dart';
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/features/smart_quotation/models/whatsapp_config_model.dart';
import 'package:app_movil/features/smart_quotation/services/quotation_naming_engine.dart';
import 'package:app_movil/features/smart_quotation/services/matching_service.dart';
import 'package:app_movil/features/smart_quotation/screens/extraction_result_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/whatsapp_preview_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/matching_screen.dart';
import 'package:app_movil/features/smart_quotation/widgets/extraction/quotation_confirmation_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/whatsapp/wa_message_editor.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';

class _MockTestAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  bool get isCommunityClient => false;

  @override
  BusinessModel? get currentBusiness => null;

  @override
  String get businessName => "Mi Negocio";

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockTestSmartQuotationProvider extends ChangeNotifier implements SmartQuotationProvider {
  @override
  File? get currentImage => null;

  @override
  List<ExtractedItem> get items => [];

  @override
  ExtractedMetadata? get metadata => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('🛡️ SUITE ADVERSARIAL: UNIVERSALIZACIÓN COTIZADOR IA, MODAL CONFIRMACIÓN, PDF Y WHATSAPP', () {
    
    // =========================================================================
    // VECTOR A1 & A5: MATCHING SERVICE - PRIORIDAD MAYORISTA VS MENUDEO
    // =========================================================================
    group('Vector A1 & A5: MatchingService Ponderación Mayorista y Fallback', () {
      test('Vector A1: Coincidencia explícita de empaque mayorista otorga +35 puntos', () {
        final bonus = MatchingService.calculatePresentationBonus(
          presUnit: 'Caja',
          presName: 'Caja x 20 unidades',
          itemUnit: 'caja',
          prioritizeWholesale: true,
        );
        expect(bonus, equals(35));
      });

      test('Vector A1: Estrategia mayorista otorga +25 puntos a presentaciones por volumen', () {
        final bonus = MatchingService.calculatePresentationBonus(
          presUnit: 'Paquete',
          presName: 'Paquete x 10',
          itemUnit: null, // El usuario no especificó unidad pero activó modo mayorista
          prioritizeWholesale: true,
        );
        expect(bonus, equals(25));
      });

      test('Vector A5: Fallback a unidad cuando producto no tiene empaque mayorista (+0 bono mayorista)', () {
        final bonus = MatchingService.calculatePresentationBonus(
          presUnit: 'Unidad',
          presName: 'Individual',
          itemUnit: 'paquete',
          prioritizeWholesale: true,
        );
        // Al no haber empaque mayorista, el bono mayorista es 0 y el algoritmo empareja con la unidad base sin romperse
        expect(bonus, equals(0));
      });

      test('Modo Menudeo / Precio Público prioriza unidad (+10 puntos)', () {
        final bonus = MatchingService.calculatePresentationBonus(
          presUnit: 'Unidad',
          presName: 'Individual',
          itemUnit: 'unidad',
          prioritizeWholesale: false,
        );
        expect(bonus, equals(10));
      });
    });

    // =========================================================================
    // VECTOR A2: EXTRACCIÓN Y DETECCIÓN DE MODOS CONTEXTUALES
    // =========================================================================
    group('Vector A2: Modos Contextuales QuotationContextMode y Serialización', () {
      test('Serialización y deserialización de QuotationContextMode', () {
        expect(QuotationContextMode.general.name, equals('general'));
        expect(QuotationContextMode.wholesale.name, equals('wholesale'));
        expect(QuotationContextMode.school.name, equals('school'));

        expect(QuotationContextMode.values.firstWhere((e) => e.name == 'general'), equals(QuotationContextMode.general));
        expect(QuotationContextMode.values.firstWhere((e) => e.name == 'wholesale'), equals(QuotationContextMode.wholesale));
        expect(QuotationContextMode.values.firstWhere((e) => e.name == 'school'), equals(QuotationContextMode.school));
      });

      test('ExtractedMetadata almacena contextMode y datos comerciales', () {
        final meta = ExtractedMetadata(
          contextMode: QuotationContextMode.wholesale,
          clientOrContactName: 'Freddy Rodriguez',
          businessOrInstitutionName: 'Bodega San José EIRL',
          phone: '976644890',
          referenceNotes: 'Pedido semanal de abarrotes',
        );

        final json = meta.toJson();
        expect(json['context_mode'], equals('wholesale'));
        expect(json['client_or_contact_name'], equals('Freddy Rodriguez'));
        expect(json['business_or_institution_name'], equals('Bodega San José EIRL'));
        expect(json['phone'], equals('976644890'));
        expect(json['reference_notes'], equals('Pedido semanal de abarrotes'));

        final deserialized = ExtractedMetadata.fromJson(json);
        expect(deserialized.contextMode, equals(QuotationContextMode.wholesale));
        expect(deserialized.clientOrContactName, equals('Freddy Rodriguez'));
        expect(deserialized.businessOrInstitutionName, equals('Bodega San José EIRL'));
        expect(deserialized.phone, equals('976644890'));
        expect(deserialized.referenceNotes, equals('Pedido semanal de abarrotes'));
      });
    });

    // =========================================================================
    // VECTOR A3: PRESERVACIÓN DE CAMPOS ADAPTATIVOS
    // =========================================================================
    group('Vector A3: Preservación de Datos al Alternar de Modo en UI', () {
      test('ExtractedMetadata.copyWith conserva campos no sobreescritos al cambiar modo', () {
        var metadata = ExtractedMetadata(
          contextMode: QuotationContextMode.school,
          institutionName: 'Colegio San Pedro',
          studentName: 'Mateo Quispe',
          gradeLevel: '3° Primaria',
        );

        // El comerciante cambia de Escolar a Mayorista
        metadata = metadata.copyWith(
          contextMode: QuotationContextMode.wholesale,
          businessOrInstitutionName: 'Comercial Quispe',
        );

        // Los datos previamente digitados deben conservarse
        expect(metadata.contextMode, equals(QuotationContextMode.wholesale));
        expect(metadata.studentName, equals('Mateo Quispe'));
        expect(metadata.businessOrInstitutionName, equals('Comercial Quispe'));
      });
    });

    // =========================================================================
    // VECTOR A4: DEDUPLICACIÓN INTELIGENTE DE TEXTO (displayNameClean)
    // =========================================================================
    group('Vector A4: Deduplicador Inteligente displayNameClean sin Repeticiones', () {
      test('Caso Real 1: Elimina marca y variantes repetidas preservando pack/medida', () {
        final item = QuotationItem(
          id: 1,
          productId: 10,
          productName: 'Agua Sin Gas PET 500ML',
          brandName: 'San Carlos',
          specificName: 'Sin Gas 500ml x 20 Transparente',
          quantity: 2,
          unitPriceApplied: 1.00,
          originalUnitPrice: 1.00,
        );

        final clean = item.displayNameClean;
        // No debe repetir "Sin Gas" ni "500ml"
        expect(clean, equals('Agua Sin Gas PET 500ML (San Carlos • x 20 Transparente)'));
      });

      test('Caso Real 2: Elimina marca repetida en nombre de producto', () {
        final item = QuotationItem(
          id: 2,
          productId: 20,
          productName: 'Gaseosa concordia PET 355ML',
          brandName: 'Concordia',
          specificName: 'Concordia Cultura 355ml x 15',
          quantity: 1,
          unitPriceApplied: 1.00,
          originalUnitPrice: 1.00,
        );

        final clean = item.displayNameClean;
        // "Concordia" ya está en el producto, solo debe conservar "Cultura x 15"
        expect(clean, equals('Gaseosa concordia PET 355ML (Cultura x 15)'));
      });

      test('Caso 3: Producto limpio sin marca redundante', () {
        final item = QuotationItem(
          id: 3,
          productId: 30,
          productName: 'Cuaderno Cuadriculado 100h',
          brandName: 'Standford',
          specificName: 'Azul',
          quantity: 3,
          unitPriceApplied: 5.50,
          originalUnitPrice: 6.00,
        );

        final clean = item.displayNameClean;
        expect(clean, equals('Cuaderno Cuadriculado 100h (Standford • Azul)'));
      });

      test('Caso 4: Producto sin variantes secundarias', () {
        final item = QuotationItem(
          id: 4,
          productId: 40,
          productName: 'Lápiz Grafito 2B',
          brandName: null,
          specificName: null,
          quantity: 1,
          unitPriceApplied: 1.50,
          originalUnitPrice: 1.50,
        );

        expect(item.displayNameClean, equals('Lápiz Grafito 2B'));
      });
    });

    // =========================================================================
    // VECTOR A6: QUOTATION NAMING ENGINE CONTEXTUAL Y FORMATO DE MONEDA
    // =========================================================================
    group('Vector A6: Nombramiento Contextual y Formato de Moneda Estricto', () {
      test('Nombramiento para Pedido Mayorista sin grados escolares', () {
        final title = QuotationNamingEngine.generateTitle(
          typedClientName: 'Freddy',
          schoolName: 'Bodega San José',
          gradeLevel: null,
          quotationType: 'ai_scan',
          contextMode: QuotationContextMode.wholesale,
        );

        expect(title.contains('Bodega San José (Freddy)'), isTrue);
        expect(title.contains('[IA]'), isTrue);
        expect(title.contains('°'), isFalse);
        expect(title.contains('Primaria'), isFalse);
      });

      test('Nombramiento para Pedido General sin grados escolares', () {
        final title = QuotationNamingEngine.generateTitle(
          typedClientName: 'María Pérez',
          quotationType: 'ai_scan',
          contextMode: QuotationContextMode.general,
        );

        expect(title.contains('María Pérez'), isTrue);
        expect(title.contains('[IA]'), isTrue);
        expect(title.contains('°'), isFalse);
      });

      test('Nombramiento para Lista Escolar incluye colegio y grado', () {
        final title = QuotationNamingEngine.generateTitle(
          typedClientName: 'Juan Pérez',
          schoolName: 'Colegio Santa Rosa',
          gradeLevel: '5° Primaria',
          quotationType: 'ai_scan',
          contextMode: QuotationContextMode.school,
        );

        expect(title.contains('Juan Pérez · Colegio Santa Rosa (5° Primaria)'), isTrue);
        expect(title.contains('[IA]'), isTrue);
      });

      test('Formato de Moneda Estricto (S/ X.XX, Erradicación de 1,00 S/)', () {
        final formatted1 = AppCurrency.format(1.00);
        final formatted2 = AppCurrency.format(2.00);
        final formatted5 = AppCurrency.format(5.00);

        expect(formatted1, equals('S/ 1.00'));
        expect(formatted2, equals('S/ 2.00'));
        expect(formatted5, equals('S/ 5.00'));

        // Garantizar que no contiene el formato invertido con coma
        expect(formatted1.contains('1,00 S/'), isFalse);
        expect(formatted2.contains('2,00 S/'), isFalse);
      });
    });

    // =========================================================================
    // VECTOR A7: RETROCOMPATIBILIDAD 100% SQLITE Y GETTERS HISTÓRICOS
    // =========================================================================
    group('Vector A7: Retrocompatibilidad Total SQLite y Getters Históricos', () {
      test('ExtractedMetadata mantiene getters retrocompatibles studentName, institutionName, gradeLevel', () {
        final meta = ExtractedMetadata(
          contextMode: QuotationContextMode.school,
          institutionName: 'Colegio Nacional',
          studentName: 'Carlos Gómez',
          gradeLevel: '6° Grado',
        );

        // Getters tradicionales no deben romper
        expect(meta.institutionName, equals('Colegio Nacional'));
        expect(meta.studentName, equals('Carlos Gómez'));
        expect(meta.gradeLevel, equals('6° Grado'));

        // Nuevos getters alias
        expect(meta.businessOrInstitutionName, equals('Colegio Nacional'));
        expect(meta.clientOrContactName, equals('Carlos Gómez'));
      });

      test('SmartQuotationModel infiere contextMode automáticamente desde institutionName histórico', () {
        final quotationWholesale = SmartQuotationModel(
          id: 1,
          negocioId: 1,
          creadoPorUsuarioId: 1,
          institutionName: 'Bodega El Triunfo SAC - RUC 20456789012',
          totalAmount: 150.00,
          totalSavings: 15.00,
          status: 'PENDING',
          type: 'ai_scan',
          createdAt: DateTime.now().toIso8601String(),
        );

        expect(quotationWholesale.contextMode, equals(QuotationContextMode.wholesale));

        final quotationSchool = SmartQuotationModel(
          id: 2,
          negocioId: 1,
          creadoPorUsuarioId: 1,
          institutionName: 'I.E. 1024 Santa María',
          gradeLevel: '2° Primaria',
          totalAmount: 85.00,
          totalSavings: 5.00,
          status: 'PENDING',
          type: 'ai_scan',
          createdAt: DateTime.now().toIso8601String(),
        );

        expect(quotationSchool.contextMode, equals(QuotationContextMode.school));
      });
    });

    // =========================================================================
    // WHATSAPP CONFIG & MATRIZ DE ESCENARIOS
    // =========================================================================
    group('WhatsApp Config y Plantillas por Escenario', () {
      test('WhatsAppMessageStyle incluye wholesale y school', () {
        expect(WhatsAppMessageStyle.wholesale.label, equals('Mayorista / Negocio'));
        expect(WhatsAppMessageStyle.school.label, equals('Lista Escolar'));
        expect(WhatsAppMessageStyle.commercial.label, equals('Estándar / Pedido'));
        expect(WhatsAppMessageStyle.compact.label, equals('Resumen Rápido'));
      });

      test('WhatsAppConfig inicializa flags showUnitPrices, showBrandPackage, showClientData en true', () {
        final config = WhatsAppConfig();
        expect(config.showUnitPrices, isTrue);
        expect(config.showBrandPackage, isTrue);
        expect(config.showClientData, isTrue);
      });
    });

    // =========================================================================
    // PERSISTENCIA Y RECONSTRUCCIÓN DE MODOS (SQLITE / JSON)
    // =========================================================================
    group('Vector A7 & Persistencia: Reconstrucción y Fidelidad de Modos en SQLite', () {
      test('Cotización general sin colegio ni grado se reconstruye como general (no escolar)', () {
        final q = SmartQuotationModel(
          id: 1,
          negocioId: 1,
          creadoPorUsuarioId: 1,
          clientName: 'Juan Pérez',
          totalAmount: 100.0,
          totalSavings: 0.0,
          status: 'PENDING',
          type: 'ai_scan',
          createdAt: '2026-11-12',
          items: [],
        );
        expect(q.contextMode, equals(QuotationContextMode.general));
      });

      test('Cotización mayorista con tag [modo:wholesale] o [mayorista] persiste y se reconstruye como wholesale', () {
        final json = {
          'id': 2,
          'negocio_id': 1,
          'creado_por_usuario_id': 1,
          'client_name': 'Bodega San Martín',
          'notas': 'Pedido por fardo [modo:wholesale]',
          'total_amount': 500.0,
          'total_savings': 50.0,
          'status': 'PENDING',
          'type': 'ai_scan',
          'created_at': '2026-11-12',
        };
        final q = SmartQuotationModel.fromJson(json);
        expect(q.contextMode, equals(QuotationContextMode.wholesale));
        expect(q.displayNotas, equals('Pedido por fardo'));
      });

      test('Cotización escolar con colegio o grado se reconstruye como school', () {
        final json = {
          'id': 3,
          'negocio_id': 1,
          'creado_por_usuario_id': 1,
          'client_name': 'Mateo Ruiz',
          'institution_name': 'Colegio San Agustín',
          'grade_level': '3° Primaria',
          'total_amount': 150.0,
          'total_savings': 10.0,
          'status': 'PENDING',
          'type': 'ai_scan',
          'created_at': '2026-11-12',
        };
        final q = SmartQuotationModel.fromJson(json);
        expect(q.contextMode, equals(QuotationContextMode.school));
      });
    });

    // =========================================================================
    // WIDGET TESTS: CONFIRMATION MODAL, EXTRACTION & WHATSAPP SCREENS
    // =========================================================================
    group('Widget Tests: Modal Confirmación, ExtractionResultScreen y WhatsApp', () {
      testWidgets('QuotationConfirmationModal renderiza estrategia mayorista y menudeo en 360x640dp sin overflows', (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        bool? confirmedWholesale;
        QuotationContextMode? confirmedMode;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    QuotationConfirmationModal.show(
                      context: context,
                      totalItems: 15,
                      readyItems: 15,
                      zeroOrEmptyItems: 0,
                      currentMode: QuotationContextMode.general,
                      onConfirm: (prioritizeWholesale, mode) {
                        confirmedWholesale = prioritizeWholesale;
                        confirmedMode = mode;
                      },
                    );
                  },
                  child: const Text('Abrir Modal'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Abrir Modal'));
        await tester.pumpAndSettle();

        expect(find.text('Generar Cotización'), findsOneWidget);
        expect(find.text('Vas a cotizar 15 de 15 productos'), findsOneWidget);
        expect(find.text('📦 Priorizar Mayorista / Cajas / Paquetes'), findsOneWidget);
        expect(find.text('🏷️ Precio Público / Menudeo'), findsOneWidget);

        // Seleccionar modo mayorista asegurando visibilidad dentro del scroll
        await tester.ensureVisible(find.text('📦 Priorizar Mayorista / Cajas / Paquetes'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('📦 Priorizar Mayorista / Cajas / Paquetes'));
        await tester.pumpAndSettle();

        // Confirmar (los botones inferiores están fijos y accesibles sin overflow)
        await tester.tap(find.text('Sí, Cotizar →'));
        await tester.pumpAndSettle();

        expect(confirmedWholesale, isTrue);
        expect(confirmedMode, equals(QuotationContextMode.general));
      });

      testWidgets('QuotationConfirmationModal en pantalla ultra-compacta 320x568dp mantiene botones accesibles sin overflow', (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        bool confirmed = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    QuotationConfirmationModal.show(
                      context: context,
                      totalItems: 10,
                      readyItems: 10,
                      zeroOrEmptyItems: 0,
                      currentMode: QuotationContextMode.wholesale,
                      onConfirm: (prioritizeWholesale, mode) {
                        confirmed = true;
                      },
                    );
                  },
                  child: const Text('Abrir Modal 320'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Abrir Modal 320'));
        await tester.pumpAndSettle();

        expect(find.text('Generar Cotización'), findsOneWidget);
        expect(find.text('Sí, Cotizar →'), findsOneWidget);

        await tester.tap(find.text('Sí, Cotizar →'));
        await tester.pumpAndSettle();

        expect(confirmed, isTrue);
      });

      testWidgets('WaMessageEditor renderiza los 5 chips modulares y los 4 estilos de escenario', (tester) async {
        final ctrl = TextEditingController(text: "¡Hola! Detalle de pedido");
        final config = WhatsAppConfig();
        String? lastToggled;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: WaMessageEditor(
                  isDark: false,
                  isManualEdit: false,
                  messageCtrl: ctrl,
                  onChanged: (_) {},
                  config: config,
                  onStyleChanged: (_) {},
                  onRegenerateAuto: () {},
                  onOptionToggled: (key, _) => lastToggled = key,
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verificar 4 plantillas visibles
        expect(find.text('Estándar / Pedido'), findsOneWidget);
        expect(find.text('Mayorista / Negocio'), findsOneWidget);
        expect(find.text('Resumen Rápido'), findsOneWidget);
        expect(find.text('Lista Escolar'), findsOneWidget);

        // Verificar los 5 chips modulares
        expect(find.text('Precios Unitarios (c/u)'), findsOneWidget);
        expect(find.text('Marca / Empaque'), findsOneWidget);
        expect(find.text('Datos del Cliente / RUC'), findsOneWidget);
        expect(find.text('Validez'), findsOneWidget);
        expect(find.text('Medios de Pago'), findsOneWidget);

        // Tocar chip modular de Precios Unitarios
        await tester.tap(find.text('Precios Unitarios (c/u)'));
        await tester.pumpAndSettle();
        expect(lastToggled, equals('unit_prices'));

        // Tocar chip modular de Marca / Empaque
        await tester.tap(find.text('Marca / Empaque'));
        await tester.pumpAndSettle();
        expect(lastToggled, equals('brand_package'));

        // Tocar chip modular de Datos del Cliente / RUC
        await tester.tap(find.text('Datos del Cliente / RUC'));
        await tester.pumpAndSettle();
        expect(lastToggled, equals('client_data'));

        // Tocar chip modular de Validez
        await tester.tap(find.text('Validez'));
        await tester.pumpAndSettle();
        expect(lastToggled, equals('validity'));

        // Tocar chip modular de Medios de Pago
        await tester.tap(find.text('Medios de Pago'));
        await tester.pumpAndSettle();
        expect(lastToggled, equals('payment'));

        // Tocar plantilla de Mayorista
        await tester.tap(find.text('Mayorista / Negocio'));
        await tester.pumpAndSettle();

        // Verificar botones directos
        expect(find.text('Restaurar'), findsOneWidget);
        expect(find.text('Copiar'), findsOneWidget);
      });

      test('ExtractionResultScreen, WhatsAppPreviewScreen y MatchingScreen instancian con parámetros universales', () {
        const extractionScreen = ExtractionResultScreen();
        expect(extractionScreen, isNotNull);

        const waScreen = WhatsAppPreviewScreen(
          quotationId: 42,
          contextMode: QuotationContextMode.wholesale,
        );
        expect(waScreen.quotationId, equals(42));
        expect(waScreen.contextMode, equals(QuotationContextMode.wholesale));

        final matchingScreen = MatchingScreen(
          extractedItems: const [],
          metadata: ExtractedMetadata(contextMode: QuotationContextMode.general),
          prioritizeWholesale: true,
        );
        expect(matchingScreen.prioritizeWholesale, isTrue);
        expect(matchingScreen.metadata?.contextMode, equals(QuotationContextMode.general));
      });

      testWidgets('ExtractionResultScreen y WhatsAppPreviewScreen renderizan y compilan correctamente en árbol de widgets', (tester) async {
        final mockAuth = _MockTestAuthProvider();
        final mockQuotation = _MockTestSmartQuotationProvider();

        // 1. Renderizar ExtractionResultScreen
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
              ChangeNotifierProvider<SmartQuotationProvider>.value(value: mockQuotation),
            ],
            child: const MaterialApp(
              home: ExtractionResultScreen(),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(ExtractionResultScreen), findsOneWidget);

        // 2. Renderizar WhatsAppPreviewScreen con modo mayorista
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
              ChangeNotifierProvider<SmartQuotationProvider>.value(value: mockQuotation),
            ],
            child: const MaterialApp(
              home: WhatsAppPreviewScreen(
                contextMode: QuotationContextMode.wholesale,
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(WhatsAppPreviewScreen), findsOneWidget);
      });
    });

  });
}
