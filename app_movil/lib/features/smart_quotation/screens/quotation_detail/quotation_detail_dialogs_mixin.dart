part of '../quotation_detail_screen.dart';

mixin _QuotationDetailDialogsMixin on _QuotationDetailScreenStateBase {
  @override
  Future<void> _changeStatus(
    String newStatus, {
    bool isAutoRevert = false,
  }) async {
    final workbenchProv = Provider.of<WorkbenchProvider>(
      context,
      listen: false,
    );
    final validation = workbenchProv.getValidationFor(widget.quotationId);

    if (newStatus == 'READY' && validation != null) {
      if (!validation.canSell || validation.sharedStockConflicts.isNotEmpty) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Theme.of(context).cardTheme.color,
            title: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange[400]),
                const SizedBox(width: 10),
                const Flexible(child: Text("Atención")),
              ],
            ),
            content: Text(
              validation.sharedStockConflicts.isNotEmpty
                  ? "No puedes marcar como 'Listo para Vender' porque hay un conflicto de stock compartido entre variantes de un mismo producto.\n\nPor favor usa el botón 'CORREGIR' primero."
                  : "No puedes marcar como 'Listo para Vender' porque hay productos agotados o con stock insuficiente.\n\nPor favor usa el botón 'CORREGIR' primero.",
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white70
                    : Colors.black87,
                fontSize: 16,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Entendido", style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        );
        return;
      }
    }

    if (newStatus == 'CONVERT_PACK') {
      _confirmConvertToPack(workbenchProv);
      return;
    }

    final bool success = await workbenchProv.changeQuotationStatus(
      widget.quotationId,
      newStatus,
    );

    if (success && mounted) {
      if (isAutoRevert) {
        CustomSnackBar.show(
          context,
          message: "Estado cambiado a Pendiente por cambios en inventario.",
          backgroundColor: Colors.orange[800]!,
          icon: Icons.info_outline,
        );
      } else {
        String msg = "Estado actualizado";
        if (newStatus == 'READY') {
          msg = "Lista marcada como LISTA para vender";
        }
        if (newStatus == 'ARCHIVED') {
          msg = "Lista archivada";
        }
        CustomSnackBar.show(context, message: msg, isError: false);
      }
      _loadData();
    }
  }

  @override
  void _confirmConvertToPack(WorkbenchProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        title: const Text(
          "Crear Pack Escolar",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Se creará una copia de esta lista como plantilla 'Pack Escolar'.\n\n¿Deseas continuar?",
          style: TextStyle(
            color: isDark ? Colors.grey[300] : Colors.grey[700],
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar", style: TextStyle(fontSize: 16)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.blue[300] : Colors.blue[800],
              foregroundColor: isDark ? Colors.black87 : Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final int? newPackId = await provider.convertToPack(
                widget.quotationId,
              );
              if (newPackId != null && mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        QuotationDetailScreen(quotationId: newPackId),
                  ),
                );
                CustomSnackBar.show(
                  context,
                  message: "Pack creado exitosamente",
                  isError: false,
                );
              } else if (mounted) {
                CustomSnackBar.show(
                  context,
                  message: "Error al crear el pack",
                  isError: true,
                );
              }
            },
            child: const Text(
              "Crear Pack",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void _handleDeleteRequest() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = _fullQuotation?.status;

    if (status == 'SOLD') {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            "Acción no permitida",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            "Una cotización vendida forma parte del historial contable y no se puede eliminar.",
            style: TextStyle(
              color: isDark ? Colors.grey[300] : Colors.grey[700],
              fontSize: 15,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Entendido", style: TextStyle(fontSize: 15)),
            ),
          ],
        ),
      );
      return;
    }

    final isDraft = status == 'DRAFT';
    final titleText = isDraft ? "¿Eliminar borrador?" : "¿Eliminar cotización?";
    final messageText = isDraft
        ? "¿Estás seguro de que deseas eliminar este borrador? Esta acción es irreversible."
        : "Esta cotización está en proceso.\n\n¿Estás seguro de que deseas eliminarla definitivamente? Esta acción es irreversible.";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: isDark ? Colors.red[300] : Colors.red[700],
              size: 26,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                titleText,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          messageText,
          style: TextStyle(
            color: isDark ? Colors.grey[300] : Colors.grey[700],
            fontSize: 15,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "Cancelar",
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.red[800] : Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final prov = Provider.of<WorkbenchProvider>(
                context,
                listen: false,
              );
              final bool success = await prov.deleteQuotation(
                widget.quotationId,
              );
              if (success && mounted) {
                Navigator.pop(context);
                CustomSnackBar.show(
                  context,
                  message: "Cotización eliminada exitosamente",
                  isError: false,
                );
              } else if (mounted) {
                CustomSnackBar.show(
                  context,
                  message: "Error al eliminar la cotización",
                  isError: true,
                );
              }
            },
            child: const Text(
              "Sí, Eliminar",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void _showQuotationNameDialog(bool isDark) {
    final title = _fullQuotation?.clientName ?? widget.clientName ?? "Detalle";
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        title: Row(
          children: [
            Icon(
              Icons.description_outlined,
              color: isDark ? Colors.blue[300] : Colors.blue[800],
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                "Nombre de la Lista",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: SelectableText(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.blueGrey[900],
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 18),
            label: const Text("Copiar"),
            onPressed: () {
              Navigator.pop(ctx);
              ClipboardHelper.copyWithFeedback(
                context,
                title,
                feedbackMessage: "Nombre copiado",
              );
            },
          ),
          if (_fullQuotation?.status != 'SOLD' &&
              !Provider.of<AuthProvider>(
                context,
                listen: false,
              ).isCommunityClient)
            ElevatedButton.icon(
              icon: const Icon(Icons.edit, size: 18),
              label: const Text("Editar"),
              onPressed: () {
                Navigator.pop(ctx);
                _showRenameDialog(isDark);
              },
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cerrar"),
          ),
        ],
      ),
    );
  }

  @override
  void _showRenameDialog(bool isDark) {
    final controller = TextEditingController(
      text: _fullQuotation?.clientName ?? "",
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        title: const Text(
          "Cambiar Nombre",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: "Nombre o Cliente",
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.restore_outlined),
              tooltip: "Restaurar nombre automático",
              onPressed: () {
                controller.text = QuotationNamingEngine.generateTitle(
                  typedClientName: _fullQuotation?.clientName,
                  schoolName: _fullQuotation?.institutionName,
                  gradeLevel: _fullQuotation?.gradeLevel,
                  quotationType: _fullQuotation?.type ?? 'manual',
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () async {
              String newName = controller.text.trim();
              if (newName.isEmpty) {
                newName = QuotationNamingEngine.generateTitle(
                  typedClientName: _fullQuotation?.clientName,
                  schoolName: _fullQuotation?.institutionName,
                  gradeLevel: _fullQuotation?.gradeLevel,
                  quotationType: _fullQuotation?.type ?? 'manual',
                );
              }
              if (newName.isNotEmpty) {
                Navigator.pop(ctx);
                final workbenchProv = Provider.of<WorkbenchProvider>(
                  context,
                  listen: false,
                );
                final ok = await workbenchProv.renameQuotation(
                  widget.quotationId,
                  newName,
                );
                if (ok) {
                  _loadData();
                  if (mounted) {
                    CustomSnackBar.show(
                      context,
                      message: "Nombre actualizado",
                      isError: false,
                    );
                  }
                }
              }
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  @override
  void _showTextEvidenceDialog(bool isDark) {
    String fullText = _fullQuotation?.originalTextDump ?? "";
    if (fullText.isEmpty && _fullQuotation != null) {
      final itemsText = _fullQuotation!.items
          .where((i) => i.originalText != null && i.originalText!.isNotEmpty)
          .map((i) => "- ${i.originalText}")
          .join("\n");
      if (itemsText.isNotEmpty) {
        fullText =
            "$itemsText\n\n(Nota: Mostrando texto parcial de items vinculados)";
      }
    }
    if (fullText.isEmpty) {
      fullText = "No hay texto registrado.";
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        title: Text(
          "Texto Extraído",
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              fullText,
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.grey[300] : Colors.black87,
              ),
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            icon: Icon(
              Icons.copy,
              color: isDark ? Colors.blue[300] : Colors.blue,
            ),
            label: Text(
              "Copiar",
              style: TextStyle(
                color: isDark ? Colors.blue[300] : Colors.blue,
                fontSize: 16,
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ClipboardHelper.copyWithFeedback(
                context,
                fullText,
                feedbackMessage: "Texto copiado",
              );
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "Cerrar",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}
