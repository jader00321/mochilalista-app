import 'package:flutter/material.dart';
import 'package:app_movil/features/smart_quotation/providers/workbench_provider.dart';
import 'package:app_movil/features/smart_quotation/widgets/quotation_card.dart';
import 'package:app_movil/features/smart_quotation/screens/quotation_detail_screen.dart';
import 'package:app_movil/features/smart_quotation/services/quotation_service.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

class ArchivedListsModal {
  static void show(BuildContext context, WorkbenchProvider provider, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (ctx) {
        return _ArchivedListsModalContent(
          provider: provider,
          isDark: isDark,
        );
      },
    );
  }
}

class _ArchivedListsModalContent extends StatefulWidget {
  final WorkbenchProvider provider;
  final bool isDark;

  const _ArchivedListsModalContent({
    required this.provider,
    required this.isDark,
  });

  @override
  State<_ArchivedListsModalContent> createState() => _ArchivedListsModalContentState();
}

class _ArchivedListsModalContentState extends State<_ArchivedListsModalContent> {
  bool _isLoading = false;

  Future<void> _handleRestore(BuildContext ctx, dynamic q) async {
    setState(() => _isLoading = true);
    try {
      final success = await widget.provider.changeQuotationStatus(q.id, 'DRAFT');
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lista restaurada exitosamente"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDelete(BuildContext ctx, dynamic q) async {
    setState(() => _isLoading = true);
    try {
      await QuotationService().hardDeleteQuotation(q.id);
      if (!mounted) return;
      await widget.provider.loadDashboard();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cotización eliminada"), backgroundColor: Colors.red));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.provider,
      builder: (context, _) {
        return InteractiveSheetWrapper(
          title: "Listas Archivadas",
          icon: Icons.archive,
          iconColor: widget.isDark ? Colors.grey[400] : Colors.grey[700],
          maxHeightFactor: 0.90,
          applyEffectiveBottomPadding: true,
          child: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: widget.isDark ? Colors.blue.withValues(alpha: 0.08) : Colors.blue[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: widget.isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: widget.isDark ? Colors.blue[300] : Colors.blue[700], size: 20),
                              const SizedBox(width: 8),
                              Text(
                                "¿Qué son las Listas Archivadas?", 
                                style: TextStyle(fontWeight: FontWeight.bold, color: widget.isDark ? Colors.blue[200] : Colors.blue[900], fontSize: 16)
                              ),
                            ]
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Aquí se guardan las listas que has archivado. Funciona como una papelera: estas listas desaparecen de tu Mesa de Trabajo activa y son excluidas de todas las estadísticas y cálculos.",
                            style: TextStyle(color: widget.isDark ? Colors.grey[300] : Colors.blueGrey[800], fontSize: 14, height: 1.4),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "💡 Puedes archivar una lista manteniendo presionada su tarjeta en la Mesa de Trabajo, o desde su pantalla de detalles.",
                            style: TextStyle(color: widget.isDark ? Colors.grey[400] : Colors.blueGrey[700], fontSize: 13, fontStyle: FontStyle.italic, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (widget.provider.archivedList.isEmpty)
                    SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Text("No tienes listas archivadas", style: TextStyle(color: widget.isDark ? Colors.grey[500] : Colors.grey, fontSize: 18)),
                        )
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.only(bottom: 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final q = widget.provider.archivedList[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: QuotationCard(
                                quotation: q,
                                isDark: widget.isDark,
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => QuotationDetailScreen(quotationId: q.id, clientName: q.clientName)))
                                    .then((_) => widget.provider.loadDashboard());
                                },
                                onLongPress: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    elevation: 0,
                                    builder: (bsCtx) => InteractiveSheetWrapper(
                                      title: q.clientName ?? "Opciones",
                                      icon: Icons.archive,
                                      iconColor: widget.isDark ? Colors.purple[300] : Colors.purple,
                                      maxHeightFactor: 0.6,
                                      applyEffectiveBottomPadding: true,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ListTile(
                                            leading: const CircleAvatar(
                                              backgroundColor: Colors.blueAccent,
                                              child: Icon(Icons.restore, color: Colors.white, size: 20),
                                            ),
                                            title: Text("Restaurar Lista", style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
                                            subtitle: Text("Devolverá la lista a la Mesa de Trabajo activa", style: TextStyle(color: widget.isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13)),
                                            onTap: () {
                                              Navigator.pop(bsCtx);
                                              _handleRestore(context, q);
                                            },
                                          ),
                                          const Divider(),
                                          ListTile(
                                            leading: const CircleAvatar(
                                              backgroundColor: Colors.redAccent,
                                              child: Icon(Icons.delete_forever, color: Colors.white, size: 20),
                                            ),
                                            title: Text("Eliminar Definitivamente", style: TextStyle(color: widget.isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
                                            subtitle: Text("Esta acción no se puede deshacer", style: TextStyle(color: widget.isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13)),
                                            onTap: () {
                                              Navigator.pop(bsCtx);
                                              showDialog(
                                                context: context,
                                                builder: (dialogCtx) => AlertDialog(
                                                  backgroundColor: widget.isDark ? const Color(0xFF23232F) : Colors.white,
                                                  title: const Text("¿Eliminar definitivamente?", style: TextStyle(fontWeight: FontWeight.bold)),
                                                  content: const Text("Esta acción borrará la cotización por completo de la base de datos y no se podrá recuperar."),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(dialogCtx),
                                                      child: const Text("Cancelar"),
                                                    ),
                                                    ElevatedButton(
                                                      onPressed: () {
                                                        Navigator.pop(dialogCtx);
                                                        _handleDelete(context, q);
                                                      },
                                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                                      child: const Text("Eliminar", style: TextStyle(color: Colors.white)),
                                                    )
                                                  ],
                                                )
                                              );
                                            },
                                          ),
                                          const SizedBox(height: 12),
                                        ],
                                      ),
                                    ),
                                  );
                                }, 
                              ),
                            );
                          },
                          childCount: widget.provider.archivedList.length,
                        ),
                      ),
                    ),
                ],
              ),
            if (_isLoading)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24))
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
