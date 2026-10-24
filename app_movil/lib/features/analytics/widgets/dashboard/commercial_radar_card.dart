import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_movil/features/analytics/models/commercial_radar_model.dart';
import 'package:app_movil/features/analytics/services/commercial_radar_service.dart';
import 'package:app_movil/features/analytics/widgets/dashboard/glass_card.dart';

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

class _CommercialRadarCardState extends State<CommercialRadarCard> with SingleTickerProviderStateMixin {
  late String _selectedRegion;
  String _selectedCategory = 'Todas';
  bool _isLoading = true;
  final List<CommercialNewsItem> _newsItems = [];
  StreamSubscription<CommercialNewsItem>? _streamSubscription;
  late AnimationController _pulseController;

  final List<String> _categories = [
    'Todas',
    'Clima y Rutas',
    'Mi Región',
    'Leyes y SUNAT',
    'Campañas',
  ];

  static const String _prefRegionKey = 'commercial_radar_selected_region';
  static const List<String> _predefinedRegions = [
    'Talara, Piura',
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
      _newsItems.clear();
    });

    _streamSubscription = CommercialRadarService.streamCuratedNews(
      region: _selectedRegion,
      forceRefresh: forceRefresh,
    ).listen(
      (item) {
        if (mounted) {
          setState(() {
            _newsItems.add(item);
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
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefRegionKey, newRegion);
    } catch (_) {}
    _startRadarStream(forceRefresh: true);
  }

  void _openRegionPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          bottom: true,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: widget.isDark ? Colors.white24 : Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Enfoque Geográfico",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  "Sintoniza noticias, rutas, clima y mercado de tu localidad:",
                  style: TextStyle(
                    fontSize: 12, 
                    color: widget.isDark ? Colors.grey[400] : Colors.grey[600]
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ..._predefinedRegions.map((reg) {
                          final isSelected = reg == _selectedRegion;
                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                            leading: Icon(
                              reg == 'Todo el Perú' ? Icons.public : Icons.location_on,
                              color: isSelected ? Colors.blueAccent : Colors.grey,
                              size: 20,
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
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                          leading: const Icon(Icons.edit_location_alt, color: Colors.amberAccent, size: 20),
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
    switch (category) {
      case 'Clima y Rutas':
        return Icons.cloud_outlined;
      case 'Leyes y SUNAT':
        return Icons.gavel_rounded;
      case 'Campañas':
        return Icons.campaign_rounded;
      case 'Mi Región':
      default:
        return Icons.location_on_outlined;
    }
  }

  LinearGradient _getBannerGradient(String category) {
    switch (category) {
      case 'Clima y Rutas':
        return const LinearGradient(
          colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'Leyes y SUNAT':
        return const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF5B21B6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'Campañas':
        return const LinearGradient(
          colors: [Color(0xFFD97706), Color(0xFFB45309)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'Mi Región':
      default:
        return const LinearGradient(
          colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  List<CommercialNewsItem> get _filteredItems {
    if (_selectedCategory == 'Todas') return _newsItems;
    return _newsItems.where((item) => item.category == _selectedCategory).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems;

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
                    Row(
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
                    const SizedBox(height: 2),
                    Text(
                      "Alertas estratégicas para comerciantes en Perú",
                      style: TextStyle(
                        fontSize: 12, 
                        color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
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
          Row(
            children: [
              Text(
                "Enfoque Geográfico:",
                style: TextStyle(
                  fontSize: 12, 
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? Colors.grey[400] : Colors.grey[700],
                ),
              ),
              const SizedBox(width: 8),
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

          // News items or loading indicator
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
              children: filtered.asMap().entries.map((entry) {
                final item = entry.value;
                return _buildNewsCard(item);
              }).toList(),
            ),
        ],
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
          // Banner Clicable (Mandatory Technical Rule #2)
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
                // Category + Source + Region badge row
                Row(
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
                          Text(
                            item.category,
                            style: TextStyle(
                              fontSize: 10, 
                              fontWeight: FontWeight.bold, 
                              color: catColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.sourceName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.open_in_new, 
                      size: 14, 
                      color: widget.isDark ? Colors.white38 : Colors.grey[400],
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Title Clicable (Mandatory Technical Rule #2)
                GestureDetector(
                  onTap: () => _launchSourceUrl(item.sourceUrl),
                  child: Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                      color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Commercial Summary
                Text(
                  item.summary,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: widget.isDark ? Colors.grey[300] : Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 12),

                // Actionable Merchant Advice
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.isDark 
                        ? Colors.amber.withValues(alpha: 0.08) 
                        : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.amber.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    item.actionableAdvice,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                      color: widget.isDark ? Colors.amber[200] : const Color(0xFF92400E),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Leer fuente oficial button (Mandatory Technical Rule #2)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        visualDensity: VisualDensity.compact,
                        foregroundColor: Colors.blueAccent,
                      ),
                      icon: const Icon(Icons.arrow_outward, size: 14),
                      label: const Text(
                        "Leer fuente oficial ↗",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _launchSourceUrl(item.sourceUrl),
                    ),
                  ],
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
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
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.category.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                      letterSpacing: 1.0,
                    ),
                  ),
                  Text(
                    item.region,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
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
}
