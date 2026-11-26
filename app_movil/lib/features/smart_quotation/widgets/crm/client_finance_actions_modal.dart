import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/core/utils/app_date_formatter.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/finance_actions/client_finance_draft_manager.dart';

export 'package:app_movil/features/smart_quotation/widgets/crm/finance_actions/client_finance_draft_manager.dart';

part 'finance_actions/client_finance_draft_and_submit.dart';
part 'finance_actions/client_finance_loan_schedule_logic.dart';
part 'finance_actions/client_finance_installment_dialog.dart';
part 'finance_actions/client_finance_confirmation_dialogs.dart';
part 'finance_actions/client_finance_withdraw_and_cards.dart';
part 'finance_actions/client_finance_loan_tab.dart';
part 'finance_actions/client_finance_loan_schedule_section.dart';
part 'finance_actions/client_finance_inputs_and_one_quota.dart';

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

abstract class _ClientFinanceActionsStateBase
    extends State<ClientFinanceActionsModal>
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
  bool _isLoanInfoExpanded = false;
  bool _isWithdrawInfoExpanded = false;

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


  void _saveCurrentDraft();
  void _saveDraftByIndex(int tabIndex);
  void _restoreDraftForTab(int tabIndex);
  void _cleanActiveTab();
  String _getFrequencyContextSubtitle();
  String _formatDateSpanish(DateTime date);
  void _submitAction(TrackingProvider provider);
  Future<void> _executeSubmitLoan(
    TrackingProvider provider,
    double amount,
    double interestRate,
    double finalDebt,
    String motivo,
    List<InstallmentModel> installments,
  );
  void _toggleWeekday(int day);
  void _recalculateMultipleInstallments({String? customFeedback});
  Future<void> _selectDueDate(BuildContext context);
  Future<void> _selectStartDate(BuildContext context);
  Future<void> _selectLoanEmissionDate(BuildContext context);
  Future<void> _editInstallmentDate(int index);
  void _skipDayForInstallment(int index);
  void _showInstallmentStatusDialog(int index);
  void _showOneQuotaPartialDialog(double enteredAmount);
  void _showPreConfirmDialog(
    TrackingProvider provider,
    double amount,
    double interestRate,
    double finalDebt,
    String motivo,
    List<InstallmentModel> installments,
  );
  Widget _buildDynamicContextualCard(
    bool isDark,
    double enteredAmount,
    TrackingProvider provider,
  );
  Widget _buildWithdrawTab(
      Color textColor, bool hasAvailableBalance, double enteredAmount);
  Widget _buildLoanTab(Color textColor, double enteredAmount);
  List<Widget> _buildGeneratedSchedulePreview(Color textColor);
  Widget _buildOneQuotaStatusCard(Color textColor, double enteredAmount);
  Widget _buildWeekdayButton(int dayNumber, String shortLetter, String fullName);
  Widget _buildPresetChip({
    required String label,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
  });
  Widget _buildMethodChip(String method, IconData icon, bool isWithdraw);
  Widget _buildInputLarge({
    required TextEditingController ctrl,
    required bool isDark,
    required Color textColor,
    required bool isInt,
  });
  Widget _buildInput({
    required String label,
    // ignore: unused_element_parameter
    String? prefix,
    String? suffix,
    required TextEditingController ctrl,
    required bool isDark,
    required Color textColor,
    bool isInt = false,
  });

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
            const SizedBox(height: 4),

            // Selector de 2 tarjetas interactivas con subtítulos guía
            _buildTopModeSelector(widget.isDark),
            const SizedBox(height: 4),

            // Tarjeta Contextual Dinámica y Reactiva
            _buildDynamicContextualCard(widget.isDark, enteredAmount, provider),
            const SizedBox(height: 2),

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

            // Bottom Action Bar sin doble compensación (respiro ergonómico limpio de 12dp sobre la barra del sistema)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
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
                height: 50,
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                height: 1.15,
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

}

class _ClientFinanceActionsModalState extends _ClientFinanceActionsStateBase
    with
        _ClientFinanceDraftSubmitMixin,
        _ClientFinanceLoanScheduleLogicMixin,
        _ClientFinanceInstallmentDialogMixin,
        _ClientFinanceConfirmationDialogsMixin,
        _ClientFinanceWithdrawAndCardsMixin,
        _ClientFinanceLoanTabMixin,
        _ClientFinanceLoanScheduleSectionMixin,
        _ClientFinanceInputsAndOneQuotaMixin {}
