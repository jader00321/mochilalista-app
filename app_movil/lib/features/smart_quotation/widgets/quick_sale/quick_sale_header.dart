import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/features/smart_quotation/services/client_service.dart';
import 'package:app_movil/features/smart_quotation/widgets/manual/client_search_modal.dart';
import 'package:app_movil/core/widgets/morphing_accordion.dart';

class QuickSaleHeader extends StatefulWidget {
  final bool isGuest;
  final bool isDark;

  const QuickSaleHeader({super.key, required this.isGuest, required this.isDark});

  @override
  State<QuickSaleHeader> createState() => _QuickSaleHeaderState();
}

class _QuickSaleHeaderState extends State<QuickSaleHeader> {
  final ClientService _clientService = ClientService();

  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _dniCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _notesCtrl;

  bool _isEditingClient = false;
  bool _showExtraWalkInFields = false;
  bool _isSavingClient = false;

  int? _lastClientId;
  String? _lastClientName;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _dniCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _dniCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = Provider.of<QuickSaleProvider>(context, listen: false);
    _syncFromProvider(provider);
  }

  void _syncFromProvider(QuickSaleProvider provider) {
    // Detectamos si el cliente cambió de ID o si se desvinculó/vació el carrito externamente
    final idChanged = provider.clientId != _lastClientId;
    final clearedExternally = provider.clientId == null &&
        provider.clientName == null &&
        (_lastClientId != null || (_lastClientName != null && _lastClientName!.isNotEmpty));
    final clientAssigned = provider.selectedClient != null &&
        provider.selectedClient!.id != _lastClientId;

    if (idChanged || clearedExternally || clientAssigned) {
      _lastClientId = provider.clientId;
      _lastClientName = provider.clientName;
      _isEditingClient = false;
      _showExtraWalkInFields = false;

      final client = provider.selectedClient;
      if (client != null) {
        _nameCtrl.text = client.fullName;
        _phoneCtrl.text = client.phone;
        _dniCtrl.text = client.docNumber ?? '';
        _addressCtrl.text = client.address ?? '';
        _notesCtrl.text = client.notes ?? '';
      } else {
        _nameCtrl.text = provider.clientName ?? '';
        _phoneCtrl.text = provider.clientPhone ?? '';
        _dniCtrl.clear();
        _addressCtrl.clear();
        _notesCtrl.text = provider.clientNote ?? '';
      }
    }
  }

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
            const Text("Modo Exploración", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          "La base de datos de clientes está bloqueada en el Modo Exploración.\n\nPara buscar clientes reales de tu tienda, necesitas registrar un negocio desde tu Perfil.",
          style: TextStyle(color: widget.isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 16, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Entendido", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          )
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

  Future<void> _saveClientChanges(QuickSaleProvider quickProv) async {
    final client = quickProv.selectedClient;
    if (client == null || client.id == 0) return;

    final messenger = ScaffoldMessenger.of(context);
    final newName = _nameCtrl.text.trim();
    if (newName.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("El nombre del cliente no puede estar vacío"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSavingClient = true);

    try {
      final updatedData = {
        'nombre_completo': newName,
        'telefono': _phoneCtrl.text.replaceAll(' ', '').trim(),
        'dni_ruc': _dniCtrl.text.trim().isEmpty ? null : _dniCtrl.text.trim(),
        'direccion': _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        'notas': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      };

      final updatedClient = await _clientService.updateClient(client.id, updatedData);
      quickProv.updateSelectedClientData(updatedClient);

      if (mounted) {
        setState(() {
          _isEditingClient = false;
          _isSavingClient = false;
        });
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text("Datos del cliente actualizados en el directorio"),
              ],
            ),
            backgroundColor: const Color(0xFF00C853),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingClient = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text("Error actualizando cliente: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _registerWalkInClient(QuickSaleProvider quickProv) async {
    final messenger = ScaffoldMessenger.of(context);
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Por favor ingresa al menos el nombre para registrar al cliente"),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final negocioId = authProv.activeBusinessId;
    final usuarioId = authProv.user?.id ?? 0;

    if (negocioId == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("No hay un negocio activo para registrar el cliente"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSavingClient = true);

    try {
      final clientData = {
        'nombre_completo': name,
        'telefono': _phoneCtrl.text.replaceAll(' ', '').trim(),
        'dni_ruc': _dniCtrl.text.trim().isEmpty ? null : _dniCtrl.text.trim(),
        'direccion': _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        'notas': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      };

      final newClient = await _clientService.createClient(clientData, negocioId, usuarioId);
      quickProv.updateSelectedClientData(newClient);

      if (mounted) {
        setState(() {
          _isSavingClient = false;
          _showExtraWalkInFields = false;
        });
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text("Cliente '${newClient.fullName}' registrado y vinculado")),
              ],
            ),
            backgroundColor: const Color(0xFF00C853),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSavingClient = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text("Error registrando cliente: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  String _formatPhone(String phone) {
    String clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.length == 9) {
      return "${clean.substring(0, 3)} ${clean.substring(3, 6)} ${clean.substring(6, 9)}";
    }
    return phone;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<QuickSaleProvider>(context);
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    _syncFromProvider(provider);

    final hasSaldo = provider.clientSaldo > 0;
    final selectedClient = provider.selectedClient;
    final hasDebt = selectedClient != null && selectedClient.totalDebt > 0;

    Widget? badgeWidget;
    if (hasSaldo) {
      badgeWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF00E676).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.4)),
        ),
        child: Text(
          "S/ ${provider.clientSaldo.toStringAsFixed(2)} a favor",
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF00E676),
          ),
        ),
      );
    } else if (hasDebt) {
      badgeWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFFFF5252).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFF5252).withValues(alpha: 0.4)),
        ),
        child: Text(
          "Deuda: S/ ${selectedClient.totalDebt.toStringAsFixed(2)}",
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFF5252),
          ),
        ),
      );
    } else if (provider.clientId != null) {
      badgeWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: (widget.isDark ? const Color(0xFF42A5F5) : Colors.blue).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          "Vinculado",
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: widget.isDark ? const Color(0xFF64B5F6) : const Color(0xFF1565C0),
          ),
        ),
      );
    } else if (provider.clientName != null && provider.clientName!.isNotEmpty) {
      badgeWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.amber.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
        ),
        child: Text(
          "Cliente de Paso",
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: widget.isDark ? Colors.amber[300] : Colors.amber[800],
          ),
        ),
      );
    }

    return MorphingAccordion(
      title: provider.clientName ?? "Datos del Cliente (Opcional)",
      icon: Icons.person_outline_rounded,
      iconColor: widget.isDark ? Colors.blue[300] : Colors.blue,
      summaryBadge: badgeWidget,
      backgroundColor: widget.isDark ? const Color(0xFF1E1E2A) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      content: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Botón de búsqueda de clientes en base de datos
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.person_search_rounded, size: 20),
                label: const Text(
                  "Buscar en Directorio de Clientes",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: widget.isDark ? Colors.blue[300] : Colors.blue[800],
                  side: BorderSide(
                    color: widget.isDark
                        ? Colors.blue.withValues(alpha: 0.3)
                        : Colors.blue.shade200,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _openClientSearch(context, provider),
              ),
            ),
            const SizedBox(height: 16),

            // Saldo a favor banner
            if (provider.clientSaldo > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? const Color(0xFF00E676).withValues(alpha: 0.12)
                      : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF00E676).withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF00C853), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Saldo a favor disponible: ${currency.format(provider.clientSaldo)}",
                        style: TextStyle(
                          color: widget.isDark ? const Color(0xFF69F0AE) : const Color(0xFF1B5E20),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Deuda pendiente banner
            if (hasDebt)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? const Color(0xFFFF5252).withValues(alpha: 0.12)
                      : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFFF5252).withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF5252), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Deuda acumulada pendiente: ${currency.format(selectedClient.totalDebt)}",
                        style: TextStyle(
                          color: widget.isDark ? const Color(0xFFFF8A80) : const Color(0xFFB71C1C),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Vista del cliente seleccionado de BD
            if (provider.clientId != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: widget.isDark ? const Color(0xFF23232F) : Colors.blue[50],
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: widget.isDark ? Colors.white12 : Colors.blue.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: widget.isDark
                              ? Colors.blue.withValues(alpha: 0.25)
                              : Colors.blue[200],
                          radius: 22,
                          child: Text(
                            provider.clientName!.isNotEmpty
                                ? provider.clientName![0].toUpperCase()
                                : "?",
                            style: TextStyle(
                              color: widget.isDark ? Colors.blue[300] : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                provider.clientName!,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: widget.isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              if (provider.clientPhone != null && provider.clientPhone!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(Icons.smartphone_rounded, size: 13, color: widget.isDark ? Colors.grey[400] : Colors.grey[700]),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatPhone(provider.clientPhone!),
                                      style: TextStyle(
                                        color: widget.isDark ? Colors.grey[300] : Colors.grey[700],
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (selectedClient?.docNumber != null && selectedClient!.docNumber!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(Icons.badge_outlined, size: 13, color: widget.isDark ? Colors.grey[400] : Colors.grey[700]),
                                    const SizedBox(width: 4),
                                    Text(
                                      "DNI/RUC: ${selectedClient.docNumber}",
                                      style: TextStyle(
                                        color: widget.isDark ? Colors.grey[300] : Colors.grey[700],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (selectedClient?.address != null && selectedClient!.address!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(Icons.location_on_outlined, size: 13, color: widget.isDark ? Colors.grey[400] : Colors.grey[700]),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        selectedClient.address!,
                                        style: TextStyle(
                                          color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              if (provider.clientNote != null && provider.clientNote!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  "Nota: ${provider.clientNote}",
                                  style: TextStyle(
                                    color: widget.isDark ? Colors.teal[300] : Colors.teal[700],
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Botón de toggle para editar in-situ
                        IconButton(
                          icon: Icon(
                            _isEditingClient ? Icons.close_rounded : Icons.edit_note_rounded,
                            color: widget.isDark ? Colors.blue[300] : Colors.blue[700],
                          ),
                          tooltip: _isEditingClient ? "Cerrar edición" : "Editar datos del cliente",
                          onPressed: () {
                            setState(() {
                              _isEditingClient = !_isEditingClient;
                            });
                          },
                        ),
                      ],
                    ),

                    // Formulario de edición in-situ expandible
                    AnimatedSize(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                      child: _isEditingClient
                          ? Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Divider(color: widget.isDark ? Colors.white12 : Colors.blue.shade100),
                                  const SizedBox(height: 6),
                                  Text(
                                    "Editar Ficha del Cliente:",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: widget.isDark ? Colors.blue[200] : Colors.blue[900],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  _buildTextField(
                                    controller: _nameCtrl,
                                    label: "Nombre Completo",
                                    icon: Icons.person_outline,
                                    isDark: widget.isDark,
                                  ),
                                  const SizedBox(height: 10),
                                  _buildTextField(
                                    controller: _phoneCtrl,
                                    label: "Teléfono / WhatsApp",
                                    icon: Icons.phone_outlined,
                                    isDark: widget.isDark,
                                    isPhone: true,
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 4,
                                        child: _buildTextField(
                                          controller: _dniCtrl,
                                          label: "DNI / RUC",
                                          icon: Icons.badge_outlined,
                                          isDark: widget.isDark,
                                          keyboardType: TextInputType.number,
                                          maxLength: 11,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 5,
                                        child: _buildTextField(
                                          controller: _addressCtrl,
                                          label: "Dirección",
                                          icon: Icons.location_on_outlined,
                                          isDark: widget.isDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  _buildTextField(
                                    controller: _notesCtrl,
                                    label: "Notas Internas del Cliente",
                                    icon: Icons.note_outlined,
                                    isDark: widget.isDark,
                                    maxLines: 2,
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 42,
                                    child: ElevatedButton.icon(
                                      onPressed: _isSavingClient ? null : () => _saveClientChanges(provider),
                                      icon: _isSavingClient
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                            )
                                          : const Icon(Icons.check_rounded, size: 18),
                                      label: Text(
                                        _isSavingClient ? "Guardando en BD..." : "Guardar Cambios del Cliente",
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF2563EB),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Botón desvincular
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    provider.setClientInfo(
                      id: null,
                      name: null,
                      phone: null,
                      clientNote: null,
                      saleNote: provider.saleNote,
                      saldo: 0,
                    );
                    setState(() {
                      _isEditingClient = false;
                      _nameCtrl.clear();
                      _phoneCtrl.clear();
                      _dniCtrl.clear();
                      _addressCtrl.clear();
                      _notesCtrl.clear();
                    });
                  },
                  icon: const Icon(Icons.person_off_outlined, color: Colors.redAccent, size: 16),
                  label: const Text(
                    "Desvincular Cliente",
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.red.withValues(alpha: 0.08),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ] else ...[
              // Sección de Cliente de Paso
              Text(
                "O registra un cliente de paso:",
                style: TextStyle(
                  color: widget.isDark ? Colors.grey[400] : Colors.grey[700],
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              _buildTextField(
                controller: _nameCtrl,
                label: "Nombre del Cliente",
                icon: Icons.person_outline,
                isDark: widget.isDark,
                onChanged: (val) {
                  provider.setClientInfo(
                    id: null,
                    name: val.trim().isEmpty ? null : val,
                    phone: provider.clientPhone,
                    clientNote: provider.clientNote,
                    saleNote: provider.saleNote,
                    saldo: 0,
                  );
                },
              ),
              const SizedBox(height: 10),
              _buildTextField(
                controller: _phoneCtrl,
                label: "Teléfono / WhatsApp",
                icon: Icons.phone_outlined,
                isDark: widget.isDark,
                isPhone: true,
                onChanged: (val) {
                  final cleanPhone = val.replaceAll(' ', '');
                  provider.setClientInfo(
                    id: null,
                    name: provider.clientName,
                    phone: cleanPhone.trim().isEmpty ? null : cleanPhone,
                    clientNote: provider.clientNote,
                    saleNote: provider.saleNote,
                    saldo: 0,
                  );
                },
              ),
              const SizedBox(height: 6),

              // Botón desplegar datos adicionales para cliente de paso
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _showExtraWalkInFields = !_showExtraWalkInFields;
                      });
                    },
                    icon: Icon(
                      _showExtraWalkInFields ? Icons.remove_circle_outline : Icons.add_circle_outline,
                      size: 15,
                      color: widget.isDark ? Colors.blue[300] : Colors.blue[700],
                    ),
                    label: Text(
                      _showExtraWalkInFields ? "Ocultar datos extra" : "+ DNI, Dirección y Notas",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: widget.isDark ? Colors.blue[300] : Colors.blue[700],
                      ),
                    ),
                  ),

                  // Botón para guardar en directorio CRM
                  if (_nameCtrl.text.trim().isNotEmpty)
                    TextButton.icon(
                      onPressed: _isSavingClient ? null : () => _registerWalkInClient(provider),
                      icon: _isSavingClient
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF00C853)),
                            )
                          : const Icon(Icons.person_add_alt_1_rounded, size: 15, color: Color(0xFF00C853)),
                      label: Text(
                        "Guardar en Directorio",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: widget.isDark ? const Color(0xFF69F0AE) : const Color(0xFF2E7D32),
                        ),
                      ),
                    ),
                ],
              ),

              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: _showExtraWalkInFields
                    ? Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: _buildTextField(
                                    controller: _dniCtrl,
                                    label: "DNI / RUC",
                                    icon: Icons.badge_outlined,
                                    isDark: widget.isDark,
                                    keyboardType: TextInputType.number,
                                    maxLength: 11,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 5,
                                  child: _buildTextField(
                                    controller: _addressCtrl,
                                    label: "Dirección",
                                    icon: Icons.location_on_outlined,
                                    isDark: widget.isDark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _buildTextField(
                              controller: _notesCtrl,
                              label: "Notas de la Venta / Cliente",
                              icon: Icons.note_outlined,
                              isDark: widget.isDark,
                              onChanged: (val) {
                                provider.setClientInfo(
                                  clientNote: val.trim().isEmpty ? null : val.trim(),
                                );
                              },
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    bool isPhone = false,
    TextInputType? keyboardType,
    int? maxLength,
    int maxLines = 1,
    Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
      keyboardType: isPhone ? TextInputType.phone : (keyboardType ?? TextInputType.text),
      inputFormatters: isPhone
          ? [FilteringTextInputFormatter.digitsOnly, _PhoneFormatter()]
          : (maxLength != null ? [LengthLimitingTextInputFormatter(maxLength)] : null),
      maxLength: isPhone ? 11 : maxLength,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
        prefixIcon: Icon(icon, color: isDark ? Colors.blueGrey[300] : Colors.blueGrey, size: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        filled: true,
        fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100],
        isDense: true,
        counterText: "",
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      onChanged: onChanged,
    );
  }
}

class _PhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (text.length > 9) text = text.substring(0, 9);
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 3 == 0) buffer.write(' ');
      buffer.write(text[i]);
    }
    final newText = buffer.toString();
    return newValue.copyWith(text: newText, selection: TextSelection.collapsed(offset: newText.length));
  }
}