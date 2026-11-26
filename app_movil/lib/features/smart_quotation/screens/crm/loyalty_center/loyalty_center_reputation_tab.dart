part of '../loyalty_center_screen.dart';

mixin _LoyaltyCenterReputationTabMixin on _LoyaltyCenterStateBase {
  // =========================================================================
  // TAB 1: REPUTACIÓN Y NIVELES
  // =========================================================================
  @override
  Widget _buildReputationTab(bool isDark, Color cardColor, Color textColor) {
    final clients = _filteredReputationClients;

    return Column(
      children: [
        // Buscador y Chips de Niveles
        Container(
          key: _tourKeys.pendingClientsKey,
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
                    if (_clientsWithClaimableRewards.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _buildTierFilterChip(
                        'CON_PREMIO_LISTO',
                        'Con Premio Listo (${_clientsWithClaimableRewards.length})',
                        Icons.card_giftcard_rounded,
                        Colors.amber[800]!,
                      ),
                    ],
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

}
