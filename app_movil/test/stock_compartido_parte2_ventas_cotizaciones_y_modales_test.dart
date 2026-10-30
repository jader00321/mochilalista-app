import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/features/smart_quotation/services/sales_service.dart';
import 'package:app_movil/features/smart_quotation/services/quotation_service.dart';
import 'package:app_movil/features/smart_quotation/models/matching_model.dart';
import 'package:app_movil/features/smart_quotation/models/extracted_list_model.dart';
import 'package:app_movil/features/smart_quotation/widgets/manual/manual_quote_item_card.dart';
import 'package:app_movil/features/smart_quotation/widgets/matching/matching_item_row.dart';
import 'package:app_movil/features/smart_quotation/providers/matching_provider.dart';
import 'package:app_movil/core/widgets/product_detail_modal.dart';
import 'package:app_movil/core/widgets/stock_update_modal.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';

class _TestInventoryProvider extends InventoryProvider {
  final List<InventoryWrapper> _testItems;
  int? updatedPresentationId;
  int? updatedQuota;
  bool? clearCupoCalled;
  int? updatedStock;

  _TestInventoryProvider(this._testItems);

  @override
  List<InventoryWrapper> get items => _testItems;

  @override
  Future<bool> updateVariantQuota(int presentationId, int? newQuota) async {
    updatedPresentationId = presentationId;
    updatedQuota = newQuota;
    clearCupoCalled = newQuota == null;
    return true;
  }

  @override
  Future<bool> updatePresentation(
    int presentationId, {
    String? umpCompra,
    double? precioUmpProveedor,
    double? cantidadUmpComprada,
    double? totalPagoLote,
    int? unidadesPorLote,
    String? unidadVenta,
    int? unidadesPorVenta,
    double? costoUnitarioCalculado,
    double? factorGananciaVenta,
    double? precioVentaFinal,
    double? oferta,
    String? tipoDesc,
    double? valorDesc,
    int? stock,
    int? cupoMaximoVariante,
    bool clearCupo = false,
    String? estado,
    String? imagenUrl,
  }) async {
    updatedPresentationId = presentationId;
    updatedStock = stock;
    updatedQuota = cupoMaximoVariante;
    clearCupoCalled = clearCupo;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('AUDITORÍA ADVERSARIAL PARTE 2: MOTOR DE VENTAS, COTIZACIONES Y MODALES', () {
    late Database db;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      LocalDatabase.setCustomDatabase(db);

      await db.execute('''
        CREATE TABLE productos (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nombre TEXT,
          modo_stock TEXT,
          stock_compartido INTEGER DEFAULT 0,
          costo_base REAL DEFAULT 0,
          precio_base REAL DEFAULT 0,
          categoria_id INTEGER,
          marca_id INTEGER,
          unidad_medida TEXT,
          estado TEXT DEFAULT 'activo'
        )
      ''');

      await db.execute('''
        CREATE TABLE presentaciones_producto (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          producto_id INTEGER,
          nombre_especifico TEXT,
          unidad_venta TEXT,
          unidades_por_venta INTEGER DEFAULT 1,
          stock_actual INTEGER DEFAULT 0,
          stock_alerta INTEGER DEFAULT 0,
          usa_stock_compartido INTEGER DEFAULT 1,
          precio_venta_final REAL DEFAULT 0,
          costo_unitario_calculado REAL DEFAULT 0,
          cupo_maximo_variante INTEGER,
          es_default INTEGER DEFAULT 0,
          activo INTEGER DEFAULT 1
        )
      ''');

      await db.execute('''
        CREATE TABLE usuarios (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nombre TEXT,
          email TEXT,
          rol TEXT,
          negocio_id INTEGER DEFAULT 1,
          activo INTEGER DEFAULT 1
        )
      ''');

      await db.execute('''
        CREATE TABLE ventas (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          numero_secuencial INTEGER,
          negocio_id INTEGER,
          creado_por_usuario_id INTEGER,
          cotizacion_id INTEGER,
          cliente_id INTEGER,
          origen_venta TEXT DEFAULT 'directa',
          metodo_pago TEXT DEFAULT 'EFECTIVO',
          estado_pago TEXT DEFAULT 'PAGADO',
          estado_entrega TEXT DEFAULT 'ENTREGADO',
          monto_total REAL,
          monto_pagado REAL,
          descuento_aplicado REAL DEFAULT 0,
          abono_inicial REAL DEFAULT 0,
          porcentaje_interes REAL DEFAULT 0,
          is_archived INTEGER DEFAULT 0,
          motivo_anulacion TEXT,
          fecha_venta TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE venta_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          venta_id INTEGER,
          presentation_id INTEGER,
          product_id INTEGER,
          bundle_id INTEGER,
          bundle_snapshot TEXT,
          cantidad INTEGER DEFAULT 1,
          precio_unitario REAL,
          original_unit_price REAL,
          subtotal REAL,
          nombre_producto TEXT,
          brand_name TEXT,
          specific_name TEXT,
          unidad_medida TEXT,
          original_text TEXT,
          image_url TEXT,
          is_manual_price INTEGER DEFAULT 0
        )
      ''');

      await db.execute('''
        CREATE TABLE stock_ledger (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          presentation_id INTEGER,
          negocio_id INTEGER,
          tipo_transaccion TEXT,
          cantidad INTEGER,
          costo_unitario REAL,
          precio_venta REAL,
          origen_id INTEGER,
          fecha_registro TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE cuotas (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          venta_id INTEGER,
          numero_cuota INTEGER,
          monto REAL,
          monto_pagado REAL DEFAULT 0.00,
          fecha_vencimiento TEXT,
          estado TEXT DEFAULT 'pendiente'
        )
      ''');

      await db.execute('''
        CREATE TABLE pagos (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          negocio_id INTEGER,
          creado_por_usuario_id INTEGER,
          cliente_id INTEGER,
          venta_id INTEGER,
          cuota_id INTEGER,
          monto REAL,
          metodo_pago TEXT,
          nota TEXT,
          fecha_pago TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE notificaciones (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER,
          negocio_id INTEGER,
          titulo TEXT,
          mensaje TEXT,
          tipo TEXT,
          prioridad TEXT,
          leida INTEGER DEFAULT 0,
          objeto_relacionado_tipo TEXT,
          objeto_relacionado_id INTEGER,
          fecha_creacion TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE smart_quotations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          numero_secuencial INTEGER,
          negocio_id INTEGER,
          creado_por_usuario_id INTEGER,
          client_id INTEGER,
          client_name TEXT,
          total_amount REAL,
          status TEXT DEFAULT 'DRAFT',
          is_template INTEGER DEFAULT 0,
          created_at TEXT,
          updated_at TEXT
        )
      ''');

      await db.execute('''
        CREATE TABLE smart_quotation_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          quotation_id INTEGER,
          product_id INTEGER,
          presentation_id INTEGER,
          bundle_id INTEGER,
          product_name TEXT,
          specific_name TEXT,
          quantity INTEGER,
          unit_price_applied REAL,
          original_unit_price REAL,
          is_manual_price INTEGER DEFAULT 0
        )
      ''');

      await db.execute('''
        CREATE TABLE paquetes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nombre_paquete TEXT,
          tipo_promocion TEXT DEFAULT 'paquete',
          precio_venta_total REAL,
          activo INTEGER DEFAULT 1
        )
      ''');

      await db.execute('''
        CREATE TABLE items_paquete (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          paquete_id INTEGER,
          presentacion_id INTEGER,
          cantidad_requerida INTEGER DEFAULT 1
        )
      ''');
    });

    tearDown(() async {
      LocalDatabase.setCustomDatabase(null);
      await db.close();
    });

    // -------------------------------------------------------------------------
    // TEST 1: CASO EXACTO AUDITORÍA MOTOR DE VENTAS (48 base -> Par x2 & ½ Docena x6)
    // -------------------------------------------------------------------------
    test(
      '1. Auditoría Motor de Ventas: 48 base -> Vende 1 Par (baja a 46, Par 23, ½ Docena 7) y Anula (restaura 48, 24, 8)',
      () async {
        final salesService = SalesService();

        // 1. Insertar producto con 48 unidades base
        final prodId = await db.insert('productos', {
          'nombre': 'Calcetines Escolares',
          'modo_stock': 'COMPARTIDO',
          'stock_compartido': 48,
          'costo_base': 2.0,
        });

        // Variante 1: Par x2 (factor 2 -> físico 24)
        final vParId = await db.insert('presentaciones_producto', {
          'producto_id': prodId,
          'nombre_especifico': 'Par',
          'unidad_venta': 'Par',
          'unidades_por_venta': 2,
          'stock_actual': 48,
          'usa_stock_compartido': 1,
          'precio_venta_final': 5.0,
          'costo_unitario_calculado': 4.0,
        });

        // Variante 2: ½ Docena x6 (factor 6 -> físico 8)
        final vMediaDocenaId = await db.insert('presentaciones_producto', {
          'producto_id': prodId,
          'nombre_especifico': '½ Docena',
          'unidad_venta': 'Media Docena',
          'unidades_por_venta': 6,
          'stock_actual': 48,
          'usa_stock_compartido': 1,
          'precio_venta_final': 14.0,
          'costo_unitario_calculado': 12.0,
        });

        // Verificar estado inicial en SQLite
        final pInit = await db.query(
          'productos',
          where: 'id = ?',
          whereArgs: [prodId],
        );
        expect(pInit.first['stock_compartido'], equals(48));

        final presParInit = await db.query(
          'presentaciones_producto',
          where: 'id = ?',
          whereArgs: [vParId],
        );
        expect(presParInit.first['stock_actual'], equals(48));
        final parModelInit = ProductPresentation.fromJson(presParInit.first);
        expect(parModelInit.unidadesVendiblesDisponibles, equals(24));

        final presDocInit = await db.query(
          'presentaciones_producto',
          where: 'id = ?',
          whereArgs: [vMediaDocenaId],
        );
        expect(presDocInit.first['stock_actual'], equals(48));
        final docModelInit = ProductPresentation.fromJson(presDocInit.first);
        expect(docModelInit.unidadesVendiblesDisponibles, equals(8));

        // 2. Vender 1 Par x2 a través de SalesService
        final saleModel = await salesService.createSale(
          {
            'metodo_pago': 'EFECTIVO',
            'estado_pago': 'PAGADO',
            'estado_entrega': 'ENTREGADO',
            'monto_total': 5.0,
            'monto_pagado': 5.0,
            'items': [
              {
                'product_id': prodId,
                'presentation_id': vParId,
                'quantity': 1,
                'unit_price': 5.0,
                'cost': 4.0,
                'subtotal': 5.0,
              },
            ],
          },
          1,
          1,
        );

        expect(saleModel.id, isPositive);

        // 3. Verificar estado post-venta en SQLite
        final pPostSale = await db.query(
          'productos',
          where: 'id = ?',
          whereArgs: [prodId],
        );
        expect(
          pPostSale.first['stock_compartido'],
          equals(46),
          reason: 'Pool base debe descontar 2 unidades base',
        );

        final presParPost = await db.query(
          'presentaciones_producto',
          where: 'id = ?',
          whereArgs: [vParId],
        );
        expect(presParPost.first['stock_actual'], equals(46));
        final parModelPost = ProductPresentation.fromJson(presParPost.first);
        expect(
          parModelPost.unidadesVendiblesDisponibles,
          equals(23),
          reason: 'Par x2 debe pasar a 23',
        );

        final presDocPost = await db.query(
          'presentaciones_producto',
          where: 'id = ?',
          whereArgs: [vMediaDocenaId],
        );
        expect(
          presDocPost.first['stock_actual'],
          equals(46),
          reason: 'Variante hermana compartida debe sincronizarse',
        );
        final docModelPost = ProductPresentation.fromJson(presDocPost.first);
        expect(
          docModelPost.unidadesVendiblesDisponibles,
          equals(7),
          reason: '½ Docena x6 debe pasar automáticamente a 7 (46 ~/ 6)',
        );

        // 4. Anular la venta (voidSale)
        await salesService.voidSale(saleModel.id, 1, 'Prueba adversarial');

        // 5. Verificar restauración exacta post-anulación
        final pPostVoid = await db.query(
          'productos',
          where: 'id = ?',
          whereArgs: [prodId],
        );
        expect(
          pPostVoid.first['stock_compartido'],
          equals(48),
          reason: 'Pool base restaurado a 48',
        );

        final presParVoid = await db.query(
          'presentaciones_producto',
          where: 'id = ?',
          whereArgs: [vParId],
        );
        expect(presParVoid.first['stock_actual'], equals(48));
        final parModelVoid = ProductPresentation.fromJson(presParVoid.first);
        expect(parModelVoid.unidadesVendiblesDisponibles, equals(24));

        final presDocVoid = await db.query(
          'presentaciones_producto',
          where: 'id = ?',
          whereArgs: [vMediaDocenaId],
        );
        expect(presDocVoid.first['stock_actual'], equals(48));
        final docModelVoid = ProductPresentation.fromJson(presDocVoid.first);
        expect(docModelVoid.unidadesVendiblesDisponibles, equals(8));
      },
    );

    // -------------------------------------------------------------------------
    // TEST 2: SINCRONIZACIÓN Y ACOTMIENTO DE CUPO MANUAL AL VENDER Y ANULAR
    // -------------------------------------------------------------------------
    test(
      '2. Sincronización y acotamiento de cupo_maximo_variante al vender y anular',
      () async {
        final salesService = SalesService();

        // Pool de 60 unidades base
        final prodId = await db.insert('productos', {
          'nombre': 'Cuadernos',
          'modo_stock': 'COMPARTIDO',
          'stock_compartido': 60,
        });

        // Variante A: Paquete x10 (factor 10 -> físico 6). Tiene cupo manual = 4.
        final vPaq10 = await db.insert('presentaciones_producto', {
          'producto_id': prodId,
          'nombre_especifico': 'Paquete x10',
          'unidad_venta': 'Paquete',
          'unidades_por_venta': 10,
          'stock_actual': 60,
          'usa_stock_compartido': 1,
          'precio_venta_final': 20.0,
          'cupo_maximo_variante': 4,
        });

        // Variante B: Paquete x5 (factor 5 -> físico 12). Tiene cupo manual = 11.
        final vPaq5 = await db.insert('presentaciones_producto', {
          'producto_id': prodId,
          'nombre_especifico': 'Paquete x5',
          'unidad_venta': 'Paquete x5',
          'unidades_por_venta': 5,
          'stock_actual': 60,
          'usa_stock_compartido': 1,
          'precio_venta_final': 10.0,
          'cupo_maximo_variante': 11,
        });

        // Vender 2 de Variante A (consume 2 * 10 = 20 base).
        // Pool pasa de 60 a 40.
        // Variante A tenía cupo 4 -> baja a 4 - 2 = 2.
        // Variante B hermana tenía cupo 11 -> pero nuevo físico es 40 ~/ 5 = 8.
        // Su cupo de 11 excede 8, por tanto se debe acotar automáticamente a 8!
        final saleModel = await salesService.createSale(
          {
            'metodo_pago': 'EFECTIVO',
            'estado_pago': 'PAGADO',
            'estado_entrega': 'ENTREGADO',
            'monto_total': 40.0,
            'monto_pagado': 40.0,
            'items': [
              {
                'product_id': prodId,
                'presentation_id': vPaq10,
                'quantity': 2,
                'unit_price': 20.0,
                'cost': 15.0,
                'subtotal': 40.0,
              },
            ],
          },
          1,
          1,
        );

        expect(saleModel.id, isPositive);

        final presAPost = await db.query(
          'presentaciones_producto',
          where: 'id = ?',
          whereArgs: [vPaq10],
        );
        expect(
          presAPost.first['cupo_maximo_variante'],
          equals(2),
          reason: 'Cupo de variante vendida baja de 4 a 2',
        );
        expect(
          ProductPresentation.fromJson(
            presAPost.first,
          ).unidadesVendiblesDisponibles,
          equals(2),
        );

        final presBPost = await db.query(
          'presentaciones_producto',
          where: 'id = ?',
          whereArgs: [vPaq5],
        );
        expect(
          presBPost.first['cupo_maximo_variante'],
          equals(8),
          reason:
              'Cupo de variante hermana se acota al nuevo techo físico (40 ~/ 5 = 8)',
        );
        expect(
          ProductPresentation.fromJson(
            presBPost.first,
          ).unidadesVendiblesDisponibles,
          equals(8),
        );

        // Anulación: devuelve 20 base al pool (vuelve a 60).
        // Cupo de Variante A pasa de 2 a 2 + 2 = 4 (acotado al techo físico 6 -> 4).
        await salesService.voidSale(saleModel.id, 1, 'Anulación cupo');
        final presAVoid = await db.query(
          'presentaciones_producto',
          where: 'id = ?',
          whereArgs: [vPaq10],
        );
        expect(presAVoid.first['cupo_maximo_variante'], equals(4));
      },
    );

    // -------------------------------------------------------------------------
    // TEST 3: COTIZACIONES - SIMULACIÓN LIBRE Y BLOQUEO PRE-VENTA (QuotationService)
    // -------------------------------------------------------------------------
    test(
      '3. Cotizaciones: Simulación libre y bloqueo en QuotationService.validateIntegrity cuando no alcanza el stock compartido',
      () async {
        final quotationService = QuotationService();

        // Producto con 30 unidades base
        final prodId = await db.insert('productos', {
          'nombre': 'Plumones',
          'modo_stock': 'COMPARTIDO',
          'stock_compartido': 30,
        });

        final vEstuche = await db.insert('presentaciones_producto', {
          'producto_id': prodId,
          'nombre_especifico': 'Estuche x10',
          'unidad_venta': 'Estuche',
          'unidades_por_venta': 10,
          'stock_actual': 30,
          'usa_stock_compartido': 1,
          'precio_venta_final': 15.0,
          'cupo_maximo_variante': 2, // Cupo acotado a 2 estuches (20 base)
        });

        // Crear cotización donde se simula cotizar 3 estuches (excede el cupo de 2 y demanda 30 base)
        final quoteId = await db.insert('smart_quotations', {
          'client_name': 'Cliente Escuela',
          'total_amount': 45.0,
          'status': 'DRAFT',
        });

        await db.insert('smart_quotation_items', {
          'quotation_id': quoteId,
          'product_id': prodId,
          'presentation_id': vEstuche,
          'product_name': 'Plumones Estuche x10',
          'quantity': 3,
          'unit_price_applied': 15.0,
          'original_unit_price': 15.0,
        });

        // Validar integridad antes de venta
        final integrity = await quotationService.validateIntegrity(quoteId);
        expect(
          integrity.canSell,
          isFalse,
          reason: 'Debe invalidar la conversión a venta',
        );
        expect(integrity.hasIssues, isTrue);
        expect(integrity.stockWarnings.isNotEmpty, isTrue);

        final warning = integrity.stockWarnings.first;
        expect(warning.requested, equals(3));
        expect(
          warning.available,
          equals(2),
          reason:
              'Stock disponible reportado debe respetar el cupo de 2 estuches',
        );
      },
    );

    // -------------------------------------------------------------------------
    // TEST 4: CARRITO RÁPIDO CON CUPO MANUAL (QuickSaleProvider)
    // -------------------------------------------------------------------------
    test(
      '4. QuickSaleProvider: getRemainingVendibleStock y addToCart respetan cupo_maximo_variante',
      () {
        final quickSale = QuickSaleProvider();

        final prod = Product(
          id: 501,
          categoriaId: 1,
          nombre: 'Cinta Embalaje',
          modoStock: 'COMPARTIDO',
          stockCompartido: 50,
        );

        final presConCupo = ProductPresentation(
          id: 88,
          nombreEspecifico: 'Rollo',
          unidadVenta: 'Rollo',
          unidadesPorVenta: 1,
          stockActual: 50,
          usaStockCompartido: true,
          cupoMaximoVariante: 5, // Solo 5 autorizados
          precioVentaFinal: 3.0,
        );

        final wrapper = InventoryWrapper(
          product: prod,
          presentation: presConCupo,
        );

        // El stock vendible restante debe ser 5
        expect(quickSale.getRemainingVendibleStock(wrapper), equals(5));

        // Agregar al carrito y subir cantidad a 5
        final err1 = quickSale.addToCart(wrapper);
        expect(err1, isNull);
        final errQty5 = quickSale.updateQuantity(presConCupo.id!, 5, 50);
        expect(errQty5, isNull);
        expect(quickSale.getQuantity(presConCupo.id!), equals(5));

        // Intentar subir a 6 debe bloquearse
        final errQty6 = quickSale.updateQuantity(presConCupo.id!, 6, 50);
        expect(errQty6, isNotNull);
        expect(errQty6, contains('cupo'));
      },
    );

    // -------------------------------------------------------------------------
    // TEST 5: StockUpdateModal (Modo Compartido): Bloqueo en máx físico y Banner temporal 4s
    // -------------------------------------------------------------------------
    testWidgets(
      '5. StockUpdateModal (Modo Compartido): Bloqueo estricto en maxPhysicalUnits y banner temporal de 4s',
      (WidgetTester tester) async {
        final prod = Product(
          id: 101,
          categoriaId: 1,
          nombre: 'Calcetines Escolares',
          modoStock: 'COMPARTIDO',
          stockCompartido: 48,
          presentaciones: [],
        );

        // Par x2 -> maxPhysical = 48 ~/ 2 = 24. Cupo inicial = 20.
        final presPar = ProductPresentation(
          id: 201,
          nombreEspecifico: 'Par',
          unidadVenta: 'Par',
          unidadesPorVenta: 2,
          stockActual: 48,
          usaStockCompartido: true,
          precioVentaFinal: 5.0,
          cupoMaximoVariante: 20,
        );

        final wrapper = InventoryWrapper(product: prod, presentation: presPar);
        final testProv = _TestInventoryProvider([wrapper]);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StockUpdateModal(
                presentation: presPar,
                provider: testProv,
                isDark: false,
              ),
            ),
          ),
        );

        // 1. Verificar estado inicial: campo de texto muestra "20"
        expect(find.text('20'), findsOneWidget);
        // Pestañas normales ("Sumar Compra" / "Fijar Stock Total") deben estar ocultas
        expect(find.text('Sumar Compra'), findsNothing);
        expect(find.text('Fijar Stock Total'), findsNothing);
        // Botón "Restaurar al máximo (24)" debe estar presente
        expect(find.textContaining('Restaurar al máximo (24)'), findsOneWidget);

        // 2. Tocar chip rápido "+50" para intentar superar el máximo (20 + 50 = 70 > 24)
        await tester.tap(find.text('+50'));
        await tester.pump();

        // El valor debe bloquearse estrictamente en 24
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller?.text, equals('24'));

        // El banner temporal de advertencia debe aparecer
        expect(
          find.textContaining(
            'No puedes aumentar más del máximo permitido (24',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'El cambio de la cantidad de unidades base solo se puede realizar en la ventana de Editar Producto.',
          ),
          findsOneWidget,
        );

        // 3. Avanzar el tiempo 4 segundos: el banner debe desaparecer automáticamente
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();

        // Verificar que el banner ya no está activo
        final warningFinder = find.textContaining(
          'No puedes aumentar más del máximo permitido',
        );
        expect(warningFinder.hitTestable(), findsNothing);

        // 4. Intentar aumentar usando chip '+10' estando ya en el tope de 24
        await tester.tap(find.text('+10'));
        await tester.pump();
        expect(textField.controller?.text, equals('24'));
        expect(
          find.textContaining(
            'No puedes aumentar más del máximo permitido (24',
          ),
          findsOneWidget,
        );

        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();
        expect(
          find
              .textContaining('No puedes aumentar más del máximo permitido')
              .hitTestable(),
          findsNothing,
        );

        // 5. Intentar aumentar usando el botón '+'
        await tester.tap(find.byIcon(Icons.add));
        await tester.pump();
        expect(textField.controller?.text, equals('24'));
        expect(
          find.textContaining(
            'No puedes aumentar más del máximo permitido (24',
          ),
          findsOneWidget,
        );

        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();

        // 6. Escribir un número mayor a 24 en el campo de texto (por ejemplo '99')
        await tester.enterText(find.byType(TextField), '99');
        await tester.pump();
        expect(textField.controller?.text, equals('24'));
        expect(
          find.textContaining(
            'No puedes aumentar más del máximo permitido (24',
          ),
          findsOneWidget,
        );

        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();

        // 7. Reducir con chip '-5' (24 - 5 = 19) y restaurar con el botón rápido
        await tester.tap(find.text('-5'));
        await tester.pump();
        expect(textField.controller?.text, equals('19'));

        await tester.tap(find.textContaining('Restaurar al máximo (24)'));
        await tester.pump();
        expect(textField.controller?.text, equals('24'));
      },
    );

    // -------------------------------------------------------------------------
    // TEST 6: StockUpdateModal: Guardar variante compartida actualiza solo cupo_maximo_variante
    // -------------------------------------------------------------------------
    testWidgets(
      '6. StockUpdateModal: Guardar variante compartida actualiza solo cupo y JAMÁS altera unidades base; Stock Propio mantiene pestañas normales',
      (WidgetTester tester) async {
        final prod = Product(
          id: 101,
          categoriaId: 1,
          nombre: 'Calcetines Escolares',
          modoStock: 'COMPARTIDO',
          stockCompartido: 48,
          presentaciones: [],
        );

        // Par x2 -> maxPhysical = 24. Cupo inicial = 20.
        final presPar = ProductPresentation(
          id: 201,
          nombreEspecifico: 'Par',
          unidadVenta: 'Par',
          unidadesPorVenta: 2,
          stockActual: 48,
          usaStockCompartido: true,
          precioVentaFinal: 5.0,
          cupoMaximoVariante: 20,
        );

        final wrapper = InventoryWrapper(product: prod, presentation: presPar);
        final testProv = _TestInventoryProvider([wrapper]);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StockUpdateModal(
                presentation: presPar,
                provider: testProv,
                isDark: false,
              ),
            ),
          ),
        );

        // Bajar cupo tocando chip "-5" (de 20 a 15)
        await tester.tap(find.text('-5'));
        await tester.pump();

        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.controller?.text, equals('15'));

        // Tocar "APLICAR CAMBIOS"
        await tester.tap(find.text('APLICAR CAMBIOS'));
        await tester.pumpAndSettle();

        // Certificar que se invocó la actualización con presentationId = 201 y cupo = 15
        expect(testProv.updatedPresentationId, equals(201));
        expect(testProv.updatedQuota, equals(15));
        // Certificar que NO se modificó stock ni unidades base
        expect(
          testProv.updatedStock,
          isNull,
          reason: 'JAMÁS debe pasarse parámetro stock para variante compartida',
        );
        expect(
          prod.stockCompartido,
          equals(48),
          reason: 'Pool base debe mantenerse intacto en 48',
        );

        // Parte B: Verificar que para variante de STOCK PROPIO (usaStockCompartido == false), se mantienen intactos los modos normales
        final presPropio = ProductPresentation(
          id: 301,
          nombreEspecifico: 'Docena Propia',
          unidadVenta: 'Docena',
          unidadesPorVenta: 12,
          stockActual: 10,
          usaStockCompartido: false,
          precioVentaFinal: 25.0,
        );
        final wrapperPropio = InventoryWrapper(
          product: prod,
          presentation: presPropio,
        );
        final testProvPropio = _TestInventoryProvider([wrapperPropio]);

        await tester.pumpWidget(
          MaterialApp(
            key: const ValueKey('modal_stock_propio_app'),
            home: Scaffold(
              body: StockUpdateModal(
                presentation: presPropio,
                provider: testProvPropio,
                isDark: false,
              ),
            ),
          ),
        );

        // Para stock propio sí deben existir las pestañas normales
        expect(find.text('Sumar Compra'), findsOneWidget);
        expect(find.text('Fijar Stock Total'), findsOneWidget);
      },
    );

    // -------------------------------------------------------------------------
    // TEST 7: Modales de Detalle: Selector de variantes colapsado por defecto y chips en 2 filas
    // -------------------------------------------------------------------------
    testWidgets(
      '7. Modales de Detalle: Selector de variantes colapsado por defecto, despliegue con "Ver otras" y chips en 2 filas centradas',
      (WidgetTester tester) async {
        final prod = Product(
          id: 801,
          categoriaId: 1,
          nombre: 'Cuaderno Cuadriculado',
          modoStock: 'MIXTO',
          stockCompartido: 60,
          presentaciones: [
            ProductPresentation(
              id: 881,
              nombreEspecifico: 'Principal',
              unidadVenta: 'Unidad',
              unidadesPorVenta: 1,
              stockActual: 60,
              usaStockCompartido: true,
              precioVentaFinal: 4.50,
            ),
            ProductPresentation(
              id: 882,
              nombreEspecifico: 'Caja x10',
              unidadVenta: 'Caja',
              unidadesPorVenta: 10,
              stockActual: 60,
              usaStockCompartido: true,
              precioVentaFinal: 40.00,
            ),
          ],
        );

        final wrapper = InventoryWrapper(
          product: prod,
          presentation: prod.presentaciones.first,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    ProductDetailModal.show(
                      context,
                      item: wrapper,
                      onAddToCart: (int q, [ProductPresentation? p]) {},
                      onAddToList: (int q, [ProductPresentation? p]) {},
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

        // 1. Verificar que la sección del selector de variantes está colapsada por defecto
        expect(
          find.text('Seleccionar Variante / Presentación'),
          findsOneWidget,
        );
        expect(find.text('Ver otras'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        expect(find.text('Ocultar'), findsNothing);

        // 2. Tocar "Ver otras" para desplegar la sección
        await tester.tap(find.text('Ver otras'));
        await tester.pumpAndSettle();

        // Ahora el botón pasa a ser "Ocultar"
        expect(find.text('Ocultar'), findsOneWidget);

        // Verificar que los chips muestran el nombre específico ("Principal" y "Caja x10")
        expect(find.text('Principal'), findsOneWidget);
        expect(find.text('Caja x10'), findsOneWidget);

        // Verificar que la segunda fila del chip contiene la unidad, factor y precio en AppCurrency
        expect(
          find.textContaining(AppCurrency.format(4.50)),
          findsAtLeastNWidgets(1),
        );
        expect(
          find.textContaining(AppCurrency.format(40.00)),
          findsAtLeastNWidgets(1),
        );

        // 3. Volver a tocar "Ocultar" para colapsar
        await tester.tap(find.text('Ocultar'));
        await tester.pumpAndSettle();

        expect(find.text('Ver otras'), findsOneWidget);
        expect(find.text('Ocultar'), findsNothing);
      },
    );

    // -------------------------------------------------------------------------
    // TEST 8: MODALES DE DETALLE Y TEXTOS MONETARIOS (AppCurrency.format) EN 360DP
    // -------------------------------------------------------------------------
    testWidgets(
      '8. Modales de Detalle: Sin overflow en 360dp y verificación de AppCurrency.format',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(360, 740);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final prod = Product(
          id: 701,
          categoriaId: 1,
          nombre: 'Lápices Grafito 2B',
          modoStock: 'MIXTO',
          stockCompartido: 48,
          presentaciones: [
            ProductPresentation(
              id: 901,
              nombreEspecifico: 'Docena Escolar',
              unidadVenta: 'Docena',
              unidadesPorVenta: 12,
              stockActual: 48,
              usaStockCompartido: true,
              precioVentaFinal: 12.50,
              precioOferta: 10.00,
              costoUnitarioCalculado: 6.00,
            ),
            ProductPresentation(
              id: 902,
              nombreEspecifico: 'Caja Metálica Colección',
              unidadVenta: 'Caja',
              unidadesPorVenta: 24,
              stockActual: 5,
              usaStockCompartido: false, // Stock Propio
              precioVentaFinal: 35.00,
              costoUnitarioCalculado: 20.00,
            ),
          ],
        );

        final wrapper = InventoryWrapper(
          product: prod,
          presentation: prod.presentaciones.first,
        );

        // Validar ProductDetailModal en 360dp
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    ProductDetailModal.show(
                      context,
                      item: wrapper,
                      onAddToCart: (int q, [ProductPresentation? p]) {},
                      onAddToList: (int q, [ProductPresentation? p]) {},
                    );
                  },
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Abrir'));
        await tester.pumpAndSettle();

        // Verificar que no hay overflow
        expect(tester.takeException(), isNull);

        // Desplegar selector de variantes para verificar banner de stock compartido
        await tester.tap(find.text('Ver otras'));
        await tester.pumpAndSettle();

        // Verificar que el banner reactivo muestra "Pool Base" para la variante compartida
        expect(find.textContaining('Pool Base: 48 und.'), findsOneWidget);

        // Verificar que los precios usan el formato de AppCurrency (S/ 12.50, S/ 10.00, etc.)
        expect(
          find.textContaining(AppCurrency.format(12.50)),
          findsAtLeastNWidgets(1),
        );
        expect(
          find.textContaining(AppCurrency.format(10.00)),
          findsAtLeastNWidgets(1),
        );

        // -----------------------------------------------------------------------
        // PARTE B: Advertencia Visual de Cupo Individual Superado en ManualQuoteItemCard
        // -----------------------------------------------------------------------
        final matchedSharedItem = MatchedProduct(
          productId: 701,
          presentationId: 901,
          fullName: 'Lápices Grafito Docena Escolar',
          price: 12.50,
          stock: 48,
          unit: 'Docena',
          conversionFactor: 12,
          usaStockCompartido: true,
          sharedStockPool: 48,
          cupoMaximoVariante: 2, // Cupo fijado en 2 docenas
        );

        // Simular libremente 3 docenas (> cupo 2) en ManualQuoteItemCard
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChangeNotifierProvider<QuickSaleProvider>(
                create: (_) => QuickSaleProvider(),
                child: ManualQuoteItemCard(
                  item: matchedSharedItem,
                  quantity: 3, // Supera cupo de 2
                  manualPrice: 12.50,
                  customName: '',
                  index: 0,
                  isDark: false,
                  isClient: false,
                  isEditing: false,
                  onTap: () {},
                  onDelete: () {},
                  onIncrease: () {},
                  onDecrease: () {},
                ),
              ),
            ),
          ),
        );

        // Debe mostrar advertencia de cupo individual superado: "⚠️ Supera Cupo: 2"
        expect(find.text('⚠️ Supera Cupo: 2'), findsOneWidget);

        // -----------------------------------------------------------------------
        // PARTE C: Advertencia Visual de Cupo Individual Superado en MatchingItemRow
        // -----------------------------------------------------------------------
        final matchPair = MatchPair(
          sourceItem: ExtractedItem(
            id: 1,
            originalText: '3 docenas lapices',
            fullName: 'Lápices Grafito Docena Escolar',
            quantity: 3,
            unit: 'Docena',
          ),
          selectedProduct: matchedSharedItem,
          status: MatchStatus.manual,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ChangeNotifierProvider<MatchingProvider>(
                create: (_) => MatchingProvider(),
                child: MatchingItemRow(
                  pair: matchPair,
                  index: 0,
                  isClient: false,
                  onTapProduct: () {},
                  onChangeRequest: () {},
                  onDelete: () {},
                  onUnlink: () {},
                ),
              ),
            ),
          ),
        );

        // Debe mostrar advertencia de cupo individual superado: "Supera Cupo: 2"
        expect(find.byIcon(Icons.warning_amber_rounded), findsWidgets);
        expect(find.text('Supera Cupo: 2'), findsOneWidget);
      },
    );
  });
}
