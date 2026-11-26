part of '../commercial_radar_screen.dart';

mixin _RadarNewsCardMixin on _CommercialRadarScreenStateBase {
  @override
  Widget _buildNewsCard(CommercialNewsItem item, bool isDark) {
    final catColor = _getCategoryColor(item.category);
    final catIcon = _getCategoryIcon(item.category);
    final isBookmarked = _savedNewsMap.containsKey(item.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Clicable con degradado temático + Acciones Rápidas (Blindado con FittedBox Anti-Overflow)
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  catColor.withValues(alpha: 0.85),
                  catColor.withValues(alpha: 0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Icon(catIcon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      item.category.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  icon: Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    color: Colors.white,
                    size: 19,
                  ),
                  tooltip: isBookmarked
                      ? "Quitar de Guardadas"
                      : "Guardar en Favoritos",
                  onPressed: () => _toggleBookmark(item),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 28,
                    minHeight: 28,
                  ),
                  icon: const Icon(
                    Icons.open_in_new,
                    color: Colors.white70,
                    size: 17,
                  ),
                  tooltip: "Abrir enlace original",
                  onPressed: () => _launchUrl(item.sourceUrl),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Metadata: Medio Verificado + Distintivo de Credibilidad + Alcance + Antigüedad (Cero Emojis)
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.blue[400]! : Colors.blue[700]!)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.sourceName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.blue[300] : Colors.blue[800],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: item.isLive
                            ? const Color(0xFF059669).withValues(alpha: 0.15)
                            : Colors.indigo.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: item.isLive
                              ? const Color(0xFF059669).withValues(alpha: 0.4)
                              : Colors.indigo.withValues(alpha: 0.35),
                          width: 0.8,
                        ),
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                item.isLive
                                    ? Icons.sensors_rounded
                                    : Icons.verified_user_outlined,
                                size: 11,
                                color: item.isLive
                                    ? const Color(0xFF059669)
                                    : Colors.indigoAccent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                item.isLive
                                    ? "En Vivo Verificada"
                                    : "Guía Verificada",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: item.isLive
                                      ? (isDark
                                            ? const Color(0xFF34D399)
                                            : const Color(0xFF065F46))
                                      : (isDark
                                            ? Colors.indigo[200]
                                            : Colors.indigo[800]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Badge Territorial (Local / Regional / Nacional)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (item.scope == RadarNewsScope.local
                                    ? Colors.teal
                                    : item.scope == RadarNewsScope.regional
                                    ? Colors.cyan
                                    : Colors.blueGrey)
                                .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 160),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                item.scope == RadarNewsScope.local
                                    ? Icons.near_me_outlined
                                    : item.scope == RadarNewsScope.regional
                                    ? Icons.map_outlined
                                    : Icons.public_outlined,
                                size: 11,
                                color: item.scope == RadarNewsScope.local
                                    ? Colors.tealAccent
                                    : item.scope == RadarNewsScope.regional
                                    ? Colors.cyanAccent
                                    : Colors.blueGrey[200],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                item.scopeLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: item.scope == RadarNewsScope.local
                                      ? (isDark
                                            ? Colors.tealAccent
                                            : Colors.teal[800])
                                      : item.scope == RadarNewsScope.regional
                                      ? (isDark
                                            ? Colors.cyanAccent
                                            : Colors.cyan[800])
                                      : (isDark
                                            ? Colors.blueGrey[200]
                                            : Colors.blueGrey[800]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Text(
                      item.displayDateOrBadge,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Titular limpio sin emojis
                InkWell(
                  onTap: () => _launchUrl(item.sourceUrl),
                  child: Text(
                    item.cleanTitle,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Resumen
                Text(
                  item.cleanSummary,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 14),

                // Bloque 1 de Análisis IA: Impacto en tu Negocio / Ruta
                if (item.cleanImpact.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.orange.withValues(alpha: 0.1)
                          : const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.local_shipping_outlined,
                          color: Colors.orange,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Impacto en tu Negocio / Ruta:",
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.cleanImpact,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.35,
                                  color: isDark
                                      ? Colors.orange[100]
                                      : const Color(0xFF9A3412),
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
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
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
                      const Icon(
                        Icons.lightbulb_outline,
                        color: Colors.green,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Medidas y Recomendaciones Clave:",
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.cleanAdvice,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.35,
                                color: isDark
                                    ? Colors.green[100]
                                    : const Color(0xFF065F46),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            icon: Icon(action.icon, size: 15),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                action.label,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            onPressed: () =>
                                _executeRadarAction(context, action.type),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.green.withValues(
                              alpha: 0.15,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(
                            Icons.share_outlined,
                            color: Colors.green,
                            size: 18,
                          ),
                          tooltip: "Compartir Alerta por WhatsApp",
                          onPressed: () => _shareAlert(item),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),

                // Botón Leer Fuente Oficial
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                    ),
                    onPressed: () => _launchUrl(item.sourceUrl),
                    icon: const Icon(Icons.link, size: 16),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text("Leer fuente original (${item.sourceName})"),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('clima') || lower.contains('ruta')) {
      return const Color(0xFF0284C7);
    }
    if (lower.contains('ley') || lower.contains('sunat')) {
      return const Color(0xFF7C3AED);
    }
    if (lower.contains('proveedor') || lower.contains('abastecimiento')) {
      return const Color(0xFFD97706);
    }
    if (lower.contains('campaña') ||
        lower.contains('campana') ||
        lower.contains('fecha')) {
      return const Color(0xFFE11D48);
    }
    return const Color(0xFF059669);
  }

  IconData _getCategoryIcon(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('clima') || lower.contains('ruta')) {
      return Icons.wb_cloudy_outlined;
    }
    if (lower.contains('ley') || lower.contains('sunat')) {
      return Icons.gavel_rounded;
    }
    if (lower.contains('proveedor') || lower.contains('abastecimiento')) {
      return Icons.local_shipping_outlined;
    }
    if (lower.contains('campaña') ||
        lower.contains('campana') ||
        lower.contains('fecha')) {
      return Icons.event_available_outlined;
    }
    return Icons.location_on_outlined;
  }
}
