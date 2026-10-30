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
    Set<int>? excludedWeekdays,
    List<InstallmentModel>? installments,
  })  : dueDate = dueDate ?? DateTime.now().add(const Duration(days: 30)),
        startDate = startDate ?? DateTime.now(),
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

  const ClientFinanceActionsModal({
    super.key,
    required this.client,
    required this.isDark,
  });

  /// Presenta el modal de operaciones financieras garantizando enableDrag: false
  /// para evitar que el gesto de arrastre compita con el scroll vertical de cuotas.
  static Future<void> show(
    BuildContext context, {
    required ClientModel client,
    required bool isDark,
    VoidCallback? onCompleted,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ClientFinanceActionsModal(
        client: client,
        isDark: isDark,
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

  // Fecha de vencimiento para préstamo simple (1 cuota)
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));

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
    final initialTab = draftMgr.getActiveTab(widget.client.id);

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
    if (_tabController.index == 1 && _splitInQuotas) {
      _recalculateMultipleInstallments();
    } else {
      _saveCurrentDraft();
    }
  }

  void _onNumCuotasChanged() {
    if (_tabController.index == 1 && _splitInQuotas) {
      _recalculateMultipleInstallments();
    }
  }

  void _onInterestChanged() {
    if (_tabController.index == 1 && _splitInQuotas) {
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
  // GESTIÓN DE BORRADORES
  // =========================================================================

  void _saveCurrentDraft() {
    _saveDraftByIndex(_tabController.index);
  }

  void _saveDraftByIndex(int tabIndex) {
    final draftMgr = ClientFinanceDraftManager.instance;
    if (tabIndex == 0) {
      draftMgr.setWithdrawDraft(
        widget.client.id,
        FinanceWithdrawDraft(
          amount: _amountCtrl.text,
          method: _withdrawMethod,
        ),
      );
    } else {
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
          excludedWeekdays: _excludedWeekdays,
          installments: _installments,
        ),
      );
    }
  }

  void _restoreDraftForTab(int tabIndex) {
    final draftMgr = ClientFinanceDraftManager.instance;
    if (tabIndex == 0) {
      final draft = draftMgr.getWithdrawDraft(widget.client.id);
      _amountCtrl.text = draft?.amount ?? '';
      _withdrawMethod = draft?.method ?? 'Efectivo';
    } else {
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
        _excludedWeekdays = {DateTime.sunday};
        _installments.clear();
      }
    }
    if (mounted) setState(() {});
  }

  /// Limpia únicamente los datos y el borrador de la pestaña actualmente activa
  void _cleanActiveTab() {
    HapticFeedback.mediumImpact();
    final isWithdraw = _tabController.index == 0;
    if (isWithdraw) {
      ClientFinanceDraftManager.instance
          .clearWithdrawDraft(widget.client.id);
      _amountCtrl.clear();
      _withdrawMethod = "Efectivo";
      CustomSnackBar.show(context,
          message: "Formulario de Retiro restablecido", isError: false);
    } else {
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
      _excludedWeekdays = {DateTime.sunday};
      _installments.clear();
      _scheduleUpdateFeedback = null;
      _installmentShiftReasons.clear();
      CustomSnackBar.show(context,
          message: "Formulario de Préstamo restablecido", isError: false);
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

        _installments.add(InstallmentModel(
          installmentNumber: i,
          amount: amt,
          dueDate: DateFormat('yyyy-MM-dd').format(quotaDate),
          status: "pendiente",
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

        _installments.add(InstallmentModel(
          installmentNumber: i,
          amount: amt,
          dueDate: DateFormat('yyyy-MM-dd').format(quotaDate),
          status: "pendiente",
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

        _installments.add(InstallmentModel(
          installmentNumber: i,
          amount: amt,
          dueDate: DateFormat('yyyy-MM-dd').format(quotaDate),
          status: "pendiente",
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

        _installments.add(InstallmentModel(
          installmentNumber: i,
          amount: amt,
          dueDate: DateFormat('yyyy-MM-dd').format(quotaDate),
          status: "pendiente",
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
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
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
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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

  Future<void> _editInstallmentDate(int index) async {
    final current =
        DateTime.tryParse(_installments[index].dueDate) ?? DateTime.now();
    final minDate = index == 0
        ? _startDate
        : (DateTime.tryParse(_installments[index - 1].dueDate)
                ?.add(const Duration(days: 1)) ??
            DateTime.now());

    final picked = await showDatePicker(
      context: context,
      initialDate: current.isBefore(minDate) ? minDate : current,
      firstDate: minDate,
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
      _installments[fromIndex] = InstallmentModel(
        installmentNumber: current.installmentNumber,
        amount: current.amount,
        dueDate: DateFormat('yyyy-MM-dd').format(validDate),
        status: current.status,
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
        _installments[i] = InstallmentModel(
          installmentNumber: c.installmentNumber,
          amount: c.amount,
          dueDate: DateFormat('yyyy-MM-dd').format(next),
          status: c.status,
        );
      }
      _scheduleUpdateFeedback =
          "Cuota #${fromIndex + 1} actualizada • Cuotas siguientes corridas en cascada";
      _feedbackTrigger++;
    });
    _saveCurrentDraft();
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

    if (_tabController.index == 0) {
      // Retiro de saldo
      if (amount > widget.client.saldoAFavor) {
        CustomSnackBar.show(context,
            message: "El monto supera el saldo a favor disponible",
            isError: true);
        return;
      }
      _executeSubmitWithdrawal(provider, amount);
    } else {
      // Préstamo
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
        finalInstallments = [
          InstallmentModel(
            installmentNumber: 1,
            amount: amount,
            dueDate: DateFormat('yyyy-MM-dd').format(_dueDate),
            status: "pendiente",
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
                _buildSummaryRow("Monto Base:", AppCurrency.format(amount)),
                if (interestRate > 0)
                  _buildSummaryRow(
                    "Interés (${interestRate.toStringAsFixed(1)}%):",
                    AppCurrency.format(finalDebt - amount),
                  ),
                const Divider(),
                _buildSummaryRow("Total a Cobrar:",
                    AppCurrency.format(finalDebt),
                    isBold: true),
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
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Cuota ${c.installmentNumber} • ${_formatDateSpanish(d)}",
                              style: TextStyle(
                                fontSize: 13,
                                color: widget.isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[700],
                              ),
                            ),
                            Text(
                              AppCurrency.format(c.amount),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: widget.isDark
                                    ? Colors.white
                                    : Colors.black87,
                              ),
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
    bool isWithdrawTab = _tabController.index == 0;
    bool hasAvailableBalance = widget.client.saldoAFavor > 0.01;

    bool canSubmitWithdraw = isWithdrawTab &&
        hasAvailableBalance &&
        enteredAmount > 0 &&
        enteredAmount <= widget.client.saldoAFavor;
    bool canSubmitLoan = !isWithdrawTab && enteredAmount > 0;
    bool canSubmit = isWithdrawTab ? canSubmitWithdraw : canSubmitLoan;

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
              isWithdrawTab ? "Limpiar retiro" : "Limpiar préstamo",
          child: TextButton.icon(
            icon: const Icon(Icons.cleaning_services_outlined,
                size: 16),
            label: const Text("Limpiar",
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold)),
            style: TextButton.styleFrom(
              foregroundColor:
                  isWithdrawTab ? Colors.teal : Colors.orange[800],
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: _cleanActiveTab,
          ),
        ),
      ],
      backgroundColor: surfaceColor,
      child: Column(
        children: [
          const SizedBox(height: 8),

            // TabBar con estilo blindado
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: widget.isDark
                    ? Colors.white.withAlpha(12)
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: widget.isDark
                      ? Colors.blueGrey[700]
                      : Colors.blueGrey[800],
                  boxShadow: [
                    if (!widget.isDark)
                      BoxShadow(
                        color: Colors.black.withAlpha(25),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                labelColor: Colors.white,
                unselectedLabelColor:
                    widget.isDark ? Colors.grey[400] : Colors.grey[600],
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
                tabs: const [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.output, size: 18),
                        SizedBox(width: 8),
                        Text("Retirar"),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.account_balance, size: 18),
                        SizedBox(width: 8),
                        Text("Préstamo"),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // TabBarView sin cortes
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildWithdrawTab(
                      textColor, hasAvailableBalance, enteredAmount),
                  _buildLoanTab(textColor, enteredAmount),
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
                        isWithdrawTab ? Colors.teal : Colors.orange[800],
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
                          isWithdrawTab
                              ? "Confirmar Retiro"
                              : "Registrar Préstamo",
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                ),
              ),
            ),
          ],
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
              Column(
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
          const Text(
            "⚠️ El monto supera el saldo disponible para retiro",
            style: TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold),
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

        // Motivo / Detalle
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

        // Fecha de vencimiento para 1 cuota
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Cronograma Generado",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: textColor)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "Total: ${AppCurrency.format(_installments.fold<double>(0.0, (sum, c) => sum + c.amount))}",
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Colors.orange),
                  ),
                ),
              ],
            ),
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
                          radius: 13,
                          backgroundColor:
                              Colors.orange.withValues(alpha: 0.2),
                          child: Text(
                            "${cuota.installmentNumber}",
                            style: const TextStyle(
                                fontSize: 11,
                                color: Colors.orange,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 10),
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
                        Tooltip(
                          message: "Saltar día y recalcular siguientes",
                          child: InkWell(
                            onTap: () => _skipDayForInstallment(i),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              margin: const EdgeInsets.only(right: 8),
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
                                      size: 13,
                                      color: widget.isDark
                                          ? Colors.grey[300]
                                          : Colors.grey[700]),
                                  const SizedBox(width: 2),
                                  Text(
                                    "+1d",
                                    style: TextStyle(
                                      fontSize: 10,
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
                        Text(
                          AppCurrency.format(cuota.amount),
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: textColor),
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
