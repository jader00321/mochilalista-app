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

  const NotificationItemCard({
    super.key,
    required this.notif,
    required this.isDark,
    required this.isSelected,
    required this.isSelectionMode,
    required this.tabIndex,
    required this.onLongPress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color iconColor;
    IconData iconData;

    switch (notif.prioridad.toLowerCase()) {
      case 'alta':
        iconColor = isDark ? Colors.red[400]! : Colors.red[600]!;
        iconData = Icons.warning_amber_rounded;
        break;
      case 'media':
        iconColor = isDark ? Colors.blue[400]! : Colors.blue[700]!;
        iconData = Icons.info_outline_rounded;
        break;
      case 'baja':
      default:
        iconColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
        iconData = Icons.notifications_none_rounded;
        break;
    }

    if (notif.type == 'exito' || (notif.objetoRelacionadoTipo != null && notif.objetoRelacionadoTipo!.contains('venta'))) {
      iconColor = isDark ? Colors.green[400]! : Colors.green[600]!;
      iconData = Icons.check_circle_outline_rounded;
    }

    final cardColor = isDark ? const Color(0xFF23232F) : Colors.white;

    return GestureDetector(
      onLongPress: onLongPress,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
             ? (isDark ? Colors.red[900]!.withValues(alpha: 0.3) : Colors.red[50])
             : (notif.isRead ? cardColor : (isDark ? iconColor.withValues(alpha: 0.12) : iconColor.withValues(alpha: 0.05))),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
               ? Colors.red[400]!
               : (notif.isRead ? (isDark ? Colors.white10 : Colors.grey.shade200) : iconColor.withValues(alpha: 0.4)), 
            width: 1.5
          ),
          boxShadow: [
            if (!isDark && notif.isRead && !isSelected) BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
            if (!isDark && !notif.isRead && !isSelected) BoxShadow(color: iconColor.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isSelectionMode && tabIndex == 2)
               Padding(
                  padding: const EdgeInsets.only(right: 12, top: 4),
                  child: Icon(isSelected ? Icons.check_circle : Icons.radio_button_unchecked, color: isSelected ? Colors.red[600] : Colors.grey[400]),
               ),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(iconData, color: iconColor, size: 28),
            ),
            const SizedBox(width: 16),
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
                          notif.title, 
                          style: TextStyle(fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.w800, fontSize: 16, color: isDark ? Colors.white : Colors.black87),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        DateFormat('HH:mm').format(notif.createdAt), 
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[500], fontWeight: FontWeight.w600),
                      )
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    notif.message, 
                    style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700], fontSize: 14, height: 1.4),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (notif.objetoRelacionadoTipo != null && !isSelectionMode) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(notif.isResolved ? Icons.check_circle_rounded : Icons.touch_app_rounded, size: 16, color: notif.isResolved ? Colors.green : (isDark ? Colors.blue[300] : Colors.blue[700])),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            notif.isResolved 
                              ? "Resuelta automáticamente" 
                              : _getActionText(notif.objetoRelacionadoTipo), 
                            style: TextStyle(fontSize: 13, color: notif.isResolved ? Colors.green : (isDark ? Colors.blue[300] : Colors.blue[700]), fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    )
                  ]
                ],
              ),
            ),
            if (!notif.isRead && !isSelectionMode) ...[
              const SizedBox(width: 12),
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 10, height: 10,
                decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
              )
            ]
          ],
        ),
      ),
    );
  }

  String _getActionText(String? type) {
    if (type == null) return "Toca para ver detalles";
    switch (type.toLowerCase()) {
      case 'producto':
        return "Toca para ver análisis de stock";
      case 'cuota':
        return "Toca para ver detalles de la deuda";
      case 'venta':
      case 'cotizacion':
      case 'venta_admin':
      case 'venta_cliente':
        return "Toca para ver la venta";
      default:
        return "Toca para más información";
    }
  }
}
