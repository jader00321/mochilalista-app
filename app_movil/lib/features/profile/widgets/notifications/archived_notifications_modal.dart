import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/core/providers/notification_provider.dart';
import 'package:app_movil/core/models/notification_model.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/core/widgets/notification_toast_feedback.dart';

class ArchivedNotificationsModal extends StatefulWidget {
  final bool isDark;

  const ArchivedNotificationsModal({
    super.key,
    required this.isDark,
  });

  static Future<void> show(BuildContext context, {required bool isDark}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => ArchivedNotificationsModal(isDark: isDark),
    );
  }

  @override
  State<ArchivedNotificationsModal> createState() => _ArchivedNotificationsModalState();
}

class _ArchivedNotificationsModalState extends State<ArchivedNotificationsModal> {
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
        title: const Text("Eliminar Definitivamente"),
        content: Text("¿Deseas eliminar permanentemente la notificación '${notif.title}'? Esta acción no se puede deshacer."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              prov.deleteNotification(notif.id);
              Navigator.pop(ctx);
              NotificationToastFeedback.showSuccess(context, "Notificación eliminada definitivamente");
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[600], foregroundColor: Colors.white),
            child: const Text("Sí, Eliminar"),
          ),
        ],
      ),
    );
  }

  void _confirmUnarchiveAll(BuildContext context, NotificationProvider prov) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Desarchivar Todas"),
        content: const Text("¿Deseas devolver todas las notificaciones archivadas a tu lista principal activa?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              prov.unarchiveAll();
              Navigator.pop(ctx);
              NotificationToastFeedback.showSuccess(context, "Todas las notificaciones han sido desarchivadas");
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[600], foregroundColor: Colors.white),
            child: const Text("Sí, Desarchivar"),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAll(BuildContext context, NotificationProvider prov) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Vaciar Archivadas"),
        content: const Text("¿Estás seguro de eliminar permanentemente TODAS las notificaciones archivadas? Esta acción no se puede deshacer."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              prov.deleteAllArchived();
              Navigator.pop(ctx);
              NotificationToastFeedback.showSuccess(context, "Bandeja de archivadas vaciada");
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
              ? (isDark ? Colors.amber[800]!.withValues(alpha: 0.35) : Colors.amber[100])
              : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey[200]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.amber[700]! : Colors.transparent,
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
                    ? (isDark ? Colors.amber[300] : Colors.orange[900])
                    : (isDark ? Colors.grey[400] : Colors.grey[700]),
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected 
                    ? (isDark ? Colors.amber[600] : Colors.orange[800])
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
    final archivedList = prov.archivedNotifications;
    final effectiveBottom = InteractiveSheetWrapper.getEffectiveBottomPadding(context, minPadding: kMinDefensiveBottomClearance);

    final bgCardColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final sectionBg = isDark ? const Color(0xFF1E1E28) : Colors.grey[50];
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];

    // Conteo por categorías en archivadas
    final int countTodas = archivedList.length;
    final int countCobranzas = archivedList.where((n) => n.objetoRelacionadoTipo == 'cuota').length;
    final int countInventario = archivedList.where((n) => n.objetoRelacionadoTipo == 'producto').length;
    final int countCotizaciones = archivedList.where((n) => n.objetoRelacionadoTipo == 'cotizacion' || n.objetoRelacionadoTipo == 'venta').length;

    // Filtrar lista
    final filteredList = archivedList.where((n) {
      if (_selectedCategory == 'Cobranzas' && n.objetoRelacionadoTipo != 'cuota') return false;
      if (_selectedCategory == 'Inventario' && n.objetoRelacionadoTipo != 'producto') return false;
      if (_selectedCategory == 'Cotizaciones' && n.objetoRelacionadoTipo != 'cotizacion' && n.objetoRelacionadoTipo != 'venta') return false;

      if (_searchQuery.trim().isNotEmpty) {
        final q = _searchQuery.trim().toLowerCase();
        final inTitle = n.title.toLowerCase().contains(q);
        final inMsg = n.message.toLowerCase().contains(q);
        if (!inTitle && !inMsg) return false;
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
                        color: Colors.amber.withValues(alpha: isDark ? 0.25 : 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.inventory_2_outlined, color: isDark ? Colors.amber[300] : Colors.orange[800], size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Notificaciones Archivadas",
                            style: TextStyle(
                              fontSize: 16.0,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            "${archivedList.length} notificación${archivedList.length != 1 ? 'es' : ''} resguardada${archivedList.length != 1 ? 's' : ''}",
                            style: TextStyle(fontSize: 12, color: subtitleColor),
                          ),
                        ],
                      ),
                    ),
                    if (archivedList.isNotEmpty)
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert_rounded, color: isDark ? Colors.grey[400] : Colors.grey[700]),
                        tooltip: "Opciones de archivadas",
                        onSelected: (val) {
                          if (val == 'unarchive_all') _confirmUnarchiveAll(context, prov);
                          if (val == 'delete_all') _confirmDeleteAll(context, prov);
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'unarchive_all',
                            child: Row(
                              children: [
                                Icon(Icons.unarchive_rounded, color: Colors.blue, size: 18),
                                SizedBox(width: 10),
                                Text("Desarchivar todas"),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete_all',
                            child: Row(
                              children: [
                                Icon(Icons.delete_sweep_rounded, color: Colors.red, size: 18),
                                SizedBox(width: 10),
                                Text("Vaciar archivadas"),
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
          const Divider(height: 1),

          // Buscador rápido y chips de filtro si hay elementos
          if (archivedList.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: SizedBox(
                height: 40,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                  style: TextStyle(fontSize: 13, color: textColor),
                  decoration: InputDecoration(
                    hintText: "Buscar en archivadas...",
                    hintStyle: TextStyle(fontSize: 12.5, color: subtitleColor),
                    prefixIcon: Icon(Icons.search_rounded, size: 18, color: subtitleColor),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 16),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF161622) : Colors.grey[200],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
            ),
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
          ],

          Expanded(
            child: archivedList.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 64, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text(
                            "Bandeja de Archivadas Vacía",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "Las notificaciones que archives se guardarán aquí para no saturar tu bandeja activa.",
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
                                "Sin coincidencias",
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "No hay notificaciones archivadas con el filtro seleccionado.",
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12.5, color: subtitleColor),
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
                                const SizedBox(height: 14),
                                Wrap(
                                  alignment: WrapAlignment.end,
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () => _confirmPermanentDelete(context, notif, prov),
                                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                                      label: const Text("Eliminar", style: TextStyle(fontSize: 12)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red[600],
                                        side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        prov.unarchiveNotification(notif.id);
                                        NotificationToastFeedback.showSuccess(
                                          context,
                                          "Notificación desarchivada y devuelta a la lista principal",
                                        );
                                      },
                                      icon: const Icon(Icons.unarchive_rounded, size: 16),
                                      label: const Text("Desarchivar", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue[600],
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          if (archivedList.isNotEmpty)
            Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, effectiveBottom + 8),
              decoration: BoxDecoration(
                color: bgCardColor,
                border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmDeleteAll(context, prov),
                      icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text("Limpiar bandeja", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red[600],
                        side: BorderSide(color: Colors.red.withValues(alpha: 0.35)),
                        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _confirmUnarchiveAll(context, prov),
                      icon: const Icon(Icons.unarchive_rounded, size: 16),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text("Restaurar todo", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
