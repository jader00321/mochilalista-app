import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/client_full_stats_modal.dart';
import 'package:app_movil/features/smart_quotation/widgets/crm/client_finance_actions_modal.dart';

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

  // Estado del modo plegable de alerta
  bool _isAlertFolded = false;
  int _lastCheckedOverdueCount = -1;

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

  Future<void> _checkFoldedMemory(int currentOverdueCount) async {
    if (currentOverdueCount <= 0 || _lastCheckedOverdueCount == currentOverdueCount) return;
    _lastCheckedOverdueCount = currentOverdueCount;

    try {
      final prefs = await SharedPreferences.getInstance();
      final keyTs = 'crm_overdue_folded_ts_${widget.client.id}';
      final keyCount = 'crm_overdue_folded_count_${widget.client.id}';

      final foldedTs = prefs.getInt(keyTs);
      final foldedCount = prefs.getInt(keyCount) ?? 0;

      if (foldedTs != null) {
        final now = DateTime.now().millisecondsSinceEpoch;
        const sevenDaysMs = 7 * 24 * 60 * 60 * 1000;
        final hasExpired = (now - foldedTs) > sevenDaysMs;
        final hasNewOverdue = currentOverdueCount > foldedCount;

        if (!hasExpired && !hasNewOverdue) {
          if (mounted && !_isAlertFolded) {
            setState(() => _isAlertFolded = true);
          }
        } else {
          // Ha expirado la semana o se venció una nueva cuota: auto-desplegar
          if (mounted && _isAlertFolded) {
            setState(() => _isAlertFolded = false);
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _toggleAlertFold(int currentOverdueCount) async {
    HapticFeedback.selectionClick();
    final newFolded = !_isAlertFolded;
    setState(() => _isAlertFolded = newFolded);

    try {
      final prefs = await SharedPreferences.getInstance();
      final keyTs = 'crm_overdue_folded_ts_${widget.client.id}';
      final keyCount = 'crm_overdue_folded_count_${widget.client.id}';

      if (newFolded) {
        await prefs.setInt(keyTs, DateTime.now().millisecondsSinceEpoch);
        await prefs.setInt(keyCount, currentOverdueCount);
      } else {
        await prefs.remove(keyTs);
        await prefs.remove(keyCount);
      }
    } catch (_) {}
  }

  void _onWppTap() async {
    try {
      await _bounceControllerWpp.forward().orCancel;
      await _bounceControllerWpp.reverse().orCancel;
    } catch (_) {}
    if (mounted) widget.onWhatsAppTap();
  }

  void _onCallTap() async {
    try {
      await _bounceControllerCall.forward().orCancel;
      await _bounceControllerCall.reverse().orCancel;
    } catch (_) {}
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
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 26, 
                backgroundColor: Colors.white24,
                child: Text(
                  widget.client.fullName.isNotEmpty ? widget.client.fullName[0].toUpperCase() : "?",
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.client.fullName, 
                      style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold, letterSpacing: 0.3), 
                      maxLines: 2, 
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.phone, color: Colors.white70, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          widget.client.phone.isNotEmpty && widget.client.phone != "000000000"
                              ? widget.client.phone
                              : "Sin teléfono", 
                          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
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
          
          const SizedBox(height: 10),
          Row(
            children: [
              _buildTrustBadge(),
              const Spacer(),
              ScaleTransition(
                scale: _pulseAnimation,
                child: _buildFullStatsButton(context),
              ),
            ],
          ),
          
          if (widget.client.etiquetas.isNotEmpty) ...[
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: widget.client.etiquetas.map((tag) => Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                  child: Text(tag, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.4)),
                )).toList(),
              ),
            ),
          ],

          const SizedBox(height: 12),
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
                      vertical: 10,
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
                        vertical: 10,
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
                      vertical: 10,
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
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 15, color: Colors.white),
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
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
      ),
      style: TextButton.styleFrom(
        backgroundColor: Colors.white.withAlpha(38),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(204),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.4)),
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
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.greenAccent.withAlpha(38), 
          borderRadius: BorderRadius.circular(12), 
          border: Border.all(color: Colors.greenAccent.withAlpha(76)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "Cliente al día. Sin cuotas vencidas.", 
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    if (overdueCount > 0) {
      // Verificar memoria inteligente si no se ha evaluado para este conteo
      _checkFoldedMemory(overdueCount);

      final String cuotasText = overdueCount == 1 ? "1 cuota vencida" : "$overdueCount cuotas vencidas";
      final String diasText = "hace $maxDaysOverdue ${maxDaysOverdue == 1 ? 'día' : 'días'}";

      return AnimatedCrossFade(
        duration: const Duration(milliseconds: 250),
        crossFadeState: _isAlertFolded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        // Modo 1: Expandido (Detallado sin colisión)
        firstChild: Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.redAccent.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      cuotasText, 
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  InkWell(
                    onTap: () => _toggleAlertFold(overdueCount),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("Plegar", style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
                          const SizedBox(width: 2),
                          Icon(Icons.keyboard_arrow_up, size: 16, color: Colors.white.withValues(alpha: 0.7)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "Deuda más antigua: $diasText", 
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                  if (widget.client.phone.isNotEmpty && widget.client.phone != "000000000")
                    ElevatedButton.icon(
                      onPressed: () {
                        // Persistir memoria al pulsar recordar para no volver a saturar la pantalla
                        _toggleAlertFold(overdueCount);
                        widget.onWhatsAppTap();
                      },
                      icon: const Icon(Icons.send_rounded, size: 13),
                      label: const Text("Recordar", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        // Modo 2: Retraído (Píldora Discreta)
        secondChild: InkWell(
          onTap: () => _toggleAlertFold(overdueCount),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "$cuotasText ($diasText)",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Text("Ver", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      SizedBox(width: 2),
                      Icon(Icons.keyboard_arrow_down, size: 14, color: Colors.white),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    return const SizedBox.shrink();
  }
}
