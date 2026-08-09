import 'package:flutter/material.dart';
import '../../providers/workbench_provider.dart';

class DashboardHeader extends StatelessWidget {
  final WorkbenchProvider provider;
  final bool isDark;

  const DashboardHeader({super.key, required this.provider, required this.isDark});

  @override
  Widget build(BuildContext context) {
    int prepCount = provider.inProcessList.length;
    int readyCount = provider.readyAndPacksList.length;
    int alertCount = provider.criticalAlertsCount; 

    return Container(
      height: 126, 
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 20, top: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
            ? [const Color(0xFF0D47A1), const Color(0xFF001633)] 
            : [const Color(0xFF1565C0), const Color(0xFF0D47A1)], 
          begin: Alignment.topCenter, end: Alignment.bottomCenter 
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24))
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            _buildKpiCard("En Revisión", "$prepCount", Icons.pending_actions, Colors.orange),
            const SizedBox(width: 12),
            _buildKpiCard("Preparadas", "$readyCount", Icons.check_circle_outline, Colors.greenAccent),
            const SizedBox(width: 12),
            _buildKpiCard("Alertas ⚠️", "$alertCount", Icons.warning_amber, Colors.redAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: 140, 
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), 
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12), 
        borderRadius: BorderRadius.circular(16)
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18), 
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label, 
                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold), 
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis
                )
              ), 
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
