import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/core/utils/smart_search_matcher.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/services/client_service.dart';
import 'package:app_movil/features/smart_quotation/services/loyalty_whatsapp_service.dart';
import 'package:app_movil/features/smart_quotation/screens/crm/client_detail_screen.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/reward_review_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/meta_reward_editor_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/loyalty_rules_config_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/promotion_broadcast_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/client_loyalty_history_modal.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';
import 'package:app_movil/core/services/tour/interactive_tour_service.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';
import 'package:app_movil/core/widgets/tour/configs/loyalty_center_tour.dart';

part 'loyalty_center/loyalty_center_metrics_and_actions.dart';
part 'loyalty_center/loyalty_center_reputation_tab.dart';
part 'loyalty_center/loyalty_center_reputation_card.dart';
part 'loyalty_center/loyalty_center_rewards_tab.dart';
part 'loyalty_center/loyalty_center_reward_cards.dart';
part 'loyalty_center/loyalty_center_offers_tab.dart';

class LoyaltyCenterScreen extends StatefulWidget {
  final int initialTabIndex;
  final bool autoTriggerTour;
  final LoyaltyCenterTourKeys? tourKeys;

  const LoyaltyCenterScreen({
    super.key,
    this.initialTabIndex = 0,
    this.autoTriggerTour = true,
    this.tourKeys,
  });

  @override
  State<LoyaltyCenterScreen> createState() => _LoyaltyCenterScreenState();
}

abstract class _LoyaltyCenterStateBase extends State<LoyaltyCenterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final LoyaltyCenterTourKeys _tourKeys;
  final ClientService _clientService = ClientService();

  final TextEditingController _reputationSearchCtrl = TextEditingController();
  final TextEditingController _productSearchCtrl = TextEditingController();

  bool _isLoading = true;
  bool _isHeaderVisible = true;
  bool _showTab3Banner = true;
  bool _isAudienceDockExpanded = false;

  List<ClientModel> _allClients = [];
  List<ClientRewardModel> _pendingRewards = [];
  List<ClientRewardModel> _pastRewards = [];
  List<RewardGoalModel> _goals = [];
  List<Map<String, dynamic>> _catalogProducts = [];
  List<Map<String, dynamic>> _clientsWithClaimableRewards = [];
  Map<int, List<RewardGoalModel>> _clientsClaimableMap = {};

  // Tab 1: Filtros de Reputación
  String _reputationSearchQuery = '';
  String _selectedTierFilter = 'TODOS'; // 'TODOS', 'CASI_EN_LA_META', o keys de tier
  List<Map<String, dynamic>> _almostAtGoalList = [];
  Map<int, Map<String, dynamic>> _almostAtGoalMap = {};

  // Tab 3: Avisos y Ofertas
  String _productSearchQuery = '';
  String _productFilterMode = 'ofertas'; // 'ofertas', 'baja_rotacion', 'todos'
  final Set<int> _selectedProductIds = {};
  String _audienceFilterTier = 'TODOS';
  final Set<int> _deselectedAudienceClientIds = {};

  @override
  void initState() {
    super.initState();
    _tourKeys = widget.tourKeys ?? LoyaltyCenterTourKeys();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadData();
      if (widget.autoTriggerTour) {
        InteractiveTourService.maybeStartAutomaticTour(
          context,
          _buildTourConfig(),
          onTourCompleted: () {
            if (mounted && _tabController.index != widget.initialTabIndex) {
              _tabController.animateTo(widget.initialTabIndex);
            }
          },
        );
      }
    });
  }

  ScreenTourConfig _buildTourConfig() {
    return LoyaltyCenterTour.buildConfig(
      keys: _tourKeys,
      onSwitchTab: (index) async {
        if (!mounted) return;
        _tabController.animateTo(index);
        await Future.delayed(const Duration(milliseconds: 300));
      },
      onRestoreInitialTab: () async {
        if (!mounted) return;
        _tabController.animateTo(widget.initialTabIndex);
        await Future.delayed(const Duration(milliseconds: 300));
      },
    );
  }

  void _startTour(BuildContext context) {
    InteractiveTourService.startManualTour(
      context,
      _buildTourConfig(),
      onTourCompleted: () {
        if (mounted && _tabController.index != widget.initialTabIndex) {
          _tabController.animateTo(widget.initialTabIndex);
        }
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _reputationSearchCtrl.dispose();
    _productSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() => loadData();

  Future<void> loadData() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final negocioId = auth.activeBusinessId ?? 1;

    try {
      // 0. Sincronizar niveles de reputación para garantizar score 500-749 = PLATA
      await _clientService.syncClientReputationTiers(negocioId);

      // 1. Cargar o sembrar metas si no existen
      var goals = await _clientService.getRewardGoals(negocioId, activeOnly: false);
      if (goals.isEmpty) {
        await LocalDatabase.seedDefaultMetasRecompensas(
          await _clientService.dbHelper.database,
        );
        goals = await _clientService.getRewardGoals(negocioId, activeOnly: false);
      }

      // 1.5. Evaluación retroactiva de metas activas para todos los clientes
      await _clientService.evaluateAllClientsForActiveGoals(negocioId);

      // 2. Cargar clientes
      final clients = await _clientService.getAllClients(negocioId);

      // 3. Cargar clientes "Casi en la Meta" (>= 70% o faltan <= 50 pts)
      final almostAtGoal = await _clientService.getClientsAlmostAtGoal(negocioId);
      final almostMap = <int, Map<String, dynamic>>{};
      for (var item in almostAtGoal) {
        final client = item['client'] as ClientModel;
        almostMap[client.id] = item;
      }

      // 3.5. Cargar clientes con metas alcanzadas listas para reclamar
      final claimableList = await _clientService.getClientsWithClaimableRewards(negocioId);
      final claimableMap = <int, List<RewardGoalModel>>{};
      for (var item in claimableList) {
        final client = item['client'] as ClientModel;
        claimableMap[client.id] = (item['claimable_goals'] as List).cast<RewardGoalModel>();
      }

      // 4. Cargar recompensas pendientes
      final pending = await _clientService.getPendingReviewRewards(negocioId);

      // 5. Cargar recompensas pasadas (excluyendo registros técnicos de migración)
      final db = await _clientService.dbHelper.database;
      final pastRows = await db.rawQuery('''
        SELECT rc.*, c.nombre_completo AS cliente_nombre, c.telefono AS cliente_telefono,
               c.puntos_actuales AS cliente_puntos, mr.nombre AS meta_titulo,
               mr.tipo_beneficio AS meta_tipo_beneficio, mr.valor_beneficio AS meta_valor_beneficio
        FROM recompensas_cliente rc
        JOIN clientes c ON rc.cliente_id = c.id
        JOIN metas_recompensas mr ON rc.meta_id = mr.id
        WHERE mr.negocio_id = ? 
          AND rc.estado != 'PENDIENTE_REVISION'
          AND rc.estado != 'MIGRADA_A_SALDO_LIBRE'
        ORDER BY rc.fecha_canje DESC, rc.fecha_aprobacion DESC, rc.fecha_desbloqueo DESC
        LIMIT 40
      ''', [negocioId]);
      final past = pastRows.map((r) => ClientRewardModel.fromMap(r)).toList();

      // 6. Cargar productos con ofertas / stock para Tab 3
      final prodRows = await db.rawQuery('''
        SELECT pp.id, p.nombre AS producto_nombre, pp.nombre_especifico,
               pp.precio_venta_final, pp.precio_oferta, pp.tipo_descuento,
               pp.valor_descuento, pp.stock_actual
        FROM presentaciones_producto pp
        JOIN productos p ON pp.producto_id = p.id
        WHERE p.negocio_id = ? AND pp.activo = 1
        ORDER BY (pp.precio_oferta IS NOT NULL OR pp.valor_descuento > 0) DESC, pp.stock_actual ASC
        LIMIT 80
      ''', [negocioId]);


      final prods = prodRows.map((r) {
        final pVenta = (r['precio_venta_final'] as num?)?.toDouble() ?? 0.0;
        final pOferta = (r['precio_oferta'] as num?)?.toDouble();
        final tipoDesc = r['tipo_descuento'] as String?;
        final valDesc = (r['valor_descuento'] as num?)?.toDouble();

        bool hasOffer = false;
        double effectivePrice = pVenta;

        if (pOferta != null && pOferta > 0 && pOferta < pVenta) {
          hasOffer = true;
          effectivePrice = pOferta;
        } else if (valDesc != null && valDesc > 0 && tipoDesc != null && tipoDesc != 'ninguno') {
          hasOffer = true;
          if (tipoDesc == 'porcentaje') {
            effectivePrice = pVenta * (1.0 - (valDesc / 100.0));
          } else {
            effectivePrice = pVenta - valDesc;
          }
        }

        final stock = (r['stock_actual'] as num?)?.toInt() ?? 0;
        final bool isLowStock = stock <= 5;

        return {
          'id': r['id'],
          'nombre': '${r['producto_nombre']}${r['nombre_especifico'] != null && (r['nombre_especifico'] as String).isNotEmpty ? " - ${r['nombre_especifico']}" : ""}',
          'precioRegular': pVenta,
          'precioEfectivo': effectivePrice > 0 ? effectivePrice : 0.0,
          'hasOffer': hasOffer,
          'stock': stock,
          'isLowStock': isLowStock,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _goals = goals;
          _allClients = clients;
          _almostAtGoalList = almostAtGoal;
          _almostAtGoalMap = almostMap;
          _pendingRewards = pending;
          _pastRewards = past;
          _catalogProducts = prods;
          _clientsWithClaimableRewards = claimableList;
          _clientsClaimableMap = claimableMap;
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      debugPrint("EXCEPCION EN _loadData: $e\n$stack");
      if (mounted) setState(() => _isLoading = false);
    }
  }


  void _openRulesConfig();
  Future<void> _openLoyaltyGuidePreview();
  List<ClientModel> get _filteredReputationClients;
  int _countByTier(String tierKey);
  List<Map<String, dynamic>> get _filteredCatalogProducts;
  int get _ofertasCount;
  int get _bajaRotacionCount;
  List<ClientModel> get _segmentClients;
  List<ClientModel> get _finalAudienceClients;
  void _onScrollNotification(UserScrollNotification notification);
  Widget _buildExecutiveHeader(bool isDark, Color cardColor, Color textColor);
  Widget _buildReputationTab(bool isDark, Color cardColor, Color textColor);
  Widget _buildReputationClientCard(
    ClientModel client,
    bool isDark,
    Color cardColor,
    Color textColor,
  );
  Widget _buildRewardsAndGoalsTab(bool isDark, Color cardColor, Color textColor);
  Widget _buildPendingRewardCard(
    ClientRewardModel rw,
    bool isDark,
    Color cardColor,
    Color textColor,
  );
  Widget _buildGoalCard(
    RewardGoalModel goal,
    bool isDark,
    Color cardColor,
    Color textColor,
  );
  Widget _buildPastRewardCard(
    ClientRewardModel rw,
    bool isDark,
    Color cardColor,
    Color textColor,
  );
  Widget _buildOffersBroadcasterTab(bool isDark, Color cardColor, Color textColor);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF13131A) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF1E1E2A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        titleSpacing: 16,
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            "Fidelización y Premios",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 17.5,
              letterSpacing: -0.2,
            ),
          ),
        ),
        centerTitle: false,
        backgroundColor: isDark ? const Color(0xFF1A1A24) : Colors.amber[800],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: "Actualizar datos",
            onPressed: _loadData,
          ),
          InfoTooltipButton(
            title: "Centro de Fidelización y Gamificación",
            description:
                "Gestiona los puntos acumulados por tus clientes, revisa y aprueba recompensas comerciales desbloqueadas y difunde ofertas exclusivas por WhatsApp.",
            onStartInteractiveTour: () => _startTour(context),
            tips: const [
              InfoTip(
                icon: Icons.stars_rounded,
                text: "Los clientes suman puntos automáticamente con compras al contado y pagos puntuales.",
              ),
              InfoTip(
                icon: Icons.notifications_active_rounded,
                text: "Revisa y confirma cada premio en 'Recompensas y Metas' antes de enviarlo por WhatsApp.",
              ),
              InfoTip(
                icon: Icons.point_of_sale_rounded,
                text: "Los premios aprobados se pueden canjear en 1 toque en Caja Rápida como descuento.",
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Container(
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.white10 : Colors.black12,
                  width: 0.5,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3.0,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelPadding: const EdgeInsets.symmetric(horizontal: 2),
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
              tabs: [
                const Tab(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.military_tech_outlined, size: 16),
                        SizedBox(width: 4),
                        Text("Reputación"),
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
                        Badge(
                          isLabelVisible: _pendingRewards.isNotEmpty,
                          label: Text('${_pendingRewards.length}'),
                          backgroundColor: Colors.redAccent,
                          child: const Icon(Icons.emoji_events_outlined, size: 16),
                        ),
                        const SizedBox(width: 4),
                        const Text("Recompensas"),
                      ],
                    ),
                  ),
                ),
                const Tab(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.campaign_outlined, size: 16),
                        SizedBox(width: 4),
                        Text("Avisos y Ofertas"),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : NotificationListener<UserScrollNotification>(
              onNotification: (n) {
                _onScrollNotification(n);
                return false;
              },
              child: Column(
                children: [
                  // Banner Resumen Ejecutivo Superior Retráctil
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    height: (_isHeaderVisible && _tabController.index != 2) ? 58.0 : 0.0,
                    child: ClipRect(
                      child: OverflowBox(
                        minHeight: 0,
                        maxHeight: 58,
                        alignment: Alignment.topCenter,
                        child: _buildExecutiveHeader(isDark, cardColor, textColor),
                      ),
                    ),
                  ),

                  // Contenido de las 3 Pestañas
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildReputationTab(isDark, cardColor, textColor),
                        _buildRewardsAndGoalsTab(isDark, cardColor, textColor),
                        _buildOffersBroadcasterTab(isDark, cardColor, textColor),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // =========================================================================
  // CABECERA EJECUTIVA SUPERIOR ANTI-COLISIÓN (3 COLUMNAS PROPORCIONALES)
  // =========================================================================
}

class _LoyaltyCenterScreenState extends _LoyaltyCenterStateBase
    with
        _LoyaltyCenterMetricsAndActionsMixin,
        _LoyaltyCenterReputationTabMixin,
        _LoyaltyCenterReputationCardMixin,
        _LoyaltyCenterRewardsTabMixin,
        _LoyaltyCenterRewardCardsMixin,
        _LoyaltyCenterOffersTabMixin {}
