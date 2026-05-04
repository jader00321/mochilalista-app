import '../database/local_db.dart';
import '../models/product_model.dart';
import '../models/inventory_wrapper.dart';
import 'image_service.dart';

class ProductService {
  int? _negocioId;
  
  void updateContext(int? negocioId) => _negocioId = negocioId;
  
  final dbHelper = LocalDatabase.instance;

  Future<List<InventoryWrapper>?> fetchInventory(Map<String, dynamic> queryParams) async {
    if (_negocioId == null) return null;
    try {
      final db = await dbHelper.database;
      
      String query = '''
        SELECT p.*, pr.id AS pres_id, pr.nombre_especifico, pr.descripcion AS pres_desc, pr.imagen_url AS pres_img,
        pr.codigo_barras AS pres_cb, pr.proveedor_id AS pres_prov, pr.ump_compra, pr.precio_ump_proveedor,
        pr.cantidad_ump_comprada, pr.total_pago_lote, pr.unidades_por_lote, pr.factura_carga_id,
        pr.unidad_venta, pr.unidades_por_venta, pr.costo_unitario_calculado, pr.factor_ganancia_venta,
        pr.precio_venta_final, pr.stock_actual, pr.stock_alerta, pr.es_default, pr.precio_oferta,
        pr.tipo_descuento, pr.valor_descuento, pr.estado AS pres_estado, pr.activo AS pres_activo
        FROM presentaciones_producto pr
        INNER JOIN productos p ON pr.producto_id = p.id
        WHERE p.negocio_id = ? AND pr.activo = 1
      ''';
      
      List<dynamic> args = [_negocioId];

      if (queryParams['q'] != null && queryParams['q'].toString().isNotEmpty) {
        query += " AND (p.nombre LIKE ? OR pr.codigo_barras LIKE ? OR p.codigo_barras LIKE ?)";
        args.addAll(['%${queryParams['q']}%', '%${queryParams['q']}%', '%${queryParams['q']}%']);
      }
      if (queryParams['estado'] != null) {
        query += " AND pr.estado = ?";
        args.add(queryParams['estado']);
      }
      if (queryParams['category_ids'] != null && queryParams['category_ids'].toString().isNotEmpty) {
        List<String> catIdsStr = queryParams['category_ids'].toString().split(',');
        query += " AND p.categoria_id IN (${List.filled(catIdsStr.length, '?').join(',')})";
        args.addAll(catIdsStr.map((id) => int.tryParse(id.trim()) ?? -1));
      }
      if (queryParams['brand_ids'] != null && queryParams['brand_ids'].toString().isNotEmpty) {
        List<String> brandIdsStr = queryParams['brand_ids'].toString().split(',');
        query += " AND p.marca_id IN (${List.filled(brandIdsStr.length, '?').join(',')})";
        args.addAll(brandIdsStr.map((id) => int.tryParse(id.trim()) ?? -1));
      }
      if (queryParams['has_offer'] == 'true') {
        query += " AND pr.precio_oferta IS NOT NULL AND pr.precio_oferta > 0";
      }
      if (queryParams['only_defaults'] == 'true') {
        query += " AND pr.es_default = 1";
      }

      query += " ORDER BY p.nombre ASC LIMIT ? OFFSET ?";
      args.add(int.parse(queryParams['limit'] ?? '20'));
      args.add(int.parse(queryParams['skip'] ?? '0'));

      final List<Map<String, dynamic>> rows = await db.rawQuery(query, args);

      return rows.map((row) {
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
        return InventoryWrapper(product: Product.fromJson(productJson), presentation: ProductPresentation.fromJson(presJson));
      }).toList();

    } catch (e) { print("Error Fetch Inventory Local: $e"); return null;}
  }

  Future<Product?> fetchProductById(int productId) async {
    try {
      final db = await dbHelper.database;
      final pRows = await db.query('productos', where: 'id = ?', whereArgs: [productId]);
      if (pRows.isEmpty) return null;

      final prRows = await db.query('presentaciones_producto', where: 'producto_id = ? AND activo = 1', whereArgs: [productId]);
      
      Map<String, dynamic> fullJson = Map.from(pRows.first);
      fullJson['presentaciones'] = prRows;
      
      return Product.fromJson(fullJson);
    } catch (e) { return null;}
  }

  Future<bool> deleteProduct(int id) async {
    try {
      final db = await dbHelper.database;
      final prod = await db.query('productos', columns: ['imagen_url'], where: 'id = ?', whereArgs: [id]);
      if (prod.isNotEmpty && prod.first['imagen_url'] != null) await ImageService.deleteLocalImage(prod.first['imagen_url'] as String);
      
      final pres = await db.query('presentaciones_producto', columns: ['imagen_url'], where: 'producto_id = ?', whereArgs: [id]);
      for (var p in pres) {
        if (p['imagen_url'] != null) await ImageService.deleteLocalImage(p['imagen_url'] as String);
      }

      await db.delete('productos', where: 'id = ?', whereArgs: [id]); 
      return true;
    } catch (e) { return false; }
  }

  Future<bool> createFullProduct({
    required String nombre, int? marcaId, required int categoriaId, int? proveedorId, 
    required String estado, String? descripcion, String? imagenUrl, String? codigoBarras, 
    required List<ProductPresentation> presentaciones
  }) async {
    if (_negocioId == null) return false;
    try {
      final db = await dbHelper.database;
      String? finalParentUrl = await ImageService.processAndSaveImage(imagenUrl);

      // 🔥 REPLICACIÓN EXACTA: Uso de Transaction para integridad de datos (Evita datos corruptos)
      await db.transaction((txn) async {
        int pId = await txn.insert('productos', {
          'negocio_id': _negocioId, 'nombre': nombre, 'marca_id': marcaId, 'categoria_id': categoriaId,
          'descripcion': descripcion, 'imagen_url': finalParentUrl, 'codigo_barras': codigoBarras,
          'estado': estado, 'fecha_actualizacion': DateTime.now().toIso8601String()
        });

        for (var pres in presentaciones) {
          String? finalPresUrl = await ImageService.processAndSaveImage(pres.imagenUrl);
          Map<String, dynamic> sqliteMap = pres.toSqlite(pId);
          sqliteMap['imagen_url'] = finalPresUrl;
          sqliteMap.remove('id');
          if (sqliteMap['proveedor_id'] == null) sqliteMap['proveedor_id'] = proveedorId;
          await txn.insert('presentaciones_producto', sqliteMap);
        }
      });
      return true;
    } catch (e) { 
      print("Error createFullProduct: $e");
      return false; 
    }
  }

  Future<bool> editFullProduct({
    required int productId, required String nombre, int? marcaId, required int categoriaId, 
    int? proveedorId, required String estado, String? descripcion, String? imagenUrl, String? codigoBarras, 
    required List<ProductPresentation> presentaciones, required List<int> idsToDelete
  }) async {
    try {
      final db = await dbHelper.database;
      
      final oldProd = await db.query('productos', columns: ['imagen_url'], where: 'id = ?', whereArgs: [productId]);
      String? finalParentUrl = await ImageService.processAndSaveImage(imagenUrl, oldImagePath: oldProd.first['imagen_url'] as String?);

      // 🔥 REPLICACIÓN EXACTA: Transacción para borrar, actualizar e insertar variantes sin riesgo
      await db.transaction((txn) async {
        await txn.update('productos', {
          'nombre': nombre, 'marca_id': marcaId, 'categoria_id': categoriaId, 'descripcion': descripcion, 
          'imagen_url': finalParentUrl, 'codigo_barras': codigoBarras, 'estado': estado, 
          'fecha_actualizacion': DateTime.now().toIso8601String()
        }, where: 'id = ?', whereArgs: [productId]);
        
        for (int id in idsToDelete) {
           final oldP = await txn.query('presentaciones_producto', columns: ['imagen_url'], where: 'id = ?', whereArgs: [id]);
           if (oldP.isNotEmpty && oldP.first['imagen_url'] != null) await ImageService.deleteLocalImage(oldP.first['imagen_url'] as String);
           await txn.delete('presentaciones_producto', where: 'id = ?', whereArgs: [id]);
        }
        
        for (var pres in presentaciones) {
          if (pres.id != null) {
            final oldP = await txn.query('presentaciones_producto', columns: ['imagen_url'], where: 'id = ?', whereArgs: [pres.id]);
            String? finalPresUrl = await ImageService.processAndSaveImage(pres.imagenUrl, oldImagePath: oldP.isNotEmpty ? oldP.first['imagen_url'] as String? : null);
            
            Map<String, dynamic> updateMap = pres.toSqlite(productId);
            updateMap['imagen_url'] = finalPresUrl;
            if (updateMap['proveedor_id'] == null) updateMap['proveedor_id'] = proveedorId;

            await txn.update('presentaciones_producto', updateMap, where: 'id = ?', whereArgs: [pres.id]);
          } else {
            String? finalPresUrl = await ImageService.processAndSaveImage(pres.imagenUrl);
            Map<String, dynamic> insertMap = pres.toSqlite(productId);
            insertMap['imagen_url'] = finalPresUrl;
            insertMap.remove('id');
            if (insertMap['proveedor_id'] == null) insertMap['proveedor_id'] = proveedorId;

            await txn.insert('presentaciones_producto', insertMap);
          }
        }
      });
      return true;
    } catch (e) { 
      print("Error editFullProduct: $e");
      return false; 
    }
  }

  Future<bool> updatePresentation(int presentationId, Map<String, dynamic> body) async {
    try {
      final db = await dbHelper.database;
      await db.update('presentaciones_producto', body, where: 'id = ?', whereArgs: [presentationId]);
      return true;
    } catch (e) { return false; }
  }
}