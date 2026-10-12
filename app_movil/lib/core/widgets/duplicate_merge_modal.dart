import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/core/widgets/duplicate_warning_dialog.dart';

/// =========================================================================
/// 🔧 TAREA 2.4: Modal de Detección y Fusión de Duplicados
/// Detecta automáticamente posibles duplicados en marcas, categorías y
/// proveedores, y permite al usuario fusionarlos con un solo toque.
/// =========================================================================

enum MergeEntityType { brand, category, provider }

class DuplicateMergeModal {
  /// Abre el modal de detección de duplicados para el tipo de entidad dado
  static Future<void> show(
    BuildContext context, {
    required MergeEntityType type,
    required bool isDark,
  }) async {
    final provider = Provider.of<InventoryProvider>(context, listen: false);
    final List<List<Map<String, dynamic>>> duplicateGroups = [];

    switch (type) {
      case MergeEntityType.brand:
        final items = provider.brands;
        _findDuplicateGroups(
          items.map((b) => {'id': b.id, 'name': b.nombre, 'extra': '${b.productsCount} productos'}).toList(),
          duplicateGroups,
        );
        break;
      case MergeEntityType.category:
        final items = provider.categories;
        _findDuplicateGroups(
          items.map((c) => {'id': c.id, 'name': c.nombre, 'extra': '${c.productsCount} productos'}).toList(),
          duplicateGroups,
        );
        break;
      case MergeEntityType.provider:
        final items = provider.providers;
        _findDuplicateGroups(
          items.map((p) => {
            'id': p.id,
            'name': p.nombreEmpresa,
            'extra': p.ruc != null && p.ruc!.isNotEmpty ? 'RUC: ${p.ruc}' : 'Sin RUC',
            'ruc': p.ruc ?? '',
          }).toList(),
          duplicateGroups,
          checkRuc: true,
        );
        break;
    }

    if (!context.mounted) return;

    if (duplicateGroups.isEmpty) {
      CustomSnackBar.show(
        context,
        message: "✅ No se encontraron duplicados",
        isError: false,
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DuplicateMergeSheet(
        type: type,
        duplicateGroups: duplicateGroups,
        isDark: isDark,
      ),
    );
  }

  /// Detecta grupos de duplicados basándose en nombre similar
  static void _findDuplicateGroups(
    List<Map<String, dynamic>> items,
    List<List<Map<String, dynamic>>> groups, {
    bool checkRuc = false,
  }) {
    final matched = <int>{};

    for (int i = 0; i < items.length; i++) {
      if (matched.contains(items[i]['id'])) continue;

      final group = <Map<String, dynamic>>[items[i]];

      for (int j = i + 1; j < items.length; j++) {
        if (matched.contains(items[j]['id'])) continue;

        bool isDup = DuplicateDetector.areSimilar(
          items[i]['name'] as String,
          items[j]['name'] as String,
        );

        // Para proveedores, también verificar RUC idéntico
        if (!isDup && checkRuc) {
          final rucA = items[i]['ruc'] as String? ?? '';
          final rucB = items[j]['ruc'] as String? ?? '';
          if (rucA.isNotEmpty && rucB.isNotEmpty && rucA == rucB) {
            isDup = true;
          }
        }

        if (isDup) {
          group.add(items[j]);
          matched.add(items[j]['id'] as int);
        }
      }

      if (group.length > 1) {
        matched.add(items[i]['id'] as int);
        groups.add(group);
      }
    }
  }
}

class _DuplicateMergeSheet extends StatefulWidget {
  final MergeEntityType type;
  final List<List<Map<String, dynamic>>> duplicateGroups;
  final bool isDark;

  const _DuplicateMergeSheet({
    required this.type,
    required this.duplicateGroups,
    required this.isDark,
  });

  @override
  State<_DuplicateMergeSheet> createState() => _DuplicateMergeSheetState();
}

class _DuplicateMergeSheetState extends State<_DuplicateMergeSheet> {
  bool _isMerging = false;

  String get _entityLabel {
    switch (widget.type) {
      case MergeEntityType.brand:
        return 'Marcas';
      case MergeEntityType.category:
        return 'Categorías';
      case MergeEntityType.provider:
        return 'Proveedores';
    }
  }

  Color get _accentColor {
    switch (widget.type) {
      case MergeEntityType.brand:
        return Colors.orange;
      case MergeEntityType.category:
        return Colors.blue;
      case MergeEntityType.provider:
        return Colors.purple;
    }
  }

  Future<void> _performMerge(
    Map<String, dynamic> keepItem,
    Map<String, dynamic> removeItem,
  ) async {
    setState(() => _isMerging = true);

    final provider = Provider.of<InventoryProvider>(context, listen: false);
    final keepId = keepItem['id'] as int;
    final removeId = removeItem['id'] as int;

    bool success = false;
    switch (widget.type) {
      case MergeEntityType.brand:
        success = await provider.mergeBrands(keepId, removeId);
        break;
      case MergeEntityType.category:
        success = await provider.mergeCategories(keepId, removeId);
        break;
      case MergeEntityType.provider:
        success = await provider.mergeProviders(keepId, removeId);
        break;
    }

    if (mounted) {
      setState(() => _isMerging = false);

      if (success) {
        // Remover el grupo fusionado de la lista
        for (final group in widget.duplicateGroups) {
          group.removeWhere((item) => item['id'] == removeId);
        }
        widget.duplicateGroups.removeWhere((g) => g.length <= 1);
        setState(() {});

        CustomSnackBar.show(
          context,
          message: "✅ Fusionado: \"${removeItem['name']}\" → \"${keepItem['name']}\"",
        );

        if (widget.duplicateGroups.isEmpty) {
          if (mounted) Navigator.pop(context);
        }
      } else {
        CustomSnackBar.show(
          context,
          message: "Error al fusionar",
          isError: true,
        );
      }
    }
  }

  void _showMergeConfirmation(
    List<Map<String, dynamic>> group,
    Map<String, dynamic> keepItem,
    Map<String, dynamic> removeItem,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.merge_type, color: _accentColor, size: 24),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                "Confirmar Fusión",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 14,
                  color: widget.isDark ? Colors.grey[300] : Colors.grey[700],
                  height: 1.5,
                ),
                children: [
                  const TextSpan(text: "Se reasignarán todos los registros de:\n\n"),
                  TextSpan(
                    text: "❌ \"${removeItem['name']}\"\n",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red[400],
                    ),
                  ),
                  const TextSpan(text: "\nhacia:\n\n"),
                  TextSpan(
                    text: "✅ \"${keepItem['name']}\"",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green[400],
                    ),
                  ),
                  const TextSpan(text: "\n\ny luego se eliminará el duplicado."),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Cancelar",
              style: TextStyle(
                color: widget.isDark ? Colors.grey[400] : Colors.grey,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _performMerge(keepItem, removeItem);
            },
            child: const Text(
              "Fusionar",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF14141C) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          const SizedBox(height: 12),
          Container(
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: widget.isDark ? Colors.white24 : Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.find_replace, color: _accentColor, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Duplicados en $_entityLabel",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: widget.isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "${widget.duplicateGroups.length} grupos",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _accentColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              "Selecciona cuál conservar. El otro será eliminado y sus productos reasignados.",
              style: TextStyle(
                fontSize: 13,
                color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (_isMerging)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text("Fusionando registros..."),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                itemCount: widget.duplicateGroups.length,
                separatorBuilder: (_, __) => Divider(
                  height: 24,
                  color: widget.isDark ? Colors.white10 : Colors.grey[200],
                ),
                itemBuilder: (ctx, groupIdx) {
                  final group = widget.duplicateGroups[groupIdx];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Grupo ${groupIdx + 1}",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: widget.isDark ? Colors.grey[500] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...group.map((item) {
                        final others = group.where((g) => g['id'] != item['id']).toList();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: widget.isDark
                                ? const Color(0xFF23232F)
                                : Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: widget.isDark ? Colors.white10 : Colors.grey.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['name'] as String,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: widget.isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      "ID: ${item['id']} • ${item['extra']}",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: widget.isDark ? Colors.grey[500] : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Botón conservar: fusiona los demás hacia este
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green[700],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(Icons.check, size: 16),
                                label: const Text(
                                  "Conservar",
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                onPressed: () {
                                  if (others.length == 1) {
                                    _showMergeConfirmation(group, item, others.first);
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
