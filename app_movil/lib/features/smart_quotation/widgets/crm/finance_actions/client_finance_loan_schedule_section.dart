part of '../client_finance_actions_modal.dart';

mixin _ClientFinanceLoanScheduleSectionMixin on _ClientFinanceActionsStateBase {
  @override
  List<Widget> _buildGeneratedSchedulePreview(Color textColor) {
    return [
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
    ];
  }
}
