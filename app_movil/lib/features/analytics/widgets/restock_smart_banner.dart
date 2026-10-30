import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_movil/core/database/local_db.dart';
import 'package:app_movil/features/analytics/screens/smart_restock_screen.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:provider/provider.dart';

/// 🏆 RestockSmartBanner (Mobile Awards Standard)
/// Componente de dos estados para Alertas de Stock en el Home:
/// 1. [Modo Píldora Simple]: Etiqueta compacta limpia [ ⚠️ N Alertas de Stock ] (por defecto).
/// 2. [Modo Desplegado Inline]: Panel suavemente animado (AnimatedSize) con resumen de productos afectados
///    y acceso directo a SmartRestockScreen.
class RestockSmartBanner extends StatefulWidget {
  const RestockSmartBanner({super.key});

  @override
  State<RestockSmartBanner> createState() => _RestockSmartBannerState();
}

class _RestockSmartBannerState extends State<RestockSmartBanner>
    with SingleTickerProviderStateMixin {
  int _alertCount = 0;
  List<Map<String, dynamic>> _criticalItems = [];
  bool _isLoading = true;
  bool _isExpanded = false;
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

      await _loadCriticalProductsFromDb(auth.activeBusinessId!);

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCriticalProductsFromDb(int businessId) async {
    final db = await LocalDatabase.instance.database;

    // Conteo directo instantáneo a 0ms en SQLite sin loops pesados ni lag
    final countResult = await db.rawQuery(
      '''
      SELECT COUNT(*) as alert_count
      FROM presentaciones_producto pp
      INNER JOIN productos p ON pp.producto_id = p.id
      WHERE p.negocio_id = ? AND pp.activo = 1 AND pp.stock_actual <= pp.stock_alerta
      ''',
      [businessId],
    );

    final totalAlerts = (countResult.first['alert_count'] as num?)?.toInt() ?? 0;

    List<Map<String, dynamic>> critical = [];
    if (totalAlerts > 0) {
      final topCritical = await db.rawQuery(
        '''
        SELECT pp.id as presentation_id, pp.stock_actual, pp.stock_alerta,
               pp.nombre_especifico, pp.unidad_venta, p.nombre as producto_nombre
        FROM presentaciones_producto pp
        INNER JOIN productos p ON pp.producto_id = p.id
        WHERE p.negocio_id = ? AND pp.activo = 1 AND pp.stock_actual <= pp.stock_alerta
        ORDER BY pp.stock_actual ASC
        LIMIT 5
        ''',
        [businessId],
      );

      critical = topCritical.map((row) {
        return {
          'nombre': "${row['producto_nombre'] ?? ''} ${row['nombre_especifico'] ?? ''}".trim(),
          'stock': (row['stock_actual'] as num?)?.toInt() ?? 0,
          'rop': (row['stock_alerta'] as num?)?.toInt() ?? 5,
          'unidad': row['unidad_venta'] ?? 'und',
        };
      }).toList();
    }

    if (mounted) {
      setState(() {
        _alertCount = totalAlerts;
        _criticalItems = critical;
      });
    }
  }

  void _toggleExpanded() {
    HapticFeedback.lightImpact();
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _alertCount == 0) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final pulseValue = _pulseController.value;
          final glowAlpha = 0.2 + (pulseValue * 0.25);
          final borderAlpha = 0.4 + (pulseValue * 0.35);

          return AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.centerRight,
            child: _isExpanded
                ? _buildExpandedPanel(isDark, borderAlpha, glowAlpha)
                : _buildCollapsedPill(isDark, borderAlpha, glowAlpha, pulseValue),
          );
        },
      ),
    );
  }

  /// 1️⃣ ESTADO POR DEFECTO: Modo Etiqueta / Píldora Simple
  Widget _buildCollapsedPill(
    bool isDark,
    double borderAlpha,
    double glowAlpha,
    double pulseValue,
  ) {
    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _toggleExpanded,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF261A08) : const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.orange.withValues(alpha: borderAlpha),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: glowAlpha * 0.45),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Transform.scale(
                  scale: 1.0 + (pulseValue * 0.1),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orangeAccent,
                    size: 17,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _alertCount == 1 ? "1 Alerta de Stock" : "$_alertCount Alertas de Stock",
                  style: TextStyle(
                    color: isDark ? const Color(0xFFFFB74D) : const Color(0xFFE65100),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: isDark ? Colors.orange[300] : Colors.orange[800],
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 2️⃣ ESTADO DESPLEGADO INLINE: Resumen de productos afectados + Acción directa
  Widget _buildExpandedPanel(bool isDark, double borderAlpha, double glowAlpha) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E160A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.orange.withValues(alpha: borderAlpha),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: glowAlpha * 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header del panel desplegado (tocar para replegar)
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              onTap: _toggleExpanded,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.22),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orangeAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                "Alertas de Reabastecimiento",
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.5,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(10),
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
                            "Toca para replegar",
                            style: TextStyle(
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.orangeAccent, size: 24),
                      onPressed: _toggleExpanded,
                      tooltip: "Replegar alerta",
                    ),
                  ],
                ),
              ),
            ),
          ),
          Divider(height: 1, color: isDark ? Colors.white10 : Colors.orange.shade100),

          // Lista resumida de productos en riesgo (hasta 3-4 ítems)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              children: _criticalItems.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 16, color: Colors.orange[300]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item['nombre'],
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.redAccent.withValues(alpha: 0.4),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          "Stock: ${item['stock']} ${item['unidad']}",
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          // Botón de acción: navegar al centro de inteligencia de inventario
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SizedBox(
              width: double.infinity,
              height: 38,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SmartRestockScreen(),
                    ),
                  ).then((_) => _checkRestockAlerts(forceRefresh: true));
                },
                icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                label: const Text(
                  "Gestionar Reabastecimiento",
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

