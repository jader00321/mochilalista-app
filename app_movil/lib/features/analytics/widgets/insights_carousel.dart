import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_movil/features/analytics/providers/analytics_provider.dart';
import 'package:app_movil/features/analytics/screens/smart_restock_screen.dart';
import 'package:app_movil/features/promotions/screens/bundle_builder_screen.dart';

class InsightsCarousel extends StatefulWidget {
  final AnalyticsData data;
  final bool isDark;

  const InsightsCarousel({
    super.key,
    required this.data,
    required this.isDark,
  });

  @override
  State<InsightsCarousel> createState() => _InsightsCarouselState();
}

class _InsightsCarouselState extends State<InsightsCarousel> with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  Timer? _timer;
  late AnimationController _modalAnimationController;
  List<BusinessInsight> _shuffledInsights = [];

  @override
  void initState() {
    super.initState();
    _shuffledInsights = List.from(widget.data.insights)..shuffle();
    _scrollController = ScrollController();
    _modalAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _startAutoScroll();
  }

  @override
  void didUpdateWidget(InsightsCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data.insights != widget.data.insights) {
      setState(() {
        _shuffledInsights = List.from(widget.data.insights)..shuffle();
      });
    }
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_scrollController.hasClients) {
        final double maxScroll = _scrollController.position.maxScrollExtent;
        final double currentScroll = _scrollController.position.pixels;
        final double itemWidth = 316.0; // 300 width + 16 right margin
        
        if (currentScroll + itemWidth <= maxScroll) {
          _scrollController.animateTo(currentScroll + itemWidth, duration: const Duration(milliseconds: 800), curve: Curves.easeInOut);
        } else {
          _scrollController.animateTo(0, duration: const Duration(milliseconds: 800), curve: Curves.easeInOut);
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    _modalAnimationController.dispose();
    super.dispose();
  }

  void _navigateToRoute(BuildContext context, String route) {
    switch (route) {
      case 'smart_restock':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SmartRestockScreen()));
        break;
      case 'bundle_liquidation':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const BundleBuilderScreen(initialTipoPromocion: 'PAQUETE_LIQUIDACION')));
        break;
      case 'bundle_flash':
        Navigator.push(context, MaterialPageRoute(builder: (_) => const BundleBuilderScreen(initialTipoPromocion: 'PAQUETE_OFERTA')));
        break;
    }
  }

  void _showInsightDetail(BuildContext context, BusinessInsight insight, Color bgColor, Color iconColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      transitionAnimationController: _modalAnimationController,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, controller) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: ListView(
                controller: controller,
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: widget.isDark ? Colors.white24 : Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
                        child: Icon(insight.icon, color: iconColor, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(insight.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: widget.isDark ? Colors.white : Colors.black87)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    insight.description,
                    style: TextStyle(fontSize: 15, color: widget.isDark ? Colors.grey[300] : Colors.grey[800], height: 1.5),
                  ),
                  if (insight.suggestedAction != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: widget.isDark ? Colors.black12 : Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: widget.isDark ? Colors.white10 : Colors.grey[300]!),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.lightbulb_outline, color: Colors.amber[700], size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "¿Qué hacer?\n${insight.suggestedAction}",
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.grey[300] : Colors.grey[800], height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (insight.actionRoute != null) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _navigateToRoute(context, insight.actionRoute!);
                        },
                        icon: const Icon(Icons.arrow_forward),
                        label: Text(insight.actionLabel ?? "Continuar"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: iconColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text("Cerrar", style: TextStyle(color: widget.isDark ? Colors.white70 : Colors.black54)),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: iconColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text("Entendido", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }
        );
      },
    );
  }
  @override
  Widget build(BuildContext context) {
    if (widget.data.insights.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8.0, bottom: 16.0),
          child: Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.amber[600], size: 22),
              const SizedBox(width: 8),
              const Text("Novedades y Oportunidades", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
            ],
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _shuffledInsights.length,
            itemBuilder: (context, index) {
              final insight = _shuffledInsights[index];
              Color bgColor = Colors.blue.withValues(alpha: 0.15);
              Color iconColor = widget.isDark ? Colors.lightBlueAccent : Colors.blue[700]!;
              
              switch (insight.type) {
                case InsightType.success:
                  bgColor = Colors.green.withValues(alpha: 0.15);
                  iconColor = widget.isDark ? Colors.greenAccent : Colors.green[700]!;
                  break;
                case InsightType.warning:
                  bgColor = Colors.redAccent.withValues(alpha: 0.15);
                  iconColor = widget.isDark ? Colors.redAccent : Colors.red[700]!;
                  break;
                case InsightType.info:
                  bgColor = Colors.blue.withValues(alpha: 0.15);
                  iconColor = widget.isDark ? Colors.lightBlueAccent : Colors.blue[700]!;
                  break;
                case InsightType.tip:
                  bgColor = Colors.amber.withValues(alpha: 0.15);
                  iconColor = widget.isDark ? Colors.amberAccent : Colors.amber[800]!;
                  break;
              }

              return GestureDetector(
                onTap: () => _showInsightDetail(context, insight, bgColor, iconColor),
                child: Container(
                  width: 300,
                  margin: const EdgeInsets.only(right: 16, bottom: 8),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: widget.isDark 
                        ? [const Color(0xFF1E293B), const Color(0xFF0F172A)] 
                        : [Colors.white, const Color(0xFFF8FAFC)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: widget.isDark ? Colors.white10 : Colors.blueGrey.withValues(alpha: 0.1), width: 1),
                    boxShadow: [
                      BoxShadow(color: iconColor.withValues(alpha: 0.1), blurRadius: 15, offset: const Offset(0, 5)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
                            child: Icon(insight.icon, color: iconColor, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(child: Text(insight.title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: widget.isDark ? Colors.white : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        insight.description,
                        style: TextStyle(fontSize: 13, color: widget.isDark ? Colors.grey[400] : Colors.blueGrey[700], height: 1.5),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
