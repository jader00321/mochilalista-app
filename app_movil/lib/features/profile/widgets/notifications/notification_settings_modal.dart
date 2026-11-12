import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/providers/notification_provider.dart';
import 'package:app_movil/core/models/notification_preferences_model.dart';
import 'package:app_movil/features/profile/widgets/notifications/archived_notifications_modal.dart';
import 'package:app_movil/features/profile/widgets/notifications/silenced_notifications_modal.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

class NotificationSettingsModal extends StatefulWidget {
  final bool isDark;

  const NotificationSettingsModal({
    super.key,
    required this.isDark,
  });

  static Future<void> show(BuildContext context, {required bool isDark}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (_) => NotificationSettingsModal(isDark: isDark),
    );
  }

  @override
  State<NotificationSettingsModal> createState() => _NotificationSettingsModalState();
}

class _NotificationSettingsModalState extends State<NotificationSettingsModal> {
  late NotificationPreferences _localPrefs;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final prov = Provider.of<NotificationProvider>(context, listen: false);
      _localPrefs = prov.preferences;
      _initialized = true;
    }
  }

  void _updatePreference(NotificationPreferences newPrefs) {
    setState(() {
      _localPrefs = newPrefs;
    });
    Provider.of<NotificationProvider>(context, listen: false).updatePreferences(newPrefs);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final prov = Provider.of<NotificationProvider>(context);
    final effectiveBottom = InteractiveSheetWrapper.getEffectiveBottomPadding(context, minPadding: kMinDefensiveBottomClearance);

    final bgCardColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final sectionBg = isDark ? const Color(0xFF1E1E28) : Colors.grey[50];
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: sectionBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle y Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
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
                        color: Colors.blue.withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.settings_suggest_rounded, color: isDark ? Colors.blue[300] : Colors.blue[700], size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Configuración de Alertas",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                          letterSpacing: -0.3,
                        ),
                      ),
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

          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, effectiveBottom + 20),
              physics: const BouncingScrollPhysics(),
              children: [
                // ACCESOS A BANDEJAS DE RESGUARDO
                _buildSectionHeader("BANDEJAS DE RESGUARDO", isDark),
                Container(
                  decoration: BoxDecoration(
                    color: bgCardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.amber.withValues(alpha: isDark ? 0.2 : 0.1),
                          child: Icon(Icons.inventory_2_outlined, color: isDark ? Colors.amber[300] : Colors.orange[800]),
                        ),
                        title: const Text("Notificaciones Archivadas", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                        subtitle: Text("Alertas retiradas temporalmente de la lista activa", style: TextStyle(fontSize: 12, color: subtitleColor)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "${prov.archivedCount}",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                        onTap: () {
                          ArchivedNotificationsModal.show(context, isDark: isDark);
                        },
                      ),
                      Divider(height: 1, indent: 64, color: isDark ? Colors.white10 : Colors.grey[200]),
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.red.withValues(alpha: isDark ? 0.2 : 0.1),
                          child: Icon(Icons.notifications_off_outlined, color: isDark ? Colors.red[300] : Colors.red[700]),
                        ),
                        title: const Text("Ítems No Deseados / Silenciados", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                        subtitle: Text("Cuotas, clientes o productos con alertas bloqueadas", style: TextStyle(fontSize: 12, color: subtitleColor)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "${prov.silencedCount}",
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right_rounded),
                          ],
                        ),
                        onTap: () {
                          SilencedNotificationsModal.show(context, isDark: isDark);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // CANALES DE COBRANZAS
                _buildSectionHeader("ALERTAS DE COBRANZAS", isDark),
                _buildContainer([
                  _buildSwitchTile(
                    title: "Cuotas Vencidas (Mora)",
                    subtitle: "Avisos críticos de cuotas con fecha límite superada",
                    value: _localPrefs.notifCuotasVencidas,
                    onChanged: (v) => _updatePreference(_localPrefs.copyWith(notifCuotasVencidas: v)),
                    icon: Icons.warning_amber_rounded,
                    iconColor: Colors.red,
                    isDark: isDark,
                  ),
                  _buildSwitchTile(
                    title: "Avisos Preventivos de Vencimiento",
                    subtitle: "Recordatorios anticipados de cuotas próximas a vencer",
                    value: _localPrefs.notifCuotasPreventivas,
                    onChanged: (v) => _updatePreference(_localPrefs.copyWith(notifCuotasPreventivas: v)),
                    icon: Icons.schedule_rounded,
                    iconColor: Colors.orange,
                    isDark: isDark,
                  ),
                  _buildSwitchTile(
                    title: "Confirmación de Pagos y Abonos",
                    subtitle: "Historial de cuotas canceladas con éxito",
                    value: _localPrefs.notifConfirmacionPagos,
                    onChanged: (v) => _updatePreference(_localPrefs.copyWith(notifConfirmacionPagos: v)),
                    icon: Icons.check_circle_outline_rounded,
                    iconColor: Colors.green,
                    isDark: isDark,
                  ),
                ], bgCardColor, isDark),
                const SizedBox(height: 24),

                // CANALES DE INVENTARIO
                _buildSectionHeader("ALERTAS DE INVENTARIO", isDark),
                _buildContainer([
                  _buildSwitchTile(
                    title: "Productos Agotados (0 und.)",
                    subtitle: "Aviso crítico inmediato al agotarse existencias",
                    value: _localPrefs.notifStockAgotado,
                    onChanged: (v) => _updatePreference(_localPrefs.copyWith(notifStockAgotado: v)),
                    icon: Icons.remove_shopping_cart_rounded,
                    iconColor: Colors.red,
                    isDark: isDark,
                  ),
                  _buildSwitchTile(
                    title: "Stock Bajo Preventivo",
                    subtitle: "Alertas al alcanzar el umbral mínimo configurado",
                    value: _localPrefs.notifStockBajo,
                    onChanged: (v) => _updatePreference(_localPrefs.copyWith(notifStockBajo: v)),
                    icon: Icons.inventory_2_outlined,
                    iconColor: Colors.amber,
                    isDark: isDark,
                  ),
                  _buildSwitchTile(
                    title: "Stock Compartido Bajo",
                    subtitle: "Vigilancia de presentaciones con stock común",
                    value: _localPrefs.notifStockCompartido,
                    onChanged: (v) => _updatePreference(_localPrefs.copyWith(notifStockCompartido: v)),
                    icon: Icons.alt_route_rounded,
                    iconColor: Colors.purple,
                    isDark: isDark,
                  ),
                ], bgCardColor, isDark),
                const SizedBox(height: 24),

                // CANALES DE COTIZACIONES Y METAS
                _buildSectionHeader("VENTAS, COTIZACIONES Y PREMIOS", isDark),
                _buildContainer([
                  _buildSwitchTile(
                    title: "Cotizaciones por Vencer / Vencidas",
                    subtitle: "Seguimiento para cerrar acuerdos pendientes",
                    value: _localPrefs.notifCotizacionesVencidas,
                    onChanged: (v) => _updatePreference(_localPrefs.copyWith(notifCotizacionesVencidas: v)),
                    icon: Icons.receipt_long_rounded,
                    iconColor: Colors.indigo,
                    isDark: isDark,
                  ),
                  _buildSwitchTile(
                    title: "Metas y Fidelización",
                    subtitle: "Avisos cuando un cliente alcanza puntos para un premio",
                    value: _localPrefs.notifMetasFidelizacion,
                    onChanged: (v) => _updatePreference(_localPrefs.copyWith(notifMetasFidelizacion: v)),
                    icon: Icons.military_tech_rounded,
                    iconColor: Colors.amber,
                    isDark: isDark,
                  ),
                ], bgCardColor, isDark),
                const SizedBox(height: 24),

                // TIEMPOS Y UMBRALES
                _buildSectionHeader("TIEMPOS Y CONDICIONES", isDark),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: bgCardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Anticipación de Avisos Preventivos",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "¿Con cuántos días de anticipación alertar cuotas por vencer?",
                        style: TextStyle(fontSize: 12, color: subtitleColor),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildAnticipationChip(0, "Mismo día", isDark),
                          _buildAnticipationChip(1, "1 día antes", isDark),
                          _buildAnticipationChip(2, "2 días antes", isDark),
                          _buildAnticipationChip(3, "3 días antes", isDark),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
                      const SizedBox(height: 18),
                      Text(
                        "Prioridad Mínima Visible",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Filtra la exigencia de las alertas mostradas en lista activa",
                        style: TextStyle(fontSize: 12, color: subtitleColor),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildPriorityChip("todas", "Mostrar todas", isDark),
                          _buildPriorityChip("preventivas_criticas", "Preventivas y Críticas", isDark),
                          _buildPriorityChip("solo_criticas", "Solo Críticas", isDark),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // APARIENCIA E INTERACCIÓN
                _buildSectionHeader("INTERACCIÓN Y NAVEGACIÓN", isDark),
                _buildContainer([
                  _buildSwitchTile(
                    title: "Smart Grouping por Cliente",
                    subtitle: "Agrupa clientes con 2 o más cuotas en mora en tarjeta maestra",
                    value: _localPrefs.activarSmartGrouping,
                    onChanged: (v) => _updatePreference(_localPrefs.copyWith(activarSmartGrouping: v)),
                    icon: Icons.groups_rounded,
                    iconColor: Colors.blue,
                    isDark: isDark,
                  ),
                  _buildSwitchTile(
                    title: "Dashboard de Pulso Ejecutivo",
                    subtitle: "Muestra KPIs rápidos de mora e inventario en Pendientes",
                    value: _localPrefs.mostrarPulseDashboard,
                    onChanged: (v) => _updatePreference(_localPrefs.copyWith(mostrarPulseDashboard: v)),
                    icon: Icons.analytics_outlined,
                    iconColor: Colors.teal,
                    isDark: isDark,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Comportamiento al Deslizar (Swipe)",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: textColor),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Elige la función al arrastrar horizontalmente sobre la pantalla",
                          style: TextStyle(fontSize: 12, color: subtitleColor),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildSwipeModeBtn(
                                id: 'tab_navigation',
                                label: "Navegar pestañas",
                                icon: Icons.swipe_rounded,
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildSwipeModeBtn(
                                id: 'card_actions',
                                label: "Cajón de tarjeta",
                                icon: Icons.view_headline_rounded,
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ], bgCardColor, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.1,
          color: isDark ? Colors.grey[400] : Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildContainer(List<Widget> children, Color bgColor, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
  }) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: isDark ? 0.2 : 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600])),
      activeThumbColor: Colors.blue[600],
    );
  }

  Widget _buildAnticipationChip(int days, String label, bool isDark) {
    final isSel = _localPrefs.diasAnticipacionCuotas == days;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12.5)),
      selected: isSel,
      onSelected: (v) {
        if (v) _updatePreference(_localPrefs.copyWith(diasAnticipacionCuotas: days));
      },
      selectedColor: Colors.blue.withValues(alpha: isDark ? 0.3 : 0.15),
      labelStyle: TextStyle(
        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
        color: isSel ? (isDark ? Colors.blue[200] : Colors.blue[800]) : (isDark ? Colors.grey[400] : Colors.grey[700]),
      ),
    );
  }

  Widget _buildPriorityChip(String id, String label, bool isDark) {
    final isSel = _localPrefs.prioridadMinima == id;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12.5)),
      selected: isSel,
      onSelected: (v) {
        if (v) _updatePreference(_localPrefs.copyWith(prioridadMinima: id));
      },
      selectedColor: Colors.blue.withValues(alpha: isDark ? 0.3 : 0.15),
      labelStyle: TextStyle(
        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
        color: isSel ? (isDark ? Colors.blue[200] : Colors.blue[800]) : (isDark ? Colors.grey[400] : Colors.grey[700]),
      ),
    );
  }

  Widget _buildSwipeModeBtn({
    required String id,
    required String label,
    required IconData icon,
    required bool isDark,
  }) {
    final isSel = _localPrefs.comportamientoSwipe == id;
    final color = isSel ? Colors.blue : (isDark ? Colors.grey[600]! : Colors.grey[400]!);

    return InkWell(
      onTap: () => _updatePreference(_localPrefs.copyWith(comportamientoSwipe: id)),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSel ? Colors.blue.withValues(alpha: isDark ? 0.25 : 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: isSel ? 0.8 : 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSel ? Colors.blue[400] : color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                  color: isSel ? (isDark ? Colors.white : Colors.blue[900]) : color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
