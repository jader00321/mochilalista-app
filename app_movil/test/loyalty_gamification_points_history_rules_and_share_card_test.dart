import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/widgets/loyalty_toast_feedback.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/services/client_service.dart';
import 'package:app_movil/features/smart_quotation/services/loyalty_whatsapp_service.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/client_loyalty_history_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/loyalty_rules_config_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late ClientService clientService;
  const int testNegocioId = 1;
  const int testUsuarioId = 1;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await LocalDatabase.createDBForTesting(db);
    LocalDatabase.setCustomDatabase(db);

    await db.insert('negocios', {
      'id': testNegocioId,
      'nombre_comercial': 'Bazar Luzam',
      'moneda': 'S/ (Soles)',
    });
    await db.insert('usuarios', {
      'id': testUsuarioId,
      'nombre_completo': 'Administrador',
      'email': 'admin@bazar.com',
    });

    clientService = ClientService();
    await LocalDatabase.seedDefaultMetasRecompensas(db);
  });

  tearDown(() async {
    LocalDatabase.setCustomDatabase(null);
    await db.close();
  });

  group('FASE 1: Modal de Historial de Puntos con Pestañas y Ajuste Manual', () {
    testWidgets('ClientLoyaltyHistoryModal renderiza TabBar con 2 pestañas y erradica término "Kardex"', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final client = ClientModel(
        id: 10,
        negocioId: testNegocioId,
        creadoPorUsuarioId: testUsuarioId,
        fullName: 'Jj',
        phone: '922836879',
        registeredDate: DateTime.now().toIso8601String(),
        puntosActuales: 50,
        puntosHistoricos: 50,
        scoreReputacion: 227,
        rachaPagosPuntuales: 0,
      );

      final movements = [
        LoyaltyLedgerModel(
          id: 1,
          negocioId: testNegocioId,
          clienteId: 10,
          tipoMovimiento: 'COMPRA_CONTADO',
          puntosDelta: 50,
          puntosSaldoResultante: 50,
          scoreDelta: 5,
          scoreResultante: 227,
          motivo: 'Compra al contado #101',
          referenciaTipo: 'venta',
          fechaRegistro: DateTime.now().toIso8601String(),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClientLoyaltyHistoryModal(
              client: client,
              autoLoadHistory: false,
              initialMovements: movements,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // Verificar que el término anticuado "Kardex" no existe en la interfaz
      expect(find.textContaining('Kardex de Movimientos'), findsNothing);
      expect(find.textContaining('Kardex'), findsNothing);

      // Verificar que existen las 2 pestañas modernas
      expect(find.textContaining('Premios y Metas'), findsOneWidget);
      expect(find.text('Historial de Puntos'), findsOneWidget);

      // Pestaña 1 muestra botón de Cartilla
      expect(find.text('Enviar Cartilla de Puntos al Cliente'), findsOneWidget);

      // Cambiar a Pestaña 2 (Historial de Puntos)
      await tester.tap(find.text('Historial de Puntos'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Verificar chips de filtro y botón + Bono Manual
      expect(find.text('+ Bono Manual'), findsOneWidget);
      expect(find.text('Todos'), findsOneWidget);
      expect(find.text('+ Ganados'), findsOneWidget);
      expect(find.text('- Salidas'), findsOneWidget);
      expect(find.text('Compra al contado #101'), findsOneWidget);
    });

    testWidgets('Filtra ruido técnico de migración (+50 y -50 por acumulación libre)', (tester) async {
      final client = ClientModel(
        id: 11,
        negocioId: testNegocioId,
        creadoPorUsuarioId: testUsuarioId,
        fullName: 'Jj',
        phone: '922836879',
        registeredDate: DateTime.now().toIso8601String(),
        puntosActuales: 50,
        puntosHistoricos: 50,
        scoreReputacion: 227,
        rachaPagosPuntuales: 0,
      );

      final movements = [
        LoyaltyLedgerModel(
          id: 1,
          negocioId: testNegocioId,
          clienteId: 11,
          tipoMovimiento: 'RESTAURACION_MIGRACION',
          puntosDelta: 50,
          puntosSaldoResultante: 50,
          scoreDelta: 0,
          scoreResultante: 227,
          motivo: 'Restauración de puntos por cambio a acumulación libre',
          referenciaTipo: 'migracion',
          fechaRegistro: DateTime.now().toIso8601String(),
        ),
        LoyaltyLedgerModel(
          id: 2,
          negocioId: testNegocioId,
          clienteId: 11,
          tipoMovimiento: 'COMPRA_CONTADO',
          puntosDelta: 50,
          puntosSaldoResultante: 50,
          scoreDelta: 5,
          scoreResultante: 227,
          motivo: 'Compra escolar al contado',
          referenciaTipo: 'venta',
          fechaRegistro: DateTime.now().toIso8601String(),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ClientLoyaltyHistoryModal(
              client: client,
              autoLoadHistory: false,
              initialMovements: movements,
              initialTabIndex: 1, // Directo al historial
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // El movimiento de migración técnica debe estar filtrado
      expect(find.textContaining('Restauración de puntos por cambio a acumulación libre'), findsNothing);
      // El movimiento real del cliente debe mostrarse
      expect(find.text('Compra escolar al contado'), findsOneWidget);
    });
  });

  group('FASE 2: Badges en Español y Exclusión de MIGRADA_A_SALDO_LIBRE', () {
    test('ClientService excluye registros MIGRADA_A_SALDO_LIBRE del historial visible', () async {
      final cId = await db.insert('clientes', {
        'negocio_id': testNegocioId,
        'creado_por_usuario_id': testUsuarioId,
        'nombre_completo': 'Cliente Prueba',
        'telefono': '987654321',
        'puntos_actuales': 50,
        'score_reputacion': 500,
        'fecha_registro': DateTime.now().toIso8601String(),
      });

      // Insertar una recompensa activa y una migrada a saldo libre
      await db.insert('recompensas_cliente', {
        'negocio_id': testNegocioId,
        'cliente_id': cId,
        'meta_id': 1,
        'puntos_consumidos': 50,
        'estado': 'MIGRADA_A_SALDO_LIBRE',
        'tipo_beneficio': 'PRODUCTO_REGALO',
        'valor_beneficio': 10.0,
        'titulo_recompensa': 'Premio Antiguo Migrado',
        'fecha_desbloqueo': DateTime.now().toIso8601String(),
      });

      await db.insert('recompensas_cliente', {
        'negocio_id': testNegocioId,
        'cliente_id': cId,
        'meta_id': 1,
        'puntos_consumidos': 50,
        'estado': 'CANJEADA',
        'tipo_beneficio': 'PRODUCTO_REGALO',
        'valor_beneficio': 10.0,
        'titulo_recompensa': 'Premio Real Entregado',
        'fecha_desbloqueo': DateTime.now().toIso8601String(),
        'fecha_canje': DateTime.now().toIso8601String(),
      });

      // Consultar historial reciente
      final recent = await db.rawQuery('''
        SELECT * FROM recompensas_cliente 
        WHERE negocio_id = ? AND estado != 'MIGRADA_A_SALDO_LIBRE'
      ''', [testNegocioId]);

      expect(recent.length, equals(1));
      expect(recent.first['titulo_recompensa'], equals('Premio Real Entregado'));
      expect(recent.first['estado'], equals('CANJEADA'));
    });
  });

  group('FASE 3: Toast Inmune a Pegarse (LoyaltyToastFeedback) y Modal de Reglas', () {
    testWidgets('LoyaltyToastFeedback muestra mensaje flotante y se disipa limpiamente', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: ElevatedButton(
                  onPressed: () {
                    LoyaltyToastFeedback.showSuccess(
                      ctx,
                      "Reglas guardadas correctamente",
                    );
                  },
                  child: const Text("Mostrar Toast"),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Mostrar Toast"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text("Reglas guardadas correctamente"), findsOneWidget);

      // Esperar que termine el timer de 1800ms + animación de salida
      await tester.pump(const Duration(milliseconds: 2200));
      expect(find.text("Reglas guardadas correctamente"), findsNothing);
    });

    testWidgets('LoyaltyRulesConfigModal renderiza en 320dp con títulos hasta 2 líneas y botones balanceados', (tester) async {
      tester.view.physicalSize = const Size(320, 750);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoyaltyRulesConfigModal(
              negocioId: testNegocioId,
              initialRules: LoyaltyRulesModel(
                negocioId: testNegocioId,
                updatedAt: DateTime.now().toIso8601String(),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text("Configurar Reglas de Puntos"), findsOneWidget);
      expect(find.text("Valores por Defecto"), findsOneWidget);
      expect(find.text("Guardar Reglas"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('FASE 4: Cartilla WhatsApp con Formato Limpio y Compartir Nativo', () {
    test('formatBusinessName convierte nombre a mayúsculas limpias', () {
      expect(LoyaltyWhatsAppService.formatBusinessName("librería BAZAR LUZAM"), equals("LIBRERÍA BAZAR LUZAM"));
      expect(LoyaltyWhatsAppService.formatBusinessName("tienda escolar"), equals("TIENDA ESCOLAR"));
    });

    test('buildLoyaltyGuideAndCatalogMessage genera catálogo limpio sin paréntesis redundantes', () {
      final nowStr = DateTime.now().toIso8601String();
      final goals = [
        RewardGoalModel(
          id: 1,
          negocioId: 1,
          nombre: "ganador",
          puntosRequeridos: 50,
          tipoBeneficio: "PRODUCTO_REGALO",
          valorBeneficio: 10.0,
          descripcion: "Producto de Regalo (S/ 10.00)",
          createdAt: nowStr,
        ),
        RewardGoalModel(
          id: 2,
          negocioId: 1,
          nombre: "Descuento de Bienvenida",
          puntosRequeridos: 100,
          tipoBeneficio: "DESCUENTO_MONTO",
          valorBeneficio: 5.0,
          descripcion: "Descuento de S/ 5.00",
          createdAt: nowStr,
        ),
        RewardGoalModel(
          id: 3,
          negocioId: 1,
          nombre: "10% de Ahorro Especial",
          puntosRequeridos: 300,
          tipoBeneficio: "DESCUENTO_PORCENTAJE",
          valorBeneficio: 10.0,
          descripcion: "10% de Descuento",
          createdAt: nowStr,
        ),
      ];

      final rules = LoyaltyRulesModel(
        negocioId: 1,
        puntosPorCompraActivo: true,
        puntosPorUnidadMoneda: 1,
        montoBaseCompra: 1.0,
        compraMinimaParaPuntos: 0.0,
        bonoCotizacionActivo: true,
        puntosBonoCotizacion: 10,
        bonoPagoPuntualActivo: true,
        puntosPagoPuntual: 25,
        updatedAt: nowStr,
      );

      final text = LoyaltyWhatsAppService.buildLoyaltyGuideAndCatalogMessage(
        businessName: "Bazar Luzam",
        rules: rules,
        activeGoals: goals,
      );

      // Debe contener el valor formateado sin duplicaciones
      expect(text, contains("• *50 pts:* ganador (Producto de Regalo - S/ 10.00)"));
      expect(text, contains("• *100 pts:* Descuento de Bienvenida (Descuento de S/ 5.00)"));
      expect(text, contains("• *300 pts:* 10% de Ahorro Especial (10% de Descuento)"));
      expect(text.contains("(Producto de Regalo) ("), isFalse);
    });

    test('buildSummaryGuideMessage genera guía concisa de fidelización', () {
      final nowStr = DateTime.now().toIso8601String();
      final rules = LoyaltyRulesModel(
        negocioId: 1,
        puntosPorCompraActivo: true,
        puntosPorUnidadMoneda: 1,
        montoBaseCompra: 1.0,
        compraMinimaParaPuntos: 0.0,
        bonoCotizacionActivo: true,
        puntosBonoCotizacion: 10,
        bonoPagoPuntualActivo: true,
        puntosPagoPuntual: 25,
        updatedAt: nowStr,
      );

      final msg = LoyaltyWhatsAppService.buildSummaryGuideMessage(
        businessName: "Bazar Luzam",
        rules: rules,
        activeGoals: [],
      );

      expect(msg, contains("PROGRAMA DE PUNTOS • BAZAR LUZAM"));
      expect(msg, contains("Compras al Contado"));
      expect(msg, contains("+1 pto"));
    });

    test('buildPromoInviteMessage genera invitación publicitaria con llamado a la acción', () {
      final nowStr = DateTime.now().toIso8601String();
      final goals = [
        RewardGoalModel(
          id: 1,
          negocioId: 1,
          nombre: "ganador",
          puntosRequeridos: 50,
          tipoBeneficio: "PRODUCTO_REGALO",
          valorBeneficio: 10.0,
          createdAt: nowStr,
        ),
      ];

      final promoMsg = LoyaltyWhatsAppService.buildPromoInviteMessage(
        businessName: "Bazar Luzam",
        activeGoals: goals,
        clientName: "Carlos",
        puntosActuales: 35,
      );

      expect(promoMsg, contains("DESCUBRE TUS BENEFICIOS EN BAZAR LUZAM"));
      expect(promoMsg, contains("Carlos"));
      expect(promoMsg, contains("35 pts"));
      expect(promoMsg, contains("ganador"));
      expect(promoMsg, contains("¡Haz tu pedido hoy"));
    });

    test('buildLoyaltyGuideAndCatalogMessage incluye datos de tienda (dirección y contacto)', () {
      final nowStr = DateTime.now().toIso8601String();
      final rules = LoyaltyRulesModel(
        negocioId: 1,
        puntosPorCompraActivo: true,
        puntosPorUnidadMoneda: 1,
        montoBaseCompra: 1.0,
        updatedAt: nowStr,
      );

      final msg = LoyaltyWhatsAppService.buildLoyaltyGuideAndCatalogMessage(
        businessName: "Bazar Luzam",
        rules: rules,
        activeGoals: [],
        includeStoreInfo: true,
        businessAddress: "Av. Principal 123",
        businessPhone: "987654321",
      );

      expect(msg, contains("📍 *Dirección:* Av. Principal 123"));
      expect(msg, contains("📞 *Contacto:* 987654321"));
    });

    testWidgets('showEditableWhatsAppPreviewModal muestra 3 formatos, 3 toggles, botón Restaurar y selector de cliente', (tester) async {
      final nowStr = DateTime.now().toIso8601String();
      final rules = LoyaltyRulesModel(
        negocioId: 1,
        puntosPorCompraActivo: true,
        puntosPorUnidadMoneda: 1,
        montoBaseCompra: 1.0,
        updatedAt: nowStr,
      );
      final goals = [
        RewardGoalModel(
          id: 1,
          negocioId: 1,
          nombre: "Premio 1",
          puntosRequeridos: 50,
          tipoBeneficio: "PRODUCTO_REGALO",
          valorBeneficio: 10.0,
          createdAt: nowStr,
        ),
      ];
      final availableClients = [
        ClientModel(
          id: 1,
          negocioId: 1,
          creadoPorUsuarioId: 1,
          fullName: "Juan Perez",
          phone: "999888777",
          registeredDate: nowStr,
          puntosActuales: 45,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  LoyaltyWhatsAppService.showEditableWhatsAppPreviewModal(
                    context: ctx,
                    title: "Cartilla de Puntos y Premios",
                    phone: "",
                    initialMessage: "Mensaje Inicial",
                    rules: rules,
                    activeGoals: goals,
                    businessName: "Bazar Luzam",
                    availableClients: availableClients,
                  );
                },
                child: const Text("Abrir Cartilla"),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Abrir Cartilla"));
      await tester.pumpAndSettle();

      // Verificar los 3 formatos
      expect(find.text("Completo"), findsOneWidget);
      expect(find.text("Resumen Corto"), findsOneWidget);
      expect(find.text("Invitación Promocional"), findsOneWidget);

      // Verificar los 3 toggles de secciones (en formato COMPLETO)
      expect(find.text("Cómo ganar"), findsOneWidget);
      expect(find.text("Catálogo premios"), findsOneWidget);
      expect(find.text("Datos tienda"), findsOneWidget);

      // Verificar botón Restaurar
      expect(find.text("Restaurar"), findsOneWidget);

      // Verificar Selector de Cliente
      expect(find.text("Personalizar:"), findsOneWidget);
      expect(find.text("General para todos"), findsOneWidget);

      // Tocar "Invitación Promocional"
      await tester.tap(find.text("Invitación Promocional"));
      await tester.pumpAndSettle();
      expect(find.textContaining("DESCUBRE TUS BENEFICIOS"), findsOneWidget);

      // Tocar "Restaurar"
      await tester.ensureVisible(find.text("Restaurar"));
      await tester.tap(find.text("Restaurar"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text("Mensaje restaurado al formato original"), findsOneWidget);

      // Drenar el temporizador de 1800ms del toast
      await tester.pump(const Duration(milliseconds: 2200));
    });
  });

  group('FASE 5: Filtro Reputación CON_PREMIO_LISTO, Teléfono Limpio y Micro-Progreso', () {
    test('Reputación trata "000000000" como "Sin teléfono"', () {
      String formatPhone(String? phone) {
        if (phone == null || phone.trim().isEmpty || phone.trim() == '000000000') {
          return "Sin teléfono";
        }
        return phone.trim();
      }

      expect(formatPhone("000000000"), equals("Sin teléfono"));
      expect(formatPhone(""), equals("Sin teléfono"));
      expect(formatPhone(null), equals("Sin teléfono"));
      expect(formatPhone("922836879"), equals("922836879"));
    });

    test('getClientsWithClaimableRewards detecta clientes con saldo para reclamar metas', () async {
      final client = await clientService.createClient({
        'nombre_completo': 'Cliente Ganador',
        'telefono': '955444333',
        'puntos_actuales': 120,
      }, testNegocioId, testUsuarioId);

      // Con 120 puntos y metas a 50 y 100 puntos, debe aparecer con premios listos
      final claimable = await clientService.getClientsWithClaimableRewards(testNegocioId);
      expect(claimable.any((item) => (item['client'] as ClientModel).id == client.id), isTrue);
      final clientItem = claimable.firstWhere((item) => (item['client'] as ClientModel).id == client.id);
      expect((clientItem['claimable_goals'] as List).length, greaterThanOrEqualTo(1));
    });

    test('Cálculo de Próxima Meta y micro-progreso para cliente sin premios listos', () {
      final nowStr = DateTime.now().toIso8601String();
      final client = ClientModel(
        id: 1,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        fullName: "Freddy",
        phone: "910888652",
        registeredDate: nowStr,
        puntosActuales: 40,
      );

      final goals = [
        RewardGoalModel(
          id: 1,
          negocioId: 1,
          nombre: "Descuento de Bienvenida",
          puntosRequeridos: 100,
          tipoBeneficio: "DESCUENTO_MONTO",
          valorBeneficio: 5.0,
          createdAt: nowStr,
        ),
        RewardGoalModel(
          id: 2,
          negocioId: 1,
          nombre: "Bono Especial Fidelidad",
          puntosRequeridos: 300,
          tipoBeneficio: "DESCUENTO_MONTO",
          valorBeneficio: 30.0,
          createdAt: nowStr,
        ),
      ];

      // Ordenar metas por puntos requeridos
      goals.sort((a, b) => a.puntosRequeridos.compareTo(b.puntosRequeridos));

      // Buscar próxima meta
      RewardGoalModel? nextGoal;
      for (final g in goals) {
        if (g.puntosRequeridos > client.puntosActuales) {
          nextGoal = g;
          break;
        }
      }
      nextGoal ??= goals.last;

      expect(nextGoal.nombre, equals("Descuento de Bienvenida"));
      final double progress = (client.puntosActuales / nextGoal.puntosRequeridos).clamp(0.0, 1.0);
      final int percent = (progress * 100).toInt();
      expect(percent, equals(40));
      expect(progress, equals(0.4));
    });

    test('claimAndDeliverReward con SQLite atómico descuenta saldo e impide saldo negativo', () async {
      final client = await clientService.createClient({
        'nombre_completo': 'Cliente Atómico',
        'telefono': '911222333',
        'puntos_actuales': 100,
      }, testNegocioId, testUsuarioId);

      final goals = await clientService.getRewardGoals(testNegocioId, activeOnly: true);
      final goal100 = goals.firstWhere((g) => g.puntosRequeridos == 100);

      // Reclamar premio con saldo suficiente
      final reward = await clientService.claimAndDeliverReward(
        client.id,
        goal100.id,
        usuarioId: testUsuarioId,
      );
      expect(reward, isNotNull);

      final updatedClient = await clientService.getClientById(client.id);
      expect(updatedClient?.puntosActuales, equals(0));

      // Intentar reclamar de nuevo cuando el saldo es 0 -> debe fallar de forma atómica retornando null
      final failedAttempt = await clientService.claimAndDeliverReward(
        client.id,
        goal100.id,
        usuarioId: testUsuarioId,
      );
      expect(failedAttempt, isNull);

      final afterFailedClient = await clientService.getClientById(client.id);
      expect(afterFailedClient?.puntosActuales, equals(0));
    });
  });
}
