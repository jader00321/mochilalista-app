part of '../loyalty_center_screen.dart';

mixin _LoyaltyCenterMetricsAndActionsMixin on _LoyaltyCenterStateBase {
  @override
  void _openRulesConfig() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final negocioId = auth.activeBusinessId ?? 1;
    LoyaltyRulesConfigModal.show(
      context,
      negocioId: negocioId,
      onRulesSaved: _loadData,
    );
  }

  @override
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
        rules: rules,
        activeGoals: _goals.where((g) => g.activo).toList(),
        businessName: auth.activeBusinessName,
        availableClients: _allClients,
      );
    }
  }

  // --- FILTROS TAB 1 (Reputación) ---
  @override
  List<ClientModel> get _filteredReputationClients {
    return _allClients.where((c) {
      if (_selectedTierFilter == 'CON_PREMIO_LISTO') {
        if (!_clientsClaimableMap.containsKey(c.id) ||
            (_clientsClaimableMap[c.id]?.isEmpty ?? true)) {
          return false;
        }
      } else if (_selectedTierFilter == 'CASI_EN_LA_META') {
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

  @override
  int _countByTier(String tierKey) {
    return _allClients.where((c) => c.tier.key == tierKey).length;
  }

  // --- FILTROS TAB 3 (Productos y Difusión) ---
  @override
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

  @override
  int get _ofertasCount => _catalogProducts.where((p) => p['hasOffer'] as bool).length;
  @override
  int get _bajaRotacionCount => _catalogProducts.where((p) => p['isLowStock'] as bool).length;

  @override
  List<ClientModel> get _segmentClients {
    if (_audienceFilterTier == 'TODOS') return _allClients;
    return _allClients.where((c) => c.tier.key == _audienceFilterTier).toList();
  }

  @override
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

  @override
  void _onScrollNotification(UserScrollNotification notification) {
    if (notification.direction == ScrollDirection.reverse && _isHeaderVisible) {
      setState(() => _isHeaderVisible = false);
    } else if (notification.direction == ScrollDirection.forward && !_isHeaderVisible) {
      setState(() => _isHeaderVisible = true);
    }
  }


  @override
  Widget _buildExecutiveHeader(bool isDark, Color cardColor, Color textColor) {
    final int premiosListosTotal = _clientsWithClaimableRewards.fold<int>(
      0,
      (sum, item) => sum + ((item['claimable_goals'] as List?)?.length ?? 0),
    );
    final bool hasPremiosListos = premiosListosTotal > 0 || _pendingRewards.isNotEmpty;

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
              "Premios Listos",
              premiosListosTotal > 0
                  ? "$premiosListosTotal disponible${premiosListosTotal > 1 ? 's' : ''}"
                  : (_pendingRewards.isNotEmpty
                      ? "${_pendingRewards.length} pendientes"
                      : "0 pendientes"),
              Icons.notifications_active_rounded,
              hasPremiosListos ? Colors.green[700]! : Colors.grey,
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

}
