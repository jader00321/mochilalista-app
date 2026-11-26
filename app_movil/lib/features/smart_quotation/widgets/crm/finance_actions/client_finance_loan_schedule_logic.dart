part of '../client_finance_actions_modal.dart';

mixin _ClientFinanceLoanScheduleLogicMixin on _ClientFinanceActionsStateBase {
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

  @override
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
  @override
  String _formatDateSpanish(DateTime date) =>
      AppDateFormatter.formatDateSpanish(date, includeWeekday: true);

  /// Toggle de día de la semana con protección anti-bucle (debe quedar al menos 1 día activo)
  @override
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

  @override
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

  @override
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

  @override
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

  @override
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

  @override
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
  @override
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

}
