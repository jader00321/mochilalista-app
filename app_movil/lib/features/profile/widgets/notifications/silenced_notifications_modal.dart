import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/core/providers/notification_provider.dart';
import 'package:app_movil/core/models/notification_model.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

class SilencedNotificationsModal extends StatefulWidget {
  final bool isDark;

  const SilencedNotificationsModal({
    super.key,
    required this.isDark,
  });

  static Future<void> show(BuildContext context, {required bool isDark}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => SilencedNotificationsModal(isDark: isDark),
    );
  }

  @override
  State<SilencedNotificationsModal> createState() => _SilencedNotificationsModalState();
}

class _SilencedNotificationsModalState extends State<SilencedNotificationsModal> {
  String _searchQuery = '';
  String _selectedCategory = 'Todas';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _confirmPermanentDelete(BuildContext context, NotificationModel notif, NotificationProvider prov) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Eliminar Registro"),
        content: Text("¿Deseas eliminar permanentemente esta notificación silenciada ('${notif.title}')?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              prov.deleteNotification(notif.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Registro eliminado"),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[600], foregroundColor: Colors.white),
            child: const Text("Sí, Eliminar"),
          ),
        ],
      ),
    );
  }

  void _confirmUnsilenceAll(BuildContext context, NotificationProvider prov) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Restaurar Todas las Alertas"),
        content: const Text("¿Deseas reactivar y devolver todas las notificaciones silenciadas a tu lista principal activa?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              prov.unsilenceAll();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Todas las alertas han sido reactivadas y restauradas"),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], foregroundColor: Colors.white),
            child: const Text("Sí, Restaurar Todas"),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAll(BuildContext context, NotificationProvider prov) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Vaciar No Deseadas"),
        content: const Text("¿Estás seguro de eliminar permanentemente TODAS las notificaciones silenciadas? Las alertas para estos ítems seguirán bloqueadas."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              prov.deleteAllSilenced();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Bandeja de No Deseadas vaciada"),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[600], foregroundColor: Colors.white),
            child: const Text("Sí, Vaciar"),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String title, int count, bool isDark) {
    final bool isSelected = _selectedCategory == title;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = title),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected 
              ? (isDark ? Colors.red[900]!.withValues(alpha: 0.35) : Colors.red[100])
              : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey[200]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.red[700]! : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected 
                    ? (isDark ? Colors.red[300] : Colors.red[900])
                    : (isDark ? Colors.grey[400] : Colors.grey[700]),
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected 
                    ? (isDark ? Colors.red[700] : Colors.red[800])
                    : (isDark ? Colors.white12 : Colors.grey[300]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "$count",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[800]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final prov = Provider.of<NotificationProvider>(context);
    final silencedList = prov.silencedNotifications;
    final effectiveBottom = InteractiveSheetWrapper.getEffectiveBottomPadding(context, minPadding: kMinDefensiveBottomClearance);

    final bgCardColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final sectionBg = isDark ? const Color(0xFF1E1E28) : Colors.grey[50];
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];

    // Conteo por categorías en silenciadas
    final int countTodas = silencedList.length;
    final int countCobranzas = silencedList.where((n) => n.objetoRelacionadoTipo == 'cuota').length;
    final int countInventario = silencedList.where((n) => n.objetoRelacionadoTipo == 'producto').length;
    final int countCotizaciones = silencedList.where((n) => n.objetoRelacionadoTipo == 'cotizacion' || n.objetoRelacionadoTipo == 'venta').length;

    // Filtrar lista
    final filteredList = silencedList.where((n) {
      if (_selectedCategory == 'Cobranzas' && n.objetoRelacionadoTipo != 'cuota') return false;
      if (_selectedCategory == 'Inventario' && n.objetoRelacionadoTipo != 'producto') return false;
      if (_selectedCategory == 'Cotizaciones' && n.objetoRelacionadoTipo != 'cotizacion' && n.objetoRelacionadoTipo != 'venta') return false;

      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final inTitle = n.title.toLowerCase().contains(q);
        final inMsg = n.message.toLowerCase().contains(q);
        final inKey = n.effectiveMuteKey.toLowerCase().contains(q);
        if (!inTitle && !inMsg && !inKey) return false;
      }
      return true;
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: sectionBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: isDark ? 0.25 : 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.notifications_off_outlined, color: isDark ? Colors.red[300] : Colors.red[700], size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Ítems en No Deseadas",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                              letterSpacing: -0.3,
                            ),
                          ),
                          Text(
                            "$countTodas ítem${countTodas != 1 ? 's' : ''} con alertas bloqueadas",
                            style: TextStyle(fontSize: 12, color: subtitleColor),
                          ),
                        ],
                      ),
                    ),
                    if (silencedList.isNotEmpty)
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert_rounded, color: subtitleColor),
                        tooltip: "Opciones de No Deseadas",
                        onSelected: (val) {
                          if (val == 'unsilence_all') {
                            _confirmUnsilenceAll(context, prov);
                          } else if (val == 'delete_all') {
                            _confirmDeleteAll(context, prov);
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'unsilence_all',
                            child: Row(
                              children: [
                                Icon(Icons.notifications_active_rounded, size: 18, color: Colors.green),
                                SizedBox(width: 10),
                                Text("Restaurar todas las alertas", style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete_all',
                            child: Row(
                              children: [
                                Icon(Icons.delete_sweep_rounded, size: 18, color: Colors.red),
                                SizedBox(width: 10),
                                Text("Vaciar No Deseadas", style: TextStyle(fontSize: 13, color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                      tooltip: "Cerrar",
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Buscador de Silenciadas
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF282836) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: TextStyle(fontSize: 13, color: textColor),
                decoration: InputDecoration(
                  hintText: "Buscar por palabra clave, folio o mute key...",
                  hintStyle: TextStyle(fontSize: 12, color: subtitleColor),
                  prefixIcon: Icon(Icons.search_rounded, size: 18, color: subtitleColor),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),

          // Chips de categorías
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildCategoryChip('Todas', countTodas, isDark),
                  const SizedBox(width: 8),
                  _buildCategoryChip('Cobranzas', countCobranzas, isDark),
                  const SizedBox(width: 8),
                  _buildCategoryChip('Inventario', countInventario, isDark),
                  const SizedBox(width: 8),
                  _buildCategoryChip('Cotizaciones', countCotizaciones, isDark),
                ],
              ),
            ),
          ),

          const Divider(height: 1),

          // Lista de Silenciadas
          Expanded(
            child: silencedList.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_off_outlined, size: 64, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            "Sin Alertas Bloqueadas",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Cuando muevas una alerta a 'No Deseadas', el sistema dejará de generar avisos para ese producto, cuota o cliente.",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: subtitleColor),
                          ),
                        ],
                      ),
                    ),
                  )
                : filteredList.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off_rounded, size: 48, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text(
                                "No se encontraron alertas bloqueadas",
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Intenta cambiar el término de búsqueda o la categoría.",
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: subtitleColor),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(16, 12, 16, effectiveBottom + 20),
                        physics: const BouncingScrollPhysics(),
                        itemCount: filteredList.length,
                        itemBuilder: (context, index) {
                          final notif = filteredList[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: bgCardColor,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        notif.title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: textColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      DateFormat('dd/MM HH:mm').format(notif.createdAt),
                                      style: TextStyle(fontSize: 11.5, color: subtitleColor),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  notif.message,
                                  style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[300] : Colors.grey[700]),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: isDark ? 0.2 : 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.block_rounded, size: 13, color: isDark ? Colors.red[300] : Colors.red[700]),
                                      const SizedBox(width: 4),
                                      Text(
                                        "Alertas relacionadas bloqueadas (${notif.effectiveMuteKey})",
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.red[300] : Colors.red[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () => _confirmPermanentDelete(context, notif, prov),
                                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                                      label: const Text("Eliminar", style: TextStyle(fontSize: 12)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red[600],
                                        side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        prov.unsilenceNotification(notif.id);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text("Ítem restaurado a lista principal y alertas reactivadas"),
                                            duration: Duration(seconds: 2),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.notifications_active_rounded, size: 16),
                                      label: const Text("Restaurar y Reactivar", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green[700],
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
