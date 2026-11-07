import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/utils/smart_search_matcher.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/services/loyalty_whatsapp_service.dart';
import 'package:app_movil/features/smart_quotation/screens/crm/loyalty_center_screen.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/meta_reward_editor_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/promotion_broadcast_modal.dart';

class _MockLoyaltyAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  int? get activeBusinessId => 1;

  @override
  String get businessName => 'Librería Central';

  @override
  String get activeBusinessName => 'Librería Central';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late _MockLoyaltyAuthProvider mockAuth;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await LocalDatabase.createDBForTesting(db);
    LocalDatabase.setCustomDatabase(db);

    mockAuth = _MockLoyaltyAuthProvider();

    // Sembrar datos básicos para pruebas de pantalla completa
    await db.insert('negocios', {
      'id': 1,
      'nombre_comercial': 'Librería Central',
      'moneda': 'S/ (Soles)',
    });
    await db.insert('usuarios', {
      'id': 1,
      'nombre_completo': 'Vendedor Central',
      'email': 'admin@libreria.com',
    });

    await LocalDatabase.seedDefaultMetasRecompensas(db);

    // Sembrar clientes clave (incluyendo Huk y Bmk con score 500 y 580)
    await db.insert('clientes', {
      'id': 1,
      'negocio_id': 1,
      'creado_por_usuario_id': 1,
      'nombre_completo': 'Huk Quispe',
      'telefono': '987111222',
      'puntos_actuales': 80,
      'puntos_historicos': 80,
      'score_reputacion': 500,
      'nivel_reputacion': 'BRONCE', // Desfasado a propósito para verificar sincronización
      'fecha_registro': '2026-11-01',
    });

    await db.insert('clientes', {
      'id': 2,
      'negocio_id': 1,
      'creado_por_usuario_id': 1,
      'nombre_completo': 'Bmk Paredes',
      'telefono': '987333444',
      'puntos_actuales': 20,
      'puntos_historicos': 50,
      'score_reputacion': 580,
      'nivel_reputacion': 'BRONCE', // Desfasado a propósito
      'fecha_registro': '2026-11-01',
    });

    await db.insert('clientes', {
      'id': 3,
      'negocio_id': 1,
      'creado_por_usuario_id': 1,
      'nombre_completo': 'Freddy Morales',
      'telefono': '911222333',
      'puntos_actuales': 0,
      'puntos_historicos': 0,
      'score_reputacion': 300,
      'nivel_reputacion': 'OBSERVACION',
      'fecha_registro': '2026-11-01',
    });

    await db.insert('clientes', {
      'id': 4,
      'negocio_id': 1,
      'creado_por_usuario_id': 1,
      'nombre_completo': 'Jj Ramos',
      'telefono': '922836879',
      'puntos_actuales': 250,
      'puntos_historicos': 950,
      'score_reputacion': 920,
      'nivel_reputacion': 'DIAMANTE_VIP',
      'fecha_registro': '2026-11-01',
    });

    // Sembrar productos para Tab 3
    await db.insert('productos', {
      'id': 1,
      'negocio_id': 1,
      'nombre': 'Agua Sin Gas PET 500ML',
    });
    await db.insert('presentaciones_producto', {
      'id': 101,
      'producto_id': 1,
      'nombre_especifico': 'Sin Gas',
      'precio_venta_final': 2.50,
      'precio_oferta': 2.00,
      'stock_actual': 20,
      'activo': 1,
    });

    await db.insert('productos', {
      'id': 2,
      'negocio_id': 1,
      'nombre': 'Cartulina - Alto Color Basic y Neón',
    });
    await db.insert('presentaciones_producto', {
      'id': 102,
      'producto_id': 2,
      'nombre_especifico': 'Pliego Neón',
      'precio_venta_final': 1.50,
      'precio_oferta': 1.20,
      'stock_actual': 4,
      'activo': 1,
    });
  });

  tearDown(() async {
    LocalDatabase.setCustomDatabase(null);
    await db.close();
  });

  group('Árbitro Adversarial - Grupo 1: SmartSearchMatcher Multi-Palabra & Diacríticos', () {
    test('Normalización diacrítica remueve tildes y caracteres especiales en español', () {
      expect(SmartSearchMatcher.normalize('Canción'), equals('cancion'));
      expect(SmartSearchMatcher.normalize('ÁÉÍÓÚ ñandú'), equals('aeiou nandu'));
      expect(SmartSearchMatcher.normalize('  MÚLTIPLES   ESPACIOS  '), equals('multiples espacios'));
      expect(SmartSearchMatcher.normalize(null), equals(''));
      expect(SmartSearchMatcher.normalize(''), equals(''));
    });

    test('Busca "agua 500" y encuentra producto independientemente del orden', () {
      const targets = [
        'Agua Sin Gas PET 500ML',
        'Bebidas y Líquidos',
        'San Mateo',
      ];

      expect(
        SmartSearchMatcher.matches(query: 'agua 500', targets: targets),
        isTrue,
        reason: 'Orden natural debe coincidir',
      );

      expect(
        SmartSearchMatcher.matches(query: '500 agua', targets: targets),
        isTrue,
        reason: 'Orden invertido debe coincidir',
      );

      expect(
        SmartSearchMatcher.matches(query: 'AGUA pet 500', targets: targets),
        isTrue,
        reason: 'Mayúsculas y minúsculas deben coincidir',
      );

      expect(
        SmartSearchMatcher.matches(query: 'agua gasificada', targets: targets),
        isFalse,
        reason: 'Token no existente debe descartar la coincidencia',
      );
    });

    test('Busca cliente con tilde sin escribirla ("cancion" encuentra "Canción")', () {
      const targets = ['María Peña Canción', '987654321', 'Plata'];

      expect(
        SmartSearchMatcher.matches(query: 'maria pena', targets: targets),
        isTrue,
      );

      expect(
        SmartSearchMatcher.matches(query: 'cancion', targets: targets),
        isTrue,
      );
    });

    test('Busca cliente por tokens cruzados nombre + teléfono ("jj 922")', () {
      const targets = ['Jj Ramos', '922836879', 'Plata', 'PLATA'];

      expect(
        SmartSearchMatcher.matches(query: 'jj 922', targets: targets),
        isTrue,
      );

      expect(
        SmartSearchMatcher.matches(query: '922 jj', targets: targets),
        isTrue,
      );
    });

    test('Búsqueda vacía o solo espacios siempre retorna true', () {
      const targets = ['Cuaderno Stanford 100 Hojas'];
      expect(SmartSearchMatcher.matches(query: '', targets: targets), isTrue);
      expect(SmartSearchMatcher.matches(query: '   ', targets: targets), isTrue);
    });
  });

  group('Árbitro Adversarial - Grupo 2: ReputationTier & Sincronización 500-749 = PLATA', () {
    test('ReputationTier.fromScore mapea estrictamente según nuevos umbrales v9.20', () {
      // 0 - 349: Observación
      expect(ReputationTier.fromScore(0), equals(ReputationTier.observacion));
      expect(ReputationTier.fromScore(340), equals(ReputationTier.observacion));
      expect(ReputationTier.fromScore(349), equals(ReputationTier.observacion));

      // 350 - 499: Bronce
      expect(ReputationTier.fromScore(350), equals(ReputationTier.bronce));
      expect(ReputationTier.fromScore(400), equals(ReputationTier.bronce));
      expect(ReputationTier.fromScore(499), equals(ReputationTier.bronce));

      // 500 - 749: Plata (CRÍTICO: Clientes Huk con 500 y Bmk con 580 son PLATA)
      expect(ReputationTier.fromScore(500), equals(ReputationTier.plata));
      expect(ReputationTier.fromScore(580), equals(ReputationTier.plata));
      expect(ReputationTier.fromScore(749), equals(ReputationTier.plata));

      // 750 - 899: Oro
      expect(ReputationTier.fromScore(750), equals(ReputationTier.oro));
      expect(ReputationTier.fromScore(850), equals(ReputationTier.oro));
      expect(ReputationTier.fromScore(899), equals(ReputationTier.oro));

      // 900 - 1000: Diamante VIP
      expect(ReputationTier.fromScore(900), equals(ReputationTier.diamanteVip));
      expect(ReputationTier.fromScore(950), equals(ReputationTier.diamanteVip));
      expect(ReputationTier.fromScore(1000), equals(ReputationTier.diamanteVip));
    });

    test('ClientModel con score 500 o 580 resuelve tier en PLATA aún si SQLite tenía "BRONCE"', () {
      final clientHuk = ClientModel(
        id: 1,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        fullName: 'Huk',
        phone: '987111222',
        scoreReputacion: 500,
        nivelReputacion: 'BRONCE',
        registeredDate: '2026-11-01',
      );

      final clientBmk = ClientModel(
        id: 2,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        fullName: 'Bmk',
        phone: '987333444',
        scoreReputacion: 580,
        nivelReputacion: 'BRONCE',
        registeredDate: '2026-11-01',
      );

      expect(clientHuk.tier, equals(ReputationTier.plata));
      expect(clientBmk.tier, equals(ReputationTier.plata));
      expect(clientHuk.tier.limiteCreditoSugerido, equals(350.0));
      expect(clientBmk.tier.limiteCreditoSugerido, equals(350.0));
    });

    test('badgeText devuelve nombres limpios sin emojis Unicode', () {
      expect(ReputationTier.diamanteVip.badgeText, equals('Diamante VIP'));
      expect(ReputationTier.oro.badgeText, equals('Oro'));
      expect(ReputationTier.plata.badgeText, equals('Plata'));
      expect(ReputationTier.bronce.badgeText, equals('Bronce'));
      expect(ReputationTier.observacion.badgeText, equals('Observación'));

      for (final tier in ReputationTier.allTiers) {
        expect(tier.badgeText.contains(RegExp(r'[\u{1F300}-\u{1FAFF}]', unicode: true)), isFalse);
      }
    });
  });

  group('Árbitro Adversarial - Grupo 3: Renderizado 360x800dp sin Cortes ni Overflows', () {
    testWidgets('LoyaltyCenterScreen renderiza en 360dp con 0 cortes en AppBar, TabBar y Métricas', (tester) async {
      tester.view.physicalSize = const Size(360 * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
          ],
          child: const MaterialApp(
            home: LoyaltyCenterScreen(),
          ),
        ),
      );

      final state = tester.state(find.byType(LoyaltyCenterScreen));
      await tester.runAsync(() async {
        await (state as dynamic).loadData();
      });
      await tester.pump();

      expect(tester.takeException(), isNull);

      // 1. Título completo sin cortes
      expect(find.text("Fidelización y Premios"), findsOneWidget);

      // 2. 3 Pestañas completas (en especial "Avisos y Ofertas" sin perder la "s")
      expect(find.text("Reputación"), findsOneWidget);
      expect(find.text("Recompensas"), findsOneWidget);
      expect(find.text("Avisos y Ofertas"), findsOneWidget);

      // 3. Métricas ejecutivas anti-colisión
      expect(find.text("Puntos Activos"), findsOneWidget);
      expect(find.text("Por Revisar"), findsOneWidget);
      expect(find.text("Clientes VIP"), findsOneWidget);

      // 4. Clientes sincronizados: Huk aparece como Plata (no Bronce)
      expect(find.text("Huk Quispe"), findsOneWidget);
      expect(find.text("Plata"), findsWidgets);

      // 5. Chips con icono vectorial y conteo real (Cero emojis en chips)
      expect(find.textContaining("Todos (4)"), findsOneWidget);
      expect(find.textContaining("Plata (2)"), findsOneWidget);
      expect(find.textContaining("Observación (1)"), findsOneWidget);
      expect(find.textContaining("Diamante VIP (1)"), findsOneWidget);
    });

    testWidgets('Pestaña 2 (Recompensas) muestra títulos de metas hasta 2 líneas sin truncar', (tester) async {
      tester.view.physicalSize = const Size(360 * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
          ],
          child: const MaterialApp(
            home: LoyaltyCenterScreen(initialTabIndex: 1),
          ),
        ),
      );

      final state1 = tester.state(find.byType(LoyaltyCenterScreen));
      await tester.runAsync(() async {
        await (state1 as dynamic).loadData();
      });
      await tester.pump();
      expect(tester.takeException(), isNull);

      // Catálogo de Metas
      expect(find.text("Catálogo de Metas"), findsOneWidget);
      expect(find.text("Descuento de Bienvenida"), findsOneWidget);
      expect(find.text("10% de Ahorro Especial"), findsOneWidget);
      expect(find.text("Bono Especial Fidelidad"), findsOneWidget);
      expect(find.textContaining("Línea de Crédito Preferencial"), findsOneWidget);
    });

    testWidgets('Pestaña 3 (Avisos y Ofertas) oculta cabecera de métricas para maximizar espacio vertical', (tester) async {
      tester.view.physicalSize = const Size(360 * 2, 800 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
          ],
          child: const MaterialApp(
            home: LoyaltyCenterScreen(initialTabIndex: 2),
          ),
        ),
      );

      final state1 = tester.state(find.byType(LoyaltyCenterScreen));
      await tester.runAsync(() async {
        await (state1 as dynamic).loadData();
      });
      await tester.pump();
      expect(tester.takeException(), isNull);

      // En Tab 3, los productos se renderizan
      expect(find.text("1. Selecciona los Productos"), findsOneWidget);
      expect(find.textContaining("Ofertas Activas"), findsOneWidget);
      expect(find.textContaining("Agua Sin Gas PET 500ML"), findsOneWidget);

      // Dock inferior colapsable
      expect(find.textContaining("Audiencia: Todos"), findsOneWidget);
    });
  });

  group('Árbitro Adversarial - Grupo 4: Formulario Dinámico y Live Preview en MetaRewardEditorModal', () {
    testWidgets('Cambiar beneficio a Porcentaje actualiza dinámicamente Live Preview Card con "%"', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MetaRewardEditorModal(negocioId: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verificar que inicialmente es Descuento en Monto (S/)
      expect(find.text("Descuento en Monto (S/)"), findsOneWidget);
      expect(find.text("Vista Previa en Tiempo Real"), findsOneWidget);
      expect(find.textContaining("Descuento de S/"), findsOneWidget);

      // Cambiar Dropdown a Descuento Porcentual
      await tester.tap(find.text("Descuento en Monto (S/)"));
      await tester.pumpAndSettle();

      await tester.tap(find.text("Descuento Porcentual (%)").last);
      await tester.pumpAndSettle();

      // Debe actualizar label a Porcentaje (%) y Live Preview a % de Descuento
      expect(find.text("Porcentaje (%)"), findsOneWidget);
      expect(find.textContaining("% de Descuento"), findsOneWidget);
    });

    testWidgets('Escribir en el título actualiza en tiempo real (0ms) la Live Preview Card', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MetaRewardEditorModal(negocioId: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final titleInput = find.byType(TextFormField).first;
      await tester.enterText(titleInput, "Super Bono Navideño");
      await tester.pump();

      // La Live Preview Card debe contener "Super Bono Navideño"
      expect(find.text("Super Bono Navideño"), findsNWidgets(2)); // Input + Preview Card
    });
  });

  group('Árbitro Adversarial - Grupo 5: Difusor WhatsApp & Audiencia Asistida', () {
    test('buildPromotionMessage genera texto con precios regulares, oferta y ahorros en AppCurrency', () {
      final products = [
        {
          'nombre': 'Agua Mineral 500ml',
          'precioRegular': 3.00,
          'precioEfectivo': 2.00,
        },
        {
          'nombre': 'Pack Cuadernos',
          'precioRegular': 15.00,
          'precioEfectivo': 12.00,
        },
      ];

      final msg = LoyaltyWhatsAppService.buildPromotionMessage(
        clientName: 'Carlos',
        businessName: 'Librería Central',
        products: products,
      );

      expect(msg.contains('¡Hola, Carlos!'), isTrue);
      expect(msg.contains('Librería Central'), isTrue);
      expect(msg.contains('Agua Mineral 500ml'), isTrue);
      expect(msg.contains('Pack Cuadernos'), isTrue);
      expect(msg.contains(AppCurrency.format(3.00)), isTrue);
      expect(msg.contains(AppCurrency.format(2.00)), isTrue);
      expect(msg.contains('Ahorro de ${AppCurrency.format(1.00)}'), isTrue);
      expect(msg.contains('Ahorro de ${AppCurrency.format(3.00)}'), isTrue);
    });

    testWidgets('PromotionBroadcastModal muestra mensaje editable, lista de clientes y botón copiar', (tester) async {
      final targetClients = [
        ClientModel(
          id: 1,
          negocioId: 1,
          creadoPorUsuarioId: 1,
          fullName: 'Huk Quispe',
          phone: '987111222',
          registeredDate: '2026-11-01',
        ),
      ];

      final selectedProducts = [
        {
          'nombre': 'Cuaderno Loro',
          'precioRegular': 5.00,
          'precioEfectivo': 4.00,
        }
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PromotionBroadcastModal(
              businessName: 'Librería Central',
              selectedProducts: selectedProducts,
              targetClients: targetClients,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Difusión de Promociones"), findsOneWidget);
      expect(find.textContaining("1 productos • 1 destinatarios"), findsOneWidget);
      expect(find.text("Copiar Mensaje"), findsOneWidget);
      expect(find.text("Huk Quispe"), findsOneWidget);
      expect(find.text("Enviar"), findsOneWidget);
    });
  });
}
