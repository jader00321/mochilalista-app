import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/utils/app_logger.dart';
import 'package:app_movil/features/smart_quotation/repositories/client_repository.dart';

class ClientService {
  final _repository = ClientRepository();
  final dbHelper = LocalDatabase.instance; // Mantenido solo para transacciones complejas inter-tabla

  Future<ClientModel?> getClientById(int id) async {
    try {
      final clientDataRaw = await _repository.getClientRawById(id);
      if (clientDataRaw != null) {
        final salesRows = await _repository.getClientSales(id);
        final paymentsRows = await _repository.getClientPayments(id);
        
        Map<String, dynamic> clientData = Map.from(clientDataRaw);
        clientData['ultimas_ventas'] = salesRows;
        clientData['ultimos_pagos'] = paymentsRows;
        return ClientModel.fromJson(clientData);
      }
      return null;
    } catch (e, stack) { 
      AppLogger.error('ClientService.getClientById', e, stack); 
      return null; 
    }
  }
  
  Future<List<ClientModel>> searchClients(String query, int negocioId) async {
    try {
      final rows = await _repository.searchClientsRaw(query, negocioId);
      return rows.map((e) => ClientModel.fromJson(e)).toList();
    } catch (e, stack) { 
      AppLogger.error('ClientService.searchClients', e, stack); 
      return []; 
    }
  }

  Future<List<ClientModel>> getRecentClients(int negocioId, {int limit = 5}) async {
    try {
      final rows = await _repository.getRecentClientsRaw(negocioId, limit: limit);
      return rows.map((e) => ClientModel.fromJson(e)).toList();
    } catch (e, stack) {
      AppLogger.error('ClientService.getRecentClients', e, stack);
      return [];
    }
  }

  Future<ClientModel> createClient(Map<String, dynamic> clientData, int negocioId, int usuarioId) async {
    try {
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
      int id = await _repository.insertClient(insertData);
      return (await getClientById(id))!;
    } catch (e) { throw Exception("Error creando cliente localmente: $e"); }
  }

  Future<ClientModel> updateClient(int id, Map<String, dynamic> clientData) async {
    try {
      Map<String, dynamic> updateData = Map.from(clientData);
      if (updateData.containsKey('etiquetas') && updateData['etiquetas'] is List) {
        updateData['etiquetas'] = jsonEncode(updateData['etiquetas']);
      }
      await _repository.updateClient(id, updateData);
      return (await getClientById(id))!;
    } catch (e) { throw Exception("Error actualizando cliente localmente: $e"); }
  }

  Future<bool> deleteClient(int id) async {
    return await _repository.deleteClient(id);
  }
  
  Future<List<ClientModel>> getTrackingClients(int negocioId, {bool debtorsOnly = false}) async {
    try {
      final rows = await _repository.getTrackingClientsRaw(negocioId, debtorsOnly: debtorsOnly);
      return rows.map((e) => ClientModel.fromJson(e)).toList();
    } catch (e) { return []; }
  }

  Future<List<ClientModel>> getAllClients(int negocioId) async {
    try {
      final rows = await _repository.getAllClientsRaw(negocioId);
      
      List<ClientModel> clients = [];
      for (var row in rows) {
        Map<String, dynamic> clientData = Map.from(row);
        int clientId = clientData['id'] as int;
        
        clientData['ultimas_ventas'] = await _repository.getClientSales(clientId);
        clientData['ultimos_pagos'] = await _repository.getClientPayments(clientId);
        
        clients.add(ClientModel.fromJson(clientData));
      }
      return clients;
    } catch (e) { return []; }
  }

  Future<List<LedgerItem>> getClientLedger(int clientId) async {
    try {
      final db = await dbHelper.database;
      List<LedgerItem> ledger = [];

      final sales = await db.rawQuery('''
        SELECT id, numero_secuencial, origen_venta, fecha_venta, monto_total
        FROM ventas 
        WHERE cliente_id = ? AND is_archived = 0
      ''', [clientId]);
      
      final payments = await db.rawQuery('''
        SELECT p.*, c.numero_cuota, v.origen_venta as pago_origen_venta, v.numero_secuencial as venta_numero_secuencial 
        FROM pagos p 
        LEFT JOIN cuotas c ON p.cuota_id = c.id 
        LEFT JOIN ventas v ON p.venta_id = v.id
        WHERE p.cliente_id = ? AND (v.is_archived IS NULL OR v.is_archived = 0)
      ''', [clientId]);

      List<Map<String, dynamic>> combined = [];
      for (var s in sales) {
        final displayId = s['numero_secuencial'] ?? s['id'];
        String label = s['origen_venta'] == 'prestamo_personal' 
            ? 'Préstamo #$displayId' 
            : 'Venta #$displayId';
        String subtipo = s['origen_venta'] == 'prestamo_personal' ? 'prestamo' : 'venta';
        combined.add({'id_ref': s['id'], 'tipo': 'cargo', 'subtipo': subtipo, 'fecha': s['fecha_venta'], 'monto': s['monto_total'], 'detalle': label, 'affects_debt': true});
      }
      for (var p in payments) {
        String detail = 'Pago en ${p['metodo_pago']}';
        String subtipo = 'pago';
        bool affectsDebt = true;
        
        // Si el pago no está vinculado a una venta (ej. Saldo a favor, abono desvinculado, retiro), no afecta la deuda histórica.
        if (p['venta_id'] == null || p['nota'] == 'Conversión a Saldo a favor' || p['metodo_pago'] == 'devolucion' || p['metodo_pago'] == 'retiro_saldo') {
          affectsDebt = false;
        }

        if (p['metodo_pago'] == 'saldo_a_favor') {
          detail = 'Pago con Saldo a Favor';
        } else if (p['metodo_pago'] == 'devolucion') {
          detail = p['nota']?.toString() ?? 'Devolución';
          subtipo = 'devolucion';
        } else if (p['metodo_pago'] == 'retiro_saldo') {
          detail = p['nota']?.toString() ?? 'Retiro de Saldo a favor';
          subtipo = 'retiro_saldo';
        }
        
        bool isLoan = p['pago_origen_venta'] == 'prestamo_personal';
        String entityName = isLoan ? 'Préstamo' : 'Venta';
        final displayVentaId = p['venta_numero_secuencial'] ?? p['venta_id'];
        
        if (p['nota'] != null && p['nota'].toString().isNotEmpty && p['metodo_pago'] != 'devolucion' && p['metodo_pago'] != 'retiro_saldo') {
           detail = '${p['nota']} (${p['metodo_pago']})';
           
           // 🔥 FASE 3: Identificar de qué venta es el Abono Inicial
           String notaLower = p['nota'].toString().toLowerCase();
           if (notaLower.contains('abono inicial') || notaLower.contains('pago adelantado') || notaLower.contains('conversión a saldo a favor')) {
             if (p['venta_id'] != null && !notaLower.contains('conversión a saldo a favor')) {
               detail += ' de $entityName #$displayVentaId';
             } else if (notaLower.contains('conversión a saldo a favor')) {
               detail = 'Conversión a Saldo a favor';
             }
           }
        } else if (p['numero_cuota'] != null && p['metodo_pago'] != 'devolucion' && p['metodo_pago'] != 'retiro_saldo') {
           detail += ' (Cuota ${p['numero_cuota']} de $entityName #$displayVentaId)';
        } else if (p['cuota_id'] != null && p['metodo_pago'] != 'devolucion' && p['metodo_pago'] != 'retiro_saldo') {
           detail += ' (Cuota, $entityName #$displayVentaId)';
        } else if (p['venta_id'] != null && p['metodo_pago'] != 'devolucion' && p['metodo_pago'] != 'retiro_saldo') {
           detail += ' ($entityName #$displayVentaId)';
        }

        combined.add({'id_ref': p['id'], 'tipo': 'abono', 'subtipo': subtipo, 'fecha': p['fecha_pago'], 'monto': p['monto'], 'detalle': detail, 'affects_debt': affectsDebt});
      }

      combined.sort((a, b) {
        DateTime dateA = DateTime.tryParse(a['fecha'] ?? "") ?? DateTime.fromMillisecondsSinceEpoch(0);
        DateTime dateB = DateTime.tryParse(b['fecha'] ?? "") ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateA.compareTo(dateB);
      });

      double runningBalance = 0.0;
      for (var item in combined) {
        double monto = (item['monto'] as num).toDouble();
        if (item['affects_debt'] == true) {
          if (item['tipo'] == 'cargo') { 
            runningBalance += monto; 
          } else { 
            runningBalance -= monto; 
          }
        }
        if (runningBalance < 0.01) runningBalance = 0.0;

        ledger.add(LedgerItem(
          idRef: item['id_ref'], tipo: item['tipo'], subtipo: item['subtipo'], fecha: DateTime.parse(item['fecha']),
          monto: monto, detalle: item['detalle'], saldoResultante: runningBalance
        ));
      }
      return ledger.reversed.toList(); 
    } catch (e) { return []; }
  }

  Future<List<SmartQuotationModel>> getPendingQuotations(int clientId) async {
    try {
      final db = await dbHelper.database;
      final rows = await db.query('smart_quotations', where: 'client_id = ? AND status != ? AND status != ? AND status != ?', whereArgs: [clientId, 'SOLD', 'ARCHIVED', 'ANNULLED'], orderBy: 'created_at DESC');
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
      
      // --- DATA HEALING: Reconstruir monto_pagado y abono_inicial desde la fuente de verdad (tabla pagos) ---
      await db.transaction((txn) async {
         final ventas = await txn.query('ventas', where: 'cliente_id = ? AND (is_archived IS NULL OR is_archived = 0)', whereArgs: [clientId]);
         for (var v in ventas) {
            int vId = v['id'] as int;
            double montoTotal = (v['monto_total'] as num).toDouble();
            
            // 1. Sanar cuotas
            final cuotas = await txn.query('cuotas', where: 'venta_id = ?', whereArgs: [vId]);
            double totalCuotasPagado = 0.0;
            for (var c in cuotas) {
               int cId = c['id'] as int;
               final pagosCuota = await txn.rawQuery('SELECT SUM(monto) as total FROM pagos WHERE cuota_id = ? AND venta_id = ? AND metodo_pago != ? AND metodo_pago != ?', [cId, vId, 'devolucion', 'retiro_saldo']);
               double pCuota = (pagosCuota.first['total'] as num?)?.toDouble() ?? 0.0;
               double cMonto = (c['monto'] as num).toDouble();
               
               int cMontoCents = (cMonto * 100).round();
               int pCuotaCents = (pCuota * 100).round();
               
               String cStatus = (cMontoCents - pCuotaCents) <= 10 ? 'pagado' : 'parcial';
               if (pCuotaCents == 0) cStatus = 'pendiente';
               
               await txn.update('cuotas', {'monto_pagado': pCuota, 'estado': cStatus}, where: 'id = ?', whereArgs: [cId]);
               totalCuotasPagado += pCuota;
            }
            
            // 2. Sanar pagos directos a la venta (abono inicial o ventas al contado)
            final pagosAbono = await txn.rawQuery('SELECT SUM(monto) as total FROM pagos WHERE venta_id = ? AND cuota_id IS NULL AND metodo_pago != ? AND metodo_pago != ?', [vId, 'devolucion', 'retiro_saldo']);
            double pAbono = (pagosAbono.first['total'] as num?)?.toDouble() ?? 0.0;
            
            double nuevoMontoPagado = totalCuotasPagado + pAbono;
            
            int vTotalCents = (montoTotal * 100).round();
            int vPagadoCents = (nuevoMontoPagado * 100).round();
            
            String vStatus = (vTotalCents - vPagadoCents) <= 10 ? 'pagado' : 'parcial';
            if (vPagadoCents == 0) vStatus = 'pendiente';
            
            String vEntrega = v['estado_entrega'] as String? ?? 'entregado';
            if (vStatus == 'pagado' && vEntrega == 'retenido_por_pago') {
               vEntrega = 'pendiente_recojo';
            }
            
            if (cuotas.isNotEmpty) {
               await txn.update('ventas', {'monto_pagado': nuevoMontoPagado, 'abono_inicial': pAbono, 'estado_pago': vStatus, 'estado_entrega': vEntrega}, where: 'id = ?', whereArgs: [vId]);
            } else {
               await txn.update('ventas', {'monto_pagado': nuevoMontoPagado, 'estado_pago': vStatus, 'estado_entrega': vEntrega}, where: 'id = ?', whereArgs: [vId]);
            }
         }
      });
      // ------------------------------------------------------------------------------------------------------

      final debtsRows = await db.rawQuery('''
        SELECT SUM(monto_total - monto_pagado) as debt 
        FROM ventas 
        WHERE cliente_id = ? AND estado_pago != ? AND is_archived = 0
      ''', [clientId, 'pagado']);
      double totalDeuda = 0.0;
      if (debtsRows.isNotEmpty && debtsRows.first['debt'] != null) {
        totalDeuda = (debtsRows.first['debt'] as num).toDouble();
      }
      if (totalDeuda < 0.02) totalDeuda = 0.0;
      await _repository.updateClient(clientId, {'deuda_total': totalDeuda});
    } catch (e) {
      // Ignorar en caso de error
    }
  }

  Future<void> recalculateClientSaldoAFavor(int clientId) async {
    try {
      final db = await dbHelper.database;
      final result = await db.rawQuery('''
        SELECT 
          SUM(CASE WHEN p.nota = 'Conversión a Saldo a favor' THEN p.monto ELSE 0 END) as excedentes,
          SUM(CASE WHEN p.metodo_pago = 'devolucion' THEN p.monto ELSE 0 END) as devoluciones,
          SUM(CASE WHEN p.metodo_pago = 'saldo_a_favor' AND (v.is_archived IS NULL OR v.is_archived = 0) THEN p.monto ELSE 0 END) as gastado,
          SUM(CASE WHEN p.metodo_pago = 'retiro_saldo' THEN p.monto ELSE 0 END) as retirado
        FROM pagos p
        LEFT JOIN ventas v ON p.venta_id = v.id
        WHERE p.cliente_id = ?
      ''', [clientId]);
      
      double nuevoSaldo = 0.0;
      if (result.isNotEmpty) {
         double excedentes = (result.first['excedentes'] as num?)?.toDouble() ?? 0.0;
         double devoluciones = (result.first['devoluciones'] as num?)?.toDouble() ?? 0.0;
         double gastado = (result.first['gastado'] as num?)?.toDouble() ?? 0.0;
         double retirado = (result.first['retirado'] as num?)?.toDouble() ?? 0.0;
         nuevoSaldo = excedentes + devoluciones - gastado - retirado;
         if (nuevoSaldo < 0) nuevoSaldo = 0.0;
      }
      
      await _repository.updateClient(clientId, {'saldo_a_favor': nuevoSaldo});
    } catch (e) {
      // Ignorar en caso de error
    }
  }

  Future<void> recalculateClientDeliveries(int clientId) async {
    try {
      final db = await dbHelper.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) as pendientes FROM ventas WHERE cliente_id = ? AND estado_entrega != ? AND is_archived = 0',
        [clientId, 'entregado']
      );
      int pendientes = 0;
      if (result.isNotEmpty && result.first['pendientes'] != null) {
        pendientes = result.first['pendientes'] as int;
      }
      await _repository.updateClient(clientId, {'entregas_pendientes': pendientes});
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

              if (cStatus == 'pagado') {
                 final cRows = await txn.query('clientes', columns: ['nombre_completo'], where: 'id = ?', whereArgs: [clientId], limit: 1);
                 String cName = cRows.isNotEmpty ? cRows.first['nombre_completo'] as String : "Cliente";
                 await txn.insert('notificaciones', {
                    'user_id': usuarioId,
                    'negocio_id': negocioId,
                    'titulo': "Cuota Pagada",
                    'mensaje': "El cliente $cName acaba de cancelar la cuota.",
                    'tipo': 'exito',
                    'prioridad': 'Media',
                    'leida': 0,
                    'objeto_relacionado_tipo': 'cuota',
                    'objeto_relacionado_id': cId,
                    'fecha_creacion': DateTime.now().toIso8601String()
                 });
              }
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
           double vMontoTotal = (vRow['monto_total'] as num).toDouble();
           
           // El monto_total ya incluye el interés desde la base de datos
           int vMontoCents = (vMontoTotal * 100).round();
           int vPagadoCents = ((vRow['monto_pagado'] as num).toDouble() * 100).round();
           int vDeudaCents = vMontoCents - vPagadoCents;
           
           if (vDeudaCents > 0) {
              int abonoCents = remainingCents >= vDeudaCents ? vDeudaCents : remainingCents;
              remainingCents -= abonoCents;
              int newPagadoCents = vPagadoCents + abonoCents;
              String vStatus = (vMontoCents - newPagadoCents) <= 10 ? 'pagado' : 'parcial';
              
              String vEntrega = vRow['estado_entrega'] as String? ?? 'entregado';
              if (vStatus == 'pagado' && vEntrega == 'retenido_por_pago') {
                 vEntrega = 'pendiente_recojo';
              }
              
              await txn.update('ventas', {'monto_pagado': newPagadoCents / 100.0, 'estado_pago': vStatus, 'estado_entrega': vEntrega}, where: 'id = ?', whereArgs: [vId]);
              await txn.insert('pagos', {'negocio_id': negocioId, 'creado_por_usuario_id': usuarioId, 'cliente_id': clientId, 'venta_id': vId, 'monto': abonoCents / 100.0, 'metodo_pago': method, 'fecha_pago': DateTime.now().toIso8601String()});
           }
        }

        // 3. Sincronizar estado de ventas contenedoras
        for (var vRow in ventas) {
           int vId = vRow['id'] as int;
           final vCuotas = await txn.query('cuotas', where: 'venta_id = ?', whereArgs: [vId]);
           if (vCuotas.isNotEmpty) {
              double vMontoTotal = (vRow['monto_total'] as num).toDouble();
              double abonoInicial = ((vRow['abono_inicial'] as num?) ?? 0.0).toDouble();
              
              // El monto_total ya incluye el interés desde la base de datos
              int vTotalCents = (vMontoTotal * 100).round();
              int vNewPagadoCents = (abonoInicial * 100).round();
              for (var c in vCuotas) { vNewPagadoCents += ((c['monto_pagado'] as num).toDouble() * 100).round(); }
              String vStatus = (vTotalCents - vNewPagadoCents) <= 10 ? 'pagado' : 'parcial';
              
              String vEntrega = vRow['estado_entrega'] as String? ?? 'entregado';
              if (vStatus == 'pagado' && vEntrega == 'retenido_por_pago') {
                 vEntrega = 'pendiente_recojo';
              }

              await txn.update('ventas', {'monto_pagado': vNewPagadoCents / 100.0, 'estado_pago': vStatus, 'estado_entrega': vEntrega}, where: 'id = ?', whereArgs: [vId]);
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
      
      // Asegurar reconciliación real después de cada pago (deuda y saldo a favor)
      await recalculateClientDebt(clientId);
      await recalculateClientSaldoAFavor(clientId);
      return true;
    } catch (e) { throw Exception("Error registrando pago localmente: $e"); }
  }

  Future<void> recalculateClientReputation(int clientId) async {
    try {
      final db = await dbHelper.database;
      
      final clientStats = await _repository.getClientCancellationStats(clientId);
      int totalVentas = clientStats['totalVentas'] ?? 0;
      double cancellationRate = clientStats['cancellationRate'] ?? 0.0;
      
      // Regla: Mínimo 3 ventas (historicas) para poder juzgar la reputación.
      if (totalVentas >= 3) {
        String newReputation = 'bueno';
        if (cancellationRate > 30.0) {
          newReputation = 'malo';
        } else if (cancellationRate > 15.0) {
          newReputation = 'regular';
        }
        
        await db.update(
          'clientes', 
          {'nivel_confianza': newReputation},
          where: 'id = ?',
          whereArgs: [clientId]
        );
      }
    } catch (e, stack) {
      AppLogger.error('ClientService.recalculateClientReputation', e, stack);
    }
  }

  Future<void> withdrawClientBalance(int clientId, int negocioId, int usuarioId, double amount, String method) async {
    final db = await dbHelper.database;
    await db.transaction((txn) async {
      await txn.insert('pagos', {
        'negocio_id': negocioId,
        'creado_por_usuario_id': usuarioId,
        'cliente_id': clientId,
        'venta_id': null,
        'monto': amount,
        'metodo_pago': 'retiro_saldo',
        'nota': 'Retiro de Saldo a favor ($method)',
        'fecha_pago': DateTime.now().toIso8601String(),
      });
    });
    await recalculateClientSaldoAFavor(clientId);
  }

  Future<void> registerLoan(int clientId, int negocioId, int usuarioId, {
    required double amount,
    required String motivo,
    double? interestRate,
    String? metodoPago,
    List<InstallmentModel>? installments,
  }) async {
    final db = await dbHelper.database;
    
    await db.transaction((txn) async {
      final nextSeqResult = await txn.rawQuery('SELECT COALESCE(MAX(numero_secuencial), 0) + 1 as next_val FROM ventas WHERE negocio_id = ?', [negocioId]);
      int sequentialId = (nextSeqResult.first['next_val'] as int?) ?? 1;

      // Monto total incluye interés. Si hay cuotas, priorizamos su suma exacta.
      double finalDebt = amount + (amount * (interestRate ?? 0) / 100);
      if (installments != null && installments.isNotEmpty) {
        finalDebt = installments.fold(0.0, (sum, cuota) => sum + cuota.amount);
      }

      // 1. Insertar "venta virtual" como préstamo
      int loanId = await txn.insert('ventas', {
        'numero_secuencial': sequentialId,
        'negocio_id': negocioId,
        'creado_por_usuario_id': usuarioId,
        'cliente_id': clientId,
        'origen_venta': 'prestamo_personal',
        'metodo_pago': metodoPago ?? 'Efectivo',
        'estado_pago': 'pendiente',
        'estado_entrega': 'entregado', // No hay entrega física
        'monto_total': finalDebt,
        'monto_pagado': 0.0,
        'nota_prestamo': motivo,
        'porcentaje_interes': interestRate ?? 0.0,
        'fecha_venta': DateTime.now().toIso8601String(),
      });

      // 2. Insertar cuotas generadas por el modal o cuota única por defecto
      if (installments != null && installments.isNotEmpty) {
        for (var cuota in installments) {
          await txn.insert('cuotas', {
            'venta_id': loanId,
            'numero_cuota': cuota.installmentNumber,
            'monto': cuota.amount,
            'monto_pagado': 0.0,
            'fecha_vencimiento': cuota.dueDate,
            'estado': 'pendiente',
          });
        }
      } else {
        final defaultDue = DateTime.now().add(const Duration(days: 30));
        await txn.insert('cuotas', {
          'venta_id': loanId,
          'numero_cuota': 1,
          'monto': finalDebt,
          'monto_pagado': 0.0,
          'fecha_vencimiento': DateFormat('yyyy-MM-dd').format(defaultDue),
          'estado': 'pendiente',
        });
      }
    });

    // 3. Recalcular deuda
    await recalculateClientDebt(clientId);
  }
}