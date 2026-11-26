import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/utils/app_date_formatter.dart';

import 'package:app_movil/core/providers/notification_provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/models/notification_model.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/core/database/local_db.dart';

import 'package:app_movil/features/smart_quotation/screens/quotation_detail_screen.dart';
import 'package:app_movil/features/scanner/screens/invoice_detail_screen.dart';
import 'package:app_movil/features/catalog/screens/product_edit_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/crm/client_detail_screen.dart';
import 'package:app_movil/features/smart_quotation/services/sales_service.dart';
import 'package:app_movil/features/smart_quotation/services/client_service.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';
import 'package:app_movil/core/services/tour/interactive_tour_service.dart';
import 'package:app_movil/core/widgets/tour/configs/notifications_tour.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';

import 'package:app_movil/features/profile/widgets/notifications/notification_filter_bar.dart';
import 'package:app_movil/features/profile/widgets/notifications/notification_item_card.dart';
import 'package:app_movil/features/profile/widgets/notifications/notification_empty_state.dart';
import 'package:app_movil/features/profile/widgets/notifications/notification_settings_modal.dart';
import 'package:app_movil/features/profile/widgets/notifications/archived_notifications_modal.dart';
import 'package:app_movil/features/profile/widgets/notifications/stock_analysis_modal.dart';
import 'package:app_movil/core/widgets/notification_toast_feedback.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

import 'package:app_movil/features/smart_quotation/widgets/history/detail_widgets/whatsapp_preview_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/detail_widgets/cuota_morosidad_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/payment_entry_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/reward_review_modal.dart';

part 'notifications/notifications_app_bar.dart';
part 'notifications/notifications_actions_and_deeplinks.dart';
part 'notifications/notifications_cuota_detail_modal.dart';
part 'notifications/notifications_generic_detail_modal.dart';
part 'notifications/notifications_grouped_client_section.dart';
part 'notifications/notifications_pulse_and_cards.dart';
part 'notifications/notifications_card_action_menu.dart';

class NotificationsScreen extends StatefulWidget {
  final bool autoTriggerTour;
  final NotificationsTourKeys? tourKeys;

  const NotificationsScreen({
    super.key,
    this.autoTriggerTour = true,
    this.tourKeys,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

abstract class _NotificationsStateBase extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final NotificationsTourKeys _tourKeys;
  bool _didAttemptAutoTour = false;

  String _categoryFilter =
      'Todas'; // Todas, Cobranzas, Inventario, Cotizaciones
  String _timeFilter = 'Todo'; // Todo, Hoy, 7 Días, Específico
  DateTime? _specificDate;

  InventoryProvider? _inventoryProvider;

  bool _isSelectionMode = false;
  final Set<int> _selectedIds = {};

  // Estado para Smart Grouping expandible
  final Set<int> _expandedClientGroupIds = {};

  @override
  void initState() {
    super.initState();
    _tourKeys = widget.tourKeys ?? NotificationsTourKeys();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index != 2 && _isSelectionMode) {
        setState(() {
          _isSelectionMode = false;
          _selectedIds.clear();
        });
      }
      setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _inventoryProvider = Provider.of<InventoryProvider>(
        context,
        listen: false,
      );
      _inventoryProvider?.addListener(_onInventoryChanged);
      await Provider.of<NotificationProvider>(
        context,
        listen: false,
      ).fetchNotifications();
      if (mounted) _maybeStartAutoTour();
    });
  }

  ScreenTourConfig _buildTourConfig() {
    return NotificationsTour.buildConfig(keys: _tourKeys);
  }

  void _startTour(BuildContext context) {
    InteractiveTourService.startManualTour(context, _buildTourConfig());
  }

  void _maybeStartAutoTour() {
    if (!widget.autoTriggerTour || _didAttemptAutoTour || !mounted) return;
    _didAttemptAutoTour = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await InteractiveTourService.maybeStartAutomaticTour(
        context,
        _buildTourConfig(),
      );
    });
  }

  void _onInventoryChanged() {
    if (mounted) {
      Provider.of<NotificationProvider>(
        context,
        listen: false,
      ).fetchNotifications();
    }
  }

  @override
  void dispose() {
    _inventoryProvider?.removeListener(_onInventoryChanged);
    _tabController.dispose();
    super.dispose();
  }


  PreferredSizeWidget _buildNotificationsAppBar({
    required BuildContext context,
    required NotificationProvider notifProv,
    required bool isDark,
    required Color bgColor,
    required Color textColor,
  });
  void _onActionRecordarCuota(NotificationModel notif);
  void _onActionCobrarCuota(NotificationModel notif);
  void _onActionMoraCuota(NotificationModel notif);
  void _onActionAbastecer(NotificationModel notif);
  void _onActionKardex(NotificationModel notif);
  void _onActionVerCotizacion(NotificationModel notif);
  void _onActionVerPremio(NotificationModel notif);
  void _onActionRecordarConsolidado(
    int clientId,
    String clientName,
    String? clientPhone,
    List<NotificationModel> cuotas,
  );
  void _handleDeepLink(NotificationModel notif, BuildContext context);
  void _showStockAnalysisModal(
    NotificationModel notif,
    BuildContext context,
  );
  void _showCuotaVencidaModal(
    NotificationModel notif,
    BuildContext context,
  );
  void _showNotificationDetails(NotificationModel notif);
  List<dynamic> _buildGroupedList(List<NotificationModel> notifs);
  Widget _buildGroupedClientMasterCard({
    required int clientId,
    required String clientName,
    required String? clientPhone,
    required List<NotificationModel> cuotas,
    required bool isDark,
    required NotificationProvider prov,
  });
  void _confirmDelete(NotificationProvider prov);
  Widget _buildTabContent(
    List<NotificationModel> notifs,
    NotificationProvider prov,
    bool isDark, {
    required int tabIndex,
  });
  Widget _buildNotificationCardItem(
    NotificationModel notif,
    NotificationProvider prov,
    bool isDark, {
    required int tabIndex,
  });
  void _handleArchive(NotificationModel notif, NotificationProvider prov);
  void _handleSilence(NotificationModel notif, NotificationProvider prov);
  void _handleToggleResolve(
    NotificationModel notif,
    NotificationProvider prov,
  );
  void _showCardActionMenu(
    NotificationModel notif,
    NotificationProvider prov,
    bool isDark,
  );

  @override
  Widget build(BuildContext context) {
    final notifProv = Provider.of<NotificationProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black87;

    List<NotificationModel> filteredNotifs = notifProv.notifications;

    // Apply Time Filter
    if (_timeFilter != 'Todo') {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      filteredNotifs = filteredNotifs.where((n) {
        final notifDate = DateTime(
          n.createdAt.year,
          n.createdAt.month,
          n.createdAt.day,
        );
        if (_timeFilter == 'Hoy') {
          return notifDate == today;
        } else if (_timeFilter == '7 Días') {
          return notifDate.isAfter(today.subtract(const Duration(days: 7))) ||
              notifDate == today;
        } else if (_timeFilter == 'Específico' && _specificDate != null) {
          return notifDate.year == _specificDate!.year &&
              notifDate.month == _specificDate!.month;
        }
        return true;
      }).toList();
    }

    // Apply Category Filter
    if (_categoryFilter != 'Todas') {
      filteredNotifs = filteredNotifs.where((n) {
        final tipo = n.objetoRelacionadoTipo?.toLowerCase();
        if (_categoryFilter == 'Cobranzas') return tipo == 'cuota';
        if (_categoryFilter == 'Inventario') return tipo == 'producto';
        if (_categoryFilter == 'Cotizaciones') {
          return tipo == 'cotizacion' || tipo == 'venta';
        }
        return true;
      }).toList();
    }

    // Split by tabs
    final pendientes = filteredNotifs
        .where((n) => n.isActionable && !n.isResolved)
        .toList();
    final resueltas = filteredNotifs
        .where((n) => n.isActionable && n.isResolved)
        .toList();
    final historial = filteredNotifs;

    // Conteo para chips de categoría
    final currentTabNotifs = _tabController.index == 0
        ? notifProv.notifications
              .where((n) => n.isActionable && !n.isResolved)
              .toList()
        : (_tabController.index == 1
              ? notifProv.notifications
                    .where((n) => n.isActionable && n.isResolved)
                    .toList()
              : notifProv.notifications);

    final int totalCount = currentTabNotifs.length;
    final int cobranzasCount = currentTabNotifs
        .where((n) => n.objetoRelacionadoTipo == 'cuota')
        .length;
    final int inventarioCount = currentTabNotifs
        .where((n) => n.objetoRelacionadoTipo == 'producto')
        .length;
    final int cotizacionesCount = currentTabNotifs
        .where(
          (n) =>
              n.objetoRelacionadoTipo == 'cotizacion' ||
              n.objetoRelacionadoTipo == 'venta',
        )
        .length;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildNotificationsAppBar(
        context: context,
        notifProv: notifProv,
        isDark: isDark,
        bgColor: bgColor,
        textColor: textColor,
      ),
      body: Column(
        children: [
          KeyedSubtree(
            key: _tourKeys.filtersBarKey,
            child: NotificationFilterBar(
              isDark: isDark,
              categoryFilter: _categoryFilter,
              timeFilter: _timeFilter,
              totalCount: totalCount,
              cobranzasCount: cobranzasCount,
              inventarioCount: inventarioCount,
              cotizacionesCount: cotizacionesCount,
              specificDate: _specificDate,
              onCategoryFilterChanged: (v) =>
                  setState(() => _categoryFilter = v),
              onTimeFilterChanged: (f) => setState(() => _timeFilter = f),
              onSpecificDateTapped: () async {
                DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() {
                    _timeFilter = 'Específico';
                    _specificDate = picked;
                  });
                }
              },
            ),
          ),
          if (_tabController.index == 2 && _isSelectionMode)
            NotificationSelectionBar(
              isDark: isDark,
              selectedCount: _selectedIds.length,
              onCancel: () => setState(() {
                _isSelectionMode = false;
                _selectedIds.clear();
              }),
              onDelete: () => _confirmDelete(notifProv),
            ),
          Expanded(
            child: KeyedSubtree(
              key: _tourKeys.cardsFeedKey,
              child: TabBarView(
                controller: _tabController,
                physics:
                    notifProv.preferences.comportamientoSwipe == 'card_actions'
                    ? const NeverScrollableScrollPhysics()
                    : null,
                children: [
                  _buildTabContent(pendientes, notifProv, isDark, tabIndex: 0),
                  _buildTabContent(resueltas, notifProv, isDark, tabIndex: 1),
                  _buildTabContent(historial, notifProv, isDark, tabIndex: 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

}

class _NotificationsScreenState extends _NotificationsStateBase
    with
        _NotificationsAppBarMixin,
        _NotificationsActionsAndDeeplinksMixin,
        _NotificationsCuotaDetailModalMixin,
        _NotificationsGenericDetailModalMixin,
        _NotificationsGroupedClientSectionMixin,
        _NotificationsPulseAndCardsMixin,
        _NotificationsCardActionMenuMixin {}
