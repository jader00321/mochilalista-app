import 'package:flutter/material.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/features/analytics/services/inventory_intelligence_service.dart';
import 'package:app_movil/features/analytics/screens/smart_restock_screen.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RestockSmartBanner extends StatefulWidget {
  const RestockSmartBanner({super.key});

  @override
  State<RestockSmartBanner> createState() => _RestockSmartBannerState();
}

class _RestockSmartBannerState extends State<RestockSmartBanner> with SingleTickerProviderStateMixin {
  int _alertCount = 0;
  bool _isLoading = true;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _checkRestockAlerts();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkRestockAlerts({bool forceRefresh = false}) async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (!auth.hasActiveContext) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'restock_alert_count_${auth.activeBusinessId}';
      final cacheTimeKey = 'restock_alert_time_${auth.activeBusinessId}';

      if (!forceRefresh) {
        final lastCount = prefs.getInt(cacheKey);
        final lastTimeStr = prefs.getString(cacheTimeKey);

        if (lastCount != null && lastTimeStr != null) {
          final lastTime = DateTime.tryParse(lastTimeStr);
          if (lastTime != null && DateTime.now().difference(lastTime).inHours < 4) {
            if (mounted) {
              setState(() {
                _alertCount = lastCount;
                _isLoading = false;
              });
            }
            return; // Usamos el caché
          }
        }
      }

      final db = await LocalDatabase.instance.database;
      final biService = InventoryIntelligenceService();

      final products = await db.rawQuery(
        '''
        SELECT pp.id as presentation_id, pp.stock_actual
        FROM presentaciones_producto pp
        INNER JOIN productos p ON pp.producto_id = p.id
        WHERE p.negocio_id = ? AND pp.activo = 1
      ''',
        [auth.activeBusinessId],
      );

      int count = 0;
      for (var row in products) {
        int presId = row['presentation_id'] as int;
        int currentStock = (row['stock_actual'] as num?)?.toInt() ?? 0;

        final biData = await biService.calculateReorderPoint(
          presId,
          currentStock,
        );
        int rop = (biData['rop'] as num).toInt();

        if (currentStock <= rop && biData['velocity_per_day'] > 0) {
          count++;
        }
      }

      await prefs.setInt(cacheKey, count);
      await prefs.setString(cacheTimeKey, DateTime.now().toIso8601String());

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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final alertText = _alertCount == 1
        ? "1 producto requiere reabastecimiento urgente"
        : "$_alertCount productos requieren reabastecimiento";

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulseValue = _pulseController.value;
        final glowAlpha = 0.2 + (pulseValue * 0.25);
        final borderAlpha = 0.35 + (pulseValue * 0.35);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SmartRestockScreen(),
                ),
              ).then((_) => _checkRestockAlerts(forceRefresh: true));
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          const Color(0xFF2C1E08).withValues(alpha: 0.95),
                          const Color(0xFF1B1408).withValues(alpha: 0.95),
                        ]
                      : [
                          const Color(0xFFFFF8E7),
                          const Color(0xFFFFECB3).withValues(alpha: 0.8),
                        ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: borderAlpha),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withValues(alpha: glowAlpha * 0.5),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Icono con micro-pulso y fondo suave ámbar
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: isDark ? 0.25 : 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Transform.scale(
                      scale: 1.0 + (pulseValue * 0.08),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orangeAccent,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Textos informativos
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              "Alerta de Reabastecimiento",
                              style: TextStyle(
                                color: isDark ? Colors.white : const Color(0xFF4E2C00),
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                "$_alertCount",
                                style: const TextStyle(
                                  color: Colors.orangeAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          alertText,
                          style: TextStyle(
                            color: isDark ? Colors.orange[200] : const Color(0xFF8D5000),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Botón de acción rápido "Revisar"
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withValues(alpha: 0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Revisar",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(width: 3),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.white,
                          size: 10,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
