part of '../smart_action_grid.dart';

mixin _SmartActionGridModalsAndTraysMixin on _SmartActionGridStateBase {
  @override
  Widget _buildHiddenCardsTray(
    BuildContext context,
    Map<String, _ActionCardDef> cardDefs,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF171922) : const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.visibility_off_outlined,
                size: 16,
                color: Colors.grey,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "Tarjetas Ocultas (${_hiddenCardIds.length})",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                "Toca para restaurar",
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _hiddenCardIds.map((hiddenId) {
              final def = cardDefs[hiddenId];
              if (def == null) {
                return const SizedBox.shrink();
              }
              return ActionChip(
                backgroundColor: isDark
                    ? const Color(0xFF232532)
                    : Colors.white,
                avatar: const Icon(
                  Icons.add_circle_outline_rounded,
                  color: Colors.green,
                  size: 16,
                ),
                label: Text(
                  def.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                onPressed: () => _toggleHideCard(hiddenId),
                side: BorderSide(color: Colors.green.withValues(alpha: 0.3)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E202B) : const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade300,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.widgets_outlined,
            size: 40,
            color: Colors.blueAccent.withValues(alpha: 0.8),
          ),
          const SizedBox(height: 8),
          const Text(
            "Todas las tarjetas están ocultas",
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            "Puedes restaurar todos los accesos originales o personalizar cuáles mostrar.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                ),
                onPressed: _resetToFactory,
                icon: const Icon(Icons.restore_rounded, size: 16),
                label: const Text(
                  "Restablecer Tarjetas",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white70 : Colors.black87,
                  side: BorderSide(
                    color: isDark ? Colors.white24 : Colors.grey.shade400,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() => _isEditing = true);
                },
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: const Text(
                  "Personalizar",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void _showResumeDialog(
    BuildContext context, {
    required String title,
    required String msg,
    required bool isDark,
    required VoidCallback onNew,
    required VoidCallback onResume,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        title: Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        content: Text(
          msg,
          style: TextStyle(
            color: isDark ? Colors.grey[300] : Colors.grey[700],
            fontSize: 15,
            height: 1.4,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onNew();
            },
            child: const Text(
              "Iniciar Nueva",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.blue[600] : Colors.blue[800],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              onResume();
            },
            child: const Text(
              "Retomar",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void _showQuickSalePowerShortcut(
    BuildContext context,
    QuickSaleProvider prov,
    bool isDark,
  ) {
    HapticFeedback.heavyImpact();
    InteractiveSheetWrapper.show(
      context: context,
      builder: (ctx) => InteractiveSheetWrapper(
        title: "Atajos de Venta Rápida",
        maxHeightFactor: 0.6,
        applyEffectiveBottomPadding: true,
        child: Column(
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.pink.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.flash_on_rounded,
                  color: Colors.pinkAccent,
                ),
              ),
              title: const Text(
                "Nueva Venta Limpia",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                "Vacía la caja y abre una nueva venta en blanco",
              ),
              onTap: () {
                Navigator.pop(ctx);
                prov.clearCart();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QuickSaleScreen()),
                );
              },
            ),
            const Divider(),
            if (prov.cartItems.isNotEmpty) ...[
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_sweep_rounded,
                    color: Colors.redAccent,
                  ),
                ),
                title: Text(
                  "Vaciar Caja (${prov.cartItems.length} ítems)",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
                subtitle: const Text(
                  "Descarta todos los productos actualmente en cola",
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  prov.clearCart();
                  CustomSnackBar.show(
                    context,
                    message: "Caja vaciada correctamente",
                  );
                },
              ),
              const Divider(),
            ],
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.point_of_sale_rounded,
                  color: Colors.blue,
                ),
              ),
              title: const Text(
                "Continuar Venta Pendiente",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                prov.cartItems.isNotEmpty
                    ? "${prov.cartItems.length} productos esperando cobro"
                    : "Caja actualmente vacía",
              ),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QuickSaleScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
