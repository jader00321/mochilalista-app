part of '../notifications_screen.dart';

mixin _NotificationsAppBarMixin on _NotificationsStateBase {
  @override
  PreferredSizeWidget _buildNotificationsAppBar({
    required BuildContext context,
    required NotificationProvider notifProv,
    required bool isDark,
    required Color bgColor,
    required Color textColor,
  }) {
    return AppBar(
      titleSpacing: 0,
      title: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          "Notificaciones",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: textColor,
            fontSize: 19,
            letterSpacing: -0.5,
          ),
        ),
      ),
      backgroundColor: bgColor,
      iconTheme: IconThemeData(color: textColor),
      elevation: 0,
      centerTitle: false,
      actions: [
        InfoTooltipButton(
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          padding: const EdgeInsets.all(6),
          onStartInteractiveTour: () => _startTour(context),
          title: 'Notificaciones',
          description:
              'Centro de control inteligente de tu negocio: cobranzas en mora, vencimientos preventivos, inventario bajo y cotizaciones.',
          tips: const [
            InfoTip(
              icon: Icons.swipe_rounded,
              text:
                  'Desliza horizontalmente para navegar entre pestañas con total seguridad.',
            ),
            InfoTip(
              icon: Icons.more_vert_rounded,
              text:
                  'Toca los tres puntos en cualquier tarjeta para archivar, silenciar o resolver con opción Deshacer.',
            ),
            InfoTip(
              icon: Icons.chat_bubble_outline,
              text:
                  'Envía recordatorios instantáneos por WhatsApp con mensaje pre-armado.',
            ),
            InfoTip(
              icon: Icons.payments_outlined,
              text:
                  'Cobra y registra abonos directamente desde la notificación.',
            ),
            InfoTip(
              icon: Icons.settings_suggest_outlined,
              text:
                  'Personaliza canales, umbrales y alertas desde el botón de configuración.',
            ),
          ],
        ),
        KeyedSubtree(
          key: _tourKeys.archiveActionsKey,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.inventory_2_outlined),
                    tooltip: "Notificaciones Archivadas",
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: const EdgeInsets.all(6),
                    onPressed: () => ArchivedNotificationsModal.show(
                      context,
                      isDark: isDark,
                    ),
                  ),
                  if (notifProv.archivedCount > 0)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber[700],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 14,
                          minHeight: 14,
                        ),
                        child: Text(
                          "${notifProv.archivedCount}",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (notifProv.unreadCount > 0)
                IconButton(
                  icon: Icon(
                    Icons.done_all_rounded,
                    color: isDark ? Colors.blue[300] : Colors.blue[700],
                  ),
                  tooltip: "Marcar todas como leídas",
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  padding: const EdgeInsets.all(6),
                  onPressed: () => notifProv.markAllAsRead(),
                ),
            ],
          ),
        ),
        KeyedSubtree(
          key: _tourKeys.settingsButtonKey,
          child: IconButton(
            icon: Icon(Icons.settings_outlined, color: textColor),
            tooltip: "Configuración de Notificaciones",
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: const EdgeInsets.all(6),
            onPressed: () =>
                NotificationSettingsModal.show(context, isDark: isDark),
          ),
        ),
        const SizedBox(width: 4),
      ],
      bottom: TabBar(
        controller: _tabController,
        labelColor: isDark ? Colors.white : Colors.blue[800],
        unselectedLabelColor: isDark ? Colors.grey[500] : Colors.grey[600],
        indicatorColor: isDark ? Colors.blue[400] : Colors.blue[700],
        labelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        indicatorWeight: 3,
        tabs: [
          Tab(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Pendientes"),
                  if (notifProv.pendingCount > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red[600],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "${notifProv.pendingCount}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Tab(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Resueltas"),
                  if (notifProv.resolvedCount > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.15)
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "${notifProv.resolvedCount}",
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Tab(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Historial"),
                  if (notifProv.totalHistoryCount > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.15)
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        "${notifProv.totalHistoryCount}",
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
