import 'package:flutter/material.dart';

import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/widgets/search/omni_search_result_cards.dart';

class OmniQuoteResultCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isDark;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onOpen;

  const OmniQuoteResultCard({
    super.key,
    required this.data,
    required this.isDark,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final double amount = (data['total_amount'] as num?)?.toDouble() ?? 0.0;
    final int quoteId = data['id'] as int;
    final int seq = (data['numero_secuencial'] as int?) ?? quoteId;
    final String institution = (data['institution_name'] ?? '').toString();
    final String grade = (data['grade_level'] ?? '').toString();
    final String status = (data['status'] ?? 'PENDING').toString();

    return OmniExpandableCardShell(
      isDark: isDark,
      isExpanded: isExpanded,
      expandedDarkBorder: Colors.orange.withValues(alpha: 0.5),
      expandedLightBorder: Colors.orange.shade300,
      onTap: onToggleExpand,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.orange.withValues(alpha: 0.15)
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.description_outlined,
                  size: 20,
                  color: isDark ? Colors.orange[300] : Colors.orange[800],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Cotización #$seq · ${data['client_name'] ?? 'Cliente General'}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Estado: $status${institution.isNotEmpty ? ' · $institution' : ''}",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 0,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 96),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      AppCurrency.format(amount),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                ),
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: onOpen,
                tooltip: "Ver cotización",
              ),
            ],
          ),
          if (isExpanded) ...[
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: isDark ? Colors.white12 : Colors.grey.shade200,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (institution.isNotEmpty)
                  OmniDetailChip("Institución", institution, isDark),
                if (grade.isNotEmpty)
                  OmniDetailChip("Grado/Nivel", grade, isDark),
                OmniDetailChip("Folio", "#$seq", isDark, isMonospace: true),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? Colors.orange[700]
                      : Colors.orange[800],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  elevation: 0,
                ),
                icon: const Icon(Icons.visibility_rounded, size: 16),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "Abrir Detalle de Cotización",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                onPressed: onOpen,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class OmniSaleResultCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isDark;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onOpen;

  const OmniSaleResultCard({
    super.key,
    required this.data,
    required this.isDark,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final double amount = (data['monto_total'] as num?)?.toDouble() ?? 0.0;
    final int saleId = data['id'] as int;
    final int seq = (data['numero_secuencial'] as int?) ?? saleId;
    final String paymentMethod = (data['metodo_pago'] ?? 'efectivo').toString();
    final String paymentStatus = (data['estado_pago'] ?? 'completado')
        .toString();
    final String rawDate = (data['fecha_venta'] ?? '').toString();
    final String dateStr = rawDate.length >= 10
        ? rawDate.substring(0, 10)
        : rawDate;

    return OmniExpandableCardShell(
      isDark: isDark,
      isExpanded: isExpanded,
      expandedDarkBorder: Colors.teal.withValues(alpha: 0.5),
      expandedLightBorder: Colors.teal.shade300,
      onTap: onToggleExpand,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.teal.withValues(alpha: 0.15)
                      : Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.receipt_rounded,
                  size: 20,
                  color: isDark ? Colors.teal[300] : Colors.teal[700],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Venta #$seq · ${data['cliente_nombre'] ?? 'Cliente Mostrador'}",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Pago: $paymentMethod · $paymentStatus${dateStr.isNotEmpty ? ' · $dateStr' : ''}",
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                flex: 0,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 96),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      AppCurrency.format(amount),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: isDark ? Colors.teal[300] : Colors.teal[800],
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: EdgeInsets.zero,
                ),
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: onOpen,
                tooltip: "Ver venta",
              ),
            ],
          ),
          if (isExpanded) ...[
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: isDark ? Colors.white12 : Colors.grey.shade200,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OmniDetailChip("Folio", "#$seq", isDark, isMonospace: true),
                OmniDetailChip(
                  "Método Pago",
                  paymentMethod.toUpperCase(),
                  isDark,
                ),
                OmniDetailChip(
                  "Estado Pago",
                  paymentStatus.toUpperCase(),
                  isDark,
                ),
                if (dateStr.isNotEmpty)
                  OmniDetailChip("Fecha", dateStr, isDark),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.teal[700] : Colors.teal[600],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  elevation: 0,
                ),
                icon: const Icon(Icons.receipt_long_rounded, size: 16),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "Abrir Detalle de Venta",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                onPressed: onOpen,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
