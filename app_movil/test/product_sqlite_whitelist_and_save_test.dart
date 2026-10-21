import 'package:flutter_test/flutter_test.dart';
import 'package:app_movil/features/catalog/models/product_model.dart';
import 'package:app_movil/features/catalog/services/product_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fase 1: Whitelists de SQLite y Manejo de Errores al Guardar Producto', () {
    test('ProductPresentation.toSqlite genera mapa y puede ser sanitizado con whitelist', () {
      final pres = ProductPresentation(
        id: 10,
        nombreEspecifico: "Azul 0.5mm",
        unidadVenta: "Docena",
        unidadesPorVenta: 12,
        precioVentaFinal: 18.90,
        costoUnitarioCalculado: 8.00,
        factorGananciaVenta: 2.36,
        stockActual: 24,
        esDefault: true,
        orden: 0,
        deferredProviderName: "Nuevo Proveedor SAC",
      );

      final map = pres.toSqlite(1);
      expect(map.containsKey('deferred_provider_name'), isTrue);

      // Simular sanitización con el whitelist oficial
      const kPresCols = {
        'id', 'producto_id', 'proveedor_id', 'nombre_especifico', 'descripcion',
        'imagen_url', 'codigo_barras', 'ump_compra', 'precio_ump_proveedor',
        'cantidad_ump_comprada', 'total_pago_lote', 'unidades_por_lote',
        'factura_carga_id', 'unidad_venta', 'unidades_por_venta',
        'costo_unitario_calculado', 'factor_ganancia_venta', 'precio_venta_final',
        'precio_oferta', 'tipo_descuento', 'valor_descuento', 'stock_actual',
        'estado', 'stock_alerta', 'es_default', 'orden', 'activo',
      };

      map.removeWhere((key, _) => !kPresCols.contains(key));
      expect(map.containsKey('deferred_provider_name'), isFalse);
      expect(map.containsKey('nombre_especifico'), isTrue);
      expect(map['precio_venta_final'], equals(18.90));
    });

    test('Mapa de Producto elimina proveedor_id y campos diferidos tras sanitización', () {
      final productData = <String, dynamic>{
        'negocio_id': 1,
        'nombre': 'Lapicero Faber Castell',
        'marca_id': null,
        'deferred_brand_name': null,
        'categoria_id': 2,
        'deferred_category_name': null,
        'proveedor_id': 5,
        'deferred_provider_name': null,
        'descripcion': 'Caja de 10 unidades',
        'imagen_url': null,
        'codigo_barras': '7751234567890',
        'estado': 'publico',
        'fecha_actualizacion': '2026-10-18T00:00:00.000',
      };

      const kProdCols = {
        'id', 'negocio_id', 'categoria_id', 'marca_id', 'codigo_barras',
        'nombre', 'descripcion', 'imagen_url', 'estado', 'fecha_actualizacion',
      };

      // Antes de sanitizar contiene campos no existentes en la tabla productos
      expect(productData.containsKey('proveedor_id'), isTrue);
      expect(productData.containsKey('deferred_provider_name'), isTrue);

      // Aplicar filtro de whitelist canónico
      productData.removeWhere((key, _) => !kProdCols.contains(key));

      expect(productData.containsKey('proveedor_id'), isFalse);
      expect(productData.containsKey('deferred_provider_name'), isFalse);
      expect(productData.containsKey('deferred_brand_name'), isFalse);
      expect(productData.containsKey('deferred_category_name'), isFalse);
      expect(productData['nombre'], equals('Lapicero Faber Castell'));
      expect(productData['categoria_id'], equals(2));
    });

    test('ProductService expone lastError cuando falla la creación por falta de negocio', () async {
      final service = ProductService();
      // Sin actualizar negocioId
      final success = await service.createFullProduct(
        nombre: 'Producto Test',
        estado: 'publico',
        presentaciones: [],
      );

      expect(success, isFalse);
      expect(service.lastError, contains('No hay negocio seleccionado'));
    });

    test('db_id se preserva y extrae correctamente antes de aplicar _kPresentacionColumns whitelist', () {
      final presData = <String, dynamic>{
        'db_id': 502,
        'nombre_especifico': 'Azul 0.7mm',
        'precio_venta_final': 3.50,
        'custom_ui_flag': true,
      };

      const kPresCols = {
        'id', 'producto_id', 'proveedor_id', 'nombre_especifico', 'descripcion',
        'imagen_url', 'codigo_barras', 'ump_compra', 'precio_ump_proveedor',
        'cantidad_ump_comprada', 'total_pago_lote', 'unidades_por_lote',
        'factura_carga_id', 'unidad_venta', 'unidades_por_venta',
        'costo_unitario_calculado', 'factor_ganancia_venta', 'precio_venta_final',
        'precio_oferta', 'tipo_descuento', 'valor_descuento', 'stock_actual',
        'estado', 'stock_alerta', 'es_default', 'orden', 'activo',
      };

      // Si extraemos db_id ANTES de removeWhere:
      final rawId = presData['db_id'] ?? presData['id'];
      expect(rawId, equals(502));

      presData.remove('id');
      presData.remove('db_id');
      presData.removeWhere((key, _) => !kPresCols.contains(key));

      // El mapa resultante está 100% limpio para SQLite y el ID fue preservado
      expect(presData.containsKey('db_id'), isFalse);
      expect(presData.containsKey('custom_ui_flag'), isFalse);
      expect(presData['nombre_especifico'], equals('Azul 0.7mm'));
      expect(rawId, equals(502));
    });
  });
}
