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

class _RestockSmartBannerState extends State<RestockSmartBanner> {
  int _alertCount = 0;
  bool _isLoading = true;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _checkRestockAlerts();
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
          if (lastTime != null &&
              DateTime.now().difference(lastTime).inHours < 4) {
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

    Widget childWidget;

    if (!_isExpanded) {
      // Modo Discreto (Píldora)
      childWidget = Align(
        alignment: Alignment.centerRight,
        child: Container(
          key: const ValueKey('discrete_chip'),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                setState(() => _isExpanded = true);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 8.0,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "$_alertCount Alertas de Stock",
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      // Modo Expandido (Banner Completo)
      childWidget = Container(
        key: const ValueKey('expanded_banner'),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.orangeAccent, Colors.deepOrange],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SmartRestockScreen(),
                    ),
                  ).then((_) => _checkRestockAlerts(forceRefresh: true));
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 14.0,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Alerta de Reabastecimiento",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              "Tienes $_alertCount productos con stock crítico",
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(
                        width: 32,
                      ), // Espacio para el botón de cerrar
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              child: Center(
                child: IconButton(
                  icon: const Icon(
                    Icons.keyboard_arrow_up,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    setState(() => _isExpanded = false);
                  },
                ),
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.centerRight,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeIn,
        switchOutCurve: Curves.easeOut,
        child: childWidget,
      ),
    );
  }
}
