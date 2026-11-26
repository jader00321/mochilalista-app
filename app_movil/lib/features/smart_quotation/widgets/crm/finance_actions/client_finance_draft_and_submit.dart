part of '../client_finance_actions_modal.dart';

mixin _ClientFinanceDraftSubmitMixin on _ClientFinanceActionsStateBase {
  // =========================================================================
  // GESTIÓN DE BORRADORES (Tab 0: Préstamo, Tab 1: Retiro)
  // =========================================================================

  @override
  void _saveCurrentDraft() {
    _saveDraftByIndex(_tabController.index);
  }

  @override
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

  @override
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
  @override
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
  // ENVÍO Y PERSISTENCIA EN SQLITE
  // =========================================================================

  @override
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

  @override
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

}
