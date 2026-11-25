import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/core/providers/auth_provider.dart'; // 🔥 FASE 4
import 'package:app_movil/core/widgets/filter_drawer.dart';

// Pestañas
import 'package:app_movil/features/catalog/screens/tabs/products_tab.dart';
import 'package:app_movil/features/catalog/screens/tabs/categories_tab.dart';
import 'package:app_movil/features/catalog/screens/tabs/brands_tab.dart';
import 'package:app_movil/features/catalog/screens/tabs/providers_tab.dart';
import 'package:app_movil/features/promotions/screens/offers_tab.dart';

import 'package:app_movil/features/scanner/screens/invoice_history_screen.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';
import 'package:app_movil/core/widgets/deep_nav_return_pill.dart';
import 'package:app_movil/features/auth/screens/onboarding/onboarding_screen.dart';
import 'package:app_movil/core/services/tour/interactive_tour_service.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';
import 'package:app_movil/core/widgets/tour/configs/inventory_tour.dart';

class PlaceholderTab extends StatelessWidget {
  final String title;
  final IconData icon;
  const PlaceholderTab({super.key, required this.title, required this.icon});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 60,
            color: isDark ? Colors.white10 : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            "Gestión de $title",
            style: TextStyle(
              fontSize: 18,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class InventoryScreen extends StatefulWidget {
  final int initialTabIndex;
  final bool autoTriggerTour;
  final InventoryTourKeys? tourKeys;
  const InventoryScreen({
    super.key,
    this.initialTabIndex = 0,
    this.autoTriggerTour = true,
    this.tourKeys,
  });

  @override
  State<InventoryScreen> createState() => InventoryScreenState();
}

class InventoryScreenState extends State<InventoryScreen>
    with TickerProviderStateMixin {
  final _tourKeys = InventoryTourKeys();
  final _offersTabKey = GlobalKey<OffersTabState>();
  InventoryTourKeys get _effectiveTourKeys => widget.tourKeys ?? _tourKeys;
  late TabController _tabController;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;
  int _lastObservedTabIndex = 0;

  Future<void> _ensureProductsTabActiveForTour() async {
    if (!mounted) return;
    if (_tabController.index != 0) {
      _tabController.animateTo(0);
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  /// Construye la configuración de guía interactiva contextual para la pestaña actualmente visible.
  ScreenTourConfig buildTourConfigForCurrentTab() {
    return InventoryTour.buildConfigForTab(
      tabIndex: _tabController.index,
      keys: _effectiveTourKeys,
      onEnsureProductsTabActive: _ensureProductsTabActiveForTour,
      onExpandOffersInsights: () async {
        await _offersTabKey.currentState?.expandInsightsForTour();
      },
      onRestoreOffersInsights: () async {
        await _offersTabKey.currentState?.restoreInsightsAfterTour();
      },
    );
  }

  /// Dispara la guía interactiva correspondiente a la pestaña activa (automática o manual).
  Future<void> startActiveTabTour({bool automatic = false}) async {
    if (!mounted) return;
    final config = buildTourConfigForCurrentTab();
    if (automatic) {
      await InteractiveTourService.maybeStartAutomaticTour(context, config);
    } else {
      await InteractiveTourService.startManualTour(context, config);
    }
  }

  void _onTabSelectionChanged() {
    if (!mounted) return;
    if (_tabController.index != _lastObservedTabIndex) {
      setState(() {
        _lastObservedTabIndex = _tabController.index;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _lastObservedTabIndex = _tabController.index;
    _tabController.addListener(_onTabSelectionChanged);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<InventoryProvider>(
        context,
        listen: false,
      ).loadInventory(reset: true);
      if (widget.autoTriggerTour) {
        startActiveTabTour(automatic: true);
      }
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabSelectionChanged);
    _tabController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _applyFilters(Map<String, dynamic> filters) {
    Provider.of<InventoryProvider>(context, listen: false).loadInventory(
      reset: true,
      categoryIds: filters['categoryIds'],
      brandIds: filters['brandIds'],
      providerIds: filters['providerIds'],
      filterState: filters['estado'],
      minPrice: filters['minPrice'],
      maxPrice: filters['maxPrice'],
      minStock: filters['minStock'],
      maxStock: filters['maxStock'],
      hasOffer: filters['hasOffer'],
      onlyDefaults: filters['onlyDefaults'],
    );
  }

  // 🔥 NUEVO: Explicación de Exploración
  void _showExplorationModal(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.explore, color: Colors.orange[400]),
            const SizedBox(width: 10),
            const Text(
              "Modo Exploración",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          "Para ver el historial inteligente de las facturas de proveedores que la IA ha procesado, necesitas registrar tu propio negocio en tu Perfil.",
          style: TextStyle(
            color: isDark ? Colors.grey[300] : Colors.grey[700],
            fontSize: 16,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "Entendido",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = theme.scaffoldBackgroundColor;

    final auth = Provider.of<AuthProvider>(context);
    final isGuest = !auth.hasActiveContext;

    return Scaffold(
      backgroundColor: bgColor,
      endDrawer: FilterDrawer(onApplyFilters: _applyFilters),

      appBar: AppBar(
        titleSpacing: 8,
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            "Gestión de Negocio",
            maxLines: 1,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1A1A24) : theme.primaryColor,
        foregroundColor: Colors.white,

        actions: [
          KeyedSubtree(
            key: _effectiveTourKeys.invoiceAiKey,
            child: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ScaleTransition(
                scale: _glowAnimation,
                child: Tooltip(
                  message: "Historial de Facturas IA",
                  child: IconButton(
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Icon(Icons.receipt_long_rounded, size: 26),
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF1A1A24)
                                    : theme.primaryColor,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.auto_awesome,
                              size: 8,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    onPressed: () {
                      // 🔥 BLOQUEO DE INVITADO PARA HISTORIAL DE FACTURAS
                      if (isGuest) {
                        _showExplorationModal(context, isDark);
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const InvoiceHistoryScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          // Guía contextual e información específica de la pestaña activa
          _buildContextualInfoTooltip(_tabController.index),
        ],

        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: KeyedSubtree(
            key: _effectiveTourKeys.tabsKey,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              padding: EdgeInsets.zero,
              labelPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              unselectedLabelColor: Colors.white54,
              tabs: const [
                Tab(text: "PRODUCTOS"),
                Tab(text: "OFERTAS / BUNDLES"),
                Tab(text: "CATEGORÍAS"),
                Tab(text: "MARCAS"),
                Tab(text: "PROVEEDORES"),
              ],
            ),
          ),
        ),
      ),

      body: Stack(
        children: [
          Column(
            children: [
              // 🔥 AVISO DE EXPLORACIÓN PERMANENTE PARA INVITADOS
              if (isGuest)
                Container(
                  width: double.infinity,
                  color: Colors.orange.withValues(alpha: 0.15),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange[700]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Modo Exploración. Para agregar productos y categorías reales, debes registrar tu negocio.",
                          style: TextStyle(
                            color: isDark ? Colors.orange[200] : Colors.orange[900],
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text("Registrar", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    ProductsTab(
                      tabController: _tabController,
                      tourKeys: _effectiveTourKeys,
                    ),
                    OffersTab(
                      key: _offersTabKey,
                      tourKeys: _effectiveTourKeys,
                    ),
                    CategoriesTab(tourKeys: _effectiveTourKeys),
                    BrandsTab(tourKeys: _effectiveTourKeys),
                    ProvidersTab(tourKeys: _effectiveTourKeys),
                  ],
                ),
              ),
            ],
          ),
          const DeepNavReturnPill(isBottom: true),
        ],
      ),
    );
  }

  Widget _buildContextualInfoTooltip(int tabIndex) {
    switch (tabIndex) {
      case 1:
        return InfoTooltipButton(
          iconColor: Colors.white70,
          title: 'Ofertas y Bundles',
          description:
              'Detecta productos estancados y crea paquetes promocionales, 2x1 o liquidaciones calculando stock máximo automáticamente.',
          tips: const [
            InfoTip(
              icon: Icons.lightbulb_outline_rounded,
              text:
                  'Revisa Insights y Sugerencias para convertir inventario lento en efectivo.',
            ),
            InfoTip(
              icon: Icons.add_box_outlined,
              text:
                  'Usa + Nuevo para configurar ofertas Flash, Liquidez o combos Escolares.',
            ),
          ],
          onStartInteractiveTour: () => startActiveTabTour(automatic: false),
        );
      case 2:
        return InfoTooltipButton(
          iconColor: Colors.white70,
          title: 'Categorías de Catálogo',
          description:
              'Organiza tus líneas de negocio, auto-clasifica productos con IA o fusiona categorías duplicadas sin perder artículos.',
          tips: const [
            InfoTip(
              icon: Icons.auto_awesome_rounded,
              text:
                  'Auto-categorizar IA agrupa artículos sueltos en segundos.',
            ),
            InfoTip(
              icon: Icons.find_replace_rounded,
              text:
                  'Detectar Duplicados unifica categorías repetidas en una sola.',
            ),
          ],
          onStartInteractiveTour: () => startActiveTabTour(automatic: false),
        );
      case 3:
        return InfoTooltipButton(
          iconColor: Colors.white70,
          title: 'Marcas de Productos',
          description:
              'Administra las marcas del inventario, revisa artículos vinculados en el modal de detalle y fusiona duplicados.',
          tips: const [
            InfoTip(
              icon: Icons.branding_watermark_outlined,
              text:
                  'Toca una marca para editarla, suspenderla o ver cuántos productos tiene.',
            ),
          ],
          onStartInteractiveTour: () => startActiveTabTour(automatic: false),
        );
      case 4:
        return InfoTooltipButton(
          iconColor: Colors.white70,
          title: 'Proveedores y Compras',
          description:
              'Centraliza distribuidores, RUC y datos de contacto. Toca cualquier ficha para ver productos vinculados y fusionar repetidos.',
          tips: const [
            InfoTip(
              icon: Icons.local_shipping_outlined,
              text:
                  'Tener RUC y razón social limpios mejora el escaneo de facturas con IA.',
            ),
          ],
          onStartInteractiveTour: () => startActiveTabTour(automatic: false),
        );
      case 0:
      default:
        return InfoTooltipButton(
          iconColor: Colors.white70,
          title: 'Gestión de Negocio',
          description:
              'Aquí administras todo tu inventario: productos, categorías, marcas, proveedores y ofertas. Busca, filtra y edita tu catálogo al instante.',
          tips: const [
            InfoTip(
              icon: Icons.search_rounded,
              text:
                  'Usa el buscador y los filtros del panel derecho para encontrar productos rápidamente.',
            ),
            InfoTip(
              icon: Icons.receipt_long_rounded,
              text:
                  'El botón superior con IA abre el historial de facturas procesadas.',
            ),
            InfoTip(
              icon: Icons.find_replace_rounded,
              text:
                  'Cambia de pestaña para ver guías dedicadas de Ofertas, Categorías, Marcas y Proveedores.',
            ),
          ],
          onStartInteractiveTour: () => startActiveTabTour(automatic: false),
        );
    }
  }
}
