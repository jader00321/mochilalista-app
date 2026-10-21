import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/smart_quotation/widgets/history/sale_action_bottom_sheet.dart';
import 'package:app_movil/core/widgets/empty_state_widget.dart';

class SalesListBuilder extends StatefulWidget {
  const SalesListBuilder({super.key});

  @override
  State<SalesListBuilder> createState() => _SalesListBuilderState();
}

class _SalesListBuilderState extends State<SalesListBuilder> {


  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<SaleProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardTheme.color ?? Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    if (provider.isLoading && provider.salesHistory.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.salesHistory.isEmpty) {
      return const EmptyStateWidget(
        icon: Icons.receipt_long,
        title: "Sin Ventas",
        subtitle: "No hay ventas registradas en este filtro.",
      );
    }

    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final dateFormat = DateFormat('dd/MM/yyyy • hh:mm a');

    return RefreshIndicator(
      onRefresh: () async => provider.loadFilteredHistory(reset: true),
      color: Colors.blue[800],
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        itemCount: provider.salesHistory.length + (provider.hasMoreData ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == provider.salesHistory.length) {
            WidgetsBinding.instance.addPostFrameCallback((_) => provider.loadFilteredHistory());
            return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator()));
          }

          final sale = provider.salesHistory[index];
          final date = DateTime.tryParse(sale.saleDate) ?? DateTime.now();

          // 🏷️ Badge de Origen Explícito
          final String originBadgeText;
          final Color originBadgeColor;
          final IconData originAvatarIcon;

          if (sale.isLoan) {
            originBadgeText = "🏦 Préstamo Personal";
            originBadgeColor = isDark ? Colors.amber[400]! : Colors.amber[800]!;
            originAvatarIcon = Icons.account_balance_wallet_rounded;
          } else if (sale.isQuickSale) {
            originBadgeText = "⚡ Caja Rápida";
            originBadgeColor = isDark ? Colors.teal[300]! : Colors.teal[700]!;
            originAvatarIcon = Icons.flash_on_rounded;
          } else {
            originBadgeText = "📋 Cotización Vendida";
            originBadgeColor = isDark ? Colors.orange[300]! : Colors.orange[800]!;
            originAvatarIcon = Icons.request_quote_rounded;
          }

          // 👤 Nombre del Cliente
          final clientName = sale.clientName?.trim();
          final hasClient = clientName != null && clientName.isNotEmpty;
          final clientTitle = hasClient 
              ? clientName 
              : (sale.isLoan ? "Cliente no registrado" : "Cliente eventual");

          // 📝 Subtítulo contextual
          final String subtitleText;
          if (sale.isLoan) {
            subtitleText = sale.notes?.isNotEmpty == true ? sale.notes! : "Sin motivo especificado";
          } else {
            subtitleText = sale.notes?.isNotEmpty == true 
                ? sale.notes! 
                : (hasClient ? "Cliente vinculado" : "Venta en mostrador");
          }

          return InkWell(
            onTap: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (_) => SaleActionBottomSheet(sale: sale),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: sale.isArchived ? (isDark ? Colors.white10 : Colors.grey[100]) : cardColor, 
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                boxShadow: [if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 4))]
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1️⃣ Fila Superior (Cabecera)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                sale.isLoan ? "Préstamo #${sale.displayId}" : "Recibo #${sale.displayId}", 
                                style: TextStyle(
                                  fontWeight: FontWeight.bold, 
                                  color: isDark ? Colors.grey[300] : Colors.grey[700], 
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _OriginBadge(
                              text: originBadgeText, 
                              color: originBadgeColor, 
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        dateFormat.format(date), 
                        style: TextStyle(
                          fontSize: 12, 
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14), 
                  
                  // 2️⃣ Cuerpo Central
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: originBadgeColor.withValues(alpha: 0.15), 
                        radius: 20, 
                        child: Icon(
                          originAvatarIcon, 
                          size: 20, 
                          color: originBadgeColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Nombre y Subtítulo
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              clientTitle, 
                              style: TextStyle(
                                fontSize: 16, 
                                fontWeight: FontWeight.bold, 
                                color: sale.isArchived ? Colors.grey : textColor,
                                fontStyle: !hasClient ? FontStyle.italic : FontStyle.normal,
                              ),
                              maxLines: 1, 
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitleText, 
                              style: TextStyle(
                                fontSize: 13, 
                                color: isDark ? Colors.blueGrey[300] : Colors.blueGrey[700], 
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            if (sale.paymentMethod.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white12 : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  sale.paymentMethod.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.grey[300] : Colors.grey[800],
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      
                      // Columna de Importes
                      Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              currency.format(sale.trueTotalAmount),
                              style: TextStyle(
                                fontSize: 17, 
                                fontWeight: FontWeight.w900, 
                                color: sale.isArchived 
                                    ? Colors.grey 
                                    : (sale.isLoan 
                                        ? (isDark ? Colors.amber[300] : Colors.amber[900]) 
                                        : (isDark ? Colors.blue[300] : Colors.blue[900])),
                                decoration: sale.isArchived ? TextDecoration.lineThrough : null, 
                              ),
                            ),
                            if (sale.isPartialPayment) ...[
                              const SizedBox(height: 2),
                              Text(
                                "Abonado: S/ ${sale.paidAmount.toStringAsFixed(2)}",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.green[300] : Colors.green[800],
                                ),
                              ),
                              Text(
                                "Debe: S/ ${sale.pendingDebt.toStringAsFixed(2)}",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.red[300] : Colors.red[700],
                                ),
                              ),
                            ] else if (sale.isUnpaid) ...[
                              const SizedBox(height: 2),
                              Text(
                                "Debe: S/ ${sale.pendingDebt.toStringAsFixed(2)}",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.red[300] : Colors.red[700],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 3️⃣ Fila Inferior de Estados (Badges compactos)
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      // Badge de Pago Real
                      if (sale.isArchived)
                        _Badge(
                          text: "ANULADO", 
                          color: isDark ? Colors.red[300]! : Colors.red, 
                          icon: Icons.auto_delete, 
                          isDark: isDark,
                        )
                      else if (sale.isFullyPaid)
                        _Badge(
                          text: "PAGADO", 
                          color: isDark ? Colors.green[400]! : Colors.green[700]!, 
                          icon: Icons.check_circle_rounded, 
                          isDark: isDark,
                        )
                      else if (sale.isPartialPayment)
                        _Badge(
                          text: "PAGO PARCIAL · Debe S/ ${sale.pendingDebt.toStringAsFixed(2)}", 
                          color: isDark ? Colors.orange[300]! : Colors.orange[800]!, 
                          icon: Icons.timelapse_rounded, 
                          isDark: isDark,
                        )
                      else
                        _Badge(
                          text: "PENDIENTE DE COBRO · S/ ${sale.pendingDebt.toStringAsFixed(2)}", 
                          color: isDark ? Colors.red[300]! : Colors.red[700]!, 
                          icon: Icons.pending_actions_rounded, 
                          isDark: isDark,
                        ),
                      
                      // Badge de Entrega (solo productos, NUNCA en préstamos)
                      if (!sale.isLoan && !sale.isArchived)
                        _Badge(
                          text: sale.deliveryStatus.toUpperCase().replaceAll("_", " "), 
                          color: sale.deliveryStatus.contains("entregado") 
                              ? (isDark ? Colors.blue[300]! : Colors.blue) 
                              : (isDark ? Colors.purple[300]! : Colors.purple), 
                          icon: Icons.local_shipping_outlined, 
                          isDark: isDark,
                        ),
                    ],
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OriginBadge extends StatelessWidget {
  final String text;
  final Color color;
  final bool isDark;

  const _OriginBadge({required this.text, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  final IconData icon;
  final bool isDark;

  const _Badge({required this.text, required this.color, required this.icon, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12), 
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            text, 
            style: TextStyle(
              fontSize: 10.5, 
              fontWeight: FontWeight.w800, 
              color: color, 
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}