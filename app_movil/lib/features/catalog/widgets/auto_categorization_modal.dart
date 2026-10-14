import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/services/auto_categorization_service.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';

class AutoCategorizationModal extends StatefulWidget {
  final bool isDark;

  const AutoCategorizationModal({super.key, required this.isDark});

  static Future<void> show(BuildContext context, {required bool isDark}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AutoCategorizationModal(isDark: isDark),
    );
  }

  @override
  State<AutoCategorizationModal> createState() => _AutoCategorizationModalState();
}

class _AutoCategorizationModalState extends State<AutoCategorizationModal> {
  bool _isLoading = true;
  bool _isSaving = false;
  List<ProductCategorySuggestion> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  Future<void> _loadSuggestions() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final invProv = Provider.of<InventoryProvider>(context, listen: false);
    final businessId = auth.activeBusinessId;

    if (businessId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final results = await AutoCategorizationService.getSuggestionsForBusiness(
      businessId,
      invProv.categories,
    );

    if (mounted) {
      setState(() {
        _suggestions = results;
        _isLoading = false;
      });
    }
  }

  Future<void> _apply() async {
    final selected = _suggestions.where((s) => s.selected).toList();
    if (selected.isEmpty) return;

    setState(() => _isSaving = true);
    final invProv = Provider.of<InventoryProvider>(context, listen: false);

    final count = await AutoCategorizationService.applySuggestions(
      selected,
      invProv,
    );

    if (mounted) {
      Navigator.pop(context);
      CustomSnackBar.show(
        context,
        message: "¡Listo! Se categorizaron $count productos exitosamente.",
        isError: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark ? Colors.white : Colors.black87;
    final cardBg = widget.isDark ? const Color(0xFF1E2235) : Colors.white;
    final selectedCount = _suggestions.where((s) => s.selected).length;

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: widget.isDark ? Colors.white24 : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.blue, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Auto-Categorización",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Text(
                        "Sugerencias basadas en el nombre del producto",
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _suggestions.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                size: 64,
                                color: widget.isDark ? Colors.green[400] : Colors.green[700],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "¡Todo al día!",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "No hay productos sin categorizar o pendientes de sugerencia.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          // Select all bar
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            child: Row(
                              children: [
                                Text(
                                  "${_suggestions.length} productos identificados",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: widget.isDark ? Colors.grey[300] : Colors.grey[700],
                                  ),
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: () {
                                    final allSelected = _suggestions.every((s) => s.selected);
                                    setState(() {
                                      for (var s in _suggestions) {
                                        s.selected = !allSelected;
                                      }
                                    });
                                  },
                                  child: Text(
                                    _suggestions.every((s) => s.selected)
                                        ? "Deseleccionar todos"
                                        : "Seleccionar todos",
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // List
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              itemCount: _suggestions.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (ctx, i) {
                                final s = _suggestions[i];
                                return InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => setState(() => s.selected = !s.selected),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: widget.isDark
                                          ? (s.selected ? Colors.blue.withValues(alpha: 0.12) : const Color(0xFF14141C))
                                          : (s.selected ? Colors.blue[50] : Colors.grey[50]),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: s.selected
                                            ? (widget.isDark ? Colors.blue.withValues(alpha: 0.4) : Colors.blue.shade300)
                                            : (widget.isDark ? Colors.white10 : Colors.grey.shade200),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Checkbox(
                                          value: s.selected,
                                          activeColor: Colors.blue,
                                          onChanged: (v) => setState(() => s.selected = v ?? false),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                s.productName,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                  color: textColor,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      s.currentCategoryName,
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                                                        decoration: TextDecoration.lineThrough,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Icon(
                                                    Icons.arrow_forward,
                                                    size: 12,
                                                    color: widget.isDark ? Colors.blue[300] : Colors.blue[800],
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Flexible(
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: Colors.green.withValues(alpha: 0.15),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        s.suggestedCategoryName,
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold,
                                                          color: widget.isDark ? Colors.green[300] : Colors.green[800],
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
          ),

          // Bottom action button
          if (_suggestions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: (_isSaving || selectedCount == 0) ? null : _apply,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check, size: 20),
                  label: Text(
                    _isSaving
                        ? "Aplicando..."
                        : "Aplicar a $selectedCount producto(s)",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.isDark ? Colors.blue[400] : Colors.blue[800],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
