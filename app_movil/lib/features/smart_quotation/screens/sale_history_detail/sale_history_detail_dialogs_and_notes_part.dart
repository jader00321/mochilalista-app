part of '../sale_history_detail_screen.dart';

extension _SaleHistoryDetailDialogsExt on _SaleHistoryDetailScreenState {
  Widget _buildSheetHeaderRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  void _showDuplicateOptionsModal(int cotizacionId, bool isDark) {
    InteractiveSheetWrapper.show(
      context: context,
      builder: (ctx) {
        return InteractiveSheetWrapper(
          applyEffectiveBottomPadding: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSheetHeaderRow(
                  icon: Icons.content_copy,
                  iconColor: isDark ? Colors.blue[300]! : Colors.blue[800]!,
                  title: "Opciones de Duplicación",
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                Text(
                  "Elige cómo deseas duplicar esta lista vendida sin alterar la original.",
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: isDark
                        ? Colors.blue.withValues(alpha: 0.15)
                        : Colors.blue[50],
                    child: Icon(
                      Icons.shopping_cart_checkout,
                      color: isDark ? Colors.blue[300] : Colors.blue,
                    ),
                  ),
                  title: Text(
                    "Vender Nuevamente (Genérica)",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    "Crea una copia editable exacta para asignársela a un nuevo cliente.",
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _handleCloneToGeneric(cotizacionId);
                  },
                ),
                Divider(
                  height: 16,
                  color: isDark ? Colors.white10 : Colors.grey[200],
                ),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: isDark
                        ? Colors.purple.withValues(alpha: 0.15)
                        : Colors.purple[50],
                    child: Icon(
                      Icons.inventory_2,
                      color: isDark ? Colors.purple[300] : Colors.purple,
                    ),
                  ),
                  title: Text(
                    "Guardar como Plantilla (Pack)",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    "Convierte esta lista en un catálogo recurrente.",
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _handleConvertToPack(cotizacionId);
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showEditNoteDialog({
    required String type,
    required String currentNote,
    required int id,
  }) async {
    final ctrl = TextEditingController(text: currentNote);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isClient = type == 'client';
    final isLoan = type == 'loan';

    final String title;
    final String hintText;
    final Color color;
    final IconData icon;

    if (isClient) {
      title = currentNote.isEmpty
          ? "Agregar Nota al Cliente"
          : "Editar Nota del Cliente";
      hintText = "Escribe la observación general del cliente aquí...";
      color = isDark ? Colors.blue[300]! : Colors.blue[800]!;
      icon = Icons.assignment_ind;
    } else if (isLoan) {
      title = currentNote.isEmpty
          ? "Agregar Nota del Préstamo"
          : "Editar Nota del Préstamo";
      hintText = "Escribe el motivo u observación del préstamo aquí...";
      color = isDark ? Colors.amber[300]! : Colors.amber[800]!;
      icon = Icons.monetization_on_outlined;
    } else {
      title = currentNote.isEmpty
          ? "Agregar Nota de Venta"
          : "Editar Nota de la Venta";
      hintText = "Escribe los detalles o nota de la venta aquí...";
      color = isDark ? Colors.orange[300]! : Colors.orange[800]!;
      icon = Icons.speaker_notes;
    }

    final bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 16,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(
              color: isDark ? Colors.grey[600] : Colors.grey,
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar", style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "Guardar",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      _updateState(() => _isProcessingAction = true);
      final saleProv = Provider.of<SaleProvider>(context, listen: false);
      bool success = false;
      final newText = ctrl.text.trim();

      if (isClient) {
        success = await saleProv.updateClientNote(id, newText);
        if (success) {
          _updateState(() {
            _saleData!['cliente_notas'] = newText;
          });
        }
      } else if (isLoan) {
        success = await saleProv.updateSaleNote(id, newText);
        if (success) {
          _updateState(() {
            _saleData!['nota_prestamo'] = newText;
            _saleData!['notes'] = newText;
          });
        }
      } else {
        success = await saleProv.updateQuotationNote(id, newText);
        if (success) {
          _updateState(() {
            if (_saleData!['cotizacion'] != null) {
              _saleData!['cotizacion']['notas'] = newText;
            }
          });
        }
      }

      _updateState(() => _isProcessingAction = false);

      if (success) {
        _showSnack(
          currentNote.isEmpty
              ? "Nota agregada correctamente"
              : "Nota actualizada correctamente",
        );
      } else {
        _showSnack("Error al guardar la nota", isError: true);
      }
    }
  }

  void _showAddNoteMenu({
    required int cotizacionId,
    required int? clientId,
    required String currentSaleNote,
    required String currentClientNote,
    required bool isDark,
    required bool isLoan,
    required int saleId,
  }) {
    InteractiveSheetWrapper.show(
      context: context,
      builder: (ctx) {
        return InteractiveSheetWrapper(
          applyEffectiveBottomPadding: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSheetHeaderRow(
                  icon: Icons.edit_note,
                  iconColor: isDark ? Colors.amber[300]! : Colors.amber[800]!,
                  title: "Gestionar Notas",
                  isDark: isDark,
                ),
                const SizedBox(height: 10),
                Text(
                  isLoan
                      ? "¿Qué tipo de nota deseas registrar en este préstamo?"
                      : "¿Qué tipo de nota deseas agregar o modificar?",
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: isDark
                        ? Colors.orange.withValues(alpha: 0.15)
                        : Colors.orange[50],
                    child: Icon(
                      isLoan
                          ? Icons.monetization_on_outlined
                          : Icons.speaker_notes,
                      color: isDark ? Colors.orange[300] : Colors.orange[800],
                    ),
                  ),
                  title: Text(
                    currentSaleNote.isEmpty
                        ? (isLoan
                              ? "Agregar Motivo del Préstamo"
                              : "Agregar Nota de Venta")
                        : (isLoan
                              ? "Editar Motivo del Préstamo"
                              : "Editar Nota de Venta"),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    isLoan
                        ? "Motivo, condiciones o acuerdos particulares de este préstamo."
                        : "Detalles exclusivos para este recibo en particular.",
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (isLoan) {
                      _showEditNoteDialog(
                        type: 'loan',
                        currentNote: currentSaleNote,
                        id: saleId,
                      );
                    } else if (cotizacionId > 0) {
                      _showEditNoteDialog(
                        type: 'sale',
                        currentNote: currentSaleNote,
                        id: cotizacionId,
                      );
                    } else {
                      _showEditNoteDialog(
                        type: 'loan',
                        currentNote: currentSaleNote,
                        id: saleId,
                      );
                    }
                  },
                ),
                if (clientId != null && clientId > 0) ...[
                  Divider(
                    height: 16,
                    color: isDark ? Colors.white10 : Colors.grey[200],
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: isDark
                          ? Colors.blue.withValues(alpha: 0.15)
                          : Colors.blue[50],
                      child: Icon(
                        Icons.assignment_ind,
                        color: isDark ? Colors.blue[300] : Colors.blue[800],
                      ),
                    ),
                    title: Text(
                      currentClientNote.isEmpty
                          ? "Agregar Nota al Cliente (CRM)"
                          : "Editar Nota del Cliente",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      "Se guardará en el perfil general del cliente.",
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _showEditNoteDialog(
                        type: 'client',
                        currentNote: currentClientNote,
                        id: clientId,
                      );
                    },
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }
}
