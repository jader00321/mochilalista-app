import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import 'package:app_movil/features/analytics/models/commercial_radar_model.dart';
import 'package:app_movil/features/analytics/services/commercial_radar_service.dart';
import 'package:app_movil/features/analytics/screens/smart_restock_screen.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';

enum RadarTab { noticiasDelDia, guardadas }

class CommercialRadarScreen extends StatefulWidget {
  final String initialRegion;

  const CommercialRadarScreen({
    super.key,
    this.initialRegion = 'Talara / Piura',
  });

  @override
  State<CommercialRadarScreen> createState() => _CommercialRadarScreenState();
}

class _CommercialRadarScreenState extends State<CommercialRadarScreen> with SingleTickerProviderStateMixin {
  late String _selectedRegion;
  RadarTab _activeTab = RadarTab.noticiasDelDia;
  String _selectedCategory = 'Todas';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  final List<CommercialNewsItem> _allNewsItems = [];
  final Map<String, CommercialNewsItem> _savedNewsMap = {};
  int _visibleCount = 6;
  StreamSubscription<CommercialNewsItem>? _streamSubscription;
  late AnimationController _pulseController;

  static const String _prefRegionKey = 'commercial_radar_selected_region';
  static const List<String> _predefinedRegions = [
    'Talara / Piura',
    'Piura / Región Norte',
    'Todo el Perú',
    'Lima',
    'Arequipa',
    'Trujillo',
    'Chiclayo',
    'Cusco',
  ];

  final List<String> _categories = [
    'Todas',
    'Mi Región',
    'Clima y Rutas',
    'Leyes y SUNAT',
    'Proveedores y Abastecimiento',
    'Fechas y Campañas',
  ];

  @override
  void initState() {
    super.initState();
    _selectedRegion = widget.initialRegion;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedReg = prefs.getString(_prefRegionKey);
      if (savedReg != null && savedReg.isNotEmpty && mounted) {
        setState(() {
          _selectedRegion = savedReg;
        });
      }

      final savedList = await CommercialRadarService.getSavedNews();
      if (mounted) {
        setState(() {
          _savedNewsMap.clear();
          for (var item in savedList) {
            _savedNewsMap[item.id] = item;
          }
        });
      }
    } catch (_) {}
    _fetchNews(forceRefresh: false);
  }

  Future<void> _toggleBookmark(CommercialNewsItem item) async {
    final wasSaved = _savedNewsMap.containsKey(item.id);
    setState(() {
      if (wasSaved) {
        _savedNewsMap.remove(item.id);
      } else {
        _savedNewsMap[item.id] = item;
      }
    });

    if (wasSaved) {
      await CommercialRadarService.removeSavedNews(item.id);
      if (mounted) {
        CustomSnackBar.show(context, message: "Noticia retirada de Guardadas");
      }
    } else {
      await CommercialRadarService.saveNewsItem(item);
      if (mounted) {
        CustomSnackBar.show(context, message: "Noticia guardada en favoritos");
      }
    }
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _pulseController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _fetchNews({bool forceRefresh = false}) {
    _streamSubscription?.cancel();
    setState(() {
      _isLoading = true;
      if (forceRefresh) {
        _visibleCount = 6;
      }
    });

    // Cargar caché si existe para evitar pantalla vacía
    final cached = CommercialRadarService.getCachedNews(_selectedRegion);
    if (cached != null && cached.isNotEmpty && _allNewsItems.isEmpty) {
      _allNewsItems.addAll(cached);
    }

    _streamSubscription = CommercialRadarService.streamCuratedNews(
      region: _selectedRegion,
      forceRefresh: forceRefresh,
    ).listen(
      (item) {
        if (mounted) {
          setState(() {
            final idx = _allNewsItems.indexWhere((n) => n.id == item.id);
            if (idx == -1) {
              _allNewsItems.add(item);
            } else {
              _allNewsItems[idx] = item;
            }
            _isLoading = false;
          });
        }
      },
      onError: (_) {
        if (mounted) setState(() => _isLoading = false);
      },
      onDone: () {
        if (mounted) {
          setState(() => _isLoading = false);
          if (forceRefresh) {
            final newCount = CommercialRadarService.lastNewSignalsCount;
            if (newCount > 0) {
              CustomSnackBar.show(
                context,
                message: "$newCount nuevas señales agregadas al radar",
              );
            } else {
              CustomSnackBar.show(
                context,
                message: "Radar actualizado con las últimas señales del día",
              );
            }
          }
        }
      },
    );
  }

  Future<void> _launchUrl(String url) async {
    if (url.isEmpty) return;
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(context, message: "No se pudo abrir el enlace: $e", isError: true);
      }
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

  Future<void> _changeRegion(String newRegion) async {
    setState(() {
      _selectedRegion = newRegion;
      _visibleCount = 6;
      _allNewsItems.clear();
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefRegionKey, newRegion);
    } catch (_) {}
    _fetchNews(forceRefresh: true);
  }

  void _openRegionPicker(bool isDark) {
    final sheetBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => InteractiveSheetWrapper(
        backgroundColor: sheetBg,
        maxHeightFactor: 0.85,
        applyEffectiveBottomPadding: true,
        showHandle: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.location_on, color: Colors.blueAccent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Enfoque Geográfico", 
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        "Sintoniza noticias, rutas y clima de tu localidad",
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: InteractiveSheetWrapper.kModalScrollBottomClearance),
                  children: [
                    ..._predefinedRegions.map((reg) {
                      final isSelected = reg == _selectedRegion;
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          reg == 'Todo el Perú' ? Icons.public : Icons.location_city,
                          color: isSelected ? Colors.blueAccent : Colors.grey,
                        ),
                        title: Text(
                          reg,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? Colors.blueAccent : (isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                        trailing: isSelected 
                            ? const Icon(Icons.check_circle, color: Colors.blueAccent, size: 20) 
                            : null,
                        onTap: () {
                          Navigator.pop(ctx);
                          _changeRegion(reg);
                        },
                      );
                    }),
                    const Divider(),
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.edit_location_alt, color: Colors.amber),
                      title: const Text(
                        "Otra Ciudad o Región...", 
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        _promptCustomRegion(isDark);
                      },
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

  void _promptCustomRegion(bool isDark) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.location_city, color: Colors.blueAccent),
            SizedBox(width: 8),
            Text("Ciudad o Región", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Escribe tu ciudad o provincia para sintonizar noticias locales:",
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: "Ej: Huancayo, Chiclayo, Iquitos...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              final val = textController.text.trim();
              if (val.isNotEmpty) {
                Navigator.pop(dlgCtx);
                _changeRegion(val);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Aplicar"),
          ),
        ],
      ),
    );
  }

  List<CommercialNewsItem> _getFilteredNews() {
    List<CommercialNewsItem> baseList;

    if (_activeTab == RadarTab.guardadas) {
      baseList = _savedNewsMap.values.toList();
    } else if (_selectedCategory == 'Todas') {
      baseList = _allNewsItems;
    } else {
      final targetCat = _selectedCategory.toLowerCase();
      baseList = _allNewsItems.where((item) {
        final itemCat = item.category.toLowerCase();
        if (targetCat.contains('región') || targetCat.contains('region')) {
          return itemCat.contains('región') || itemCat.contains('region') || item.region == _selectedRegion;
        }
        if (targetCat.contains('clima') || targetCat.contains('ruta')) {
          return itemCat.contains('clima') || itemCat.contains('ruta');
        }
        if (targetCat.contains('sunat') || targetCat.contains('ley')) {
          return itemCat.contains('sunat') || itemCat.contains('ley');
        }
        if (targetCat.contains('proveedor') || targetCat.contains('abastecimiento')) {
          return itemCat.contains('proveedor') || itemCat.contains('abastecimiento');
        }
        if (targetCat.contains('campaña') || targetCat.contains('campana') || targetCat.contains('fecha')) {
          return itemCat.contains('campaña') || itemCat.contains('campana') || itemCat.contains('fecha');
        }
        return itemCat.contains(targetCat);
      }).toList();
    }

    if (_searchQuery.trim().isEmpty) {
      return baseList;
    }

    final query = _searchQuery.trim().toLowerCase();
    return baseList.where((item) {
      return item.title.toLowerCase().contains(query) ||
          item.summary.toLowerCase().contains(query) ||
          item.impactAnalysis.toLowerCase().contains(query) ||
          item.actionableAdvice.toLowerCase().contains(query) ||
          item.sourceName.toLowerCase().contains(query);
    }).toList();
  }

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
      if (t.contains('quebrada') || t.contains('cierre') || t.contains('bloqueo') || t.contains('aislamiento')) {
        rutasStatus = "Alerta";
        rutasColor = Colors.redAccent;
        break;
      } else if (t.contains('lluvia') || t.contains('precaución') || t.contains('demora')) {
        rutasStatus = "Precaución";
        rutasColor = Colors.amber;
      }
    }

    // 2. Abastecimiento
    String abastStatus = "Estable";
    Color abastColor = Colors.greenAccent;
    final abastItems = _allNewsItems.where((n) {
      final c = n.category.toLowerCase();
      return c.contains('proveedor') || c.contains('abastecimiento') || c.contains('precio');
    }).toList();

    for (var n in abastItems) {
      final t = '${n.title} ${n.impactAnalysis}'.toLowerCase();
      if (t.contains('desabastecimiento') || t.contains('quiebre') || t.contains('paro') || t.contains('crítico')) {
        abastStatus = "Crítico";
        abastColor = Colors.redAccent;
        break;
      } else if (t.contains('demora') || t.contains('alza') || t.contains('ajuste') || t.contains('parcial')) {
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

  IconData _getCategoryChipIcon(String category) {
    final cat = category.toLowerCase();
    if (cat == 'todas') return Icons.public_rounded;
    if (cat.contains('región') || cat.contains('region')) return Icons.location_on_outlined;
    if (cat.contains('clima') || cat.contains('ruta')) return Icons.wb_cloudy_outlined;
    if (cat.contains('ley') || cat.contains('sunat')) return Icons.gavel_rounded;
    if (cat.contains('proveedor') || cat.contains('abastecimiento')) return Icons.local_shipping_outlined;
    if (cat.contains('campaña') || cat.contains('campana') || cat.contains('fecha')) return Icons.event_available_outlined;
    return Icons.label_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    final filtered = _getFilteredNews();
    final paged = filtered.take(_visibleCount).toList();
    final pulse = _calculateOperationalPulse();
    final isNoticiasTab = _activeTab == RadarTab.noticiasDelDia;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        leadingWidth: 40,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Radar Comercial IA",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.3),
            ),
            Text(
              "Señales de mercado • $_selectedRegion",
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.blueAccent[100] : Colors.blueAccent[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 22),
            tooltip: "Actualizar noticias",
            onPressed: () => _fetchNews(forceRefresh: true),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _fetchNews(forceRefresh: true),
        color: Colors.blueAccent,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            // Sliver 1: Panel Superior de Monitoreo + Semáforo de Pulso Operativo
            SliverToBoxAdapter(
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
                    border: Border.all(color: isDark ? Colors.white12 : Colors.grey[300]!),
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
                                color: Colors.redAccent.withValues(alpha: 0.15 + (_pulseController.value * 0.1)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.redAccent.withValues(alpha: 0.3 * _pulseController.value),
                                    blurRadius: 10 * _pulseController.value,
                                    spreadRadius: 2,
                                  )
                                ],
                              ),
                              child: const Icon(Icons.radar_rounded, color: Colors.redAccent, size: 24),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      "IA EN VIVO",
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.redAccent),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.greenAccent),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      "${filtered.length} alertas detectadas",
                                      style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  "Monitoreo Logístico y Comercial",
                                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          // Píldora de Región
                          InkWell(
                            onTap: () => _openRegionPicker(isDark),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.35)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.location_on, size: 13, color: Colors.blueAccent),
                                  const SizedBox(width: 4),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 90),
                                    child: Text(
                                      _selectedRegion,
                                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(Icons.keyboard_arrow_down, size: 14, color: Colors.blueAccent),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Semáforo de Pulso Operativo (con FittedBox para cero desborde)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black.withValues(alpha: 0.25) : Colors.grey[100],
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!),
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
                            Container(width: 1, height: 26, color: isDark ? Colors.white12 : Colors.grey[300]),
                            Expanded(
                              child: _buildPulseItem(
                                icon: Icons.inventory_2_outlined,
                                title: "Abastecimiento",
                                status: pulse['abastecimiento'] as String,
                                statusColor: pulse['abastColor'] as Color,
                                isDark: isDark,
                              ),
                            ),
                            Container(width: 1, height: 26, color: isDark ? Colors.white12 : Colors.grey[300]),
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
            ),

            // Sliver 2: Sticky Header Pinned con Pestañas Segmentadas, Buscador y Chips de Categoría
            SliverPersistentHeader(
              pinned: true,
              delegate: _RadarStickyHeaderDelegate(
                height: isNoticiasTab ? 142.0 : 96.0,
                child: Container(
                  color: bgColor,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Pestaña Segmentada Superior: Noticias del Día vs Guardadas (X)
                      Container(
                        height: 38,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.black.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _activeTab = RadarTab.noticiasDelDia;
                                  _visibleCount = 6;
                                }),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _activeTab == RadarTab.noticiasDelDia
                                        ? Colors.blueAccent
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.radar_rounded,
                                        size: 15,
                                        color: _activeTab == RadarTab.noticiasDelDia
                                            ? Colors.white
                                            : (isDark ? Colors.grey[400] : Colors.grey[700]),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        "Noticias del Día",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: _activeTab == RadarTab.noticiasDelDia
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          color: _activeTab == RadarTab.noticiasDelDia
                                              ? Colors.white
                                              : (isDark ? Colors.grey[400] : Colors.grey[700]),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _activeTab = RadarTab.guardadas;
                                  _visibleCount = 6;
                                }),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: _activeTab == RadarTab.guardadas
                                        ? Colors.blueAccent
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.bookmarks_rounded,
                                        size: 15,
                                        color: _activeTab == RadarTab.guardadas
                                            ? Colors.white
                                            : (isDark ? Colors.grey[400] : Colors.grey[700]),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        "Guardadas (${_savedNewsMap.length})",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: _activeTab == RadarTab.guardadas
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          color: _activeTab == RadarTab.guardadas
                                              ? Colors.white
                                              : (isDark ? Colors.grey[400] : Colors.grey[700]),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Buscador en Tiempo Real
                      Container(
                        height: 36,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? Colors.white12 : Colors.grey[300]!),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() => _searchQuery = val),
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black87),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                            border: InputBorder.none,
                            hintText: "Buscar noticias, rutas, SUNAT...",
                            hintStyle: TextStyle(fontSize: 11.5, color: isDark ? Colors.grey[500] : Colors.grey[400]),
                            prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            prefixIcon: const Icon(Icons.search, size: 17, color: Colors.blueAccent),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? GestureDetector(
                                    onTap: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                    child: const Icon(Icons.close, size: 16, color: Colors.grey),
                                  )
                                : null,
                          ),
                        ),
                      ),

                      // Chips de Categorías Vectoriales Limpios (Solo si está en Noticias del Día)
                      if (isNoticiasTab) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 34,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: _categories.map((cat) {
                                final isSelected = _selectedCategory == cat;
                                final iconData = _getCategoryChipIcon(cat);
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    avatar: Icon(
                                      iconData,
                                      size: 13,
                                      color: isSelected ? Colors.white : Colors.blueAccent,
                                    ),
                                    labelPadding: const EdgeInsets.only(left: 2, right: 4),
                                    label: Text(
                                      cat,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[800]),
                                      ),
                                    ),
                                    selected: isSelected,
                                    onSelected: (_) => setState(() {
                                      _selectedCategory = cat;
                                      _visibleCount = 6;
                                    }),
                                    selectedColor: Colors.blueAccent,
                                    backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.grey[200],
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      side: BorderSide(
                                        color: isSelected ? Colors.blueAccent : (isDark ? Colors.white10 : Colors.grey[300]!),
                                      ),
                                    ),
                                    showCheckmark: false,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Sliver 3: Feed de Alertas con Staggered Streaming
            if (_isLoading && _allNewsItems.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Colors.blueAccent),
                      SizedBox(height: 16),
                      Text("Sintonizando radar con inteligencia artificial...", style: TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                ),
              )
            else if (filtered.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _activeTab == RadarTab.guardadas ? Icons.bookmarks_outlined : Icons.radar_outlined,
                        size: 48,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _activeTab == RadarTab.guardadas
                            ? "No tienes noticias guardadas aún"
                            : "No se encontraron noticias con los filtros actuales",
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index < paged.length) {
                        return _buildNewsCard(paged[index], isDark);
                      } else if (paged.length < filtered.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _visibleCount += 6;
                                });
                              },
                              icon: const Icon(Icons.add, size: 16),
                              label: Text("Cargar más señales (${filtered.length - paged.length} restantes)"),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.blueAccent,
                                side: const BorderSide(color: Colors.blueAccent),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                            ),
                          ),
                        );
                      }
                      return null;
                    },
                    childCount: paged.length < filtered.length ? paged.length + 1 : paged.length,
                  ),
                ),
              ),
          ],
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
                Icon(icon, size: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
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
                  decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
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

  Widget _buildNewsCard(CommercialNewsItem item, bool isDark) {
    final catColor = _getCategoryColor(item.category);
    final catIcon = _getCategoryIcon(item.category);
    final isBookmarked = _savedNewsMap.containsKey(item.id);
    final bool isLogisticsOrSupply = item.category.toLowerCase().contains('proveedor') ||
        item.category.toLowerCase().contains('abastecimiento') ||
        item.category.toLowerCase().contains('clima') ||
        item.category.toLowerCase().contains('ruta');

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
          // Banner Clicable con degradado temático + Acciones Rápidas
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [catColor.withValues(alpha: 0.85), catColor.withValues(alpha: 0.6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                Icon(catIcon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.category.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
                      letterSpacing: 0.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: Icon(
                    isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    color: Colors.white,
                    size: 20,
                  ),
                  tooltip: isBookmarked ? "Quitar de Guardadas" : "Guardar en Favoritos",
                  onPressed: () => _toggleBookmark(item),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(Icons.open_in_new, color: Colors.white70, size: 18),
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
                // Metadata: Medio Verificado + Fecha y Antigüedad
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.blue[400]! : Colors.blue[700]!).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.sourceName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.blue[300] : Colors.blue[800],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          item.compactTimeAgo,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                        ),
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
                      color: isDark ? Colors.orange.withValues(alpha: 0.1) : const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.local_shipping_outlined, color: Colors.orange, size: 18),
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
                                  color: isDark ? Colors.orange[100] : const Color(0xFF9A3412),
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
                    color: isDark ? Colors.green.withValues(alpha: 0.1) : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline, color: Colors.green, size: 18),
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
                                color: isDark ? Colors.green[100] : const Color(0xFF065F46),
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
                Row(
                  children: [
                    if (isLogisticsOrSupply)
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.inventory_2_outlined, size: 15),
                          label: const Text(
                            "Revisar Stock Crítico",
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const SmartRestockScreen()));
                          },
                        ),
                      )
                    else
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            visualDensity: VisualDensity.compact,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.checklist_rounded, size: 15),
                          label: const Text(
                            "Ir a Mesa de Trabajo",
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () {
                            CustomSnackBar.show(context, message: "Aperturando mesa de trabajo comercial...");
                          },
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
                ),
                const SizedBox(height: 8),

                // Botón Leer Fuente Oficial
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    ),
                    onPressed: () => _launchUrl(item.sourceUrl),
                    icon: const Icon(Icons.link, size: 16),
                    label: Text("Leer fuente original (${item.sourceName})"),
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
    if (lower.contains('clima') || lower.contains('ruta')) return const Color(0xFF0284C7);
    if (lower.contains('ley') || lower.contains('sunat')) return const Color(0xFF7C3AED);
    if (lower.contains('proveedor') || lower.contains('abastecimiento')) return const Color(0xFFD97706);
    if (lower.contains('campaña') || lower.contains('campana') || lower.contains('fecha')) return const Color(0xFFE11D48);
    return const Color(0xFF059669);
  }

  IconData _getCategoryIcon(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('clima') || lower.contains('ruta')) return Icons.wb_cloudy_outlined;
    if (lower.contains('ley') || lower.contains('sunat')) return Icons.gavel_rounded;
    if (lower.contains('proveedor') || lower.contains('abastecimiento')) return Icons.local_shipping_outlined;
    if (lower.contains('campaña') || lower.contains('campana') || lower.contains('fecha')) return Icons.event_available_outlined;
    return Icons.location_on_outlined;
  }
}

/// Delegate rígido para Sticky Header de CommercialRadarScreen (0 píxeles de overflow)
class _RadarStickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  const _RadarStickyHeaderDelegate({required this.child, this.height = 98.0});

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _RadarStickyHeaderDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.height != height;
  }
}
