import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart'; 

import '../../providers/tracking_provider.dart';
import '../../../../providers/auth_provider.dart'; // 🔥 FASE 4
import '../../models/crm_models.dart';
import '../../widgets/crm/client_filter_bar.dart';
import '../../widgets/crm/client_card.dart';
import '../../widgets/crm/client_profile_editor.dart';

class ClientTrackingScreen extends StatefulWidget {
  const ClientTrackingScreen({super.key});

  @override
  State<ClientTrackingScreen> createState() => _ClientTrackingScreenState();
}

class _ClientTrackingScreenState extends State<ClientTrackingScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TrackingProvider>(context, listen: false).loadClients();
    });

    _scrollController.addListener(() {
      if (_scrollController.offset > 200 && !_showScrollToTop) {
        setState(() => _showScrollToTop = true);
      } else if (_scrollController.offset <= 200 && _showScrollToTop) {
        setState(() => _showScrollToTop = false);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0, 
      duration: const Duration(milliseconds: 500), 
      curve: Curves.easeInOutCubic
    );
  }

  // 🔥 NUEVO: Explicación de Exploración
  void _showExplorationModal(BuildContext context, bool isDark) {
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
          "Para crear clientes o enviar mensajes de cobro masivos, necesitas registrar tu propio negocio.\n\n"
          "Dirígete a tu Perfil cuando estés listo para empezar a gestionar tus clientes reales.",
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

  void _openCreateClientEditor() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!auth.hasActiveContext) {
      _showExplorationModal(context, isDark);
      return;
    }

    final emptyClient = ClientModel(
      id: 0,
      negocioId: 0,
      creadoPorUsuarioId: 0,
      fullName: "",
      phone: "",
      registeredDate: DateTime.now().toIso8601String(),
    );

    final updatedClient = await showModalBottomSheet<ClientModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ClientProfileEditor(client: emptyClient, isNew: true),
    );

    if (updatedClient != null && mounted) {
      Provider.of<TrackingProvider>(context, listen: false).loadClients();
    }
  }

  void _showMassReminderBottomSheet(BuildContext context, List<ClientModel> debtors) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (!auth.hasActiveContext) {
      _showExplorationModal(context, isDark);
      return;
    }

    final bgColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        List<int> sentClientIds = [];

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85, 
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28))
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.campaign, color: isDark ? Colors.blue[300] : Colors.blue, size: 30),
                          const SizedBox(width: 12),
                          Text("Recordatorio Masivo", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
                        ],
                      ),
                      IconButton(icon: Icon(Icons.close, color: textColor, size: 28), onPressed: () => Navigator.pop(ctx))
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text("Abre WhatsApp uno por uno para enviar el mensaje de forma segura. (${sentClientIds.length}/${debtors.length} enviados)", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 16)),
                  const SizedBox(height: 20),
                  
                  Expanded(
                    child: ListView.separated(
                      itemCount: debtors.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
                      itemBuilder: (context, index) {
                        final client = debtors[index];
                        final bool isSent = sentClientIds.contains(client.id);
                        final bool invalidPhone = client.phone.isEmpty || client.phone.length < 8;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          leading: CircleAvatar(
                            radius: 26,
                            backgroundColor: isSent ? Colors.green.withOpacity(0.2) : (isDark ? Colors.white10 : Colors.grey[200]),
                            child: Icon(isSent ? Icons.check : Icons.person, color: isSent ? Colors.green : (isDark ? Colors.white54 : Colors.grey)),
                          ),
                          title: Text(client.fullName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor, decoration: isSent ? TextDecoration.lineThrough : null)),
                          subtitle: Text(invalidPhone ? "Sin número válido" : client.phone, style: TextStyle(fontSize: 15, color: invalidPhone ? Colors.red : (isDark ? Colors.grey[400] : Colors.grey[600]))),
                          trailing: invalidPhone 
                            ? null 
                            : ElevatedButton.icon(
                                onPressed: isSent ? null : () async {
                                  String msg = "Hola ${client.fullName}, te saludamos de la librería. Te escribimos para recordarte que tienes un saldo pendiente. Agradecemos tu pronta cancelación.";
                                  final url = Uri.parse("https://wa.me/51${client.phone}?text=${Uri.encodeComponent(msg)}");
                                  
                                  if (await canLaunchUrl(url)) {
                                    await launchUrl(url, mode: LaunchMode.externalApplication);
                                    setModalState(() => sentClientIds.add(client.id));
                                  }
                                },
                                icon: Icon(isSent ? Icons.done_all : Icons.send, size: 20),
                                label: Text(isSent ? "Enviado" : "Enviar", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isSent ? (isDark ? Colors.grey[800] : Colors.grey[300]) : const Color(0xFF25D366),
                                  foregroundColor: isSent ? (isDark ? Colors.grey[500] : Colors.grey[700]) : Colors.white,
                                  elevation: isSent ? 0 : 2,
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))
                                ),
                              ),
                        );
                      },
                    ),
                  )
                ],
              ),
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TrackingProvider>(context);
    final clients = provider.filteredClients;
    final debtorsList = clients.where((c) => c.totalDebt > 0).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Directorio de Clientes", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add, size: 28), 
            tooltip: "Nuevo Cliente", 
            onPressed: _openCreateClientEditor
          ),
          const SizedBox(width: 8)
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              height: 55,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF23232F) : Colors.white, 
                borderRadius: BorderRadius.circular(16),
                boxShadow: [if(!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
              ),
              child: TextField(
                controller: _searchCtrl,
                style: TextStyle(color: textColor, fontSize: 18),
                onChanged: (val) => provider.setSearchQuery(val),
                decoration: InputDecoration(
                  hintText: "Buscar por nombre, teléfono o DNI...",
                  hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400], fontSize: 16),
                  prefixIcon: Icon(Icons.search, color: isDark ? Colors.grey[400] : Colors.grey, size: 26),
                  suffixIcon: _searchCtrl.text.isNotEmpty 
                      ? IconButton(icon: Icon(Icons.clear, size: 24, color: textColor), onPressed: () { _searchCtrl.clear(); provider.setSearchQuery(""); }) 
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
        ),
      ),
      
      body: Column(
        children: [
          // 🔥 AVISO DE EXPLORACIÓN PERMANENTE PARA INVITADOS
          if (!Provider.of<AuthProvider>(context).hasActiveContext)
             Container(
               width: double.infinity,
               color: Colors.orange.withOpacity(0.15),
               padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
               child: Row(
                 children: [
                   Icon(Icons.info_outline, color: Colors.orange[700]),
                   const SizedBox(width: 12),
                   Expanded(
                     child: Text(
                       "Modo Exploración. Para agregar clientes a tu Directorio, debes registrar tu negocio.",
                       style: TextStyle(color: isDark ? Colors.orange[200] : Colors.orange[900], fontSize: 13),
                     )
                   )
                 ]
               )
             ),

          const ClientFilterBar(),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: surfaceColor,
              border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200))
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${clients.length} clientes encontrados", 
                  style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontWeight: FontWeight.bold, fontSize: 15)
                ),
                PopupMenuButton<String>(
                  color: surfaceColor,
                  child: Row(
                    children: [
                      Icon(Icons.sort, size: 22, color: isDark ? Colors.blue[300] : Colors.blue), 
                      const SizedBox(width: 8), 
                      Text("Ordenar", style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue, fontWeight: FontWeight.bold, fontSize: 16))
                    ]
                  ),
                  onSelected: (val) => provider.setSort(val),
                  itemBuilder: (ctx) => [
                    PopupMenuItem(value: 'name_asc', child: Text("Alfabético (A-Z)", style: TextStyle(color: textColor, fontSize: 16, fontWeight: provider.currentSort == 'name_asc' ? FontWeight.bold : FontWeight.normal))),
                    PopupMenuItem(value: 'newest', child: Text("Más recientes", style: TextStyle(color: textColor, fontSize: 16, fontWeight: provider.currentSort == 'newest' ? FontWeight.bold : FontWeight.normal))),
                    PopupMenuItem(value: 'oldest', child: Text("Más antiguos", style: TextStyle(color: textColor, fontSize: 16, fontWeight: provider.currentSort == 'oldest' ? FontWeight.bold : FontWeight.normal))),
                  ],
                )
              ],
            ),
          ),

          Expanded(
            child: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : clients.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center, 
                      children: [
                        Icon(Icons.people_outline, size: 90, color: isDark ? Colors.white10 : Colors.grey[300]), 
                        const SizedBox(height: 20), 
                        Text("No se encontraron clientes", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 18, fontWeight: FontWeight.bold))
                      ]
                    )
                  )
                : RefreshIndicator(
                    onRefresh: () => provider.loadClients(),
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.only(top: 16, bottom: provider.filterHasDebt ? 120 : 100),
                      itemCount: clients.length,
                      itemBuilder: (ctx, i) => ClientCard(
                        client: clients[i], 
                        onRefresh: () => provider.loadClients()
                      ),
                    ),
                  ),
          ),
        ],
      ),
      
      floatingActionButton: _showScrollToTop 
        ? FloatingActionButton(
            mini: true,
            onPressed: _scrollToTop,
            backgroundColor: isDark ? Colors.blueGrey[800] : Colors.white,
            foregroundColor: isDark ? Colors.white : Colors.black87,
            elevation: 4,
            child: const Icon(Icons.keyboard_arrow_up, size: 28),
          )
        : null,

      bottomSheet: (provider.filterHasDebt && debtorsList.isNotEmpty)
        ? Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: surfaceColor, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, -5))]),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("${debtorsList.length} deudores filtrados", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor)),
                        const SizedBox(height: 4),
                        Text("Envío individual seguro", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14)),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showMassReminderBottomSheet(context, debtorsList),
                    icon: const Icon(Icons.campaign, size: 24),
                    label: const Text("Cobrar a Todos", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800], 
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))
                    ),
                  )
                ],
              ),
            ),
          )
        : null,
    );
  }
}