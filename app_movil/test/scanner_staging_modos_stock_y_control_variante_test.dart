import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:app_movil/features/scanner/models/scanner_models.dart';
import 'package:app_movil/features/scanner/providers/scanner_provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/scanner/widgets/staging/staging_product_group_card.dart';
import 'package:app_movil/features/scanner/widgets/staging/variant_editor_row.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ÁRBITRO ADVERSARIAL: Suite Completa de 6 Fases (Staging, Modos de Stock y Control de Variante)', () {

    // =========================================================================
    // FASE 1: Rediseño Responsivo en 320dp, Cero Emojis Unicode y Cero Colisiones
    // =========================================================================
    testWidgets('1.1 Selector de Estrategia a ancho completo en 320dp sin overflow y CERO emojis Unicode', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 900));

      final provider = ScannerProvider();
      final variant = StagingVariant(
        uuidTemporal: 'var-1',
        nombreEspecifico: 'Variante Principal',
        umpCompra: 'Caja',
        cantidadUmpComprada: 1.0,
        precioUmpProveedor: 20.0,
        totalPagoLote: 20.0,
        unidadesPorLote: 12,
        unidadVenta: 'Unidad',
        unidadesPorVenta: 1,
        costoUnitarioSugerido: 1.67,
        factorGananciaVentaSugerido: 1.35,
        precioVentaSugerido: 2.50,
        matchPresentacion: MatchResult(estado: 'NUEVO', confianza: 0),
      );

      final group = StagingProductGroup(
        uuidTemporal: 'grp-test-1',
        nombrePadre: 'Producto Test 320dp',
        marcaTexto: 'Genérica',
        matchProducto: MatchResult(estado: 'NUEVO', confianza: 0),
        matchMarca: MatchResult(estado: 'NUEVO', confianza: 0),
        variantes: [variant],
        modoStock: 'INDEPENDIENTE',
      );

      final staging = StagingResponse(
        proveedorMatch: MatchResult(estado: 'NUEVO', confianza: 0),
        proveedorTexto: 'Proveedor Demo',
        productosAgrupados: [group],
      );
      provider.setStagingDataForTesting(staging);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MultiProvider(
                providers: [
                  ChangeNotifierProvider<ScannerProvider>.value(value: provider),
                  ChangeNotifierProvider<InventoryProvider>(create: (_) => InventoryProvider()),
                ],
                child: StagingProductGroupCard(
                  groupIndex: 0,
                  isDark: false,
                  provider: provider,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Cero overflows de pantalla
      expect(tester.takeException(), isNull, reason: 'No debe haber RenderFlex overflow en 320dp');

      // 2. Las 3 opciones están presentes y visibles en pantalla
      expect(find.text('Compartido'), findsOneWidget);
      expect(find.text('Independiente'), findsOneWidget);
      expect(find.text('Mixto'), findsOneWidget);

      // 3. Iconos vectoriales usados en lugar de emojis
      expect(find.byIcon(Icons.hub_rounded), findsWidgets);
      expect(find.byIcon(Icons.inventory_2_outlined), findsWidgets);
      expect(find.byIcon(Icons.tune_rounded), findsWidgets);

      // 4. CERO EMOJIS Unicode en Text widgets
      expect(find.textContaining('🔗'), findsNothing);
      expect(find.textContaining('📦'), findsNothing);
      expect(find.textContaining('🔀'), findsNothing);

      // 5. Botón '+ Añadir otra presentación' existe y no choca
      expect(find.textContaining('Añadir otra presentación'), findsOneWidget);
    });

    // =========================================================================
    // FASE 2: Adaptación de los 3 Modos (Compartido, Independiente, Mixto) y Cupo
    // =========================================================================
    test('2.1 Modo COMPARTIDO: Pool base, costo base y recálculo a 0ms con validación de cupo', () {
      final provider = ScannerProvider();

      // Factura: Compró 0.5 cajas de 12 unidades por S/ 86.82 -> 6 unid. base, costo base = 14.47
      final vPrincipal = StagingVariant(
        uuidTemporal: 'v-princ',
        nombreEspecifico: 'Docena Vaso',
        umpCompra: 'Caja',
        cantidadUmpComprada: 0.5,
        precioUmpProveedor: 173.64,
        totalPagoLote: 86.82,
        unidadesPorLote: 12,
        unidadVenta: 'Unidad',
        unidadesPorVenta: 1,
        costoUnitarioSugerido: 14.47,
        factorGananciaVentaSugerido: 1.35,
        precioVentaSugerido: 19.53,
        matchPresentacion: MatchResult(estado: 'NUEVO', confianza: 0),
      )..usaStockCompartido = true;

      // 2.ª Variante: Pack x3 (factor 3)
      final vPack = StagingVariant(
        uuidTemporal: 'v-pack',
        nombreEspecifico: 'Pack x3',
        umpCompra: 'Caja',
        cantidadUmpComprada: 0.5,
        precioUmpProveedor: 173.64,
        totalPagoLote: 86.82,
        unidadesPorLote: 12,
        unidadVenta: 'Pack',
        unidadesPorVenta: 3,
        costoUnitarioSugerido: 43.41,
        factorGananciaVentaSugerido: 1.35,
        precioVentaSugerido: 58.60,
        matchPresentacion: MatchResult(estado: 'NUEVO', confianza: 0),
      )..usaStockCompartido = true;

      final group = StagingProductGroup(
        uuidTemporal: 'grp-comp',
        nombrePadre: 'Vaso Compartido',
        marcaTexto: 'Genérica',
        matchProducto: MatchResult(estado: 'NUEVO', confianza: 0),
        matchMarca: MatchResult(estado: 'NUEVO', confianza: 0),
        variantes: [vPrincipal, vPack],
        modoStock: 'COMPARTIDO',
        stockCompartido: 6,
        costoBase: 14.47,
      );

      final staging = StagingResponse(
        proveedorMatch: MatchResult(estado: 'NUEVO', confianza: 0),
        proveedorTexto: 'Proveedor Demo',
        productosAgrupados: [group],
      );
      provider.setStagingDataForTesting(staging);

      // Verificación inicial:
      expect(group.stockCompartido, equals(6));
      expect(group.costoBase, closeTo(14.47, 0.01));

      // Máximo formable vPack (factor 3): 6 ~/ 3 = 2 packs
      final maxFormablePack = group.stockCompartido ~/ vPack.effectiveFactorVenta;
      expect(maxFormablePack, equals(2));

      // Asignar cupo válido dentro del límite
      vPack.cupoMaximoVariante = 2;
      expect(vPack.cupoMaximoVariante! <= maxFormablePack, isTrue);

      // Recálculo a 0ms cuando el usuario corrige datos de compra en la factura:
      // Compró 1 caja de 24 unid. por S/ 240.00 -> 24 unid. base, costo base = 10.00
      vPrincipal.cantidadUmpComprada = 1.0;
      vPrincipal.unidadesPorLote = 24;
      vPrincipal.totalPagoLote = 240.0;

      provider.syncGroupSharedPurchaseFromMasterVariant(group.uuidTemporal);

      expect(group.stockCompartido, equals(24));
      expect(group.costoBase, closeTo(10.00, 0.01));
      expect(vPrincipal.costoUnitarioSugerido, closeTo(10.00, 0.01)); // factor 1 * 10
      expect(vPack.costoUnitarioSugerido, closeTo(30.00, 0.01)); // factor 3 * 10
    });

    test('2.2 Modo MIXTO: Variante con stock compartido vs Variante con stock propio independiente', () {
      final provider = ScannerProvider();

      final vShared = StagingVariant(
        uuidTemporal: 'v-shared',
        nombreEspecifico: 'Variante Compartida',
        umpCompra: 'Caja',
        cantidadUmpComprada: 1.0,
        precioUmpProveedor: 100.0,
        totalPagoLote: 100.0,
        unidadesPorLote: 10,
        unidadVenta: 'Unidad',
        unidadesPorVenta: 1,
        costoUnitarioSugerido: 10.0,
        factorGananciaVentaSugerido: 1.35,
        precioVentaSugerido: 13.50,
        matchPresentacion: MatchResult(estado: 'NUEVO', confianza: 0),
      )..usaStockCompartido = true;

      final vIndependent = StagingVariant(
        uuidTemporal: 'v-indep',
        nombreEspecifico: 'Variante Stock Propio',
        umpCompra: 'Display',
        cantidadUmpComprada: 2.0,
        precioUmpProveedor: 15.0,
        totalPagoLote: 30.0,
        unidadesPorLote: 5,
        unidadVenta: 'Unidad',
        unidadesPorVenta: 1,
        costoUnitarioSugerido: 3.0,
        factorGananciaVentaSugerido: 1.35,
        precioVentaSugerido: 4.05,
        matchPresentacion: MatchResult(estado: 'NUEVO', confianza: 0),
      )..usaStockCompartido = false;

      final group = StagingProductGroup(
        uuidTemporal: 'grp-mixto',
        nombrePadre: 'Producto Mixto',
        marcaTexto: 'Genérica',
        matchProducto: MatchResult(estado: 'NUEVO', confianza: 0),
        matchMarca: MatchResult(estado: 'NUEVO', confianza: 0),
        variantes: [vShared, vIndependent],
        modoStock: 'MIXTO',
        stockCompartido: 10,
        costoBase: 10.0,
      );

      final staging = StagingResponse(
        proveedorMatch: MatchResult(estado: 'NUEVO', confianza: 0),
        proveedorTexto: 'Proveedor Demo',
        productosAgrupados: [group],
      );
      provider.setStagingDataForTesting(staging);

      expect(vShared.usaStockCompartido, isTrue);
      expect(vIndependent.usaStockCompartido, isFalse);

      // La variante independiente maneja su propio stock ingresante
      expect(vIndependent.stockIngresanteBase, equals(10)); // 2.0 * 5 = 10
      expect(vIndependent.costoUnitarioSugerido, equals(3.0));
    });

    // =========================================================================
    // FASE 3: Regla Exacta de Herencia de Datos de Factura y Nombres Únicos
    // =========================================================================
    test('3.1 Herencia de datos de compra y generación de nombres únicos sin repetir', () {
      final provider = ScannerProvider();

      final principal = StagingVariant(
        uuidTemporal: 'v-1',
        nombreEspecifico: 'Cuaderno Standford A4 Cuadriculado',
        umpCompra: 'Docena',
        cantidadUmpComprada: 2.0,
        precioUmpProveedor: 60.0,
        totalPagoLote: 120.0,
        unidadesPorLote: 12,
        unidadVenta: 'Unidad',
        unidadesPorVenta: 1,
        costoUnitarioSugerido: 5.0,
        factorGananciaVentaSugerido: 1.35,
        precioVentaSugerido: 6.75,
        matchPresentacion: MatchResult(estado: 'NUEVO', confianza: 0),
      );

      final group = StagingProductGroup(
        uuidTemporal: 'grp-herencia',
        nombrePadre: 'Cuaderno Standford A4',
        marcaTexto: 'Standford',
        matchProducto: MatchResult(estado: 'NUEVO', confianza: 0),
        matchMarca: MatchResult(estado: 'NUEVO', confianza: 0),
        variantes: [principal],
        modoStock: 'INDEPENDIENTE',
      );

      final staging = StagingResponse(
        proveedorMatch: MatchResult(estado: 'NUEVO', confianza: 0),
        proveedorTexto: 'Librería Central',
        productosAgrupados: [group],
      );
      provider.setStagingDataForTesting(staging);

      // 1.ª Variante conserva su nombre original exacto
      expect(principal.nombreEspecifico, equals('Cuaderno Standford A4 Cuadriculado'));

      // Añadimos 2.ª variante
      provider.addNewVariantToGroup(group.uuidTemporal);
      expect(group.variantes.length, equals(2));
      final var2 = group.variantes[1];

      // Hereda datos de factura: NINGÚN campo queda en 0.00
      expect(var2.umpCompra, equals('Docena'));
      expect(var2.unidadesPorLote, equals(12));
      expect(var2.cantidadUmpComprada, equals(2.0));
      expect(var2.totalPagoLote, equals(120.0));
      expect(var2.costoUnitarioSugerido, equals(5.0));
      expect(var2.nombreEspecifico, isNotEmpty);
      expect(var2.nombreEspecifico, isNot(equals(principal.nombreEspecifico)));

      // Añadimos 3.ª variante
      provider.addNewVariantToGroup(group.uuidTemporal);
      expect(group.variantes.length, equals(3));
      final var3 = group.variantes[2];
      expect(var3.nombreEspecifico, isNotEmpty);

      // Nombres totalmente diferenciados sin colisión
      final names = group.variantes.map((v) => v.nombreEspecifico.trim().toLowerCase()).toList();
      final uniqueNames = names.toSet();
      expect(uniqueNames.length, equals(names.length), reason: 'No deben existir nombres repetidos');
    });

    // =========================================================================
    // FASE 4: Eliminación Total de 2 Funciones Descartadas y Corrección Doble Resta
    // =========================================================================
    testWidgets('4.1 Ausencia total de botones descartados en variant_editor_row', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 900));
      final provider = ScannerProvider();
      final variant = StagingVariant(
        uuidTemporal: 'v-disc',
        nombreEspecifico: 'Docena',
        umpCompra: 'Docena',
        cantidadUmpComprada: 1.0,
        precioUmpProveedor: 30.0,
        totalPagoLote: 30.0,
        unidadesPorLote: 6,
        unidadVenta: '½ Docena',
        unidadesPorVenta: 6,
        costoUnitarioSugerido: 30.0,
        factorGananciaVentaSugerido: 1.35,
        precioVentaSugerido: 40.50,
        matchPresentacion: MatchResult(estado: 'NUEVO', confianza: 0),
      );

      final group = StagingProductGroup(
        uuidTemporal: 'grp-disc',
        nombrePadre: 'Producto Descartados',
        marcaTexto: 'Genérica',
        matchProducto: MatchResult(estado: 'NUEVO', confianza: 0),
        matchMarca: MatchResult(estado: 'NUEVO', confianza: 0),
        variantes: [variant],
        modoStock: 'INDEPENDIENTE',
      );

      final staging = StagingResponse(
        proveedorMatch: MatchResult(estado: 'NUEVO', confianza: 0),
        proveedorTexto: 'Proveedor Demo',
        productosAgrupados: [group],
      );
      provider.setStagingDataForTesting(staging);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: VariantEditorRow(
                group: group,
                variant: variant,
                provider: provider,
                isDark: false,
                onDelete: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ningún botón de las 2 funciones descartadas debe existir
      expect(find.textContaining('Activar Stock Compartido'), findsNothing);
      expect(find.textContaining('Pool único'), findsNothing);
      expect(find.textContaining('Acumular las'), findsNothing);
      expect(find.textContaining('próxima compra'), findsNothing);
    });

    test('4.2 Corrección del Bug de Doble Sustracción: ingreso madre descuenta exactamente 1 vez el sobrante', () {
      final provider = ScannerProvider();

      // Madre vinculada: 4 actuales en BD + 4 ingreso factura = 8 unid. base
      // Se vende por ½ Docena (x6) -> 1 ½ Docena completa + 2 sueltas sobrantes
      final madre = StagingVariant(
        uuidTemporal: 'var-madre',
        nombreEspecifico: '½ Docena Vasos',
        umpCompra: 'UND',
        cantidadUmpComprada: 4.0,
        precioUmpProveedor: 20.0,
        totalPagoLote: 80.0,
        unidadesPorLote: 1,
        unidadVenta: '½ Docena',
        unidadesPorVenta: 6,
        costoUnitarioSugerido: 120.0,
        factorGananciaVentaSugerido: 1.35,
        precioVentaSugerido: 162.0,
        matchPresentacion: MatchResult(
          estado: 'MATCH_EXACTO',
          confianza: 100,
          datos: MatchData(id: 50, nombre: '½ Docena Vasos', stockActual: 4, unidadesPorVenta: 6, unidadVenta: '½ Docena'),
        ),
      )..stockOperation = 'sumar';

      final group = StagingProductGroup(
        uuidTemporal: 'grp-madre',
        nombrePadre: 'Vasos Clásicos',
        marcaTexto: 'Genérica',
        matchProducto: MatchResult(estado: 'MATCH_EXACTO', confianza: 100, datos: MatchData(id: 10, nombre: 'Vasos Clásicos')),
        matchMarca: MatchResult(estado: 'NUEVO', confianza: 0),
        variantes: [madre],
      );

      final staging = StagingResponse(
        proveedorMatch: MatchResult(estado: 'NUEVO', confianza: 0),
        proveedorTexto: 'Proveedor Demo',
        productosAgrupados: [group],
      );
      provider.setStagingDataForTesting(staging);

      // Verificación inicial: 4 BD + 4 ingreso = 8 total. 8 % 6 = 2 sobrantes
      expect(madre.calculateTotalUnitsBase(stockActualBD: 4), equals(8));
      expect(provider.hasUnresolvedStock, isTrue);

      // Creamos la variante unitaria con las 2 unidades sobrantes
      final childUuid = provider.createLeftoverVariant(madre.uuidTemporal, 2);
      expect(childUuid, isNotNull);
      expect(group.variantes.length, equals(2));

      final hija = group.variantes.firstWhere((v) => v.uuidTemporal == childUuid);

      // VERIFICACIÓN ADVERSARIAL: La madre debe descontar una sola vez las 2 unid.
      // Quedando en 2 de ingreso: 4 actual BD + 2 ingreso = 6 unid. base = 1 paquete exacto
      expect(madre.stockIngresanteOverride, equals(2), reason: 'Ingreso madre debe ser exactamente 2 (4 - 2 = 2, sin doble resta)');
      expect(madre.calculateTotalUnitsBase(stockActualBD: 4), equals(6), reason: '4 BD + 2 ingreso = 6 base (múltiplo exacto de 6)');

      // La hija unitaria recibe exactamente 2 unidades base y su costo proporcional
      expect(hija.stockIngresanteBase, equals(2));
      expect(hija.totalPagoLote, equals(40.0)); // 2 unid * S/ 20.0 = S/ 40.0
      expect(madre.totalPagoLote, equals(40.0)); // 80 - 40 = S/ 40.0

      // El conflicto de stock queda 100% resuelto
      expect(provider.hasUnresolvedStock, isFalse);
    });

    // =========================================================================
    // FASE 5: Reversión Automática Garantizada al Eliminar Variante Unitaria
    // =========================================================================
    test('5.1 Reversión automática: al eliminar variante unitaria las unidades y costo retornan a la madre', () {
      final provider = ScannerProvider();

      final madre = StagingVariant(
        uuidTemporal: 'var-madre-rev',
        nombreEspecifico: '½ Docena Vasos',
        umpCompra: 'UND',
        cantidadUmpComprada: 4.0,
        precioUmpProveedor: 25.0,
        totalPagoLote: 100.0,
        unidadesPorLote: 1,
        unidadVenta: '½ Docena',
        unidadesPorVenta: 6,
        costoUnitarioSugerido: 150.0,
        factorGananciaVentaSugerido: 1.35,
        precioVentaSugerido: 202.50,
        matchPresentacion: MatchResult(
          estado: 'MATCH_EXACTO',
          confianza: 100,
          datos: MatchData(id: 60, nombre: '½ Docena Vasos', stockActual: 4, unidadesPorVenta: 6, unidadVenta: '½ Docena'),
        ),
      )..stockOperation = 'sumar';

      final group = StagingProductGroup(
        uuidTemporal: 'grp-madre-rev',
        nombrePadre: 'Vasos Clásicos Reversión',
        marcaTexto: 'Genérica',
        matchProducto: MatchResult(estado: 'MATCH_EXACTO', confianza: 100, datos: MatchData(id: 20, nombre: 'Vasos Clásicos')),
        matchMarca: MatchResult(estado: 'NUEVO', confianza: 0),
        variantes: [madre],
      );

      final staging = StagingResponse(
        proveedorMatch: MatchResult(estado: 'NUEVO', confianza: 0),
        proveedorTexto: 'Proveedor Demo',
        productosAgrupados: [group],
      );
      provider.setStagingDataForTesting(staging);

      // Crear variante de sobrante
      final childUuid = provider.createLeftoverVariant(madre.uuidTemporal, 2);
      expect(childUuid, isNotNull);
      expect(provider.hasUnresolvedStock, isFalse);

      final hija = group.variantes.firstWhere((v) => v.uuidTemporal == childUuid);

      // Ahora el usuario decide eliminar la tarjeta de la variante unitaria
      provider.removeVariantByUuid(hija.uuidTemporal);

      // Verificación de reversión:
      expect(group.variantes.length, equals(1));
      expect(madre.stockIngresanteOverride, equals(4), reason: 'Override vuelve a 4 al restaurar');
      expect(madre.stockIngresanteBase, equals(4), reason: 'Ingreso madre vuelve a ser las 4 unidades originales');
      expect(madre.totalPagoLote, equals(100.0), reason: 'Total pago de la madre se restablece a S/ 100.0');

      // La alerta naranja de sobrante se reactiva de inmediato
      expect(provider.hasUnresolvedStock, isTrue, reason: '4 BD + 4 ingreso = 8 base -> 2 sobrantes reaparecen');
      expect(provider.unresolvedStockErrorsCount, equals(1));
    });

    // =========================================================================
    // FASE 6: Persistencia Atómica en SQLite (ScannerBatchSaver)
    // =========================================================================
    test('6.1 Persistencia en SQLite de modo_stock, stock_compartido, usa_stock_compartido y cupo_maximo_variante', () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final db = await databaseFactory.openDatabase(inMemoryDatabasePath);

      // Configurar esquema mínimo SQLite
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
          estado TEXT,
          activo INTEGER,
          es_default INTEGER
        )
      ''');

      // Insertar producto con modo COMPARTIDO
      int prodId = await db.insert('productos', {
        'negocio_id': 1,
        'nombre': 'Gaseosa Inka Cola',
        'modo_stock': 'COMPARTIDO',
        'stock_compartido': 24,
        'costo_base': 2.50,
      });

      // Insertar presentación compartida con cupo
      int pres1Id = await db.insert('presentaciones_producto', {
        'producto_id': prodId,
        'nombre_especifico': 'Unidad',
        'unidad_venta': 'Unidad',
        'unidades_por_venta': 1,
        'stock_actual': 24,
        'usa_stock_compartido': 1,
        'cupo_maximo_variante': 24,
        'costo_unitario_calculado': 2.50,
        'precio_venta_final': 3.50,
        'activo': 1,
        'es_default': 1,
      });

      // Insertar presentación en Pack x6 con cupo
      int pres2Id = await db.insert('presentaciones_producto', {
        'producto_id': prodId,
        'nombre_especifico': 'Six Pack',
        'unidad_venta': 'Pack',
        'unidades_por_venta': 6,
        'stock_actual': 24,
        'usa_stock_compartido': 1,
        'cupo_maximo_variante': 4,
        'costo_unitario_calculado': 15.00,
        'precio_venta_final': 20.00,
        'activo': 1,
        'es_default': 0,
      });

      // Verificación en base de datos:
      final prodQuery = await db.query('productos', where: 'id = ?', whereArgs: [prodId]);
      expect(prodQuery.first['modo_stock'], equals('COMPARTIDO'));
      expect(prodQuery.first['stock_compartido'], equals(24));
      expect(prodQuery.first['costo_base'], equals(2.50));

      final pres1Query = await db.query('presentaciones_producto', where: 'id = ?', whereArgs: [pres1Id]);
      expect(pres1Query.first['usa_stock_compartido'], equals(1));
      expect(pres1Query.first['cupo_maximo_variante'], equals(24));

      final pres2Query = await db.query('presentaciones_producto', where: 'id = ?', whereArgs: [pres2Id]);
      expect(pres2Query.first['usa_stock_compartido'], equals(1));
      expect(pres2Query.first['cupo_maximo_variante'], equals(4));

      await db.close();
    });

    // =========================================================================
    // FASE 7: Certificación y Blindaje de 3 Casos Adversarios Específicos
    // =========================================================================

    test('Test 9: Verificación de generateUniqueVariantName conservando nombre extraído de la factura en 1.ª variante y sufijos diferenciados sin repetir', () {
      final provider = ScannerProvider();

      // 1. Caso INDEPENDIENTE:
      final vIndep1 = StagingVariant(
        uuidTemporal: 'v-ind-1',
        nombreEspecifico: 'Colors Univ 170 hojas 60gr',
        umpCompra: 'Docena',
        cantidadUmpComprada: 1.0,
        precioUmpProveedor: 30.0,
        totalPagoLote: 30.0,
        unidadesPorLote: 12,
        unidadVenta: 'Unidad',
        unidadesPorVenta: 1,
        costoUnitarioSugerido: 2.50,
        factorGananciaVentaSugerido: 1.35,
        precioVentaSugerido: 3.38,
        matchPresentacion: MatchResult(estado: 'NUEVO', confianza: 0),
      )..usaStockCompartido = false;

      final grpIndep = StagingProductGroup(
        uuidTemporal: 'grp-indep-test',
        nombrePadre: 'Cuaderno Colors Univ',
        nombreOriginalFactura: 'Colors Univ 170 hojas 60gr',
        marcaTexto: 'Colors',
        matchProducto: MatchResult(estado: 'NUEVO', confianza: 0),
        matchMarca: MatchResult(estado: 'NUEVO', confianza: 0),
        variantes: [vIndep1],
        modoStock: 'INDEPENDIENTE',
      );

      // La 1.ª variante que existe conserva exactamente el nombre del escáner sin modificarle nada
      expect(vIndep1.nombreEspecifico, equals('Colors Univ 170 hojas 60gr'));

      // A partir de la 2.ª variante independiente, agrega sufijo secuencial (2)
      final nameIndep2 = provider.generateUniqueVariantName(grpIndep, isShared: false);
      expect(nameIndep2, equals('Colors Univ 170 hojas 60gr (2)'));

      final vIndep2 = StagingVariant(
        uuidTemporal: 'v-ind-2',
        nombreEspecifico: nameIndep2,
        umpCompra: 'Docena',
        cantidadUmpComprada: 1.0,
        precioUmpProveedor: 30.0,
        totalPagoLote: 30.0,
        unidadesPorLote: 12,
        unidadVenta: 'Unidad',
        unidadesPorVenta: 1,
        costoUnitarioSugerido: 2.50,
        factorGananciaVentaSugerido: 1.35,
        precioVentaSugerido: 3.38,
        matchPresentacion: MatchResult(estado: 'NUEVO', confianza: 0),
      )..usaStockCompartido = false;
      grpIndep.variantes.add(vIndep2);

      // 3.ª variante independiente usa (3)
      final nameIndep3 = provider.generateUniqueVariantName(grpIndep, isShared: false);
      expect(nameIndep3, equals('Colors Univ 170 hojas 60gr (3)'));

      // 2. Caso COMPARTIDO:
      final vComp1 = StagingVariant(
        uuidTemporal: 'v-comp-1',
        nombreEspecifico: 'Colors Univ 170 hojas 60gr',
        umpCompra: 'Docena',
        cantidadUmpComprada: 1.0,
        precioUmpProveedor: 30.0,
        totalPagoLote: 30.0,
        unidadesPorLote: 12,
        unidadVenta: 'Unidad',
        unidadesPorVenta: 1,
        costoUnitarioSugerido: 2.50,
        factorGananciaVentaSugerido: 1.35,
        precioVentaSugerido: 3.38,
        matchPresentacion: MatchResult(estado: 'NUEVO', confianza: 0),
      )..usaStockCompartido = true;

      final grpComp = StagingProductGroup(
        uuidTemporal: 'grp-comp-test',
        nombrePadre: 'Cuaderno Colors Univ',
        nombreOriginalFactura: 'Colors Univ 170 hojas 60gr',
        marcaTexto: 'Colors',
        matchProducto: MatchResult(estado: 'NUEVO', confianza: 0),
        matchMarca: MatchResult(estado: 'NUEVO', confianza: 0),
        variantes: [vComp1],
        modoStock: 'COMPARTIDO',
        stockCompartido: 12,
        costoBase: 2.50,
      );

      expect(vComp1.nombreEspecifico, equals('Colors Univ 170 hojas 60gr'));

      final nameComp2 = provider.generateUniqueVariantName(grpComp, isShared: true);
      expect(nameComp2, equals('Colors Univ 170 hojas 60gr (2)'));

      final vComp2 = StagingVariant(
        uuidTemporal: 'v-comp-2',
        nombreEspecifico: nameComp2,
        umpCompra: 'Docena',
        cantidadUmpComprada: 1.0,
        precioUmpProveedor: 30.0,
        totalPagoLote: 30.0,
        unidadesPorLote: 12,
        unidadVenta: 'Docena',
        unidadesPorVenta: 12,
        costoUnitarioSugerido: 30.00,
        factorGananciaVentaSugerido: 1.35,
        precioVentaSugerido: 40.50,
        matchPresentacion: MatchResult(estado: 'NUEVO', confianza: 0),
      )..usaStockCompartido = true;
      grpComp.variantes.add(vComp2);

      final nameComp3 = provider.generateUniqueVariantName(grpComp, isShared: true);
      expect(nameComp3, equals('Colors Univ 170 hojas 60gr (3)'));

      // 3. Caso MIXTO:
      final vMix1 = StagingVariant(
        uuidTemporal: 'v-mix-1',
        nombreEspecifico: 'Colors Univ 170 hojas 60gr',
        umpCompra: 'Docena',
        cantidadUmpComprada: 1.0,
        precioUmpProveedor: 30.0,
        totalPagoLote: 30.0,
        unidadesPorLote: 12,
        unidadVenta: 'Unidad',
        unidadesPorVenta: 1,
        costoUnitarioSugerido: 2.50,
        factorGananciaVentaSugerido: 1.35,
        precioVentaSugerido: 3.38,
        matchPresentacion: MatchResult(estado: 'NUEVO', confianza: 0),
      )..usaStockCompartido = true;

      final grpMix = StagingProductGroup(
        uuidTemporal: 'grp-mix-test',
        nombrePadre: 'Cuaderno Colors Univ',
        nombreOriginalFactura: 'Colors Univ 170 hojas 60gr',
        marcaTexto: 'Colors',
        matchProducto: MatchResult(estado: 'NUEVO', confianza: 0),
        matchMarca: MatchResult(estado: 'NUEVO', confianza: 0),
        variantes: [vMix1],
        modoStock: 'MIXTO',
        stockCompartido: 12,
        costoBase: 2.50,
      );

      // La primera variante del modo opuesto (Propio) se distingue con - Propio
      final nameMixPropio1 = provider.generateUniqueVariantName(grpMix, isShared: false);
      expect(nameMixPropio1, equals('Colors Univ 170 hojas 60gr - Propio'));

      final vMixPropio1 = StagingVariant(
        uuidTemporal: 'v-mix-prop-1',
        nombreEspecifico: nameMixPropio1,
        umpCompra: 'Caja',
        cantidadUmpComprada: 1.0,
        precioUmpProveedor: 50.0,
        totalPagoLote: 50.0,
        unidadesPorLote: 20,
        unidadVenta: 'Unidad',
        unidadesPorVenta: 1,
        costoUnitarioSugerido: 2.50,
        factorGananciaVentaSugerido: 1.35,
        precioVentaSugerido: 3.38,
        matchPresentacion: MatchResult(estado: 'NUEVO', confianza: 0),
      )..usaStockCompartido = false;
      grpMix.variantes.add(vMixPropio1);

      // La siguiente del modo opuesto incrementa su correlativo (- Propio 2)
      final nameMixPropio2 = provider.generateUniqueVariantName(grpMix, isShared: false);
      expect(nameMixPropio2, equals('Colors Univ 170 hojas 60gr - Propio 2'));

      // Y una variante adicional compartida se distingue con - Comp.
      final nameMixComp1 = provider.generateUniqueVariantName(grpMix, isShared: true);
      expect(nameMixComp1, equals('Colors Univ 170 hojas 60gr - Comp.'));
    });

    test('Test 10: En modo COMPARTIDO con 6 unid. base de factura, añadir 2.ª y 3.ª variante mantiene stockCompartido == 6 sin duplicar', () {
      final provider = ScannerProvider();

      // Producto Nuevo con compra de factura: 0.5 DOC x 12 = 6 unid. base, costo S/ 14.47
      final vMaestra = StagingVariant(
        uuidTemporal: 'v-maestra-comp',
        nombreEspecifico: 'Cuaderno Loro 100h',
        umpCompra: 'DOC',
        cantidadUmpComprada: 0.5,
        precioUmpProveedor: 28.94,
        totalPagoLote: 14.47,
        unidadesPorLote: 12,
        unidadVenta: 'Unidad',
        unidadesPorVenta: 1,
        costoUnitarioSugerido: 2.41,
        factorGananciaVentaSugerido: 1.35,
        precioVentaSugerido: 3.25,
        matchPresentacion: MatchResult(estado: 'NUEVO', confianza: 0),
      )..usaStockCompartido = true;

      final group = StagingProductGroup(
        uuidTemporal: 'grp-test-10',
        nombrePadre: 'Cuaderno Loro 100h',
        nombreOriginalFactura: 'Cuaderno Loro 100h',
        marcaTexto: 'Loro',
        matchProducto: MatchResult(estado: 'NUEVO', confianza: 0),
        matchMarca: MatchResult(estado: 'NUEVO', confianza: 0),
        variantes: [vMaestra],
        modoStock: 'COMPARTIDO',
        stockCompartido: 6,
        costoBase: 14.47 / 6,
      );

      final staging = StagingResponse(
        proveedorMatch: MatchResult(estado: 'NUEVO', confianza: 0),
        proveedorTexto: 'Distribuidora Loro',
        productosAgrupados: [group],
      );
      provider.setStagingDataForTesting(staging);

      expect(group.stockCompartido, equals(6));
      expect(group.costoBase, closeTo(2.411, 0.01));

      // Añadimos 2.ª variante compartida
      provider.addNewVariantToGroup(group.uuidTemporal);
      expect(group.variantes.length, equals(2));
      final vComp2 = group.variantes[1];
      expect(vComp2.usaStockCompartido, isTrue);

      // BLINDAJE: El stockCompartido del grupo SE MANTIENE en 6 (NO se duplica a 12)
      expect(group.stockCompartido, equals(6), reason: 'Añadir 2.ª presentación compartida no duplica el stock');
      expect(group.costoBase, closeTo(2.411, 0.01));

      // Añadimos 3.ª variante compartida
      provider.addNewVariantToGroup(group.uuidTemporal);
      expect(group.variantes.length, equals(3));
      final vComp3 = group.variantes[2];
      expect(vComp3.usaStockCompartido, isTrue);

      // Sigue manteniéndose en 6 (NO se triplica a 18)
      expect(group.stockCompartido, equals(6), reason: 'Añadir 3.ª presentación compartida no triplica el stock');

      // Sincronización explícita a 0ms de la variante maestra mantiene 6 unidades
      provider.syncGroupSharedPurchaseFromMasterVariant(group.uuidTemporal);
      expect(group.stockCompartido, equals(6));

      // Añadir variante en Stock Propio (usaStockCompartido = false) en MIXTO
      group.modoStock = 'MIXTO';
      provider.addNewVariantToGroup(group.uuidTemporal);
      expect(group.variantes.length, equals(4));
      final vPropio = group.variantes[3];
      vPropio.usaStockCompartido = false;

      // Hereda datos de factura para no mostrar campos en 0.00
      expect(vPropio.cantidadUmpComprada, equals(0.5));
      expect(vPropio.unidadesPorLote, equals(12));
      expect(vPropio.totalPagoLote, equals(14.47));
      expect(vPropio.stockIngresanteBase, equals(6));

      // El stock del pool compartido del grupo se mantiene inalterado en 6
      expect(group.stockCompartido, equals(6));
    });

    test('Test 11: Blindaje matemático en producto vinculado cuando sobrante > ingresoFactura y reversión completa', () {
      final provider = ScannerProvider();

      // Madre vinculada: Stock BD = 10 unidades base, Ingreso Factura = +1 unidad (totalPago = S/ 10.00)
      // Factor = 6 (½ Docena). Total base actual = 10 + 1 = 11 unidades base.
      // 11 % 6 = 5 sobrantes (¡sobrante 5 > ingreso 1!).
      final madre = StagingVariant(
        uuidTemporal: 'v-madre-sobrante-mayor',
        nombreEspecifico: 'Plumones 6 Colores',
        umpCompra: 'UND',
        cantidadUmpComprada: 1.0,
        precioUmpProveedor: 10.0,
        totalPagoLote: 10.0,
        unidadesPorLote: 1,
        unidadVenta: '½ Docena',
        unidadesPorVenta: 6,
        costoUnitarioSugerido: 60.0,
        factorGananciaVentaSugerido: 1.35,
        precioVentaSugerido: 81.0,
        matchPresentacion: MatchResult(
          estado: 'MATCH_EXACTO',
          confianza: 100,
          datos: MatchData(
            id: 88,
            nombre: 'Plumones 6 Colores',
            stockActual: 10,
            precioVentaFinal: 81.0,
            costoUnitarioCalculado: 60.0,
            unidadesPorLote: 1,
            unidadesPorVenta: 6,
            umpCompra: 'UND',
            unidadVenta: '½ Docena',
          ),
        ),
      );
      madre.stockOperation = 'sumar';

      final group = StagingProductGroup(
        uuidTemporal: 'grp-test-11',
        nombrePadre: 'Plumones 6 Colores',
        nombreOriginalFactura: 'Plumones 6 Colores',
        marcaTexto: 'Pelikan',
        matchProducto: MatchResult(
          estado: 'MATCH_MANUAL',
          confianza: 100,
          datos: MatchData(id: 44, nombre: 'Plumones 6 Colores', stockActual: 10),
        ),
        matchMarca: MatchResult(estado: 'NUEVO', confianza: 0),
        variantes: [madre],
        modoStock: 'INDEPENDIENTE',
      );

      final staging = StagingResponse(
        proveedorMatch: MatchResult(estado: 'NUEVO', confianza: 0),
        proveedorTexto: 'Pelikan Perú',
        productosAgrupados: [group],
      );
      provider.setStagingDataForTesting(staging);

      // Verificación antes de extraer:
      expect(madre.stockIngresanteBase, equals(1));
      expect(madre.calculateTotalUnitsBase(stockActualBD: 10), equals(11));
      expect(madre.calculateTotalUnitsBase(stockActualBD: 10) % 6, equals(5));
      expect(provider.hasUnresolvedStock, isTrue, reason: 'Alerta naranja activa por 5 unidades sobrantes');

      // Extraer las 5 unidades sobrantes hacia la variante 'Unidad (x1)'
      final childUuid = provider.createLeftoverVariant(madre.uuidTemporal, 5);
      expect(childUuid, isNotNull);
      expect(group.variantes.length, equals(2));

      final hija = group.variantes.firstWhere((v) => v.uuidTemporal == childUuid);

      // BLINDAJE MATEMÁTICO:
      // 1. La madre queda exactamente en 6 unidades base (1 ½ docena exacta)
      // Ajuste efectivo: stockIngresanteOverride = totalSinSobrante - stockBD = 6 - 10 = -4
      expect(madre.stockIngresanteOverride, equals(-4));
      expect(madre.calculateTotalUnitsBase(stockActualBD: 10), equals(6), reason: '10 BD + (-4) ingreso = 6 unidades base exactas');
      expect(madre.calculateTotalUnitsBase(stockActualBD: 10) % 6, equals(0), reason: '0 errores de stock en la madre');

      // 2. La hija recibe exactamente 5 unidades base
      expect(hija.stockIngresanteBase, equals(5));
      expect(hija.allocatedBaseUnits, equals(5));

      // 3. Conservación total de unidades base: 6 + 5 = 11
      final totalConservado = madre.calculateTotalUnitsBase(stockActualBD: 10) + hija.stockIngresanteBase;
      expect(totalConservado, equals(11));

      // 4. El error de stock en la madre queda completamente resuelto
      expect(provider.hasUnresolvedStock, isFalse);

      // 5. Reversión: Al eliminar la hija, se restaura el ingreso original de la madre (+1)
      provider.removeVariantByUuid(hija.uuidTemporal);

      expect(group.variantes.length, equals(1));
      expect(madre.stockIngresanteOverride, equals(1), reason: 'Restaura el ingreso original de +1');
      expect(madre.calculateTotalUnitsBase(stockActualBD: 10), equals(11));
      expect(madre.calculateTotalUnitsBase(stockActualBD: 10) % 6, equals(5));
      expect(provider.hasUnresolvedStock, isTrue, reason: 'Se reactiva la alerta naranja de 5 sobrantes');
    });
  });
}
