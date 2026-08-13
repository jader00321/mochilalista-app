import 'package:flutter/material.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/features/analytics/services/inventory_intelligence_service.dart';
import 'package:app_movil/features/analytics/screens/smart_restock_screen.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class RestockSmartBanner extends StatefulWidget {
  const RestockSmartBanner({super.key});

  @override
  State<RestockSmartBanner> createState() => _RestockSmartBannerState();
}

class _RestockSmartBannerState extends State<RestockSmartBanner> {
  int _alertCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkRestockAlerts();
  }

  Future<void> _checkRestockAlerts() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (!auth.hasActiveContext) {
        setState(() => _isLoading = false);
        return;
      }

      final db = await LocalDatabase.instance.database;
      final biService = InventoryIntelligenceService();

      final products = await db.rawQuery('''
        SELECT pp.id as presentation_id, pp.stock_actual
        FROM presentaciones_producto pp
        INNER JOIN productos p ON pp.producto_id = p.id
        WHERE p.negocio_id = ? AND pp.activo = 1
      ''', [auth.activeBusinessId]);

      int count = 0;
      for (var row in products) {
        int presId = row['presentation_id'] as int;
        int currentStock = (row['stock_actual'] as num?)?.toInt() ?? 0;
        
        final biData = await biService.calculateReorderPoint(presId, currentStock);
        int rop = (biData['rop'] as num).toInt();
        
        if (currentStock <= rop && biData['velocity_per_day'] > 0) {
          count++;
        }
      }

      if (mounted) {
        setState(() {
          _alertCount = count;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _alertCount == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Colors.orangeAccent, Colors.deepOrange]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SmartRestockScreen()));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.warning_amber_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Alerta de Reabastecimiento", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Text("Tienes $_alertCount productos con stock crítico", style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
