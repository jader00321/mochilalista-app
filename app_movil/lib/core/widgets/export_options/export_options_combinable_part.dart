part of '../export_options_modal.dart';

extension _ExportOptionsCombinableExt on _ExportOptionsModalState {
  Widget _buildCombinableBody() {
    final activePeriodText = widget.activePeriodLabel ?? "Periodo Seleccionado";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("1. ALCANCE TEMPORAL", Icons.date_range_outlined),
        const SizedBox(height: 8),
        _buildPillRow([
          (
            label: "Vista Actual",
            isSelected: _scope == 'current',
            onTap: () {
              _updateState(() => _scope = 'current');
              _refreshLiveCount();
            },
          ),
          (
            label: activePeriodText,
            isSelected: _scope == 'period',
            onTap: () {
              _updateState(() => _scope = 'period');
              _refreshLiveCount();
            },
          ),
          (
            label: "Histórico Total",
            isSelected: _scope == 'full_history',
            onTap: () {
              _updateState(() => _scope = 'full_history');
              _refreshLiveCount();
            },
          ),
        ]),
        const SizedBox(height: 20),
        _buildSectionHeader("2. TIPO DE REGISTRO", Icons.category_outlined),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildChoiceChip(
              label: "Todas las Activas",
              isSelected: _operationType == 'all_active',
              onTap: () {
                _updateState(() => _operationType = 'all_active');
                _refreshLiveCount();
              },
            ),
            _buildChoiceChip(
              label: "Solo Cotizaciones",
              isSelected: _operationType == 'smart_quotation',
              onTap: () {
                _updateState(() => _operationType = 'smart_quotation');
                _refreshLiveCount();
              },
            ),
            _buildChoiceChip(
              label: "Solo Caja Rápida",
              isSelected: _operationType == 'pos_rapido',
              onTap: () {
                _updateState(() => _operationType = 'pos_rapido');
                _refreshLiveCount();
              },
            ),
            _buildChoiceChip(
              label: "Solo Préstamos",
              isSelected: _operationType == 'prestamo_personal',
              onTap: () {
                _updateState(() => _operationType = 'prestamo_personal');
                _refreshLiveCount();
              },
            ),
            _buildChoiceChip(
              label: "Solo Anuladas",
              isSelected: _operationType == 'archived',
              onTap: () {
                _updateState(() => _operationType = 'archived');
                _refreshLiveCount();
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        _buildSectionHeader(
          "ESTADO FINANCIERO",
          Icons.account_balance_wallet_outlined,
        ),
        const SizedBox(height: 8),
        _buildPillRow([
          (
            label: "Todos",
            isSelected: _financialStatus == 'todos',
            onTap: () {
              _updateState(() => _financialStatus = 'todos');
              _refreshLiveCount();
            },
          ),
          (
            label: "Solo Pagados",
            isSelected: _financialStatus == 'pagados',
            onTap: () {
              _updateState(() => _financialStatus = 'pagados');
              _refreshLiveCount();
            },
          ),
          (
            label: "Con Deuda",
            isSelected: _financialStatus == 'con_deuda',
            onTap: () {
              _updateState(() => _financialStatus = 'con_deuda');
              _refreshLiveCount();
            },
          ),
        ]),
        const SizedBox(height: 20),
        _buildSectionHeader(
          "3. ORGANIZACIÓN Y PAGO",
          Icons.account_tree_outlined,
        ),
        const SizedBox(height: 8),
        _buildPillRow([
          (
            label: "Continua",
            isSelected: _grouping == 'continuous',
            onTap: () {
              _updateState(() => _grouping = 'continuous');
              _refreshLiveCount();
            },
          ),
          (
            label: "Agrupada",
            isSelected: _grouping == 'grouped_by_method',
            onTap: () {
              _updateState(() => _grouping = 'grouped_by_method');
              _refreshLiveCount();
            },
          ),
          (
            label: "Por Método",
            isSelected: _grouping == 'specific_method',
            onTap: () {
              _updateState(() => _grouping = 'specific_method');
              _refreshLiveCount();
            },
          ),
        ]),
        if (_grouping == 'specific_method') ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildMethodChip("Efectivo", 'efectivo', Icons.money),
              _buildMethodChip("Yape / Plin", 'yape_plin', Icons.phone_android),
              _buildMethodChip(
                "Transferencia",
                'transferencia',
                Icons.account_balance,
              ),
              _buildMethodChip("Deuda / Crédito", 'credito', Icons.credit_card),
            ],
          ),
        ],
        const SizedBox(height: 20),
        _buildSectionHeader("4. FORMATO DE DESCARGA", Icons.print_outlined),
        const SizedBox(height: 10),
        _buildFormatCardsRow(csvSubtitle: "Hoja de Cálculo", spacing: 14),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.isDark
                ? const Color(0xFF262638)
                : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.blue.withValues(alpha: widget.isDark ? 0.3 : 0.2),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.analytics_outlined,
                color: Colors.blue,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Resumen previo de exportación",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: widget.isDark
                            ? Colors.white
                            : Colors.blue.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isLoadingCount
                          ? "Calculando operaciones coincidentes..."
                          : "${_liveCount ?? 0} operaciones encontradas para descargar",
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.isDark
                            ? Colors.grey[300]
                            : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
