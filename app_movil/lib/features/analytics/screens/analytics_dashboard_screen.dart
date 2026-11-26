import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/core/utils/app_date_formatter.dart';
import 'package:share_plus/share_plus.dart';

import 'package:app_movil/features/analytics/providers/analytics_provider.dart';
import 'package:app_movil/features/analytics/services/analytics_export_service.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/widgets/sliver_sticky_header_delegate.dart';
import 'package:app_movil/features/analytics/models/dashboard_section_config.dart';
import 'package:app_movil/features/analytics/widgets/dashboard/dashboard_customizer_modal.dart';
import 'package:app_movil/features/analytics/widgets/dashboard/commercial_radar_card.dart';
import 'package:app_movil/features/analytics/widgets/charts/monthly_sales_chart.dart';
import 'package:app_movil/features/analytics/widgets/charts/payment_method_chart.dart';
import 'package:app_movil/features/analytics/widgets/charts/origin_pie_chart.dart';
import 'package:app_movil/features/analytics/widgets/charts/sales_by_day_chart.dart';
import 'package:app_movil/features/analytics/widgets/charts/top_products_chart.dart';
import 'package:app_movil/features/analytics/widgets/insights_carousel.dart';
import 'package:app_movil/features/analytics/widgets/dashboard/financial_summary_card.dart';
import 'package:app_movil/features/analytics/widgets/dashboard/kpi_summary_row.dart';
import 'package:app_movil/features/analytics/widgets/dashboard/top_clients_card.dart';
import 'package:app_movil/features/analytics/widgets/dashboard/extra_metrics_card.dart';
import 'package:app_movil/features/analytics/widgets/dashboard/restock_alerts_card.dart';
import 'package:app_movil/features/analytics/widgets/dashboard/dead_stock_card.dart';
import 'package:app_movil/features/analytics/widgets/dashboard/top_categories_card.dart';
import 'package:app_movil/features/analytics/screens/smart_restock_screen.dart';
import 'package:app_movil/features/analytics/screens/predictive_analytics_screen.dart';
import 'package:app_movil/core/widgets/info_tooltip_button.dart';
import 'package:app_movil/core/services/tour/interactive_tour_service.dart';
import 'package:app_movil/core/widgets/tour/configs/analytics_dashboard_tour.dart';

part 'analytics_dashboard/analytics_dashboard_states_and_actions.dart';
part 'analytics_dashboard/analytics_dashboard_sections_and_tabs.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  final bool autoTriggerTour;
  final AnalyticsDashboardTourKeys? tourKeys;

  const AnalyticsDashboardScreen({
    super.key,
    this.autoTriggerTour = true,
    this.tourKeys,
  });

  @override
  State<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

abstract class _AnalyticsDashboardScreenStateBase
    extends State<AnalyticsDashboardScreen>
    with TickerProviderStateMixin {
  late AnalyticsDashboardTourKeys _tourKeys;
  bool _obscureAmounts = false;
  final ValueNotifier<bool> _isFabCompactNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String> _activeGroupNotifier = ValueNotifier<String>('resumen');
  bool _isJumpingProgrammatically = false;
  late ScrollController _scrollController;
  late ScrollController _chipBarScrollController;
  late AnimationController _pulseController;
  final GlobalKey _stickyHeaderKey = GlobalKey();
  
  List<DashboardSectionConfig> _sections = DashboardSectionConfig.getDefaultSections();
  final Map<String, GlobalKey> _sectionKeys = {};
  final Map<String, GlobalKey> _chipKeys = {};

  @override
  void initState() {
    super.initState();
    _tourKeys = widget.tourKeys ?? AnalyticsDashboardTourKeys();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _chipBarScrollController = ScrollController();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _initializeKeys();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      _loadCustomSections(auth.activeBusinessId ?? 0);
      Provider.of<AnalyticsProvider>(context, listen: false).reset();

      if (widget.autoTriggerTour) {
        InteractiveTourService.maybeStartAutomaticTour(
          context,
          AnalyticsDashboardTour.buildConfig(keys: _tourKeys),
        );
      }
    });
  }

  void _initializeKeys() {
    for (var s in _sections) {
      _sectionKeys[s.id] = GlobalKey();
    }
    for (var g in ['resumen', 'graficos', 'inventario', 'radar']) {
      _chipKeys[g] = GlobalKey();
    }
  }

  Future<void> _loadCustomSections(int businessId) async {
    final loaded = await DashboardSectionConfig.loadSections(businessId);
    if (mounted) {
      setState(() {
        _sections = loaded;
        for (var s in _sections) {
          _sectionKeys.putIfAbsent(s.id, () => GlobalKey());
        }
        for (var g in ['resumen', 'graficos', 'inventario', 'radar']) {
          _chipKeys.putIfAbsent(g, () => GlobalKey());
        }
      });
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final isDown = _scrollController.position.userScrollDirection == ScrollDirection.reverse;
    if (isDown != _isFabCompactNotifier.value) {
      _isFabCompactNotifier.value = isDown;
    }

    // ScrollSpy de la Ola Vibrante: se suspende durante saltos programáticos
    if (_isJumpingProgrammatically) return;

    final headerBox = _stickyHeaderKey.currentContext?.findRenderObject() as RenderBox?;
    final headerBottomDy = headerBox != null && headerBox.hasSize
        ? headerBox.localToGlobal(Offset(0, headerBox.size.height)).dy
        : 165.0;

    final visibleList = _sections.where((s) => s.isVisible).toList();
    for (var sec in visibleList) {
      final key = _sectionKeys[sec.id];
      final ctx = key?.currentContext;
      if (ctx != null) {
        final renderBox = ctx.findRenderObject() as RenderBox?;
        if (renderBox != null && renderBox.hasSize) {
          final position = renderBox.localToGlobal(Offset.zero);
          // Umbral visual relativo a la cabecera fija
          if (position.dy <= (headerBottomDy + 40) && (position.dy + renderBox.size.height) > (headerBottomDy + 40)) {
            if (_activeGroupNotifier.value != sec.categoryGroup) {
              _activeGroupNotifier.value = sec.categoryGroup;
              _centerChipInBar(sec.categoryGroup);
            }
            break;
          }
        }
      }
    }
  }

  void _centerChipInBar(String group) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_chipBarScrollController.hasClients) return;
      final chipKey = _chipKeys[group];
      final chipBox = chipKey?.currentContext?.findRenderObject() as RenderBox?;
      if (chipBox != null && chipBox.hasSize && mounted) {
        final chipGlobal = chipBox.localToGlobal(Offset.zero);
        final screenWidth = MediaQuery.of(context).size.width;
        final currentScroll = _chipBarScrollController.offset;
        final chipScreenCenter = chipGlobal.dx + (chipBox.size.width / 2);
        final delta = chipScreenCenter - (screenWidth / 2);
        final targetOffset = (currentScroll + delta).clamp(0.0, _chipBarScrollController.position.maxScrollExtent);
        _chipBarScrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _chipBarScrollController.dispose();
    _pulseController.dispose();
    _isFabCompactNotifier.dispose();
    _activeGroupNotifier.dispose();
    super.dispose();
  }

  /// Salto milimétrico sincronizado y con transición limpia de la Ola Vibrante
  void _jumpToGroup(String group) {
    DashboardSectionConfig? targetSection;
    for (var sec in _sections) {
      if (sec.isVisible && sec.categoryGroup == group) {
        targetSection = sec;
        break;
      }
    }

    if (targetSection == null) {
      CustomSnackBar.show(context, message: 'La sección no está visible actualmente.');
      return;
    }

    _isJumpingProgrammatically = true;
    _activeGroupNotifier.value = group;
    _centerChipInBar(group);

    final key = _sectionKeys[targetSection.id];
    final ctx = key?.currentContext;
    if (ctx != null) {
      final targetBox = ctx.findRenderObject() as RenderBox?;
      final headerBox = _stickyHeaderKey.currentContext?.findRenderObject() as RenderBox?;
      if (targetBox != null && targetBox.hasSize && headerBox != null && headerBox.hasSize) {
        final headerBottomDy = headerBox.localToGlobal(Offset(0, headerBox.size.height)).dy;
        final targetTopDy = targetBox.localToGlobal(Offset.zero).dy;
        // Descontar la cabecera fija pinned real + 12px exactos de respiro visual
        final delta = (targetTopDy - headerBottomDy) - 12.0;
        final currentOffset = _scrollController.offset;
        final targetOffset = (currentOffset + delta).clamp(0.0, _scrollController.position.maxScrollExtent);

        _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
        ).then((_) {
          Future.delayed(const Duration(milliseconds: 60), () {
            if (mounted) _isJumpingProgrammatically = false;
          });
        });
        return;
      }
    }

    // Fallback seguro si el widget aún no está en el viewport
    final visibleList = _sections.where((s) => s.isVisible).toList();
    final index = visibleList.indexWhere((s) => s.id == targetSection!.id);
    if (index != -1 && _scrollController.hasClients) {
      final double maxExtent = _scrollController.position.maxScrollExtent;
      final double estimatedOffset = (index / visibleList.length) * maxExtent;
      _scrollController.animateTo(
        estimatedOffset.clamp(0.0, maxExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      ).then((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final postCtx = key?.currentContext;
          final fineTargetBox = postCtx?.findRenderObject() as RenderBox?;
          final fineHeaderBox = _stickyHeaderKey.currentContext?.findRenderObject() as RenderBox?;
          if (fineTargetBox != null && fineTargetBox.hasSize && fineHeaderBox != null && fineHeaderBox.hasSize) {
            final hBottom = fineHeaderBox.localToGlobal(Offset(0, fineHeaderBox.size.height)).dy;
            final tTop = fineTargetBox.localToGlobal(Offset.zero).dy;
            final fineDelta = (tTop - hBottom) - 12.0;
            final fineTarget = (_scrollController.offset + fineDelta).clamp(0.0, _scrollController.position.maxScrollExtent);
            _scrollController.animateTo(
              fineTarget,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
            ).then((_) {
              if (mounted) _isJumpingProgrammatically = false;
            });
            return;
          }
          if (mounted) _isJumpingProgrammatically = false;
        });
      });
    } else {
      _isJumpingProgrammatically = false;
    }
  }

  void _exportPdf(BuildContext context, AnalyticsProvider prov, AuthProvider auth);
  void _exportCsv(BuildContext context, AnalyticsProvider prov, AuthProvider auth);
  String _formatCurrency(double amount);
  void _showDashboardGuide(BuildContext context);
  Widget _buildBody(AnalyticsProvider prov, bool isDark, AuthProvider auth);
  Widget _buildPeriodChipsRow(AnalyticsProvider prov, bool isDark, {required bool isPreSelect});
  Widget _buildCustomScrollView(AnalyticsProvider prov, bool isDark);

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<AnalyticsProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        titleSpacing: 4,
        leadingWidth: 40,
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            "Inteligencia de Negocio",
            style: TextStyle(
              fontSize: 18.5,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.4,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (prov.currentStep == AnalyticsStep.done) ...[
            // 1. Personalizar Dashboard
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: const Icon(Icons.tune, size: 21),
              tooltip: "Personalizar Dashboard",
              onPressed: () {
                DashboardCustomizerModal.show(
                  context: context,
                  negocioId: auth.activeBusinessId ?? 0,
                  isDark: isDark,
                  currentSections: _sections,
                  onSaved: (newSections) {
                    setState(() {
                      _sections = newSections;
                      for (var s in _sections) {
                        _sectionKeys.putIfAbsent(s.id, () => GlobalKey());
                      }
                      for (var g in ['resumen', 'graficos', 'inventario', 'radar']) {
                        _chipKeys.putIfAbsent(g, () => GlobalKey());
                      }
                    });
                  },
                );
              },
            ),
            // 2. Ojo de Privacidad
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: Icon(_obscureAmounts ? Icons.visibility_off : Icons.visibility, size: 21),
              tooltip: _obscureAmounts ? "Mostrar Saldos" : "Ocultar Saldos",
              onPressed: () => setState(() => _obscureAmounts = !_obscureAmounts),
            ),
            // 3. Menú contextual ⋮ (Guía, Actualizar, Exportar)
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: const Icon(Icons.more_vert, size: 22),
              tooltip: "Más opciones",
              onSelected: (value) {
                switch (value) {
                  case 'refresh':
                    prov.runStaggeredAnalysis();
                    break;
                  case 'guide':
                    _showDashboardGuide(context);
                    break;
                  case 'pdf':
                    _exportPdf(context, prov, auth);
                    break;
                  case 'csv':
                    _exportCsv(context, prov, auth);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh, size: 20),
                      SizedBox(width: 10),
                      Text("Actualizar datos", style: TextStyle(fontSize: 13.5)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'guide',
                  child: Row(
                    children: [
                      Icon(Icons.help_outline, size: 20, color: Colors.blueAccent),
                      SizedBox(width: 10),
                      Text("Guía del Panel", style: TextStyle(fontSize: 13.5)),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'pdf',
                  child: Row(
                    children: [
                      Icon(Icons.picture_as_pdf_outlined, size: 20, color: Colors.redAccent),
                      SizedBox(width: 10),
                      Text("Exportar Informe (PDF)", style: TextStyle(fontSize: 13.5)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'csv',
                  child: Row(
                    children: [
                      Icon(Icons.table_chart_outlined, size: 20, color: Colors.green),
                      SizedBox(width: 10),
                      Text("Exportar Datos (CSV)", style: TextStyle(fontSize: 13.5)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
          ] else ...[
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              icon: const Icon(Icons.help_outline, size: 21),
              tooltip: "Guía del Panel",
              onPressed: () => _showDashboardGuide(context),
            ),
            const SizedBox(width: 4),
          ],
        ],
      ),
      body: _buildBody(prov, isDark, auth),
      floatingActionButton: prov.currentStep == AnalyticsStep.done
          ? ValueListenableBuilder<bool>(
              valueListenable: _isFabCompactNotifier,
              builder: (context, isCompact, _) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  child: isCompact
                      ? FloatingActionButton(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          tooltip: "Alertas de Reabastecimiento",
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const SmartRestockScreen()));
                          },
                          child: const Icon(Icons.add_alert),
                        )
                      : FloatingActionButton.extended(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const SmartRestockScreen()));
                          },
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          icon: const Icon(Icons.add_alert),
                          label: const Text(
                            'Alertas de Reabastecimiento',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                );
              },
            )
          : null,
    );
  }
}

class _AnalyticsDashboardScreenState extends _AnalyticsDashboardScreenStateBase
    with
        _AnalyticsDashboardStatesAndActionsMixin,
        _AnalyticsDashboardSectionsAndTabsMixin {}
