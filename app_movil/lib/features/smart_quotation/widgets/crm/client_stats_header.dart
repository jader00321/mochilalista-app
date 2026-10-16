import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/client_full_stats_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/client_finance_actions_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/client_compliance_sparkline.dart';

class ClientStatsHeader extends StatefulWidget {
  final ClientModel client;
  final bool isDark;
  final VoidCallback onWhatsAppTap;
  final VoidCallback onCallTap;
  final VoidCallback onGoToQuickSale;
  final VoidCallback? onGoToQuotation;
  final VoidCallback onFinanceActionCompleted;

  const ClientStatsHeader({
    super.key,
    required this.client,
    required this.isDark,
    required this.onWhatsAppTap,
    required this.onCallTap,
    required this.onGoToQuickSale,
    this.onGoToQuotation,
    required this.onFinanceActionCompleted,
  });

  @override
  State<ClientStatsHeader> createState() => _ClientStatsHeaderState();
}

class _ClientStatsHeaderState extends State<ClientStatsHeader> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  late AnimationController _bounceControllerWpp;
  late Animation<double> _bounceAnimationWpp;

  late AnimationController _bounceControllerCall;
  late Animation<double> _bounceAnimationCall;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _bounceControllerWpp = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _bounceAnimationWpp = Tween<double>(begin: 1.0, end: 0.9).animate(CurvedAnimation(parent: _bounceControllerWpp, curve: Curves.easeIn));

    _bounceControllerCall = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _bounceAnimationCall = Tween<double>(begin: 1.0, end: 0.9).animate(CurvedAnimation(parent: _bounceControllerCall, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _bounceControllerWpp.dispose();
    _bounceControllerCall.dispose();
    super.dispose();
  }

  void _onWppTap() async {
    try {
      await _bounceControllerWpp.forward().orCancel;
      await _bounceControllerWpp.reverse().orCancel;
    } catch (e) {
      // Ignorar si el componente se desmonta
    }
    if (mounted) widget.onWhatsAppTap();
  }

  void _onCallTap() async {
    try {
      await _bounceControllerCall.forward().orCancel;
      await _bounceControllerCall.reverse().orCancel;
    } catch (e) {
      // Ignorar si el componente se desmonta
    }
    if (mounted) widget.onCallTap();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildProfileHeader(context),
      ],
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    return Container(
      color: widget.isDark ? const Color(0xFF1A1A24) : const Color(0xFF1565C0),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28, 
                backgroundColor: Colors.white24,
                child: Text(
                  widget.client.fullName.isNotEmpty ? widget.client.fullName[0].toUpperCase() : "?",
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.client.fullName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 0.5), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.phone, color: Colors.white70, size: 16),
                        const SizedBox(width: 4),
                        Text(widget.client.phone, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
                        const Spacer(),
                        ScaleTransition(
                          scale: _bounceAnimationWpp,
                          child: _buildSmallActionButton(Icons.chat, const Color(0xFF25D366), _onWppTap),
                        ),
                        const SizedBox(width: 8),
                        ScaleTransition(
                          scale: _bounceAnimationCall,
                          child: _buildSmallActionButton(Icons.call, widget.isDark ? Colors.blue[600]! : Colors.blue[800]!, _onCallTap),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          Row(
            children: [
              _buildTrustBadge(),
              const Spacer(),
              ScaleTransition(
                scale: _pulseAnimation,
                child: _buildFullStatsButton(context),
              )
            ],
          ),
          
          if (widget.client.etiquetas.isNotEmpty) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: widget.client.etiquetas.map((tag) => Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                  child: Text(tag, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                )).toList(),
              ),
            ),
          ],
          ClientComplianceSparkline(
            client: widget.client,
            isDark: widget.isDark,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: ElevatedButton.icon(
                  onPressed: widget.onGoToQuickSale,
                  icon: const Icon(Icons.point_of_sale, size: 16),
                  label: const Text(
                    "Caja Rápida",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 11,
                      horizontal: 8,
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              if (widget.onGoToQuotation != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    onPressed: widget.onGoToQuotation,
                    icon: const Icon(Icons.request_quote_outlined, size: 16),
                    label: const Text(
                      "Cotizar",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 11,
                        horizontal: 8,
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => ClientFinanceActionsModal(
                        client: widget.client,
                        isDark: widget.isDark,
                      ),
                    ).then((_) {
                      widget.onFinanceActionCompleted();
                    });
                  },
                  icon: const Icon(Icons.account_balance_wallet, size: 16),
                  label: const Text(
                    "Finanzas",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.isDark
                        ? Colors.blueGrey[800]
                        : Colors.blueGrey[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 11,
                      horizontal: 8,
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
          
          _buildDelinquencyBanner(context),
        ],
      ),
    );
  }

  Widget _buildSmallActionButton(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
  }

  Widget _buildFullStatsButton(BuildContext context) {
    return TextButton.icon(
      onPressed: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => ClientFullStatsModal(client: widget.client, isDark: widget.isDark),
        );
      },
      icon: const Icon(Icons.analytics_rounded, color: Colors.white, size: 16),
      label: const Text(
        "Ver Analítica", 
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)
      ),
      style: TextButton.styleFrom(
        backgroundColor: Colors.white.withAlpha(38),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildTrustBadge() {
    Color color;
    IconData icon;
    String label = widget.client.nivelConfianza.toUpperCase();
    switch (widget.client.nivelConfianza.toLowerCase()) {
      case 'excelente': color = Colors.greenAccent; icon = Icons.star; break;
      case 'regular': color = Colors.orangeAccent; icon = Icons.warning; break;
      case 'moroso': color = Colors.redAccent; icon = Icons.block; break;
      case 'bueno':
      default: color = Colors.blueAccent; icon = Icons.thumb_up; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(204),
        borderRadius: BorderRadius.circular(16)
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildDelinquencyBanner(BuildContext context) {
    final provider = Provider.of<TrackingProvider>(context);
    final debts = provider.currentClientDebts;
    if (debts.isEmpty || provider.isLoadingDebts) return const SizedBox.shrink();

    int overdueCount = 0;
    int maxDaysOverdue = 0;
    DateTime today = DateTime.now();
    today = DateTime(today.year, today.month, today.day);

    for (var sale in debts) {
      for (var cuota in sale.installments) {
        if (cuota.status != 'pagado') {
          DateTime dueDate = DateTime.tryParse(cuota.dueDate) ?? DateTime.now();
          dueDate = DateTime(dueDate.year, dueDate.month, dueDate.day);
          if (dueDate.isBefore(today)) {
            overdueCount++;
            int days = today.difference(dueDate).inDays;
            if (days > maxDaysOverdue) maxDaysOverdue = days;
          }
        }
      }
    }

    if (overdueCount == 0 && widget.client.totalDebt > 0) {
      return Container(
        margin: const EdgeInsets.only(top: 24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: Colors.greenAccent.withAlpha(38), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.greenAccent.withAlpha(76))),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.greenAccent),
            const SizedBox(width: 12),
            const Expanded(child: Text("Cliente al día. Sin cuotas vencidas.", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          ],
        ),
      );
    }

    if (overdueCount > 0) {
      return Container(
        margin: const EdgeInsets.only(top: 24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: Colors.redAccent.withAlpha(38), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.redAccent.withAlpha(76))),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("⚠️ $overdueCount cuota(s) vencida(s)", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  Text("Deuda más antigua: hace $maxDaysOverdue días", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            if (widget.client.phone.isNotEmpty && widget.client.phone != "000000000")
              ElevatedButton.icon(
                onPressed: widget.onWhatsAppTap,
                icon: const Icon(Icons.send, size: 14),
                label: const Text("Recordar", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
          ],
        ),
      );
    }
    
    return const SizedBox.shrink();
  }
}
