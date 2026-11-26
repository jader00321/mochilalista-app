import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/features/analytics/data/peru_ubigeo_catalog.dart';
import 'package:app_movil/features/analytics/models/commercial_radar_model.dart';
import 'package:app_movil/features/analytics/services/commercial_radar_service.dart';
import 'package:app_movil/features/analytics/screens/smart_restock_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/workbench_screen.dart';
import 'package:app_movil/features/catalog/screens/inventory_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/quick_sale_screen.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/core/services/tour/interactive_tour_service.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';
import 'package:app_movil/core/widgets/tour/configs/commercial_radar_tour.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';
import 'package:app_movil/features/analytics/screens/commercial_radar/location_picker_sheet.dart';

export 'package:app_movil/features/analytics/screens/commercial_radar/location_picker_sheet.dart';

part 'commercial_radar/radar_pulse_and_actions.dart';
part 'commercial_radar/radar_header_and_filters.dart';
part 'commercial_radar/radar_news_card.dart';

enum RadarTab { noticiasDelDia, guardadas }

class CommercialRadarScreen extends StatefulWidget {
  final String initialRegion;
  final bool autoTriggerTour;
  final CommercialRadarTourKeys? tourKeys;
  final int? profileId;

  const CommercialRadarScreen({
    super.key,
    this.initialRegion = 'Talara / Piura',
    this.autoTriggerTour = true,
    this.tourKeys,
    this.profileId,
  });

  @override
  State<CommercialRadarScreen> createState() => _CommercialRadarScreenState();
}

abstract class _CommercialRadarScreenStateBase
    extends State<CommercialRadarScreen>
    with SingleTickerProviderStateMixin {
  late RadarLocation _selectedLocation;
  String get _selectedRegion => _selectedLocation.displayName;
  late final CommercialRadarTourKeys _tourKeys;
  bool _didAttemptAutoTour = false;
  int? _resolvedProfileId;
  bool _didInitProfileDependencies = false;

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

  final List<String> _categories = [
    'Todas',
    'Mi Región',
    'Clima y Rutas',
    'Leyes y SUNAT',
    'Proveedores y Abastecimiento',
    'Fechas y Campañas',
  ];

  Map<String, dynamic> _calculateOperationalPulse();
  Future<void> _launchUrl(String url);
  void _shareAlert(CommercialNewsItem item);
  void _executeRadarAction(BuildContext context, RadarActionType type);
  Widget _buildPulseSliver(
    bool isDark,
    List<CommercialNewsItem> filtered,
    Map<String, dynamic> pulse,
  );
  Widget _buildStickyFilterSliver(
    bool isDark,
    Color bgColor,
    bool isNoticiasTab,
  );
  Widget _buildFeedSliver(
    bool isDark,
    List<CommercialNewsItem> filtered,
    List<CommercialNewsItem> paged,
  );
  Widget _buildNewsCard(CommercialNewsItem item, bool isDark);

  @override
  void initState() {
    super.initState();
    _tourKeys = widget.tourKeys ?? CommercialRadarTourKeys();
    _selectedLocation = RadarLocation.fromLegacyString(widget.initialRegion);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  int? _resolveActiveProfileId(BuildContext context) {
    if (widget.profileId != null) return widget.profileId;
    try {
      return Provider.of<AuthProvider?>(context)?.activeUserId;
    } catch (_) {
      return null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextProfileId = _resolveActiveProfileId(context);
    if (!_didInitProfileDependencies) {
      _didInitProfileDependencies = true;
      _resolvedProfileId = nextProfileId;
      _loadSavedData(profileId: _resolvedProfileId);
    } else if (nextProfileId != _resolvedProfileId) {
      _switchActiveProfile(nextProfileId);
    }
  }

  @override
  void didUpdateWidget(covariant CommercialRadarScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.profileId != oldWidget.profileId) {
      final nextProfileId = _resolveActiveProfileId(context);
      if (nextProfileId != _resolvedProfileId) {
        _switchActiveProfile(nextProfileId);
      }
    }
  }

  void _switchActiveProfile(int? nextProfileId) {
    _streamSubscription?.cancel();
    setState(() {
      _resolvedProfileId = nextProfileId;
      _selectedLocation = RadarLocation.fromLegacyString(widget.initialRegion);
      _allNewsItems.clear();
      _savedNewsMap.clear();
      _visibleCount = 6;
      _isLoading = true;
    });
    _loadSavedData(profileId: nextProfileId);
  }

  ScreenTourConfig _buildTourConfig() {
    return CommercialRadarTour.buildConfig(keys: _tourKeys);
  }

  void _startTour(BuildContext context) {
    InteractiveTourService.startManualTour(context, _buildTourConfig());
  }

  void _maybeScheduleAutoTour() {
    if (!widget.autoTriggerTour || _didAttemptAutoTour) return;
    _didAttemptAutoTour = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await InteractiveTourService.maybeStartAutomaticTour(
        context,
        _buildTourConfig(),
      );
    });
  }

  Future<void> _loadSavedData({int? profileId}) async {
    final loadProfileId = profileId;
    final fallbackLocation = RadarLocation.fromLegacyString(
      widget.initialRegion,
    );
    try {
      final resolvedLocation =
          await CommercialRadarService.loadLocationForProfile(
            profileId: loadProfileId,
            fallback: fallbackLocation,
          );
      if (!mounted || loadProfileId != _resolvedProfileId) return;

      final savedList = await CommercialRadarService.getSavedNews(
        profileId: loadProfileId,
      );
      if (!mounted || loadProfileId != _resolvedProfileId) return;

      setState(() {
        _selectedLocation = resolvedLocation;
        _savedNewsMap.clear();
        for (var item in savedList) {
          _savedNewsMap[item.id] = item;
        }
      });
    } catch (_) {}
    if (!mounted || loadProfileId != _resolvedProfileId) return;
    _fetchNews(forceRefresh: false);
    _maybeScheduleAutoTour();
  }

  Future<void> _toggleBookmark(CommercialNewsItem item) async {
    final activeProfileId = _resolvedProfileId;
    final wasSaved = _savedNewsMap.containsKey(item.id);
    setState(() {
      if (wasSaved) {
        _savedNewsMap.remove(item.id);
      } else {
        _savedNewsMap[item.id] = item;
      }
    });

    if (wasSaved) {
      await CommercialRadarService.removeSavedNews(
        item.id,
        profileId: activeProfileId,
      );
      if (mounted) {
        CustomSnackBar.show(context, message: "Noticia retirada de Guardadas");
      }
    } else {
      await CommercialRadarService.saveNewsItem(
        item,
        profileId: activeProfileId,
      );
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
    final cached = CommercialRadarService.getCachedNewsForLocation(
      _selectedLocation,
    );
    if (cached != null && cached.isNotEmpty && _allNewsItems.isEmpty) {
      _allNewsItems.addAll(cached);
    }

    _streamSubscription =
        CommercialRadarService.streamCuratedNews(
          location: _selectedLocation,
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
                    message:
                        "Radar actualizado con las últimas señales del día",
                  );
                }
              }
            }
          },
        );
  }

  void _changeLocation(RadarLocation newLocation) {
    if (newLocation == _selectedLocation) return;
    final activeProfileId = _resolvedProfileId;
    setState(() {
      _selectedLocation = newLocation;
      _visibleCount = 6;
      _allNewsItems.clear();
    });
    unawaited(
      CommercialRadarService.saveLocationForProfile(
        newLocation,
        profileId: activeProfileId,
      ),
    );
    _fetchNews(forceRefresh: true);
  }

  void _openRegionPicker(bool isDark) {
    final sheetBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LocationPickerSheet(
        isDark: isDark,
        sheetBg: sheetBg,
        currentLocation: _selectedLocation,
        onLocationSelected: (loc) {
          Navigator.pop(ctx);
          _changeLocation(loc);
        },
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
          return itemCat.contains('región') ||
              itemCat.contains('region') ||
              item.scope == RadarNewsScope.local ||
              item.scope == RadarNewsScope.regional ||
              item.region.toLowerCase().contains(
                _selectedLocation.province.toLowerCase(),
              ) ||
              item.region.toLowerCase().contains(
                _selectedLocation.department.toLowerCase(),
              );
        }
        if (targetCat.contains('clima') || targetCat.contains('ruta')) {
          return itemCat.contains('clima') || itemCat.contains('ruta');
        }
        if (targetCat.contains('sunat') || targetCat.contains('ley')) {
          return itemCat.contains('sunat') || itemCat.contains('ley');
        }
        if (targetCat.contains('proveedor') ||
            targetCat.contains('abastecimiento')) {
          return itemCat.contains('proveedor') ||
              itemCat.contains('abastecimiento');
        }
        if (targetCat.contains('campaña') ||
            targetCat.contains('campana') ||
            targetCat.contains('fecha')) {
          return itemCat.contains('campaña') ||
              itemCat.contains('campana') ||
              itemCat.contains('fecha');
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
        leadingWidth: 38,
        actionsPadding: EdgeInsets.zero,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                "Radar Comercial IA",
                maxLines: 1,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            Text(
              "Señales de mercado • $_selectedRegion",
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.blueAccent[100] : Colors.blueAccent[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          InfoTooltipButton(
            iconColor: isDark ? Colors.white70 : Colors.black54,
            iconSize: 20,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            onStartInteractiveTour: () => _startTour(context),
            title: "Radar Comercial IA",
            description:
                "Monitorea alertas reales sobre clima y rutas logísticas, abastecimiento, leyes SUNAT y campañas comerciales según tu ubicación geográfica.",
            tips: const [
              InfoTip(
                icon: Icons.location_on_outlined,
                text:
                    "Selecciona Departamento, Provincia y Distrito/Localidad para priorizar fuentes locales y regionales.",
              ),
              InfoTip(
                icon: Icons.traffic_outlined,
                text:
                    "El Semáforo Operativo evalúa Rutas/Fletes, Abastecimiento y los días para la próxima campaña.",
              ),
              InfoTip(
                icon: Icons.bookmarks_outlined,
                text:
                    "Guarda cualquier señal relevante para consultarla después sin conexión en la pestaña Guardadas.",
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            tooltip: "Actualizar noticias",
            onPressed: () => _fetchNews(forceRefresh: true),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _fetchNews(forceRefresh: true),
        color: Colors.blueAccent,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            _buildPulseSliver(isDark, filtered, pulse),
            _buildStickyFilterSliver(isDark, bgColor, isNoticiasTab),
            _buildFeedSliver(isDark, filtered, paged),
            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.paddingOf(context).bottom + 24.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommercialRadarScreenState extends _CommercialRadarScreenStateBase
    with
        _RadarPulseAndActionsMixin,
        _RadarHeaderAndFiltersMixin,
        _RadarNewsCardMixin {}
