import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
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

class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  State<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> with TickerProviderStateMixin {
  bool _obscureAmounts = false;
  bool _isFabCompact = false;
  late ScrollController _scrollController;
  late AnimationController _pulseController;
  
  List<DashboardSectionConfig> _sections = DashboardSectionConfig.getDefaultSections();
  final Map<String, GlobalKey> _sectionKeys = {};

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _initializeKeys();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      _loadCustomSections(auth.activeBusinessId ?? 0);
      Provider.of<AnalyticsProvider>(context, listen: false).reset();
    });
  }

  void _initializeKeys() {
    for (var s in _sections) {
      _sectionKeys[s.id] = GlobalKey();
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
      });
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final isDown = _scrollController.position.userScrollDirection == ScrollDirection.reverse;
    if (isDown != _isFabCompact) {
      setState(() => _isFabCompact = isDown);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _exportPdf(BuildContext context, AnalyticsProvider prov, AuthProvider auth) async {
    if (prov.data == null) return;
    try {
      final file = await AnalyticsExportService.exportToPdf(prov.data!, auth.businessName);
      if (!context.mounted) return;
      // ignore: deprecated_member_use
      Share.shareXFiles([XFile(file.path)], text: 'Reporte Estadístico - ${auth.businessName}');
    } catch (e) {
      if (!context.mounted) return;
      CustomSnackBar.show(context, message: 'Error al exportar PDF: $e', isError: true);
    }
  }

  void _exportCsv(BuildContext context, AnalyticsProvider prov, AuthProvider auth) async {
    if (prov.data == null) return;
    try {
      final file = await AnalyticsExportService.exportToCsv(prov.data!, auth.businessName);
      if (!context.mounted) return;
      // ignore: deprecated_member_use
      Share.shareXFiles([XFile(file.path)], text: 'Datos CSV - ${auth.businessName}');
    } catch (e) {
      if (!context.mounted) return;
      CustomSnackBar.show(context, message: 'Error al exportar CSV: $e', isError: true);
    }
  }

  String _formatCurrency(double amount) {
    if (_obscureAmounts) return 'S/ ***.**';
    return AppCurrency.format(amount);
  }

  Future<void> _pickCustomDateRange(AnalyticsProvider prov) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: prov.customDateRange ?? DateTimeRange(
        start: now.subtract(const Duration(days: 30)),
        end: now,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blueAccent,
              brightness: Theme.of(context).brightness,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      prov.setCustomDateRange(picked);
    }
  }

  /// Salto dinámico sincronizado y tolerante a fallos (Mandatory Technical Rule #1)
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

    final key = _sectionKeys[targetSection.id];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
        alignment: 0.08,
      );
    } else {
      // Fallback seguro: aproximar scroll según posición relativa
      final visibleList = _sections.where((s) => s.isVisible).toList();
      final index = visibleList.indexWhere((s) => s.id == targetSection!.id);
      if (index != -1 && _scrollController.hasClients) {
        final double maxExtent = _scrollController.position.maxScrollExtent;
        final double estimatedOffset = (index / visibleList.length) * maxExtent;
        _scrollController.animateTo(
          estimatedOffset.clamp(0.0, maxExtent),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        ).then((_) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (key != null && key.currentContext != null) {
              Scrollable.ensureVisible(
                key.currentContext!,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
                alignment: 0.08,
              );
            }
          });
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final prov = Provider.of<AnalyticsProvider>(context);
    final auth = Provider.of<AuthProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        titleSpacing: 0,
        leadingWidth: 38,
        title: const Text(
          "Inteligencia de Negocio",
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: -0.5),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          const InfoTooltipButton(
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: 32, minHeight: 36),
            iconSize: 20,
            title: "Inteligencia de Negocio & Radar",
            description:
                "Panel de analítica ejecutiva, financiera y comercial. Integra predicción con IA, inventario estancado y radar de noticias del mercado en tiempo real.",
            tips: [
              InfoTip(
                icon: Icons.dashboard_customize,
                text: "Presiona el ícono de personalización (⚙️ / deslizador) para reordenar u ocultar tarjetas con arrastre táctil.",
              ),
              InfoTip(
                icon: Icons.radar,
                text: "El Radar Comercial sintoniza noticias de carreteras, clima, leyes de SUNAT y campañas en Perú y tu región.",
              ),
              InfoTip(
                icon: Icons.visibility_outlined,
                text: "Oculta saldos con el ícono del ojo para operar seguro frente a clientes en el mostrador.",
              ),
              InfoTip(
                icon: Icons.file_download_outlined,
                text: "Exporta tu informe completo en PDF formal o Excel CSV con la moneda oficial.",
              ),
            ],
          ),
          if (prov.currentStep == AnalyticsStep.done) ...[
            // Mandatory Technical Rule #4: Botón de personalización claro en AppBar
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
              icon: const Icon(Icons.tune, size: 21),
              tooltip: "Personalizar y Reordenar Dashboard",
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
                    });
                  },
                );
              },
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
              icon: const Icon(Icons.refresh, size: 21),
              tooltip: "Regenerar reporte",
              onPressed: () => prov.runStaggeredAnalysis(),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
              icon: Icon(_obscureAmounts ? Icons.visibility_off : Icons.visibility, size: 21),
              onPressed: () => setState(() => _obscureAmounts = !_obscureAmounts),
              tooltip: _obscureAmounts ? "Mostrar Saldos" : "Ocultar Saldos",
            ),
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
              icon: const Icon(Icons.download, size: 21),
              tooltip: "Exportar reporte",
              onSelected: (value) {
                if (value == 'pdf') _exportPdf(context, prov, auth);
                if (value == 'csv') _exportCsv(context, prov, auth);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'pdf', child: Text("Exportar a PDF")),
                const PopupMenuItem(value: 'csv', child: Text("Exportar a Excel (CSV)")),
              ],
            ),
            const SizedBox(width: 4),
          ],
        ],
      ),
      body: _buildBody(prov, isDark, auth),
      floatingActionButton: prov.currentStep == AnalyticsStep.done
          ? AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              child: _isFabCompact
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
            )
          : null,
    );
  }

  Widget _buildBody(AnalyticsProvider prov, bool isDark, AuthProvider auth) {
    if (prov.currentStep == AnalyticsStep.idle) {
      return _buildIdleScreen(prov, isDark);
    }

    if (prov.currentStep != AnalyticsStep.done && prov.currentStep != AnalyticsStep.error) {
      return _buildLoadingScreen(prov, isDark);
    }

    if (prov.currentStep == AnalyticsStep.error) {
      return _buildErrorScreen(prov);
    }

    return _buildCustomScrollView(prov, isDark);
  }

  /// Fase 2: Pantalla Pre-Carga (AnalyticsStep.idle) Rediseñada
  Widget _buildIdleScreen(AnalyticsProvider prov, bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Glowing pulsing halo icon
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blueAccent.withValues(alpha: 0.12 + (_pulseController.value * 0.1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueAccent.withValues(alpha: 0.25 * _pulseController.value),
                        blurRadius: 30 * _pulseController.value,
                        spreadRadius: 6 * _pulseController.value,
                      )
                    ],
                  ),
                  child: const Icon(Icons.query_stats, size: 72, color: Colors.blueAccent),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              "Inteligencia de Negocio & Radar",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
            ),
            const SizedBox(height: 8),
            Text(
              "Métricas auditadas a 0ms, proyecciones comerciales y señales de mercado en tiempo real para tu negocio.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14, 
                height: 1.4,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),

            // 4 Sleek Preview Cards
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 2.0,
              children: [
                _buildIdleFeatureBadge("📊 Ganancia Neta Real", "Sin margen de error", isDark),
                _buildIdleFeatureBadge("🚀 Motor Predictivo", "Tendencias de ventas", isDark),
                _buildIdleFeatureBadge("📦 Inventario Muerto", "Rescate de liquidez", isDark),
                _buildIdleFeatureBadge("📰 Radar Mercado IA", "Perú & Tu Región", isDark),
              ],
            ),
            const SizedBox(height: 24),

            // Pre-selección de Periodo
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        "Selecciona el periodo a analizar:",
                        style: TextStyle(
                          fontSize: 13, 
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.grey[300] : Colors.grey[800],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (prov.selectedPeriod == AnalyticsPeriod.custom && prov.customDateRange != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        "${DateFormat('dd/MM').format(prov.customDateRange!.start)} - ${DateFormat('dd/MM').format(prov.customDateRange!.end)}",
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 40,
                  child: _buildPeriodChipsRow(prov, isDark, isPreSelect: true),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Primary CTA Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => prov.runStaggeredAnalysis(),
                icon: const Icon(Icons.play_arrow_rounded, size: 24),
                label: const Text(
                  "Generar Reporte Integral", 
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildIdleFeatureBadge(String title, String subtitle, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              title, 
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold), 
              maxLines: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle, 
            style: TextStyle(fontSize: 10.5, color: isDark ? Colors.grey[400] : Colors.grey[600]), 
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen(AnalyticsProvider prov, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120, height: 120,
                  child: CircularProgressIndicator(
                    value: prov.progress, 
                    strokeWidth: 8, 
                    backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                  ),
                ),
                Text(
                  "${(prov.progress * 100).toInt()}%", 
                  style: const TextStyle(fontSize: 24, color: Colors.blueAccent, fontWeight: FontWeight.bold)
                ),
              ],
            ),
            const SizedBox(height: 40),
            _buildLoadingStep("Consultando ventas del periodo...", prov.currentStep.index > AnalyticsStep.sales.index, prov.currentStep == AnalyticsStep.sales, isDark),
            _buildLoadingStep("Evaluando mejores clientes y recurrencia...", prov.currentStep.index > AnalyticsStep.clients.index, prov.currentStep == AnalyticsStep.clients, isDark),
            _buildLoadingStep("Analizando rotación y capital inmovilizado...", prov.currentStep.index > AnalyticsStep.insights.index, prov.currentStep == AnalyticsStep.insights, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingStep(String text, bool isDone, bool isActive, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 24),
      child: Row(
        children: [
          Icon(
            isDone ? Icons.check_circle : (isActive ? Icons.hourglass_bottom : Icons.radio_button_unchecked),
            color: isDone ? Colors.greenAccent : (isActive ? Colors.blueAccent : (isDark ? Colors.white30 : Colors.black26)),
            size: 22,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                color: isDone 
                    ? (isDark ? Colors.white : Colors.black87) 
                    : (isActive ? Colors.blueAccent : (isDark ? Colors.white54 : Colors.black54)),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildErrorScreen(AnalyticsProvider prov) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 72, color: Colors.redAccent),
            const SizedBox(height: 20),
            Text(
              prov.statusMessage, 
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => prov.runStaggeredAnalysis(),
              icon: const Icon(Icons.refresh),
              label: const Text("Intentar Nuevamente"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            )
          ],
        ),
      ),
    );
  }

  /// Fase 3: CustomScrollView con Sticky Sliver Header y Salto Rápido
  Widget _buildCustomScrollView(AnalyticsProvider prov, bool isDark) {
    final data = prov.data!;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);

    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Cabecera Fija Pinned con Filtro de Tiempo y Salto Rápido
        SliverPersistentHeader(
          pinned: true,
          delegate: SliverStickyHeaderDelegate(
            minHeight: 98,
            maxHeight: 98,
            child: Container(
              color: bgColor,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Row 1: Chips de periodos con ShaderMask para desvanecimiento elegante
                  SizedBox(
                    height: 38,
                    child: ShaderMask(
                      shaderCallback: (Rect bounds) {
                        return const LinearGradient(
                          colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
                          stops: [0.0, 0.04, 0.96, 1.0],
                        ).createShader(bounds);
                      },
                      blendMode: BlendMode.dstIn,
                      child: _buildPeriodChipsRow(prov, isDark, isPreSelect: false),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Row 2: Chips de Salto Rápido dinámicos
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildQuickJumpChip("📊 Resumen", () => _jumpToGroup('resumen'), isDark),
                        const SizedBox(width: 8),
                        _buildQuickJumpChip("📈 Gráficos", () => _jumpToGroup('graficos'), isDark),
                        const SizedBox(width: 8),
                        _buildQuickJumpChip("📦 Inventario", () => _jumpToGroup('inventario'), isDark),
                        const SizedBox(width: 8),
                        _buildQuickJumpChip("📰 Radar Comercial", () => _jumpToGroup('radar'), isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Cuerpo Reordenable Dinámico
        SliverPadding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 140),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final visibleSections = _sections.where((s) => s.isVisible).toList();
                if (index >= visibleSections.length) return null;

                final section = visibleSections[index];
                return Padding(
                  key: _sectionKeys[section.id],
                  padding: const EdgeInsets.only(bottom: 20),
                  child: _buildSectionWidget(section.id, data, isDark, prov),
                );
              },
              childCount: _sections.where((s) => s.isVisible).length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickJumpChip(String label, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white12 : Colors.grey[300]!),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodChipsRow(AnalyticsProvider prov, bool isDark, {required bool isPreSelect}) {
    final periods = [
      {'val': AnalyticsPeriod.today, 'label': 'Hoy'},
      {'val': AnalyticsPeriod.week, 'label': '7 Días'},
      {'val': AnalyticsPeriod.month, 'label': '30 Días'},
      {'val': AnalyticsPeriod.sixMonths, 'label': '6 Meses'},
      {'val': AnalyticsPeriod.allTime, 'label': 'Todo'},
      {'val': AnalyticsPeriod.custom, 'label': 'Personalizado 📅'},
    ];

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: isPreSelect ? 0 : 16),
      itemCount: periods.length,
      separatorBuilder: (_, __) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final p = periods[index];
        final val = p['val'] as AnalyticsPeriod;
        final isSelected = prov.selectedPeriod == val;

        return ChoiceChip(
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
          label: Text(
            p['label'] as String, 
            style: TextStyle(
              fontSize: 11,
              color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          selected: isSelected,
          onSelected: (selected) {
            if (val == AnalyticsPeriod.custom) {
              _pickCustomDateRange(prov);
            } else {
              prov.changePeriod(val);
            }
          },
          selectedColor: Colors.blueAccent,
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.grey[200],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: isSelected ? Colors.blueAccent : (isDark ? Colors.white10 : Colors.grey[300]!),
            ),
          ),
          showCheckmark: false,
        );
      },
    );
  }

  Widget _buildSectionWidget(String id, AnalyticsData data, bool isDark, AnalyticsProvider prov) {
    switch (id) {
      case 'financial_summary':
        return FinancialSummaryCard(data: data, isDark: isDark, formatCurrency: _formatCurrency);
      case 'kpi_grid':
        return KpiSummaryRow(data: data, isDark: isDark, formatCurrency: _formatCurrency);
      case 'commercial_radar':
        return CommercialRadarCard(isDark: isDark);
      case 'predictive_engine':
        return _buildPredictiveButton(context, isDark);
      case 'insights_carousel':
        return InsightsCarousel(data: data, isDark: isDark);
      case 'restock_alerts':
        return RestockAlertsCard(data: data, isDark: isDark);
      case 'sales_evolution':
        return MonthlySalesChart(data: data, isDark: isDark, formatCurrency: _formatCurrency);
      case 'sales_by_day':
        return SalesByDayChart(data: data, isDark: isDark, formatCurrency: _formatCurrency);
      case 'sales_by_origin':
        return OriginPieChart(data: data, isDark: isDark, formatCurrency: _formatCurrency);
      case 'payment_methods':
        return PaymentMethodChart(data: data, isDark: isDark, formatCurrency: _formatCurrency);
      case 'top_categories':
        // Mandatory Technical Rule #3: 1 sola tarjeta inteligente de categorías unificadas
        return TopCategoriesCard(data: data, isDark: isDark, formatCurrency: _formatCurrency);
      case 'top_products':
        return TopProductsChart(data: data, isDark: isDark);
      case 'top_clients':
        return TopClientsCard(data: data, isDark: isDark, formatCurrency: _formatCurrency);
      case 'extra_metrics':
        return ExtraMetricsCard(data: data, isDark: isDark, formatCurrency: _formatCurrency);
      case 'dead_stock':
        return DeadStockCard(data: data, isDark: isDark);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPredictiveButton(BuildContext context, bool isDark) {
    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const PredictiveAnalyticsScreen()));
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6D28D9).withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.rocket_launch, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Motor Predictivo de Crecimiento", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text("Descubre proyecciones y tendencias con IA.", style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }
}
