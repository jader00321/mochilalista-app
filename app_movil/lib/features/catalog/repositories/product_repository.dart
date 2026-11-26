import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/database/product_queries.dart';
import 'package:app_movil/core/utils/app_logger.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/features/scanner/services/spanish_lemmatizer.dart';

part 'product_repository_queries.dart';
part 'product_repository_stock_audit.dart';
part 'product_repository_mutations.dart';

abstract class _ProductRepositoryBase {
  final _dbHelper = LocalDatabase.instance;

  /// Whitelists oficiales basados en el esquema canónico de SQLite (local_db.dart)
  static const Set<String> _kProductoColumns = {
    'id',
    'negocio_id',
    'categoria_id',
    'marca_id',
    'codigo_barras',
    'nombre',
    'descripcion',
    'imagen_url',
    'estado',
    'fecha_creacion',
    'fecha_actualizacion',
    'modo_stock',
    'stock_compartido',
    'costo_base',
  };

  static const Set<String> _kPresentacionColumns = {
    'id',
    'producto_id',
    'proveedor_id',
    'nombre_especifico',
    'descripcion',
    'imagen_url',
    'codigo_barras',
    'ump_compra',
    'precio_ump_proveedor',
    'cantidad_ump_comprada',
    'total_pago_lote',
    'unidades_por_lote',
    'factura_carga_id',
    'unidad_venta',
    'unidades_por_venta',
    'costo_unitario_calculado',
    'factor_ganancia_venta',
    'precio_venta_final',
    'precio_oferta',
    'tipo_descuento',
    'valor_descuento',
    'stock_actual',
    'estado',
    'stock_alerta',
    'es_default',
    'orden',
    'activo',
    'usa_stock_compartido',
    'cupo_maximo_variante',
  };

  Future<void> _recordInitialDiscountTxn(
    dynamic txnOrDb,
    int presentationId,
    Map<String, dynamic> data,
  );

  Future<int> _updatePresentationTxn(
    dynamic txn,
    int id,
    Map<String, dynamic> data,
  );
}

class ProductRepository extends _ProductRepositoryBase
    with
        _ProductRepositoryQueriesMixin,
        _ProductRepositoryStockAuditMixin,
        _ProductRepositoryMutationsMixin {}
