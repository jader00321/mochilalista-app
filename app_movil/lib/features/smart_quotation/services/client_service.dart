import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/models/smart_quotation_model.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/utils/app_logger.dart';
import 'package:app_movil/core/utils/smart_search_matcher.dart';
import 'package:app_movil/features/smart_quotation/repositories/client_repository.dart';
import 'package:app_movil/features/smart_quotation/services/sales_service.dart';

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
        'puntos_actuales': clientData['puntos_actuales'] ?? 0,
        'puntos_historicos': clientData['puntos_historicos'] ?? 0,
        'racha_pagos_puntuales': clientData['racha_pagos_puntuales'] ?? 0,
        'score_reputacion': clientData['score_reputacion'] ?? 500,
        'nivel_reputacion': clientData['nivel_reputacion'] ?? 'PLATA',
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
      // ⚡ Evaluar morosidad periódica acumulada de las deudas del cliente antes de cargar su estado de cuenta
      await SalesService().evaluarMorosidadPeriodica(clienteId: clientId);

      final db = await dbHelper.database;
      List<LedgerItem> ledger = [];

      final sales = await db.rawQuery('''
        SELECT v.id, v.numero_secuencial, v.origen_venta, v.fecha_venta, v.monto_total, 
               COALESCE(v.mora_total, 0.0) as mora_total, v.nota_prestamo, v.created_at,
               (SELECT COUNT(c.id) FROM cuotas c WHERE c.venta_id = v.id) as cuotas_count
        FROM ventas v 
        WHERE v.cliente_id = ? AND (v.is_archived IS NULL OR v.is_archived = 0)
      ''', [clientId]);
      
      final payments = await db.rawQuery('''
        SELECT p.*, c.numero_cuota, v.origen_venta as pago_origen_venta, 
               v.numero_secuencial as venta_numero_secuencial, v.id as v_id,
               v.fecha_venta as v_fecha_venta
        FROM pagos p 
        LEFT JOIN cuotas c ON p.cuota_id = c.id 
        LEFT JOIN ventas v ON p.venta_id = v.id
        WHERE p.cliente_id = ? 
          AND (v.is_archived IS NULL OR v.is_archived = 0)
          AND (p.nota IS NULL OR p.nota NOT LIKE '%[ANULADO%')
      ''', [clientId]);

      List<Map<String, dynamic>> eventos = [];
      try {
        eventos = await db.rawQuery('''
          SELECT e.*, v.numero_secuencial as venta_numero_secuencial
          FROM eventos_financieros_cliente e
          LEFT JOIN ventas v ON e.venta_id = v.id
          WHERE e.cliente_id = ?
        ''', [clientId]);
      } catch (_) {}

      List<Map<String, dynamic>> combined = [];

      for (var s in sales) {
        final displayId = s['numero_secuencial'] ?? s['id'];
        final bool isLoan = s['origen_venta'] == 'prestamo_personal';
        final String label = isLoan ? 'Préstamo #$displayId' : 'Venta #$displayId';
        final String subtipo = isLoan ? 'prestamo' : 'venta';
        final double montoTotal = (s['monto_total'] as num).toDouble();
        final double moraTotal = (s['mora_total'] as num?)?.toDouble() ?? 0.0;
        final double montoBase = (montoTotal - moraTotal) > 0 ? (montoTotal - moraTotal) : montoTotal;
        final int cCount = (s['cuotas_count'] as num?)?.toInt() ?? 1;

        combined.add({
          'id_ref': s['id'],
          'tipo': 'cargo',
          'subtipo': subtipo,
          'fecha': s['fecha_venta'],
          'created_at': s['created_at'] ?? s['fecha_venta'],
          'monto': montoTotal,
          'monto_base': montoBase,
          'mora_monto': moraTotal,
          'detalle': label,
          'nota': s['nota_prestamo'],
          'cuotas_count': cCount,
          'affects_debt': true,
          'venta_id': s['id'],
          'can_edit': isLoan,
          'can_delete': isLoan,
          'tie_breaker': 1, // Cargos primero en acumulación
          'seq_id': s['id'],
        });
      }

      for (var p in payments) {
        final bool isLoan = p['pago_origen_venta'] == 'prestamo_personal';
        final String entityName = isLoan ? 'Préstamo' : 'Venta';
        final displayVentaId = p['venta_numero_secuencial'] ?? p['venta_id'];
        final String metodoPago = p['metodo_pago']?.toString() ?? 'Efectivo';
        final int? cuotaNum = (p['numero_cuota'] as num?)?.toInt();
        final String? rawNota = p['nota']?.toString();

        String subtipo = 'pago';
        bool affectsDebt = true;
        if (p['venta_id'] == null || rawNota == 'Conversión a Saldo a favor' || metodoPago == 'devolucion' || metodoPago == 'retiro_saldo') {
          affectsDebt = false;
        }

        String cleanTitle;
        if (metodoPago == 'devolucion') {
          cleanTitle = rawNota ?? 'Devolución';
          subtipo = 'devolucion';
        } else if (metodoPago == 'retiro_saldo') {
          cleanTitle = rawNota ?? 'Retiro de Saldo a favor';
          subtipo = 'retiro_saldo';
        } else if (metodoPago == 'saldo_a_favor') {
          cleanTitle = 'Pago con Saldo a Favor';
        } else if (cuotaNum != null) {
          final bool isHist = rawNota != null && rawNota.toLowerCase().contains('histórico');
          cleanTitle = isHist
              ? 'Abono Histórico • Cuota #$cuotaNum ($entityName #$displayVentaId)'
              : 'Abono • Cuota #$cuotaNum ($entityName #$displayVentaId)';
        } else if (rawNota != null && rawNota.isNotEmpty) {
          cleanTitle = rawNota;
        } else if (p['venta_id'] != null) {
          cleanTitle = 'Abono • $entityName #$displayVentaId';
        } else {
          cleanTitle = 'Abono a cuenta';
        }

        combined.add({
          'id_ref': p['id'],
          'tipo': 'abono',
          'subtipo': subtipo,
          'fecha': p['fecha_pago'],
          'created_at': p['created_at'] ?? p['fecha_pago'],
          'monto': (p['monto'] as num).toDouble(),
          'detalle': cleanTitle,
          'metodo_pago': metodoPago,
          'nota': rawNota,
          'cuota_numero': cuotaNum,
          'venta_id': p['venta_id'],
          'cuota_id': p['cuota_id'],
          'pago_id': p['id'],
          'affects_debt': affectsDebt,
          'can_edit': true,
          'can_delete': true,
          'tie_breaker': 2, // Abonos después del cargo en acumulación
          'seq_id': p['id'],
          'parent_venta_id': p['venta_id'],
        });
      }

      for (var ev in eventos) {
        final tEv = ev['tipo_evento']?.toString() ?? 'evento';
        combined.add({
          'id_ref': ev['id'],
          'tipo': 'evento',
          'subtipo': tEv,
          'tipo_evento': tEv,
          'fecha': ev['fecha_evento'],
          'created_at': ev['fecha_evento'],
          'monto': (ev['monto_impacto'] as num?)?.toDouble() ?? 0.0,
          'detalle': ev['titulo']?.toString() ?? 'Evento Financiero',
          'nota': ev['descripcion']?.toString(),
          'venta_id': ev['venta_id'],
          'cuota_id': ev['cuota_id'],
          'evento_id': ev['id'],
          'affects_debt': false,
          'can_edit': false,
          'can_delete': true,
          'tie_breaker': 3,
          'seq_id': ev['id'],
        });
      }

      // Ordenamiento de recencia operativa: de más antiguo a más reciente para acumulación de saldo
      combined.sort((a, b) {
        DateTime dateA = DateTime.tryParse(a['created_at']?.toString() ?? a['fecha']?.toString() ?? "") ?? DateTime.fromMillisecondsSinceEpoch(0);
        DateTime dateB = DateTime.tryParse(b['created_at']?.toString() ?? b['fecha']?.toString() ?? "") ?? DateTime.fromMillisecondsSinceEpoch(0);
        int dateCmp = dateA.compareTo(dateB);
        if (dateCmp != 0) return dateCmp;

        int pVentaA = (a['parent_venta_id'] ?? a['venta_id'] ?? 0) as int;
        int pVentaB = (b['parent_venta_id'] ?? b['venta_id'] ?? 0) as int;
        if (pVentaA != 0 && pVentaA == pVentaB) {
          int tbA = (a['tie_breaker'] as int?) ?? 1;
          int tbB = (b['tie_breaker'] as int?) ?? 1;
          int tbCmp = tbA.compareTo(tbB);
          if (tbCmp != 0) return tbCmp;
        }

        int idA = (a['seq_id'] as int?) ?? 0;
        int idB = (b['seq_id'] as int?) ?? 0;
        return idA.compareTo(idB);
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
          idRef: item['id_ref'],
          tipo: item['tipo'],
          subtipo: item['subtipo'],
          fecha: DateTime.tryParse(item['fecha']?.toString() ?? "") ?? DateTime.now(),
          monto: monto,
          detalle: item['detalle'],
          saldoResultante: runningBalance,
          ventaId: item['venta_id'],
          cuotaId: item['cuota_id'],
          pagoId: item['pago_id'],
          eventoId: item['evento_id'],
          montoBase: item['monto_base'] != null ? (item['monto_base'] as num).toDouble() : null,
          moraMonto: item['mora_monto'] != null ? (item['mora_monto'] as num).toDouble() : null,
          metodoPago: item['metodo_pago'],
          nota: item['nota'],
          cuotaNumero: item['cuota_numero'],
          entidadRef: item['detalle'],
          canEdit: item['can_edit'] ?? false,
          canDelete: item['can_delete'] ?? false,
          tipoEvento: item['tipo_evento'],
          fechaOperacion: DateTime.tryParse(item['created_at']?.toString() ?? ""),
        ));
      }

      // Invertir para que la operación MÁS RECIENTE registrada esté siempre en la CIMA de la lista
      return ledger.reversed.toList(); 
    } catch (e) { return []; }
  }

  /// ✏️ Edita un abono/pago existente recalculando en cascada cuotas, ventas y deuda del cliente
  Future<bool> editarPago(
    int pagoId, {
    required double nuevoMonto,
    required String nuevoMetodoPago,
    DateTime? nuevaFechaPago,
    String? nuevaNota,
  }) async {
    try {
      final db = await dbHelper.database;
      int? clienteId;
      int? ventaId;
      int? cuotaId;

      await db.transaction((txn) async {
        final pRows = await txn.query('pagos', where: 'id = ?', whereArgs: [pagoId]);
        if (pRows.isEmpty) throw Exception("Pago no encontrado");
        final oldPago = pRows.first;
        final double montoAnterior = (oldPago['monto'] as num).toDouble();
        clienteId = oldPago['cliente_id'] as int?;
        ventaId = oldPago['venta_id'] as int?;
        cuotaId = oldPago['cuota_id'] as int?;
        final int negocioId = (oldPago['negocio_id'] as int?) ?? 1;

        final updateData = <String, dynamic>{
          'monto': nuevoMonto,
          'metodo_pago': nuevoMetodoPago,
          if (nuevaNota != null) 'nota': nuevaNota,
          if (nuevaFechaPago != null) 'fecha_pago': nuevaFechaPago.toIso8601String(),
        };

        await txn.update('pagos', updateData, where: 'id = ?', whereArgs: [pagoId]);

        // Sincronizar cuota vinculada si existe
        if (cuotaId != null) {
          final sumCuota = await txn.rawQuery('''
            SELECT COALESCE(SUM(monto), 0.0) as pagado 
            FROM pagos 
            WHERE cuota_id = ? AND (nota IS NULL OR nota NOT LIKE '%[ANULADO%')
          ''', [cuotaId]);
          final double cuotaPagado = (sumCuota.first['pagado'] as num?)?.toDouble() ?? 0.0;

          final cData = await txn.query('cuotas', where: 'id = ?', whereArgs: [cuotaId]);
          if (cData.isNotEmpty) {
            final double cMonto = (cData.first['monto'] as num).toDouble();
            final String dueDate = cData.first['fecha_vencimiento']?.toString() ?? '';
            final todayStr = DateTime.now().toIso8601String().split('T').first;

            String newStatus = 'pendiente';
            if (cuotaPagado >= cMonto && cMonto > 0) {
              newStatus = 'pagado';
            } else if (cuotaPagado > 0) {
              newStatus = 'parcial';
            } else if (dueDate.isNotEmpty && dueDate.split('T').first.compareTo(todayStr) < 0) {
              newStatus = 'vencida';
            }

            await txn.update('cuotas', {
              'monto_pagado': cuotaPagado,
              'estado': newStatus,
            }, where: 'id = ?', whereArgs: [cuotaId]);
          }
        }

        // Sincronizar venta vinculada si existe
        if (ventaId != null) {
          final sumVenta = await txn.rawQuery('''
            SELECT COALESCE(SUM(monto), 0.0) as pagado 
            FROM pagos 
            WHERE venta_id = ? AND (nota IS NULL OR nota NOT LIKE '%[ANULADO%')
          ''', [ventaId]);
          final double ventaPagado = (sumVenta.first['pagado'] as num?)?.toDouble() ?? 0.0;

          final vData = await txn.query('ventas', where: 'id = ?', whereArgs: [ventaId]);
          if (vData.isNotEmpty) {
            final double vTotal = (vData.first['monto_total'] as num).toDouble();
            String vStatus = 'pendiente';
            if (ventaPagado >= vTotal && vTotal > 0) {
              vStatus = 'pagado';
            } else if (ventaPagado > 0) {
              vStatus = 'parcial';
            }

            await txn.update('ventas', {
              'monto_pagado': ventaPagado,
              'estado_pago': vStatus,
            }, where: 'id = ?', whereArgs: [ventaId]);
          }
        }

        // Registrar evento de auditoría
        await txn.insert('eventos_financieros_cliente', {
          'negocio_id': negocioId,
          'cliente_id': clienteId ?? 0,
          'venta_id': ventaId,
          'cuota_id': cuotaId,
          'pago_id': pagoId,
          'tipo_evento': 'abono_editado',
          'titulo': 'Abono editado',
          'descripcion': 'Monto corregido de S/ ${montoAnterior.toStringAsFixed(2)} a S/ ${nuevoMonto.toStringAsFixed(2)} ($nuevoMetodoPago)',
          'monto_anterior': montoAnterior,
          'monto_nuevo': nuevoMonto,
          'monto_impacto': nuevoMonto - montoAnterior,
          'fecha_evento': DateTime.now().toIso8601String(),
        });
      });

      if (clienteId != null) {
        await recalculateClientDebt(clienteId!);
        await recalculateClientSaldoAFavor(clienteId!);
        await recalculateClientReputation(clienteId!);
      }
      return true;
    } catch (e) {
      debugPrint("Error al editar pago: $e");
      return false;
    }
  }

  /// 🗑️ Revierte o elimina limpiamente un abono de la cuenta del cliente
  Future<bool> revertirPago(int pagoId) async {
    try {
      final db = await dbHelper.database;
      int? clienteId;
      int? ventaId;
      int? cuotaId;

      await db.transaction((txn) async {
        final pRows = await txn.query('pagos', where: 'id = ?', whereArgs: [pagoId]);
        if (pRows.isEmpty) throw Exception("Pago no encontrado");
        final oldPago = pRows.first;
        final double montoAnterior = (oldPago['monto'] as num).toDouble();
        clienteId = oldPago['cliente_id'] as int?;
        ventaId = oldPago['venta_id'] as int?;
        cuotaId = oldPago['cuota_id'] as int?;
        final int negocioId = (oldPago['negocio_id'] as int?) ?? 1;

        // Borrado limpio del pago en SQLite
        await txn.delete('pagos', where: 'id = ?', whereArgs: [pagoId]);

        // Sincronizar cuota
        if (cuotaId != null) {
          final sumCuota = await txn.rawQuery('''
            SELECT COALESCE(SUM(monto), 0.0) as pagado 
            FROM pagos 
            WHERE cuota_id = ? AND (nota IS NULL OR nota NOT LIKE '%[ANULADO%')
          ''', [cuotaId]);
          final double cuotaPagado = (sumCuota.first['pagado'] as num?)?.toDouble() ?? 0.0;

          final cData = await txn.query('cuotas', where: 'id = ?', whereArgs: [cuotaId]);
          if (cData.isNotEmpty) {
            final double cMonto = (cData.first['monto'] as num).toDouble();
            final String dueDate = cData.first['fecha_vencimiento']?.toString() ?? '';
            final todayStr = DateTime.now().toIso8601String().split('T').first;

            String newStatus = 'pendiente';
            if (cuotaPagado >= cMonto && cMonto > 0) {
              newStatus = 'pagado';
            } else if (cuotaPagado > 0) {
              newStatus = 'parcial';
            } else if (dueDate.isNotEmpty && dueDate.split('T').first.compareTo(todayStr) < 0) {
              newStatus = 'vencida';
            }

            await txn.update('cuotas', {
              'monto_pagado': cuotaPagado,
              'estado': newStatus,
            }, where: 'id = ?', whereArgs: [cuotaId]);
          }
        }

        // Sincronizar venta
        if (ventaId != null) {
          final sumVenta = await txn.rawQuery('''
            SELECT COALESCE(SUM(monto), 0.0) as pagado 
            FROM pagos 
            WHERE venta_id = ? AND (nota IS NULL OR nota NOT LIKE '%[ANULADO%')
          ''', [ventaId]);
          final double ventaPagado = (sumVenta.first['pagado'] as num?)?.toDouble() ?? 0.0;

          final vData = await txn.query('ventas', where: 'id = ?', whereArgs: [ventaId]);
          if (vData.isNotEmpty) {
            final double vTotal = (vData.first['monto_total'] as num).toDouble();
            String vStatus = 'pendiente';
            if (ventaPagado >= vTotal && vTotal > 0) {
              vStatus = 'pagado';
            } else if (ventaPagado > 0) {
              vStatus = 'parcial';
            }

            await txn.update('ventas', {
              'monto_pagado': ventaPagado,
              'estado_pago': vStatus,
            }, where: 'id = ?', whereArgs: [ventaId]);
          }
        }

        // Registrar evento de auditoría
        await txn.insert('eventos_financieros_cliente', {
          'negocio_id': negocioId,
          'cliente_id': clienteId ?? 0,
          'venta_id': ventaId,
          'cuota_id': cuotaId,
          'tipo_evento': 'abono_anulado',
          'titulo': 'Abono anulado / revertido',
          'descripcion': 'Se eliminó el abono de S/ ${montoAnterior.toStringAsFixed(2)}. La deuda del cliente aumentó correspondientemente.',
          'monto_anterior': montoAnterior,
          'monto_nuevo': 0.0,
          'monto_impacto': montoAnterior,
          'fecha_evento': DateTime.now().toIso8601String(),
        });
      });

      if (clienteId != null) {
        await recalculateClientDebt(clienteId!);
        await recalculateClientSaldoAFavor(clienteId!);
        await recalculateClientReputation(clienteId!);
      }
      return true;
    } catch (e) {
      debugPrint("Error al revertir pago: $e");
      return false;
    }
  }

  /// 🗑️ Revierte o elimina una venta o préstamo completo creado por error
  Future<bool> revertirVentaOPrestamo(int ventaId) async {
    try {
      final db = await dbHelper.database;
      int? clienteId;

      await db.transaction((txn) async {
        final vRows = await txn.query('ventas', where: 'id = ?', whereArgs: [ventaId]);
        if (vRows.isEmpty) throw Exception("Venta o préstamo no encontrado");
        final venta = vRows.first;
        clienteId = venta['cliente_id'] as int?;

        // Eliminar pagos asociados
        await txn.delete('pagos', where: 'venta_id = ?', whereArgs: [ventaId]);
        // Eliminar cuotas
        await txn.delete('cuotas', where: 'venta_id = ?', whereArgs: [ventaId]);
        // Eliminar items de venta
        await txn.delete('venta_items', where: 'venta_id = ?', whereArgs: [ventaId]);
        // Eliminar eventos financieros asociados
        await txn.delete('eventos_financieros_cliente', where: 'venta_id = ?', whereArgs: [ventaId]);
        // Eliminar la venta
        await txn.delete('ventas', where: 'id = ?', whereArgs: [ventaId]);
      });

      if (clienteId != null) {
        await recalculateClientDebt(clienteId!);
        await recalculateClientSaldoAFavor(clienteId!);
        await recalculateClientReputation(clienteId!);
      }
      return true;
    } catch (e) {
      debugPrint("Error al revertir préstamo/venta: $e");
      return false;
    }
  }

  /// 🗑️ Elimina un evento financiero de auditoría para dejar el historial 100% limpio (Vista Cliente)
  Future<bool> eliminarEventoFinanciero(int eventoId) async {
    try {
      final db = await dbHelper.database;
      await db.delete('eventos_financieros_cliente', where: 'id = ?', whereArgs: [eventoId]);
      return true;
    } catch (e) {
      debugPrint("Error al eliminar evento financiero: $e");
      return false;
    }
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
      // ⚡ Evaluar morosidad automática acumulada del cliente antes de consultar sus deudas
      await SalesService().evaluarMorosidadPeriodica(clienteId: clientId);

      final db = await dbHelper.database;
      final rows = await db.query('ventas', where: 'cliente_id = ? AND estado_pago != ? AND is_archived = 0', whereArgs: [clientId, 'pagado'], orderBy: 'fecha_venta ASC');
      
      List<SaleModel> sales = [];
      for (var row in rows) {
        Map<String, dynamic> saleData = Map.from(row);
        int saleId = saleData['id'] as int;
        var cuotas = await db.query('cuotas', where: 'venta_id = ?', whereArgs: [saleId], orderBy: 'numero_cuota ASC');

        // Auto-heal si la venta no tiene cuotas pero tiene saldo o es crédito
        if (cuotas.isEmpty) {
          final double montoTot = (saleData['monto_total'] as num?)?.toDouble() ?? 0.0;
          final double montoPag = (saleData['monto_pagado'] as num?)?.toDouble() ?? 0.0;
          final double saldoPend = montoTot - montoPag;
          if (saldoPend > 0.01 || saleData['metodo_pago'] == 'credito' || saleData['tipo_venta'] == 'credito') {
            final String fechaVenc = saleData['fecha_entrega']?.toString() ?? saleData['fecha_venta']?.toString() ?? DateTime.now().toIso8601String();
            final double cuotaMonto = saldoPend > 0.01 ? saldoPend : montoTot;
            final double cuotaPagado = saldoPend > 0.01 ? 0.0 : montoPag;
            final String cEstado = saldoPend <= 0.01 ? 'pagado' : (cuotaPagado > 0 ? 'parcial' : 'pendiente');

            await db.insert('cuotas', {
              'venta_id': saleId,
              'numero_cuota': 1,
              'monto': cuotaMonto,
              'monto_original': cuotaMonto,
              'monto_pagado': cuotaPagado,
              'fecha_vencimiento': fechaVenc,
              'estado': cEstado,
              'mora_monto': 0.0,
              'mora_porcentaje': 0.0,
              'mora_automatica': 0,
            });
            cuotas = await db.query('cuotas', where: 'venta_id = ?', whereArgs: [saleId], orderBy: 'numero_cuota ASC');
          }
        }

        saleData['cuotas'] = cuotas;
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
               
               final Map<String, dynamic> cuotaUpdates = {'monto_pagado': pCuota, 'estado': cStatus};
               if (cStatus == 'pagado') {
                 cuotaUpdates['mora_automatica'] = 0; // Apagar mora automática si ya está pagada
               }
               await txn.update('cuotas', cuotaUpdates, where: 'id = ?', whereArgs: [cId]);
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
               final double sumCuotasTotal = cuotas.fold(0.0, (s, c) => s + (c['monto'] as num).toDouble());
               final double sumMoraTotal = cuotas.fold(0.0, (s, c) => s + ((c['mora_monto'] as num?)?.toDouble() ?? 0.0));
               await txn.update('ventas', {
                 'monto_total': sumCuotasTotal,
                 'mora_total': sumMoraTotal,
                 'monto_pagado': nuevoMontoPagado,
                 'abono_inicial': pAbono,
                 'estado_pago': vStatus,
                 'estado_entrega': vEntrega
               }, where: 'id = ?', whereArgs: [vId]);
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
      final cRows = await db.query('cuotas', where: 'id = ?', whereArgs: [cuotaId]);
      if (cRows.isEmpty) return false;
      final cuota = cRows.first;
      final int ventaId = cuota['venta_id'] as int;
      final double montoOriginal = (cuota['monto_original'] as num?)?.toDouble() 
          ?? (cuota['monto'] as num).toDouble();
      final double moraMonto = (cuota['mora_monto'] as num?)?.toDouble() ?? 0.0;

      final now = DateTime.now();
      final todayNorm = DateTime(now.year, now.month, now.day);
      final DateTime? parsedNewDate = DateTime.tryParse(newDate.split('T').first);
      final bool isFutureOrToday = parsedNewDate != null && !parsedNewDate.isBefore(todayNorm);

      int? clienteId;
      await db.transaction((txn) async {
        if (isFutureOrToday && (moraMonto > 0.001 || (cuota['monto'] as num).toDouble() > montoOriginal)) {
          // 🛡️ Salvaguarda: Cuota reprogramada en plazo resetea mora para no cobrar mora anticipada
          await txn.update('cuotas', {
            'fecha_vencimiento': newDate,
            'monto': montoOriginal,
            'mora_monto': 0.0,
            'mora_porcentaje': 0.0,
            'mora_periodos_acumulados': 0,
            'mora_fecha_inicio': newDate,
          }, where: 'id = ?', whereArgs: [cuotaId]);

          final sumRes = await txn.rawQuery(
            'SELECT SUM(monto) as total, SUM(mora_monto) as total_mora FROM cuotas WHERE venta_id = ?', 
            [ventaId]
          );
          final double nuevoVentaTotal = (sumRes.first['total'] as num?)?.toDouble() ?? montoOriginal;
          final double totalMoraVenta = (sumRes.first['total_mora'] as num?)?.toDouble() ?? 0.0;

          await txn.update('ventas', {
            'monto_total': nuevoVentaTotal,
            'mora_total': totalMoraVenta,
          }, where: 'id = ?', whereArgs: [ventaId]);
        } else {
          await txn.update('cuotas', {
            'fecha_vencimiento': newDate,
            if (isFutureOrToday) 'mora_fecha_inicio': newDate,
          }, where: 'id = ?', whereArgs: [cuotaId]);
        }

        if (isFutureOrToday) {
          // 🔔 V31: Resolver/limpiar inmediatamente la alerta de cuota vencida al reprogramarla a fecha futura
          await txn.update('notificaciones', {
            'is_resolved': 1,
            'fecha_resolucion': DateTime.now().toIso8601String(),
          }, where: "objeto_relacionado_tipo = 'cuota' AND objeto_relacionado_id = ? AND dedup_key LIKE 'cuota_vencida_%'", whereArgs: [cuotaId]);
        }

        final vRows = await txn.query('ventas', columns: ['cliente_id'], where: 'id = ?', whereArgs: [ventaId]);
        if (vRows.isNotEmpty) {
          clienteId = vRows.first['cliente_id'] as int?;
        }
      });

      if (clienteId != null) {
        await recalculateClientDebt(clienteId!);
        await recalculateClientReputation(clienteId!);
      }
      return true;
    } catch (e, stack) {
      AppLogger.error('ClientService.updateInstallmentDueDate', e, stack);
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
           var cuotas = await txn.query('cuotas', where: 'venta_id = ? AND estado != ?', whereArgs: [vId, 'pagado'], orderBy: 'numero_cuota ASC');
           if (cuotas.isEmpty) {
              final allCuotas = await txn.query('cuotas', where: 'venta_id = ?', whereArgs: [vId]);
              if (allCuotas.isEmpty) {
                final double montoTot = (vRow['monto_total'] as num?)?.toDouble() ?? 0.0;
                final double montoPag = (vRow['monto_pagado'] as num?)?.toDouble() ?? 0.0;
                final double saldoPend = montoTot - montoPag;
                if (saldoPend > 0.01 || vRow['metodo_pago'] == 'credito' || vRow['tipo_venta'] == 'credito') {
                  final String fechaVenc = vRow['fecha_entrega']?.toString() ?? vRow['fecha_venta']?.toString() ?? DateTime.now().toIso8601String();
                  final double cuotaMonto = saldoPend > 0.01 ? saldoPend : montoTot;
                  final double cuotaPagado = saldoPend > 0.01 ? 0.0 : montoPag;
                  final String cEstado = saldoPend <= 0.01 ? 'pagado' : (cuotaPagado > 0 ? 'parcial' : 'pendiente');
                  await txn.insert('cuotas', {
                    'venta_id': vId,
                    'numero_cuota': 1,
                    'monto': cuotaMonto,
                    'monto_original': cuotaMonto,
                    'monto_pagado': cuotaPagado,
                    'fecha_vencimiento': fechaVenc,
                    'estado': cEstado,
                    'mora_monto': 0.0,
                    'mora_porcentaje': 0.0,
                    'mora_automatica': 0,
                  });
                  cuotas = await txn.query('cuotas', where: 'venta_id = ? AND estado != ?', whereArgs: [vId, 'pagado'], orderBy: 'numero_cuota ASC');
                }
              }
           }
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

        // Priorizar cuotas (Cascada Inteligente y FIFO Canónico)
        cuotasPendientes.sort((a, b) {
           if (cuotaId != null) {
              final bool isTargetA = a['id'] == cuotaId;
              final bool isTargetB = b['id'] == cuotaId;
              if (isTargetA && !isTargetB) return -1;
              if (!isTargetA && isTargetB) return 1;

              // Cascada dentro del mismo préstamo/venta
              final targetVentaId = cuotasPendientes.firstWhere((c) => c['id'] == cuotaId, orElse: () => <String, dynamic>{})['venta_id'];
              final bool isSameVentaA = a['venta_id'] == targetVentaId;
              final bool isSameVentaB = b['venta_id'] == targetVentaId;
              if (isSameVentaA && !isSameVentaB) return -1;
              if (!isSameVentaA && isSameVentaB) return 1;

              if (isSameVentaA && isSameVentaB) {
                 final numCuotaA = (a['numero_cuota'] as num?)?.toInt() ?? 0;
                 final numCuotaB = (b['numero_cuota'] as num?)?.toInt() ?? 0;
                 final cuotaComp = numCuotaA.compareTo(numCuotaB);
                 if (cuotaComp != 0) return cuotaComp;
              }
           } else if (ventaId != null) {
              final bool isVentaA = a['venta_id'] == ventaId;
              final bool isVentaB = b['venta_id'] == ventaId;
              if (isVentaA && !isVentaB) return -1;
              if (!isVentaA && isVentaB) return 1;

              if (isVentaA && isVentaB) {
                 final numCuotaA = (a['numero_cuota'] as num?)?.toInt() ?? 0;
                 final numCuotaB = (b['numero_cuota'] as num?)?.toInt() ?? 0;
                 final cuotaComp = numCuotaA.compareTo(numCuotaB);
                 if (cuotaComp != 0) return cuotaComp;
              }
           }

           // Distribución Automática (o cuotas secundarias fuera de la venta objetivo):
           // Orden cronológico estricto por fecha de vencimiento ASC
           final dateAStr = a['fecha_vencimiento']?.toString() ?? '';
           final dateBStr = b['fecha_vencimiento']?.toString() ?? '';
           final dateA = DateTime.tryParse(dateAStr) ?? DateTime(2099);
           final dateB = DateTime.tryParse(dateBStr) ?? DateTime(2099);
           final dateComp = dateA.compareTo(dateB);
           if (dateComp != 0) return dateComp;

           final numCuotaA = (a['numero_cuota'] as num?)?.toInt() ?? 0;
           final numCuotaB = (b['numero_cuota'] as num?)?.toInt() ?? 0;
           final cuotaComp = numCuotaA.compareTo(numCuotaB);
           if (cuotaComp != 0) return cuotaComp;

           return ((a['venta_id'] as num?)?.toInt() ?? 0).compareTo((b['venta_id'] as num?)?.toInt() ?? 0);
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
              
              final Map<String, dynamic> cUpdates = {'monto_pagado': newPagadoCents / 100.0, 'estado': cStatus};
              if (cStatus == 'pagado') {
                 cUpdates['mora_automatica'] = 0;
              }
              await txn.update('cuotas', cUpdates, where: 'id = ?', whereArgs: [cId]);
              await txn.insert('pagos', {'negocio_id': negocioId, 'creado_por_usuario_id': usuarioId, 'cliente_id': clientId, 'venta_id': vId, 'cuota_id': cId, 'monto': abonoCents / 100.0, 'metodo_pago': method, 'fecha_pago': DateTime.now().toIso8601String()});

              // 🔔 V31: Resolver la alerta de cuota vencida al pagar
              if (cStatus == 'pagado') {
                await txn.update('notificaciones', {
                  'is_resolved': 1,
                  'fecha_resolucion': DateTime.now().toIso8601String(),
                }, where: "objeto_relacionado_tipo = 'cuota' AND objeto_relacionado_id = ?", whereArgs: [cId]);
              }

              if (cStatus == 'pagado') {
                 final cRows = await txn.query('clientes', columns: ['nombre_completo', 'puntos_actuales', 'puntos_historicos', 'racha_pagos_puntuales', 'score_reputacion'], where: 'id = ?', whereArgs: [clientId], limit: 1);
                 String cName = cRows.isNotEmpty ? cRows.first['nombre_completo'] as String : "Cliente";
                 int cPuntosActuales = cRows.isNotEmpty ? (cRows.first['puntos_actuales'] as num?)?.toInt() ?? 0 : 0;
                 int cPuntosHistoricos = cRows.isNotEmpty ? (cRows.first['puntos_historicos'] as num?)?.toInt() ?? 0 : 0;
                 int cRacha = cRows.isNotEmpty ? (cRows.first['racha_pagos_puntuales'] as num?)?.toInt() ?? 0 : 0;
                 int cScore = cRows.isNotEmpty ? (cRows.first['score_reputacion'] as num?)?.toInt() ?? 500 : 500;

                 String dueDateStr = (cRow['fecha_vencimiento'] as String? ?? '').split('T').first;
                 String todayStr = DateTime.now().toIso8601String().split('T').first;
                 bool isPunctual = dueDateStr.isEmpty || todayStr.compareTo(dueDateStr) <= 0;

                 if (isPunctual) {
                    const int bonoPts = 25;
                    int newPuntosActuales = cPuntosActuales + bonoPts;
                    int newPuntosHistoricos = cPuntosHistoricos + bonoPts;
                    int newRacha = cRacha + 1;

                    await txn.update('clientes', {
                       'puntos_actuales': newPuntosActuales,
                       'puntos_historicos': newPuntosHistoricos,
                       'racha_pagos_puntuales': newRacha,
                    }, where: 'id = ?', whereArgs: [clientId]);

                    await txn.insert('historial_puntos_reputacion', {
                       'negocio_id': negocioId,
                       'cliente_id': clientId,
                       'tipo_movimiento': 'BONO_PAGO_PUNTUAL',
                       'puntos_delta': bonoPts,
                       'puntos_saldo_resultante': newPuntosActuales,
                       'score_delta': 15,
                       'score_resultante': (cScore + 15).clamp(0, 1000),
                       'motivo': 'Bono por pago puntual de cuota #$cId (Racha: $newRacha)',
                       'referencia_tipo': 'cuota',
                       'referencia_id': cId,
                       'fecha_registro': DateTime.now().toIso8601String(),
                    });

                    await evaluateAndUnlockRewardGoals(txn, clientId, negocioId, usuarioId: usuarioId, clientName: cName);
                 } else {
                    await txn.update('clientes', {
                       'racha_pagos_puntuales': 0,
                    }, where: 'id = ?', whereArgs: [clientId]);
                 }

                 final vRows = await txn.query('ventas', columns: ['numero_secuencial', 'origen_venta', 'monto_total', 'monto_pagado'], where: 'id = ?', whereArgs: [vId], limit: 1);
                 final bool isLoan = vRows.isNotEmpty && vRows.first['origen_venta'] == 'prestamo_personal';
                 final String folio = vRows.isNotEmpty 
                     ? (isLoan ? 'Préstamo #${vRows.first['numero_secuencial'] ?? vId}' : 'Recibo #${vRows.first['numero_secuencial'] ?? vId}')
                     : 'Operación #$vId';
                 final int cuotaNum = (cRow['numero_cuota'] as num?)?.toInt() ?? 1;
                 final double abonoMonto = abonoCents / 100.0;
                 final double saldoRestante = ((cMontoCents - newPagadoCents) / 100.0).clamp(0.0, double.infinity);

                 final String notifTitle = "Cuota Pagada • $cName";
                 final String saldoTxt = "¡Deuda de cuota liquidada!";
                 final String baseMsg = "$cName canceló S/ ${abonoMonto.toStringAsFixed(2)} de la Cuota #$cuotaNum ($folio). $saldoTxt";
                 final String fullMsg = isPunctual ? "$baseMsg (+25 pts de bono puntual)." : baseMsg;

                 await txn.insert('notificaciones', {
                    'user_id': usuarioId,
                    'negocio_id': negocioId,
                    'dedup_key': 'pago_cuota_${cId}_${DateTime.now().millisecondsSinceEpoch}',
                    'titulo': notifTitle,
                    'mensaje': fullMsg,
                    'tipo': 'exito',
                    'nivel_prioridad': 'informativa',
                    'prioridad': 'Media',
                    'leida': 0,
                    'is_resolved': 1,
                    'objeto_relacionado_tipo': 'cuota',
                    'objeto_relacionado_id': cId,
                    'metadata_json': jsonEncode({
                       'cliente_id': clientId,
                       'cliente_nombre': cName,
                       'cuota_id': cId,
                       'cuota_numero': cuotaNum,
                       'venta_id': vId,
                       'folio_operacion': folio,
                       'es_prestamo': isLoan,
                       'monto_pagado': abonoMonto,
                       'saldo_restante': saldoRestante,
                    }),
                    'fecha_creacion': DateTime.now().toIso8601String(),
                    'fecha_resolucion': DateTime.now().toIso8601String(),
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
      await recalculateClientReputation(clientId);
      return true;
    } catch (e) { throw Exception("Error registrando pago localmente: $e"); }
  }

  Future<void> recalculateClientReputation(int clientId) async {
    try {
      final db = await dbHelper.database;
      final todayStr = DateTime.now().toIso8601String().split('T').first;

      // 1. Estadísticas de ventas
      final salesStats = await db.rawQuery('''
        SELECT 
          COUNT(*) as total_ventas,
          SUM(CASE WHEN is_archived = 1 THEN 1 ELSE 0 END) as ventas_anuladas,
          SUM(CASE WHEN (is_archived IS NULL OR is_archived = 0) THEN monto_pagado ELSE 0 END) as total_pagado
        FROM ventas 
        WHERE cliente_id = ?
      ''', [clientId]);

      int totalVentas = (salesStats.first['total_ventas'] as int?) ?? 0;
      int ventasAnuladas = (salesStats.first['ventas_anuladas'] as int?) ?? 0;
      double totalPagado = ((salesStats.first['total_pagado'] as num?) ?? 0.0).toDouble();
      int ventasCompletadas = totalVentas - ventasAnuladas;

      // 2. Historial de cuotas y puntualidad
      final cuotas = await db.rawQuery('''
        SELECT c.fecha_vencimiento, c.estado, c.monto, c.monto_pagado,
               MAX(p.fecha_pago) as ultima_fecha_pago
        FROM cuotas c
        JOIN ventas v ON c.venta_id = v.id
        LEFT JOIN pagos p ON p.cuota_id = c.id
        WHERE v.cliente_id = ? AND (v.is_archived IS NULL OR v.is_archived = 0) AND (c.estado IS NULL OR c.estado != 'anulada')
        GROUP BY c.id
        ORDER BY c.fecha_vencimiento ASC
      ''', [clientId]);

      int racha = 0;
      int cuotasPuntuales = 0;
      int cuotasVencidasActivas = 0;
      int totalCuotas = cuotas.length;

      for (var cuota in cuotas) {
        String due = (cuota['fecha_vencimiento'] as String? ?? '').split('T').first;
        String status = cuota['estado'] as String? ?? 'pendiente';
        String? lastPay = cuota['ultima_fecha_pago'] as String?;

        if (status == 'pagado') {
          String payDate = (lastPay ?? due).split('T').first;
          if (payDate.compareTo(due) <= 0) {
            racha++;
            cuotasPuntuales++;
          } else {
            racha = 0; // Se pagó fuera de término
          }
        } else {
          // Cuota pendiente, parcial o vencida
          if (status == 'vencida' || (due.isNotEmpty && due.compareTo(todayStr) < 0)) {
            cuotasVencidasActivas++;
            racha = 0; // Mora activa corta la racha
          }
        }
      }

      // 3. Cálculo de Score Multivariable (0 - 1000)
      double score = 500.0;

      // Puntualidad (peso principal)
      if (totalCuotas > 0) {
        double complianceRate = cuotasPuntuales / totalCuotas;
        score += (complianceRate * 150.0);
        score += (racha * 15.0).clamp(0.0, 150.0);
        if (cuotasVencidasActivas > 0) {
          score -= (cuotasVencidasActivas * 80.0);
        }
      } else {
        // Cliente solo de contado: bono neutral por compras limpias
        if (ventasCompletadas > 0) score += 50.0;
      }

      // Constancia y Frecuencia
      if (ventasCompletadas >= 9) {
        score += 150.0;
      } else if (ventasCompletadas >= 4) {
        score += 80.0;
      } else if (ventasCompletadas >= 1) {
        score += 30.0;
      }

      // Penalización por cancelaciones
      if (totalVentas > 0 && (ventasAnuladas / totalVentas) > 0.20) {
        score -= 80.0;
      }

      // Volumen Neto (LTV)
      if (cuotasVencidasActivas == 0) {
        if (totalPagado > 5000) {
          score += 150.0;
        } else if (totalPagado > 2000) {
          score += 110.0;
        } else if (totalPagado > 500) {
          score += 75.0;
        } else if (totalPagado > 100) {
          score += 30.0;
        }
      }

      int finalScore = score.round().clamp(0, 1000);

      // Determinación del nivel: si tiene cuotas vencidas activas, siempre pasa a OBSERVACIÓN / moroso
      String nivel;
      String legacyConfianza;
      if (cuotasVencidasActivas > 0 || finalScore < 350) {
        nivel = 'OBSERVACION';
        legacyConfianza = 'moroso';
      } else if (finalScore < 500) {
        nivel = 'BRONCE';
        legacyConfianza = 'regular';
      } else if (finalScore < 750) {
        nivel = 'PLATA';
        legacyConfianza = 'bueno';
      } else if (finalScore < 900) {
        nivel = 'ORO';
        legacyConfianza = 'excelente';
      } else {
        nivel = 'DIAMANTE_VIP';
        legacyConfianza = 'excelente';
      }

      await db.update(
        'clientes', 
        {
          'score_reputacion': finalScore,
          'nivel_reputacion': nivel,
          'racha_pagos_puntuales': racha,
          'nivel_confianza': legacyConfianza,
        },
        where: 'id = ?',
        whereArgs: [clientId]
      );
    } catch (e, stack) {
      AppLogger.error('ClientService.recalculateClientReputation', e, stack);
    }
  }

  // ==========================================
  // 🏆 V27: GESTIÓN DE GAMIFICACIÓN Y METAS
  // ==========================================

  /// Evalúa si el cliente alcanzó nuevas metas con sus puntos actuales.
  /// Si alcanza una meta y no tiene recompensa activa para ella,
  /// reserva los puntos en `puntos_actuales` (dejando `puntos_historicos` intactos)
  /// e inserta la recompensa en estado 'PENDIENTE_REVISION'.
  Future<List<ClientRewardModel>> evaluateAndUnlockRewardGoals(
    DatabaseExecutor txn,
    int clientId,
    int negocioId, {
    int? usuarioId,
    String? clientName,
  }) async {
    List<ClientRewardModel> unlockedRewards = [];
    try {
      final clientRow = await txn.query(
        'clientes',
        columns: ['puntos_actuales', 'puntos_historicos', 'score_reputacion', 'nombre_completo'],
        where: 'id = ?',
        whereArgs: [clientId],
        limit: 1,
      );
      if (clientRow.isEmpty) return [];

      int currentPuntos = (clientRow.first['puntos_actuales'] as num?)?.toInt() ?? 0;
      int currentScore = (clientRow.first['score_reputacion'] as num?)?.toInt() ?? 500;
      String name = clientName ?? (clientRow.first['nombre_completo'] as String? ?? 'Cliente');

      final metas = await txn.query(
        'metas_recompensas',
        where: 'negocio_id = ? AND activo = 1',
        whereArgs: [negocioId],
        orderBy: 'puntos_requeridos ASC',
      );

      for (var m in metas) {
        int metaId = m['id'] as int;
        int req = (m['puntos_requeridos'] as num).toInt();

        if (currentPuntos >= req) {
          // Verificar si ya tiene una recompensa activa sin consumir/descartar para esta meta
          final existing = await txn.rawQuery('''
            SELECT COUNT(*) as cnt FROM recompensas_cliente 
            WHERE cliente_id = ? AND meta_id = ? AND estado IN ('PENDIENTE_REVISION', 'APROBADA_NOTIFICADA')
          ''', [clientId, metaId]);
          int cnt = (existing.first['cnt'] as int?) ?? 0;

          if (cnt == 0) {
            // Reservar puntos de puntos_actuales (puntos_historicos se mantiene intacto para rango)
            currentPuntos -= req;
            await txn.update(
              'clientes',
              {'puntos_actuales': currentPuntos},
              where: 'id = ?',
              whereArgs: [clientId],
            );

            final now = DateTime.now().toIso8601String();
            int newRewardId = await txn.insert('recompensas_cliente', {
              'negocio_id': negocioId,
              'cliente_id': clientId,
              'meta_id': metaId,
              'puntos_consumidos': req,
              'estado': 'PENDIENTE_REVISION',
              'tipo_beneficio': m['tipo_beneficio'],
              'valor_beneficio': m['valor_beneficio'],
              'titulo_recompensa': m['nombre'],
              'descripcion_recompensa': m['descripcion'],
              'fecha_desbloqueo': now,
            });

            // Kardex
            await txn.insert('historial_puntos_reputacion', {
              'negocio_id': negocioId,
              'cliente_id': clientId,
              'tipo_movimiento': 'RESERVA_META',
              'puntos_delta': -req,
              'puntos_saldo_resultante': currentPuntos,
              'score_delta': 0,
              'score_resultante': currentScore,
              'motivo': 'Puntos reservados por desbloqueo de meta: ${m['nombre']}',
              'referencia_tipo': 'meta',
              'referencia_id': metaId,
              'fecha_registro': now,
            });

            // Notificación interna
            if (usuarioId != null) {
              await txn.insert('notificaciones', {
                'user_id': usuarioId,
                'negocio_id': negocioId,
                'dedup_key': 'recompensa_meta_$newRewardId',
                'titulo': "Premio Desbloqueado • $name",
                'mensaje': "$name alcanzó la meta '${m['nombre']}' y espera tu confirmación.",
                'tipo': 'alerta',
                'nivel_prioridad': 'informativa',
                'prioridad': 'Alta',
                'leida': 0,
                'is_resolved': 0,
                'objeto_relacionado_tipo': 'recompensa',
                'objeto_relacionado_id': newRewardId,
                'metadata_json': jsonEncode({
                  'cliente_id': clientId,
                  'cliente_nombre': name,
                  'meta_id': metaId,
                  'meta_nombre': m['nombre'],
                  'recompensa_id': newRewardId,
                }),
                'fecha_creacion': now,
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            }

            unlockedRewards.add(ClientRewardModel(
              id: newRewardId,
              negocioId: negocioId,
              clienteId: clientId,
              metaId: metaId,
              puntosConsumidos: req,
              estado: 'PENDIENTE_REVISION',
              tipoBeneficio: m['tipo_beneficio'] as String,
              valorBeneficio: (m['valor_beneficio'] as num).toDouble(),
              tituloRecompensa: m['nombre'] as String,
              descripcionRecompensa: m['descripcion'] as String?,
              fechaDesbloqueo: now,
            ));
          }
        }
      }
    } catch (e, stack) {
      AppLogger.error('ClientService.evaluateAndUnlockRewardGoals', e, stack);
    }
    return unlockedRewards;
  }

  /// Evalúa retroactivamente a todos los clientes del negocio que posean puntos actuales > 0
  /// contra las metas de recompensas activas (ordenadas de menor a mayor requerimiento).
  /// Si un cliente califica y aún no tiene la meta en PENDIENTE_REVISION o APROBADA_NOTIFICADA,
  /// se desbloquea automáticamente reservando los puntos correspondientes.
  Future<List<ClientRewardModel>> evaluateAllClientsForActiveGoals(int negocioId, {int? usuarioId}) async {
    List<ClientRewardModel> allUnlocked = [];
    try {
      final db = await dbHelper.database;
      final clients = await db.query(
        'clientes',
        columns: ['id', 'puntos_actuales', 'nombre_completo'],
        where: 'negocio_id = ? AND puntos_actuales > 0',
        whereArgs: [negocioId],
      );
      if (clients.isEmpty) return [];

      await db.transaction((txn) async {
        for (var c in clients) {
          int clientId = c['id'] as int;
          String clientName = (c['nombre_completo'] as String?) ?? 'Cliente';
          final unlocked = await evaluateAndUnlockRewardGoals(
            txn,
            clientId,
            negocioId,
            usuarioId: usuarioId,
            clientName: clientName,
          );
          allUnlocked.addAll(unlocked);
        }
      });
    } catch (e, stack) {
      AppLogger.error('ClientService.evaluateAllClientsForActiveGoals', e, stack);
    }
    return allUnlocked;
  }

  /// Obtiene el catálogo de metas de recompensas del negocio
  Future<List<RewardGoalModel>> getRewardGoals(int negocioId, {bool activeOnly = true}) async {
    try {
      final db = await dbHelper.database;
      String where = 'negocio_id = ?';
      if (activeOnly) where += ' AND activo = 1';

      var rows = await db.query(
        'metas_recompensas',
        where: where,
        whereArgs: [negocioId],
        orderBy: 'puntos_requeridos ASC',
      );

      if (rows.isEmpty) {
        await LocalDatabase.seedDefaultMetasRecompensas(db);
        rows = await db.query(
          'metas_recompensas',
          where: where,
          whereArgs: [negocioId],
          orderBy: 'puntos_requeridos ASC',
        );
      }

      return rows.map((r) => RewardGoalModel.fromJson(r)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Crea una nueva meta de puntos
  Future<RewardGoalModel> createRewardGoal(int negocioId, Map<String, dynamic> data) async {
    final db = await dbHelper.database;
    final map = {
      'negocio_id': negocioId,
      'nombre': data['nombre'],
      'puntos_requeridos': data['puntos_requeridos'],
      'tipo_beneficio': data['tipo_beneficio'] ?? 'DESCUENTO_MONTO',
      'valor_beneficio': data['valor_beneficio'] ?? 0.0,
      'descripcion': data['descripcion'],
      'activo': data['activo'] ?? 1,
      'es_predeterminada': 0,
      'created_at': DateTime.now().toIso8601String(),
    };
    int id = await db.insert('metas_recompensas', map);
    map['id'] = id;
    return RewardGoalModel.fromJson(map);
  }

  /// Actualiza una meta de puntos
  Future<bool> updateRewardGoal(int goalId, Map<String, dynamic> data) async {
    try {
      final db = await dbHelper.database;
      await db.update('metas_recompensas', data, where: 'id = ?', whereArgs: [goalId]);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Elimina una meta de puntos
  Future<bool> deleteRewardGoal(int goalId) async {
    try {
      final db = await dbHelper.database;
      await db.delete('metas_recompensas', where: 'id = ?', whereArgs: [goalId]);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Obtiene recompensas de un cliente (filtradas por estado opcional)
  Future<List<ClientRewardModel>> getClientRewards(int clientId, {String? status}) async {
    try {
      final db = await dbHelper.database;
      String query = '''
        SELECT rc.*, c.nombre_completo AS cliente_nombre, c.telefono AS cliente_telefono,
               mr.nombre AS meta_titulo
        FROM recompensas_cliente rc
        LEFT JOIN clientes c ON rc.cliente_id = c.id
        LEFT JOIN metas_recompensas mr ON rc.meta_id = mr.id
        WHERE rc.cliente_id = ?
      ''';
      List<dynamic> args = [clientId];
      if (status != null && status.isNotEmpty) {
        query += ' AND rc.estado = ?';
        args.add(status);
      }
      query += ' ORDER BY rc.fecha_desbloqueo DESC';
      final rows = await db.rawQuery(query, args);
      return rows.map((r) => ClientRewardModel.fromJson(r)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Obtiene recompensas pendientes de revisión en todo el negocio
  Future<List<ClientRewardModel>> getPendingReviewRewards(int negocioId) async {
    try {
      final db = await dbHelper.database;
      final rows = await db.rawQuery('''
        SELECT rc.*, c.nombre_completo AS cliente_nombre, c.telefono AS cliente_telefono,
               mr.nombre AS meta_titulo
        FROM recompensas_cliente rc
        LEFT JOIN clientes c ON rc.cliente_id = c.id
        LEFT JOIN metas_recompensas mr ON rc.meta_id = mr.id
        WHERE rc.negocio_id = ? AND rc.estado = ?
        ORDER BY rc.fecha_desbloqueo DESC
      ''', [negocioId, 'PENDIENTE_REVISION']);
      return rows.map((r) => ClientRewardModel.fromJson(r)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Contador ultra-rápido a 0ms de recompensas pendientes de revisión
  Future<int> getPendingReviewRewardsCount(int negocioId) async {
    try {
      final db = await dbHelper.database;
      final res = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM recompensas_cliente WHERE negocio_id = ? AND estado = ?',
        [negocioId, 'PENDIENTE_REVISION'],
      );
      return (res.first['cnt'] as int?) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Obtiene la siguiente meta alcanzable para un cliente según sus puntos actuales
  Future<Map<String, dynamic>?> getNextGoalForClient(int clientId, int negocioId) async {
    try {
      final db = await dbHelper.database;
      final clientRow = await db.query(
        'clientes',
        columns: ['puntos_actuales'],
        where: 'id = ?',
        whereArgs: [clientId],
        limit: 1,
      );
      if (clientRow.isEmpty) return null;
      int currentPoints = (clientRow.first['puntos_actuales'] as num?)?.toInt() ?? 0;

      final goals = await getRewardGoals(negocioId, activeOnly: true);
      if (goals.isEmpty) return null;

      for (var g in goals) {
        if (g.puntosRequeridos > currentPoints) {
          int faltantes = g.puntosRequeridos - currentPoints;
          double progress = (currentPoints / g.puntosRequeridos).clamp(0.0, 1.0);
          return {
            'goal': g,
            'puntos_actuales': currentPoints,
            'puntos_requeridos': g.puntosRequeridos,
            'puntos_faltantes': faltantes,
            'missing': faltantes,
            'progreso': progress,
            'progress': progress,
          };
        }
      }
      final maxGoal = goals.last;
      return {
        'goal': maxGoal,
        'puntos_actuales': currentPoints,
        'puntos_requeridos': maxGoal.puntosRequeridos,
        'puntos_faltantes': 0,
        'missing': 0,
        'progreso': 1.0,
        'progress': 1.0,
      };
    } catch (e) {
      return null;
    }
  }

  /// Aprueba una recompensa pendiente y la deja lista para canje / notificada
  Future<bool> approveReward(
    int rewardId, {
    String? customTitle,
    String? customBenefitType,
    double? customBenefitValue,
    String? note,
  }) async {
    try {
      final db = await dbHelper.database;
      Map<String, dynamic> updates = {
        'estado': 'APROBADA_NOTIFICADA',
        'fecha_aprobacion': DateTime.now().toIso8601String(),
      };
      if (customTitle != null) updates['titulo_recompensa'] = customTitle;
      if (customBenefitType != null) updates['tipo_beneficio'] = customBenefitType;
      if (customBenefitValue != null) updates['valor_beneficio'] = customBenefitValue;
      if (note != null) updates['nota_revision'] = note;

      await db.update('recompensas_cliente', updates, where: 'id = ?', whereArgs: [rewardId]);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Descarta o rechaza una recompensa: RESTAURA automáticamente los puntos consumidos al cliente
  Future<bool> discardReward(int rewardId, {String? reason}) async {
    try {
      final db = await dbHelper.database;
      await db.transaction((txn) async {
        final rows = await txn.query('recompensas_cliente', where: 'id = ?', whereArgs: [rewardId], limit: 1);
        if (rows.isEmpty) return;

        final rew = rows.first;
        int clientId = rew['cliente_id'] as int;
        int puntosConsumidos = (rew['puntos_consumidos'] as num).toInt();
        int negocioId = rew['negocio_id'] as int;
        String prevEstado = rew['estado'] as String;

        // Marcar como descartada
        await txn.update(
          'recompensas_cliente',
          {'estado': 'DESCARTADA', 'nota_revision': reason ?? 'Descartada por el comerciante'},
          where: 'id = ?',
          whereArgs: [rewardId],
        );

        // Restaurar puntos si estaba pendiente o aprobada (no canjeada)
        if (prevEstado != 'CANJEADA' && puntosConsumidos > 0) {
          await txn.rawUpdate(
            'UPDATE clientes SET puntos_actuales = puntos_actuales + ? WHERE id = ?',
            [puntosConsumidos, clientId],
          );

          final clientRow = await txn.query(
            'clientes',
            columns: ['puntos_actuales', 'score_reputacion'],
            where: 'id = ?',
            whereArgs: [clientId],
            limit: 1,
          );
          int newPuntos = (clientRow.first['puntos_actuales'] as num?)?.toInt() ?? 0;
          int score = (clientRow.first['score_reputacion'] as num?)?.toInt() ?? 500;

          await txn.insert('historial_puntos_reputacion', {
            'negocio_id': negocioId,
            'cliente_id': clientId,
            'tipo_movimiento': 'RESTAURACION_RECHAZO',
            'puntos_delta': puntosConsumidos,
            'puntos_saldo_resultante': newPuntos,
            'score_delta': 0,
            'score_resultante': score,
            'motivo': reason != null ? 'Recompensa rechazada: $reason' : 'Restauración por descarte de recompensa',
            'referencia_tipo': 'recompensa',
            'referencia_id': rewardId,
            'fecha_registro': DateTime.now().toIso8601String(),
          });
        }
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Obtiene el kardex de puntos y reputación de un cliente
  Future<List<LoyaltyLedgerModel>> getClientLoyaltyLedger(int clientId, {int limit = 50}) async {
    try {
      final db = await dbHelper.database;
      final rows = await db.query(
        'historial_puntos_reputacion',
        where: 'cliente_id = ?',
        whereArgs: [clientId],
        orderBy: 'fecha_registro DESC',
        limit: limit,
      );
      return rows.map((r) => LoyaltyLedgerModel.fromJson(r)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Agrega un movimiento manual de puntos o score
  Future<List<ClientRewardModel>> addManualLoyaltyMovement(
    int clientId,
    int negocioId, {
    required int pointsDelta,
    required String motivo,
    int scoreDelta = 0,
    int? usuarioId,
  }) async {
    final db = await dbHelper.database;
    List<ClientRewardModel> unlocked = [];
    await db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE clientes SET puntos_actuales = MAX(0, puntos_actuales + ?), puntos_historicos = MAX(0, puntos_historicos + ?) WHERE id = ?',
        [pointsDelta, pointsDelta > 0 ? pointsDelta : 0, clientId],
      );

      final cRow = await txn.query(
        'clientes',
        columns: ['puntos_actuales', 'score_reputacion', 'nombre_completo'],
        where: 'id = ?',
        whereArgs: [clientId],
        limit: 1,
      );
      int pResult = (cRow.first['puntos_actuales'] as num?)?.toInt() ?? 0;
      int sResult = (cRow.first['score_reputacion'] as num?)?.toInt() ?? 500;
      String cName = cRow.first['nombre_completo'] as String? ?? 'Cliente';

      await txn.insert('historial_puntos_reputacion', {
        'negocio_id': negocioId,
        'cliente_id': clientId,
        'tipo_movimiento': 'AJUSTE_MANUAL',
        'puntos_delta': pointsDelta,
        'puntos_saldo_resultante': pResult,
        'score_delta': scoreDelta,
        'score_resultante': sResult,
        'motivo': motivo,
        'referencia_tipo': 'manual',
        'referencia_id': null,
        'fecha_registro': DateTime.now().toIso8601String(),
      });

      // Evaluar si con estos puntos desbloquea metas
      if (pointsDelta > 0) {
        unlocked = await evaluateAndUnlockRewardGoals(
          txn,
          clientId,
          negocioId,
          usuarioId: usuarioId,
          clientName: cName,
        );
      }
    });
    await recalculateClientReputation(clientId);
    return unlocked;
  }

  /// Sincroniza el campo nivel_reputacion en SQLite según el score_reputacion actual de cada cliente.
  /// Esto asegura que clientes con score 500–749 (como Huk y Bmk) se almacenen y sincronicen como 'PLATA'.
  Future<void> syncClientReputationTiers(int negocioId) async {
    try {
      final db = await dbHelper.database;
      await db.rawUpdate('''
        UPDATE clientes 
        SET nivel_reputacion = CASE 
          WHEN score_reputacion >= 900 THEN 'DIAMANTE_VIP'
          WHEN score_reputacion >= 750 THEN 'ORO'
          WHEN score_reputacion >= 500 THEN 'PLATA'
          WHEN score_reputacion >= 350 THEN 'BRONCE'
          ELSE 'OBSERVACION'
        END
        WHERE negocio_id = ?
      ''', [negocioId]);
    } catch (e, stack) {
      AppLogger.error('ClientService.syncClientReputationTiers', e, stack);
    }
  }

  /// Obtiene clientes filtrados por nivel de fidelización y búsqueda opcional
  Future<List<ClientModel>> getClientsByLoyaltyTier(
    int negocioId, {
    String? tierKey,
    String? searchQuery,
  }) async {
    try {
      await syncClientReputationTiers(negocioId);
      final db = await dbHelper.database;
      String where = 'negocio_id = ?';
      List<dynamic> args = [negocioId];

      if (tierKey != null && tierKey.isNotEmpty && tierKey != 'TODOS') {
        where += ' AND nivel_reputacion = ?';
        args.add(tierKey);
      }

      final rows = await db.query(
        'clientes',
        where: where,
        whereArgs: args,
        orderBy: 'score_reputacion DESC, puntos_actuales DESC',
      );

      var clients = rows.map((r) => ClientModel.fromJson(r)).toList();
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        clients = clients.where((c) => SmartSearchMatcher.matches(
          query: searchQuery,
          targets: [
            c.fullName,
            c.phone,
            c.docNumber,
            c.tier.displayName,
            c.tier.key,
          ],
        )).toList();
      }
      return clients;
    } catch (e) {
      return [];
    }
  }

  /// Identifica clientes que están cerca de una meta (impulso de compra comercial)
  /// Regla matemática estricta: Requiere puntosActuales > 0 y avance >= 50% de la meta.
  Future<List<Map<String, dynamic>>> getClientsAlmostAtGoal(
    int negocioId, {
    double minPercent = 0.50,
    double maxPercent = 0.99,
  }) async {
    try {
      final db = await dbHelper.database;
      final metas = await db.query(
        'metas_recompensas',
        where: 'negocio_id = ? AND activo = 1',
        whereArgs: [negocioId],
        orderBy: 'puntos_requeridos ASC',
      );
      if (metas.isEmpty) return [];

      final clients = await db.query('clientes', where: 'negocio_id = ?', whereArgs: [negocioId]);
      List<Map<String, dynamic>> results = [];

      for (var c in clients) {
        int pts = (c['puntos_actuales'] as num?)?.toInt() ?? 0;
        // Un cliente con 0 puntos JAMÁS entra en "Casi en la Meta"
        if (pts <= 0) continue;

        for (var m in metas) {
          int req = (m['puntos_requeridos'] as num).toInt();
          if (pts < req) {
            double progress = pts / req;
            int faltantes = req - pts;
            if (progress >= minPercent && progress <= maxPercent) {
              results.add({
                'client': ClientModel.fromJson(c),
                'goal': RewardGoalModel.fromJson(m),
                'puntos_actuales': pts,
                'puntos_faltantes': faltantes,
                'porcentaje': (progress * 100).round(),
              });
              break; // Solo sugerir la meta más próxima
            }
          }
        }
      }
      return results;
    } catch (e) {
      return [];
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
    DateTime? loanDate,
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

      // Calcular total amortizado históricamente a partir de las cuotas
      double totalAbonadoHistorico = 0.0;
      if (installments != null && installments.isNotEmpty) {
        totalAbonadoHistorico = installments.fold(0.0, (sum, cuota) => sum + cuota.montoPagado);
      }
      if (totalAbonadoHistorico > finalDebt) totalAbonadoHistorico = finalDebt;

      String estadoPago = 'pendiente';
      if ((finalDebt - totalAbonadoHistorico) <= 0.02 && finalDebt > 0) {
        estadoPago = 'pagado';
      } else if (totalAbonadoHistorico > 0) {
        estadoPago = 'parcial';
      }

      final emissionDateIso = (loanDate ?? DateTime.now()).toIso8601String();

      // 1. Insertar "venta virtual" como préstamo
      int loanId = await txn.insert('ventas', {
        'numero_secuencial': sequentialId,
        'negocio_id': negocioId,
        'creado_por_usuario_id': usuarioId,
        'cliente_id': clientId,
        'origen_venta': 'prestamo_personal',
        'metodo_pago': metodoPago ?? 'Efectivo',
        'estado_pago': estadoPago,
        'estado_entrega': 'entregado', // No hay entrega física
        'monto_total': finalDebt,
        'monto_pagado': totalAbonadoHistorico,
        'abono_inicial': totalAbonadoHistorico,
        'nota_prestamo': motivo,
        'porcentaje_interes': interestRate ?? 0.0,
        'mora_total': 0.0,
        'fecha_venta': emissionDateIso,
      });

      // 2. Insertar cuotas generadas por el modal o cuota única por defecto
      final todayStr = DateTime.now().toIso8601String().split('T').first;

      if (installments != null && installments.isNotEmpty) {
        for (var cuota in installments) {
          String dueStr = cuota.dueDate.split('T').first;
          double cMonto = cuota.amount;
          double cPagado = cuota.montoPagado;

          String cStatus = cuota.status;
          if (cPagado >= cMonto && cMonto > 0) {
            cStatus = 'pagado';
          } else if (cPagado > 0) {
            cStatus = 'parcial';
          } else {
            // Si no tiene pago, determinar si está vencida o pendiente según fecha
            cStatus = (dueStr.isNotEmpty && dueStr.compareTo(todayStr) < 0) ? 'vencida' : 'pendiente';
          }

          int cuotaId = await txn.insert('cuotas', {
            'venta_id': loanId,
            'numero_cuota': cuota.installmentNumber,
            'monto': cMonto,
            'monto_original': cMonto,
            'monto_pagado': cPagado,
            'fecha_vencimiento': cuota.dueDate,
            'estado': cStatus,
            'mora_monto': 0.0,
            'mora_porcentaje': 0.0,
            'mora_automatica': 0,
          });

          // Si la cuota ya cuenta con un abono histórico, insertar el registro en `pagos`
          if (cPagado > 0) {
            await txn.insert('pagos', {
              'negocio_id': negocioId,
              'creado_por_usuario_id': usuarioId,
              'cliente_id': clientId,
              'venta_id': loanId,
              'cuota_id': cuotaId,
              'monto': cPagado,
              'metodo_pago': metodoPago ?? 'Efectivo',
              'nota': 'Abono histórico (Cuota #${cuota.installmentNumber} Préstamo #$sequentialId)',
              'fecha_pago': cuota.dueDate.isNotEmpty ? cuota.dueDate : emissionDateIso,
            });
          }
        }
      } else {
        final defaultDue = DateTime.now().add(const Duration(days: 30));
        await txn.insert('cuotas', {
          'venta_id': loanId,
          'numero_cuota': 1,
          'monto': finalDebt,
          'monto_original': finalDebt,
          'monto_pagado': 0.0,
          'fecha_vencimiento': DateFormat('yyyy-MM-dd').format(defaultDue),
          'estado': 'pendiente',
          'mora_monto': 0.0,
          'mora_porcentaje': 0.0,
          'mora_automatica': 0,
        });
      }
    });

    // 3. Recalcular deuda, saldo a favor y reputación
    await recalculateClientDebt(clientId);
    await recalculateClientSaldoAFavor(clientId);
    await recalculateClientReputation(clientId);
  }
}