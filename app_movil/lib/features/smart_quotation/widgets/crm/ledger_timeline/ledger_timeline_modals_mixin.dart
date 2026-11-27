part of '../ledger_timeline_tab.dart';

mixin _LedgerTimelineModalsMixin on _LedgerTimelineTabBase {
  @override
  void _showEditPagoModal(BuildContext context, LedgerItem item, int clientId) {
    if (item.pagoId == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final montoCtrl = TextEditingController(
      text: item.monto.toStringAsFixed(2),
    );
    final notaCtrl = TextEditingController(text: item.nota ?? '');
    String metodoSeleccionado = item.metodoPago ?? 'Efectivo';
    DateTime fechaSeleccionada = item.fecha;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E28) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (sheetCtx, setModalState) {
            final mediaQuery = MediaQuery.of(sheetCtx);
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: mediaQuery.viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Encabezado
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit_note_rounded,
                                color: Colors.blueAccent,
                                size: 24,
                              ),
                              SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  "Corregir / Editar Abono",
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.of(modalCtx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Advertencia de Recálculo en Cascada
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(
                          alpha: isDark ? 0.15 : 0.08,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.25),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: Colors.blueAccent,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Al guardar, se recalculará automáticamente la cuota, la venta asociada y el saldo del cliente.",
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Monto
                    const Text(
                      "Monto del Abono (S/)",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: montoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(
                          Icons.attach_money_rounded,
                          size: 20,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Método de Pago
                    const Text(
                      "Método de Pago",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: ['Efectivo', 'Yape', 'Plin', 'Transferencia']
                          .map((met) {
                            final isSel =
                                metodoSeleccionado.toLowerCase() ==
                                met.toLowerCase();
                            return ChoiceChip(
                              label: Text(met),
                              selected: isSel,
                              onSelected: (sel) {
                                if (sel) {
                                  setModalState(() => metodoSeleccionado = met);
                                }
                              },
                            );
                          })
                          .toList(),
                    ),
                    const SizedBox(height: 14),

                    // Fecha de Pago
                    const Text(
                      "Fecha del Pago",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: fechaSeleccionada,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (picked != null) {
                          setModalState(() => fechaSeleccionada = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? Colors.white24
                                : Colors.grey.shade400,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                AppDateFormatter.formatDate(fechaSeleccionada),
                              ),
                            ),
                            const Icon(Icons.calendar_today_rounded, size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Nota Explicativa
                    const Text(
                      "Nota / Motivo de Corrección",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notaCtrl,
                      decoration: InputDecoration(
                        hintText: "Ej. Corrección por error de digitación",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Botón Guardar
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_rounded),
                        label: const Text(
                          "Guardar Cambios",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final nuevoMonto =
                              double.tryParse(
                                montoCtrl.text.replaceAll(',', '.'),
                              ) ??
                              0.0;
                          if (nuevoMonto <= 0) {
                            AppFeedbackHelper.showSnackBar(
                              context,
                              "El monto debe ser mayor a 0",
                            );
                            return;
                          }

                          Navigator.of(modalCtx).pop();

                          final prov = Provider.of<TrackingProvider>(
                            context,
                            listen: false,
                          );
                          final ok = await prov.editarPago(
                            clientId,
                            item.pagoId!,
                            nuevoMonto: nuevoMonto,
                            nuevoMetodoPago: metodoSeleccionado,
                            nuevaFechaPago: fechaSeleccionada,
                            nuevaNota: notaCtrl.text.trim().isNotEmpty
                                ? notaCtrl.text.trim()
                                : null,
                          );

                          if (ok) {
                            widget.onRefresh?.call();
                            if (context.mounted) {
                              AppFeedbackHelper.showSnackBar(
                                context,
                                "Abono corregido con éxito",
                                backgroundColor: Colors.green,
                              );
                            }
                          } else {
                            if (context.mounted) {
                              AppFeedbackHelper.showSnackBar(
                                context,
                                "No se pudo corregir el abono",
                                backgroundColor: Colors.redAccent,
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void _showDeleteConfirmModal(
    BuildContext context,
    LedgerItem item,
    int clientId,
  ) {
    String title = "¿Confirmar Eliminación?";
    String content = "Esta acción modificará los saldos contables.";
    String confirmLabel = "Eliminar";

    if (item.tipo == 'cargo') {
      final String opName = item.subtipo == 'prestamo' ? 'Préstamo' : 'Venta';
      title = "¿Revertir este $opName?";
      content =
          "Se revertirá la operación de ${AppCurrency.format(item.monto)} y sus cronogramas asociados. La deuda del cliente se recalculará automáticamente.";
      confirmLabel = "Revertir $opName";
    } else if (item.tipo == 'abono') {
      title = "¿Revertir este Abono?";
      content =
          "Se anulará el abono de ${AppCurrency.format(item.monto)}. La deuda del cliente aumentará y la cuota volverá a estar pendiente.";
      confirmLabel = "Revertir Abono";
    } else if (item.tipo == 'evento') {
      title = "¿Descartar Registro?";
      content =
          "Este registro informativo se eliminará del historial contable.";
      confirmLabel = "Descartar";
    }

    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.redAccent,
              size: 24,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(content, style: const TextStyle(fontSize: 13.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlgCtx).pop(),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.of(dlgCtx).pop();
              final prov = Provider.of<TrackingProvider>(
                context,
                listen: false,
              );
              bool ok = false;

              if (item.tipo == 'cargo' && item.ventaId != null) {
                ok = await prov.revertirVentaOPrestamo(clientId, item.ventaId!);
              } else if (item.tipo == 'abono' && item.pagoId != null) {
                ok = await prov.revertirPago(clientId, item.pagoId!);
              } else if (item.tipo == 'evento' && item.eventoId != null) {
                ok = await prov.eliminarEventoFinanciero(
                  clientId,
                  item.eventoId!,
                );
              }

              if (ok) {
                widget.onRefresh?.call();
                if (context.mounted) {
                  AppFeedbackHelper.showSnackBar(
                    context,
                    "Operación revertida con éxito",
                    backgroundColor: Colors.green,
                  );
                }
              } else {
                if (context.mounted) {
                  AppFeedbackHelper.showSnackBar(
                    context,
                    "No se pudo completar la reversión",
                    backgroundColor: Colors.redAccent,
                  );
                }
              }
            },
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }
}
