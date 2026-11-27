part of '../sale_financial_detail_screen.dart';

mixin _SaleFinancialBalanceCardMixin on _SaleFinancialDetailScreenStateBase {
  Widget _buildReceiptButton() {
    return Container(
      key: _tourKeys.receiptButtonKey,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SaleHistoryDetailScreen(saleId: widget.saleId),
            ),
          );
        },
        icon: const Icon(Icons.receipt_long, size: 22),
        label: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            "Ver Comprobante / Compartir",
            maxLines: 1,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[800],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard({
    required bool isDark,
    required bool isLoan,
    required double total,
    required double pagado,
    required double saldo,
    required double interes,
    required double moraTotal,
  }) {
    return Container(
      key: _tourKeys.balanceCardKey,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14141C) : Colors.blueGrey[900],
        borderRadius: BorderRadius.circular(20),
        border: isDark ? Border.all(color: Colors.white10) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.1 * 255).toInt()),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            isLoan
                ? "Saldo Pendiente de este Préstamo"
                : "Saldo Pendiente de esta Venta",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          if (interes > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha((0.2 * 255).toInt()),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orange.withAlpha((0.5 * 255).toInt()),
                ),
              ),
              child: Text(
                "Interés aplicado: ${interes.toStringAsFixed(1)}%",
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (moraTotal > 0.01)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha((0.2 * 255).toInt()),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.red.withAlpha((0.5 * 255).toInt()),
                ),
              ),
              child: Text(
                "Mora acumulada: + ${AppCurrency.format(moraTotal)}",
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              AppCurrency.format(saldo),
              style: TextStyle(
                color: saldo == 0 ? Colors.greenAccent : Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: Colors.white24, height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLoan ? "Monto Total" : "Costo Total",
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        AppCurrency.format(total),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      "Abonado",
                      style: TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        AppCurrency.format(pagado),
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
