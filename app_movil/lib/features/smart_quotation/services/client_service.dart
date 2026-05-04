import 'dart:convert';
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
        final salesRows = await db.rawQuery('''
          SELECT v.*, (SELECT COUNT(id) FROM venta_items WHERE venta_id = v.id) as items_count 
          FROM ventas v 
          WHERE v.cliente_id = ? 
          ORDER BY v.fecha_venta DESC 
          LIMIT 5
        ''', [id]);
        clientData['ultimas_ventas'] = salesRows;
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
        'etiquetas': jsonEncode(clientData['etiquetas'] ?? []),
        'nivel_confianza': clientData['nivel_confianza'] ?? 'bueno',
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
      
      Map<String, dynamic> updateData = Map.from(clientData);
      if (updateData.containsKey('etiquetas') && updateData['etiquetas'] is List) {
        updateData['etiquetas'] = jsonEncode(updateData['etiquetas']);
      }
      
      await db.update('clientes', updateData, where: 'id = ?', whereArgs: [id]);
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

  Future<List<ClientModel>> getAllClients(int negocioId) async {
    try {
      final db = await dbHelper.database;
      final rows = await db.query('clientes', where: 'negocio_id = ?', whereArgs: [negocioId]);
      
      List<ClientModel> clients = [];
      for (var row in rows) {
        Map<String, dynamic> clientData = Map.from(row);
        int clientId = clientData['id'] as int;
        final salesRows = await db.rawQuery('''
          SELECT v.*, (SELECT COUNT(id) FROM venta_items WHERE venta_id = v.id) as items_count 
          FROM ventas v 
          WHERE v.cliente_id = ? 
          ORDER BY v.fecha_venta DESC 
          LIMIT 5
        ''', [clientId]);
        clientData['ultimas_ventas'] = salesRows;
        clientData['ultimos_pagos'] = await db.query('pagos', where: 'cliente_id = ?', whereArgs: [clientId], orderBy: 'fecha_pago DESC', limit: 5);
        clients.add(ClientModel.fromJson(clientData));
      }
      return clients;
    } catch (e) { return []; }
  }

  Future<List<LedgerItem>> getClientLedger(int clientId) async {
    try {
      final db = await dbHelper.database;
      List<LedgerItem> ledger = [];

      final sales = await db.query('ventas', where: 'cliente_id = ? AND is_archived = 0', whereArgs: [clientId]);
      final payments = await db.rawQuery('''
        SELECT p.*, c.numero_cuota 
        FROM pagos p 
        LEFT JOIN cuotas c ON p.cuota_id = c.id 
        WHERE p.cliente_id = ?
      ''', [clientId]);

      List<Map<String, dynamic>> combined = [];
      for (var s in sales) {
        combined.add({'id_ref': s['id'], 'tipo': 'cargo', 'fecha': s['fecha_venta'], 'monto': s['monto_total'], 'detalle': 'Venta #${s['id']}'});
      }
      for (var p in payments) {
        String detail = 'Pago en ${p['metodo_pago']}';
        if (p['metodo_pago'] == 'saldo_a_favor') detail = 'Pago con Saldo a Favor';
        
        if (p['nota'] != null && p['nota'].toString().isNotEmpty) {
           detail = '${p['nota']} (${p['metodo_pago']})';
        } else if (p['numero_cuota'] != null) {
           detail += ' (Cuota ${p['numero_cuota']} de Venta #${p['venta_id']})';
        } else if (p['cuota_id'] != null) {
           detail += ' (Cuota, Venta #${p['venta_id']})';
        } else if (p['venta_id'] != null) {
           detail += ' (Venta #${p['venta_id']})';
        }

        combined.add({'id_ref': p['id'], 'tipo': 'abono', 'fecha': p['fecha_pago'], 'monto': p['monto'], 'detalle': detail});
      }

      combined.sort((a, b) {
        DateTime dateA = DateTime.tryParse(a['fecha'] ?? "") ?? DateTime.fromMillisecondsSinceEpoch(0);
        DateTime dateB = DateTime.tryParse(b['fecha'] ?? "") ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateA.compareTo(dateB);
      });

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
      final rows = await db.query('ventas', where: 'cliente_id = ? AND estado_pago != ? AND is_archived = 0', whereArgs: [clientId, 'pagado'], orderBy: 'fecha_venta ASC');
      
      List<SaleModel> sales = [];
      for (var row in rows) {
        Map<String, dynamic> saleData = Map.from(row);
        int saleId = saleData['id'] as int;
        saleData['cuotas'] = await db.query('cuotas', where: 'venta_id = ?', whereArgs: [saleId], orderBy: 'numero_cuota ASC');
        sales.add(SaleModel.fromJson(saleData));
      }
      return sales;
    } catch (e) { return []; }
  }

  Future<void> recalculateClientDebt(int clientId) async {
    try {
      final db = await dbHelper.database;
      final debtsRows = await db.rawQuery('SELECT SUM(monto_total - monto_pagado) as debt FROM ventas WHERE cliente_id = ? AND estado_pago != ? AND is_archived = 0', [clientId, 'pagado']);
      double totalDeuda = 0.0;
      if (debtsRows.isNotEmpty && debtsRows.first['debt'] != null) {
        totalDeuda = (debtsRows.first['debt'] as num).toDouble();
      }
      if (totalDeuda < 0.02) totalDeuda = 0.0;
      await db.update('clientes', {'deuda_total': totalDeuda}, where: 'id = ?', whereArgs: [clientId]);
    } catch (e) {
      // Ignorar en caso de error
    }
  }

  Future<bool> updateInstallmentDueDate(int cuotaId, String newDate) async {
    try {
      final db = await dbHelper.database;
      await db.update('cuotas', {'fecha_vencimiento': newDate}, where: 'id = ?', whereArgs: [cuotaId]);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> registerPayment(int clientId, double amount, String method, int negocioId, int usuarioId, {int? ventaId, int? cuotaId, bool guardarVuelto = false, bool isAutomatic = false}) async {
    try {
      final db = await dbHelper.database;

      await db.transaction((txn) async {
        int remainingCents = (amount * 100).round();

        // Si se paga con saldo a favor, restar del cliente
        final clientRows = await txn.query('clientes', where: 'id = ?', whereArgs: [clientId], limit: 1);
        int cSaldoCents = 0;
        if (clientRows.isNotEmpty) {
           cSaldoCents = ((clientRows.first['saldo_a_favor'] as num).toDouble() * 100).round();
        }

        if (method == "saldo_a_favor") {
           cSaldoCents -= remainingCents; 
           if (cSaldoCents < 0) cSaldoCents = 0; 
        }

        // Obtener todas las ventas activas
        final ventas = await txn.query('ventas', where: 'cliente_id = ? AND estado_pago != ? AND is_archived = 0', whereArgs: [clientId, 'pagado'], orderBy: 'fecha_venta ASC');
        
        List<Map<String, dynamic>> cuotasPendientes = [];
        List<Map<String, dynamic>> ventasSinCuotas = [];

        for (var vRow in ventas) {
           int vId = vRow['id'] as int;
           final cuotas = await txn.query('cuotas', where: 'venta_id = ? AND estado != ?', whereArgs: [vId, 'pagado'], orderBy: 'numero_cuota ASC');
           if (cuotas.isNotEmpty) {
              for (var cRow in cuotas) {
                 var c = Map<String, dynamic>.from(cRow);
                 c['vRow'] = vRow; 
                 cuotasPendientes.add(c);
              }
           } else {
              ventasSinCuotas.add(vRow);
           }
        }

        // Priorizar cuotas (Cascada Inteligente)
        cuotasPendientes.sort((a, b) {
           int scoreA = 0;
           int scoreB = 0;
           if (cuotaId != null) {
              if (a['id'] == cuotaId) scoreA += 100;
              if (b['id'] == cuotaId) scoreB += 100;
           }
           if (ventaId != null) {
              if (a['venta_id'] == ventaId) scoreA += 10;
              if (b['venta_id'] == ventaId) scoreB += 10;
           }
           return scoreB.compareTo(scoreA); // Mayor score primero
        });

        // 1. Pagar cuotas
        for (var cRow in cuotasPendientes) {
           if (remainingCents <= 0) break;
           int cId = cRow['id'] as int;
           int vId = cRow['venta_id'] as int;
           int cMontoCents = ((cRow['monto'] as num).toDouble() * 100).round();
           int cPagadoCents = ((cRow['monto_pagado'] as num).toDouble() * 100).round();
           int cDeudaCents = cMontoCents - cPagadoCents;
           
           if (cDeudaCents > 0) {
              int abonoCents = remainingCents >= cDeudaCents ? cDeudaCents : remainingCents;
              remainingCents -= abonoCents;
              int newPagadoCents = cPagadoCents + abonoCents;
              String cStatus = (cMontoCents - newPagadoCents) <= 10 ? 'pagado' : 'parcial';
              
              await txn.update('cuotas', {'monto_pagado': newPagadoCents / 100.0, 'estado': cStatus}, where: 'id = ?', whereArgs: [cId]);
              await txn.insert('pagos', {'negocio_id': negocioId, 'creado_por_usuario_id': usuarioId, 'cliente_id': clientId, 'venta_id': vId, 'cuota_id': cId, 'monto': abonoCents / 100.0, 'metodo_pago': method, 'fecha_pago': DateTime.now().toIso8601String()});
           }
        }

        // 2. Pagar ventas sin cuotas
        ventasSinCuotas.sort((a, b) {
           int scoreA = (ventaId != null && a['id'] == ventaId) ? 100 : 0;
           int scoreB = (ventaId != null && b['id'] == ventaId) ? 100 : 0;
           return scoreB.compareTo(scoreA);
        });

        for (var vRow in ventasSinCuotas) {
           if (remainingCents <= 0) break;
           int vId = vRow['id'] as int;
           int vMontoCents = ((vRow['monto_total'] as num).toDouble() * 100).round();
           int vPagadoCents = ((vRow['monto_pagado'] as num).toDouble() * 100).round();
           int vDeudaCents = vMontoCents - vPagadoCents;
           
           if (vDeudaCents > 0) {
              int abonoCents = remainingCents >= vDeudaCents ? vDeudaCents : remainingCents;
              remainingCents -= abonoCents;
              int newPagadoCents = vPagadoCents + abonoCents;
              String vStatus = (vMontoCents - newPagadoCents) <= 10 ? 'pagado' : 'parcial';
              
              await txn.update('ventas', {'monto_pagado': newPagadoCents / 100.0, 'estado_pago': vStatus}, where: 'id = ?', whereArgs: [vId]);
              await txn.insert('pagos', {'negocio_id': negocioId, 'creado_por_usuario_id': usuarioId, 'cliente_id': clientId, 'venta_id': vId, 'monto': abonoCents / 100.0, 'metodo_pago': method, 'fecha_pago': DateTime.now().toIso8601String()});
           }
        }

        // 3. Sincronizar estado de ventas contenedoras
        for (var vRow in ventas) {
           int vId = vRow['id'] as int;
           final vCuotas = await txn.query('cuotas', where: 'venta_id = ?', whereArgs: [vId]);
           if (vCuotas.isNotEmpty) {
              int vTotalCents = ((vRow['monto_total'] as num).toDouble() * 100).round();
              int vNewPagadoCents = 0;
              for (var c in vCuotas) { vNewPagadoCents += ((c['monto_pagado'] as num).toDouble() * 100).round(); }
              String vStatus = (vTotalCents - vNewPagadoCents) <= 10 ? 'pagado' : 'parcial';
              await txn.update('ventas', {'monto_pagado': vNewPagadoCents / 100.0, 'estado_pago': vStatus}, where: 'id = ?', whereArgs: [vId]);
           }
        }

        // 4. Registrar excedentes y calcular saldo a favor final
        if (remainingCents > 0) {
           await txn.insert('pagos', {'negocio_id': negocioId, 'creado_por_usuario_id': usuarioId, 'cliente_id': clientId, 'monto': remainingCents / 100.0, 'metodo_pago': method, 'nota': 'Conversión a Saldo a favor', 'fecha_pago': DateTime.now().toIso8601String()});
           if (guardarVuelto && method != "saldo_a_favor") {
              cSaldoCents += remainingCents;
           }
        }

        if (clientRows.isNotEmpty) {
           await txn.update('clientes', {
             'saldo_a_favor': cSaldoCents / 100.0
           }, where: 'id = ?', whereArgs: [clientId]);
        }
      });
      
      // Asegurar reconciliación real después de cada pago
      await recalculateClientDebt(clientId);
      return true;
    } catch (e) { throw Exception("Error registrando pago localmente: $e"); }
  }
}