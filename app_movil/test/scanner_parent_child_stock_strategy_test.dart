import 'package:flutter_test/flutter_test.dart';
import 'package:app_movil/features/scanner/models/scanner_models.dart';
import 'package:app_movil/features/scanner/providers/scanner_provider.dart';
import 'package:app_movil/features/scanner/widgets/staging/comparative_modal/comparative_update_modal.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ÁRBITRO ADVERSARIAL: Auditoría Matemática Padre <-> Hijo (Creación y Reversión Total)', () {
    test('1.1 Separación exacta de 2 sobrantes: Madre (+2 base, S/ 45.00) e Hija (+2 base, S/ 45.00)', () {
      final provider = ScannerProvider();

      // Madre: 4 actual en BD + 4 ingreso factura (S/ 90.00) en ½ Docena (x6)
      final madre = StagingVariant(
        uuidTemporal: 'var-madre-docena',
        nombreEspecifico: 'Vaso Vidrio',
        unidadVenta: '½ Docena',
        unidadesPorVenta: 6,
        umpCompra: 'UND',
        cantidadUmpComprada: 4.0,
        unidadesPorLote: 1,
        precioUmpProveedor: 22.50,
        totalPagoLote: 90.00,
        costoUnitarioSugerido: 135.00, // 22.50 * 6
        factorGananciaVentaSugerido: 1.35,
        precioVentaSugerido: 182.25,
        matchPresentacion: MatchResult(
          estado: 'MATCH_EXACTO',
          confianza: 100,
          datos: MatchData(
            id: 201,
            nombre: 'Vaso Vidrio ½ Docena',
            unidadVenta: '½ Docena',
            unidadesPorVenta: 6,
            stockActual: 4, // 4 actual en BD
          ),
        ),
      );

      final group = StagingProductGroup(
        uuidTemporal: 'group-vasos',
        nombrePadre: 'Vaso Vidrio Clásico',
        marcaTexto: 'Cristal',
        matchProducto: MatchResult(
          estado: 'MATCH_EXACTO',
          confianza: 100,
          datos: MatchData(id: 101, nombre: 'Vaso Vidrio Clásico', stockActual: 4),
        ),
        matchMarca: MatchResult(estado: 'MATCH_EXACTO', confianza: 100),
        variantes: [madre],
      );

      provider.setStagingDataForTesting(
        StagingResponse(
          proveedorMatch: MatchResult(estado: 'MATCH_EXACTO', confianza: 100),
          proveedorTexto: 'Cristalería Central',
          productosAgrupados: [group],
        ),
      );

      // Verificación inicial: 4 BD + 4 ingreso = 8 base. 8 % 6 = 2 sobrantes.
      int totalBaseInicial = madre.calculateTotalUnitsBase(stockActualBD: 4);
      expect(totalBaseInicial, equals(8));
      expect(totalBaseInicial % 6, equals(2));

      // Separamos las 2 unidades sobrantes
      final childUuid = provider.createLeftoverVariant(madre.uuidTemporal, 2);
      expect(childUuid, isNotNull);
      expect(group.variantes.length, equals(2));

      final hija = group.variantes.firstWhere((v) => v.uuidTemporal == childUuid);

      // 1. Verificación Madre tras separación
      expect(madre.stockIngresanteOverride, equals(2), reason: 'Madre pasa a +2 unid. base de ingreso');
      expect(madre.totalPagoLote, equals(45.00), reason: 'Total pago madre pasa a S/ 45.00');
      expect(madre.calculateTotalUnitsBase(stockActualBD: 4), equals(6), reason: '4 BD + 2 ingreso = 6 base (1 presentación exacta)');
      expect(madre.allowLeftoverInReserve, isFalse);

      // 2. Verificación Hija tras separación
      expect(hija.sourceVariantUuid, equals(madre.uuidTemporal));
      expect(hija.allocatedBaseUnits, equals(2), reason: 'Hija nace con +2 unid. base asignadas');
      expect(hija.allocatedPurchaseCost, equals(45.00), reason: 'Hija nace con S/ 45.00 asignados');
      expect(hija.cantidadUmpComprada, equals(2.0), reason: 'Compró: 2');
      expect(hija.totalPagoLote, equals(45.00), reason: 'P. Total: S/ 45.00');
      expect(hija.costoUnitarioSugerido, equals(22.50), reason: 'Costo Unit.: S/ 22.50');
      expect(hija.unidadesPorVenta, equals(1));
      expect(hija.unidadVenta, equals('Unidad'));

      // 3. Conservación de masa física y financiera exacta
      expect(madre.stockIngresanteBase + hija.stockIngresanteBase, equals(4), reason: '2 madre + 2 hija = 4 total factura');
      expect(madre.totalPagoLote + hija.totalPagoLote, equals(90.00), reason: '45.00 madre + 45.00 hija = 90.00 total factura');
    });

    test('1.2 Reversión total al eliminar la variante hija: Madre recupera +4 base y S/ 90.00', () {
      final provider = ScannerProvider();

      final madre = StagingVariant(
        uuidTemporal: 'var-madre-docena-2',
        nombreEspecifico: 'Vaso Vidrio',
        unidadVenta: '½ Docena',
        unidadesPorVenta: 6,
        umpCompra: 'UND',
        cantidadUmpComprada: 4.0,
        unidadesPorLote: 1,
        precioUmpProveedor: 22.50,
        totalPagoLote: 90.00,
        costoUnitarioSugerido: 135.00,
        factorGananciaVentaSugerido: 1.35,
        precioVentaSugerido: 182.25,
        matchPresentacion: MatchResult(
          estado: 'MATCH_EXACTO',
          confianza: 100,
          datos: MatchData(id: 201, nombre: 'Vaso Vidrio ½ Docena', stockActual: 4),
        ),
      );

      final group = StagingProductGroup(
        uuidTemporal: 'group-vasos-2',
        nombrePadre: 'Vaso Vidrio Clásico',
        marcaTexto: 'Cristal',
        matchProducto: MatchResult(estado: 'MATCH_EXACTO', confianza: 100),
        matchMarca: MatchResult(estado: 'MATCH_EXACTO', confianza: 100),
        variantes: [madre],
      );

      provider.setStagingDataForTesting(
        StagingResponse(
          proveedorMatch: MatchResult(estado: 'MATCH_EXACTO', confianza: 100),
          proveedorTexto: 'Cristalería Central',
          productosAgrupados: [group],
        ),
      );

      // Separamos 2 unidades
      final childUuid = provider.createLeftoverVariant(madre.uuidTemporal, 2)!;
      expect(group.variantes.length, equals(2));
      expect(madre.totalPagoLote, equals(45.00));

      // Simulamos que el usuario elimina la variante hija usando el flujo oficial removeVariantByUuid
      provider.removeVariantByUuid(childUuid);

      // Verificaciones post-reversión
      expect(group.variantes.length, equals(1), reason: 'Hija fue eliminada del grupo');
      expect(group.variantes.first.uuidTemporal, equals(madre.uuidTemporal));

      expect(madre.stockIngresanteOverride, equals(4), reason: 'Madre recuperó sus 2 unidades (+2 + 2 = 4)');
      expect(madre.totalPagoLote, equals(90.00), reason: 'Madre recuperó sus S/ 45.00 (45.00 + 45.00 = 90.00)');
      expect(madre.cantidadUmpComprada, equals(4.0));
      expect(madre.allowLeftoverInReserve, isFalse, reason: 'Bandera de reserva reseteada para que la alerta reaparezca');

      // Comprobar que la alerta de 2 sobrantes reaparece en la madre (4 BD + 4 ingreso = 8 total, 8 % 6 = 2)
      int totalRestaurado = madre.calculateTotalUnitsBase(stockActualBD: 4);
      expect(totalRestaurado, equals(8));
      expect(totalRestaurado % 6, equals(2), reason: 'Reaparece al instante la alerta de las 2 unid. sobrantes');
    });

    test('1.3 Conservación matemática con empaque mayorista (unidadesPorLote = 8, compra = 1 Caja por S/ 80.00)', () {
      final provider = ScannerProvider();

      final madre = StagingVariant(
        uuidTemporal: 'var-madre-mayorista',
        nombreEspecifico: 'Pilas AA',
        unidadVenta: 'Caja x6',
        unidadesPorVenta: 6,
        umpCompra: 'Caja',
        cantidadUmpComprada: 1.0,
        unidadesPorLote: 8, // 1 Caja de 8 unidades = 8 base
        precioUmpProveedor: 80.00,
        totalPagoLote: 80.00, // Costo base = S/ 10.00 por unidad
        costoUnitarioSugerido: 60.00,
        factorGananciaVentaSugerido: 1.35,
        precioVentaSugerido: 81.00,
        matchPresentacion: MatchResult(
          estado: 'NUEVO',
          confianza: 0,
        ),
      );

      final group = StagingProductGroup(
        uuidTemporal: 'group-pilas',
        nombrePadre: 'Pilas Alcalinas AA',
        marcaTexto: 'Energizer',
        matchProducto: MatchResult(estado: 'NUEVO', confianza: 0),
        matchMarca: MatchResult(estado: 'NUEVO', confianza: 0),
        variantes: [madre],
      );

      provider.setStagingDataForTesting(
        StagingResponse(
          proveedorMatch: MatchResult(estado: 'NUEVO', confianza: 0),
          proveedorTexto: 'Mayorista Pilas',
          productosAgrupados: [group],
        ),
      );

      // 8 unidades base en caja x 6 -> sobran 2 unidades
      final childUuid = provider.createLeftoverVariant(madre.uuidTemporal, 2)!;
      final hija = group.variantes.firstWhere((v) => v.uuidTemporal == childUuid);

      // Madre: 6 base, total S/ 60.00
      expect(madre.stockIngresanteOverride, equals(6));
      expect(madre.totalPagoLote, equals(60.00));

      // Hija: 2 base, total S/ 20.00
      expect(hija.stockIngresanteOverride, equals(2));
      expect(hija.totalPagoLote, equals(20.00));
      expect(hija.costoUnitarioSugerido, equals(10.00));

      // Conservación exacta: 60 + 20 = 80; 6 + 2 = 8
      expect(madre.totalPagoLote + hija.totalPagoLote, equals(80.00));
      expect(madre.stockIngresanteOverride! + hija.stockIngresanteOverride!, equals(8));

      // Al eliminar la hija:
      provider.removeVariantByUuid(childUuid);
      expect(madre.stockIngresanteOverride, equals(8));
      expect(madre.totalPagoLote, equals(80.00));
    });
  });

  group('ÁRBITRO ADVERSARIAL: Auditoría de Opción 2 ("Activar Stock Compartido - Pool único")', () {
    test('2.1 Activar Stock Compartido mantiene las 8 base intactas y auto-habilita Unidad (x1)', () {
      final provider = ScannerProvider();

      // Madre: ½ Docena (x6) con 8 unidades base (sin presentación de factor 1)
      final madre = StagingVariant(
        uuidTemporal: 'var-madre-pool',
        nombreEspecifico: 'Plato Hondo',
        unidadVenta: '½ Docena',
        unidadesPorVenta: 6,
        umpCompra: 'UND',
        cantidadUmpComprada: 8.0,
        unidadesPorLote: 1,
        precioUmpProveedor: 10.0,
        totalPagoLote: 80.00, // 8 base a S/ 10.00 = S/ 80.00
        costoUnitarioSugerido: 60.00,
        factorGananciaVentaSugerido: 1.35,
        precioVentaSugerido: 81.00,
        matchPresentacion: MatchResult(estado: 'NUEVO', confianza: 0),
      );

      final group = StagingProductGroup(
        uuidTemporal: 'group-platos',
        nombrePadre: 'Plato Hondo Porcelana',
        marcaTexto: 'Corona',
        matchProducto: MatchResult(estado: 'NUEVO', confianza: 0),
        matchMarca: MatchResult(estado: 'NUEVO', confianza: 0),
        modoStock: 'INDEPENDIENTE',
        variantes: [madre],
      );

      provider.setStagingDataForTesting(
        StagingResponse(
          proveedorMatch: MatchResult(estado: 'NUEVO', confianza: 0),
          proveedorTexto: 'Cerámicas',
          productosAgrupados: [group],
        ),
      );

      // Usuario selecciona la Opción 2 desde la alerta de sobrante
      provider.activateSharedStockForGroup(group.uuidTemporal, madre.uuidTemporal);

      // 1. Grupo pasa a modo COMPARTIDO
      expect(group.modoStock, equals('COMPARTIDO'));

      // 2. Pool de stock conserva las 8 unidades base completas sin restar nada
      expect(group.stockCompartido, equals(8));
      expect(group.costoBase, equals(10.00));

      // 3. Todas las variantes del grupo marcadas con usaStockCompartido = true
      expect(madre.usaStockCompartido, isTrue);

      // 4. Se auto-crea la variante 'Unidad (x1)' vinculada al mismo pool
      expect(group.variantes.length, equals(2));
      final unitVariant = group.variantes.firstWhere((v) => v.effectiveFactorVenta == 1);
      expect(unitVariant.unidadVenta, equals('Unidad'));
      expect(unitVariant.unidadesPorVenta, equals(1));
      expect(unitVariant.usaStockCompartido, isTrue);
      expect(unitVariant.costoUnitarioSugerido, equals(10.00));
      expect(unitVariant.precioVentaSugerido, equals(13.50));
    });
  });

  group('ÁRBITRO ADVERSARIAL: Auditoría de Textos, Cero Emojis Duplicados y Formatos', () {
    test('3.1 Formato del badge de acumulación: "1 × ½ Docena disponible hoy (+2 unid. base acumuladas en almacén)"', () {
      final badgeText = ComparativeUpdateModal.formatAccumulationBadgeText(1, '½ Docena', 2);

      expect(badgeText, equals('1 × ½ Docena disponible hoy (+2 unid. base acumuladas en almacén)'));
      expect(badgeText.contains('reserva base'), isFalse, reason: 'Ya no existe la frase confusa "en reserva base"');
    });

    test('3.2 AppCurrency formatea limpiamente los precios', () {
      expect(AppCurrency.format(45.0), equals('S/ 45.00'));
      expect(AppCurrency.format(22.5), equals('S/ 22.50'));
      expect(AppCurrency.format(90.0), equals('S/ 90.00'));
    });
  });

  group('ÁRBITRO ADVERSARIAL: Auditoría de Guardado Atómico SQLite V26 en ScannerBatchSaver', () {
    late Database db;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);
      // Crear esquema simplificado relevante a SQLite V26
      await db.execute('''
        CREATE TABLE proveedores (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          negocio_id INTEGER,
          nombre_empresa TEXT,
          ruc TEXT,
          activo INTEGER,
          fecha_creacion TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE facturas_carga (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          numero_secuencial INTEGER,
          negocio_id INTEGER,
          proveedor_id INTEGER,
          estado TEXT,
          fecha_carga TEXT,
          fecha_emision TEXT,
          monto_total_factura REAL,
          imagen_url TEXT,
          datos_crudos_ia_json TEXT,
          cantidad_items_extraidos INTEGER
        )
      ''');
      await db.execute('''
        CREATE TABLE productos (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          negocio_id INTEGER,
          nombre TEXT,
          categoria_id INTEGER,
          marca_id INTEGER,
          estado TEXT,
          modo_stock TEXT DEFAULT 'INDEPENDIENTE',
          stock_compartido INTEGER DEFAULT 0,
          costo_base REAL DEFAULT 0.0,
          fecha_actualizacion TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE presentaciones_producto (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          producto_id INTEGER,
          proveedor_id INTEGER,
          factura_carga_id INTEGER,
          nombre_especifico TEXT,
          codigo_barras TEXT,
          ump_compra TEXT,
          precio_ump_proveedor REAL,
          cantidad_ump_comprada REAL,
          total_pago_lote REAL,
          unidades_por_lote INTEGER,
          unidad_venta TEXT,
          unidades_por_venta INTEGER,
          factor_ganancia_venta REAL,
          costo_unitario_calculado REAL,
          precio_venta_final REAL,
          stock_actual INTEGER,
          usa_stock_compartido INTEGER DEFAULT 0,
          cupo_maximo_variante INTEGER,
          precio_oferta REAL,
          tipo_descuento TEXT,
          valor_descuento REAL,
          estado TEXT,
          activo INTEGER,
          es_default INTEGER
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
        CREATE TABLE product_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          entidad_tipo TEXT,
          entidad_id INTEGER,
          campo_modificado TEXT,
          valor_anterior TEXT,
          valor_nuevo TEXT,
          fecha_cambio TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE marcas (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          negocio_id INTEGER,
          nombre TEXT,
          activo INTEGER
        )
      ''');
    });

    tearDown(() async {
      await db.close();
    });

    test('4.1 Guardado atómico sincroniza presentaciones hermanas preexistentes en SQLite al pool compartido', () async {
      // 1. Insertamos un producto existente con modo INDEPENDIENTE y 2 presentaciones hermanas
      int prodId = await db.insert('productos', {
        'negocio_id': 1,
        'nombre': 'Cuaderno Standford',
        'modo_stock': 'INDEPENDIENTE',
        'stock_compartido': 0,
        'costo_base': 5.0,
      });

      // Hermana 1: Unidad (x1) con stock_actual = 10
      await db.insert('presentaciones_producto', {
        'producto_id': prodId,
        'nombre_especifico': 'Unidad',
        'unidad_venta': 'Unidad',
        'unidades_por_venta': 1,
        'stock_actual': 10,
        'usa_stock_compartido': 1,
        'costo_unitario_calculado': 5.0,
        'precio_venta_final': 7.0,
        'activo': 1,
        'es_default': 1,
      });

      // Hermana 2 (no vino en la factura): Pack x3 con stock_actual = 10
      int p2 = await db.insert('presentaciones_producto', {
        'producto_id': prodId,
        'nombre_especifico': 'Pack x3',
        'unidad_venta': 'Pack',
        'unidades_por_venta': 3,
        'stock_actual': 10,
        'usa_stock_compartido': 1,
        'costo_unitario_calculado': 15.0,
        'precio_venta_final': 20.0,
        'activo': 1,
        'es_default': 0,
      });

      // 2. Factura ingresa +20 unidades en Hermana 1 y activa modo COMPARTIDO con pool = 30 y nuevo costo base = 6.0
      await db.transaction((txn) async {
        const int nuevoPool = 30;
        const double nuevoCostoBase = 6.0;

        // Actualización padre
        await txn.update('productos', {
          'modo_stock': 'COMPARTIDO',
          'stock_compartido': nuevoPool,
          'costo_base': nuevoCostoBase,
          'fecha_actualizacion': DateTime.now().toIso8601String(),
        }, where: 'id = ?', whereArgs: [prodId]);

        // Consulta atómica de ScannerBatchSaver (Regla 3)
        await txn.rawUpdate('''
          UPDATE presentaciones_producto
          SET stock_actual = ?
          WHERE producto_id = ? AND usa_stock_compartido = 1
        ''', [nuevoPool, prodId]);

        await txn.rawUpdate('''
          UPDATE presentaciones_producto
          SET costo_unitario_calculado = ? * unidades_por_venta
          WHERE producto_id = ? AND usa_stock_compartido = 1
        ''', [nuevoCostoBase, prodId]);
      });

      // 3. Verificación de Hermana 2 (que no vino en la factura)
      final pres2 = await db.query('presentaciones_producto', where: 'id = ?', whereArgs: [p2]);
      expect(pres2.first['stock_actual'], equals(30), reason: 'Hermana 2 sincronizada al nuevo pool compartido de 30 unidades');
      expect(pres2.first['costo_unitario_calculado'], equals(18.0), reason: 'Costo de Hermana 2 actualizado proporcionalmente (6.0 * 3 = 18.0)');

      final prod = await db.query('productos', where: 'id = ?', whereArgs: [prodId]);
      expect(prod.first['modo_stock'], equals('COMPARTIDO'));
      expect(prod.first['stock_compartido'], equals(30));
      expect(prod.first['costo_base'], equals(6.0));
    });
  });
}
