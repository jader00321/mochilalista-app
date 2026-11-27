part of '../quick_sale_header.dart';

mixin _QuickSaleClientActionsMixin on _QuickSaleHeaderBase {
  void _showExplorationModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.explore, color: Colors.orange[400]),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                "Modo Exploración",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          "La base de datos de clientes está bloqueada en el Modo Exploración.\n\nPara buscar clientes reales de tu tienda, necesitas registrar un negocio desde tu Perfil.",
          style: TextStyle(
            color: widget.isDark ? Colors.grey[300] : Colors.grey[700],
            fontSize: 16,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "Entendido",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  void _openClientSearch(BuildContext context, QuickSaleProvider quickProv) {
    if (widget.isGuest) {
      _showExplorationModal(context);
      return;
    }

    ClientSearchModal.show(
      context,
      onClientSelected: (selectedClient) {
        quickProv.setClientInfo(client: selectedClient);
        setState(() {
          _isEditingClient = false;
        });
      },
    );
  }

  @override
  Future<void> _saveClientChanges(QuickSaleProvider quickProv) async {
    final client = quickProv.selectedClient;
    if (client == null || client.id == 0) {
      return;
    }

    final newName = _nameCtrl.text.trim();
    if (newName.isEmpty) {
      AppFeedbackHelper.showError(
        context,
        "El nombre del cliente no puede estar vacío",
      );
      return;
    }

    setState(() => _isSavingClient = true);

    try {
      final updatedData = {
        'nombre_completo': newName,
        'telefono': _phoneCtrl.text.replaceAll(' ', '').trim(),
        'dni_ruc': _dniCtrl.text.trim().isEmpty ? null : _dniCtrl.text.trim(),
        'direccion': _addressCtrl.text.trim().isEmpty
            ? null
            : _addressCtrl.text.trim(),
        'notas': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      };

      final updatedClient = await _clientService.updateClient(
        client.id,
        updatedData,
      );
      quickProv.updateSelectedClientData(updatedClient);

      if (mounted) {
        setState(() {
          _isEditingClient = false;
          _isSavingClient = false;
        });
        AppFeedbackHelper.showSuccess(
          context,
          "Datos del cliente actualizados en el directorio",
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingClient = false);
        AppFeedbackHelper.showError(context, "Error actualizando cliente: $e");
      }
    }
  }

  @override
  Future<void> _registerWalkInClient(QuickSaleProvider quickProv) async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      AppFeedbackHelper.showSnackBar(
        context,
        "Por favor ingresa al menos el nombre para registrar al cliente",
        backgroundColor: Colors.orangeAccent,
      );
      return;
    }

    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final negocioId = authProv.activeBusinessId;
    final usuarioId = authProv.user?.id ?? 0;

    if (negocioId == null) {
      AppFeedbackHelper.showError(
        context,
        "No hay un negocio activo para registrar el cliente",
      );
      return;
    }

    setState(() => _isSavingClient = true);

    try {
      final clientData = {
        'nombre_completo': name,
        'telefono': _phoneCtrl.text.replaceAll(' ', '').trim(),
        'dni_ruc': _dniCtrl.text.trim().isEmpty ? null : _dniCtrl.text.trim(),
        'direccion': _addressCtrl.text.trim().isEmpty
            ? null
            : _addressCtrl.text.trim(),
        'notas': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      };

      final newClient = await _clientService.createClient(
        clientData,
        negocioId,
        usuarioId,
      );
      quickProv.updateSelectedClientData(newClient);

      if (mounted) {
        setState(() {
          _isSavingClient = false;
          _showExtraWalkInFields = false;
        });
        AppFeedbackHelper.showSuccess(
          context,
          "Cliente '${newClient.fullName}' registrado y vinculado",
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingClient = false);
        AppFeedbackHelper.showError(context, "Error registrando cliente: $e");
      }
    }
  }

  @override
  String _formatPhone(String phone) {
    final String clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.length == 9) {
      return "${clean.substring(0, 3)} ${clean.substring(3, 6)} ${clean.substring(6, 9)}";
    }
    return phone;
  }
}

class _PhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (text.length > 9) {
      text = text.substring(0, 9);
    }
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 3 == 0) {
        buffer.write(' ');
      }
      buffer.write(text[i]);
    }
    final newText = buffer.toString();
    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
