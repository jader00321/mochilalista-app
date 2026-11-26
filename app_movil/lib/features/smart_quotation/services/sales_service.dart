import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/database/product_queries.dart';
import 'package:app_movil/features/catalog/models/inventory_wrapper.dart';
import 'package:app_movil/features/smart_quotation/repositories/sale_repository.dart';
import 'package:app_movil/features/smart_quotation/services/client_service.dart';

part 'sales_service_pos_tx.dart';
part 'sales_service_history_stats.dart';
part 'sales_service_void_restore.dart';
part 'sales_service_restore_delivery.dart';
part 'sales_service_morosidad.dart';
part 'sales_service_notifications.dart';

abstract class _SalesServiceBase {
  final dbHelper = LocalDatabase.instance;
  final _repository = SaleRepository();

  Future<Map<String, dynamic>> getSaleDetail(int saleId);
  Future<void> evaluarMorosidadPeriodica({
    int? ventaId,
    int? clienteId,
    DateTime? referenceDate,
  });
  Future<void> syncCuotaNotification(int cuotaId);
  Future<void> _emitLowStockNotificationIfNeededTxn(
    Transaction txn, {
    required int negocioId,
    required int usuarioId,
    required int prodId,
    required int newStock,
    required int stockAlerta,
    required dynamic item,
  });
  Future<void> _applySaleLoyaltyAndRewardsTxn(
    Transaction txn, {
    required Map<String, dynamic> saleData,
    required int negocioId,
    required int usuarioId,
    required int saleId,
    required int sequentialId,
    required double pagadoRaw,
    required List<dynamic> cuotas,
  });
}

class SalesService extends _SalesServiceBase
    with
        _SalesServicePosTxMixin,
        _SalesServiceHistoryStatsMixin,
        _SalesServiceVoidRestoreMixin,
        _SalesServiceRestoreDeliveryMixin,
        _SalesServiceMorosidadMixin,
        _SalesServiceNotificationsMixin {}
