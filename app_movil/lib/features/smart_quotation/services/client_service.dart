import '../models/crm_models.dart';
import '../models/smart_quotation_model.dart';
import '../../../database/local_db.dart';

class ClientService {
  final dbHelper = LocalDatabase.instance;

  Future<ClientModel?> getClientById(int id) async {
    try {
      final db = await dbHelper.database;
      final rows = await db.query('clientes', where: 'id = ?', whereArgs: [id], limit: 1);
      if (rows.isNotEmpty) {
        Map<String, dynamic> clientData = Map.from(rows.first);
        clientData['ultimas_ventas'] = await db.query('ventas', where: 'cliente_id = ?', whereArgs: [id], orderBy: 'fecha_venta DESC', limit: 5);
        clientData['ultimos_pagos'] = await db.query('pagos', where: 'cliente_id = ?', whereArgs: [id], orderBy: 'fecha_pago DESC', limit: 5);
        return ClientModel.fromJson(clientData);
      }
      return null;
    } catch (e) { return null; }
  }
  
  Future<List<ClientModel>> searchClients(String query, int negocioId) async {
    try {
      final db = await dbHelper.database;
      final rows = await db.query(
        'clientes', 
        where: 'negocio_id = ? AND (nombre_completo LIKE ? OR dni_ruc LIKE ? OR telefono LIKE ?)', 
        whereArgs: [negocioId, '%$query%', '%$query%', '%$query%'],
        limit: 20
      );
      return rows.map((e) => ClientModel.fromJson(e)).toList();
    } catch (e) { return []; }
  }

  Future<ClientModel> createClient(Map<String, dynamic> clientData, int negocioId, int usuarioId) async {
    try {
      final db = await dbHelper.database;
      Map<String, dynamic> insertData = {
        'negocio_id': negocioId,
        'creado_por_usuario_id': usuarioId,
        'nombre_completo': clientData['nombre_completo'],
        'telefono': clientData['telefono'] ?? '',
        'dni_ruc': clientData['dni_ruc'],
        'direccion': clientData['direccion'],
        'correo': clientData['correo'],
        'notas': clientData['notas'],
        'deuda_total': 0.0, 'saldo_a_favor': 0.0, 'entregas_pendientes': 0,
        'fecha_registro': DateTime.now().toIso8601String()
      };
      int id = await db.insert('clientes', insertData);
      return (await getClientById(id))!;
    } catch (e) { throw Exception("Error creando cliente localmente: $e"); }
  }

  Future<ClientModel> updateClient(int id, Map<String, dynamic> clientData) async {
    try {
      final db = await dbHelper.database;
      await db.update('clientes', clientData, where: 'id = ?', whereArgs: [id]);
      return (await getClientById(id))!;
    } catch (e) { throw Exception("Error actualizando cliente localmente: $e"); }
  }
  
  Future<List<ClientModel>> getTrackingClients(int negocioId, {bool debtorsOnly = false}) async {
    try {
      final db = await dbHelper.database;
      String whereClause = debtorsOnly ? 'negocio_id = ? AND deuda_total > 0' : 'negocio_id = ? AND (deuda_total > 0 OR entregas_pendientes > 0)';
      final rows = await db.query('clientes', where: whereClause, whereArgs: [negocioId]);
      return rows.map((e) => ClientModel.fromJson(e)).toList();
    } catch (e) { return []; }
  }

  Future<List<LedgerItem>> getClientLedger(int clientId) async {
    try {
      final db = await dbHelper.database;
      List<LedgerItem> ledger = [];

      final sales = await db.query('ventas', where: 'cliente_id = ? AND is_archived = 0', whereArgs: [clientId]);
      final payments = await db.query('pagos', where: 'cliente_id = ?', whereArgs: [clientId]);

      List<Map<String, dynamic>> combined = [];
      for (var s in sales) {
        combined.add({'id_ref': s['id'], 'tipo': 'cargo', 'fecha': s['fecha_venta'], 'monto': s['monto_total'], 'detalle': 'Venta #${s['id']}'});
      }
      for (var p in payments) {
        combined.add({'id_ref': p['id'], 'tipo': 'abono', 'fecha': p['fecha_pago'], 'monto': p['monto'], 'detalle': 'Pago en ${p['metodo_pago']}'});
      }

      combined.sort((a, b) => DateTime.parse(a['fecha']).compareTo(DateTime.parse(b['fecha'])));

      double runningBalance = 0.0;
      for (var item in combined) {
        double monto = (item['monto'] as num).toDouble();
        if (item['tipo'] == 'cargo') { runningBalance += monto; } else { runningBalance -= monto; }
        ledger.add(LedgerItem(
          idRef: item['id_ref'], tipo: item['tipo'], fecha: DateTime.parse(item['fecha']),
          monto: monto, detalle: item['detalle'], saldoResultante: runningBalance
        ));
      }
      return ledger.reversed.toList(); 
    } catch (e) { return []; }
  }

  Future<List<SmartQuotationModel>> getPendingQuotations(int clientId) async {
    try {
      final db = await dbHelper.database;
      final rows = await db.query('smart_quotations', where: 'client_id = ? AND status != ? AND status != ?', whereArgs: [clientId, 'SOLD', 'ARCHIVED'], orderBy: 'created_at DESC');
      return rows.map((e) => SmartQuotationModel.fromJson(e)).toList();
    } catch (e) { return []; }
  }

  Future<List<SaleModel>> getClientDebts(int clientId) async {
    try {
      final db = await dbHelper.database;
      final rows = await db.query('ventas', where: 'cliente_id = ? AND estado_pago != ? AND is_archived = 0', whereArgs: [clientId, 'pagado']);
      return rows.map((e) => SaleModel.fromJson(e)).toList();
    } catch (e) { return []; }
  }

  Future<bool> registerPayment(int clientId, double amount, String method, int negocioId, int usuarioId, {int? ventaId, int? cuotaId, bool guardarVuelto = false}) async {
    try {
      final db = await dbHelper.database;

      // 🔥 Transacción Segura de Pagos (Evita desajustes financieros)
      await db.transaction((txn) async {
        await txn.insert('pagos', {
          'negocio_id': negocioId, 'creado_por_usuario_id': usuarioId, 'cliente_id': clientId,
          'venta_id': ventaId, 'cuota_id': cuotaId, 'monto': amount, 'metodo_pago': method,
          'fecha_pago': DateTime.now().toIso8601String()
        });

        if (ventaId != null) {
          final vRows = await txn.query('ventas', where: 'id = ?', whereArgs: [ventaId], limit: 1);
          if (vRows.isNotEmpty) {
            double newPagado = (vRows.first['monto_pagado'] as num).toDouble() + amount;
            String newStatus = newPagado >= (vRows.first['monto_total'] as num).toDouble() ? 'pagado' : 'parcial';
            await txn.update('ventas', {'monto_pagado': newPagado, 'estado_pago': newStatus}, where: 'id = ?', whereArgs: [ventaId]);
          }
        }

        if (cuotaId != null) {
           final cRows = await txn.query('cuotas', where: 'id = ?', whereArgs: [cuotaId], limit: 1);
           if (cRows.isNotEmpty) {
              double cNewPagado = (cRows.first['monto_pagado'] as num).toDouble() + amount;
              String cNewStatus = cNewPagado >= (cRows.first['monto'] as num).toDouble() ? 'pagado' : 'parcial';
              await txn.update('cuotas', {'monto_pagado': cNewPagado, 'estado': cNewStatus}, where: 'id = ?', whereArgs: [cuotaId]);
           }
        }

        final clientRows = await txn.query('clientes', where: 'id = ?', whereArgs: [clientId], limit: 1);
        if (clientRows.isNotEmpty) {
           double nuevaDeuda = (clientRows.first['deuda_total'] as num).toDouble() - amount;
           await txn.update('clientes', {'deuda_total': nuevaDeuda < 0 ? 0.0 : nuevaDeuda}, where: 'id = ?', whereArgs: [clientId]);
           
           if (guardarVuelto && nuevaDeuda < 0) {
             double saldoExistente = (clientRows.first['saldo_a_favor'] as num).toDouble();
             await txn.update('clientes', {'saldo_a_favor': saldoExistente + (nuevaDeuda * -1)}, where: 'id = ?', whereArgs: [clientId]);
           }
        }
      });
      return true;
    } catch (e) { throw Exception("Error registrando pago localmente: $e"); }
  }
}