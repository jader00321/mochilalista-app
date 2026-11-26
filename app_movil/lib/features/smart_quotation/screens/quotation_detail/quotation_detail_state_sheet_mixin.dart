part of '../quotation_detail_screen.dart';

mixin _QuotationDetailStateSheetMixin on _QuotationDetailScreenStateBase {
  @override
  void _showStateSelectorModal(bool isDark) {
    final currentStatus = _fullQuotation?.status ?? 'DRAFT';
    final bool isSold = currentStatus == 'SOLD';
    final workbenchProv = Provider.of<WorkbenchProvider>(
      context,
      listen: false,
    );

    InteractiveSheetWrapper.show(
      context: context,
      builder: (sheetCtx) => InteractiveSheetWrapper(
        title: isSold ? "Cotización Vendida" : "Opciones de Cotización",
        icon: isSold ? Icons.verified : Icons.tune,
        iconColor: isSold
            ? (isDark ? Colors.green[400]! : Colors.green[800]!)
            : (isDark ? Colors.blue[300] : Colors.blue[700]),
        maxHeightFactor: 0.85,
        applyEffectiveBottomPadding: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(
            bottom: InteractiveSheetWrapper.kModalScrollBottomClearance,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSold) ...[
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock,
                        size: 18,
                        color: isDark ? Colors.green[300] : Colors.green[800],
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Cotización Vendida (Histórico Inmutable). Puedes duplicarla para crear un nuevo borrador o compartirla.",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.green[200]
                                : Colors.green[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isDark
                        ? Colors.blue.withValues(alpha: 0.2)
                        : Colors.blue[50],
                    child: Icon(
                      Icons.copy_all,
                      color: isDark ? Colors.blue[300] : Colors.blue[700],
                    ),
                  ),
                  title: const Text(
                    "Duplicar Cotización",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    "Crea un nuevo borrador editable basado en esta cotización",
                  ),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    final newId = await workbenchProv.cloneQuotation(
                      widget.quotationId,
                    );
                    if (newId != null && mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              QuotationDetailScreen(quotationId: newId),
                        ),
                      );
                      CustomSnackBar.show(
                        context,
                        message: "Cotización duplicada como nuevo borrador",
                        isError: false,
                      );
                    }
                  },
                ),
                const SizedBox(height: 12),
              ] else ...[
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isDark
                        ? Colors.blue.withValues(alpha: 0.2)
                        : Colors.blue[50],
                    child: Icon(
                      Icons.edit,
                      color: isDark ? Colors.blue[300] : Colors.blue[700],
                    ),
                  ),
                  title: const Text(
                    "Cambiar Nombre / Cliente",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text("Actualiza el título de esta lista"),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _showRenameDialog(isDark);
                  },
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "ESTADO DE LA COTIZACIÓN",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                if (currentStatus != 'DRAFT')
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey.withValues(alpha: 0.2),
                      child: const Icon(Icons.edit_note, color: Colors.grey),
                    ),
                    title: const Text(
                      "Borrador",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text("Mover a preparación inicial"),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _changeStatus('DRAFT');
                    },
                  ),
                if (currentStatus != 'PENDING')
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.withValues(alpha: 0.2),
                      child: const Icon(
                        Icons.access_time,
                        color: Colors.orange,
                      ),
                    ),
                    title: const Text(
                      "Pendiente (Revisar)",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      "Lista en proceso de armado o revisión",
                    ),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _changeStatus('PENDING');
                    },
                  ),
                if (currentStatus != 'READY')
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.withValues(alpha: 0.2),
                      child: const Icon(
                        Icons.check_circle_outline,
                        color: Colors.blue,
                      ),
                    ),
                    title: const Text(
                      "Listo para Vender",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      "Lista armada y validada para despacho",
                    ),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _changeStatus('READY');
                    },
                  ),
                const Divider(),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.withValues(alpha: 0.2),
                    child: const Icon(Icons.inventory_2, color: Colors.teal),
                  ),
                  title: const Text(
                    "Convertir en Pack Escolar",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text("Guardar como plantilla reutilizable"),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _confirmConvertToPack(workbenchProv);
                  },
                ),
                if (currentStatus != 'ARCHIVED')
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.purple.withValues(alpha: 0.2),
                      child: const Icon(
                        Icons.archive_outlined,
                        color: Colors.purple,
                      ),
                    ),
                    title: const Text(
                      "Archivar",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      "Ocultar de la Mesa de Trabajo activa",
                    ),
                    onTap: () {
                      Navigator.pop(sheetCtx);
                      _changeStatus('ARCHIVED');
                    },
                  ),
                Divider(color: isDark ? Colors.white10 : Colors.grey[200]),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.red.withValues(alpha: 0.15),
                    child: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
                  title: const Text(
                    "Eliminar cotización / borrador",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text(
                    "Eliminar definitivamente esta cotización",
                  ),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    _handleDeleteRequest();
                  },
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
