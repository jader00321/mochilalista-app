part of '../audit_trail_screen.dart';

mixin _AuditTrailSummaryAndHelpMixin on _AuditTrailScreenBase {
  Widget _buildSummaryCard(bool isDark) {
    final double marginPct = _currentPrice > 0
        ? ((_currentPrice - _currentCost) / _currentPrice) * 100
        : 0.0;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1B4B), const Color(0xFF312E81)]
              : [const Color(0xFF4F46E5), const Color(0xFF3730A3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayedTitle.isNotEmpty
                          ? _displayedTitle
                          : widget.productName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (_activeIsShared && _activeFactor > 1) ...[
                      const SizedBox(height: 3),
                      Text(
                        "Stock Pool: $_currentStock und. base ($_variantEquivString)",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.cyanAccent,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: "Información de Trazabilidad",
                onPressed: _showTraceabilityHelpModal,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.help_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          if (_presentations.length > 1) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 28,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _presentations.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, idx) {
                  final p = _presentations[idx];
                  final pId = (p['id'] as num).toInt();
                  final pLabel =
                      (p['nombre_especifico']?.toString().trim().isNotEmpty ==
                          true)
                      ? p['nombre_especifico'].toString().trim()
                      : 'Unidad';
                  final isSelected = pId == _activePresentationId;
                  return InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      if (!isSelected) {
                        _loadAuditTrail(pId);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.white24,
                          width: 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            (p['usa_stock_compartido'] == 1 || pId == -1)
                                ? Icons.hub_outlined
                                : Icons.inventory_2_outlined,
                            size: 11,
                            color: isSelected
                                ? const Color(0xFF312E81)
                                : Colors.white.withValues(alpha: 0.9),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            pLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isSelected
                                  ? const Color(0xFF312E81)
                                  : Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildHeaderMetric(
                    label: "Stock Actual",
                    value: (_activeIsShared && _activeFactor > 1)
                        ? "$_currentStock und. base\n($_variantEquivString)"
                        : "$_currentStock und",
                    color: Colors.white,
                  ),
                ),
                Container(width: 1, height: 28, color: Colors.white24),
                Expanded(
                  child: _buildHeaderMetric(
                    label: "Costo Est.",
                    value: AppCurrency.format(_currentCost),
                    color: Colors.amberAccent,
                  ),
                ),
                Container(width: 1, height: 28, color: Colors.white24),
                Expanded(
                  child: _buildHeaderMetric(
                    label: "Precio Venta",
                    value: AppCurrency.format(_currentPrice),
                    color: Colors.lightGreenAccent,
                  ),
                ),
                Container(width: 1, height: 28, color: Colors.white24),
                Expanded(
                  child: _buildHeaderMetric(
                    label: "Margen",
                    value: "${marginPct.toStringAsFixed(1)}%",
                    color: Colors.cyanAccent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildFlowPill(
                  icon: Icons.arrow_downward,
                  accentColor: Colors.greenAccent,
                  bgColor: Colors.green.withValues(alpha: 0.18),
                  borderColor: Colors.greenAccent.withValues(alpha: 0.25),
                  text: "Entradas: +$_totalEntradas und. base",
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFlowPill(
                  icon: Icons.arrow_upward,
                  accentColor: Colors.redAccent,
                  bgColor: Colors.red.withValues(alpha: 0.18),
                  borderColor: Colors.redAccent.withValues(alpha: 0.25),
                  text: "Salidas: -$_totalSalidas und. base",
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.outlined_flag_rounded,
                      size: 14,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Stock Inicial Base: $_stockInicialBase und. base",
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.calculate_outlined,
                      size: 14,
                      color: Colors.cyanAccent,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Saldo Auditoría: $_stockInicialBase + $_totalEntradas - $_totalSalidas = $_currentStock und. base${_activeIsShared && _activeFactor > 1 ? ' ($_variantEquivString)' : ''}",
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.cyanAccent,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlowPill({
    required IconData icon,
    required Color accentColor,
    required Color bgColor,
    required Color borderColor,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 13, color: accentColor),
          const SizedBox(width: 5),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderMetric({
    required String label,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: const TextStyle(fontSize: 10, color: Colors.white70),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTraceabilityHelpModal() {
    InteractiveSheetWrapper.show(
      context: context,
      builder: (ctx) => InteractiveSheetWrapper(
        title: "Trazabilidad de Stock (Kardex)",
        icon: Icons.timeline_rounded,
        iconColor: Colors.purpleAccent,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "La ventana de Trazabilidad es tu auditoría digital en tiempo real: registra cada evento que afecta al producto a lo largo del tiempo.",
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              _buildHelpRow(
                icon: Icons.shopping_cart_checkout,
                color: Colors.redAccent,
                title: "Ventas en Caja",
                description:
                    "Disminuyen el inventario físico y registran la salida de existencias.",
              ),
              _buildHelpRow(
                icon: Icons.local_shipping,
                color: Colors.green,
                title: "Ingreso por Factura",
                description:
                    "Incrementan el stock tras procesar compras con el escáner de facturas.",
              ),
              _buildHelpRow(
                icon: Icons.tune,
                color: Colors.blueAccent,
                title: "Ajustes Manuales",
                description:
                    "Correcciones directas por inventario físico, mermas o inventario inicial.",
              ),
              _buildHelpRow(
                icon: Icons.price_change,
                color: Colors.purpleAccent,
                title: "Cambios de Precio y Costo",
                description:
                    "Histórico de actualizaciones de costos de proveedor y precios de venta al público.",
              ),
              _buildHelpRow(
                icon: Icons.local_offer_rounded,
                color: const Color(0xFFE11D48),
                title: "Descuentos y Promociones",
                description:
                    "Histórico de ofertas activadas, cambios de porcentaje y retorno a precio normal.",
              ),
              _buildHelpRow(
                icon: Icons.label,
                color: Colors.orangeAccent,
                title: "Ediciones de Ficha",
                description:
                    "Cambios en marcas, categorías, nombres o estado de visibilidad del producto.",
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHelpRow({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
