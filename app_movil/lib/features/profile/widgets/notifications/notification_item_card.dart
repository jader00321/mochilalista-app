import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/core/models/notification_model.dart';

class NotificationItemCard extends StatelessWidget {
  final NotificationModel notif;
  final bool isDark;
  final bool isSelected;
  final bool isSelectionMode;
  final int tabIndex;
  final VoidCallback onLongPress;
  final VoidCallback onTap;
  
  // Callbacks de In-Card Actions directas
  final VoidCallback? onActionRecordar;
  final VoidCallback? onActionCobrar;
  final VoidCallback? onActionMora;
  final VoidCallback? onActionAbastecer;
  final VoidCallback? onActionKardex;
  final VoidCallback? onActionVerCotizacion;
  final VoidCallback? onActionVerPremio;

  const NotificationItemCard({
    super.key,
    required this.notif,
    required this.isDark,
    required this.isSelected,
    required this.isSelectionMode,
    required this.tabIndex,
    required this.onLongPress,
    required this.onTap,
    this.onActionRecordar,
    this.onActionCobrar,
    this.onActionMora,
    this.onActionAbastecer,
    this.onActionKardex,
    this.onActionVerCotizacion,
    this.onActionVerPremio,
  });

  String _cleanTitle(String rawTitle) {
    return rawTitle
        .replaceAll(RegExp(r'^(💰|⚠️|🚨|📋|✅|📦)\s*'), '')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    Color iconColor;
    IconData iconData;

    final nivel = notif.nivelPrioridad.toLowerCase();
    final tipo = notif.objetoRelacionadoTipo?.toLowerCase();

    if (nivel == 'critica') {
      iconColor = isDark ? const Color(0xFFFF5252) : const Color(0xFFE53935);
      if (tipo == 'producto') {
        iconData = Icons.remove_shopping_cart_rounded;
      } else {
        iconData = Icons.error_outline_rounded;
      }
    } else if (nivel == 'preventiva') {
      iconColor = isDark ? const Color(0xFFFFA726) : const Color(0xFFFB8C00);
      if (tipo == 'producto') {
        iconData = Icons.inventory_2_outlined;
      } else {
        iconData = Icons.schedule_rounded;
      }
    } else if (nivel == 'informativa' || notif.type == 'exito') {
      iconColor = isDark ? const Color(0xFF66BB6A) : const Color(0xFF43A047);
      if (tipo == 'recompensa') {
        iconData = Icons.military_tech_rounded;
      } else {
        iconData = Icons.check_circle_outline_rounded;
      }
    } else {
      // Sistema / Cotización
      iconColor = isDark ? const Color(0xFF7986CB) : const Color(0xFF3949AB);
      if (tipo == 'cotizacion' || tipo == 'venta') {
        iconData = Icons.receipt_long_rounded;
      } else {
        iconData = Icons.shield_outlined;
      }
    }

    final cardBgColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final displayTitle = _cleanTitle(notif.title);

    return GestureDetector(
      onLongPress: onLongPress,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
             ? (isDark ? Colors.red[900]!.withValues(alpha: 0.35) : Colors.red[50])
             : (notif.isRead 
                 ? cardBgColor 
                 : (isDark ? iconColor.withValues(alpha: 0.12) : iconColor.withValues(alpha: 0.05))),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
               ? Colors.red[400]!
               : (notif.isRead 
                   ? (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200) 
                   : iconColor.withValues(alpha: 0.45)), 
            width: notif.isRead ? 1.0 : 1.5,
          ),
          boxShadow: [
            if (!isDark && notif.isRead && !isSelected) 
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
            if (!isDark && !notif.isRead && !isSelected) 
              BoxShadow(color: iconColor.withValues(alpha: 0.12), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isSelectionMode && tabIndex == 2)
                  Padding(
                    padding: const EdgeInsets.only(right: 12, top: 4),
                    child: Icon(
                      isSelected ? Icons.check_circle : Icons.radio_button_unchecked, 
                      color: isSelected ? Colors.red[600] : Colors.grey[400],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15), 
                    shape: BoxShape.circle,
                  ),
                  child: Icon(iconData, color: iconColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              displayTitle, 
                              style: TextStyle(
                                fontWeight: notif.isRead ? FontWeight.w700 : FontWeight.w900, 
                                fontSize: 15.5, 
                                letterSpacing: -0.3,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('HH:mm').format(notif.createdAt), 
                            style: TextStyle(
                              fontSize: 12, 
                              color: isDark ? Colors.grey[400] : Colors.grey[600], 
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notif.message, 
                        style: TextStyle(
                          color: isDark ? Colors.grey[300] : Colors.grey[800], 
                          fontSize: 13.5, 
                          height: 1.45,
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (!notif.isRead && !isSelectionMode) ...[
                  const SizedBox(width: 8),
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 9, 
                    height: 9,
                    decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
                  )
                ]
              ],
            ),

            // In-Card Action Buttons Bar
            if (!isSelectionMode) ...[
              const SizedBox(height: 12),
              _buildInCardActions(context, iconColor),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInCardActions(BuildContext context, Color themeColor) {
    final tipo = notif.objetoRelacionadoTipo?.toLowerCase();

    if (notif.isResolved) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, size: 14, color: Colors.green),
            const SizedBox(width: 6),
            Text(
              "Resuelta automáticamente", 
              style: TextStyle(
                fontSize: 12, 
                fontWeight: FontWeight.bold, 
                color: isDark ? Colors.green[300] : Colors.green[800],
              ),
            ),
          ],
        ),
      );
    }

    List<Widget> actions = [];

    if (tipo == 'cuota') {
      if (onActionRecordar != null) {
        actions.add(_buildActionBtn(
          icon: Icons.chat_bubble_outline_rounded,
          label: "Recordar",
          color: Colors.green[700]!,
          onTap: onActionRecordar!,
        ));
      }
      if (onActionCobrar != null) {
        actions.add(_buildActionBtn(
          icon: Icons.payments_outlined,
          label: "Cobrar",
          color: isDark ? Colors.blue[300]! : Colors.blue[700]!,
          onTap: onActionCobrar!,
          isPrimary: true,
        ));
      }
      if (onActionMora != null) {
        actions.add(_buildActionBtn(
          icon: Icons.trending_up_rounded,
          label: "Mora",
          color: isDark ? Colors.amber[300]! : Colors.orange[800]!,
          onTap: onActionMora!,
        ));
      }
    } else if (tipo == 'producto') {
      if (onActionAbastecer != null) {
        actions.add(_buildActionBtn(
          icon: Icons.add_business_rounded,
          label: "Abastecer",
          color: isDark ? Colors.blue[300]! : Colors.blue[700]!,
          onTap: onActionAbastecer!,
          isPrimary: true,
        ));
      }
      if (onActionKardex != null) {
        actions.add(_buildActionBtn(
          icon: Icons.analytics_outlined,
          label: "Kardex",
          color: isDark ? Colors.teal[300]! : Colors.teal[800]!,
          onTap: onActionKardex!,
        ));
      }
    } else if (tipo == 'cotizacion') {
      if (onActionVerCotizacion != null) {
        actions.add(_buildActionBtn(
          icon: Icons.receipt_long_rounded,
          label: "Ver Cotización",
          color: isDark ? Colors.indigo[300]! : Colors.indigo[700]!,
          onTap: onActionVerCotizacion!,
          isPrimary: true,
        ));
      }
    } else if (tipo == 'recompensa') {
      if (onActionVerPremio != null) {
        actions.add(_buildActionBtn(
          icon: Icons.military_tech_rounded,
          label: "Ver Premio",
          color: isDark ? Colors.amber[300]! : Colors.amber[800]!,
          onTap: onActionVerPremio!,
          isPrimary: true,
        ));
      }
    }

    if (actions.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: actions.map((btn) => Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: btn,
        )).toList(),
      ),
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isPrimary 
                ? color.withValues(alpha: isDark ? 0.25 : 0.12)
                : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPrimary 
                  ? color.withValues(alpha: 0.5) 
                  : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
