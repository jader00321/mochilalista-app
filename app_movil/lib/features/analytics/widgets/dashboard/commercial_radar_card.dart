import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/features/analytics/models/commercial_radar_model.dart';
import 'package:app_movil/features/analytics/services/commercial_radar_service.dart';
import 'package:app_movil/features/analytics/widgets/dashboard/glass_card.dart';
import 'package:app_movil/features/analytics/screens/commercial_radar_screen.dart';
import 'package:app_movil/features/analytics/screens/smart_restock_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/workbench_screen.dart';
import 'package:app_movil/features/catalog/screens/inventory_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/quick_sale_screen.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

part 'commercial_radar_card/radar_card_header_and_pickers.dart';
part 'commercial_radar_card/radar_card_news_item.dart';

const List<String> _radarPredefinedRegions = [
  'Talara / Piura',
  'Piura / Región Norte',
  'Todo el Perú',
  'Lima',
  'Arequipa',
  'Trujillo',
  'Chiclayo',
  'Cusco',
];

class CommercialRadarCard extends StatefulWidget {
  final bool isDark;
  final String defaultRegion;
  final int? profileId;

  const CommercialRadarCard({
    super.key,
    required this.isDark,
    this.defaultRegion = 'Talara / Piura',
    this.profileId,
  });

  @override
  State<CommercialRadarCard> createState() => _CommercialRadarCardState();
}

abstract class _CommercialRadarCardStateBase extends State<CommercialRadarCard>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late String _selectedRegion;
  String _selectedCategory = 'Todas';
  bool _isLoading = true;
  final List<CommercialNewsItem> _newsItems = [];
  StreamSubscription<CommercialNewsItem>? _streamSubscription;
  late AnimationController _pulseController;
  int? _resolvedProfileId;
  bool _didInitProfileDependencies = false;

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
    _selectedRegion = widget.defaultRegion;
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
      _hydrateAndLoadForProfile(loadProfileId: nextProfileId);
    } else if (nextProfileId != _resolvedProfileId) {
      _switchActiveProfile(nextProfileId);
    }
  }

  @override
  void didUpdateWidget(covariant CommercialRadarCard oldWidget) {
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
      _selectedRegion = widget.defaultRegion;
      _newsItems.clear();
      _isLoading = true;
    });
    _hydrateAndLoadForProfile(loadProfileId: nextProfileId);
  }

  void _hydrateAndLoadForProfile({required int? loadProfileId}) {
    final cached = CommercialRadarService.getCachedNews(_selectedRegion);
    if (cached != null && cached.isNotEmpty) {
      _newsItems
        ..clear()
        ..addAll(cached);
      _isLoading = false;
    }
    _loadSavedRegion(profileId: loadProfileId);
  }

  Future<void> _loadSavedRegion({int? profileId}) async {
    final loadProfileId = profileId;
    try {
      final saved = await CommercialRadarService.loadRegionLabelForProfile(
        profileId: loadProfileId,
        defaultRegion: widget.defaultRegion,
      );
      if (!mounted || loadProfileId != _resolvedProfileId) return;
      if (saved.isNotEmpty) {
        setState(() {
          _selectedRegion = saved;
          if (_selectedRegion != widget.defaultRegion) {
            _newsItems.clear();
          }
        });
      }
    } catch (_) {}
    if (!mounted || loadProfileId != _resolvedProfileId) return;
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

  Future<void> _setRegion(String newRegion) async {
    final activeProfileId = _resolvedProfileId;
    setState(() {
      _selectedRegion = newRegion;
      _newsItems.clear();
    });
    await CommercialRadarService.saveRegionLabelForProfile(
      newRegion,
      profileId: activeProfileId,
    );
    if (!mounted || activeProfileId != _resolvedProfileId) return;
    _startRadarStream(forceRefresh: true);
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

  Widget _buildRadarCardBody(BuildContext context);
  Widget _buildNewsCard(CommercialNewsItem item);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _buildRadarCardBody(context);
  }
}

class _CommercialRadarCardState extends _CommercialRadarCardStateBase
    with _RadarCardHeaderAndPickersMixin, _RadarCardNewsItemMixin {}
