import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'dart:async';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/features/smart_quotation/services/client_service.dart';

class QuickSaleHeader extends StatelessWidget {
  final bool isGuest;
  final bool isDark;

  const QuickSaleHeader({super.key, required this.isGuest, required this.isDark});

  void _showExplorationModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
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
          style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 16, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Entendido", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      )
    );
  }

  void _openClientSearch(BuildContext context, QuickSaleProvider quickProv) {
    if (isGuest) {
       _showExplorationModal(context);
       return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _ClientSearchModal()
    ).then((selectedClient) {
      if (selectedClient != null) {
        quickProv.setClientInfo(
          id: selectedClient.id,
          name: selectedClient.fullName,
          phone: selectedClient.phone,
          saldo: selectedClient.saldoAFavor,
          clientNote: selectedClient.notes, 
          saleNote: quickProv.saleNote 
        );
      }
    });
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
    
    final headerColor = isDark ? const Color(0xFF14141C) : const Color(0xFF1F2937); // Gris muy oscuro
    final bodyColor = isDark ? const Color(0xFF1A1A24) : const Color(0xFF2D3748); // Gris medio oscuro

    final clientSubtitle = provider.clientId != null
        ? "Cliente Vinculado"
        : (provider.cartItems.isNotEmpty && provider.estimatedCartProfit > 0
            ? "Cliente anónimo · Ganancia est. ${currency.format(provider.estimatedCartProfit)}"
            : "Cliente anónimo o nuevo");

    return ExpansionTile(
      title: Text(provider.clientName ?? "Datos del Cliente (Opcional)", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
      subtitle: Text(clientSubtitle, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      iconColor: Colors.white,
      collapsedIconColor: Colors.white,
      backgroundColor: headerColor,
      collapsedBackgroundColor: bodyColor,
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.search, size: 20),
                  label: const Text("Buscar Cliente en BD", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  style: OutlinedButton.styleFrom(foregroundColor: isDark ? Colors.blue[300] : Colors.blue[800], side: BorderSide(color: isDark ? Colors.blue.withValues(alpha: 0.3) : Colors.blue.shade200), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: () => _openClientSearch(context, provider),
                ),
              ),
              const SizedBox(height: 20),

              if (provider.clientSaldo > 0)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: isDark ? Colors.amber.withValues(alpha: 0.1) : Colors.amber[50], borderRadius: BorderRadius.circular(10), border: Border.all(color: isDark ? Colors.amber.withValues(alpha: 0.3) : Colors.amber.shade200)),
                  child: Text("💰 Este cliente tiene un Saldo a Favor de ${currency.format(provider.clientSaldo)}", style: TextStyle(color: isDark ? Colors.amber[300] : Colors.amber[900], fontWeight: FontWeight.bold, fontSize: 14)),
                ),

              if (provider.clientId != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF23232F) : Colors.blue[50], 
                    borderRadius: BorderRadius.circular(16), 
                    border: Border.all(color: isDark ? Colors.white10 : Colors.blue.shade200)
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue[200], 
                        radius: 26,
                        child: Text(provider.clientName!.isNotEmpty ? provider.clientName![0].toUpperCase() : "?", style: TextStyle(color: isDark ? Colors.blue[300] : Colors.white, fontWeight: FontWeight.bold, fontSize: 24))
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(provider.clientName!, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : Colors.black87, height: 1.2)),
                            const SizedBox(height: 4),
                            if (provider.clientPhone != null && provider.clientPhone!.isNotEmpty)
                              Row(
                                children: [
                                  Icon(Icons.smartphone, size: 14, color: isDark ? Colors.grey[400] : Colors.grey[700]),
                                  const SizedBox(width: 6),
                                  Text(_formatPhone(provider.clientPhone!), style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 14, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            if (provider.clientNote != null && provider.clientNote!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text("Nota: ${provider.clientNote}", style: TextStyle(color: isDark ? Colors.teal[300] : Colors.teal, fontSize: 12, fontStyle: FontStyle.italic), maxLines: 2, overflow: TextOverflow.ellipsis),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.center,
                  child: TextButton.icon(
                    onPressed: () {
                      provider.setClientInfo(id: null, name: null, phone: null, clientNote: null, saleNote: provider.saleNote, saldo: 0);
                    }, 
                    icon: const Icon(Icons.person_off, color: Colors.red, size: 20),
                    label: const Text("Desvincular Cliente", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15)),
                    style: TextButton.styleFrom(backgroundColor: Colors.red.withValues(alpha: 0.1), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  ),
                )
              ] 
              else ...[
                Text("O ingresa un cliente de paso:", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: TextEditingController(text: provider.clientName)..selection = TextSelection.collapsed(offset: provider.clientName?.length ?? 0),
                  label: "Nombre del Cliente",
                  icon: Icons.person,
                  isDark: isDark,
                  onChanged: (val) => provider.setClientInfo(id: provider.clientId, name: val.trim().isEmpty ? null : val, phone: provider.clientPhone, clientNote: provider.clientNote, saleNote: provider.saleNote, saldo: provider.clientSaldo),
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: TextEditingController(text: provider.clientPhone)..selection = TextSelection.collapsed(offset: provider.clientPhone?.length ?? 0),
                  label: "Teléfono / WhatsApp",
                  icon: Icons.phone,
                  isDark: isDark,
                  isPhone: true,
                  onChanged: (val) {
                    final cleanPhone = val.replaceAll(' ', '');
                    provider.setClientInfo(id: provider.clientId, name: provider.clientName, phone: cleanPhone.trim().isEmpty ? null : cleanPhone, clientNote: provider.clientNote, saleNote: provider.saleNote, saldo: provider.clientSaldo);
                  }
                ),
              ],
            ],
          ),
        )
      ],
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, required bool isDark, bool isPhone = false, required Function(String) onChanged}) {
    return TextField(
      controller: controller,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16),
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      inputFormatters: isPhone ? [FilteringTextInputFormatter.digitsOnly, _PhoneFormatter()] : null,
      maxLength: isPhone ? 11 : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 15),
        prefixIcon: Icon(icon, color: isDark ? Colors.blueGrey[300] : Colors.blueGrey),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        filled: true,
        fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100],
        isDense: true,
        counterText: "",
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

// ----------------------------------------------------------------------
// MODAL DE BÚSQUEDA DE CLIENTES
// ----------------------------------------------------------------------
class _ClientSearchModal extends StatefulWidget {
  const _ClientSearchModal();
  @override
  State<_ClientSearchModal> createState() => _ClientSearchModalState();
}

class _ClientSearchModalState extends State<_ClientSearchModal> {
  final TextEditingController _ctrl = TextEditingController();
  List<dynamic> _results = [];
  bool _isLoading = false;
  Timer? _searchDebounce; 
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecentClients();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose(); 
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _loadRecentClients() async {
    setState(() => _isLoading = true);
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    if (authProv.activeBusinessId != null) {
      final clientService = ClientService();
      final results = await clientService.getRecentClients(authProv.activeBusinessId!);
      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchInput(String query) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _search(query);
    });
  }

  void _search(String query) async {
    if (query.isEmpty) {
      _loadRecentClients();
      return;
    }
    setState(() => _isLoading = true);
    final results = await Provider.of<SaleProvider>(context, listen: false).searchClients(query);
    if (mounted) {
      setState(() {
        _results = results;
        _isLoading = false;
      });
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(color: bgColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Buscar Cliente", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
              IconButton(icon: Icon(Icons.close, size: 28, color: textColor), onPressed: () => Navigator.pop(context))
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            style: TextStyle(color: textColor, fontSize: 16),
            decoration: InputDecoration(
              hintText: "Nombre, Teléfono o DNI...",
              hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey),
              prefixIcon: Icon(Icons.search, color: isDark ? Colors.blue[300] : Colors.blue),
              filled: true,
              fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100],
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              suffixIcon: _ctrl.text.isNotEmpty 
                ? IconButton(icon: Icon(Icons.clear, color: isDark ? Colors.grey : Colors.grey), onPressed: () { _ctrl.clear(); _search(""); })
                : null
            ),
            onChanged: _onSearchInput, 
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _results.isEmpty && _ctrl.text.isNotEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center, 
                      children: [
                        Icon(Icons.search_off, size: 60, color: isDark ? Colors.white10 : Colors.grey[300]), 
                        const SizedBox(height: 10), 
                        Text("No encontramos a '${_ctrl.text}'", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey, fontSize: 16)),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            final quickProv = Provider.of<QuickSaleProvider>(context, listen: false);
                            if (RegExp(r'^[0-9]+$').hasMatch(_ctrl.text.trim())) {
                               quickProv.setClientInfo(phone: _ctrl.text.trim(), name: null, id: null, saldo: 0, saleNote: quickProv.saleNote);
                            } else {
                               quickProv.setClientInfo(name: _ctrl.text.trim(), phone: null, id: null, saldo: 0, saleNote: quickProv.saleNote);
                            }
                          },
                          icon: const Icon(Icons.person_add),
                          label: const Text("Usar como cliente rápido"),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        )
                      ]
                    )
                  )
                : _results.isEmpty
                  ? Center(child: Text("Empieza a escribir para buscar...", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey)))
                  : ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
                      itemBuilder: (ctx, i) {
                        final c = _results[i];
                        final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                          leading: CircleAvatar(
                            backgroundColor: isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue[100], 
                            child: Text(
                              c.fullName.isNotEmpty ? c.fullName[0].toUpperCase() : "?",
                              style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue[800], fontWeight: FontWeight.bold, fontSize: 18)
                            )
                          ),
                          title: Row(
                            children: [
                              Expanded(child: Text(c.fullName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis)),
                              if (c.usuarioVinculadoId != null)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.teal.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.teal.withValues(alpha: 0.5))),
                                  child: const Text("APP", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.teal)),
                                )
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.phone_android, size: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(_formatPhone(c.phone), style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                                ],
                              ),
                              if (c.etiquetas.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(c.etiquetas.take(3).join(" • "), style: TextStyle(fontSize: 12, color: isDark ? Colors.purple[300] : Colors.purple[600]), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ]
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (c.totalDebt > 0 || c.saldoAFavor > 0)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (c.totalDebt > 0)
                                        Text("-${currency.format(c.totalDebt)}", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                                      if (c.saldoAFavor > 0)
                                        Text("+${currency.format(c.saldoAFavor)}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, c),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                child: const Text("Asignar", style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                          onTap: () => Navigator.pop(context, c),
                        );
                      },
                    )
          )
        ],
      ),
    );
  }
}