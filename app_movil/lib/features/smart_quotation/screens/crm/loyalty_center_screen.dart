import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/services/client_service.dart';
import 'package:app_movil/features/smart_quotation/services/loyalty_whatsapp_service.dart';
import 'package:app_movil/features/smart_quotation/screens/crm/client_detail_screen.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/reward_review_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/meta_reward_editor_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/client_loyalty_history_modal.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';

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

  bool _isLoading = true;
  List<ClientModel> _allClients = [];
  List<ClientRewardModel> _pendingRewards = [];
  List<ClientRewardModel> _pastRewards = [];
  List<RewardGoalModel> _goals = [];
  List<Map<String, dynamic>> _catalogProducts = [];

  // Tab 1: Filtros de Reputación
  String _reputationSearchQuery = '';
  String _selectedTierFilter = 'TODOS';

  // Tab 3: Avisos y Ofertas
  String _productSearchQuery = '';
  String _productFilterMode = 'ofertas'; // 'ofertas', 'baja_rotacion', 'todos'
  final Set<int> _selectedProductIds = {};
  String _audienceFilterTier = 'TODOS';
  ClientModel? _selectedAudienceClient;

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final negocioId = auth.activeBusinessId ?? 1;

    try {
      // 1. Cargar o sembrar metas si no existen
      var goals = await _clientService.getRewardGoals(negocioId, activeOnly: false);
      if (goals.isEmpty) {
        await LocalDatabase.seedDefaultMetasRecompensas(
          await _clientService.dbHelper.database,
        );
        goals = await _clientService.getRewardGoals(negocioId, activeOnly: false);
      }

      // 2. Cargar clientes
      final clients = await _clientService.getAllClients(negocioId);

      // 3. Cargar recompensas pendientes
      final pending = await _clientService.getPendingReviewRewards(negocioId);

      // 4. Cargar recompensas pasadas
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

      // 5. Cargar productos con ofertas / stock para Tab 3
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
          _pendingRewards = pending;
          _pastRewards = past;
          _catalogProducts = prods;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- FILTROS TAB 1 (Reputación) ---
  List<ClientModel> get _filteredReputationClients {
    return _allClients.where((c) {
      if (_selectedTierFilter != 'TODOS') {
        if (c.nivelReputacion.toUpperCase() != _selectedTierFilter) {
          return false;
        }
      }
      if (_reputationSearchQuery.isNotEmpty) {
        final q = _reputationSearchQuery.toLowerCase();
        final matchesName = c.fullName.toLowerCase().contains(q);
        final matchesPhone = c.phone.contains(q);
        return matchesName || matchesPhone;
      }
      return true;
    }).toList();
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
        final q = _productSearchQuery.toLowerCase();
        return (p['nombre'] as String).toLowerCase().contains(q);
      }
      return true;
    }).toList();
  }

  List<ClientModel> get _targetAudienceClients {
    if (_audienceFilterTier == 'TODOS') return _allClients;
    return _allClients.where((c) => c.nivelReputacion.toUpperCase() == _audienceFilterTier).toList();
  }

  // Métricas Ejecutivas del Negocio
  int get _totalActivePoints => _allClients.fold(0, (sum, c) => sum + c.puntosActuales);
  int get _vipAndGoldCount => _allClients.where((c) {
        final t = c.nivelReputacion.toUpperCase();
        return t == 'DIAMANTE_VIP' || t == 'ORO';
      }).length;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF13131A) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF1E1E2A) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          "Fidelización y Premios",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
        ),
        centerTitle: false,
        backgroundColor: isDark ? const Color(0xFF1A1A24) : Colors.amber[800],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3.5,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            const Tab(
              icon: Icon(Icons.military_tech_rounded, size: 20),
              text: "Reputación",
            ),
            Tab(
              icon: Badge(
                isLabelVisible: _pendingRewards.isNotEmpty,
                label: Text('${_pendingRewards.length}'),
                backgroundColor: Colors.redAccent,
                child: const Icon(Icons.emoji_events_rounded, size: 20),
              ),
              text: "Recompensas",
            ),
            const Tab(
              icon: Icon(Icons.campaign_rounded, size: 20),
              text: "Avisos y Ofertas",
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Banner Resumen Ejecutivo Superior
                _buildExecutiveHeader(isDark, cardColor, textColor),

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
    );
  }

  // =========================================================================
  // CABECERA EJECUTIVA SUPERIOR
  // =========================================================================
  Widget _buildExecutiveHeader(bool isDark, Color cardColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildExecutiveMetric(
            "Puntos en Circulación",
            "$_totalActivePoints pts",
            Icons.stars_rounded,
            Colors.amber[700]!,
            textColor,
            isDark,
          ),
          Container(height: 30, width: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
          _buildExecutiveMetric(
            "Premios por Revisar",
            "${_pendingRewards.length} pendientes",
            Icons.notifications_active_rounded,
            _pendingRewards.isNotEmpty ? Colors.redAccent : Colors.green,
            textColor,
            isDark,
          ),
          Container(height: 30, width: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
          _buildExecutiveMetric(
            "Clientes VIP / Oro",
            "$_vipAndGoldCount clientes",
            Icons.workspace_premium_rounded,
            Colors.purpleAccent,
            textColor,
            isDark,
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
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: textColor,
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: cardColor,
          child: Column(
            children: [
              TextField(
                onChanged: (val) => setState(() => _reputationSearchQuery = val),
                style: TextStyle(color: textColor, fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Buscar cliente por nombre o teléfono...",
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  filled: true,
                  fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildTierFilterChip('TODOS', 'Todos (${_allClients.length})', Colors.grey),
                    const SizedBox(width: 6),
                    _buildTierFilterChip('DIAMANTE_VIP', '💎 Diamante VIP', const Color(0xFF00B4D8)),
                    const SizedBox(width: 6),
                    _buildTierFilterChip('ORO', '🏆 Oro', const Color(0xFFFFB703)),
                    const SizedBox(width: 6),
                    _buildTierFilterChip('PLATA', '🥈 Plata', const Color(0xFFADB5BD)),
                    const SizedBox(width: 6),
                    _buildTierFilterChip('BRONCE', '🥉 Bronce', const Color(0xFFD4A373)),
                    const SizedBox(width: 6),
                    _buildTierFilterChip('OBSERVACION', '⚠️ Observación', const Color(0xFFEF476F)),
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
                        "No se encontraron clientes con este filtro",
                        style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14),
                      ),
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

  Widget _buildTierFilterChip(String key, String label, Color color) {
    final isSelected = _selectedTierFilter == key;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Color(tier.colorHex).withValues(alpha: 0.15),
                    child: Text(
                      client.fullName.isNotEmpty ? client.fullName[0].toUpperCase() : "?",
                      style: TextStyle(
                        fontSize: 20,
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
                                  fontSize: 16,
                                  color: textColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Color(tier.colorHex).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                tier.badgeText,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(tier.colorHex),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.phone_rounded, size: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              client.phone.isNotEmpty ? client.phone : "Sin teléfono",
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              "Score: ${client.scoreReputacion}/1000",
                              style: TextStyle(
                                fontSize: 12,
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
              const SizedBox(height: 12),
              Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
              const SizedBox(height: 10),

              // Fila de Indicadores: Puntos, Racha y Límite sugerido
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.stars_rounded, size: 16, color: Colors.amber[700]),
                      const SizedBox(width: 4),
                      Text(
                        "${client.puntosActuales} pts",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.amber[800],
                        ),
                      ),
                      if (client.rachaPagosPuntuales > 0) ...[
                        const SizedBox(width: 10),
                        Text(
                          "🔥 ${client.rachaPagosPuntuales} pagos a tiempo",
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ],
                  ),
                  Row(
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
                          child: Icon(Icons.history_rounded, size: 16, color: textColor),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- SECCIÓN 1: RECOMPENSAS PENDIENTES DE REVISIÓN ---
            Row(
              children: [
                Icon(Icons.pending_actions_rounded, color: Colors.orange[700], size: 22),
                const SizedBox(width: 8),
                Text(
                  "Premios Desbloqueados por Revisar",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(width: 8),
                if (_pendingRewards.isNotEmpty)
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
            ),
            const SizedBox(height: 10),

            if (_pendingRewards.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1B2A1E) : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "¡Todo al día! No hay recompensas pendientes de confirmación.",
                        style: TextStyle(
                          fontSize: 13,
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

            const SizedBox(height: 24),

            // --- SECCIÓN 2: CATÁLOGO DE METAS DEL NEGOCIO ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.emoji_events_rounded, color: Colors.amber[700], size: 22),
                    const SizedBox(width: 8),
                    Text(
                      "Catálogo de Metas",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final auth = Provider.of<AuthProvider>(context, listen: false);
                    final res = await MetaRewardEditorModal.show(
                      context,
                      negocioId: auth.activeBusinessId ?? 1,
                    );
                    if (res != null) _loadData();
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text("Nueva Meta", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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

            const SizedBox(height: 24),

            // --- SECCIÓN 3: HISTORIAL DE CANJES ---
            if (_pastRewards.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.history_rounded, color: isDark ? Colors.grey[400] : Colors.grey[700], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "Historial Reciente de Premios",
                    style: TextStyle(
                      fontSize: 16,
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

  Widget _buildPendingRewardCard(
    ClientRewardModel rw,
    bool isDark,
    Color cardColor,
    Color textColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "POR REVISAR",
                  style: TextStyle(
                    fontSize: 10,
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
              Icon(Icons.card_giftcard_rounded, size: 16, color: Colors.amber[700]),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  rw.metaTitulo,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.amber[300] : Colors.amber[900],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Puntos reservados: ${rw.puntosConsumidos} pts • Desbloqueado: ${rw.fechaDesbloqueo.split('T').first}",
            style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 42,
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
              icon: const Icon(Icons.rate_review_rounded, size: 18),
              label: const Text(
                "Revisar y Confirmar Premio",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
        benefitLabel = "Producto o Regalo";
        break;
      default:
        icon = Icons.credit_score_rounded;
        iconColor = Colors.amber;
        benefitLabel = "Crédito Preferencial";
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        goal.titulo,
                        style: TextStyle(
                          fontSize: 14,
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
                if (goal.descripcion != null && goal.descripcion!.isNotEmpty)
                  Text(
                    goal.descripcion!,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
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
            size: 20,
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
                fontSize: 10,
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
  // TAB 3: AVISOS DE OFERTAS Y LIQUIDACIÓN
  // =========================================================================
  Widget _buildOffersBroadcasterTab(bool isDark, Color cardColor, Color textColor) {
    final products = _filteredCatalogProducts;
    final audienceClients = _targetAudienceClients;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner explicativo
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.campaign_rounded, color: Colors.blue, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Selecciona productos en oferta o liquidación y envíalos por WhatsApp con formato comercial.",
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.blue[200] : Colors.blue[900]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Paso 1: Filtro de Productos y Buscador
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "1. Selecciona los Productos",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
              ),
              Text(
                "${_selectedProductIds.length} seleccionados",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber[800]),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              ChoiceChip(
                label: const Text("🔥 Ofertas Activas"),
                selected: _productFilterMode == 'ofertas',
                selectedColor: Colors.orange.withValues(alpha: 0.2),
                onSelected: (v) => setState(() => _productFilterMode = 'ofertas'),
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text("📦 Baja Rotación"),
                selected: _productFilterMode == 'baja_rotacion',
                selectedColor: Colors.purple.withValues(alpha: 0.2),
                onSelected: (v) => setState(() => _productFilterMode = 'baja_rotacion'),
              ),
              const SizedBox(width: 6),
              ChoiceChip(
                label: const Text("Todos"),
                selected: _productFilterMode == 'todos',
                selectedColor: Colors.grey.withValues(alpha: 0.2),
                onSelected: (v) => setState(() => _productFilterMode = 'todos'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          TextField(
            onChanged: (val) => setState(() => _productSearchQuery = val),
            style: TextStyle(color: textColor, fontSize: 13),
            decoration: InputDecoration(
              hintText: "Buscar producto...",
              prefixIcon: const Icon(Icons.search, size: 18),
              filled: true,
              fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 8),

          // Lista de Productos Checkable
          Container(
            height: 190,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
            ),
            child: products.isEmpty
                ? Center(
                    child: Text(
                      "No se encontraron productos",
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                  )
                : ListView.builder(
                    itemCount: products.length,
                    itemBuilder: (ctx, i) {
                      final p = products[i];
                      final id = p['id'] as int;
                      final isSelected = _selectedProductIds.contains(id);

                      return CheckboxListTile(
                        dense: true,
                        value: isSelected,
                        activeColor: Colors.amber[700],
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Row(
                          children: [
                            Text(
                              AppCurrency.format(p['precioEfectivo'] as double),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: (p['hasOffer'] as bool) ? Colors.green : textColor,
                              ),
                            ),
                            if (p['hasOffer'] as bool) ...[
                              const SizedBox(width: 6),
                              Text(
                                AppCurrency.format(p['precioRegular'] as double),
                                style: const TextStyle(
                                  fontSize: 11,
                                  decoration: TextDecoration.lineThrough,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                            const Spacer(),
                            Text(
                              "Stock: ${p['stock']}",
                              style: TextStyle(
                                fontSize: 11,
                                color: (p['isLowStock'] as bool) ? Colors.red : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 18),

          // Paso 2: Audiencia / Cliente Destino
          Text(
            "2. Selecciona la Audiencia",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 8),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildAudienceChip('TODOS', 'Todos (${_allClients.length})'),
                const SizedBox(width: 6),
                _buildAudienceChip('DIAMANTE_VIP', '💎 Diamante VIP'),
                const SizedBox(width: 6),
                _buildAudienceChip('ORO', '🏆 Oro'),
                const SizedBox(width: 6),
                _buildAudienceChip('PLATA', '🥈 Frecuentes (Plata)'),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Selector de Cliente Individual (opcional)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                isExpanded: true,
                value: _selectedAudienceClient?.id,
                hint: Text("Enviar a un cliente específico (opcional)", style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                dropdownColor: isDark ? const Color(0xFF282836) : Colors.white,
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text("Difusión a lista filtrada", style: TextStyle(fontSize: 13)),
                  ),
                  ...audienceClients.map((c) => DropdownMenuItem<int?>(
                        value: c.id,
                        child: Text("${c.fullName} (${c.tier.name})", style: const TextStyle(fontSize: 13)),
                      )),
                ],
                onChanged: (val) {
                  setState(() {
                    if (val == null) {
                      _selectedAudienceClient = null;
                    } else {
                      _selectedAudienceClient = audienceClients.firstWhere((c) => c.id == val);
                    }
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Botón de Enviar Difusión por WhatsApp
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _selectedProductIds.isEmpty
                  ? null
                  : () async {
                      final selectedProductsList = _catalogProducts
                          .where((p) => _selectedProductIds.contains(p['id']))
                          .toList();

                      final target = _selectedAudienceClient ??
                          (audienceClients.isNotEmpty ? audienceClients.first : null);

                      if (target == null) {
                        CustomSnackBar.show(context, message: "No hay clientes en este segmento");
                        return;
                      }

                      final auth = Provider.of<AuthProvider>(context, listen: false);
                      final businessName = auth.businessName;

                      await LoyaltyWhatsAppService.sendPromotionBroadcasterNotification(
                        context: context,
                        phone: target.phone,
                        clientName: target.fullName,
                        businessName: businessName,
                        products: selectedProductsList,
                      );
                    },
              icon: const Icon(Icons.send_rounded, size: 20),
              label: Text(
                _selectedAudienceClient != null
                    ? "Enviar WhatsApp a ${_selectedAudienceClient!.fullName.split(' ').first}"
                    : "Enviar Difusión WhatsApp (${_selectedProductIds.length} prod.)",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudienceChip(String key, String label) {
    final isSelected = _audienceFilterTier == key && _selectedAudienceClient == null;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      selected: isSelected,
      selectedColor: Colors.blue.withValues(alpha: 0.2),
      onSelected: (val) {
        if (val) {
          setState(() {
            _audienceFilterTier = key;
            _selectedAudienceClient = null;
          });
        }
      },
    );
  }
}
