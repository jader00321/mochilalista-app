import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

// ============================================================================
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

class ClientFinanceActionsModal extends StatefulWidget {
  final ClientModel client;
  final bool isDark;
  final int initialTab;

  const ClientFinanceActionsModal({
    super.key,
    required this.client,
    required this.isDark,
    this.initialTab = 0,
  });

  /// Presenta el modal de operaciones financieras garantizando enableDrag: false
  /// para evitar que el gesto de arrastre compita con el scroll vertical de cuotas.
  static Future<void> show(
    BuildContext context, {
    required ClientModel client,
    required bool isDark,
    int initialTab = 0,
    VoidCallback? onCompleted,
  }) {
    ClientFinanceDraftManager.instance
        .setActiveTab(client.id, initialTab.clamp(0, 1));
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClientFinanceActionsModal(
        client: client,
        isDark: isDark,
        initialTab: initialTab,
      ),
    ).then((_) {
      onCompleted?.call();
    });
  }

  @override
  State<ClientFinanceActionsModal> createState() =>
      _ClientFinanceActionsModalState();
}

class _ClientFinanceActionsModalState extends State<ClientFinanceActionsModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Controladores de texto
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _numCuotasCtrl = TextEditingController(text: "2");
  final _interestCtrl = TextEditingController(text: "0");

  String _withdrawMethod = "Efectivo";
  String _loanMethod = "Efectivo";
  String _frecuencia = "mensual";

  // Fecha de emisión / entrega del préstamo (desbloqueada desde 2015 para registros históricos)
  DateTime _loanEmissionDate = DateTime.now();

  // Fecha de vencimiento para préstamo simple (1 cuota)
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));

  // Estado y amortización previa para 1 cuota
  double _oneQuotaPaidAmount = 0.0;
  String _oneQuotaStatus = "pendiente";

  // Fraccionamiento en cuotas múltiples y motor de cascada
  bool _splitInQuotas = false;
  DateTime _startDate = DateTime.now();
  Set<int> _excludedWeekdays = {DateTime.sunday}; // Por defecto omitir domingos
  final List<InstallmentModel> _installments = [];
  String? _scheduleUpdateFeedback;
  int _feedbackTrigger = 0;
  final Map<int, String> _installmentShiftReasons = {};

  bool _isLoading = false;

  final List<String> _motivosSug = [
    "Préstamo personal",
    "Fiado mercadería",
    "Adelanto de trabajo",
    "Emergencia",
    "Otros",
  ];

  @override
  void initState() {
    super.initState();
    final draftMgr = ClientFinanceDraftManager.instance;
    final initialTab = widget.initialTab;
    draftMgr.setActiveTab(widget.client.id, initialTab.clamp(0, 1));

    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: initialTab.clamp(0, 1),
    );

    // Restaurar datos del tab activo
    _restoreDraftForTab(_tabController.index);

    // Listeners reactivos
    _amountCtrl.addListener(_onAmountChanged);
    _numCuotasCtrl.addListener(_onNumCuotasChanged);
    _interestCtrl.addListener(_onInterestChanged);
    _noteCtrl.addListener(_onNoteChanged);

    _tabController.addListener(_onTabChanged);
  }

  void _onNoteChanged() {
    _saveCurrentDraft();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _saveCurrentDraft();
    _amountCtrl.removeListener(_onAmountChanged);
    _numCuotasCtrl.removeListener(_onNumCuotasChanged);
    _interestCtrl.removeListener(_onInterestChanged);
    _noteCtrl.removeListener(_onNoteChanged);
    _tabController.removeListener(_onTabChanged);

    _tabController.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _numCuotasCtrl.dispose();
    _interestCtrl.dispose();
    super.dispose();
  }

  void _onAmountChanged() {
    if (mounted) setState(() {});
    if (_tabController.index == 0 && _splitInQuotas) {
      _recalculateMultipleInstallments();
    } else {
      _saveCurrentDraft();
    }
  }

  void _onNumCuotasChanged() {
    if (_tabController.index == 0 && _splitInQuotas) {
      _recalculateMultipleInstallments();
    }
  }

  void _onInterestChanged() {
    if (_tabController.index == 0 && _splitInQuotas) {
      _recalculateMultipleInstallments();
    }
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      // Guardar el estado del tab anterior antes de que complete la transición
      final prevIndex = _tabController.previousIndex;
      _saveDraftByIndex(prevIndex);
    } else {
      // Restaurar el estado del nuevo tab
      ClientFinanceDraftManager.instance
          .setActiveTab(widget.client.id, _tabController.index);
      _restoreDraftForTab(_tabController.index);
    }
  }

  // =========================================================================
  // GESTIÓN DE BORRADORES (Tab 0: Préstamo, Tab 1: Retiro)
  // =========================================================================

  void _saveCurrentDraft() {
    _saveDraftByIndex(_tabController.index);
  }

  void _saveDraftByIndex(int tabIndex) {
    final draftMgr = ClientFinanceDraftManager.instance;
    if (tabIndex == 0) {
      draftMgr.setLoanDraft(
        widget.client.id,
        FinanceLoanDraft(
          amount: _amountCtrl.text,
          method: _loanMethod,
          motivo: _noteCtrl.text,
          splitInQuotas: _splitInQuotas,
          numCuotas: _numCuotasCtrl.text,
          interestRate: _interestCtrl.text,
          frecuencia: _frecuencia,
          dueDate: _dueDate,
          startDate: _startDate,
          loanEmissionDate: _loanEmissionDate,
          oneQuotaPaidAmount: _oneQuotaPaidAmount,
          oneQuotaStatus: _oneQuotaStatus,
          excludedWeekdays: _excludedWeekdays,
          installments: _installments,
        ),
      );
    } else {
      draftMgr.setWithdrawDraft(
        widget.client.id,
        FinanceWithdrawDraft(
          amount: _amountCtrl.text,
          method: _withdrawMethod,
        ),
      );
    }
  }

  void _restoreDraftForTab(int tabIndex) {
    final draftMgr = ClientFinanceDraftManager.instance;
    if (tabIndex == 0) {
      final draft = draftMgr.getLoanDraft(widget.client.id);
      if (draft != null) {
        _amountCtrl.text = draft.amount;
        _loanMethod = draft.method;
        _noteCtrl.text = draft.motivo;
        _splitInQuotas = draft.splitInQuotas;
        _numCuotasCtrl.text = draft.numCuotas;
        _interestCtrl.text = draft.interestRate;
        _frecuencia = draft.frecuencia;
        _dueDate = draft.dueDate;
        _startDate = draft.startDate;
        _loanEmissionDate = draft.loanEmissionDate;
        _oneQuotaPaidAmount = draft.oneQuotaPaidAmount;
        _oneQuotaStatus = draft.oneQuotaStatus;
        _excludedWeekdays = Set<int>.from(draft.excludedWeekdays);
        _installments.clear();
        _installments.addAll(draft.installments);
      } else {
        _amountCtrl.text = '';
        _loanMethod = 'Efectivo';
        _noteCtrl.text = '';
        _splitInQuotas = false;
        _numCuotasCtrl.text = '2';
        _interestCtrl.text = '0';
        _frecuencia = 'mensual';
        _dueDate = DateTime.now().add(const Duration(days: 30));
        _startDate = DateTime.now();
        _loanEmissionDate = DateTime.now();
        _oneQuotaPaidAmount = 0.0;
        _oneQuotaStatus = 'pendiente';
        _excludedWeekdays = {DateTime.sunday};
        _installments.clear();
      }
    } else {
      final draft = draftMgr.getWithdrawDraft(widget.client.id);
      _amountCtrl.text = draft?.amount ?? '';
      _withdrawMethod = draft?.method ?? 'Efectivo';
    }
    if (mounted) setState(() {});
  }

  /// Limpia únicamente los datos y el borrador de la pestaña actualmente activa
  void _cleanActiveTab() {
    HapticFeedback.mediumImpact();
    final isLoan = _tabController.index == 0;
    if (isLoan) {
      ClientFinanceDraftManager.instance.clearLoanDraft(widget.client.id);
      _amountCtrl.clear();
      _noteCtrl.clear();
      _loanMethod = "Efectivo";
      _splitInQuotas = false;
      _numCuotasCtrl.text = "2";
      _interestCtrl.text = "0";
      _frecuencia = "mensual";
      _dueDate = DateTime.now().add(const Duration(days: 30));
      _startDate = DateTime.now();
      _loanEmissionDate = DateTime.now();
      _oneQuotaPaidAmount = 0.0;
      _oneQuotaStatus = "pendiente";
      _excludedWeekdays = {DateTime.sunday};
      _installments.clear();
      _scheduleUpdateFeedback = null;
      _installmentShiftReasons.clear();
      CustomSnackBar.show(context,
          message: "Formulario de Préstamo restablecido", isError: false);
    } else {
      ClientFinanceDraftManager.instance
          .clearWithdrawDraft(widget.client.id);
      _amountCtrl.clear();
      _withdrawMethod = "Efectivo";
      CustomSnackBar.show(context,
          message: "Formulario de Retiro restablecido", isError: false);
    }
    if (mounted) setState(() {});
  }

  // =========================================================================
  // MOTOR DE CASCADA Y DÍAS EXCLUIDOS (Sin fechas duplicadas y con ancla)
  // =========================================================================

  DateTime _addFrequency(DateTime date) {
    if (_frecuencia == "diario") return date.add(const Duration(days: 1));
    if (_frecuencia == "semanal") return date.add(const Duration(days: 7));
    if (_frecuencia == "quincenal") return date.add(const Duration(days: 15));
    // Mensual
    return _addMonthsClamped(date, 1);
  }

  DateTime _addMonthsClamped(DateTime base, int monthsToAdd) {
    int totalMonths = (base.year * 12 + (base.month - 1)) + monthsToAdd;
    int newYear = totalMonths ~/ 12;
    int newMonth = (totalMonths % 12) + 1;
    int daysInNewMonth = DateUtils.getDaysInMonth(newYear, newMonth);
    int newDay = base.day > daysInNewMonth ? daysInNewMonth : base.day;
    return DateTime(newYear, newMonth, newDay);
  }

  String _getFrequencyContextSubtitle() {
    switch (_frecuencia) {
      case 'diario':
        return "Días hábiles de cobro diario";
      case 'semanal':
        return "Días permitidos para el cobro semanal";
      case 'quincenal':
        return "Días hábiles para el cobro quincenal";
      case 'mensual':
      default:
        return "Días hábiles para el cobro mensual";
    }
  }

  /// Avanza la fecha según la frecuencia y salta cualquier día excluido.
  /// Garantiza matemáticamente que la fecha retornada sea posterior a [fromDate].
  DateTime _advanceDateSkippingExcluded(DateTime fromDate) {
    DateTime next = _addFrequency(fromDate);
    if (!next.isAfter(fromDate)) {
      next = fromDate.add(const Duration(days: 1));
    }
    while (_excludedWeekdays.contains(next.weekday)) {
      next = next.add(const Duration(days: 1));
    }
    return next;
  }

  /// Formatea la fecha con el día abreviado en español (ej. "Lun, 26/10/2026")
  String _formatDateSpanish(DateTime date) {
    try {
      String raw = DateFormat('EEE, dd/MM/yyyy', 'es').format(date);
      raw = raw.replaceAll('.', '');
      if (raw.isEmpty) return DateFormat('dd/MM/yyyy').format(date);
      return raw[0].toUpperCase() + raw.substring(1);
    } catch (_) {
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }

  /// Toggle de día de la semana con protección anti-bucle (debe quedar al menos 1 día activo)
  void _toggleWeekday(int day) {
    HapticFeedback.selectionClick();
    if (_excludedWeekdays.contains(day)) {
      // Quitar de excluidos (reactivar el día) -> Siempre seguro
      setState(() {
        _excludedWeekdays.remove(day);
        _recalculateMultipleInstallments();
      });
    } else {
      // Intentar excluir: proteger que queden al menos 1 día activo
      if (_excludedWeekdays.length >= 6) {
        HapticFeedback.heavyImpact();
        CustomSnackBar.show(
          context,
          message: "Debe quedar al menos 1 día de cobro activo en la semana",
          isError: true,
        );
        return;
      }
      setState(() {
        _excludedWeekdays.add(day);
        _recalculateMultipleInstallments();
      });
    }
  }

  InstallmentModel _buildRecalculatedInstallment({
    required int index,
    required double amount,
    required DateTime date,
    required Map<int, double> existingPaid,
  }) {
    final double paid = existingPaid[index] ?? 0.0;
    final double safePaid = paid > amount ? amount : paid;
    String status = "pendiente";
    if (safePaid >= amount && amount > 0) {
      status = "pagado";
    } else if (safePaid > 0) {
      status = "parcial";
    } else if (date.isBefore(DateTime.now())) {
      status = "vencida";
    }
    return InstallmentModel(
      installmentNumber: index,
      amount: amount,
      dueDate: DateFormat('yyyy-MM-dd').format(date),
      status: status,
      montoPagado: safePaid,
    );
  }

  void _recalculateMultipleInstallments({String? customFeedback}) {
    double amount = double.tryParse(_amountCtrl.text) ?? 0.0;
    if (amount <= 0) {
      _installments.clear();
      _installmentShiftReasons.clear();
      _scheduleUpdateFeedback = null;
      _saveCurrentDraft();
      return;
    }

    double interestRate = double.tryParse(_interestCtrl.text) ?? 0.0;
    double finalDebt = amount + (amount * interestRate / 100);

    int numCuotas = int.tryParse(_numCuotasCtrl.text) ?? 2;
    if (numCuotas < 2) numCuotas = 2;

    final Map<int, double> existingPaid = {
      for (var c in _installments) c.installmentNumber: c.montoPagado
    };

    double basePerQuota = finalDebt / numCuotas;
    _installments.clear();
    _installmentShiftReasons.clear();

    double accumulated = 0;
    int shiftedSundaysCount = 0;
    DateTime prevDate = _startDate;

    if (_frecuencia == "diario") {
      // 1. DIARIO: Día por día saltando días excluidos
      DateTime current = _startDate;
      for (int i = 1; i <= numCuotas; i++) {
        DateTime rawCandidate = current.add(const Duration(days: 1));
        DateTime quotaDate = rawCandidate;
        bool wasShifted = false;
        String shiftReason = 'Día hábil';

        while (_excludedWeekdays.contains(quotaDate.weekday)) {
          if (quotaDate.weekday == DateTime.sunday) {
            shiftedSundaysCount++;
            shiftReason = 'Dom omitido';
          } else if (quotaDate.weekday == DateTime.saturday) {
            shiftReason = 'Sáb omitido';
          }
          wasShifted = true;
          quotaDate = quotaDate.add(const Duration(days: 1));
        }

        if (wasShifted) {
          _installmentShiftReasons[i] = shiftReason;
        }

        current = quotaDate;
        prevDate = quotaDate;

        double amt = (i == numCuotas)
            ? double.parse((finalDebt - accumulated).toStringAsFixed(2))
            : double.parse(basePerQuota.toStringAsFixed(2));
        accumulated += amt;

        _installments.add(_buildRecalculatedInstallment(
          index: i,
          amount: amt,
          date: quotaDate,
          existingPaid: existingPaid,
        ));
      }
    } else if (_frecuencia == "semanal") {
      // 2. SEMANAL: Correr cuota si cae en día excluido y avanzar de 7 en 7
      DateTime firstRaw = _startDate.add(const Duration(days: 7));
      DateTime firstValid = firstRaw;
      bool firstShifted = false;
      String firstReason = 'Día hábil';

      while (_excludedWeekdays.contains(firstValid.weekday)) {
        if (firstValid.weekday == DateTime.sunday) {
          shiftedSundaysCount++;
          firstReason = 'Dom omitido';
        } else if (firstValid.weekday == DateTime.saturday) {
          firstReason = 'Sáb omitido';
        }
        firstShifted = true;
        firstValid = firstValid.add(const Duration(days: 1));
      }

      for (int i = 1; i <= numCuotas; i++) {
        DateTime quotaDate;
        if (i == 1) {
          quotaDate = firstValid;
          if (firstShifted) {
            _installmentShiftReasons[1] = firstReason;
          }
        } else {
          DateTime rawWeekly = firstValid.add(Duration(days: 7 * (i - 1)));
          quotaDate = rawWeekly;
          bool wasShifted = false;
          String shiftReason = 'Día hábil';

          while (_excludedWeekdays.contains(quotaDate.weekday)) {
            if (quotaDate.weekday == DateTime.sunday) {
              shiftedSundaysCount++;
              shiftReason = 'Dom omitido';
            } else if (quotaDate.weekday == DateTime.saturday) {
              shiftReason = 'Sáb omitido';
            }
            wasShifted = true;
            quotaDate = quotaDate.add(const Duration(days: 1));
          }

          if (wasShifted) {
            _installmentShiftReasons[i] = shiftReason;
          }
        }

        if (i > 1 && !quotaDate.isAfter(prevDate)) {
          quotaDate = prevDate.add(const Duration(days: 1));
          while (_excludedWeekdays.contains(quotaDate.weekday)) {
            quotaDate = quotaDate.add(const Duration(days: 1));
          }
        }
        prevDate = quotaDate;

        double amt = (i == numCuotas)
            ? double.parse((finalDebt - accumulated).toStringAsFixed(2))
            : double.parse(basePerQuota.toStringAsFixed(2));
        accumulated += amt;

        _installments.add(_buildRecalculatedInstallment(
          index: i,
          amount: amt,
          date: quotaDate,
          existingPaid: existingPaid,
        ));
      }
    } else if (_frecuencia == "quincenal") {
      // 3. QUINCENAL: Fecha ancla (_startDate + 15 * i días) sin deriva
      for (int i = 1; i <= numCuotas; i++) {
        DateTime theoreticalDate = _startDate.add(Duration(days: 15 * i));
        DateTime quotaDate = theoreticalDate;
        bool wasShifted = false;
        String shiftReason = 'Día hábil';

        while (_excludedWeekdays.contains(quotaDate.weekday)) {
          if (quotaDate.weekday == DateTime.sunday) {
            shiftedSundaysCount++;
            shiftReason = 'Dom omitido';
          } else if (quotaDate.weekday == DateTime.saturday) {
            shiftReason = 'Sáb omitido';
          }
          wasShifted = true;
          quotaDate = quotaDate.add(const Duration(days: 1));
        }

        if (wasShifted) {
          _installmentShiftReasons[i] = shiftReason;
        }

        if (i > 1 && !quotaDate.isAfter(prevDate)) {
          quotaDate = prevDate.add(const Duration(days: 1));
          while (_excludedWeekdays.contains(quotaDate.weekday)) {
            quotaDate = quotaDate.add(const Duration(days: 1));
          }
        }
        prevDate = quotaDate;

        double amt = (i == numCuotas)
            ? double.parse((finalDebt - accumulated).toStringAsFixed(2))
            : double.parse(basePerQuota.toStringAsFixed(2));
        accumulated += amt;

        _installments.add(_buildRecalculatedInstallment(
          index: i,
          amount: amt,
          date: quotaDate,
          existingPaid: existingPaid,
        ));
      }
    } else {
      // 4. MENSUAL: Fecha ancla (_addMonthsClamped(_startDate, i)) sin deriva
      for (int i = 1; i <= numCuotas; i++) {
        DateTime theoreticalDate = _addMonthsClamped(_startDate, i);
        DateTime quotaDate = theoreticalDate;
        bool wasShifted = false;
        String shiftReason = 'Día hábil';

        while (_excludedWeekdays.contains(quotaDate.weekday)) {
          if (quotaDate.weekday == DateTime.sunday) {
            shiftedSundaysCount++;
            shiftReason = 'Dom omitido';
          } else if (quotaDate.weekday == DateTime.saturday) {
            shiftReason = 'Sáb omitido';
          }
          wasShifted = true;
          quotaDate = quotaDate.add(const Duration(days: 1));
        }

        if (wasShifted) {
          _installmentShiftReasons[i] = shiftReason;
        }

        if (i > 1 && !quotaDate.isAfter(prevDate)) {
          quotaDate = prevDate.add(const Duration(days: 1));
          while (_excludedWeekdays.contains(quotaDate.weekday)) {
            quotaDate = quotaDate.add(const Duration(days: 1));
          }
        }
        prevDate = quotaDate;

        double amt = (i == numCuotas)
            ? double.parse((finalDebt - accumulated).toStringAsFixed(2))
            : double.parse(basePerQuota.toStringAsFixed(2));
        accumulated += amt;

        _installments.add(_buildRecalculatedInstallment(
          index: i,
          amount: amt,
          date: quotaDate,
          existingPaid: existingPaid,
        ));
      }
    }

    if (customFeedback != null) {
      _scheduleUpdateFeedback = customFeedback;
    } else {
      if (_excludedWeekdays.length == 1 &&
          _excludedWeekdays.contains(DateTime.sunday)) {
        _scheduleUpdateFeedback = shiftedSundaysCount > 0
            ? "Fechas actualizadas • $shiftedSundaysCount domingo(s) omitido(s)"
            : "Fechas actualizadas • Domingos omitidos";
      } else if (_excludedWeekdays.length == 2 &&
          _excludedWeekdays.contains(DateTime.saturday) &&
          _excludedWeekdays.contains(DateTime.sunday)) {
        _scheduleUpdateFeedback =
            "Fechas actualizadas • Solo cobros de Lunes a Viernes";
      } else if (_excludedWeekdays.isEmpty) {
        _scheduleUpdateFeedback =
            "Fechas restauradas • Cobro todos los días habilitado";
      } else {
        _scheduleUpdateFeedback =
            "Fechas actualizadas • ${7 - _excludedWeekdays.length} días de cobro activos";
      }
    }
    _feedbackTrigger++;
    _saveCurrentDraft();
  }

  Future<void> _selectDueDate(BuildContext context) async {
    final initial = _dueDate.isBefore(DateTime(2015, 1, 1))
        ? DateTime(2015, 1, 1)
        : _dueDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2015, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      locale: const Locale('es', 'ES'),
      builder: (context, child) {
        return Theme(
          data: widget.isDark ? ThemeData.dark() : ThemeData.light(),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _dueDate) {
      setState(() => _dueDate = picked);
      _saveCurrentDraft();
    }
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final initial = _startDate.isBefore(DateTime(2015, 1, 1))
        ? DateTime(2015, 1, 1)
        : _startDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2015, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      locale: const Locale('es', 'ES'),
      builder: (context, child) {
        return Theme(
          data: widget.isDark ? ThemeData.dark() : ThemeData.light(),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
        _recalculateMultipleInstallments();
      });
    }
  }

  Future<void> _selectLoanEmissionDate(BuildContext context) async {
    final initial = _loanEmissionDate.isBefore(DateTime(2015, 1, 1))
        ? DateTime(2015, 1, 1)
        : _loanEmissionDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2015, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('es', 'ES'),
      builder: (context, child) {
        return Theme(
          data: widget.isDark ? ThemeData.dark() : ThemeData.light(),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _loanEmissionDate) {
      setState(() {
        _loanEmissionDate = picked;
        if (_startDate.isBefore(picked) ||
            _startDate.difference(picked).inDays.abs() > 30) {
          _startDate = picked;
          if (_splitInQuotas) {
            _recalculateMultipleInstallments();
          }
        }
        if (_dueDate.isBefore(picked)) {
          _dueDate = picked.add(const Duration(days: 30));
        }
      });
      _saveCurrentDraft();
    }
  }

  Future<void> _editInstallmentDate(int index) async {
    final current =
        DateTime.tryParse(_installments[index].dueDate) ?? DateTime.now();
    final minDate = index == 0
        ? _startDate
        : (DateTime.tryParse(_installments[index - 1].dueDate)
                ?.add(const Duration(days: 1)) ??
            _startDate);
    final initialDate = current.isBefore(minDate) ? minDate : current;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2015, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      locale: const Locale('es', 'ES'),
      builder: (context, child) {
        return Theme(
          data: widget.isDark ? ThemeData.dark() : ThemeData.light(),
          child: child!,
        );
      },
    );
    if (picked != null) {
      _applyCascadeDateChange(index, picked);
    }
  }

  /// Acción de saltar día (postergar 1 día hábil la cuota) y recalcular en cascada
  void _skipDayForInstallment(int index) {
    final current =
        DateTime.tryParse(_installments[index].dueDate) ?? DateTime.now();
    DateTime nextValid = current.add(const Duration(days: 1));
    while (_excludedWeekdays.contains(nextValid.weekday)) {
      nextValid = nextValid.add(const Duration(days: 1));
    }
    _applyCascadeDateChange(index, nextValid);
  }

  /// 🔄 CASCADA ESTRICTA: Aplica una nueva fecha a la cuota #index y recalcula todas
  /// las cuotas posteriores garantizando fecha[i] > fecha[i-1] sin fechas repetidas.
  void _applyCascadeDateChange(int fromIndex, DateTime newDate) {
    setState(() {
      DateTime validDate = newDate;
      while (_excludedWeekdays.contains(validDate.weekday)) {
        validDate = validDate.add(const Duration(days: 1));
      }

      final current = _installments[fromIndex];
      String status = current.status;
      if (current.montoPagado >= current.amount && current.amount > 0) {
        status = 'pagado';
      } else if (current.montoPagado > 0) {
        status = 'parcial';
      } else if (validDate.isBefore(DateTime.now())) {
        status = 'vencida';
      } else {
        status = 'pendiente';
      }

      _installments[fromIndex] = InstallmentModel(
        installmentNumber: current.installmentNumber,
        amount: current.amount,
        dueDate: DateFormat('yyyy-MM-dd').format(validDate),
        status: status,
        montoPagado: current.montoPagado,
      );

      DateTime prev = validDate;
      for (int i = fromIndex + 1; i < _installments.length; i++) {
        DateTime next = _advanceDateSkippingExcluded(prev);
        if (!next.isAfter(prev)) {
          next = prev.add(const Duration(days: 1));
          while (_excludedWeekdays.contains(next.weekday)) {
            next = next.add(const Duration(days: 1));
          }
        }
        prev = next;
        final c = _installments[i];
        String cStatus = c.status;
        if (c.montoPagado >= c.amount && c.amount > 0) {
          cStatus = 'pagado';
        } else if (c.montoPagado > 0) {
          cStatus = 'parcial';
        } else if (next.isBefore(DateTime.now())) {
          cStatus = 'vencida';
        } else {
          cStatus = 'pendiente';
        }

        _installments[i] = InstallmentModel(
          installmentNumber: c.installmentNumber,
          amount: c.amount,
          dueDate: DateFormat('yyyy-MM-dd').format(next),
          status: cStatus,
          montoPagado: c.montoPagado,
        );
      }
      _scheduleUpdateFeedback =
          "Cuota #${fromIndex + 1} actualizada • Cuotas siguientes corridas en cascada";
      _feedbackTrigger++;
    });
    _saveCurrentDraft();
  }

  void _showInstallmentStatusDialog(int index) {
    final current = _installments[index];
    final amount = current.amount;

    final d = DateTime.tryParse(current.dueDate) ?? DateTime.now();
    final today = DateTime.now();
    final todayClean = DateTime(today.year, today.month, today.day);
    final dClean = DateTime(d.year, d.month, d.day);
    final bool isOverdue = dClean.isBefore(todayClean);

    int selectedOption = 0;
    if (current.montoPagado >= amount && amount > 0) {
      selectedOption = 1;
    } else if (current.montoPagado > 0) {
      selectedOption = 2;
    } else {
      selectedOption = 0;
    }

    final TextEditingController paidCtrl = TextEditingController(
      text: current.montoPagado > 0
          ? current.montoPagado.toStringAsFixed(2)
          : '',
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final double currentPaid = double.tryParse(paidCtrl.text.replaceAll(',', '.')) ?? 0.0;
            final double remainingToCollect = (amount - currentPaid) > 0 ? (amount - currentPaid) : 0.0;

            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: AlertDialog(
                backgroundColor:
                    widget.isDark ? const Color(0xFF23232F) : Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                title: Text(
                  "Estado Cuota #${current.installmentNumber} (${AppCurrency.format(amount)})",
                  style: TextStyle(
                    color: widget.isDark ? Colors.white : Colors.black87,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Si este préstamo es histórico o ya se amortizó parte de esta cuota, define su estado actual:",
                        style: TextStyle(
                          fontSize: 13,
                          color: widget.isDark
                              ? Colors.grey[400]
                              : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Tarjeta 1: Pendiente / Vencida
                      InkWell(
                        onTap: () {
                          setDialogState(() {
                            selectedOption = 0;
                            paidCtrl.clear();
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: selectedOption == 0
                                ? (isOverdue ? Colors.red.withValues(alpha: 0.12) : Colors.amber.withValues(alpha: 0.12))
                                : (widget.isDark ? Colors.white10 : Colors.grey[100]),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selectedOption == 0
                                  ? (isOverdue ? Colors.redAccent : Colors.amber[700]!)
                                  : (widget.isDark ? Colors.white12 : Colors.grey.shade300),
                              width: selectedOption == 0 ? 1.8 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isOverdue ? Icons.warning_amber_rounded : Icons.schedule_rounded,
                                color: isOverdue ? Colors.redAccent : Colors.amber[700],
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isOverdue ? "Vencida / Sin Pagar" : "Pendiente / Sin Pagar",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.5,
                                        color: widget.isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "Monto abonado: S/ 0.00",
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (selectedOption == 0)
                                Icon(Icons.check_circle_rounded,
                                    color: isOverdue ? Colors.redAccent : Colors.amber[700], size: 18),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Tarjeta 2: Ya Pagada Totalmente
                      InkWell(
                        onTap: () {
                          setDialogState(() {
                            selectedOption = 1;
                            paidCtrl.text = amount.toStringAsFixed(2);
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: selectedOption == 1
                                ? Colors.green.withValues(alpha: 0.12)
                                : (widget.isDark ? Colors.white10 : Colors.grey[100]),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selectedOption == 1
                                  ? Colors.green
                                  : (widget.isDark ? Colors.white12 : Colors.grey.shade300),
                              width: selectedOption == 1 ? 1.8 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Colors.green, size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Ya Pagada Totalmente",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.5,
                                        color: widget.isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "Monto abonado: ${AppCurrency.format(amount)}",
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (selectedOption == 1)
                                const Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Tarjeta 3: Pago Parcial / Abono
                      InkWell(
                        onTap: () {
                          setDialogState(() {
                            selectedOption = 2;
                            if (paidCtrl.text.isEmpty || currentPaid >= amount) {
                              paidCtrl.text = (amount * 0.5).toStringAsFixed(2);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: selectedOption == 2
                                ? Colors.blue.withValues(alpha: 0.12)
                                : (widget.isDark ? Colors.white10 : Colors.grey[100]),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selectedOption == 2
                                  ? Colors.blue
                                  : (widget.isDark ? Colors.white12 : Colors.grey.shade300),
                              width: selectedOption == 2 ? 1.8 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.payments_rounded, color: Colors.blue, size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Pago Parcial / Abono",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13.5,
                                        color: widget.isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "Ingresa el monto amortizado hasta la fecha",
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (selectedOption == 2)
                                const Icon(Icons.check_circle_rounded, color: Colors.blue, size: 18),
                            ],
                          ),
                        ),
                      ),

                      // Sección Condicional Animada para Pago Parcial (Solo visible si selectedOption == 2)
                      AnimatedSize(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        child: selectedOption == 2
                            ? Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextField(
                                      controller: paidCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.allow(
                                            RegExp(r'^\d*\.?\d{0,2}'))
                                      ],
                                      onChanged: (_) => setDialogState(() {}),
                                      onTapOutside: (_) =>
                                          FocusManager.instance.primaryFocus?.unfocus(),
                                      decoration: InputDecoration(
                                        labelText: "Monto Abonado",
                                        prefixText: "S/ ",
                                        hintText: "0.00",
                                        filled: true,
                                        fillColor: widget.isDark
                                            ? const Color(0xFF14141C)
                                            : Colors.grey[100],
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            borderSide: BorderSide.none),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 12),
                                        isDense: true,
                                      ),
                                    ),
                                    const SizedBox(height: 8),

                                    // Chips rápidos de porcentaje 25%, 50%, 75%
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ActionChip(
                                            label: const Center(
                                              child: Text("25%",
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 4, vertical: 0),
                                            visualDensity:
                                                VisualDensity.compact,
                                            onPressed: () {
                                              double v = double.parse(
                                                  (amount * 0.25)
                                                      .toStringAsFixed(2));
                                              paidCtrl.text =
                                                  v.toStringAsFixed(2);
                                              setDialogState(() {});
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: ActionChip(
                                            label: const Center(
                                              child: Text("50%",
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 4, vertical: 0),
                                            visualDensity:
                                                VisualDensity.compact,
                                            onPressed: () {
                                              double v = double.parse(
                                                  (amount * 0.50)
                                                      .toStringAsFixed(2));
                                              paidCtrl.text =
                                                  v.toStringAsFixed(2);
                                              setDialogState(() {});
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: ActionChip(
                                            label: const Center(
                                              child: Text("75%",
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 4, vertical: 0),
                                            visualDensity:
                                                VisualDensity.compact,
                                            onPressed: () {
                                              double v = double.parse(
                                                  (amount * 0.75)
                                                      .toStringAsFixed(2));
                                              paidCtrl.text =
                                                  v.toStringAsFixed(2);
                                              setDialogState(() {});
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // Resumen en vivo
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: widget.isDark
                                            ? Colors.black26
                                            : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: widget.isDark
                                              ? Colors.white12
                                              : Colors.grey.shade300,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                "Abonado: ${AppCurrency.format(currentPaid)}",
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.green,
                                                ),
                                              ),
                                              Text(
                                                "Resta: ${AppCurrency.format(remainingToCollect)}",
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: remainingToCollect > 0
                                                      ? Colors.orange[800]
                                                      : Colors.green,
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (currentPaid >= amount && amount > 0) ...[
                                            const SizedBox(height: 4),
                                            const Text(
                                              "El abono cubre el total de la cuota (se registrará como Pagada).",
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Cancelar",
                        style: TextStyle(color: Colors.grey)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      double finalPaid = 0.0;
                      String finalStatus = 'pendiente';

                      if (selectedOption == 0) {
                        finalPaid = 0.0;
                        finalStatus = isOverdue ? 'vencida' : 'pendiente';
                      } else if (selectedOption == 1) {
                        finalPaid = amount;
                        finalStatus = 'pagado';
                      } else {
                        double p = double.tryParse(paidCtrl.text.replaceAll(',', '.')) ?? 0.0;
                        if (p >= amount && amount > 0) {
                          finalPaid = amount;
                          finalStatus = 'pagado';
                        } else if (p > 0) {
                          finalPaid = p;
                          finalStatus = 'parcial';
                        } else {
                          finalPaid = 0.0;
                          finalStatus = isOverdue ? 'vencida' : 'pendiente';
                        }
                      }

                      setState(() {
                        _installments[index] = current.copyWith(
                          montoPagado: finalPaid,
                          status: finalStatus,
                        );
                      });
                      _saveCurrentDraft();
                      Navigator.pop(ctx);
                    },
                    child: const Text("Aplicar",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showOneQuotaPartialDialog(double enteredAmount) {
    final ctrl = TextEditingController(
      text: _oneQuotaPaidAmount > 0
          ? _oneQuotaPaidAmount.toStringAsFixed(2)
          : '',
    );
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final double p = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0.0;
          final double remaining = (enteredAmount - p) > 0 ? (enteredAmount - p) : 0.0;

          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: AlertDialog(
              backgroundColor:
                  widget.isDark ? const Color(0xFF23232F) : Colors.white,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text("Abono / Pago Parcial Histórico",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Indica el monto que ya fue amortizado de este préstamo de ${AppCurrency.format(enteredAmount)}:",
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ctrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))
                    ],
                    onChanged: (_) => setDialogState(() {}),
                    onTapOutside: (_) =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    decoration: InputDecoration(
                      labelText: "Monto Abonado",
                      prefixText: "S/ ",
                      hintText: "0.00",
                      filled: true,
                      fillColor: widget.isDark
                          ? const Color(0xFF14141C)
                          : Colors.grey[100],
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ActionChip(
                          label: const Center(
                            child: Text("25%",
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 0),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            double v = double.parse(
                                (enteredAmount * 0.25).toStringAsFixed(2));
                            ctrl.text = v.toStringAsFixed(2);
                            setDialogState(() {});
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ActionChip(
                          label: const Center(
                            child: Text("50%",
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 0),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            double v = double.parse(
                                (enteredAmount * 0.50).toStringAsFixed(2));
                            ctrl.text = v.toStringAsFixed(2);
                            setDialogState(() {});
                          },
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: ActionChip(
                          label: const Center(
                            child: Text("75%",
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 0),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            double v = double.parse(
                                (enteredAmount * 0.75).toStringAsFixed(2));
                            ctrl.text = v.toStringAsFixed(2);
                            setDialogState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? Colors.black26
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: widget.isDark
                            ? Colors.white12
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Abonado: ${AppCurrency.format(p)}",
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        Text(
                          "Resta: ${AppCurrency.format(remaining)}",
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: remaining > 0
                                ? Colors.orange[800]
                                : Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child:
                      const Text("Cancelar", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[800],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    double finalPaid = double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0.0;
                    if (finalPaid > enteredAmount) finalPaid = enteredAmount;
                    setState(() {
                      _oneQuotaPaidAmount = finalPaid;
                      if (finalPaid >= enteredAmount && enteredAmount > 0) {
                        _oneQuotaStatus = 'pagado';
                      } else if (finalPaid > 0) {
                        _oneQuotaStatus = 'parcial';
                      } else {
                        _oneQuotaStatus =
                            _dueDate.isBefore(DateTime.now()) ? 'vencida' : 'pendiente';
                      }
                    });
                    _saveCurrentDraft();
                    Navigator.pop(ctx);
                  },
                  child: const Text("Guardar"),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // =========================================================================
  // ENVÍO Y PERSISTENCIA EN SQLITE
  // =========================================================================

  void _submitAction(TrackingProvider provider) {
    double amount = double.tryParse(_amountCtrl.text) ?? 0.0;
    if (amount <= 0) {
      CustomSnackBar.show(context,
          message: "Ingresa un monto válido mayor a 0", isError: true);
      return;
    }

    if (_tabController.index == 1) {
      // Retiro de saldo
      if (amount > widget.client.saldoAFavor) {
        CustomSnackBar.show(context,
            message: "El monto supera el saldo a favor disponible",
            isError: true);
        return;
      }
      _executeSubmitWithdrawal(provider, amount);
    } else {
      // Préstamo (Tab 0)
      String motivo = _noteCtrl.text.trim();
      if (motivo.isEmpty) {
        motivo = "Préstamo personal";
      }

      double interestRate = _splitInQuotas
          ? (double.tryParse(_interestCtrl.text) ?? 0.0)
          : 0.0;

      List<InstallmentModel> finalInstallments = [];
      if (_splitInQuotas && _installments.isNotEmpty) {
        finalInstallments = List.from(_installments);
      } else {
        String status = _oneQuotaStatus;
        if (_oneQuotaPaidAmount >= amount && amount > 0) {
          status = "pagado";
        } else if (_oneQuotaPaidAmount > 0) {
          status = "parcial";
        } else if (_dueDate.isBefore(DateTime.now())) {
          status = "vencida";
        } else {
          status = "pendiente";
        }
        finalInstallments = [
          InstallmentModel(
            installmentNumber: 1,
            amount: amount,
            dueDate: DateFormat('yyyy-MM-dd').format(_dueDate),
            status: status,
            montoPagado: _oneQuotaPaidAmount,
          ),
        ];
      }

      double finalDebt =
          finalInstallments.fold(0.0, (sum, c) => sum + c.amount);
      _showPreConfirmDialog(provider, amount, interestRate, finalDebt, motivo,
          finalInstallments);
    }
  }

  Future<void> _executeSubmitWithdrawal(
      TrackingProvider provider, double amount) async {
    setState(() => _isLoading = true);
    bool ok = await provider.withdrawBalance(
        widget.client.id, amount, _withdrawMethod);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (ok) {
      ClientFinanceDraftManager.instance
          .clearWithdrawDraft(widget.client.id);
      CustomSnackBar.show(context,
          message: "Retiro registrado correctamente");
      Navigator.pop(context);
    }
  }

  Future<void> _executeSubmitLoan(
    TrackingProvider provider,
    double amount,
    double interestRate,
    double finalDebt,
    String motivo,
    List<InstallmentModel> installments,
  ) async {
    setState(() => _isLoading = true);
    bool ok = await provider.registerLoan(
      widget.client.id,
      amount,
      motivo,
      interestRate: interestRate,
      metodoPago: _loanMethod,
      installments: installments,
      loanDate: _loanEmissionDate,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (ok) {
      ClientFinanceDraftManager.instance.clearLoanDraft(widget.client.id);
      CustomSnackBar.show(context,
          message: "Préstamo registrado correctamente");
      Navigator.pop(context);
    }
  }

  void _showPreConfirmDialog(
    TrackingProvider provider,
    double amount,
    double interestRate,
    double finalDebt,
    String motivo,
    List<InstallmentModel> installments,
  ) {
    final double totalAmortizado =
        installments.fold(0.0, (sum, c) => sum + c.montoPagado);
    final double saldoDeudorInicial =
        (finalDebt - totalAmortizado).clamp(0.0, double.infinity);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:
            widget.isDark ? const Color(0xFF23232F) : Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.account_balance,
                color: widget.isDark
                    ? Colors.orange[300]
                    : Colors.orange[800],
                size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Confirmar Préstamo",
                style: TextStyle(
                  color: widget.isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSummaryRow("Fecha Emisión:",
                    _formatDateSpanish(_loanEmissionDate)),
                _buildSummaryRow("Monto Base:", AppCurrency.format(amount)),
                if (interestRate > 0)
                  _buildSummaryRow(
                    "Interés (${interestRate.toStringAsFixed(1)}%):",
                    AppCurrency.format(finalDebt - amount),
                  ),
                const Divider(),
                _buildSummaryRow("Total Préstamo:",
                    AppCurrency.format(finalDebt),
                    isBold: true),
                if (totalAmortizado > 0) ...[
                  _buildSummaryRow("Amortizado Histórico:",
                      AppCurrency.format(totalAmortizado)),
                  _buildSummaryRow("Saldo Deudor Inicial:",
                      AppCurrency.format(saldoDeudorInicial),
                      isBold: true),
                ],
                const SizedBox(height: 8),
                _buildSummaryRow("Motivo:", motivo),
                _buildSummaryRow("Entrega en:", _loanMethod),
                const SizedBox(height: 16),
                Text(
                  "Cronograma de Cuotas (${installments.length}):",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: widget.isDark
                        ? Colors.grey[300]
                        : Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? const Color(0xFF1A1A24)
                        : Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: widget.isDark
                            ? Colors.white10
                            : Colors.grey.shade200),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: installments.length,
                    separatorBuilder: (_, __) => Divider(
                        height: 1,
                        color: widget.isDark
                            ? Colors.white10
                            : Colors.grey[200]),
                    itemBuilder: (ctx, i) {
                      final c = installments[i];
                      final d = DateTime.tryParse(c.dueDate) ?? DateTime.now();
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                "Cuota ${c.installmentNumber} • ${_formatDateSpanish(d)}",
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: widget.isDark
                                      ? Colors.grey[300]
                                      : Colors.grey[800],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  AppCurrency.format(c.amount),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5,
                                    color: widget.isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                _buildConfirmQuotaBadge(c, d),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Revisar", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.isDark
                  ? Colors.orange[800]
                  : Colors.orange[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _executeSubmitLoan(provider, amount, interestRate, finalDebt,
                  motivo, installments);
            },
            child: const Text("Confirmar y Guardar",
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              fontSize: isBold ? 16 : 14,
              color: isBold
                  ? (widget.isDark ? Colors.orange[300] : Colors.orange[800])
                  : (widget.isDark ? Colors.white : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmQuotaBadge(InstallmentModel c, DateTime d) {
    if (c.montoPagado >= c.amount && c.amount > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 10, color: Colors.green),
            SizedBox(width: 3),
            Text(
              "Pagada",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
      );
    } else if (c.montoPagado > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.pie_chart_outline, size: 10, color: Colors.blue),
            const SizedBox(width: 3),
            Text(
              "Abono: ${AppCurrency.format(c.montoPagado)}",
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ],
        ),
      );
    } else if (d.isBefore(DateTime.now())) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 10, color: Colors.redAccent),
            SizedBox(width: 3),
            Text(
              "Vencida",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          "Pendiente",
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: widget.isDark ? Colors.grey[400] : Colors.grey[700],
          ),
        ),
      );
    }
  }

  Widget _buildDynamicContextualCard(
    bool isDark,
    double enteredAmount,
    TrackingProvider provider,
  ) {
    final bool isLoan = _tabController.index == 0;

    if (isLoan) {
      // 1. Detección de cuotas vencidas en tiempo real
      int overdueCount = 0;
      final today = DateTime.now();
      final todayClean = DateTime(today.year, today.month, today.day);
      for (final sale in provider.currentClientDebts) {
        if (sale.isArchived) continue;
        for (final c in sale.installments) {
          if (c.status != 'pagado' && c.status != 'anulada') {
            final due = DateTime.tryParse(c.dueDate);
            if (due != null) {
              final dueClean = DateTime(due.year, due.month, due.day);
              if (dueClean.isBefore(todayClean)) {
                overdueCount++;
              }
            }
          }
        }
      }

      final double suggestedLimit = widget.client.tier.limiteCreditoSugerido;

      if (overdueCount > 0) {
        // Mora activa detectada: límite congelado y advertencia
        final subtitle = enteredAmount > 0
            ? "Atención: ${widget.client.fullName} tiene $overdueCount ${overdueCount == 1 ? 'cuota vencida' : 'cuotas vencidas'}. Estás por otorgar un préstamo adicional a un cliente con mora activa."
            : "El cliente tiene $overdueCount ${overdueCount == 1 ? 'cuota vencida' : 'cuotas vencidas'}. Su límite de crédito sugerido está suspendido en S/ 0.00 hasta regularizar su deuda.";

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF3B1E22) : const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.red.withValues(alpha: 0.5) : const Color(0xFFFECACA),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 20, color: Colors.redAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Límite Congelado: S/ 0.00 (Mora Activa)",
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFFF8A80) : const Color(0xFF991B1B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.25,
                        color: isDark ? Colors.grey[300] : const Color(0xFF7F1D1D),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }

      if (enteredAmount <= 0) {
        // Al día, sin monto ingresado: resumen de nivel y racha
        final subtitle = widget.client.rachaPagosPuntuales > 0
            ? "Cliente puntual con racha de ${widget.client.rachaPagosPuntuales} pagos a tiempo. Recomendado para operaciones de confianza."
            : "Cliente sin historial de atrasos. Se sugiere iniciar con operaciones prudentes dentro de su tope base.";

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF282837) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, size: 20, color: Color(widget.client.tier.colorHex)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Límite de Crédito Sugerido (${widget.client.tier.badgeText}): ${AppCurrency.format(suggestedLimit)}",
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey[200] : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.25,
                        color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }

      if (enteredAmount <= suggestedLimit) {
        // Al día, monto dentro del rango seguro
        final restan = suggestedLimit - enteredAmount;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF132D21) : const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.green.withValues(alpha: 0.5) : const Color(0xFFBBF7D0),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.check_circle_outline_rounded,
                  size: 20, color: isDark ? Colors.greenAccent : const Color(0xFF16A34A)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Monto Dentro del Rango Seguro (${widget.client.tier.badgeText})",
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.greenAccent : const Color(0xFF166534),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Monto dentro del rango seguro recomendado para ${widget.client.fullName}. Restan ${AppCurrency.format(restan)} de su tope sugerido.",
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.25,
                        color: isDark ? Colors.grey[300] : const Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }

      // Al día, monto excede límite
      final exceso = enteredAmount - suggestedLimit;
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF382914) : const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.amber.withValues(alpha: 0.5) : const Color(0xFFFDE68A),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded,
                size: 20, color: isDark ? Colors.amberAccent : const Color(0xFFD97706)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Atención: Excede Límite Recomendado (${widget.client.tier.badgeText})",
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.amberAccent : const Color(0xFFB45309),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "El monto ingresado excede por ${AppCurrency.format(exceso)} el límite sugerido de ${AppCurrency.format(suggestedLimit)}. Evalúa la capacidad de pago del cliente.",
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.25,
                      color: isDark ? Colors.grey[300] : const Color(0xFF92400E),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Pestaña Retirar Saldo (Tab 1)
    if (widget.client.saldoAFavor <= 0.01) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF282837) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.account_balance_wallet_outlined, size: 20, color: Colors.grey),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Sin Saldo a Favor Disponible",
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.grey[300] : const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "${widget.client.fullName} no cuenta con saldo a favor para retiros en este momento.",
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.25,
                      color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (enteredAmount <= 0) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF132D2D) : const Color(0xFFF0FDFA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.teal.withValues(alpha: 0.5) : const Color(0xFF99F6E4),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.account_balance_wallet_rounded, size: 20, color: Colors.teal),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Saldo a Favor Disponible: ${AppCurrency.format(widget.client.saldoAFavor)}",
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.tealAccent : const Color(0xFF0F766E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Puedes registrar el desembolso total o parcial del saldo a favor de ${widget.client.fullName}.",
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.25,
                      color: isDark ? Colors.grey[300] : const Color(0xFF115E59),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (enteredAmount <= widget.client.saldoAFavor) {
      final rem = widget.client.saldoAFavor - enteredAmount;
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF132D21) : const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.green.withValues(alpha: 0.5) : const Color(0xFFBBF7D0),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.check_circle_outline_rounded,
                size: 20, color: isDark ? Colors.greenAccent : const Color(0xFF16A34A)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Retiro Válido: ${AppCurrency.format(enteredAmount)}",
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.greenAccent : const Color(0xFF166534),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "Tras este retiro, el nuevo saldo a favor de ${widget.client.fullName} será de ${AppCurrency.format(rem)}.",
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.25,
                      color: isDark ? Colors.grey[300] : const Color(0xFF15803D),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Excede saldo disponible
    final exceso = enteredAmount - widget.client.saldoAFavor;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3B1E22) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.red.withValues(alpha: 0.5) : const Color(0xFFFECACA),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, size: 20, color: Colors.redAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Monto Excede el Saldo Disponible",
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFFFF8A80) : const Color(0xFF991B1B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "No es posible retirar ${AppCurrency.format(enteredAmount)}. El monto supera el saldo disponible por ${AppCurrency.format(exceso)}.",
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.25,
                    color: isDark ? Colors.grey[300] : const Color(0xFF7F1D1D),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // CONSTRUCCIÓN DE LA VISTA
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    final surfaceColor =
        widget.isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = widget.isDark ? Colors.white : Colors.black87;
    final provider = Provider.of<TrackingProvider>(context);

    double enteredAmount = double.tryParse(_amountCtrl.text) ?? 0.0;
    bool isLoanTab = _tabController.index == 0;
    bool isWithdrawTab = _tabController.index == 1;
    bool hasAvailableBalance = widget.client.saldoAFavor > 0.01;

    bool canSubmitWithdraw = isWithdrawTab &&
        hasAvailableBalance &&
        enteredAmount > 0 &&
        enteredAmount <= widget.client.saldoAFavor;
    bool canSubmitLoan = isLoanTab && enteredAmount > 0;
    bool canSubmit = isLoanTab ? canSubmitLoan : canSubmitWithdraw;

    return InteractiveSheetWrapper(
      enableDragToDismiss: false,
      enableHeaderDragToDismiss: true,
      maintainFixedHeightOnKeyboard: true,
      maxHeightFactor: 0.92,
      applyEffectiveBottomPadding: false,
      showHandle: true,
      showCloseButton: true,
      title: "Operaciones Financieras",
      icon: Icons.account_balance_wallet,
      iconColor:
          widget.isDark ? Colors.blueGrey[300] : Colors.blueGrey[700],
      actions: [
        Tooltip(
          message:
              isLoanTab ? "Limpiar préstamo" : "Limpiar retiro",
          child: TextButton.icon(
            icon: const Icon(Icons.cleaning_services_outlined,
                size: 16),
            label: const Text("Limpiar",
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold)),
            style: TextButton.styleFrom(
              foregroundColor:
                  isLoanTab ? Colors.orange[800] : Colors.teal,
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: _cleanActiveTab,
          ),
        ),
      ],
      backgroundColor: surfaceColor,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Column(
          children: [
            const SizedBox(height: 8),

            // Selector de 2 tarjetas interactivas con subtítulos guía
            _buildTopModeSelector(widget.isDark),

            // Tarjeta Contextual Dinámica y Reactiva
            _buildDynamicContextualCard(widget.isDark, enteredAmount, provider),
            const SizedBox(height: 4),

            // TabBarView sin cortes
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLoanTab(textColor, enteredAmount),
                  _buildWithdrawTab(
                      textColor, hasAvailableBalance, enteredAmount),
                ],
              ),
            ),

            // Bottom Action Bar
            Container(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                InteractiveSheetWrapper.getEffectiveBottomPadding(
                  context,
                  minPadding: 28.0,
                ),
              ),
              decoration: BoxDecoration(
                color: surfaceColor,
                border: Border(
                    top: BorderSide(
                        color: widget.isDark
                            ? Colors.white10
                            : Colors.grey.shade200)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: canSubmit && !_isLoading
                      ? () => _submitAction(provider)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isLoanTab ? Colors.orange[800] : Colors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: canSubmit ? 2 : 0,
                    disabledBackgroundColor:
                        widget.isDark ? Colors.white10 : Colors.grey[300],
                    disabledForegroundColor:
                        widget.isDark ? Colors.grey[600] : Colors.grey[500],
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          isLoanTab
                              ? "Registrar Préstamo"
                              : "Confirmar Retiro",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopModeSelector(bool isDark) {
    final isLoan = _tabController.index == 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildSelectorCard(
              title: "Otorgar Préstamo",
              subtitle: "En cuotas o pago único con fechas",
              icon: Icons.account_balance_rounded,
              isSelected: isLoan,
              activeColor: Colors.orange[800]!,
              onTap: () {
                if (_tabController.index != 0) {
                  _tabController.animateTo(0);
                }
              },
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildSelectorCard(
              title: "Retirar Saldo",
              subtitle: "Retiros de saldo a favor o cuenta",
              icon: Icons.savings_outlined,
              isSelected: !isLoan,
              activeColor: Colors.teal,
              onTap: () {
                if (_tabController.index != 1) {
                  _tabController.animateTo(1);
                }
              },
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: isDark ? 0.22 : 0.12)
              : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isDark ? Colors.white12 : Colors.grey.shade300),
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? activeColor : (isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? (isDark ? Colors.white : activeColor)
                            : (isDark ? Colors.grey[300] : Colors.grey[800]),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                height: 1.2,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // TAB 1: RETIRO DE SALDO A FAVOR
  // =========================================================================

  Widget _buildWithdrawTab(
      Color textColor, bool hasAvailableBalance, double enteredAmount) {
    if (!hasAvailableBalance) {
      return Center(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.savings_outlined,
                    color: Colors.teal, size: 40),
              ),
              const SizedBox(height: 18),
              Text(
                "Sin Saldo a Favor Disponible",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Saldo Disponible: ${AppCurrency.format(widget.client.saldoAFavor)}",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.teal,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? const Color(0xFF1A1A24)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.isDark
                        ? Colors.white10
                        : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  "El saldo a favor se genera automáticamente cuando el cliente realiza abonos mayores a su deuda o se le aprueba una devolución de mercadería.\n\nActualmente este cliente no posee saldo a favor acumulado para retirar.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: widget.isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        // Balance Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.teal.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Saldo a Favor Disponible",
                      style: TextStyle(
                        color:
                            widget.isDark ? Colors.teal[200] : Colors.teal[900],
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppCurrency.format(widget.client.saldoAFavor),
                      style: TextStyle(
                        color:
                            widget.isDark ? Colors.teal[300] : Colors.teal[800],
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.account_balance_wallet,
                  color: Colors.teal, size: 36),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Quick action chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: Text(
                  "Retirar Todo (${AppCurrency.format(widget.client.saldoAFavor)})"),
              backgroundColor: widget.isDark
                  ? Colors.teal.withValues(alpha: 0.15)
                  : Colors.teal[50],
              side: BorderSide(color: Colors.teal.withValues(alpha: 0.4)),
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 12, color: Colors.teal),
              onPressed: () {
                _amountCtrl.text =
                    widget.client.saldoAFavor.toStringAsFixed(2);
              },
            ),
            ActionChip(
              label: const Text("Retirar 50%"),
              backgroundColor:
                  widget.isDark ? Colors.white10 : Colors.grey[100],
              side: BorderSide(
                  color: widget.isDark ? Colors.white10 : Colors.grey.shade300),
              labelStyle: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: widget.isDark ? Colors.white70 : Colors.black87,
              ),
              onPressed: () {
                final half = (widget.client.saldoAFavor / 2);
                _amountCtrl.text = half.toStringAsFixed(2);
              },
            ),
          ],
        ),

        const SizedBox(height: 20),

        Text("Monto a Retirar",
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600])),
        const SizedBox(height: 8),
        _buildInputLarge(
            ctrl: _amountCtrl,
            isDark: widget.isDark,
            textColor: textColor,
            isInt: false),

        if (enteredAmount > widget.client.saldoAFavor) ...[
          const SizedBox(height: 6),
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 14, color: Colors.redAccent),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  "El monto supera el saldo disponible para retiro",
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 22),

        Text("Método de entrega",
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600])),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildMethodChip("Efectivo", Icons.money, true),
            _buildMethodChip("Yape", Icons.qr_code_2, true),
            _buildMethodChip("Plin", Icons.qr_code, true),
            _buildMethodChip("Transferencia", Icons.account_balance, true),
          ],
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 2: PRÉSTAMO / FIADO CON MOTOR DE CRONOGRAMA EN CASCADA
  // =========================================================================

  Widget _buildLoanTab(Color textColor, double enteredAmount) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
      children: [
        // Banner informativo
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.orange, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Registrar Préstamo o Venta al Fiado",
                  style: TextStyle(
                    color: widget.isDark
                        ? Colors.orange[200]
                        : Colors.orange[900],
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        Text("Monto del Préstamo",
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600])),
        const SizedBox(height: 8),
        _buildInputLarge(
            ctrl: _amountCtrl,
            isDark: widget.isDark,
            textColor: textColor,
            isInt: false),

        const SizedBox(height: 20),

        Text("Método de entrega",
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600])),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildMethodChip("Efectivo", Icons.money, false),
            _buildMethodChip("Yape", Icons.qr_code_2, false),
            _buildMethodChip("Plin", Icons.qr_code, false),
            _buildMethodChip("Transferencia", Icons.account_balance, false),
          ],
        ),

        const SizedBox(height: 20),

        // Fecha de Emisión / Entrega del Préstamo (desbloqueada desde 2015)
        Text("Fecha de Emisión / Entrega",
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600])),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.isDark
                ? const Color(0xFF14141C)
                : Colors.grey[50],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: widget.isDark
                    ? Colors.white10
                    : Colors.grey.shade300),
          ),
          child: InkWell(
            onTap: () => _selectLoanEmissionDate(context),
            child: Row(
              children: [
                Icon(Icons.calendar_month_outlined,
                    color: widget.isDark
                        ? Colors.orange[300]
                        : Colors.orange[700],
                    size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Fecha de Entrega del Dinero",
                        style: TextStyle(
                            fontSize: 12,
                            color: widget.isDark
                                ? Colors.grey[400]
                                : Colors.grey[600]),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDateSpanish(_loanEmissionDate),
                        style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.edit_calendar,
                    color: widget.isDark
                        ? Colors.orange[300]
                        : Colors.orange[700],
                    size: 20),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Motivo / Detalle (Wrap responsivo sin desbordes horizontales)
        Text("Motivo / Detalle",
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600])),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: _motivosSug.map((motivo) {
              final isSelected = _noteCtrl.text == motivo;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(motivo),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) {
                      _noteCtrl.text = motivo;
                    } else {
                      _noteCtrl.clear();
                    }
                    FocusScope.of(context).unfocus();
                    _saveCurrentDraft();
                    setState(() {});
                  },
                  selectedColor: Colors.orange.withValues(alpha: 0.25),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? Colors.orange
                        : (widget.isDark ? Colors.grey[300] : Colors.grey[800]),
                  ),
                  backgroundColor:
                      widget.isDark ? Colors.white10 : Colors.grey[100],
                  side: BorderSide(
                    color: isSelected
                        ? Colors.orange
                        : (widget.isDark
                            ? Colors.white10
                            : Colors.grey.shade300),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 12),

        TextField(
          controller: _noteCtrl,
          maxLines: 2,
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          style: TextStyle(color: textColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: "Ej. Préstamo personal, Fiado mercadería...",
            hintStyle: TextStyle(
                color: widget.isDark ? Colors.grey[500] : Colors.grey),
            filled: true,
            fillColor:
                widget.isDark ? const Color(0xFF14141C) : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                  color:
                      widget.isDark ? Colors.white10 : Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                  color:
                      widget.isDark ? Colors.white10 : Colors.grey.shade300),
            ),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),

        const SizedBox(height: 22),

        // Fecha de vencimiento para 1 cuota y estado histórico inicial
        if (!_splitInQuotas) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: widget.isDark
                  ? const Color(0xFF14141C)
                  : Colors.grey[50],
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: widget.isDark
                      ? Colors.white10
                      : Colors.grey.shade300),
            ),
            child: InkWell(
              onTap: () => _selectDueDate(context),
              child: Row(
                children: [
                  Icon(Icons.event_available,
                      color: widget.isDark
                          ? Colors.orange[300]
                          : Colors.orange[700],
                      size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Fecha de Vencimiento (1 cuota)",
                          style: TextStyle(
                              fontSize: 12,
                              color: widget.isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600]),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDateSpanish(_dueDate),
                          style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.edit_calendar,
                      color: widget.isDark
                          ? Colors.orange[300]
                          : Colors.orange[700],
                      size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildOneQuotaStatusCard(textColor, enteredAmount),
        ],

        const SizedBox(height: 14),

        // Switch Fraccionamiento
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            "¿Dividir en cuotas o aplicar interés?",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: textColor),
          ),
          subtitle: Text(
            _splitInQuotas
                ? "Fraccionado en cuotas periódicas"
                : "Cuota única al vencimiento",
            style: TextStyle(
                fontSize: 12,
                color:
                    widget.isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
          value: _splitInQuotas,
          activeThumbColor: Colors.orange,
          onChanged: (val) {
            setState(() {
              _splitInQuotas = val;
              if (val) {
                _recalculateMultipleInstallments();
              } else {
                _installments.clear();
              }
              _saveCurrentDraft();
            });
          },
        ),

        // Sección de parámetros de cuotas múltiples
        if (_splitInQuotas) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildInput(
                  label: "N° Cuotas",
                  ctrl: _numCuotasCtrl,
                  isDark: widget.isDark,
                  textColor: textColor,
                  isInt: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _buildInput(
                  label: "Interés",
                  suffix: "%",
                  ctrl: _interestCtrl,
                  isDark: widget.isDark,
                  textColor: textColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  initialValue: _frecuencia,
                  dropdownColor: widget.isDark
                      ? const Color(0xFF23232F)
                      : Colors.white,
                  style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: "Frecuencia",
                    labelStyle: TextStyle(
                        color: widget.isDark
                            ? Colors.grey[400]
                            : Colors.grey[600],
                        fontSize: 13),
                    filled: true,
                    fillColor: widget.isDark
                        ? const Color(0xFF14141C)
                        : Colors.grey[100],
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: "diario", child: Text("Diario")),
                    DropdownMenuItem(
                        value: "semanal", child: Text("Semanal")),
                    DropdownMenuItem(
                        value: "quincenal", child: Text("Quincenal")),
                    DropdownMenuItem(
                        value: "mensual", child: Text("Mensual")),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() {
                        _frecuencia = v;
                        final names = {
                          'diario': 'Diario',
                          'semanal': 'Semanal',
                          'quincenal': 'Quincenal',
                          'mensual': 'Mensual',
                        };
                        _recalculateMultipleInstallments(
                          customFeedback:
                              "Cronograma recalculado • Frecuencia ${names[v] ?? v}",
                        );
                      });
                    }
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Selector de Fecha de Inicio de Cobro
          InkWell(
            onTap: () => _selectStartDate(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: widget.isDark
                    ? const Color(0xFF14141C)
                    : Colors.orange.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded,
                      size: 18,
                      color: widget.isDark
                          ? Colors.orange[300]
                          : Colors.orange[700]),
                  const SizedBox(width: 10),
                  Text(
                    "Fecha Base / Inicio:",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: widget.isDark
                          ? Colors.grey[300]
                          : Colors.grey[700],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDateSpanish(_startDate),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: widget.isDark
                          ? Colors.orange[300]
                          : Colors.orange[800],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.edit_calendar,
                      size: 16,
                      color: widget.isDark
                          ? Colors.orange[300]
                          : Colors.orange[700]),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Selector de Días de Cobro Activos / Excluidos [L] [M] [M] [J] [V] [S] [D]
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Días de Cobro Permitidos",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: widget.isDark
                      ? Colors.grey[300]
                      : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _getFrequencyContextSubtitle(),
                style: TextStyle(
                  fontSize: 11.5,
                  color: widget.isDark
                      ? Colors.grey[400]
                      : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),

              // Fila interactiva de los 7 días
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildWeekdayButton(1, "L", "Lunes"),
                  _buildWeekdayButton(2, "M", "Martes"),
                  _buildWeekdayButton(3, "M", "Miércoles"),
                  _buildWeekdayButton(4, "J", "Jueves"),
                  _buildWeekdayButton(5, "V", "Viernes"),
                  _buildWeekdayButton(6, "S", "Sábado"),
                  _buildWeekdayButton(7, "D", "Domingo"),
                ],
              ),

              const SizedBox(height: 10),

              // Chips de acceso rápido para presets con comportamiento Toggle
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _buildPresetChip(
                    label: "Omitir Domingos",
                    icon: Icons.event_busy_rounded,
                    isSelected: _excludedWeekdays.length == 1 &&
                        _excludedWeekdays.contains(DateTime.sunday),
                    onTap: () {
                      final isCurrentlySelected = _excludedWeekdays.length == 1 &&
                          _excludedWeekdays.contains(DateTime.sunday);
                      setState(() {
                        if (isCurrentlySelected) {
                          // Desmarcar chip -> Restaurar todos los días
                          _excludedWeekdays.clear();
                          _recalculateMultipleInstallments(
                            customFeedback:
                                "Fechas restauradas • Cobro todos los días habilitado",
                          );
                        } else {
                          // Activar Omitir Domingos
                          _excludedWeekdays = {DateTime.sunday};
                          _recalculateMultipleInstallments();
                        }
                      });
                    },
                  ),
                  _buildPresetChip(
                    label: "Solo Lun - Vie",
                    icon: Icons.business_center_outlined,
                    isSelected: _excludedWeekdays.length == 2 &&
                        _excludedWeekdays.contains(DateTime.saturday) &&
                        _excludedWeekdays.contains(DateTime.sunday),
                    onTap: () {
                      final isCurrentlySelected = _excludedWeekdays.length == 2 &&
                          _excludedWeekdays.contains(DateTime.saturday) &&
                          _excludedWeekdays.contains(DateTime.sunday);
                      setState(() {
                        if (isCurrentlySelected) {
                          // Desmarcar chip -> Restaurar todos los días
                          _excludedWeekdays.clear();
                          _recalculateMultipleInstallments(
                            customFeedback:
                                "Fechas restauradas • Cobro todos los días habilitado",
                          );
                        } else {
                          // Activar Solo Lun - Vie
                          _excludedWeekdays = {
                            DateTime.saturday,
                            DateTime.sunday,
                          };
                          _recalculateMultipleInstallments(
                            customFeedback:
                                "Fechas actualizadas • Solo cobros de Lunes a Viernes",
                          );
                        }
                      });
                    },
                  ),
                  _buildPresetChip(
                    label: "Todos los días",
                    icon: Icons.calendar_month_outlined,
                    isSelected: _excludedWeekdays.isEmpty,
                    onTap: () {
                      setState(() {
                        _excludedWeekdays.clear();
                        _recalculateMultipleInstallments(
                          customFeedback:
                              "Fechas restauradas • Cobro todos los días habilitado",
                        );
                      });
                    },
                  ),
                ],
              ),
            ],
          ),

          // Lista de cuotas generadas con soporte para edición y salto de fecha
          if (_installments.isNotEmpty) ...[
            const SizedBox(height: 18),
            Builder(builder: (context) {
              final double totalSched = _installments.fold<double>(
                  0.0, (sum, c) => sum + c.amount);
              final double paidSched = _installments.fold<double>(
                  0.0, (sum, c) => sum + c.montoPagado);
              final double pendingSched =
                  (totalSched - paidSched).clamp(0.0, double.infinity);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text("Cronograma Generado",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: textColor)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "Total: ${AppCurrency.format(totalSched)}",
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Colors.orange),
                        ),
                      ),
                    ],
                  ),
                  if (paidSched > 0) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "Ya Amortizado Histórico: ${AppCurrency.format(paidSched)}",
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            "Saldo Deudor Inicial: ${AppCurrency.format(pendingSched)}",
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              );
            }),
            if (_scheduleUpdateFeedback != null) ...[
              const SizedBox(height: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                transitionBuilder: (child, anim) {
                  return FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, -0.15),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  key: ValueKey("feedback_$_feedbackTrigger"),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: _scheduleUpdateFeedback!.contains("restauradas")
                        ? (widget.isDark
                            ? Colors.teal.withValues(alpha: 0.15)
                            : Colors.teal.shade50)
                        : (widget.isDark
                            ? Colors.amber.withValues(alpha: 0.15)
                            : Colors.amber.shade50),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _scheduleUpdateFeedback!.contains("restauradas")
                          ? (widget.isDark
                              ? Colors.teal.withValues(alpha: 0.4)
                              : Colors.teal.shade300)
                          : (widget.isDark
                              ? Colors.amber.withValues(alpha: 0.4)
                              : Colors.amber.shade300),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _scheduleUpdateFeedback!.contains("restauradas")
                            ? Icons.sync_rounded
                            : Icons.auto_awesome_rounded,
                        size: 15,
                        color: _scheduleUpdateFeedback!.contains("restauradas")
                            ? Colors.teal
                            : (widget.isDark
                                ? Colors.amber[300]
                                : Colors.amber[800]),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _scheduleUpdateFeedback!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _scheduleUpdateFeedback!.contains("restauradas")
                                ? (widget.isDark
                                    ? Colors.teal[200]
                                    : Colors.teal[900])
                                : (widget.isDark
                                    ? Colors.amber[200]
                                    : Colors.amber[900]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: widget.isDark
                    ? const Color(0xFF1A1A24)
                    : Colors.grey[50],
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: widget.isDark
                        ? Colors.white10
                        : Colors.grey.shade200),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: _installments.length,
                separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: widget.isDark
                        ? Colors.white10
                        : Colors.grey[200]),
                itemBuilder: (ctx, i) {
                  final cuota = _installments[i];
                  final dueDate =
                      DateTime.tryParse(cuota.dueDate) ?? DateTime.now();
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 9),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor:
                              Colors.orange.withValues(alpha: 0.2),
                          child: Text(
                            "${cuota.installmentNumber}",
                            style: const TextStyle(
                                fontSize: 10.5,
                                color: Colors.orange,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () => _editInstallmentDate(i),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 4, horizontal: 2),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _formatDateSpanish(dueDate),
                                          style: TextStyle(
                                              color: textColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(Icons.edit_calendar,
                                            size: 14,
                                            color: widget.isDark
                                                ? Colors.blue[300]
                                                : Colors.blue[600]),
                                      ],
                                    ),
                                  ),
                                  if (_installmentShiftReasons.containsKey(cuota.installmentNumber)) ...[
                                    const SizedBox(height: 3),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: widget.isDark
                                            ? Colors.amber.withValues(alpha: 0.2)
                                            : Colors.amber.shade100,
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(
                                          color: widget.isDark
                                              ? Colors.amber.withValues(alpha: 0.5)
                                              : Colors.amber.shade400,
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.subdirectory_arrow_right_rounded,
                                            size: 11,
                                            color: widget.isDark
                                                ? Colors.amber[300]
                                                : Colors.amber[900],
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            _installmentShiftReasons[cuota.installmentNumber]!,
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.bold,
                                              color: widget.isDark
                                                  ? Colors.amber[300]
                                                  : Colors.amber[900],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Badge de estado histórico interactivo
                        Tooltip(
                          message: "Tocar para cambiar estado (Pagada / Parcial / Pendiente)",
                          child: InkWell(
                            onTap: () => _showInstallmentStatusDialog(i),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: cuota.montoPagado >= cuota.amount &&
                                        cuota.amount > 0
                                    ? (widget.isDark
                                        ? Colors.green.withValues(alpha: 0.25)
                                        : Colors.green.shade100)
                                    : cuota.montoPagado > 0
                                        ? (widget.isDark
                                            ? Colors.blue
                                                .withValues(alpha: 0.25)
                                            : Colors.blue.shade100)
                                        : dueDate.isBefore(DateTime.now())
                                            ? (widget.isDark
                                                ? Colors.red
                                                    .withValues(alpha: 0.25)
                                                : Colors.red.shade100)
                                            : (widget.isDark
                                                ? Colors.white10
                                                : Colors.grey[200]),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    cuota.montoPagado >= cuota.amount &&
                                            cuota.amount > 0
                                        ? Icons.check_circle_outline
                                        : cuota.montoPagado > 0
                                            ? Icons.timelapse
                                            : dueDate.isBefore(DateTime.now())
                                                ? Icons.error_outline
                                                : Icons.pending_outlined,
                                    size: 11,
                                    color: cuota.montoPagado >= cuota.amount &&
                                            cuota.amount > 0
                                        ? Colors.green
                                        : cuota.montoPagado > 0
                                            ? Colors.blue
                                            : dueDate.isBefore(DateTime.now())
                                                ? Colors.redAccent
                                                : (widget.isDark
                                                    ? Colors.grey[400]
                                                    : Colors.grey[700]),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    cuota.montoPagado >= cuota.amount &&
                                            cuota.amount > 0
                                        ? "Pagada"
                                        : cuota.montoPagado > 0
                                            ? "S/ ${cuota.montoPagado.toStringAsFixed(0)}"
                                            : dueDate.isBefore(DateTime.now())
                                                ? "Vencida"
                                                : "Pend.",
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: cuota.montoPagado >=
                                                  cuota.amount &&
                                              cuota.amount > 0
                                          ? Colors.green
                                          : cuota.montoPagado > 0
                                              ? Colors.blue
                                              : dueDate.isBefore(DateTime.now())
                                                  ? Colors.redAccent
                                                  : (widget.isDark
                                                      ? Colors.grey[400]
                                                      : Colors.grey[700]),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (cuota.montoPagado < cuota.amount &&
                            cuota.status != 'pagado')
                          Tooltip(
                            message: "Saltar día y recalcular siguientes",
                            child: InkWell(
                              onTap: () => _skipDayForInstallment(i),
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 2.5),
                                margin: const EdgeInsets.only(right: 5),
                                decoration: BoxDecoration(
                                  color: widget.isDark
                                      ? Colors.white10
                                      : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.skip_next,
                                        size: 12,
                                        color: widget.isDark
                                            ? Colors.grey[300]
                                            : Colors.grey[700]),
                                    const SizedBox(width: 2),
                                    Text(
                                      "+1d",
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: widget.isDark
                                            ? Colors.grey[300]
                                            : Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                AppCurrency.format(cuota.amount),
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: textColor),
                              ),
                            ),
                            if (cuota.montoPagado > 0 &&
                                cuota.montoPagado < cuota.amount)
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  "Pend: ${AppCurrency.format(cuota.amount - cuota.montoPagado)}",
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildOneQuotaStatusCard(Color textColor, double enteredAmount) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF14141C) : Colors.grey[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.isDark ? Colors.white10 : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "Estado de Pago Inicial",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: widget.isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ),
              if (_oneQuotaPaidAmount > 0)
                Text(
                  "Abonado: ${AppCurrency.format(_oneQuotaPaidAmount)}",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "¿Este préstamo ya fue amortizado o pagado previamente?",
            style: TextStyle(
              fontSize: 11.5,
              color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text("Pendiente / Vencida"),
                selected: _oneQuotaPaidAmount == 0,
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _oneQuotaPaidAmount = 0.0;
                      _oneQuotaStatus = _dueDate.isBefore(DateTime.now())
                          ? 'vencida'
                          : 'pendiente';
                    });
                    _saveCurrentDraft();
                  }
                },
                selectedColor: Colors.orange.withValues(alpha: 0.25),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: _oneQuotaPaidAmount == 0
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: _oneQuotaPaidAmount == 0
                      ? Colors.orange
                      : (widget.isDark ? Colors.grey[300] : Colors.grey[700]),
                ),
              ),
              ChoiceChip(
                label: const Text("Ya Pagada"),
                selected: enteredAmount > 0 &&
                    _oneQuotaPaidAmount >= enteredAmount,
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _oneQuotaPaidAmount =
                          enteredAmount > 0 ? enteredAmount : 0.0;
                      _oneQuotaStatus = 'pagado';
                    });
                    _saveCurrentDraft();
                  }
                },
                selectedColor: Colors.green.withValues(alpha: 0.25),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: (enteredAmount > 0 &&
                          _oneQuotaPaidAmount >= enteredAmount)
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: (enteredAmount > 0 &&
                          _oneQuotaPaidAmount >= enteredAmount)
                      ? Colors.green
                      : (widget.isDark ? Colors.grey[300] : Colors.grey[700]),
                ),
              ),
              ChoiceChip(
                label: const Text("Pago Parcial"),
                selected: _oneQuotaPaidAmount > 0 &&
                    _oneQuotaPaidAmount < enteredAmount,
                onSelected: (val) {
                  _showOneQuotaPartialDialog(enteredAmount);
                },
                selectedColor: Colors.blue.withValues(alpha: 0.25),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: (_oneQuotaPaidAmount > 0 &&
                          _oneQuotaPaidAmount < enteredAmount)
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: (_oneQuotaPaidAmount > 0 &&
                          _oneQuotaPaidAmount < enteredAmount)
                      ? Colors.blue
                      : (widget.isDark ? Colors.grey[300] : Colors.grey[700]),
                ),
              ),
            ],
          ),
          if (enteredAmount > 0) ...[
            const SizedBox(height: 8),
            Divider(
                height: 1,
                color: widget.isDark ? Colors.white10 : Colors.grey[200]),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "Saldo Deudor Inicial:",
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),
                Text(
                  AppCurrency.format((enteredAmount - _oneQuotaPaidAmount)
                      .clamp(0.0, double.infinity)),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: (enteredAmount - _oneQuotaPaidAmount) > 0
                        ? Colors.orange
                        : Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWeekdayButton(int dayNumber, String shortLetter, String fullName) {
    final bool isExcluded = _excludedWeekdays.contains(dayNumber);
    final isDark = widget.isDark;

    Color bgColor;
    Color fgColor;
    Border border;
    List<BoxShadow>? shadows;

    if (isExcluded) {
      bgColor = isDark ? Colors.white.withAlpha(8) : Colors.grey[100]!;
      fgColor = isDark ? Colors.grey[600]! : Colors.grey[400]!;
      border = Border.all(
        color: isDark ? Colors.white10 : Colors.grey.shade300,
        width: 1,
      );
      shadows = null;
    } else {
      bgColor = isDark
          ? Colors.orange.withValues(alpha: 0.25)
          : Colors.orange.shade50;
      fgColor = isDark ? Colors.orange[200]! : Colors.orange[900]!;
      border = Border.all(
        color: isDark ? Colors.orange : Colors.orange.shade700,
        width: 1.5,
      );
      shadows = [
        BoxShadow(
          color: Colors.orange.withValues(alpha: isDark ? 0.25 : 0.15),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];
    }

    return Tooltip(
      message: isExcluded
          ? "$fullName (Excluido de cobro)"
          : "$fullName (Día de cobro activo)",
      child: InkWell(
        onTap: () => _toggleWeekday(dayNumber),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: 40,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: border,
            boxShadow: shadows,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                shortLetter,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: fgColor,
                  decoration: isExcluded ? TextDecoration.lineThrough : null,
                ),
              ),
              if (!isExcluded) ...[
                const SizedBox(height: 2),
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? Colors.orange[300] : Colors.orange[800],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChip({
    required String label,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = widget.isDark;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? Colors.orange.withValues(alpha: 0.25)
                  : Colors.orange.shade50)
              : (isDark ? Colors.white.withAlpha(12) : Colors.grey[100]),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: isSelected
                ? (isDark ? Colors.orange : Colors.orange.shade700)
                : (isDark ? Colors.white12 : Colors.grey.shade300),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color:
                        Colors.orange.withValues(alpha: isDark ? 0.25 : 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                isSelected ? Icons.check_circle_rounded : icon,
                size: 14,
                color: isSelected
                    ? (isDark ? Colors.orange[300] : Colors.orange[800])
                    : (isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? (isDark ? Colors.orange[200] : Colors.orange[900])
                    : (isDark ? Colors.grey[400] : Colors.grey[700]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodChip(String method, IconData icon, bool isWithdraw) {
    bool isSelected =
        isWithdraw ? _withdrawMethod == method : _loanMethod == method;
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected
                ? Colors.white
                : (widget.isDark ? Colors.grey[400] : Colors.grey[700]),
          ),
          const SizedBox(width: 6),
          Text(method),
        ],
      ),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() {
            if (isWithdraw) {
              _withdrawMethod = method;
            } else {
              _loanMethod = method;
            }
            _saveCurrentDraft();
          });
        }
      },
      selectedColor: isWithdraw ? Colors.teal : Colors.orange[800],
      labelStyle: TextStyle(
        color: isSelected
            ? Colors.white
            : (widget.isDark ? Colors.grey[300] : Colors.grey[800]),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: 13,
      ),
      backgroundColor: widget.isDark ? Colors.white10 : Colors.grey[100],
      side: BorderSide(
        color: isSelected
            ? (isWithdraw
                ? Colors.teal
                : (Colors.orange[800] ?? Colors.orange))
            : (widget.isDark ? Colors.white10 : Colors.grey.shade300),
      ),
    );
  }

  Widget _buildInputLarge({
    required TextEditingController ctrl,
    required bool isDark,
    required Color textColor,
    required bool isInt,
  }) {
    return TextField(
      controller: ctrl,
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      keyboardType: isInt
          ? TextInputType.number
          : const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: isInt
          ? [FilteringTextInputFormatter.digitsOnly]
          : [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
      style: TextStyle(
          fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
      decoration: InputDecoration(
        prefixText: "S/ ",
        prefixStyle: TextStyle(
            fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
        filled: true,
        fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: isDark ? Colors.white10 : Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: isDark ? Colors.white10 : Colors.grey.shade300),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildInput({
    required String label,
    String? prefix,
    String? suffix,
    required TextEditingController ctrl,
    required bool isDark,
    required Color textColor,
    bool isInt = false,
  }) {
    return TextField(
      controller: ctrl,
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      keyboardType: isInt
          ? TextInputType.number
          : const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: isInt
          ? [FilteringTextInputFormatter.digitsOnly]
          : [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
      style: TextStyle(
          color: textColor, fontSize: 15, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            fontSize: 13),
        prefixText: prefix,
        suffixText: suffix,
        filled: true,
        fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100],
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        isDense: true,
      ),
    );
  }
}
