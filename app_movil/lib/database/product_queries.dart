import '../models/product_model.dart';
import '../models/inventory_wrapper.dart';

class ProductQueries {
  static const String selectInventoryCols = '''
    SELECT p.*, m.nombre AS marca_nombre, pr.id AS pres_id, pr.nombre_especifico, pr.descripcion AS pres_desc, pr.imagen_url AS pres_img,
    pr.codigo_barras AS pres_cb, pr.proveedor_id AS pres_prov, pr.ump_compra, pr.precio_ump_proveedor,
    pr.cantidad_ump_comprada, pr.total_pago_lote, pr.unidades_por_lote, pr.factura_carga_id,
    pr.unidad_venta, pr.unidades_por_venta, pr.costo_unitario_calculado, pr.factor_ganancia_venta,
    pr.precio_venta_final, pr.stock_actual, pr.stock_alerta, pr.es_default, pr.precio_oferta,
    pr.tipo_descuento, pr.valor_descuento, pr.estado AS pres_estado, pr.activo AS pres_activo
    FROM presentaciones_producto pr
    INNER JOIN productos p ON pr.producto_id = p.id
    LEFT JOIN marcas m ON p.marca_id = m.id
  ''';

  static const String baseInventoryWhere = 'WHERE p.negocio_id = ? AND pr.activo = 1';
  
  static const String fullInventoryQuery = '$selectInventoryCols $baseInventoryWhere';

  static InventoryWrapper parseInventoryRow(Map<String, dynamic> row) {
    Map<String, dynamic> productJson = Map<String, dynamic>.from(row);
    Map<String, dynamic> presJson = {
      'id': row['pres_id'], 'nombre_especifico': row['nombre_especifico'], 'descripcion': row['pres_desc'],
      'imagen_url': row['pres_img'], 'codigo_barras': row['pres_cb'], 'proveedor_id': row['pres_prov'],
      'ump_compra': row['ump_compra'], 'precio_ump_proveedor': row['precio_ump_proveedor'],
      'cantidad_ump_comprada': row['cantidad_ump_comprada'], 'total_pago_lote': row['total_pago_lote'],
      'unidades_por_lote': row['unidades_por_lote'], 'factura_carga_id': row['factura_carga_id'],
      'unidad_venta': row['unidad_venta'], 'unidades_por_venta': row['unidades_por_venta'],
      'costo_unitario_calculado': row['costo_unitario_calculado'], 'factor_ganancia_venta': row['factor_ganancia_venta'],
      'precio_venta_final': row['precio_venta_final'], 'stock_actual': row['stock_actual'],
      'stock_alerta': row['stock_alerta'], 'es_default': row['es_default'], 'precio_oferta': row['precio_oferta'],
      'tipo_descuento': row['tipo_descuento'], 'valor_descuento': row['valor_descuento'],
      'estado': row['pres_estado'], 'activo': row['pres_activo'],
    };
    return InventoryWrapper(
      product: Product.fromJson(productJson), 
      presentation: ProductPresentation.fromJson(presJson)
    );
  }
}
