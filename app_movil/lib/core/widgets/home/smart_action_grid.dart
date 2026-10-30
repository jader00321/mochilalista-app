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

/// Definición de metadatos estáticos y callbacks de una tarjeta de acción
class _ActionCardDef {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color Function(bool isDark) colorBuilder;
  final Widget? Function(BuildContext context, bool isDark) badgeBuilder;
  final VoidCallback Function(BuildContext context, bool isDark) onTapBuilder;
  final VoidCallback? Function(BuildContext context, bool isDark)? onLongPressBuilder;

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

  const SmartActionGrid({super.key, this.onNavigateToTab});

  @override
  State<SmartActionGrid> createState() => _SmartActionGridState();
}

class _SmartActionGridState extends State<SmartActionGrid> with SingleTickerProviderStateMixin {
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
            final validIds = savedOrder.where((id) => defaultIds.contains(id)).toList();
            for (var dId in defaultIds) {
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
            _hiddenCardIds.addAll(savedHidden.where((id) => defaultIds.contains(id)));
          }

          _columnsDensity = (savedDensity == 3) ? 3 : 2;
          _heroCardId = (savedHero != null && defaultIds.contains(savedHero)) ? savedHero : null;
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
      CustomSnackBar.show(context, message: "Diseño restablecido a valores de fábrica");
    }
  }

  List<String> _getDefaultCardIds() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.isCommunityClient) {
      return ['order_catalog'];
    }
    final ids = [
      'quick_sale',
      'create_product',
      'quote_list',
      'quote_manual',
      'load_invoice',
      'clients',
      'activity',
      'analytics',
      'commercial_radar',
    ];
    if (kDebugMode) {
      ids.add('db_inspector');
    }
    return ids;
  }

  bool get _isCustomized {
    final defaultIds = _getDefaultCardIds();
    if (_columnsDensity != 2) return true;
    if (_heroCardId != null) return true;
    if (_hiddenCardIds.isNotEmpty) return true;
    if (_orderedCardIds.length != defaultIds.length) return true;
    for (int i = 0; i < defaultIds.length; i++) {
      if (i >= _orderedCardIds.length || _orderedCardIds[i] != defaultIds[i]) {
        return true;
      }
    }
    return false;
  }

  Map<String, _ActionCardDef> _getCardDefinitions(BuildContext context) {
    final inventoryScanner = Provider.of<ScannerProvider>(context);
    final quotationScanner = Provider.of<SmartQuotationProvider>(context);
    final trackingProv = Provider.of<TrackingProvider>(context);
    final salesProv = Provider.of<SaleProvider>(context);
    final quickSaleProv = Provider.of<QuickSaleProvider>(context);
    final invProv = Provider.of<InventoryProvider>(context);

    return {
      'order_catalog': _ActionCardDef(
        id: 'order_catalog',
        title: "Crear Pedido",
        subtitle: "Catálogo Virtual",
        icon: Icons.add_shopping_cart_rounded,
        colorBuilder: (isDark) => isDark ? Colors.blue[400]! : Colors.blue[700]!,
        badgeBuilder: (ctx, isDark) => null,
        onTapBuilder: (ctx, isDark) => () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const ManualQuotationScreen())),
      ),
      'quick_sale': _ActionCardDef(
        id: 'quick_sale',
        title: "Venta Rápida",
        subtitle: "Caja al paso",
        icon: Icons.flash_on_rounded,
        colorBuilder: (isDark) => isDark ? Colors.pink[300]! : Colors.pink[600]!,
        badgeBuilder: (ctx, isDark) => quickSaleProv.cartItems.isNotEmpty
            ? _buildBadge("${quickSaleProv.cartItems.length}", Colors.red)
            : null,
        onTapBuilder: (ctx, isDark) => () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const QuickSaleScreen())),
        onLongPressBuilder: (ctx, isDark) => () => _showQuickSalePowerShortcut(ctx, quickSaleProv, isDark),
      ),
      'create_product': _ActionCardDef(
        id: 'create_product',
        title: "Crear Producto",
        subtitle: "Inventario",
        icon: Icons.add_box_rounded,
        colorBuilder: (isDark) => isDark ? Colors.green[400]! : Colors.green[600]!,
        badgeBuilder: (ctx, isDark) => invProv.totalPresentationsCount > 0
            ? _buildBadge("${invProv.totalPresentationsCount}", Colors.green[800]!)
            : null,
        onTapBuilder: (ctx, isDark) => () async {
          await Navigator.push(ctx, MaterialPageRoute(builder: (_) => const ProductCreateScreen()));
        },
      ),
      'quote_list': _ActionCardDef(
        id: 'quote_list',
        title: "Cotizar Lista",
        subtitle: "Escaneo con IA",
        icon: Icons.document_scanner_rounded,
        colorBuilder: (isDark) => isDark ? Colors.orange[400]! : Colors.orange[700]!,
        badgeBuilder: (ctx, isDark) => quotationScanner.items.isNotEmpty
            ? _buildBadge("${quotationScanner.items.length}", Colors.orange)
            : null,
        onTapBuilder: (ctx, isDark) => () {
          if (quotationScanner.items.isNotEmpty) {
            _showResumeDialog(
              ctx,
              title: "Lista Detectada",
              msg: "Tienes una lista escolar procesada sin guardar.",
              isDark: isDark,
              onNew: () {
                quotationScanner.clearState();
                Navigator.push(ctx, MaterialPageRoute(builder: (_) => const ScanScreen(mode: ScanMode.quotation)));
              },
              onResume: () => Navigator.push(
                ctx,
                MaterialPageRoute(
                  builder: (_) => MatchingScreen(
                    extractedItems: quotationScanner.items,
                    metadata: quotationScanner.metadata,
                  ),
                ),
              ),
            );
          } else {
            Navigator.push(ctx, MaterialPageRoute(builder: (_) => const ScanScreen(mode: ScanMode.quotation)));
          }
        },
      ),
      'quote_manual': _ActionCardDef(
        id: 'quote_manual',
        title: "Cotizar Manual",
        subtitle: "Detallada",
        icon: Icons.edit_note_rounded,
        colorBuilder: (isDark) => isDark ? Colors.blue[400]! : Colors.blue[700]!,
        badgeBuilder: (ctx, isDark) => quotationScanner.hasManualDraft
            ? _buildBadge("${quotationScanner.draftManualItems!.length}", Colors.blue)
            : null,
        onTapBuilder: (ctx, isDark) => () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const ManualQuotationScreen())),
      ),
      'load_invoice': _ActionCardDef(
        id: 'load_invoice',
        title: "Cargar Factura",
        subtitle: "Reponer Stock",
        icon: Icons.receipt_long_rounded,
        colorBuilder: (isDark) => isDark ? Colors.teal[400]! : Colors.teal[600]!,
        badgeBuilder: (ctx, isDark) => inventoryScanner.aiRawData != null
            ? _buildBadge("${inventoryScanner.aiRawData!.items.length}", Colors.teal)
            : null,
        onTapBuilder: (ctx, isDark) => () {
          if (inventoryScanner.aiRawData != null) {
            _showResumeDialog(
              ctx,
              title: "Factura Pendiente",
              msg: "Tienes una factura en proceso de revisión o vinculación. ¿Deseas retomarla?",
              isDark: isDark,
              onNew: () {
                inventoryScanner.clearData();
                Navigator.push(ctx, MaterialPageRoute(builder: (_) => const ScanScreen(mode: ScanMode.invoice)));
              },
              onResume: () {
                if (inventoryScanner.hasSavedProgress && inventoryScanner.stagingData != null) {
                  Navigator.push(ctx, MaterialPageRoute(builder: (_) => const InvoiceStagingScreen()));
                } else {
                  Navigator.push(ctx, MaterialPageRoute(builder: (_) => const InvoiceReviewScreen()));
                }
              },
            );
          } else {
            Navigator.push(ctx, MaterialPageRoute(builder: (_) => const ScanScreen(mode: ScanMode.invoice)));
          }
        },
      ),
      'clients': _ActionCardDef(
        id: 'clients',
        title: "Clientes",
        subtitle: "Deudas y Pagos",
        icon: Icons.people_alt_rounded,
        colorBuilder: (isDark) => isDark ? Colors.purple[300]! : Colors.purple[600]!,
        badgeBuilder: (ctx, isDark) => trackingProv.clientCount > 0
            ? _buildBadge("${trackingProv.clientCount}", Colors.purple)
            : null,
        onTapBuilder: (ctx, isDark) => () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const ClientTrackingScreen())),
      ),
      'activity': _ActionCardDef(
        id: 'activity',
        title: "Actividad",
        subtitle: salesProv.todaySalesCount > 0 ? "${salesProv.todaySalesCount} ventas hoy" : "Historial Ventas",
        icon: Icons.history_edu_rounded,
        colorBuilder: (isDark) => isDark ? Colors.indigo[300]! : Colors.indigo[600]!,
        badgeBuilder: (ctx, isDark) => salesProv.todaySalesCount > 0
            ? _buildBadge("${salesProv.todaySalesCount}", Colors.indigo)
            : null,
        onTapBuilder: (ctx, isDark) => () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const SalesHistoryScreen())),
      ),
      'analytics': _ActionCardDef(
        id: 'analytics',
        title: "Estadísticas",
        subtitle: "Finanzas y Top",
        icon: Icons.pie_chart_rounded,
        colorBuilder: (isDark) => isDark ? Colors.amber[500]! : Colors.amber[700]!,
        badgeBuilder: (ctx, isDark) => null,
        onTapBuilder: (ctx, isDark) => () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const AnalyticsDashboardScreen())),
      ),
      'commercial_radar': _ActionCardDef(
        id: 'commercial_radar',
        title: "Radar IA",
        subtitle: "Noticias y Alertas",
        icon: Icons.radar,
        colorBuilder: (isDark) => isDark ? Colors.cyan[300]! : Colors.cyan[700]!,
        badgeBuilder: (ctx, isDark) => null,
        onTapBuilder: (ctx, isDark) => () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const CommercialRadarScreen())),
      ),
      'db_inspector': _ActionCardDef(
        id: 'db_inspector',
        title: "DB Inspector",
        subtitle: "Depuración BD",
        icon: Icons.admin_panel_settings_rounded,
        colorBuilder: (isDark) => isDark ? Colors.grey[400]! : Colors.grey[700]!,
        badgeBuilder: (ctx, isDark) => null,
        onTapBuilder: (ctx, isDark) => () => Navigator.push(ctx, MaterialPageRoute(builder: (_) => const DbInspectorScreen())),
      ),
    };
  }

  void _reorderCards(String draggedId, String targetId) {
    if (draggedId == targetId) return;
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
        if (_heroCardId == id) _heroCardId = null;
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

    // Título de la sección
    final sectionTitle = isGuest
        ? "Explora nuestras herramientas"
        : (isClient ? "Servicios de la Tienda" : "Gestión Operativa");

    // Tarjetas visibles
    final visibleIds = _orderedCardIds.where((id) {
      if (_hiddenCardIds.contains(id)) return false;
      if (!cardDefs.containsKey(id)) return false;
      return true;
    }).toList();

    // En modo normal, si hay una tarjeta Hero, la mostramos destacada arriba
    final String? activeHeroId = (!_isEditing && _heroCardId != null && visibleIds.contains(_heroCardId))
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
        // Cabecera con Título, Botón Personalizar y Propuesta 3 (Punto azul indicador)
        _buildSectionHeader(context, sectionTitle, isDark, isGuest),
        const SizedBox(height: 12),

        // Panel de Control Home Studio (si está en modo edición)
        if (_isEditing) ...[
          _buildHomeStudioToolbar(context, isDark),
          const SizedBox(height: 16),
        ],

        // Propuesta 2: Tarjeta Destacada "Hero Quick Access" (en modo normal)
        if (activeHeroId != null && cardDefs.containsKey(activeHeroId)) ...[
          _buildHeroCard(context, cardDefs[activeHeroId]!, isDark: isDark, screenWidth: screenWidth),
          const SizedBox(height: 14),
        ],

        // Cuadrícula Principal de Tarjetas
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
              if (def == null) return const SizedBox.shrink();

              if (_isEditing) {
                return _buildDraggableEditCard(context, def, isDark, screenWidth, effectiveCols);
              }

              return _buildNormalCard(context, def, index, isDark, screenWidth, effectiveCols);
            },
          ),

        // Bandeja de Tarjetas Ocultas (en modo edición)
        if (_isEditing && _hiddenCardIds.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildHiddenCardsTray(context, cardDefs, isDark),
        ],
      ],
    );
  }

  // =========================================================================
  // CABECERA Y BOTÓN PERSONALIZAR CON PROPUESTA 3 (PUNTO AZUL)
  // =========================================================================
  Widget _buildSectionHeader(BuildContext context, String title, bool isDark, bool isGuest) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        if (!isGuest) ...[
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                HapticFeedback.mediumImpact();
                setState(() => _isEditing = !_isEditing);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _isEditing
                      ? (_columnsDensity == 3 ? Colors.indigoAccent.withValues(alpha: 0.2) : Colors.blue.withValues(alpha: 0.2))
                      : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.12)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isEditing
                        ? Colors.blueAccent
                        : (isDark ? Colors.white.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.3)),
                    width: _isEditing ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          _isEditing ? Icons.check_circle_outline_rounded : Icons.tune_rounded,
                          size: 16,
                          color: _isEditing ? Colors.blueAccent : (isDark ? Colors.grey[300] : Colors.grey[800]),
                        ),
                        // 🔹 PROPUESTA 3: Indicador de punto azul cuando el usuario tiene diseño personalizado
                        if (_isCustomized && !_isEditing)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Colors.blueAccent,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blueAccent,
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _isEditing ? "Listo" : "Personalizar",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _isEditing ? Colors.blueAccent : (isDark ? Colors.grey[300] : Colors.grey[800]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // =========================================================================
  // TOOLBAR DE HOME STUDIO EN MODO EDICIÓN
  // =========================================================================
  Widget _buildHomeStudioToolbar(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2230) : const Color(0xFFF0F5FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: Colors.blueAccent, size: 18),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  "Home Studio: Personaliza tus accesos",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
              TextButton.icon(
                onPressed: _resetToFactory,
                icon: const Icon(Icons.refresh_rounded, size: 14, color: Colors.grey),
                label: const Text("Fábrica", style: TextStyle(fontSize: 11, color: Colors.grey)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Mantén presionado para arrastrar y ordenar. Toca [★] para fijar en portada o [x] para ocultar.",
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 10),
          // 🔹 PROPUESTA 1: Selector de Densidad (2 vs 3 Columnas)
          Row(
            children: [
              Text(
                "Densidad:",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey[300] : Colors.grey[800],
                ),
              ),
              const SizedBox(width: 8),
              _buildDensityOption(title: "2 Columnas", cols: 2, isDark: isDark),
              const SizedBox(width: 8),
              _buildDensityOption(title: "3 Columnas", cols: 3, isDark: isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDensityOption({required String title, required int cols, required bool isDark}) {
    final isSelected = _columnsDensity == cols;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _columnsDensity = cols);
        _saveCustomizations();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blueAccent : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.black87),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // PROPUESTA 2: TARJETA DESTACADA "HERO QUICK ACCESS"
  // =========================================================================
  Widget _buildHeroCard(
    BuildContext context,
    _ActionCardDef def, {
    required bool isDark,
    required double screenWidth,
  }) {
    final color = def.colorBuilder(isDark);
    final badge = def.badgeBuilder(context, isDark);

    return Material(
      color: isDark ? const Color(0xFF23232F) : Colors.white,
      elevation: isDark ? 0 : 8,
      shadowColor: isDark ? Colors.transparent : color.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: color.withValues(alpha: isDark ? 0.35 : 0.45),
          width: 1.8,
        ),
      ),
      child: InkWell(
        onTap: def.onTapBuilder(context, isDark),
        onLongPress: !_isEditing && def.onLongPressBuilder != null
            ? def.onLongPressBuilder!(context, isDark)
            : null,
        borderRadius: BorderRadius.circular(24),
        splashColor: color.withValues(alpha: 0.15),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: isDark ? 0.18 : 0.12),
                Colors.transparent,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? color.withValues(alpha: 0.25) : color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
                ),
                child: Icon(def.icon, color: color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded, color: Colors.amber, size: 12),
                              SizedBox(width: 2),
                              Text(
                                "ACCESO RÁPIDO",
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          badge,
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      def.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        color: isDark ? Colors.white : Colors.black87,
                        letterSpacing: -0.4,
                      ),
                    ),
                    Text(
                      def.subtitle,
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: color.withValues(alpha: 0.7),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // TARJETA NORMAL (MODO EJECUCIÓN)
  // =========================================================================
  Widget _buildNormalCard(
    BuildContext context,
    _ActionCardDef def,
    int index,
    bool isDark,
    double screenWidth,
    int cols,
  ) {
    final color = def.colorBuilder(isDark);
    final badge = def.badgeBuilder(context, isDark);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final double delay = (index * 0.06).clamp(0.0, 0.6);
        final double effectiveValue = ((value - delay) / (1 - delay)).clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, 20 * (1 - effectiveValue)),
          child: Opacity(opacity: effectiveValue, child: child),
        );
      },
      child: Material(
        color: isDark ? const Color(0xFF23232F) : Colors.white,
        elevation: isDark ? 0 : 7,
        shadowColor: isDark ? Colors.transparent : color.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: isDark
              ? BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1.5)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: def.onTapBuilder(context, isDark),
          onLongPress: def.onLongPressBuilder != null ? def.onLongPressBuilder!(context, isDark) : null,
          borderRadius: BorderRadius.circular(22),
          splashColor: color.withValues(alpha: 0.15),
          highlightColor: color.withValues(alpha: 0.05),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: isDark
                  ? LinearGradient(
                      colors: [color.withValues(alpha: 0.06), Colors.transparent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: cols == 3 ? 8 : (screenWidth > 400 ? 16 : 12),
              vertical: cols == 3 ? 6 : (screenWidth > 400 ? 12 : 10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: EdgeInsets.all(cols == 3 ? 6 : (screenWidth > 400 ? 11 : 8)),
                      decoration: BoxDecoration(
                        color: isDark ? color.withValues(alpha: 0.2) : color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        def.icon,
                        color: color,
                        size: cols == 3 ? 18 : (screenWidth > 400 ? 26 : 22),
                      ),
                    ),
                    if (badge != null) badge,
                  ],
                ),
                SizedBox(height: cols == 3 ? 6 : 10),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    def.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: cols == 3 ? 12.5 : (screenWidth > 400 ? 16 : 14),
                      color: isDark ? Colors.white : Colors.black87,
                      height: 1.1,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  def.subtitle,
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontSize: cols == 3 ? 9.5 : (screenWidth > 400 ? 12 : 11),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // TARJETA INTERACTIVA DE REORDENAMIENTO Y EDICIÓN (DRAG & DROP)
  // =========================================================================
  Widget _buildDraggableEditCard(
    BuildContext context,
    _ActionCardDef def,
    bool isDark,
    double screenWidth,
    int cols,
  ) {
    final color = def.colorBuilder(isDark);
    final isHero = _heroCardId == def.id;

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != def.id,
      onAcceptWithDetails: (details) {
        _reorderCards(details.data, def.id);
      },
      builder: (context, candidateData, rejectedData) {
        final isTargeted = candidateData.isNotEmpty;

        return LongPressDraggable<String>(
          data: def.id,
          feedback: Material(
            color: Colors.transparent,
            elevation: 10,
            child: SizedBox(
              width: cols == 3 ? 110 : 150,
              height: cols == 3 ? 100 : 130,
              child: Opacity(
                opacity: 0.9,
                child: _buildCardFrame(context, def, isDark, color, isHero, isTargeted, cols, isDragging: true),
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.25,
            child: _buildCardFrame(context, def, isDark, color, isHero, isTargeted, cols),
          ),
          child: _buildCardFrame(context, def, isDark, color, isHero, isTargeted, cols),
        );
      },
    );
  }

  Widget _buildCardFrame(
    BuildContext context,
    _ActionCardDef def,
    bool isDark,
    Color color,
    bool isHero,
    bool isTargeted,
    int cols, {
    bool isDragging = false,
  }) {
    return AnimatedBuilder(
      animation: _editPulseController,
      builder: (context, child) {
        final pulseAlpha = 0.2 + (_editPulseController.value * 0.25);
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF20222F) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isTargeted
                  ? Colors.blueAccent
                  : (isHero
                      ? Colors.amber
                      : Colors.blueAccent.withValues(alpha: isDragging ? 0.8 : pulseAlpha)),
              width: (isTargeted || isHero) ? 2.2 : 1.5,
            ),
            boxShadow: [
              if (isHero)
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Barra superior de controles en modo edición: Drag handle, Star (Hero), Close (Hide)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    Icons.drag_indicator_rounded,
                    color: isDark ? Colors.grey[500] : Colors.grey[400],
                    size: 18,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Botón Fijar como Hero (Propuesta 2)
                      InkWell(
                        onTap: () => _toggleHeroCard(def.id),
                        child: Icon(
                          isHero ? Icons.star_rounded : Icons.star_border_rounded,
                          color: isHero ? Colors.amber : (isDark ? Colors.grey[400] : Colors.grey[500]),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Botón Ocultar
                      InkWell(
                        onTap: () => _toggleHideCard(def.id),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 14),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(def.icon, color: color, size: cols == 3 ? 18 : 22),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        def.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: cols == 3 ? 12 : 14,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                isHero ? "En Portada" : def.subtitle,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isHero ? Colors.amber : (isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  // =========================================================================
  // BANDEJA DE TARJETAS OCULTAS
  // =========================================================================
  Widget _buildHiddenCardsTray(
    BuildContext context,
    Map<String, _ActionCardDef> cardDefs,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF171922) : const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.visibility_off_outlined, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                "Tarjetas Ocultas (${_hiddenCardIds.length})",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
              const Spacer(),
              const Text(
                "Toca para restaurar",
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _hiddenCardIds.map((hiddenId) {
              final def = cardDefs[hiddenId];
              if (def == null) return const SizedBox.shrink();
              return ActionChip(
                backgroundColor: isDark ? const Color(0xFF232532) : Colors.white,
                avatar: const Icon(Icons.add_circle_outline_rounded, color: Colors.green, size: 16),
                label: Text(
                  def.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                onPressed: () => _toggleHideCard(hiddenId),
                side: BorderSide(color: Colors.green.withValues(alpha: 0.3)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E202B) : const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Icon(Icons.widgets_outlined, size: 40, color: Colors.blueAccent.withValues(alpha: 0.8)),
          const SizedBox(height: 8),
          const Text(
            "Todas las tarjetas están ocultas",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            "Puedes restaurar todos los accesos originales o personalizar cuáles mostrar.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                onPressed: _resetToFactory,
                icon: const Icon(Icons.restore_rounded, size: 16),
                label: const Text("Restablecer Tarjetas", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white70 : Colors.black87,
                  side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade400),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() => _isEditing = true);
                },
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: const Text("Personalizar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _showResumeDialog(
    BuildContext context, {
    required String title,
    required String msg,
    required bool isDark,
    required VoidCallback onNew,
    required VoidCallback onResume,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        title: Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w900,
            fontSize: 20,
          ),
        ),
        content: Text(
          msg,
          style: TextStyle(
            color: isDark ? Colors.grey[300] : Colors.grey[700],
            fontSize: 15,
            height: 1.4,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onNew();
            },
            child: const Text(
              "Iniciar Nueva",
              style: TextStyle(color: Colors.grey, fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.blue[600] : Colors.blue[800],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              onResume();
            },
            child: const Text("Retomar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
    );
  }

  void _showQuickSalePowerShortcut(BuildContext context, QuickSaleProvider prov, bool isDark) {
    HapticFeedback.heavyImpact();
    InteractiveSheetWrapper.show(
      context: context,
      builder: (ctx) => InteractiveSheetWrapper(
        title: "Atajos de Venta Rápida",
        maxHeightFactor: 0.6,
        applyEffectiveBottomPadding: true,
        child: Column(
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.pink.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.flash_on_rounded, color: Colors.pinkAccent),
              ),
              title: const Text("Nueva Venta Limpia", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text("Vacía la caja y abre una nueva venta en blanco"),
              onTap: () {
                Navigator.pop(ctx);
                prov.clearCart();
                Navigator.push(context, MaterialPageRoute(builder: (_) => const QuickSaleScreen()));
              },
            ),
            const Divider(),
            if (prov.cartItems.isNotEmpty) ...[
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
                ),
                title: Text(
                  "Vaciar Caja (${prov.cartItems.length} ítems)",
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
                ),
                subtitle: const Text("Descarta todos los productos actualmente en cola"),
                onTap: () {
                  Navigator.pop(ctx);
                  prov.clearCart();
                  CustomSnackBar.show(context, message: "Caja vaciada correctamente");
                },
              ),
              const Divider(),
            ],
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.point_of_sale_rounded, color: Colors.blue),
              ),
              title: const Text("Continuar Venta Pendiente", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                prov.cartItems.isNotEmpty
                    ? "${prov.cartItems.length} productos esperando cobro"
                    : "Caja actualmente vacía",
              ),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const QuickSaleScreen()));
              },
            ),
          ],
        ),
      ),
    );
  }
}