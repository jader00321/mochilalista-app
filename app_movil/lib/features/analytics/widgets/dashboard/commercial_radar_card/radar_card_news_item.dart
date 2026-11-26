part of '../commercial_radar_card.dart';

mixin _RadarCardNewsItemMixin on _CommercialRadarCardStateBase {
  Future<void> _launchSourceUrl(String url) async {
    if (url.isEmpty) return;
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Clima y Rutas':
        return Colors.lightBlueAccent;
      case 'Leyes y SUNAT':
        return Colors.purpleAccent;
      case 'Campañas':
        return Colors.amberAccent;
      case 'Mi Región':
      default:
        return Colors.tealAccent;
    }
  }

  IconData _getCategoryIcon(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('clima') || cat.contains('ruta')) {
      return Icons.wb_cloudy_outlined;
    } else if (cat.contains('ley') || cat.contains('sunat')) {
      return Icons.gavel_rounded;
    } else if (cat.contains('proveedor') || cat.contains('abastecimiento')) {
      return Icons.local_shipping_outlined;
    } else if (cat.contains('campaña') || cat.contains('campana') || cat.contains('fecha')) {
      return Icons.event_available_outlined;
    } else {
      return Icons.location_on_outlined;
    }
  }

  LinearGradient _getBannerGradient(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('clima') || cat.contains('ruta')) {
      return const LinearGradient(
        colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (cat.contains('ley') || cat.contains('sunat')) {
      return const LinearGradient(
        colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (cat.contains('proveedor') || cat.contains('abastecimiento')) {
      return const LinearGradient(
        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else if (cat.contains('campaña') || cat.contains('campana') || cat.contains('fecha')) {
      return const LinearGradient(
        colors: [Color(0xFFD97706), Color(0xFFB45309)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    } else {
      return const LinearGradient(
        colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
  }

  @override
  Widget _buildNewsCard(CommercialNewsItem item) {
    final catColor = _getCategoryColor(item.category);
    final catIcon = _getCategoryIcon(item.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isDark ? Colors.white12 : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Clicable
          GestureDetector(
            onTap: () => _launchSourceUrl(item.sourceUrl),
            child: item.imageUrl != null && item.imageUrl!.startsWith('http')
                ? SizedBox(
                    height: 130,
                    width: double.infinity,
                    child: Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildFallbackBanner(item, catIcon),
                    ),
                  )
                : _buildFallbackBanner(item, catIcon),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Metadata: Categoría + Distintivo de Credibilidad + Medio + Fecha
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: catColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(catIcon, size: 12, color: catColor),
                          const SizedBox(width: 4),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 160),
                            child: Text(
                              item.category,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10, 
                                fontWeight: FontWeight.bold, 
                                color: catColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: item.isLive 
                            ? const Color(0xFF059669).withValues(alpha: 0.15) 
                            : Colors.indigo.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: item.isLive 
                              ? const Color(0xFF059669).withValues(alpha: 0.35) 
                              : Colors.indigo.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.isLive ? Icons.sensors_rounded : Icons.verified_user_outlined,
                            size: 11,
                            color: item.isLive ? const Color(0xFF059669) : Colors.indigoAccent,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              item.isLive ? "En Vivo Verificada" : "Guía Verificada",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: item.isLive
                                    ? (widget.isDark ? const Color(0xFF34D399) : const Color(0xFF065F46))
                                    : (widget.isDark ? Colors.indigo[200] : Colors.indigo[800]),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (widget.isDark ? Colors.blue[400]! : Colors.blue[700]!).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        item.sourceName,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: widget.isDark ? Colors.blue[300] : Colors.blue[800],
                        ),
                      ),
                    ),
                    Text(
                      item.compactTimeAgo,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Titular Clicable sin emojis sucios
                GestureDetector(
                  onTap: () => _launchSourceUrl(item.sourceUrl),
                  child: Text(
                    item.cleanTitle,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                      color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Resumen
                Text(
                  item.summary,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: widget.isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 12),

                // Bloque 1 de Análisis IA: Impacto en tu Negocio / Ruta
                if (item.impactAnalysis.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.isDark ? Colors.orange.withValues(alpha: 0.1) : const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.local_shipping_outlined, color: Colors.orange, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Impacto en tu Negocio / Ruta:",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.impactAnalysis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.35,
                                  color: widget.isDark ? Colors.orange[100] : const Color(0xFF9A3412),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Bloque 2 de Análisis IA: Medidas y Recomendaciones Clave
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.isDark 
                        ? Colors.green.withValues(alpha: 0.1) 
                        : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline, color: Colors.green, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Medidas y Recomendaciones Clave:",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.actionableAdvice,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                height: 1.35,
                                color: widget.isDark ? Colors.green[100] : const Color(0xFF065F46),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Botones de Acción Directa en 1 Toque (Iconos Vectoriales Nativos Cero Emojis)
                Builder(
                  builder: (context) {
                    final action = item.resolvedAction;
                    return Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: action.color,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            icon: Icon(action.icon, size: 15),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                action.label,
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                              ),
                            ),
                            onPressed: () => _executeRadarAction(context, action.type),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.green.withValues(alpha: 0.15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.share_outlined, color: Colors.green, size: 18),
                          tooltip: "Compartir Alerta por WhatsApp",
                          onPressed: () => _shareAlert(item),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 6),

                // Leer fuente oficial button
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      visualDensity: VisualDensity.compact,
                      foregroundColor: Colors.blueAccent,
                    ),
                    icon: const Icon(Icons.arrow_outward, size: 14),
                    label: Text(
                      "Leer en ${item.sourceName} ↗",
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () => _launchSourceUrl(item.sourceUrl),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackBanner(CommercialNewsItem item, IconData catIcon) {
    return Container(
      height: 90,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: _getBannerGradient(item.category),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(catIcon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          item.category.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      Text(
                        item.region,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.touch_app, color: Colors.white70, size: 16),
          )
        ],
      ),
    );
  }

  void _executeRadarAction(BuildContext context, RadarActionType type) {
    switch (type) {
      case RadarActionType.workbench:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WorkbenchScreen()),
        );
        break;
      case RadarActionType.restock:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SmartRestockScreen()),
        );
        break;
      case RadarActionType.promotions:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const InventoryScreen(initialTabIndex: 1),
          ),
        );
        break;
      case RadarActionType.quickSale:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const QuickSaleScreen()),
        );
        break;
    }
  }

  void _shareAlert(CommercialNewsItem item) {
    final text = '''
ALERTA RADAR COMERCIAL - MOCHILALISTA
Zona: $_selectedRegion
${item.cleanTitle}

Impacto en tu Negocio / Ruta:
${item.impactAnalysis.isNotEmpty ? item.impactAnalysis : item.summary}

Medidas y Recomendaciones Clave:
${item.actionableAdvice}

Fuente: ${item.sourceName} (${item.sourceUrl})
''';
    // ignore: deprecated_member_use
    Share.share(text.trim());
  }
}
