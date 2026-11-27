part of '../sale_financial_detail_screen.dart';

mixin _SaleFinancialLogisticsDialogsMixin
    on _SaleFinancialDetailScreenStateBase {
  void _showChangeStatusDialog(String currentStatus, bool isDark) {
    String selectedStatus = currentStatus;
    final dialogBgColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogBgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(
              Icons.local_shipping,
              color: isDark ? Colors.blue[300] : Colors.blue,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Estado Logístico",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Selecciona el nuevo estado de entrega:",
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildRadioTile(
                    "Entregado al instante",
                    'entregado',
                    selectedStatus,
                    Icons.inventory_2,
                    isDark ? Colors.green[400]! : Colors.green,
                    isDark,
                    (val) => setDialogState(() => selectedStatus = val),
                  ),
                  _buildRadioTile(
                    "Pendiente de Recojo",
                    'pendiente_recojo',
                    selectedStatus,
                    Icons.storefront,
                    isDark ? Colors.orange[400]! : Colors.orange,
                    isDark,
                    (val) => setDialogState(() => selectedStatus = val),
                  ),
                  _buildRadioTile(
                    "En Camino (Delivery)",
                    'en_camino',
                    selectedStatus,
                    Icons.delivery_dining,
                    isDark ? Colors.purple[300]! : Colors.purple,
                    isDark,
                    (val) => setDialogState(() => selectedStatus = val),
                  ),
                  _buildRadioTile(
                    "Retenido por Pago",
                    'retenido_por_pago',
                    selectedStatus,
                    Icons.lock_clock,
                    isDark ? Colors.red[400]! : Colors.red,
                    isDark,
                    (val) => setDialogState(() => selectedStatus = val),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "Cancelar",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[800],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => _applyDeliveryStatusChange(
              ctx: ctx,
              selectedStatus: selectedStatus,
              currentStatus: currentStatus,
              isDark: isDark,
            ),
            child: const Text(
              "Guardar",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _applyDeliveryStatusChange({
    required BuildContext ctx,
    required String selectedStatus,
    required String currentStatus,
    required bool isDark,
  }) async {
    Navigator.pop(ctx);
    final provider = Provider.of<SaleProvider>(context, listen: false);

    String? fotoPath;
    if (selectedStatus == 'entregado' && currentStatus != 'entregado') {
      final bool? takePhoto = await showDialog<bool>(
        context: context,
        builder: (ctx2) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.camera_alt, color: Colors.blue[600], size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Evidencia de Entrega",
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            "Recomendamos tomar una foto de los productos o de la guía firmada. ¿Deseas capturarla ahora?",
            style: TextStyle(
              color: isDark ? Colors.grey[300] : Colors.grey[700],
              fontSize: 16,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx2, false),
              child: Text(
                "No, solo marcar",
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[800],
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx2, true),
              child: const Text("Sí, tomar foto"),
            ),
          ],
        ),
      );

      if (takePhoto == true) {
        final XFile? image = await ImagePicker().pickImage(
          source: ImageSource.camera,
          imageQuality: 70,
        );
        if (image != null) {
          try {
            final Directory appDocDir =
                await getApplicationDocumentsDirectory();
            final String newPath = p.join(
              appDocDir.path,
              'entrega_${widget.saleId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
            );
            final File savedImage = await File(image.path).copy(newPath);
            fotoPath = savedImage.path;
          } catch (e) {
            debugPrint("Error guardando foto: $e");
          }
        }
      }
    }

    if (!mounted) return;
    setState(() => _isLoading = true);
    final success = await provider.updateDeliveryStatus(
      widget.saleId,
      selectedStatus,
      fotoPath: fotoPath,
    );

    if (success) {
      if (mounted) {
        AppFeedbackHelper.showSnackBar(
          context,
          "Logística actualizada",
          backgroundColor: Colors.green,
        );
      }
      await _loadData();
    } else {
      if (mounted) {
        AppFeedbackHelper.showSnackBar(
          context,
          provider.errorMessage,
          backgroundColor: Colors.red,
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildRadioTile(
    String title,
    String value,
    String groupValue,
    IconData icon,
    Color color,
    bool isDark,
    Function(String) onChanged,
  ) {
    final bool isSelected = value == groupValue;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
        border: Border.all(
          color: isSelected
              ? color
              : (isDark ? Colors.white10 : Colors.grey.shade300),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: RadioListTile(
        title: Row(
          children: [
            Icon(icon, size: 20, color: isSelected ? color : Colors.grey),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 15,
                  color: isSelected
                      ? color
                      : (isDark ? Colors.white : Colors.black87),
                ),
              ),
            ),
          ],
        ),
        value: value,
        // ignore: deprecated_member_use
        groupValue: groupValue,
        activeColor: color,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        // ignore: deprecated_member_use
        onChanged: (val) => onChanged(val.toString()),
      ),
    );
  }

  Widget _buildLogisticsCard(bool isDark, Color cardColor) {
    final String deliveryStatus = _saleData!['estado_entrega'] ?? 'entregado';
    String title = "Entregado al Instante";
    String subtitle = "El cliente ya tiene sus productos.";
    IconData icon = Icons.inventory_2;
    Color color = isDark ? Colors.green[400]! : Colors.green;

    if (deliveryStatus == 'retenido_por_pago') {
      title = "Retenido por Pago";
      subtitle = "Esperando cancelación de deuda.";
      icon = Icons.lock_clock;
      color = isDark ? Colors.red[400]! : Colors.red;
    } else if (deliveryStatus == 'pendiente_recojo') {
      title = "Pendiente de Recojo";
      subtitle = "Programado para entregar.";
      icon = Icons.storefront;
      color = isDark ? Colors.orange[400]! : Colors.orange;
    } else if (deliveryStatus == 'en_camino') {
      title = "En Camino (Delivery)";
      subtitle = "Paquete despachado.";
      icon = Icons.local_shipping;
      color = isDark ? Colors.purple[300]! : Colors.purple;
    }

    final String? fotoEntrega = _saleData!['foto_entrega'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: color.withValues(alpha: 0.2),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Logística: $title",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[700],
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, size: 24),
                color: color,
                tooltip: "Modificar Estado",
                onPressed: () =>
                    _showChangeStatusDialog(deliveryStatus, isDark),
              ),
            ],
          ),
          if (fotoEntrega != null && fotoEntrega.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.black12,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextButton.icon(
                icon: Icon(
                  Icons.photo_camera,
                  color: isDark ? Colors.blue[300] : Colors.blue[800],
                ),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "Ver Foto de Entrega",
                    style: TextStyle(
                      color: isDark ? Colors.blue[300] : Colors.blue[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                onPressed: () {
                  final size = MediaQuery.sizeOf(context);
                  showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      backgroundColor: Colors.transparent,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: size.height * 0.72,
                          maxWidth: size.width * 0.9,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: UniversalImage(
                            path: fotoEntrega,
                            width: size.width * 0.85,
                            fit: BoxFit.contain,
                            productName: "Evidencia Entrega #${widget.saleId}",
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
