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

class LoyaltyCenterScreen extends StatefulWidget {
  final int initialTabIndex;

  const LoyaltyCenterScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<LoyaltyCenterScreen> createState() => _LoyaltyCenterScreenState();
}

class _LoyaltyCenterScreenState extends State<LoyaltyCenterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
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
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => loadData());
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

      // 5. Cargar recompensas pasadas
      final db = await _clientService.dbHelper.database;
      final pastRows = await db.rawQuery('''
        SELECT rc.*, c.nombre_completo AS cliente_nombre, c.telefono AS cliente_telefono,
               c.puntos_actuales AS cliente_puntos, mr.nombre AS meta_titulo,
               mr.tipo_beneficio AS meta_tipo_beneficio, mr.valor_beneficio AS meta_valor_beneficio
        FROM recompensas_cliente rc
        JOIN clientes c ON rc.cliente_id = c.id
        JOIN metas_recompensas mr ON rc.meta_id = mr.id
        WHERE mr.negocio_id = ? AND rc.estado != 'PENDIENTE_REVISION'
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

  void _openRulesConfig() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final negocioId = auth.activeBusinessId ?? 1;
    LoyaltyRulesConfigModal.show(
      context,
      negocioId: negocioId,
      onRulesSaved: _loadData,
    );
  }

  Future<void> _openLoyaltyGuidePreview() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final negocioId = auth.activeBusinessId ?? 1;
    final rules = await _clientService.getLoyaltyRules(negocioId);
    if (!mounted) return;
    final msg = LoyaltyWhatsAppService.buildLoyaltyGuideAndCatalogMessage(
      businessName: auth.activeBusinessName,
      rules: rules,
      activeGoals: _goals.where((g) => g.activo).toList(),
    );
    if (mounted) {
      await LoyaltyWhatsAppService.showEditableWhatsAppPreviewModal(
        context: context,
        title: "Cartilla de Puntos y Premios",
        phone: "",
        initialMessage: msg,
      );
    }
  }

  // --- FILTROS TAB 1 (Reputación) ---
  List<ClientModel> get _filteredReputationClients {
    return _allClients.where((c) {
      if (_selectedTierFilter == 'CASI_EN_LA_META') {
        if (!_almostAtGoalMap.containsKey(c.id)) {
          return false;
        }
      } else if (_selectedTierFilter != 'TODOS') {
        if (c.tier.key != _selectedTierFilter) {
          return false;
        }
      }
      if (_reputationSearchQuery.isNotEmpty) {
        return SmartSearchMatcher.matches(
          query: _reputationSearchQuery,
          targets: [
            c.fullName,
            c.phone,
            c.docNumber,
            c.tier.displayName,
            c.tier.key,
          ],
        );
      }
      return true;
    }).toList();
  }

  int _countByTier(String tierKey) {
    return _allClients.where((c) => c.tier.key == tierKey).length;
  }

  // --- FILTROS TAB 3 (Productos y Difusión) ---
  List<Map<String, dynamic>> get _filteredCatalogProducts {
    return _catalogProducts.where((p) {
      if (_productFilterMode == 'ofertas' && !(p['hasOffer'] as bool)) {
        return false;
      }
      if (_productFilterMode == 'baja_rotacion' && !(p['isLowStock'] as bool)) {
        return false;
      }
      if (_productSearchQuery.isNotEmpty) {
        return SmartSearchMatcher.matches(
          query: _productSearchQuery,
          targets: [
            p['nombre'] as String?,
          ],
        );
      }
      return true;
    }).toList();
  }

  int get _ofertasCount => _catalogProducts.where((p) => p['hasOffer'] as bool).length;
  int get _bajaRotacionCount => _catalogProducts.where((p) => p['isLowStock'] as bool).length;

  List<ClientModel> get _segmentClients {
    if (_audienceFilterTier == 'TODOS') return _allClients;
    return _allClients.where((c) => c.tier.key == _audienceFilterTier).toList();
  }

  List<ClientModel> get _finalAudienceClients {
    final list = _segmentClients;
    return list.where((c) => !_deselectedAudienceClientIds.contains(c.id)).toList();
  }

  // Métricas Ejecutivas del Negocio
  int get _totalActivePoints => _allClients.fold(0, (sum, c) => sum + c.puntosActuales);
  int get _vipAndGoldCount => _allClients.where((c) {
        final t = c.tier.key;
        return t == 'DIAMANTE_VIP' || t == 'ORO';
      }).length;

  void _onScrollNotification(UserScrollNotification notification) {
    if (notification.direction == ScrollDirection.reverse && _isHeaderVisible) {
      setState(() => _isHeaderVisible = false);
    } else if (notification.direction == ScrollDirection.forward && !_isHeaderVisible) {
      setState(() => _isHeaderVisible = true);
    }
  }

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
            icon: const Icon(Icons.tune_rounded),
            tooltip: "Reglas de Puntos",
            onPressed: _openRulesConfig,
          ),
          IconButton(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: "Actualizar datos",
            onPressed: _loadData,
          ),
          const InfoTooltipButton(
            title: "Centro de Fidelización y Gamificación",
            description:
                "Gestiona los puntos acumulados por tus clientes, revisa y aprueba recompensas comerciales desbloqueadas y difunde ofertas exclusivas por WhatsApp.",
            tips: [
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
  Widget _buildExecutiveHeader(bool isDark, Color cardColor, Color textColor) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildExecutiveMetric(
              "Puntos Activos",
              "$_totalActivePoints pts",
              Icons.stars_rounded,
              Colors.amber[700]!,
              textColor,
              isDark,
            ),
          ),
          Container(height: 28, width: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
          Expanded(
            child: _buildExecutiveMetric(
              "Por Revisar",
              "${_pendingRewards.length} pendientes",
              Icons.notifications_active_rounded,
              _pendingRewards.isNotEmpty ? Colors.redAccent : Colors.green,
              textColor,
              isDark,
            ),
          ),
          Container(height: 28, width: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
          Expanded(
            child: _buildExecutiveMetric(
              "Clientes VIP",
              "$_vipAndGoldCount clientes",
              Icons.diamond_outlined,
              const Color(0xFF00E5FF),
              textColor,
              isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExecutiveMetric(
    String label,
    String value,
    IconData icon,
    Color color,
    Color textColor,
    bool isDark,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 1: REPUTACIÓN Y NIVELES
  // =========================================================================
  Widget _buildReputationTab(bool isDark, Color cardColor, Color textColor) {
    final clients = _filteredReputationClients;

    return Column(
      children: [
        // Buscador y Chips de Niveles
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          color: cardColor,
          child: Column(
            children: [
              TextField(
                controller: _reputationSearchCtrl,
                onChanged: (val) => setState(() => _reputationSearchQuery = val),
                style: TextStyle(color: textColor, fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: "Buscar por nombre, teléfono o nivel...",
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _reputationSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _reputationSearchCtrl.clear();
                            setState(() => _reputationSearchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildTierFilterChip(
                      'TODOS',
                      'Todos (${_allClients.length})',
                      Icons.people_outline_rounded,
                      Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    _buildTierFilterChip(
                      'CASI_EN_LA_META',
                      'Casi en la Meta (${_almostAtGoalList.length})',
                      Icons.track_changes_rounded,
                      Colors.amber[800]!,
                    ),
                    const SizedBox(width: 6),
                    _buildTierFilterChip(
                      'DIAMANTE_VIP',
                      'Diamante VIP (${_countByTier('DIAMANTE_VIP')})',
                      Icons.diamond_rounded,
                      const Color(0xFF00E5FF),
                    ),
                    const SizedBox(width: 6),
                    _buildTierFilterChip(
                      'ORO',
                      'Oro (${_countByTier('ORO')})',
                      Icons.military_tech_rounded,
                      const Color(0xFFFFB800),
                    ),
                    const SizedBox(width: 6),
                    _buildTierFilterChip(
                      'PLATA',
                      'Plata (${_countByTier('PLATA')})',
                      Icons.verified_rounded,
                      const Color(0xFFA8B2C1),
                    ),
                    const SizedBox(width: 6),
                    _buildTierFilterChip(
                      'BRONCE',
                      'Bronce (${_countByTier('BRONCE')})',
                      Icons.shield_outlined,
                      const Color(0xFFCD7F32),
                    ),
                    const SizedBox(width: 6),
                    _buildTierFilterChip(
                      'OBSERVACION',
                      'Observación (${_countByTier('OBSERVACION')})',
                      Icons.warning_amber_rounded,
                      const Color(0xFFEF4444),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Lista de Clientes con Rango
        Expanded(
          child: clients.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline_rounded, size: 48, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        _reputationSearchQuery.isNotEmpty
                            ? "No hay clientes que coincidan con la búsqueda"
                            : "No se encontraron clientes con este filtro",
                        style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13.5),
                      ),
                      if (_reputationSearchQuery.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () {
                            _reputationSearchCtrl.clear();
                            setState(() => _reputationSearchQuery = '');
                          },
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          label: const Text("Limpiar búsqueda"),
                        ),
                      ],
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  physics: const BouncingScrollPhysics(),
                  itemCount: clients.length,
                  itemBuilder: (ctx, i) => _buildReputationClientCard(clients[i], isDark, cardColor, textColor),
                ),
        ),
      ],
    );
  }

  Widget _buildTierFilterChip(String key, String label, IconData icon, Color color) {
    final isSelected = _selectedTierFilter == key;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 14,
        color: isSelected ? Colors.white : color,
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          color: isSelected ? Colors.white : color,
        ),
      ),
      selected: isSelected,
      selectedColor: color,
      backgroundColor: color.withValues(alpha: 0.12),
      onSelected: (val) {
        if (val) setState(() => _selectedTierFilter = key);
      },
    );
  }

  Widget _buildReputationClientCard(
    ClientModel client,
    bool isDark,
    Color cardColor,
    Color textColor,
  ) {
    final tier = client.tier;
    final almostAtGoal = _almostAtGoalMap[client.id];
    final clientPendingRewards = _pendingRewards.where((rw) => rw.clienteId == client.id).toList();
    final clientClaimable = _clientsClaimableMap[client.id];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: Color(tier.colorHex).withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ClientDetailScreen(client: client)),
          ).then((_) => _loadData());
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Color(tier.colorHex).withValues(alpha: 0.15),
                    child: Text(
                      client.fullName.isNotEmpty ? client.fullName[0].toUpperCase() : "?",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(tier.colorHex),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                client.fullName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: textColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: Color(tier.colorHex).withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(tier.icon, size: 12, color: Color(tier.colorHex)),
                                  const SizedBox(width: 4),
                                  Text(
                                    tier.badgeText,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(tier.colorHex),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 2,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.phone_rounded, size: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  client.phone.isNotEmpty ? client.phone : "Sin teléfono",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              "Score: ${client.scoreReputacion}/1000",
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.grey[300] : Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Indicador de Premios Disponibles, Premio en Revisión o Casi en la Meta
              if (clientClaimable != null && clientClaimable.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.6), width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.workspace_premium_rounded, size: 16, color: Colors.amber[800]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "${clientClaimable.length} premio(s) listo(s) (${client.puntosActuales} pts)",
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.amber[300] : Colors.amber[900],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () async {
                          await showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (ctx) => RewardReviewModal(
                              goal: clientClaimable.first,
                              client: client,
                              onActionCompleted: _loadData,
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber[700],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.touch_app_rounded, size: 11, color: Colors.white),
                              SizedBox(width: 3),
                              Text(
                                "Reclamar",
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (clientPendingRewards.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.45)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.card_giftcard_rounded, size: 15, color: Colors.amber[800]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "Premio listo para revisar: ${clientPendingRewards.first.metaTitulo}",
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.amber[300] : Colors.amber[900],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () async {
                          await showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (ctx) => RewardReviewModal(
                              reward: clientPendingRewards.first,
                              client: client,
                              onActionCompleted: _loadData,
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber[700],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.rate_review_rounded, size: 11, color: Colors.white),
                              SizedBox(width: 3),
                              Text(
                                "Revisar",
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (almostAtGoal != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.track_changes_rounded, size: 14, color: Colors.amber[800]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "A ${almostAtGoal['puntos_faltantes']} pts de: ${(almostAtGoal['goal'] as RewardGoalModel).nombre}",
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.amber[300] : Colors.amber[900],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () {
                          final auth = Provider.of<AuthProvider>(context, listen: false);
                          LoyaltyWhatsAppService.sendAlmostAtGoalNotification(
                            context: context,
                            phone: client.phone,
                            clientName: client.fullName.split(' ').first,
                            businessName: auth.businessName,
                            goal: almostAtGoal['goal'] as RewardGoalModel,
                            puntosFaltantes: almostAtGoal['puntos_faltantes'] as int,
                            puntosActuales: client.puntosActuales,
                          );
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF25D366),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.send_rounded, size: 10, color: Colors.white),
                              SizedBox(width: 3),
                              Text(
                                "Impulso",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 10),
              Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
              const SizedBox(height: 8),

              // Fila de Indicadores: Puntos, Racha y Límite sugerido (Wrap anti-desbordamiento 360dp)
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.stars_rounded, size: 15, color: Colors.amber[700]),
                      const SizedBox(width: 4),
                      Text(
                        "${client.puntosActuales} pts",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12.5,
                          color: Colors.amber[800],
                        ),
                      ),
                      if (client.rachaPagosPuntuales > 0) ...[
                        const SizedBox(width: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_fire_department_rounded, size: 13, color: Colors.orange),
                            const SizedBox(width: 2),
                            Text(
                              "${client.rachaPagosPuntuales} a tiempo",
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Límite Sug.: ",
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                      Text(
                        AppCurrency.format(tier.limiteCreditoSugerido),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: tier.limiteCreditoSugerido > 0 ? Colors.green[600] : Colors.red,
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () => ClientLoyaltyHistoryModal.show(
                          context,
                          client: client,
                          onPointsChanged: _loadData,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.history_rounded, size: 15, color: textColor),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // TAB 2: RECOMPENSAS Y METAS
  // =========================================================================
  Widget _buildRewardsAndGoalsTab(bool isDark, Color cardColor, Color textColor) {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- BARRA DE ACCIONES EJECUTIVAS: REGLAS Y CARTILLA ---
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openRulesConfig,
                    icon: const Icon(Icons.tune_rounded, size: 16),
                    label: const Text("Reglas de Puntos", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.amber[800],
                      side: BorderSide(color: Colors.amber.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openLoyaltyGuidePreview,
                    icon: const Icon(Icons.menu_book_rounded, size: 16),
                    label: const Text("Cartilla WhatsApp", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.grey[200] : Colors.blueGrey[800],
                      side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade400),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // --- SECCIÓN 1: PREMIOS DISPONIBLES PARA RECLAMAR ---
            if (_clientsWithClaimableRewards.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.workspace_premium_rounded, color: Colors.amber[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Premios Disponibles para Reclamar",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber[800],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "${_clientsWithClaimableRewards.length}",
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ..._clientsWithClaimableRewards.map((item) => _buildClaimableClientCard(item, isDark, cardColor, textColor)),
              const SizedBox(height: 20),
            ],

            // --- SECCIÓN 2: RECOMPENSAS PENDIENTES DE REVISIÓN ---
            Row(
              children: [
                Icon(Icons.pending_actions_rounded, color: Colors.orange[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Premios Desbloqueados por Revisar",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_pendingRewards.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "${_pendingRewards.length}",
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),

            if (_pendingRewards.isEmpty && _clientsWithClaimableRewards.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1B2A1E) : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.green, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "¡Todo al día! No hay recompensas pendientes de confirmación.",
                        style: TextStyle(
                          fontSize: 12.5,
                          color: isDark ? Colors.green[200] : Colors.green[900],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._pendingRewards.map((rw) => _buildPendingRewardCard(rw, isDark, cardColor, textColor)),

            const SizedBox(height: 22),

            // --- SECCIÓN 2: CATÁLOGO DE METAS DEL NEGOCIO ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.emoji_events_rounded, color: Colors.amber[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Catálogo de Metas",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    final auth = Provider.of<AuthProvider>(context, listen: false);
                    final res = await MetaRewardEditorModal.show(
                      context,
                      negocioId: auth.activeBusinessId ?? 1,
                    );
                    if (res != null) _loadData();
                  },
                  icon: const Icon(Icons.add, size: 15),
                  label: const Text("Nueva Meta", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    elevation: 0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (_goals.isEmpty)
              Text(
                "No hay metas configuradas. Toca '+ Nueva Meta' para agregar una.",
                style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13),
              )
            else
              ..._goals.map((g) => _buildGoalCard(g, isDark, cardColor, textColor)),

            const SizedBox(height: 22),

            // --- SECCIÓN 3: HISTORIAL DE CANJES ---
            if (_pastRewards.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.history_rounded, color: isDark ? Colors.grey[400] : Colors.grey[700], size: 19),
                  const SizedBox(width: 8),
                  Text(
                    "Historial Reciente de Premios",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ..._pastRewards.map((rw) => _buildPastRewardCard(rw, isDark, cardColor, textColor)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildClaimableClientCard(
    Map<String, dynamic> item,
    bool isDark,
    Color cardColor,
    Color textColor,
  ) {
    final client = item['client'] as ClientModel;
    final goals = (item['claimable_goals'] as List).cast<RewardGoalModel>();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.6), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Color(client.tier.colorHex).withValues(alpha: 0.2),
                child: Text(
                  client.fullName.isNotEmpty ? client.fullName[0].toUpperCase() : "?",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(client.tier.colorHex),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      client.fullName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      "${client.puntosActuales} pts disponibles",
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.amber[300] : Colors.amber[800],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.chat_rounded, size: 18),
                color: Colors.green[700],
                tooltip: "Avisar premios por WhatsApp",
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () async {
                  final auth = Provider.of<AuthProvider>(context, listen: false);
                  final msg = LoyaltyWhatsAppService.buildAvailableRewardsMessage(
                    clientName: client.fullName,
                    businessName: auth.activeBusinessName,
                    puntosSaldo: client.puntosActuales,
                    nivelReputacion: client.tier.key,
                    claimableGoals: goals,
                  );
                  if (!context.mounted) return;
                  await LoyaltyWhatsAppService.showEditableWhatsAppPreviewModal(
                    context: context,
                    title: "Avisar Premios Disponibles",
                    initialMessage: msg,
                    phone: client.phone,
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: goals.map((g) {
              return ActionChip(
                avatar: Icon(Icons.card_giftcard_rounded, size: 14, color: Colors.amber[800]),
                label: Text(
                  "${g.nombre} (${g.puntosRequeridos} pts)",
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                backgroundColor: isDark ? const Color(0xFF2E2419) : Colors.amber.shade50,
                side: BorderSide(color: Colors.amber.withValues(alpha: 0.4)),
                onPressed: () async {
                  await showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => RewardReviewModal(
                      goal: g,
                      client: client,
                      onActionCompleted: _loadData,
                    ),
                  );
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingRewardCard(
    ClientRewardModel rw,
    bool isDark,
    Color cardColor,
    Color textColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  rw.clienteNombre ?? 'Cliente',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "POR REVISAR",
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.card_giftcard_rounded, size: 15, color: Colors.amber[700]),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  rw.metaTitulo,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.amber[300] : Colors.amber[900],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Puntos reservados: ${rw.puntosConsumidos} pts • Desbloqueado: ${rw.fechaDesbloqueo.split('T').first}",
            style: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton.icon(
              onPressed: () async {
                final client = _allClients.firstWhere(
                  (c) => c.id == rw.clienteId,
                  orElse: () => ClientModel(
                    id: rw.clienteId,
                    negocioId: rw.negocioId,
                    creadoPorUsuarioId: 0,
                    fullName: rw.clienteNombre ?? 'Cliente',
                    phone: rw.clienteTelefono ?? '',
                    registeredDate: '',
                  ),
                );
                await RewardReviewModal.show(
                  context: context,
                  reward: rw,
                  client: client,
                  onActionCompleted: _loadData,
                );
              },
              icon: const Icon(Icons.rate_review_rounded, size: 16),
              label: const Text(
                "Revisar y Confirmar Premio",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(
    RewardGoalModel goal,
    bool isDark,
    Color cardColor,
    Color textColor,
  ) {
    IconData icon;
    Color iconColor;
    String benefitLabel;

    switch (goal.tipoBeneficio) {
      case 'DESCUENTO_MONTO':
        icon = Icons.attach_money_rounded;
        iconColor = Colors.green;
        benefitLabel = "Descuento de ${AppCurrency.format(goal.valorBeneficio)}";
        break;
      case 'DESCUENTO_PORCENTAJE':
        icon = Icons.percent_rounded;
        iconColor = Colors.blue;
        benefitLabel = "${goal.valorBeneficio.toStringAsFixed(0)}% de Descuento";
        break;
      case 'PRODUCTO_REGALO':
        icon = Icons.card_giftcard_rounded;
        iconColor = Colors.purple;
        benefitLabel = goal.valorBeneficio > 0
            ? "Producto de Regalo (${AppCurrency.format(goal.valorBeneficio)})"
            : "Producto de Regalo";
        break;
      default:
        icon = Icons.credit_score_rounded;
        iconColor = Colors.amber;
        benefitLabel = goal.valorBeneficio > 0
            ? "Crédito Extra de ${AppCurrency.format(goal.valorBeneficio)}"
            : "Crédito Preferencial";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        goal.titulo,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "${goal.puntosRequeridos} pts",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.amber[800],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  benefitLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
                if (goal.descripcion != null && goal.descripcion!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    goal.descripcion!,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            tooltip: "Editar meta",
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () async {
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final res = await MetaRewardEditorModal.show(
                context,
                negocioId: auth.activeBusinessId ?? 1,
                goal: goal,
              );
              if (res != null) _loadData();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPastRewardCard(
    ClientRewardModel rw,
    bool isDark,
    Color cardColor,
    Color textColor,
  ) {
    final bool isRedeemed = rw.estado == 'CANJEADA';
    final Color badgeColor = isRedeemed ? Colors.green : Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isRedeemed ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
            color: badgeColor,
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${rw.clienteNombre ?? 'Cliente'} • ${rw.metaTitulo}",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  "Estado: ${rw.estado} • ${rw.fechaCanje != null ? 'Canjeado: ${rw.fechaCanje!.split('T').first}' : rw.fechaDesbloqueo.split('T').first}",
                  style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              rw.estado,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: badgeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 3: AVISOS DE OFERTAS, AUDIENCIA Y DIFUSOR WHATSAPP
  // =========================================================================
  Widget _buildOffersBroadcasterTab(bool isDark, Color cardColor, Color textColor) {
    final products = _filteredCatalogProducts;
    final audienceClients = _finalAudienceClients;
    final bool canBroadcast = _selectedProductIds.isNotEmpty && audienceClients.isNotEmpty;

    String broadcastBtnText;
    if (_selectedProductIds.isEmpty) {
      broadcastBtnText = "Selecciona productos para difundir";
    } else if (audienceClients.isEmpty) {
      broadcastBtnText = "Sin clientes en este segmento";
    } else {
      broadcastBtnText = "Difundir Ofertas (${_selectedProductIds.length} prod. • ${audienceClients.length} clientes)";
    }

    return Column(
      children: [
        // Banner explicativo descartable
        if (_showTab3Banner)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.campaign_rounded, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Selecciona ofertas y envíalas por WhatsApp a tus clientes con formato comercial.",
                    style: TextStyle(fontSize: 11.5, color: isDark ? Colors.blue[200] : Colors.blue[900]),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  onPressed: () => setState(() => _showTab3Banner = false),
                ),
              ],
            ),
          ),

        // Filtro y Acciones Rápidas de Productos
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "1. Selecciona los Productos",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: textColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (_selectedProductIds.length == products.length) {
                          _selectedProductIds.clear();
                        } else {
                          _selectedProductIds.addAll(products.map((p) => p['id'] as int));
                        }
                      });
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: Text(
                      _selectedProductIds.length == products.length && products.isNotEmpty
                          ? "Limpiar selección"
                          : "Seleccionar todos (${products.length})",
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.amber[800]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Chips de Modo de Producto (Iconos vectoriales limpios sin emojis)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    ChoiceChip(
                      avatar: const Icon(Icons.local_fire_department_rounded, size: 14, color: Colors.orange),
                      label: Text("Ofertas Activas ($_ofertasCount)"),
                      labelStyle: TextStyle(
                        fontSize: 11.5,
                        fontWeight: _productFilterMode == 'ofertas' ? FontWeight.bold : FontWeight.w500,
                      ),
                      selected: _productFilterMode == 'ofertas',
                      selectedColor: Colors.orange.withValues(alpha: 0.2),
                      onSelected: (v) => setState(() => _productFilterMode = 'ofertas'),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      avatar: const Icon(Icons.inventory_2_outlined, size: 14, color: Colors.purple),
                      label: Text("Baja Rotación ($_bajaRotacionCount)"),
                      labelStyle: TextStyle(
                        fontSize: 11.5,
                        fontWeight: _productFilterMode == 'baja_rotacion' ? FontWeight.bold : FontWeight.w500,
                      ),
                      selected: _productFilterMode == 'baja_rotacion',
                      selectedColor: Colors.purple.withValues(alpha: 0.2),
                      onSelected: (v) => setState(() => _productFilterMode = 'baja_rotacion'),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      avatar: const Icon(Icons.list_alt_rounded, size: 14, color: Colors.grey),
                      label: Text("Todos (${_catalogProducts.length})"),
                      labelStyle: TextStyle(
                        fontSize: 11.5,
                        fontWeight: _productFilterMode == 'todos' ? FontWeight.bold : FontWeight.w500,
                      ),
                      selected: _productFilterMode == 'todos',
                      selectedColor: Colors.grey.withValues(alpha: 0.2),
                      onSelected: (v) => setState(() => _productFilterMode = 'todos'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Buscador de Productos
              TextField(
                controller: _productSearchCtrl,
                onChanged: (val) => setState(() => _productSearchQuery = val),
                style: TextStyle(color: textColor, fontSize: 13),
                decoration: InputDecoration(
                  hintText: "Buscar producto por nombre o descripción...",
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  suffixIcon: _productSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          onPressed: () {
                            _productSearchCtrl.clear();
                            setState(() => _productSearchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
        ),

        // Lista de Productos Expandida (Ocupa todo el espacio vertical disponible)
        Expanded(
          child: products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 40, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                      const SizedBox(height: 8),
                      Text(
                        _productSearchQuery.isNotEmpty
                            ? "No hay productos que coincidan con la búsqueda"
                            : "No hay productos con este filtro",
                        style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                      if (_productSearchQuery.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: () {
                            _productSearchCtrl.clear();
                            setState(() => _productSearchQuery = '');
                          },
                          child: const Text("Limpiar búsqueda"),
                        ),
                      ],
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  physics: const BouncingScrollPhysics(),
                  itemCount: products.length,
                  itemBuilder: (ctx, i) {
                    final p = products[i];
                    final id = p['id'] as int;
                    final isSelected = _selectedProductIds.contains(id);
                    final regularPrice = p['precioRegular'] as double;
                    final effectivePrice = p['precioEfectivo'] as double;
                    final hasOffer = p['hasOffer'] as bool;
                    final savings = (regularPrice - effectivePrice).clamp(0.0, double.infinity);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      elevation: 0,
                      color: cardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected
                              ? Colors.amber[700]!
                              : (isDark ? Colors.white10 : Colors.grey.shade200),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: CheckboxListTile(
                        dense: true,
                        value: isSelected,
                        activeColor: Colors.amber[700],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedProductIds.add(id);
                            } else {
                              _selectedProductIds.remove(id);
                            }
                          });
                        },
                        title: Text(
                          p['nombre'] as String,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Wrap(
                          spacing: 6,
                          runSpacing: 2,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              AppCurrency.format(effectivePrice),
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                                color: hasOffer ? Colors.green[600] : textColor,
                              ),
                            ),
                            if (hasOffer) ...[
                              Text(
                                AppCurrency.format(regularPrice),
                                style: const TextStyle(
                                  fontSize: 11,
                                  decoration: TextDecoration.lineThrough,
                                  color: Colors.grey,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  "Ahorro ${AppCurrency.format(savings)}",
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                            ],
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: (p['isLowStock'] as bool)
                                    ? Colors.red.withValues(alpha: 0.15)
                                    : (isDark ? Colors.white10 : Colors.grey[200]),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "Stock: ${p['stock']}",
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: (p['isLowStock'] as bool)
                                      ? Colors.red
                                      : (isDark ? Colors.grey[400] : Colors.grey[700]),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Dock Inferior Colapsable de Audiencia y Envío
        _buildAudienceDock(isDark, cardColor, textColor, canBroadcast, broadcastBtnText),
      ],
    );
  }

  Widget _buildAudienceDock(
    bool isDark,
    Color cardColor,
    Color textColor,
    bool canBroadcast,
    String broadcastBtnText,
  ) {
    final audienceClients = _finalAudienceClients;
    final totalSegment = _segmentClients;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
        border: Border(
          top: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade200),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Barra de Resumen / Título del Dock (Tocar para expandir/colapsar)
          InkWell(
            onTap: () => setState(() => _isAudienceDockExpanded = !_isAudienceDockExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.groups_rounded,
                    size: 18,
                    color: Colors.blue[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Audiencia: ${_audienceFilterTier == 'TODOS' ? 'Todos' : ReputationTier.fromKey(_audienceFilterTier).badgeText} (${audienceClients.length} clientes)",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "${_selectedProductIds.length} prod.",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber[800],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _isAudienceDockExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),

          // Contenido Expandido del Dock
          if (_isAudienceDockExpanded) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Chips de Niveles de Audiencia (con iconos vectoriales y conteo)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildAudienceChip('TODOS', 'Todos (${_allClients.length})', Icons.people_outline_rounded),
                        const SizedBox(width: 6),
                        _buildAudienceChip('DIAMANTE_VIP', 'Diamante VIP (${_countByTier('DIAMANTE_VIP')})', Icons.diamond_rounded),
                        const SizedBox(width: 6),
                        _buildAudienceChip('ORO', 'Oro (${_countByTier('ORO')})', Icons.military_tech_rounded),
                        const SizedBox(width: 6),
                        _buildAudienceChip('PLATA', 'Plata (${_countByTier('PLATA')})', Icons.verified_rounded),
                        const SizedBox(width: 6),
                        _buildAudienceChip('BRONCE', 'Bronce (${_countByTier('BRONCE')})', Icons.shield_outlined),
                        const SizedBox(width: 6),
                        _buildAudienceChip('OBSERVACION', 'Observación (${_countByTier('OBSERVACION')})', Icons.warning_amber_rounded),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Lista seleccionable de clientes de la audiencia
                  if (totalSegment.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        "No hay clientes registrados en este segmento.",
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 140),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: totalSegment.length,
                        itemBuilder: (ctx, idx) {
                          final c = totalSegment[idx];
                          final isIncluded = !_deselectedAudienceClientIds.contains(c.id);

                          return CheckboxListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            visualDensity: VisualDensity.compact,
                            value: isIncluded,
                            activeColor: const Color(0xFF25D366),
                            title: Text(
                              c.fullName,
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textColor),
                            ),
                            subtitle: Text(
                              "${c.phone} • ${c.tier.badgeText} (${c.puntosActuales} pts)",
                              style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                            ),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  _deselectedAudienceClientIds.remove(c.id);
                                } else {
                                  _deselectedAudienceClientIds.add(c.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],

          // Botón de Envío Difusión WhatsApp
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: canBroadcast
                    ? () {
                        final auth = Provider.of<AuthProvider>(context, listen: false);
                        final selectedProductsList = _catalogProducts
                            .where((p) => _selectedProductIds.contains(p['id']))
                            .toList();

                        PromotionBroadcastModal.show(
                          context,
                          businessName: auth.businessName,
                          selectedProducts: selectedProductsList,
                          targetClients: audienceClients,
                        );
                      }
                    : null,
                icon: const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  broadcastBtnText,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  disabledBackgroundColor: isDark ? Colors.white10 : Colors.grey.shade300,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: isDark ? Colors.white38 : Colors.grey.shade500,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudienceChip(String key, String label, IconData icon) {
    final isSelected = _audienceFilterTier == key;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 13,
        color: isSelected ? Colors.white : Colors.blue[600],
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87),
        ),
      ),
      selected: isSelected,
      selectedColor: Colors.blue[600],
      backgroundColor: Colors.blue.withValues(alpha: 0.12),
      onSelected: (val) {
        if (val) {
          setState(() {
            _audienceFilterTier = key;
            _deselectedAudienceClientIds.clear();
          });
        }
      },
    );
  }
}
