import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Providers
import 'package:app_movil/features/scanner/providers/scanner_provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/smart_quotation_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';

// Pantallas
import 'package:app_movil/features/scanner/screens/scan_screen.dart';
import 'package:app_movil/features/scanner/widgets/shared/scanning_dialog.dart';
import 'package:app_movil/features/smart_quotation/screens/manual_quotation_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/crm/client_tracking_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/crm/loyalty_center_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/matching_screen.dart';
import 'package:app_movil/features/scanner/screens/invoice_review_screen.dart';
import 'package:app_movil/features/scanner/screens/invoice_staging_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/quick_sale_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/sales_history_screen.dart';
import 'package:app_movil/features/analytics/screens/analytics_dashboard_screen.dart';
import 'package:app_movil/features/analytics/screens/commercial_radar_screen.dart';
import 'package:app_movil/features/catalog/screens/product_create_screen.dart';
import 'package:app_movil/core/screens/db_inspector_screen.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/core/providers/license_provider.dart';
import 'package:app_movil/features/auth/widgets/soft_lock_renewal_modal.dart';

part 'smart_action_grid/smart_action_grid_definitions_mixin.dart';
part 'smart_action_grid/smart_action_grid_cards_mixin.dart';
part 'smart_action_grid/smart_action_grid_studio_cards_mixin.dart';
part 'smart_action_grid/smart_action_grid_modals_and_trays_mixin.dart';

/// Definición de metadatos estáticos y callbacks de una tarjeta de acción.
class _ActionCardDef {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color Function(bool isDark) colorBuilder;
  final Widget? Function(BuildContext context, bool isDark) badgeBuilder;
  final VoidCallback Function(BuildContext context, bool isDark) onTapBuilder;
  final VoidCallback? Function(BuildContext context, bool isDark)?
  onLongPressBuilder;

  const _ActionCardDef({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colorBuilder,
    required this.badgeBuilder,
    required this.onTapBuilder,
    this.onLongPressBuilder,
  });
}

class SmartActionGrid extends StatefulWidget {
  final Function(int)? onNavigateToTab;
  final Key? tourKey;

  const SmartActionGrid({super.key, this.onNavigateToTab, this.tourKey});

  @override
  State<SmartActionGrid> createState() => _SmartActionGridState();
}

abstract class _SmartActionGridStateBase extends State<SmartActionGrid>
    with SingleTickerProviderStateMixin {
  bool _isEditing = false;
  List<String> _orderedCardIds = [];
  final Set<String> _hiddenCardIds = {};
  int _columnsDensity = 2; // 2 = Amplia, 3 = Compacta
  String? _heroCardId; // ID de la tarjeta destacada Hero
  bool _prefsLoaded = false;
  String? _lastLoadedBusinessId;

  late AnimationController _editPulseController;

  @override
  void initState() {
    super.initState();
    _editPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = Provider.of<AuthProvider>(context, listen: true);
    final businessId = auth.activeBusinessId?.toString() ?? 'global';
    if (_lastLoadedBusinessId != businessId) {
      _lastLoadedBusinessId = businessId;
      _loadCustomizations(businessId);
    }
  }

  @override
  void dispose() {
    _editPulseController.dispose();
    super.dispose();
  }

  // Claves de SharedPreferences
  String _orderKey(String bizId) => 'home_studio_order_$bizId';
  String _hiddenKey(String bizId) => 'home_studio_hidden_$bizId';
  String _densityKey(String bizId) => 'home_studio_density_$bizId';
  String _heroKey(String bizId) => 'home_studio_hero_$bizId';

  Future<void> _loadCustomizations(String bizId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedOrder = prefs.getStringList(_orderKey(bizId));
      final savedHidden = prefs.getStringList(_hiddenKey(bizId));
      final savedDensity = prefs.getInt(_densityKey(bizId)) ?? 2;
      final savedHero = prefs.getString(_heroKey(bizId));

      final defaultIds = _getDefaultCardIds();

      if (mounted) {
        setState(() {
          if (savedOrder != null && savedOrder.isNotEmpty) {
            // Mantener IDs válidos y añadir nuevos que pudieran faltar
            final validIds = savedOrder
                .where((id) => defaultIds.contains(id))
                .toList();
            for (final dId in defaultIds) {
              if (!validIds.contains(dId)) {
                validIds.add(dId);
              }
            }
            _orderedCardIds = validIds;
          } else {
            _orderedCardIds = List.from(defaultIds);
          }

          _hiddenCardIds.clear();
          if (savedHidden != null) {
            _hiddenCardIds.addAll(
              savedHidden.where((id) => defaultIds.contains(id)),
            );
          }

          _columnsDensity = (savedDensity == 3) ? 3 : 2;
          _heroCardId = (savedHero != null && defaultIds.contains(savedHero))
              ? savedHero
              : null;
          _prefsLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _orderedCardIds = List.from(_getDefaultCardIds());
          _prefsLoaded = true;
        });
      }
    }
  }

  Future<void> _saveCustomizations() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final bizId = auth.activeBusinessId?.toString() ?? 'global';
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_orderKey(bizId), _orderedCardIds);
      await prefs.setStringList(_hiddenKey(bizId), _hiddenCardIds.toList());
      await prefs.setInt(_densityKey(bizId), _columnsDensity);
      if (_heroCardId != null) {
        await prefs.setString(_heroKey(bizId), _heroCardId!);
      } else {
        await prefs.remove(_heroKey(bizId));
      }
    } catch (e) {
      debugPrint("Error guardando personalización Home Studio: $e");
    }
  }

  Future<void> _resetToFactory() async {
    HapticFeedback.mediumImpact();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final bizId = auth.activeBusinessId?.toString() ?? 'global';
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_orderKey(bizId));
      await prefs.remove(_hiddenKey(bizId));
      await prefs.remove(_densityKey(bizId));
      await prefs.remove(_heroKey(bizId));
    } catch (_) {}

    if (mounted) {
      setState(() {
        _orderedCardIds = List.from(_getDefaultCardIds());
        _hiddenCardIds.clear();
        _columnsDensity = 2;
        _heroCardId = null;
      });
      CustomSnackBar.show(
        context,
        message: "Diseño restablecido a valores de fábrica",
      );
    }
  }

  void _reorderCards(String draggedId, String targetId) {
    if (draggedId == targetId) {
      return;
    }
    final oldIndex = _orderedCardIds.indexOf(draggedId);
    final newIndex = _orderedCardIds.indexOf(targetId);
    if (oldIndex != -1 && newIndex != -1) {
      setState(() {
        _orderedCardIds.removeAt(oldIndex);
        _orderedCardIds.insert(newIndex, draggedId);
      });
      HapticFeedback.selectionClick();
      _saveCustomizations();
    }
  }

  void _toggleHideCard(String id) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_hiddenCardIds.contains(id)) {
        _hiddenCardIds.remove(id);
      } else {
        _hiddenCardIds.add(id);
        if (_heroCardId == id) {
          _heroCardId = null;
        }
      }
    });
    _saveCustomizations();
  }

  void _toggleHeroCard(String id) {
    HapticFeedback.mediumImpact();
    setState(() {
      if (_heroCardId == id) {
        _heroCardId = null;
      } else {
        _heroCardId = id;
        _hiddenCardIds.remove(id); // Asegurar que sea visible
      }
    });
    _saveCustomizations();
  }

  List<String> _getDefaultCardIds();
  bool get _isCustomized;
  Map<String, _ActionCardDef> _getCardDefinitions(BuildContext context);
  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    bool isDark,
    bool isGuest,
  );
  Widget _buildHomeStudioToolbar(BuildContext context, bool isDark);
  Widget _buildHeroCard(
    BuildContext context,
    _ActionCardDef def, {
    required bool isDark,
    required double screenWidth,
  });
  Widget _buildNormalCard(
    BuildContext context,
    _ActionCardDef def,
    int index,
    bool isDark,
    double screenWidth,
    int cols,
  );
  Widget _buildDraggableEditCard(
    BuildContext context,
    _ActionCardDef def,
    bool isDark,
    double screenWidth,
    int cols,
  );
  Widget _buildBadge(String text, Color color);
  Widget _buildHiddenCardsTray(
    BuildContext context,
    Map<String, _ActionCardDef> cardDefs,
    bool isDark,
  );
  Widget _buildEmptyState(BuildContext context, bool isDark);
  void _showResumeDialog(
    BuildContext context, {
    required String title,
    required String msg,
    required bool isDark,
    required VoidCallback onNew,
    required VoidCallback onResume,
  });
  void _showQuickSalePowerShortcut(
    BuildContext context,
    QuickSaleProvider prov,
    bool isDark,
  );

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isClient = auth.isCommunityClient;
    final isGuest = !auth.hasActiveContext;
    final screenWidth = MediaQuery.of(context).size.width;

    if (!_prefsLoaded) {
      _orderedCardIds = _getDefaultCardIds();
    }

    final cardDefs = _getCardDefinitions(context);
    final sectionTitle = isGuest
        ? "Explora nuestras herramientas"
        : (isClient ? "Servicios de la Tienda" : "Gestión Operativa");

    final visibleIds = _orderedCardIds.where((id) {
      if (_hiddenCardIds.contains(id)) {
        return false;
      }
      if (!cardDefs.containsKey(id)) {
        return false;
      }
      return true;
    }).toList();

    final String? activeHeroId =
        (!_isEditing && _heroCardId != null && visibleIds.contains(_heroCardId))
        ? _heroCardId
        : null;

    final gridCardIds = activeHeroId != null
        ? visibleIds.where((id) => id != activeHeroId).toList()
        : visibleIds;

    final int effectiveCols = screenWidth > 600 ? 3 : _columnsDensity;
    final double aspectRatio = effectiveCols == 3
        ? (screenWidth > 600 ? 1.05 : (screenWidth > 360 ? 0.82 : 0.76))
        : (screenWidth > 400 ? 1.08 : 0.94);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        widget.tourKey != null
            ? KeyedSubtree(
                key: widget.tourKey,
                child: _buildSectionHeader(
                  context,
                  sectionTitle,
                  isDark,
                  isGuest,
                ),
              )
            : _buildSectionHeader(context, sectionTitle, isDark, isGuest),
        const SizedBox(height: 12),
        if (_isEditing) ...[
          _buildHomeStudioToolbar(context, isDark),
          const SizedBox(height: 16),
        ],
        if (activeHeroId != null && cardDefs.containsKey(activeHeroId)) ...[
          _buildHeroCard(
            context,
            cardDefs[activeHeroId]!,
            isDark: isDark,
            screenWidth: screenWidth,
          ),
          const SizedBox(height: 14),
        ],
        if (gridCardIds.isEmpty && !_isEditing)
          _buildEmptyState(context, isDark)
        else
          GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: gridCardIds.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: effectiveCols,
              crossAxisSpacing: effectiveCols == 3 ? 10 : 14,
              mainAxisSpacing: effectiveCols == 3 ? 10 : 14,
              childAspectRatio: aspectRatio,
            ),
            itemBuilder: (context, index) {
              final cardId = gridCardIds[index];
              final def = cardDefs[cardId];
              if (def == null) {
                return const SizedBox.shrink();
              }

              if (_isEditing) {
                return _buildDraggableEditCard(
                  context,
                  def,
                  isDark,
                  screenWidth,
                  effectiveCols,
                );
              }

              return _buildNormalCard(
                context,
                def,
                index,
                isDark,
                screenWidth,
                effectiveCols,
              );
            },
          ),
        if (_isEditing && _hiddenCardIds.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildHiddenCardsTray(context, cardDefs, isDark),
        ],
      ],
    );
  }
}

class _SmartActionGridState extends _SmartActionGridStateBase
    with
        _SmartActionGridDefinitionsMixin,
        _SmartActionGridCardsMixin,
        _SmartActionGridStudioCardsMixin,
        _SmartActionGridModalsAndTraysMixin {}
