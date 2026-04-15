import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../providers/auth_provider.dart';
import '../../services/client_service.dart';
import '../../models/crm_models.dart';

class ClientSearchModal extends StatefulWidget {
  final Function(ClientModel) onClientSelected;

  const ClientSearchModal({super.key, required this.onClientSelected});

  @override
  State<ClientSearchModal> createState() => _ClientSearchModalState();
}

class _ClientSearchModalState extends State<ClientSearchModal> {
  Future<List<ClientModel>>? _searchFuture;
  final ClientService _clientService = ClientService();

  @override
  Widget build(BuildContext context) {
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF23232F) : Colors.white, 
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24))
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(width: 50, height: 5, decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey[300], borderRadius: BorderRadius.circular(10))),
                    const SizedBox(height: 20),
                    Text("Buscar Cliente", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 20),
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
                        if (val.isNotEmpty) {
                          setState(() {
                            _searchFuture = _clientService.searchClients(val, authProv.token!).then(
                              (clients) => clients.where((c) => !c.fullName.startsWith("Caja Rápida -")).toList()
                            );
                          });
                        } else {
                          setState(() { _searchFuture = null; });
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
                          controller: scrollController,
                          itemCount: snapshot.data!.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
                          itemBuilder: (context, index) {
                            final c = snapshot.data![index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              leading: CircleAvatar(backgroundColor: isDark ? Colors.blue.withOpacity(0.2) : Colors.blue[50], child: Text(c.fullName.isNotEmpty ? c.fullName[0].toUpperCase() : "?", style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue, fontWeight: FontWeight.bold, fontSize: 18))),
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
      },
    );
  }
}