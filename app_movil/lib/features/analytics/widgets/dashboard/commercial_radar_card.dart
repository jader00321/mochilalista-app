import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:app_movil/features/analytics/models/commercial_radar_model.dart';
import 'package:app_movil/features/analytics/services/commercial_radar_service.dart';
import 'package:app_movil/features/analytics/widgets/dashboard/glass_card.dart';
import 'package:app_movil/features/analytics/screens/commercial_radar_screen.dart';
import 'package:app_movil/features/analytics/screens/smart_restock_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/workbench_screen.dart';
import 'package:app_movil/features/catalog/screens/inventory_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/quick_sale_screen.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

class CommercialRadarCard extends StatefulWidget {
  final bool isDark;
  final String defaultRegion;

  const CommercialRadarCard({
    super.key,
    required this.isDark,
    this.defaultRegion = 'Talara / Piura',
  });

  @override
  State<CommercialRadarCard> createState() => _CommercialRadarCardState();
}

class _CommercialRadarCardState extends State<CommercialRadarCard>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late String _selectedRegion;
  String _selectedCategory = 'Todas';
  bool _isLoading = true;
  final List<CommercialNewsItem> _newsItems = [];
  StreamSubscription<CommercialNewsItem>? _streamSubscription;
  late AnimationController _pulseController;

  final List<String> _categories = [
    'Todas',
    'Mi Región',
    'Clima y Rutas',
    'Leyes y SUNAT',
    'Proveedores y Abastecimiento',
    'Fechas y Campañas',
  ];

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

  @override
  void initState() {
    super.initState();
    _selectedRegion = widget.defaultRegion;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    // Cargar caché previo si existe para evitar saltos
    final cached = CommercialRadarService.getCachedNews(_selectedRegion);
    if (cached != null && cached.isNotEmpty) {
      _newsItems.addAll(cached);
      _isLoading = false;
    }
    _loadSavedRegion();
  }

  Future<void> _loadSavedRegion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefRegionKey);
      if (saved != null && saved.isNotEmpty && mounted) {
        setState(() {
          _selectedRegion = saved;
        });
      }
    } catch (_) {}
    _startRadarStream();
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startRadarStream({bool forceRefresh = false}) {
    _streamSubscription?.cancel();
    setState(() {
      _isLoading = true;
      if (forceRefresh) _newsItems.clear();
    });

    _streamSubscription = CommercialRadarService.streamCuratedNews(
      region: _selectedRegion,
      forceRefresh: forceRefresh,
    ).listen(
      (item) {
        if (mounted) {
          setState(() {
            final idx = _newsItems.indexWhere((n) => n.id == item.id);
            if (idx == -1) {
              _newsItems.add(item);
            } else {
              _newsItems[idx] = item;
            }
            _isLoading = false;
          });
        }
      },
      onError: (_) {
        if (mounted) setState(() => _isLoading = false);
      },
      onDone: () {
        if (mounted) setState(() => _isLoading = false);
      },
    );
  }

  Future<void> _launchSourceUrl(String url) async {
    if (url.isEmpty) return;
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Future<void> _setRegion(String newRegion) async {
    setState(() {
      _selectedRegion = newRegion;
      _newsItems.clear();
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefRegionKey, newRegion);
    } catch (_) {}
    _startRadarStream(forceRefresh: true);
  }

  void _openRegionPicker() {
    final sheetBg = widget.isDark ? const Color(0xFF1E293B) : Colors.white;

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return InteractiveSheetWrapper(
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
                          "Sintoniza noticias y mercado de tu localidad",
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
                              color: isSelected 
                                  ? Colors.blueAccent 
                                  : (widget.isDark ? Colors.white : Colors.black87),
                            ),
                          ),
                          trailing: isSelected 
                              ? const Icon(Icons.check_circle, color: Colors.blueAccent, size: 20) 
                              : null,
                          onTap: () {
                            Navigator.pop(ctx);
                            _setRegion(reg);
                          },
                        );
                      }),
                      const Divider(),
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.edit_location_alt, color: Colors.amber),
                        title: const Text(
                          "Otra / Personalizada...",
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber),
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          _promptCustomRegion();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _promptCustomRegion() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
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
              "Escribe tu ciudad, provincia o región en Perú:",
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: "Ej: Huancayo, Chimbote, Iquitos...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                _setRegion(val);
              }
            },
            child: const Text("Aplicar"),
          ),
        ],
      ),
    );
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

  List<CommercialNewsItem> get _filteredItems {
    if (_selectedCategory == 'Todas') return _newsItems;
    final catLower = _selectedCategory.toLowerCase();
    return _newsItems.where((item) {
      final iCat = item.category.toLowerCase();
      if (catLower.contains('clima') && (iCat.contains('clima') || iCat.contains('ruta'))) return true;
      if (catLower.contains('region') && (iCat.contains('region') || iCat.contains('región'))) return true;
      if (catLower.contains('sunat') && (iCat.contains('sunat') || iCat.contains('ley'))) return true;
      if (catLower.contains('proveedor') && (iCat.contains('proveedor') || iCat.contains('abastecimiento'))) return true;
      if (catLower.contains('campaña') && (iCat.contains('campaña') || iCat.contains('campana') || iCat.contains('fecha'))) return true;
      return item.category == _selectedCategory;
    }).toList();
  }

  int _rotationOffset = 0;

  void _rotateSignals() {
    final items = _filteredItems;
    if (items.isEmpty) return;
    setState(() {
      _rotationOffset = (_rotationOffset + 3) % items.length;
    });
  }

  List<CommercialNewsItem> _getRotatedPreview(List<CommercialNewsItem> items, int count) {
    if (items.isEmpty) return [];
    if (items.length <= count) return items;
    final result = <CommercialNewsItem>[];
    for (int i = 0; i < count; i++) {
      result.add(items[(_rotationOffset + i) % items.length]);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final filtered = _filteredItems;
    // Priorizar distintas categorías y rotar dinámicamente
    final diversified = CommercialRadarService.interleaveCategories(filtered);
    final previewItems = _getRotatedPreview(diversified, 3);

    return GlassCard(
      isDark: widget.isDark,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with radar pulse
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.redAccent.withValues(
                        alpha: 0.15 + (_pulseController.value * 0.15),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withValues(
                            alpha: 0.2 * _pulseController.value,
                          ),
                          blurRadius: 10 * _pulseController.value,
                          spreadRadius: 2 * _pulseController.value,
                        )
                      ],
                    ),
                    child: const Icon(Icons.radar, color: Colors.redAccent, size: 22),
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          const Text(
                            "Radar Comercial",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.4)),
                            ),
                            child: const Text(
                              "IA EN VIVO",
                              style: TextStyle(
                                fontSize: 9, 
                                fontWeight: FontWeight.bold, 
                                color: Colors.blueAccent,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Alertas estratégicas para comerciantes en Perú",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12, 
                        color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.shuffle_rounded, size: 20),
                tooltip: "Alternar señales",
                onPressed: filtered.length > 1 ? _rotateSignals : null,
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: "Actualizar señales de mercado",
                onPressed: () => _startRadarStream(forceRefresh: true),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Region Switcher Pill
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                "Enfoque Geográfico:",
                style: TextStyle(
                  fontSize: 12, 
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? Colors.grey[400] : Colors.grey[700],
                ),
              ),
              GestureDetector(
                onTap: _openRegionPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: widget.isDark ? Colors.white10 : Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: widget.isDark ? Colors.white24 : Colors.grey[300]!,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _selectedRegion.toLowerCase().contains('talara') || _selectedRegion.toLowerCase().contains('piura')
                            ? Icons.location_on 
                            : (_selectedRegion == 'Todo el Perú' ? Icons.public : Icons.location_city),
                        size: 14,
                        color: Colors.blueAccent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _selectedRegion,
                        style: const TextStyle(
                          fontSize: 12, 
                          fontWeight: FontWeight.bold, 
                          color: Colors.blueAccent,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down, size: 16, color: Colors.blueAccent),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Category filter pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                    selectedColor: Colors.blueAccent,
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected 
                          ? Colors.white 
                          : (widget.isDark ? Colors.grey[300] : Colors.grey[800]),
                    ),
                    backgroundColor: widget.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                    side: BorderSide(
                      color: isSelected ? Colors.blueAccent : (widget.isDark ? Colors.white12 : Colors.grey[300]!),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // News items or loading indicator (Máximo 2 noticias estables en Estadísticas)
          if (_isLoading && _newsItems.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32.0),
              child: Center(
                child: Column(
                  children: [
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Sintonizando señales de mercado en $_selectedRegion...",
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Text(
                  "No hay alertas en la categoría '$_selectedCategory' por el momento.",
                  style: TextStyle(
                    fontSize: 13,
                    color: widget.isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
              ),
            )
          else
            Column(
              children: [
                ...previewItems.map((item) => _buildNewsCard(item)),
                const SizedBox(height: 6),
                _buildOpenRadarButton(),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildOpenRadarButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent.withValues(alpha: widget.isDark ? 0.15 : 0.08),
          foregroundColor: Colors.blueAccent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.blueAccent, width: 1.2),
          ),
        ),
        icon: const Icon(Icons.newspaper_rounded, size: 20),
        label: const Text(
          "Explorar más noticias y alertas comerciales (Abrir Radar IA)",
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CommercialRadarScreen(initialRegion: _selectedRegion),
            ),
          );
        },
      ),
    );
  }

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
                          Text(
                            item.isLive ? "En Vivo Verificada" : "Guía Verificada",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: item.isLive 
                                  ? (widget.isDark ? const Color(0xFF34D399) : const Color(0xFF065F46))
                                  : (widget.isDark ? Colors.indigo[200] : Colors.indigo[800]),
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
