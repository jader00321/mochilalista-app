part of '../commercial_radar_screen.dart';

mixin _RadarPulseAndActionsMixin on _CommercialRadarScreenStateBase {
  @override
  Map<String, dynamic> _calculateOperationalPulse() {
    // 1. Rutas y Fletes
    String rutasStatus = "Normal";
    Color rutasColor = Colors.greenAccent;
    final rutaItems = _allNewsItems.where((n) {
      final c = n.category.toLowerCase();
      return c.contains('clima') || c.contains('ruta');
    }).toList();

    for (var n in rutaItems) {
      final t = '${n.title} ${n.impactAnalysis}'.toLowerCase();
      if (t.contains('quebrada') ||
          t.contains('cierre') ||
          t.contains('bloqueo') ||
          t.contains('aislamiento')) {
        rutasStatus = "Alerta";
        rutasColor = Colors.redAccent;
        break;
      } else if (t.contains('lluvia') ||
          t.contains('precaución') ||
          t.contains('demora')) {
        rutasStatus = "Precaución";
        rutasColor = Colors.amber;
      }
    }

    // 2. Abastecimiento
    String abastStatus = "Estable";
    Color abastColor = Colors.greenAccent;
    final abastItems = _allNewsItems.where((n) {
      final c = n.category.toLowerCase();
      return c.contains('proveedor') ||
          c.contains('abastecimiento') ||
          c.contains('precio');
    }).toList();

    for (var n in abastItems) {
      final t = '${n.title} ${n.impactAnalysis}'.toLowerCase();
      if (t.contains('desabastecimiento') ||
          t.contains('quiebre') ||
          t.contains('paro') ||
          t.contains('crítico')) {
        abastStatus = "Crítico";
        abastColor = Colors.redAccent;
        break;
      } else if (t.contains('demora') ||
          t.contains('alza') ||
          t.contains('ajuste') ||
          t.contains('parcial')) {
        abastStatus = "Demoras";
        abastColor = Colors.amber;
      }
    }

    // 3. Próxima Campaña
    final now = DateTime.now();
    final year = now.year;
    final campaigns = [
      {'name': 'Campaña Escolar', 'date': DateTime(year, 3, 1)},
      {'name': 'Día de la Madre', 'date': DateTime(year, 5, 10)},
      {'name': 'Día del Padre', 'date': DateTime(year, 6, 21)},
      {'name': 'Fiestas Patrias', 'date': DateTime(year, 7, 28)},
      {'name': 'Cyber Wow', 'date': DateTime(year, 10, 20)},
      {'name': 'Campaña Navideña', 'date': DateTime(year, 12, 24)},
      {'name': 'Campaña Escolar', 'date': DateTime(year + 1, 3, 1)},
    ];

    String campName = "Navidad";
    int daysLeft = 60;
    for (var c in campaigns) {
      final dt = c['date'] as DateTime;
      if (dt.isAfter(now)) {
        campName = c['name'] as String;
        daysLeft = dt.difference(now).inDays;
        break;
      }
    }

    return {
      'rutas': rutasStatus,
      'rutasColor': rutasColor,
      'abastecimiento': abastStatus,
      'abastColor': abastColor,
      'campana': campName,
      'dias': '$daysLeft d',
    };
  }

  @override
  Future<void> _launchUrl(String url) async {
    if (url.isEmpty) return;
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: "No se pudo abrir el enlace: $e",
          isError: true,
        );
      }
    }
  }

  @override
  void _shareAlert(CommercialNewsItem item) {
    final text =
        '''
ALERTA RADAR COMERCIAL - MOCHILALISTA
Zona: ${_selectedLocation.displayName} (${item.scopeLabel})
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

  @override
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

  @override
  Widget _buildPulseSliver(
    bool isDark,
    List<CommercialNewsItem> filtered,
    Map<String, dynamic> pulse,
  ) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                  : [Colors.white, const Color(0xFFE2E8F0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.grey[300]!,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) => Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.redAccent.withValues(
                          alpha: 0.15 + (_pulseController.value * 0.1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withValues(
                              alpha: 0.3 * _pulseController.value,
                            ),
                            blurRadius: 10 * _pulseController.value,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.radar_rounded,
                        color: Colors.redAccent,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      key: _tourKeys.sourceStatusKey,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(
                              CommercialRadarService.lastSourceMode.icon,
                              size: 11,
                              color:
                                  CommercialRadarService.lastSourceMode.color,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                CommercialRadarService.lastSourceMode.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: CommercialRadarService
                                      .lastSourceMode
                                      .color,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          "${filtered.length} alertas detectadas",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          "Monitoreo Logístico y Comercial",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Píldora de Región (con Key externa sin romper selector descendiente InkWell->Container)
                  KeyedSubtree(
                    key: _tourKeys.locationPickerKey,
                    child: InkWell(
                      onTap: () => _openRegionPicker(isDark),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.blueAccent.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 13,
                              color: Colors.blueAccent,
                            ),
                            const SizedBox(width: 4),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 90),
                              child: Text(
                                _selectedRegion,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueAccent,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(
                              Icons.keyboard_arrow_down,
                              size: 14,
                              color: Colors.blueAccent,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Semáforo de Pulso Operativo (con FittedBox para cero desborde)
              Container(
                key: _tourKeys.operationalPulseKey,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.25)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.grey[300]!,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildPulseItem(
                        icon: Icons.alt_route_rounded,
                        title: "Rutas/Fletes",
                        status: pulse['rutas'] as String,
                        statusColor: pulse['rutasColor'] as Color,
                        isDark: isDark,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 26,
                      color: isDark ? Colors.white12 : Colors.grey[300],
                    ),
                    Expanded(
                      child: _buildPulseItem(
                        icon: Icons.inventory_2_outlined,
                        title: "Abastecimiento",
                        status: pulse['abastecimiento'] as String,
                        statusColor: pulse['abastColor'] as Color,
                        isDark: isDark,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 26,
                      color: isDark ? Colors.white12 : Colors.grey[300],
                    ),
                    Expanded(
                      child: _buildPulseItem(
                        icon: Icons.celebration_outlined,
                        title: pulse['campana'] as String,
                        status: pulse['dias'] as String,
                        statusColor: Colors.blueAccent,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPulseItem({
    required IconData icon,
    required String title,
    required String status,
    required Color statusColor,
    required bool isDark,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                  maxLines: 1,
                  softWrap: false,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  softWrap: false,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
