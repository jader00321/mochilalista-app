import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/catalog_provider.dart';
import 'category_chip.dart';

class CatalogHeader extends StatefulWidget {
  final VoidCallback onFilterTap;

  const CatalogHeader({super.key, required this.onFilterTap});

  @override
  State<CatalogHeader> createState() => _CatalogHeaderState();
}

class _CatalogHeaderState extends State<CatalogHeader> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CatalogProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    if (provider.searchQuery.isEmpty && _controller.text.isNotEmpty) {
      _controller.clear();
    }

    return Container(
      width: double.infinity,
      color: isDark ? const Color(0xFF14141C) : Colors.white, 
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. FILA SUPERIOR: BUSCADOR Y BOTONES
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 55,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF23232F) : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(14), 
                    ),
                    child: TextField(
                      controller: _controller,
                      onChanged: (val) => provider.setSearchQuery(val),
                      style: TextStyle(fontSize: 16, color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        hintText: "Buscar producto, marca...",
                        hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 15),
                        prefixIcon: Icon(Icons.search, color: isDark ? Colors.blue[300] : Colors.grey, size: 24),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                        suffixIcon: _controller.text.isNotEmpty 
                          ? IconButton(
                              icon: Icon(Icons.close, size: 22, color: isDark ? Colors.white70 : Colors.grey),
                              onPressed: () {
                                _controller.clear();
                                provider.setSearchQuery("");
                              },
                            )
                          : null
                      ),
                    ),
                  ),
                ),
                
                if (provider.hasActiveFilters) ...[
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: () {
                      _controller.clear();
                      provider.clearAllFilters();
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      height: 55, width: 55,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.red.withOpacity(0.15) : Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? Colors.red.withOpacity(0.4) : Colors.red.withOpacity(0.3))
                      ),
                      child: Icon(Icons.delete_outline, color: isDark ? Colors.red[300] : Colors.red, size: 26),
                    ),
                  ),
                ],

                const SizedBox(width: 10),
                
                InkWell(
                  onTap: widget.onFilterTap,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    height: 55, width: 55,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.blue[800] : theme.primaryColor,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [if (!isDark) BoxShadow(color: theme.primaryColor.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3))]
                    ),
                    child: const Icon(Icons.tune, color: Colors.white, size: 26),
                  ),
                ),
              ],
            ),
          ),

          // 2. LISTA DE CATEGORÍAS 
          SizedBox(
            height: 45,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                CategoryChip(
                  label: "Todas", 
                  isSelected: provider.selectedCategoryId == null, 
                  onTap: () => provider.selectCategory(null)
                ),
                ...provider.categories.map((c) => CategoryChip(
                  label: c.nombre, 
                  isSelected: provider.selectedCategoryId == c.id, 
                  onTap: () => provider.selectCategory(c.id)
                ))
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}