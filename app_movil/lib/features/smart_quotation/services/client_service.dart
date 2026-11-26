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

part 'client_service_crud.dart';
part 'client_service_ledger.dart';
part 'client_service_payments.dart';
part 'client_service_payment_fifo.dart';
part 'client_service_loyalty.dart';
part 'client_service_loyalty_rewards.dart';

abstract class _ClientServiceBase {
  final _repository = ClientRepository();
  final dbHelper = LocalDatabase
      .instance; // Mantenido solo para transacciones complejas inter-tabla

  Future<ClientModel?> getClientById(int id);
  Future<void> recalculateClientDebt(int clientId);
  Future<void> recalculateClientSaldoAFavor(int clientId);
  Future<void> recalculateClientReputation(int clientId);
  Future<LoyaltyRulesModel> getLoyaltyRulesTxn(
    DatabaseExecutor db,
    int negocioId,
  );
  Future<List<ClientRewardModel>> evaluateAndUnlockRewardGoals(
    DatabaseExecutor txn,
    int clientId,
    int negocioId, {
    int? usuarioId,
    String? clientName,
  });
  Future<List<RewardGoalModel>> getRewardGoals(
    int negocioId, {
    bool activeOnly = true,
  });
  Future<List<ClientRewardModel>> getClientRewards(
    int clientId, {
    String? status,
  });
  Future<Map<String, dynamic>?> getNextGoalForClient(
    int clientId,
    int negocioId,
  );
}

class ClientService extends _ClientServiceBase
    with
        _ClientServiceCrudMixin,
        _ClientServiceLedgerMixin,
        _ClientServicePaymentsMixin,
        _ClientServicePaymentFifoMixin,
        _ClientServiceLoyaltyMixin,
        _ClientServiceLoyaltyRewardsMixin {}
