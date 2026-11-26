import 'package:app_movil/features/smart_quotation/models/crm_models.dart';

// 🧠 GESTOR DE BORRADORES EN MEMORIA (ClientFinanceDraftManager)
// Preserva intacto el estado ante cambios de pestaña y cierres del modal
// ============================================================================

class FinanceWithdrawDraft {
  final String amount;
  final String method;

  FinanceWithdrawDraft({
    this.amount = '',
    this.method = 'Efectivo',
  });

  bool get isEmpty => amount.isEmpty;
}

class FinanceLoanDraft {
  final String amount;
  final String method;
  final String motivo;
  final bool splitInQuotas;
  final String numCuotas;
  final String interestRate;
  final String frecuencia;
  final DateTime dueDate;
  final DateTime startDate;
  final DateTime loanEmissionDate;
  final double oneQuotaPaidAmount;
  final String oneQuotaStatus;
  final Set<int> excludedWeekdays;
  final List<InstallmentModel> installments;

  FinanceLoanDraft({
    this.amount = '',
    this.method = 'Efectivo',
    this.motivo = '',
    this.splitInQuotas = false,
    this.numCuotas = '2',
    this.interestRate = '0',
    this.frecuencia = 'mensual',
    DateTime? dueDate,
    DateTime? startDate,
    DateTime? loanEmissionDate,
    this.oneQuotaPaidAmount = 0.0,
    this.oneQuotaStatus = 'pendiente',
    Set<int>? excludedWeekdays,
    List<InstallmentModel>? installments,
  })  : dueDate = dueDate ?? DateTime.now().add(const Duration(days: 30)),
        startDate = startDate ?? DateTime.now(),
        loanEmissionDate = loanEmissionDate ?? DateTime.now(),
        excludedWeekdays = excludedWeekdays != null
            ? Set<int>.from(excludedWeekdays)
            : {DateTime.sunday},
        installments = installments != null
            ? List<InstallmentModel>.from(installments)
            : const [];

  bool get isEmpty => amount.isEmpty && motivo.isEmpty && installments.isEmpty;
}

class ClientFinanceDraftManager {
  static final ClientFinanceDraftManager _instance =
      ClientFinanceDraftManager._internal();
  factory ClientFinanceDraftManager() => _instance;
  ClientFinanceDraftManager._internal();

  static ClientFinanceDraftManager get instance => _instance;

  final Map<int, int> _activeTabs = {};
  final Map<int, FinanceWithdrawDraft> _withdrawDrafts = {};
  final Map<int, FinanceLoanDraft> _loanDrafts = {};

  int getActiveTab(int clientId) => _activeTabs[clientId] ?? 0;
  void setActiveTab(int clientId, int index) => _activeTabs[clientId] = index;

  FinanceWithdrawDraft? getWithdrawDraft(int clientId) =>
      _withdrawDrafts[clientId];
  void setWithdrawDraft(int clientId, FinanceWithdrawDraft draft) =>
      _withdrawDrafts[clientId] = draft;
  void clearWithdrawDraft(int clientId) => _withdrawDrafts.remove(clientId);

  FinanceLoanDraft? getLoanDraft(int clientId) => _loanDrafts[clientId];
  void setLoanDraft(int clientId, FinanceLoanDraft draft) =>
      _loanDrafts[clientId] = draft;
  void clearLoanDraft(int clientId) => _loanDrafts.remove(clientId);

  void clearAll(int clientId) {
    _activeTabs.remove(clientId);
    _withdrawDrafts.remove(clientId);
    _loanDrafts.remove(clientId);
  }
}

// ============================================================================
// MODAL DE OPERACIONES FINANCIERAS (Retiro de Saldo & Préstamo / Fiado)
// ============================================================================
