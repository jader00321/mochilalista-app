import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/features/scanner/providers/scanner_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/matching_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/smart_quotation_provider.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

// Pantallas destino
import 'package:app_movil/features/smart_quotation/screens/quick_sale_screen.dart';
import 'package:app_movil/features/scanner/screens/invoice_staging_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/matching_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/manual_quotation_screen.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/screens/product_create_screen.dart';
import 'package:app_movil/core/widgets/floating_dock_session_state.dart';

/// Modelo ligero para representar un proceso de trabajo activo en el Dock.
class WorkTask {
  final String id;
  final String title;
  final String shortTitle;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onResume;
  final VoidCallback? onDiscard;

  const WorkTask({
    required this.id,
    required this.title,
    required this.shortTitle,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onResume,
    this.onDiscard,
  });
}

/// 🌟 PersistentWorkDock - Mobile Awards Multi-Proceso con Globo Flotante Magnético
class PersistentWorkDock extends StatefulWidget {
  final bool isFloating;
  final EdgeInsetsGeometry? margin;
  final ValueChanged<bool>? onBubbleModeChanged;
  final ValueChanged<bool>? onTasksChanged;

  const PersistentWorkDock({
    super.key,
    this.isFloating = true,
    this.margin,
    this.onBubbleModeChanged,
    this.onTasksChanged,
  });

  @override
  State<PersistentWorkDock> createState() => _PersistentWorkDockState();
}

class _PersistentWorkDockState extends State<PersistentWorkDock>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  int _selectedTaskIndex = 0;

  // Estado del Globo Flotante 2D y Modo Oculto en Borde (Edge Peek) sincronizado en sesión
  late bool _isBubble;
  late bool _isLeftEdge;
  late bool _isEdgeTucked; // Estado oculto en el borde mostrando solo pestaña
  late double _bubbleBottom;
  double? _bubblePanX;
  bool _hadTasks = false;

  @override
  void initState() {
    super.initState();
    _isBubble = FloatingDockSessionState.isBubble;
    _isLeftEdge = FloatingDockSessionState.isLeftEdge;
    _isEdgeTucked = FloatingDockSessionState.isEdgeTucked;
    _bubbleBottom = FloatingDockSessionState.panBottom ?? 80.0;
    _bubblePanX = FloatingDockSessionState.panX;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  void _syncSessionState() {
    FloatingDockSessionState.isBubble = _isBubble;
    FloatingDockSessionState.isLeftEdge = _isLeftEdge;
    FloatingDockSessionState.isEdgeTucked = _isEdgeTucked;
    FloatingDockSessionState.panBottom = _bubbleBottom;
    FloatingDockSessionState.panX = _bubblePanX;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  List<WorkTask> _gatherActiveTasks(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.hasActiveContext) return [];

    final tasks = <WorkTask>[];

    // 1. Caja Rápida
    final quickProv = Provider.of<QuickSaleProvider>(context);
    if (quickProv.cartItems.isNotEmpty) {
      final count = quickProv.cartItems.length;
      final total = quickProv.totalToPay;
      tasks.add(
        WorkTask(
          id: 'quick_sale',
          title: 'Caja Rápida',
          shortTitle: 'Caja',
          subtitle: '$count ítems • S/ ${total.toStringAsFixed(2)}',
          icon: Icons.point_of_sale_rounded,
          color: const Color(0xFF2E7D32),
          onResume: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QuickSaleScreen()),
            );
          },
          onDiscard: () {
            _confirmDiscard(
              context,
              title: '¿Descartar Caja Rápida?',
              message: 'Se limpiarán los productos agregados a la venta rápida.',
              onConfirm: () => quickProv.clearCart(),
            );
          },
        ),
      );
    }

    // 2. Factura en Staging / Escáner
    final scannerProv = Provider.of<ScannerProvider>(context);
    if (scannerProv.stagingData != null &&
        scannerProv.stagingData!.productosAgrupados.isNotEmpty) {
      final groupsCount = scannerProv.stagingData!.productosAgrupados.length;
      tasks.add(
        WorkTask(
          id: 'scanner_staging',
          title: 'Factura en Staging',
          shortTitle: 'Factura',
          subtitle: '$groupsCount grupos pendientes de ingreso',
          icon: Icons.receipt_long_rounded,
          color: const Color(0xFFE65100),
          onResume: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InvoiceStagingScreen()),
            );
          },
          onDiscard: () {
            _confirmDiscard(
              context,
              title: '¿Descartar Factura?',
              message: 'Se perderán los datos extraídos de la factura pendiente.',
              onConfirm: () => scannerProv.clearData(),
            );
          },
        ),
      );
    }

    // 3. Conciliación / Matching
    final matchingProv = Provider.of<MatchingProvider>(context);
    if (matchingProv.pairs.isNotEmpty) {
      final count = matchingProv.pairs.length;
      final total = matchingProv.totalNetAmount;
      tasks.add(
        WorkTask(
          id: 'matching',
          title: 'Conciliación IA',
          shortTitle: 'Conciliación',
          subtitle: '$count ítems • S/ ${total.toStringAsFixed(2)}',
          icon: Icons.auto_awesome_rounded,
          color: const Color(0xFF5E35B1),
          onResume: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MatchingScreen(
                  extractedItems: matchingProv.pairs.map((p) => p.sourceItem).toList(),
                  metadata: matchingProv.metadata,
                ),
              ),
            );
          },
          onDiscard: () {
            _confirmDiscard(
              context,
              title: '¿Descartar Conciliación?',
              message: 'Se perderán los ítems extraídos de la lista escolar.',
              onConfirm: () => matchingProv.clearState(),
            );
          },
        ),
      );
    }

    // 4. Borrador de Cotización Manual
    final smartProv = Provider.of<SmartQuotationProvider>(context);
    if (smartProv.hasManualDraft) {
      final count = smartProv.draftManualItems?.length ?? 0;
      final title = smartProv.draftQuoteTitle?.isNotEmpty == true
          ? smartProv.draftQuoteTitle!
          : 'Cotización en progreso';
      tasks.add(
        WorkTask(
          id: 'manual_quote',
          title: 'Borrador de Cotización',
          shortTitle: 'Borrador',
          subtitle: '$count ítems • $title',
          icon: Icons.edit_note_rounded,
          color: const Color(0xFF00838F),
          onResume: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ManualQuotationScreen(quotationId: null),
              ),
            );
          },
          onDiscard: () {
            _confirmDiscard(
              context,
              title: '¿Descartar Borrador?',
              message: 'Se eliminará la cotización manual guardada como borrador.',
              onConfirm: () => smartProv.clearManualDraft(),
            );
          },
        ),
      );
    }

    // 5. Borrador de Producto en Creación
    final invProv = Provider.of<InventoryProvider>(context);
    if (invProv.hasCreationDraft) {
      final draft = invProv.creationDraft!;
      final name = draft.name.trim().isNotEmpty
          ? draft.name.trim()
          : 'Nuevo Producto';
      final presCount = draft.presentations.length;
      final subtitle = presCount <= 1
          ? '$name • 1 presentación'
          : '$name • $presCount presentaciones';

      tasks.add(
        WorkTask(
          id: 'product_create',
          title: 'Producto en Creación',
          shortTitle: 'Producto',
          subtitle: subtitle,
          icon: Icons.add_box_rounded,
          color: const Color(0xFF00897B),
          onResume: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ProductCreateScreen(),
              ),
            );
          },
          onDiscard: () {
            _confirmDiscard(
              context,
              title: '¿Descartar Producto?',
              message: 'Se perderán los datos del producto que estabas creando.',
              onConfirm: () => invProv.clearCreationDraft(),
            );
          },
        ),
      );
    }

    return tasks;
  }

  void _confirmDiscard(
    BuildContext context, {
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E28) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
  }

  void _minimizeToBubble({required bool isLeft}) {
    HapticFeedback.mediumImpact();
    setState(() {
      _isBubble = true;
      _isLeftEdge = isLeft;
      _isEdgeTucked = false;
      _bubblePanX = null;
    });
    _syncSessionState();
    widget.onBubbleModeChanged?.call(true);
  }

  void _expandFromBubble() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isBubble = false;
      _isEdgeTucked = false;
      _bubblePanX = null;
    });
    _syncSessionState();
    widget.onBubbleModeChanged?.call(false);
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _gatherActiveTasks(context);
    final hasTasks = tasks.isNotEmpty;

    if (hasTasks != _hadTasks) {
      _hadTasks = hasTasks;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onTasksChanged?.call(hasTasks);
      });
    }

    if (!hasTasks) return const SizedBox.shrink();

    if (_selectedTaskIndex >= tasks.length) {
      _selectedTaskIndex = 0;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentTask = tasks[_selectedTaskIndex];
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final safePadding = mediaQuery.padding;

    // Cotas de movimiento vertical 2D para no invadir notch ni botones del sistema
    final minBottom = safePadding.bottom + 16.0;
    final maxBottom = screenHeight - safePadding.top - 74.0;

    // =========================================================================
    // CASO 1: MODO GLOBO FLOTANTE 2D + MODO OCULTO EN BORDE (EDGE PEEK)
    // =========================================================================
    if (_isBubble) {
      // SUB-CASO 1.A: PESTAÑA OCULTA EN EL BORDE (EDGE PEEK)
      if (_isEdgeTucked) {
        return AnimatedPositioned(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          bottom: _bubbleBottom.clamp(minBottom, maxBottom),
          left: _isLeftEdge ? 0 : null,
          right: !_isLeftEdge ? 0 : null,
          width: 28,
          height: 64,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              setState(() {
                _isEdgeTucked = false;
              });
              _syncSessionState();
            },
            onHorizontalDragUpdate: (details) {
              final pullingInward = _isLeftEdge ? details.delta.dx > 1 : details.delta.dx < -1;
              if (pullingInward) {
                setState(() {
                  _isEdgeTucked = false;
                  _bubblePanX = _isLeftEdge ? 24.0 : screenWidth - 82.0;
                });
                _syncSessionState();
              }
            },
            child: Container(
              width: 28,
              height: 64,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
                borderRadius: _isLeftEdge
                    ? const BorderRadius.horizontal(right: Radius.circular(18))
                    : const BorderRadius.horizontal(left: Radius.circular(18)),
                border: Border.all(
                  color: currentTask.color,
                  width: 2.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: currentTask.color.withValues(alpha: 0.45),
                    blurRadius: 14,
                    spreadRadius: 1,
                    offset: Offset(_isLeftEdge ? 2 : -2, 2),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  _isLeftEdge ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
                  color: currentTask.color,
                  size: 22,
                ),
              ),
            ),
          ),
        );
      }

      // SUB-CASO 1.B: GLOBO FLOTANTE NORMAL (Arrastre libre en 2D X e Y)
      final double? leftPos;
      final double? rightPos;

      if (_bubblePanX != null) {
        leftPos = _bubblePanX!.clamp(0.0, screenWidth - 58.0);
        rightPos = null;
      } else if (_isLeftEdge) {
        leftPos = 16.0;
        rightPos = null;
      } else {
        leftPos = null;
        rightPos = 16.0;
      }

      return AnimatedPositioned(
        duration: _bubblePanX != null ? Duration.zero : const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        bottom: _bubbleBottom.clamp(minBottom, maxBottom),
        left: leftPos,
        right: rightPos,
        width: 58,
        height: 58,
        child: GestureDetector(
          onTap: _expandFromBubble,
          onPanUpdate: (details) {
            setState(() {
              final currentStartX = _bubblePanX ?? (_isLeftEdge ? 16.0 : screenWidth - 74.0);
              _bubblePanX = (currentStartX + details.delta.dx).clamp(0.0, screenWidth - 58.0);
              _bubbleBottom = (_bubbleBottom - details.delta.dy).clamp(minBottom, maxBottom);
            });
            _syncSessionState();
          },
          onPanEnd: (details) {
            final velocityX = details.velocity.pixelsPerSecond.dx;
            final currentX = _bubblePanX ?? (_isLeftEdge ? 16.0 : screenWidth - 74.0);

            setState(() {
              // Si se arroja o jala fuertemente contra el borde -> Modo Edge Peek
              if (currentX < 24.0 || velocityX < -650) {
                _isEdgeTucked = true;
                _isLeftEdge = true;
              } else if (currentX > screenWidth - 82.0 || velocityX > 650) {
                _isEdgeTucked = true;
                _isLeftEdge = false;
              } else {
                // Magnetismo suave hacia el lateral más cercano
                _isEdgeTucked = false;
                _isLeftEdge = currentX < (screenWidth / 2);
              }
              _bubblePanX = null;
            });
            _syncSessionState();
          },
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final pulse = 1.0 + (_pulseController.value * 0.08);
              return Transform.scale(
                scale: pulse,
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: currentTask.color,
                      width: 2.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: currentTask.color.withValues(alpha: 0.4),
                        blurRadius: 16,
                        spreadRadius: 1,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        currentTask.icon,
                        color: currentTask.color,
                        size: 26,
                      ),
                      if (tasks.length > 1)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              "${tasks.length}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    // =========================================================================
    // CASO 2: MODO EXPANDIDO (Barra Completa con Swipe para Minimizar)
    // =========================================================================
    final hasMultiple = tasks.length > 1;
    final effectiveBottom = widget.isFloating
        ? InteractiveSheetWrapper.getEffectiveBottomPadding(context, minPadding: 16)
        : 0.0;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0.0;
          if (velocity < -250) {
            _minimizeToBubble(isLeft: true);
          } else if (velocity > 250) {
            _minimizeToBubble(isLeft: false);
          }
        },
        child: Container(
          margin: widget.margin ??
              EdgeInsets.fromLTRB(16, 8, 16, effectiveBottom),
          child: Material(
            elevation: isDark ? 6 : 14,
            shadowColor: currentTask.color.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(22),
            color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: currentTask.color.withValues(alpha: isDark ? 0.45 : 0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Barra de Pestañas Compacta (si hay múltiples tareas)
                  if (hasMultiple)
                    GestureDetector(
                      // Aislar gestos horizontales en las pestañas para no disparar el colapso a globo
                      onHorizontalDragStart: (_) {},
                      onHorizontalDragUpdate: (_) {},
                      onHorizontalDragEnd: (_) {},
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.3)
                              : Colors.grey.shade100,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(21)),
                        ),
                        child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: tasks.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (ctx, i) {
                          final t = tasks[i];
                          final isSelected = i == _selectedTaskIndex;
                          return InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _selectedTaskIndex = i);
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? t.color.withValues(alpha: 0.18)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? t.color.withValues(alpha: 0.6)
                                      : Colors.transparent,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(t.icon, size: 14, color: isSelected ? t.color : Colors.grey),
                                  const SizedBox(width: 5),
                                  Text(
                                    t.shortTitle,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      color: isSelected ? t.color : (isDark ? Colors.grey[400] : Colors.grey[700]),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // Fila Principal con Ajuste Tipográfico (Zero Truncamiento)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        // Avatar con pulso
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            final pulse = 1.0 + (_pulseController.value * 0.08);
                            return Transform.scale(
                              scale: pulse,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: currentTask.color.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: currentTask.color.withValues(alpha: 0.5),
                                    width: 1.5,
                                  ),
                                ),
                                child: Icon(
                                  currentTask.icon,
                                  color: currentTask.color,
                                  size: 20,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(width: 10),

                        // Columna de Título y Subtítulo con FittedBox
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  currentTask.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                currentTask.subtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Botón Descartar (Compacto)
                        if (currentTask.onDiscard != null)
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            tooltip: 'Descartar',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            color: isDark ? Colors.grey[400] : Colors.grey[500],
                            onPressed: currentTask.onDiscard,
                          ),
                        const SizedBox(width: 4),

                        // Botón Reanudar (Estilizado y Compacto)
                        ElevatedButton(
                          onPressed: currentTask.onResume,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: currentTask.color,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 1.5,
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_arrow_rounded, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'Reanudar',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),

                        // Botón Minimizar a Globo
                        IconButton(
                          icon: Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 28),
                          tooltip: 'Minimizar a globo',
                          onPressed: () => _minimizeToBubble(isLeft: false),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
