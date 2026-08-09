import 'package:flutter/material.dart';
import '../providers/analytics_provider.dart';

class InsightsCarousel extends StatelessWidget {
  final AnalyticsData data;
  final bool isDark;

  const InsightsCarousel({
    super.key,
    required this.data,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    if (data.insights.isEmpty) return const SizedBox.shrink();

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
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: data.insights.length,
            itemBuilder: (context, index) {
              final insight = data.insights[index];
              Color bgColor = Colors.blue.withValues(alpha: 0.15);
              Color iconColor = isDark ? Colors.lightBlueAccent : Colors.blue[700]!;
              
              switch (insight.type) {
                case InsightType.success:
                  bgColor = Colors.green.withValues(alpha: 0.15);
                  iconColor = isDark ? Colors.greenAccent : Colors.green[700]!;
                  break;
                case InsightType.warning:
                  bgColor = Colors.redAccent.withValues(alpha: 0.15);
                  iconColor = isDark ? Colors.redAccent : Colors.red[700]!;
                  break;
                case InsightType.info:
                  bgColor = Colors.blue.withValues(alpha: 0.15);
                  iconColor = isDark ? Colors.lightBlueAccent : Colors.blue[700]!;
                  break;
                case InsightType.tip:
                  bgColor = Colors.amber.withValues(alpha: 0.15);
                  iconColor = isDark ? Colors.amberAccent : Colors.amber[800]!;
                  break;
              }

              return Container(
                width: 280,
                margin: const EdgeInsets.only(right: 16, bottom: 8),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark 
                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)] 
                      : [Colors.white, const Color(0xFFF8FAFC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.blueGrey.withValues(alpha: 0.1), width: 1),
                  boxShadow: [
                    BoxShadow(color: iconColor.withValues(alpha: 0.1), blurRadius: 15, offset: const Offset(0, 5)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
                          child: Icon(insight.icon, color: iconColor, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Text(insight.title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: isDark ? Colors.white : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Text(
                        insight.description,
                        style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.blueGrey[700], height: 1.5),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
