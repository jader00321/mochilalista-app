import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/features/smart_quotation/services/client_service.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

class ClientSearchModal extends StatefulWidget {
  final Function(ClientModel) onClientSelected;

  const ClientSearchModal({super.key, required this.onClientSelected});

  /// 🏆 Despliegue seguro con InteractiveSheetWrapper (Swipe down to dismiss + Blindaje BUG-07)
  static Future<void> show(
    BuildContext context, {
    required Function(ClientModel) onClientSelected,
  }) {
    return InteractiveSheetWrapper.show(
      context: context,
      builder: (_) => ClientSearchModal(onClientSelected: onClientSelected),
    );
  }

  @override
  State<ClientSearchModal> createState() => _ClientSearchModalState();
}

class _ClientSearchModalState extends State<ClientSearchModal> {
  Future<List<ClientModel>>? _searchFuture;
  final ClientService _clientService = ClientService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecentClients();
    });
  }

  void _loadRecentClients() {
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    if (authProv.activeBusinessId != null) {
      setState(() {
        _searchFuture = _clientService.getRecentClients(authProv.activeBusinessId!).then(
          (clients) => clients.where((c) => !c.fullName.startsWith("Caja Rápida -")).toList()
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InteractiveSheetWrapper(
      maxHeightFactor: 0.92,
      backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
      applyEffectiveBottomPadding: true,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              children: [
                Text("Buscar Cliente", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 16),
                    TextField(
                      autofocus: true,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: "Ej: Juan Perez...",
                        hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey),
                        prefixIcon: Icon(Icons.search, color: isDark ? Colors.blue[300] : Colors.blue),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        filled: true, fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100]
                      ),
                      onChanged: (val) {
                        if (val.trim().isNotEmpty) {
                          setState(() {
                            if (authProv.activeBusinessId != null) {
                              _searchFuture = _clientService.searchClients(val, authProv.activeBusinessId!).then(
                                (clients) => clients.where((c) => !c.fullName.startsWith("Caja Rápida -")).toList()
                              );
                            }
                          });
                        } else {
                          _loadRecentClients();
                        }
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _searchFuture == null
                  ? Center(child: Text("Escribe para buscar", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey, fontSize: 16)))
                  : FutureBuilder<List<ClientModel>>(
                      future: _searchFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                        if (!snapshot.hasData || snapshot.data!.isEmpty) return Center(child: Text("No se encontraron coincidencias", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey)));

                        return ListView.separated(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: snapshot.data!.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
                          itemBuilder: (context, index) {
                            final c = snapshot.data![index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              leading: CircleAvatar(backgroundColor: isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue[50], child: Text(c.fullName.isNotEmpty ? c.fullName[0].toUpperCase() : "?", style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue, fontWeight: FontWeight.bold, fontSize: 18))),
                              title: Text(c.fullName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                              subtitle: Text(c.phone, style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[700])),
                              trailing: ElevatedButton(
                                onPressed: () {
                                  widget.onClientSelected(c);
                                  Navigator.pop(context);
                                },
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                child: const Text("Asignar", style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            );
                          },
                        );
                      },
                    ),
              )
            ],
          ),
    );
  }
}