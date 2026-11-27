part of '../client_full_stats_modal.dart';

mixin _ClientFullStatsSectionsMixin on _ClientFullStatsModalBase {
  Widget _buildPerformanceAndGlobalSections(
    List<SaleSummary> sales,
    List<SaleSummary> loans,
  ) {
    final double deudaGlobal = widget.client.totalDebt;

    double deudaPrestamos = 0.0;
    int prestamosActivos = 0;
    for (var sale in _allSales) {
      if (sale.origenVenta == 'prestamo_personal' && !sale.isArchived) {
        double deudaVenta = sale.trueTotal - sale.montoPagado;
        if (deudaVenta > 0) {
          deudaPrestamos += deudaVenta;
          prestamosActivos++;
        }
      }
    }
    double deudaCompras = deudaGlobal - deudaPrestamos;
    if (deudaCompras < 0) deudaCompras = 0;

    final double saldoFavor = widget.client.saldoAFavor;
    final int porEntregar = widget.client.pendingDeliveryCount;

    String ultimaCompra = "N/A";
    if (_allSales.isNotEmpty) {
      final salesOnly = _allSales
          .where((s) => s.origenVenta != 'prestamo_personal')
          .toList();
      if (salesOnly.isNotEmpty) {
        DateTime? dt = DateTime.tryParse(salesOnly.first.date);
        if (dt != null) {
          int diff = DateTime.now().difference(dt).inDays;
          if (diff == 0) {
            ultimaCompra = "Hoy";
          } else if (diff == 1) {
            ultimaCompra = "Ayer";
          } else {
            ultimaCompra = "Hace $diff días";
          }
        }
      }
    }

    final double totalComprado = sales.fold(
      0.0,
      (sum, sale) => sum + sale.total,
    );
    final double totalPagado = sales.fold(
      0.0,
      (sum, sale) => sum + sale.montoPagado,
    );
    final int numCompras = sales.length;
    final double ticketPromedio = numCompras > 0
        ? (totalComprado / numCompras)
        : 0;
    final double tasaCobro = totalComprado > 0
        ? ((totalPagado / totalComprado) * 100).clamp(0.0, 100.0)
        : 100.0;
    final double saldoPendienteFiltro = (totalComprado - totalPagado).clamp(
      0.0,
      double.infinity,
    );
    final String frecuenciaMedia = _calculatePurchaseFrequency(sales);
    final double totalPrestado = loans.fold(
      0.0,
      (sum, loan) => sum + loan.total,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // SECCION 1: Rendimiento Comercial (Dinámico)
        Text(
          "Rendimiento Comercial (Filtro Activo)",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: widget.isDark ? Colors.blue[300] : Colors.blue[800],
          ),
        ),
        const SizedBox(height: 14),

        _buildCommercialBalanceCard(
          totalComprado: totalComprado,
          totalPagado: totalPagado,
          tasaCobro: tasaCobro,
          saldoPendiente: saldoPendienteFiltro,
          isDark: widget.isDark,
        ),

        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 10,
          childAspectRatio: 1.12,
          children: [
            _buildStatCard(
              "Ticket Promedio",
              ticketPromedio,
              Icons.analytics,
              widget.isDark ? Colors.teal[300]! : Colors.teal[800]!,
            ),
            _buildStatCard(
              "Frecuencia Media",
              0,
              Icons.update_rounded,
              widget.isDark ? Colors.indigo[300]! : Colors.indigo[800]!,
              textValue: frecuenciaMedia,
            ),
            _buildStatCard(
              "N° de Compras",
              numCompras.toDouble(),
              Icons.receipt_long,
              widget.isDark ? Colors.purple[300]! : Colors.purple[700]!,
              isInt: true,
            ),
            _buildStatCard(
              "Última Compra",
              0,
              Icons.event_available,
              widget.isDark ? Colors.blueGrey[300]! : Colors.blueGrey[700]!,
              textValue: ultimaCompra,
            ),
          ],
        ),

        const SizedBox(height: 12),
        ClientComplianceSparkline(
          client: widget.client,
          sales: sales,
          isDark: widget.isDark,
        ),

        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),

        // SECCION 2: Estado Actual (Global)
        Text(
          "Estado de Cuenta Actual (Global)",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: widget.isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 10,
          childAspectRatio: 1.12,
          children: [
            _buildStatCard(
              "Deuda Total",
              deudaGlobal,
              Icons.account_balance_wallet,
              deudaGlobal > 0
                  ? (widget.isDark ? Colors.red[400]! : Colors.red)
                  : (widget.isDark ? Colors.green[400]! : Colors.green),
            ),
            _buildStatCard(
              "Deuda (Solo Compras)",
              deudaCompras,
              Icons.shopping_cart,
              deudaCompras > 0
                  ? (widget.isDark ? Colors.red[300]! : Colors.red[600]!)
                  : (widget.isDark ? Colors.green[300]! : Colors.green[600]!),
            ),
            _buildStatCard(
              "Saldo a Favor",
              saldoFavor,
              Icons.savings,
              widget.isDark ? Colors.amber[400]! : Colors.amber[800]!,
            ),
            _buildStatCard(
              "Por Entregar",
              porEntregar.toDouble(),
              Icons.local_shipping,
              widget.isDark ? Colors.orange[400]! : Colors.orange[800]!,
              isInt: true,
            ),
          ],
        ),

        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 16),

        // SECCION 3: Préstamos
        Text(
          "Préstamos Personales",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: widget.isDark ? Colors.orange[300] : Colors.orange[800],
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 10,
          childAspectRatio: 1.12,
          children: [
            _buildStatCard(
              "Deuda por Préstamos",
              deudaPrestamos,
              Icons.account_balance,
              deudaPrestamos > 0
                  ? (widget.isDark ? Colors.orange[400]! : Colors.orange[700]!)
                  : (widget.isDark ? Colors.green[400]! : Colors.green[700]!),
            ),
            _buildStatCard(
              "Préstamos Activos",
              prestamosActivos.toDouble(),
              Icons.list_alt,
              widget.isDark ? Colors.amber[300]! : Colors.amber[800]!,
              isInt: true,
            ),
            _buildStatCard(
              "Total Histórico Prestado",
              totalPrestado,
              Icons.monetization_on,
              widget.isDark ? Colors.deepOrange[300]! : Colors.deepOrange[700]!,
            ),
          ],
        ),
      ],
    );
  }
}
