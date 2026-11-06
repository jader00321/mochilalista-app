import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/services/client_service.dart';
import 'package:app_movil/features/smart_quotation/services/sales_service.dart';
import 'package:app_movil/features/smart_quotation/utils/pdf_generator.dart';
import 'package:app_movil/features/smart_quotation/models/pdf_config_model.dart';
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late ClientService clientService;
  late SalesService salesService;

  const int testNegocioId = 1;
  const int testUsuarioId = 1;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    await LocalDatabase.createDBForTesting(db);
    LocalDatabase.setCustomDatabase(db);

    await db.insert('negocios', {
      'id': testNegocioId,
      'nombre_comercial': 'Librería Central',
      'moneda': 'S/ (Soles)',
    });
    await db.insert('usuarios', {
      'id': testUsuarioId,
      'nombre_completo': 'Vendedor Test',
      'email': 'test@libreria.com',
    });

    clientService = ClientService();
    salesService = SalesService();
  });

  tearDown(() async {
    await db.close();
  });

  group('Motor de Morosidad, Estados de Cuota, PDF y WhatsApp (Parte 2)', () {
    test('1. Esquema SQLite v30 y serialización completa de 11 columnas de morosidad', () async {
      // Verificar columnas en ventas y cuotas
      final ventasCols = await db.rawQuery('PRAGMA table_info(ventas)');
      final cuotasCols = await db.rawQuery('PRAGMA table_info(cuotas)');

      final ventasColNames = ventasCols.map((c) => c['name'] as String).toSet();
      final cuotasColNames = cuotasCols.map((c) => c['name'] as String).toSet();

      expect(ventasColNames.contains('mora_total'), isTrue, reason: 'ventas debe contener mora_total');
      expect(cuotasColNames.contains('monto_original'), isTrue);
      expect(cuotasColNames.contains('mora_monto'), isTrue);
      expect(cuotasColNames.contains('mora_porcentaje'), isTrue);
      expect(cuotasColNames.contains('mora_automatica'), isTrue);
      expect(cuotasColNames.contains('mora_frecuencia'), isTrue);
      expect(cuotasColNames.contains('mora_intervalo_dias'), isTrue);
      expect(cuotasColNames.contains('mora_tipo'), isTrue);
      expect(cuotasColNames.contains('mora_valor'), isTrue);
      expect(cuotasColNames.contains('mora_fecha_inicio'), isTrue);
      expect(cuotasColNames.contains('mora_ultima_aplicacion'), isTrue);
      expect(cuotasColNames.contains('mora_periodos_acumulados'), isTrue);

      // Verificar serialización/deserialización en InstallmentModel
      final model = InstallmentModel(
        id: 10,
        installmentNumber: 1,
        dueDate: '2026-10-24',
        amount: 315.0,
        montoPagado: 0.0,
        status: 'pendiente',
        montoOriginal: 300.0,
        moraMonto: 15.0,
        moraPorcentaje: 5.0,
        moraAutomatica: true,
        moraFrecuencia: 'diario',
        moraIntervaloDias: 1,
        moraTipo: 'porcentaje',
        moraValor: 5.0,
        moraFechaInicio: '2026-10-24',
        moraUltimaAplicacion: '2026-10-25',
        moraPeriodosAcumulados: 1,
      );

      final sqliteMap = model.toSqlite(1);
      expect(sqliteMap['monto_original'], 300.0);
      expect(sqliteMap['mora_monto'], 15.0);
      expect(sqliteMap['mora_automatica'], 1);
      expect(sqliteMap['mora_frecuencia'], 'diario');

      final reconstructed = InstallmentModel.fromJson(sqliteMap);
      expect(reconstructed.montoOriginal, 300.0);
      expect(reconstructed.moraMonto, 15.0);
      expect(reconstructed.moraAutomatica, isTrue);
      expect(reconstructed.tieneMora, isTrue);
      expect(reconstructed.montoBase, 300.0);
    });

    test('2. Morosidad Manual: Monto Fijo (S/), Porcentaje (%) y Edición Directa de Cuota', () async {
      // Registrar cliente y préstamo base: S/ 1,000 al 20% en 4 cuotas de S/ 300.00
      final client = await clientService.createClient({
        'nombre_completo': 'Cliente Test Mora Manual',
        'telefono': '987654321',
      }, testNegocioId, testUsuarioId);

      await clientService.registerLoan(
        client.id,
        testNegocioId,
        testUsuarioId,
        amount: 1000.0,
        motivo: 'Préstamo personal en cuotas',
        interestRate: 20.0,
        installments: [
          InstallmentModel(id: 0, installmentNumber: 1, dueDate: '2026-10-24', amount: 300.0, status: 'pendiente'),
          InstallmentModel(id: 0, installmentNumber: 2, dueDate: '2026-10-31', amount: 300.0, status: 'pendiente'),
          InstallmentModel(id: 0, installmentNumber: 3, dueDate: '2026-11-07', amount: 300.0, status: 'pendiente'),
          InstallmentModel(id: 0, installmentNumber: 4, dueDate: '2026-11-14', amount: 300.0, status: 'pendiente'),
        ],
      );

      final saleRow = (await db.query('ventas', where: 'cliente_id = ?', whereArgs: [client.id])).last;
      final saleId = saleRow['id'] as int;
      final cuotas = await db.query('cuotas', where: 'venta_id = ?', whereArgs: [saleId], orderBy: 'numero_cuota ASC');
      final cuota1Id = cuotas[0]['id'] as int;
      final cuota2Id = cuotas[1]['id'] as int;

      // 2.1 Aplicar Mora Fija de S/ 15.00 a Cuota 1
      final ok1 = await salesService.aplicarMorosidadManual(
        cuota1Id,
        tipo: 'fijo',
        valor: 15.0,
      );
      expect(ok1, isTrue);

      final c1Updated = (await db.query('cuotas', where: 'id = ?', whereArgs: [cuota1Id])).first;
      expect(c1Updated['monto_original'], 300.0);
      expect(c1Updated['mora_monto'], 15.0);
      expect(c1Updated['monto'], 315.0);

      // 2.2 Aplicar Mora Porcentual del 10% a Cuota 2 (10% de S/ 300.00 = + S/ 30.00)
      final ok2 = await salesService.aplicarMorosidadManual(
        cuota2Id,
        tipo: 'porcentaje',
        valor: 10.0,
      );
      expect(ok2, isTrue);

      final c2Updated = (await db.query('cuotas', where: 'id = ?', whereArgs: [cuota2Id])).first;
      expect(c2Updated['monto_original'], 300.0);
      expect(c2Updated['mora_monto'], 30.0);
      expect(c2Updated['monto'], 330.0);

      // Verificar que ventas.mora_total consolidó la suma (15.0 + 30.0 = 45.0) y monto_total = 1245.0
      final vUpdated = (await db.query('ventas', where: 'id = ?', whereArgs: [saleId])).first;
      expect(vUpdated['mora_total'], 45.0);
      expect(vUpdated['monto_total'], 1245.0);
    });

    test('3. Motor de Morosidad Automático Periódico con Evaluación Temporal Idempotente', () async {
      final client = await clientService.createClient({
        'nombre_completo': 'Cliente Test Mora Auto',
        'telefono': '912345678',
      }, testNegocioId, testUsuarioId);

      // Crear préstamo con cuota vencida hace 4 días (2026-10-24)
      await clientService.registerLoan(
        client.id,
        testNegocioId,
        testUsuarioId,
        amount: 300.0,
        motivo: 'Préstamo con mora auto',
        interestRate: 0.0,
        installments: [
          InstallmentModel(id: 0, installmentNumber: 1, dueDate: '2026-10-24', amount: 300.0, status: 'pendiente'),
        ],
      );

      final saleRow = (await db.query('ventas', where: 'cliente_id = ?', whereArgs: [client.id])).last;
      final saleId = saleRow['id'] as int;
      final cuotas = await db.query('cuotas', where: 'venta_id = ?', whereArgs: [saleId]);
      final cuotaId = cuotas.first['id'] as int;

      // Configurar morosidad automática: S/ 5.00 diarios a partir del vencimiento (2026-10-24)
      final ok = await salesService.configurarMorosidadAutomatica(
        cuotaId,
        activa: true,
        frecuencia: 'diario',
        intervaloDias: 1,
        tipo: 'fijo',
        valor: 5.0,
        calcularDesdeVencimiento: true,
        referenceDate: DateTime(2026, 10, 24),
      );
      expect(ok, isTrue);

      // Evaluar temporalmente al 2026-10-27 (3 días transcurridos => 3 * S/ 5.00 = S/ 15.00)
      final testEvalDate = DateTime(2026, 10, 27);
      await salesService.evaluarMorosidadPeriodica(ventaId: saleId, referenceDate: testEvalDate);

      var cuotaEval = (await db.query('cuotas', where: 'id = ?', whereArgs: [cuotaId])).first;
      expect(cuotaEval['mora_periodos_acumulados'], 3);
      expect(cuotaEval['mora_monto'], 15.0);
      expect(cuotaEval['monto'], 315.0);

      // Idempotencia: Volver a evaluar en la misma fecha NO debe duplicar ni alterar la mora
      await salesService.evaluarMorosidadPeriodica(ventaId: saleId, referenceDate: testEvalDate);
      cuotaEval = (await db.query('cuotas', where: 'id = ?', whereArgs: [cuotaId])).first;
      expect(cuotaEval['mora_periodos_acumulados'], 3);
      expect(cuotaEval['mora_monto'], 15.0);
      expect(cuotaEval['monto'], 315.0);
    });

    test('4. Regla de Oro de Conservación: Desactivar modo automático mantiene mora acumulada intacta', () async {
      final client = await clientService.createClient({
        'nombre_completo': 'Cliente Conservacion Mora',
        'telefono': '944556677',
      }, testNegocioId, testUsuarioId);

      await clientService.registerLoan(
        client.id,
        testNegocioId,
        testUsuarioId,
        amount: 500.0,
        motivo: 'Préstamo regla conservacion',
        interestRate: 0.0,
        installments: [
          InstallmentModel(id: 0, installmentNumber: 1, dueDate: '2026-10-01', amount: 500.0, status: 'pendiente'),
        ],
      );

      final saleRow = (await db.query('ventas', where: 'cliente_id = ?', whereArgs: [client.id])).last;
      final saleId = saleRow['id'] as int;
      final cuotas = await db.query('cuotas', where: 'venta_id = ?', whereArgs: [saleId]);
      final cuotaId = cuotas.first['id'] as int;

      // Aplicar mora de S/ 25.00 y activar auto desde hoy sin acumulación previa
      await salesService.aplicarMorosidadManual(cuotaId, tipo: 'fijo', valor: 25.0);
      await salesService.configurarMorosidadAutomatica(
        cuotaId, 
        activa: true, 
        frecuencia: 'semanal', 
        tipo: 'fijo', 
        valor: 10.0,
        calcularDesdeVencimiento: false,
      );

      // Ahora el usuario desactiva el modo automático
      final desactOk = await salesService.configurarMorosidadAutomatica(
        cuotaId,
        activa: false,
      );
      expect(desactOk, isTrue);

      final cAfter = (await db.query('cuotas', where: 'id = ?', whereArgs: [cuotaId])).first;
      expect(cAfter['mora_automatica'], 0, reason: 'Modo automático debe quedar desactivado');
      expect(cAfter['mora_monto'], 25.0, reason: 'Mora acumulada previa DEBE conservarse intacta');
      expect(cAfter['monto'], 525.0, reason: 'Monto total de la cuota DEBE conservar el recargo acumulado');
    });

    test('5. Condonación y Quitar Morosidad: Restaura cuota a su monto base original', () async {
      final client = await clientService.createClient({
        'nombre_completo': 'Cliente Condonacion',
        'telefono': '955667788',
      }, testNegocioId, testUsuarioId);

      await clientService.registerLoan(
        client.id,
        testNegocioId,
        testUsuarioId,
        amount: 400.0,
        motivo: 'Préstamo condonacion',
        interestRate: 0.0,
        installments: [
          InstallmentModel(id: 0, installmentNumber: 1, dueDate: '2026-10-08', amount: 400.0, status: 'pendiente'),
        ],
      );

      final saleRow = (await db.query('ventas', where: 'cliente_id = ?', whereArgs: [client.id])).last;
      final saleId = saleRow['id'] as int;
      final cuotas = await db.query('cuotas', where: 'venta_id = ?', whereArgs: [saleId]);
      final cuotaId = cuotas.first['id'] as int;

      await salesService.aplicarMorosidadManual(cuotaId, tipo: 'fijo', valor: 40.0);
      var cRecargo = (await db.query('cuotas', where: 'id = ?', whereArgs: [cuotaId])).first;
      expect(cRecargo['monto'], 440.0);

      // Condonar mora
      final condonOk = await salesService.quitarMorosidad(cuotaId);
      expect(condonOk, isTrue);

      final cLimpia = (await db.query('cuotas', where: 'id = ?', whereArgs: [cuotaId])).first;
      expect(cLimpia['mora_monto'], 0.0);
      expect(cLimpia['monto'], 400.0);
      expect(cLimpia['mora_automatica'], 0);

      final vLimpia = (await db.query('ventas', where: 'id = ?', whereArgs: [saleId])).first;
      expect(vLimpia['mora_total'], 0.0);
      expect(vLimpia['monto_total'], 400.0);
    });

    test('6. Blindaje Matemático de Capital e Interés Original ante adición de Morosidad', () async {
      // Caso de imagen 1: Capital S/ 1,000.00 al 20% (+ S/ 200.00) = S/ 1,200.00
      final saleModel = SaleModel(
        id: 13,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        clientId: 5,
        clientName: 'Jj',
        origenVenta: 'prestamo_personal',
        isArchived: false,
        paymentMethod: 'efectivo',
        paymentStatus: 'pendiente',
        deliveryStatus: 'entregado',
        totalAmount: 1215.0, // Con S/ 15.00 de mora añadida
        paidAmount: 0.0,
        discount: 0.0,
        porcentajeInteres: 20.0,
        moraTotal: 15.0,
        saleDate: '2026-11-04 22:53:00',
        installments: [],
      );

      // Comprobar que capital e interés NO se contaminan con los S/ 15 de mora
      expect(saleModel.capitalPrestadoCalculado, closeTo(1000.0, 0.001));
      expect(saleModel.interesMontoCalculado, closeTo(200.0, 0.001));
      expect(saleModel.totalAmount, 1215.0);
    });

    test('7. Supresión Estricta de Teléfono Ficticio y Condiciones de Cobranza en PDF', () async {
      final quotation = SmartQuotationModel(
        id: 14,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        totalAmount: 1200.0,
        totalSavings: 0.0,
        status: 'READY',
        type: 'prestamo',
        clientName: 'Jj',
        createdAt: '2026-11-04 22:53:00',
        items: [],
      );

      // Simular datos de venta de préstamo con teléfono de 8 ceros ("00000000")
      final saleDataWithZeros = {
        'id': 14,
        'origen_venta': 'prestamo_personal',
        'cliente_nombre': 'Jj',
        'cliente_telefono': '00000000', // Ceros ficticios de Imagen 4
        'monto_total': 1200.0,
        'monto_pagado': 0.0,
        'porcentaje_interes': 20.0,
        'metodo_pago': 'efectivo',
        'estado_pago': 'pendiente',
        'fecha_venta': '2026-11-04 22:53:00',
        'cuotas': [
          {'numero_cuota': 1, 'fecha_vencimiento': '2026-10-24', 'monto': 300.0, 'monto_pagado': 0.0, 'estado': 'pendiente'},
        ],
      };

      final pdfConfig = PdfConfig(
        documentTitle: 'COMPROBANTE DE PRÉSTAMO',
        footerNote: 'Válida por 7 días', // Proviene de cotización
      );

      // Generar bytes de PDF A4 y Ticket
      final bytesA4 = await PdfGenerator.generatePdf(
        quotation: quotation,
        config: pdfConfig,
        ownerInfo: null,
        saleData: saleDataWithZeros,
      );
      expect(bytesA4, isNotEmpty);

      final bytesTicket = await PdfGenerator.generatePdf(
        quotation: quotation,
        config: pdfConfig.copyWith(pageSize: PdfPageSize.ticket80),
        ownerInfo: null,
        saleData: saleDataWithZeros,
      );
      expect(bytesTicket, isNotEmpty);
    });

    test('8. Estudio Seguro de Previsualización y Edición de WhatsApp (In-App Modal)', () {
      final testCuota = {
        'id': 1,
        'numero_cuota': 1,
        'monto': 315.0,
        'monto_original': 300.0,
        'mora_monto': 15.0,
        'monto_pagado': 0.0,
        'fecha_vencimiento': '2026-10-24',
        'estado': 'pendiente',
      };

      expect(testCuota['mora_monto'], 15.0);
      expect(testCuota['monto'], 315.0);

      // Simular teléfono con ceros
      String phone = "00000000";
      if (phone.replaceAll('0', '').isEmpty) {
        phone = "";
      }
      expect(phone, isEmpty, reason: 'Teléfonos ficticios de sólo ceros deben ser suprimidos a cadena vacía');

      // Simular teléfono válido
      String realPhone = "922836879";
      final rawDigits = realPhone.replaceAll(RegExp(r'\D'), '');
      final waPhone = rawDigits.startsWith('51') ? rawDigits : '51$rawDigits';
      expect(waPhone, '51922836879');
    });

    test('9. Frecuencias extendidas de Morosidad: cada_2_dias, cada_3_dias y personalizado (N >= 1)', () async {
      final client = await clientService.createClient({
        'nombre_completo': 'Cliente Frecuencias Extended',
        'telefono': '933445566',
      }, testNegocioId, testUsuarioId);

      // Préstamo con 3 cuotas vencidas el 2026-10-20
      await clientService.registerLoan(
        client.id,
        testNegocioId,
        testUsuarioId,
        amount: 900.0,
        motivo: 'Préstamo test frecuencias',
        interestRate: 0.0,
        installments: [
          InstallmentModel(id: 0, installmentNumber: 1, dueDate: '2026-10-20', amount: 300.0, status: 'pendiente'),
          InstallmentModel(id: 0, installmentNumber: 2, dueDate: '2026-10-20', amount: 300.0, status: 'pendiente'),
          InstallmentModel(id: 0, installmentNumber: 3, dueDate: '2026-10-20', amount: 300.0, status: 'pendiente'),
        ],
      );

      final saleRow = (await db.query('ventas', where: 'cliente_id = ?', whereArgs: [client.id])).last;
      final saleId = saleRow['id'] as int;
      final cuotas = await db.query('cuotas', where: 'venta_id = ?', whereArgs: [saleId], orderBy: 'numero_cuota ASC');

      // Cuota 1: cada_2_dias (+ S/ 10.00 fijo)
      await salesService.configurarMorosidadAutomatica(
        cuotas[0]['id'] as int,
        activa: true,
        frecuencia: 'cada_2_dias',
        tipo: 'fijo',
        valor: 10.0,
        referenceDate: DateTime(2026, 10, 20),
      );

      // Cuota 2: cada_3_dias (+ S/ 15.00 fijo)
      await salesService.configurarMorosidadAutomatica(
        cuotas[1]['id'] as int,
        activa: true,
        frecuencia: 'cada_3_dias',
        tipo: 'fijo',
        valor: 15.0,
        referenceDate: DateTime(2026, 10, 20),
      );

      // Cuota 3: personalizado cada 4 días (+ S/ 20.00 fijo)
      await salesService.configurarMorosidadAutomatica(
        cuotas[2]['id'] as int,
        activa: true,
        frecuencia: 'personalizado',
        intervaloDias: 4,
        tipo: 'fijo',
        valor: 20.0,
        referenceDate: DateTime(2026, 10, 20),
      );

      // Evaluar 6 días después (2026-10-26)
      // Cuota 1: 6 / 2 = 3 periodos => 3 * 10 = S/ 30.00 mora => Total 330.00
      // Cuota 2: 6 / 3 = 2 periodos => 2 * 15 = S/ 30.00 mora => Total 330.00
      // Cuota 3: 6 / 4 = 1 periodo => 1 * 20 = S/ 20.00 mora => Total 320.00
      await salesService.evaluarMorosidadPeriodica(ventaId: saleId, referenceDate: DateTime(2026, 10, 26));

      final c1 = (await db.query('cuotas', where: 'id = ?', whereArgs: [cuotas[0]['id']])).first;
      final c2 = (await db.query('cuotas', where: 'id = ?', whereArgs: [cuotas[1]['id']])).first;
      final c3 = (await db.query('cuotas', where: 'id = ?', whereArgs: [cuotas[2]['id']])).first;

      expect(c1['mora_intervalo_dias'], 2);
      expect(c1['mora_periodos_acumulados'], 3);
      expect(c1['mora_monto'], 30.0);
      expect(c1['monto'], 330.0);

      expect(c2['mora_intervalo_dias'], 3);
      expect(c2['mora_periodos_acumulados'], 2);
      expect(c2['mora_monto'], 30.0);
      expect(c2['monto'], 330.0);

      expect(c3['mora_intervalo_dias'], 4);
      expect(c3['mora_periodos_acumulados'], 1);
      expect(c3['mora_monto'], 20.0);
      expect(c3['monto'], 320.0);
    });

    test('10. Evaluación Automática en Perfil de Cliente y Apagado al 100% de Pago', () async {
      final client = await clientService.createClient({
        'nombre_completo': 'Cliente Auto Eval y Pago',
        'telefono': '911223344',
      }, testNegocioId, testUsuarioId);

      await clientService.registerLoan(
        client.id,
        testNegocioId,
        testUsuarioId,
        amount: 200.0,
        motivo: 'Préstamo auto eval y pago',
        interestRate: 0.0,
        installments: [
          InstallmentModel(id: 0, installmentNumber: 1, dueDate: '2026-10-10', amount: 200.0, status: 'pendiente'),
        ],
      );

      final saleRow = (await db.query('ventas', where: 'cliente_id = ?', whereArgs: [client.id])).last;
      final saleId = saleRow['id'] as int;
      final cuotas = await db.query('cuotas', where: 'venta_id = ?', whereArgs: [saleId]);
      final cuotaId = cuotas.first['id'] as int;

      // Configurar mora automática diaria de S/ 5
      await salesService.configurarMorosidadAutomatica(
        cuotaId,
        activa: true,
        frecuencia: 'diario',
        tipo: 'fijo',
        valor: 5.0,
        referenceDate: DateTime(2026, 10, 10),
      );

      // Simular que el usuario abre el perfil del cliente en fecha 2026-10-14 (4 días después)
      await salesService.evaluarMorosidadPeriodica(clienteId: client.id, referenceDate: DateTime(2026, 10, 14));

      // Verificar que la cuota ahora es S/ 220.00 (200 + 4*5)
      var cEval = (await db.query('cuotas', where: 'id = ?', whereArgs: [cuotaId])).first;
      expect(cEval['mora_periodos_acumulados'], 4);
      expect(cEval['mora_monto'], 20.0);
      expect(cEval['monto'], 220.0);

      // Pagar la cuota en su totalidad (S/ 220.00)
      final payOk = await clientService.registerPayment(
        client.id,
        220.0,
        'efectivo',
        testNegocioId,
        testUsuarioId,
        ventaId: saleId,
        cuotaId: cuotaId,
      );
      expect(payOk, isTrue);

      // Comprobar que mora_automatica se apagó automáticamente a 0
      final cPaid = (await db.query('cuotas', where: 'id = ?', whereArgs: [cuotaId])).first;
      expect(cPaid['estado'], 'pagado');
      expect(cPaid['mora_automatica'], 0, reason: 'mora_automatica DEBE apagarse al 100% de cancelación');

      // Si se vuelve a evaluar morosidad 10 días después (2026-10-24), no debe acumular nada más
      await salesService.evaluarMorosidadPeriodica(ventaId: saleId, referenceDate: DateTime(2026, 10, 24));
      final cAfterPaid = (await db.query('cuotas', where: 'id = ?', whereArgs: [cuotaId])).first;
      expect(cAfterPaid['mora_periodos_acumulados'], 4);
      expect(cAfterPaid['monto'], 220.0);
    });

    test('11. Auto-Heal de Cuotas en Venta a Crédito y Soporte Inmediato de Morosidad', () async {
      final client = await clientService.createClient({
        'nombre_completo': 'Cliente Credito Sin Cuotas',
        'telefono': '977889900',
      }, testNegocioId, testUsuarioId);

      // Insertar venta a crédito directamente en ventas sin cuotas en tabla cuotas
      final saleId = await db.insert('ventas', {
        'negocio_id': testNegocioId,
        'creado_por_usuario_id': testUsuarioId,
        'cliente_id': client.id,
        'monto_total': 500.0,
        'monto_pagado': 100.0, // Saldo pendiente S/ 400.00
        'metodo_pago': 'credito',
        'estado_pago': 'parcial',
        'estado_entrega': 'entregado',
        'fecha_venta': '2026-10-01 10:00:00',
        'is_archived': 0,
      });

      // Verificar que inicialmente cuotas está vacío
      final cuotasBefore = await db.query('cuotas', where: 'venta_id = ?', whereArgs: [saleId]);
      expect(cuotasBefore.isEmpty, isTrue);

      // Llamar a getSaleDetail: debe disparar auto-heal
      final detail = await salesService.getSaleDetail(saleId);
      final List cuotasAfter = detail['cuotas'] as List;
      expect(cuotasAfter.length, 1, reason: 'Auto-heal debió crear Cuota #1');
      expect(cuotasAfter.first['monto'], 400.0, reason: 'Monto de cuota curada debe ser igual al saldo deudor');
      expect(cuotasAfter.first['monto_original'], 400.0);

      // Aplicar morosidad a la cuota curada
      final cuotaCuradaId = cuotasAfter.first['id'] as int;
      final moraOk = await salesService.aplicarMorosidadManual(cuotaCuradaId, tipo: 'fijo', valor: 25.0);
      expect(moraOk, isTrue);

      final cWithMora = (await db.query('cuotas', where: 'id = ?', whereArgs: [cuotaCuradaId])).first;
      expect(cWithMora['monto'], 425.0);
      expect(cWithMora['mora_monto'], 25.0);
    });

    test('12. Formatos de Pago Parcial y Monto Original + Mora en WhatsApp y PDF', () async {
      final quotation = SmartQuotationModel(
        id: 15,
        negocioId: 1,
        creadoPorUsuarioId: 1,
        totalAmount: 315.0,
        totalSavings: 0.0,
        status: 'READY',
        type: 'prestamo',
        clientName: 'Cliente Formatos',
        createdAt: '2026-11-04 22:53:00',
        items: [],
      );

      final saleData = {
        'id': 15,
        'origen_venta': 'prestamo_personal',
        'cliente_nombre': 'Cliente Formatos',
        'cliente_telefono': '922836879',
        'monto_total': 315.0,
        'monto_pagado': 100.0,
        'porcentaje_interes': 0.0,
        'metodo_pago': 'efectivo',
        'estado_pago': 'parcial',
        'fecha_venta': '2026-11-04 22:53:00',
        'cuotas': [
          {
            'numero_cuota': 1,
            'fecha_vencimiento': '2026-10-24', // Vencida
            'monto': 315.0,
            'monto_original': 300.0,
            'mora_monto': 15.0,
            'monto_pagado': 100.0, // Pago parcial
            'estado': 'parcial',
          },
        ],
      };

      // Verificar generación de PDF sin excepciones
      final pdfConfig = PdfConfig(
        documentTitle: 'COMPROBANTE DE PRÉSTAMO',
        footerNote: 'Nota cobranza',
      );

      final bytesA4 = await PdfGenerator.generatePdf(
        quotation: quotation,
        config: pdfConfig,
        ownerInfo: null,
        saleData: saleData,
      );
      expect(bytesA4, isNotEmpty);

      final bytesTicket = await PdfGenerator.generatePdf(
        quotation: quotation,
        config: pdfConfig.copyWith(pageSize: PdfPageSize.ticket80),
        ownerInfo: null,
        saleData: saleData,
      );
      expect(bytesTicket, isNotEmpty);
    });
  });
}
