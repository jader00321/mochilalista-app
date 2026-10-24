import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/features/scanner/providers/scanner_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/matching_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/smart_quotation_provider.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/core/widgets/floating_dock_session_state.dart';

// Pantallas destino de los 5 procesos
import 'package:app_movil/features/smart_quotation/screens/quick_sale_screen.dart';
import 'package:app_movil/features/scanner/screens/invoice_staging_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/matching_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/manual_quotation_screen.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/screens/product_create_screen.dart';

/// Modelo interno para discriminar tareas pendientes con enunciados limpios
class _PendingTaskItem {
  final String id;
  final String label;
  final int itemCount;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _PendingTaskItem({
    required this.id,
    required this.label,
    required this.itemCount,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

/// 💊 DeepNavReturnPill - Mobile Awards Retorno en 1 Toque con Física 2D y Edge Peek
///
/// Flota discretamente en rutas secundarias profundas (Catálogo, Clientes, Inventario, Historial, etc.)
/// cuando hay un proceso activo en segundo plano (Caja Rápida, Factura en Staging,
/// Conciliación de Lista Escolar, Cotización Manual o Producto en Espera), permitiendo retornar
/// instantáneamente sin perder contexto.
///
/// 🛡️ BLINDAJES RUNTIME Y EXPERIENCIA INTERACTIVA:
/// 1. Visibilidad garantizada en ventanas permitidas (sin depender de canPop ni de accesos rápidos del Home).
/// 2. 100% Desacoplada del Home mediante `SecondaryBubbleSessionState`.
/// 3. Seguimiento 1:1 en tiempo real a 0ms de latencia durante el arrastre libre 2D.
/// 4. Anclaje bilateral simétrico elástico en bordes izquierdo y derecho sin saltos.
/// 5. Modo Edge Peek pegado al ras del borde físico de la pantalla (left: 0.0 o screenWidth - tuckWidth).
/// 6. Diseño moderno en cápsula redondeada con icono semántico circular, enunciados concisos y sin chevron (>).
/// 7. Pulsación estacionaria (450ms sin mover <= 8px y soltar): rota la tarea activa sin navegar.
class DeepNavReturnPill extends StatefulWidget {
  /// Posición vertical inicial: true para abajo con padding seguro, false para arriba.
  final bool isBottom;

  /// Identificador de la pantalla actual para auto-ocultarse si coincide con la tarea activa.
  /// Valores esperados: 'quick_sale', 'scanner_staging', 'matching', 'manual_quote', 'product_create'.
  final String? currentScreenId;

  const DeepNavReturnPill({
    super.key,
    this.isBottom = true,
    this.currentScreenId,
  });

  @override
  State<DeepNavReturnPill> createState() => _DeepNavReturnPillState();
}

class _DeepNavReturnPillState extends State<DeepNavReturnPill> {
  // Estado de Arrastre 2D y Modo Oculto en Borde sincronizado exclusivamente en SecondaryBubbleSessionState
  late bool _isLeftEdge;
  late bool _isEdgeTucked;
  double? _panX;
  double? _panBottom;

  // Medición geométrica dinámica del ancho real de la cápsula
  final GlobalKey _pillKey = GlobalKey();
  double _measuredPillWidth = 148.0;

  // Detección precisa de pulsación estacionaria vs arrastre vs toque
  Timer? _stationaryTimer;
  Offset? _pointerDownPos;
  Offset? _pointerStartPillPos;
  bool _isDragging = false;
  bool _didTriggerStationaryLongPress = false;

  @override
  void initState() {
    super.initState();
    SecondaryBubbleSessionState.addListener(_onSessionStateChanged);
    _loadSessionState();
  }

  void _loadSessionState() {
    _isLeftEdge = SecondaryBubbleSessionState.isLeftEdge;
    _isEdgeTucked = SecondaryBubbleSessionState.isEdgeTucked;
    _panBottom = SecondaryBubbleSessionState.panBottom;
    _panX = SecondaryBubbleSessionState.panX;
  }

  void _onSessionStateChanged() {
    if (!mounted) return;
    if (_isDragging) return;
    setState(() {
      _loadSessionState();
    });
  }

  @override
  void dispose() {
    SecondaryBubbleSessionState.removeListener(_onSessionStateChanged);
    _stationaryTimer?.cancel();
    super.dispose();
  }

  void _syncSessionState({bool notify = true}) {
    SecondaryBubbleSessionState.updatePosition(
      isLeftEdge: _isLeftEdge,
      isEdgeTucked: _isEdgeTucked,
      panX: _panX,
      panBottom: _panBottom,
      notify: notify,
    );
  }

  void _checkPillWidth() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final renderBox = _pillKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null && renderBox.hasSize && renderBox.size.width > 30) {
        if ((_measuredPillWidth - renderBox.size.width).abs() > 1.0) {
          setState(() {
            _measuredPillWidth = renderBox.size.width;
          });
        }
      }
    });
  }

  List<_PendingTaskItem> _buildActiveTasks(BuildContext context) {
    final tasks = <_PendingTaskItem>[];

    final quickProv = Provider.of<QuickSaleProvider?>(context, listen: false);
    final scannerProv = Provider.of<ScannerProvider?>(context, listen: false);
    final matchingProv = Provider.of<MatchingProvider?>(context, listen: false);
    final smartProv = Provider.of<SmartQuotationProvider?>(context, listen: false);
    final invProv = Provider.of<InventoryProvider?>(context, listen: false);

    // 1. Caja Rápida con productos en carrito
    if (quickProv != null && quickProv.cartItems.isNotEmpty && widget.currentScreenId != 'quick_sale') {
      final count = quickProv.cartItems.length;
      tasks.add(_PendingTaskItem(
        id: 'quick_sale',
        label: 'Caja Rápida',
        itemCount: count,
        icon: Icons.point_of_sale_rounded,
        color: const Color(0xFF2E7D32),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const QuickSaleScreen()));
        },
      ));
    }

    // 2. Factura en Staging / Escáner
    if (scannerProv != null &&
        scannerProv.stagingData != null &&
        scannerProv.stagingData!.productosAgrupados.isNotEmpty &&
        widget.currentScreenId != 'scanner_staging') {
      final count = scannerProv.stagingData!.productosAgrupados.length;
      tasks.add(_PendingTaskItem(
        id: 'scanner_staging',
        label: 'Factura Staging',
        itemCount: count,
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFFE65100),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoiceStagingScreen()));
        },
      ));
    }

    // 3. Conciliación / Matching de Lista Escolar
    if (matchingProv != null && matchingProv.pairs.isNotEmpty && widget.currentScreenId != 'matching') {
      final count = matchingProv.pairs.length;
      tasks.add(_PendingTaskItem(
        id: 'matching',
        label: 'Conciliación',
        itemCount: count,
        icon: Icons.checklist_rounded,
        color: const Color(0xFF6A1B9A),
        onTap: () {
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
      ));
    }

    // 4. Borrador de Cotización Manual
    if (smartProv != null && smartProv.hasManualDraft && widget.currentScreenId != 'manual_quote') {
      final count = smartProv.draftManualItems?.length ?? 1;
      tasks.add(_PendingTaskItem(
        id: 'manual_quote',
        label: 'Cotización',
        itemCount: count,
        icon: Icons.edit_note_rounded,
        color: const Color(0xFF00838F),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ManualQuotationScreen(quotationId: null),
            ),
          );
        },
      ));
    }

    // 5. Borrador de Producto en Creación
    if (invProv != null && invProv.hasCreationDraft && widget.currentScreenId != 'product_create') {
      tasks.add(_PendingTaskItem(
        id: 'product_create',
        label: 'Producto Nuevo',
        itemCount: 1,
        icon: Icons.add_box_rounded,
        color: const Color(0xFF00897B),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductCreateScreen()));
        },
      ));
    }

    return tasks;
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider?>(context, listen: false);
    if (auth == null || !auth.hasActiveContext) return const SizedBox.shrink();

    // Re-evaluar dependencias reactivas de forma segura
    Provider.of<QuickSaleProvider?>(context);
    Provider.of<ScannerProvider?>(context);
    Provider.of<MatchingProvider?>(context);
    Provider.of<SmartQuotationProvider?>(context);
    Provider.of<InventoryProvider?>(context);

    final activeTasks = _buildActiveTasks(context);
    if (activeTasks.isEmpty) return const SizedBox.shrink();

    // Clamp seguro del índice seleccionado en SecondaryBubbleSessionState
    int selectedIndex = SecondaryBubbleSessionState.selectedTaskIndex;
    if (selectedIndex >= activeTasks.length) {
      selectedIndex = activeTasks.length - 1;
      SecondaryBubbleSessionState.selectedTaskIndex = selectedIndex;
    }
    if (selectedIndex < 0) {
      selectedIndex = 0;
      SecondaryBubbleSessionState.selectedTaskIndex = 0;
    }

    final currentTask = activeTasks[selectedIndex];

    // Auto-ocultar si el usuario ya se encuentra en la pantalla de esa única tarea
    if (activeTasks.length == 1 && widget.currentScreenId == currentTask.id) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    _checkPillWidth();

    return _buildPill(
      context,
      isDark: isDark,
      currentTask: currentTask,
      taskIndex: selectedIndex,
      totalTasks: activeTasks.length,
      activeTasks: activeTasks,
    );
  }

  Widget _buildPill(
    BuildContext context, {
    required bool isDark,
    required _PendingTaskItem currentTask,
    required int taskIndex,
    required int totalTasks,
    required List<_PendingTaskItem> activeTasks,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final safePadding = mediaQuery.padding;

    final defaultBottom = widget.isBottom
        ? InteractiveSheetWrapper.getEffectiveBottomPadding(context, minPadding: 80)
        : 16.0;

    final minBottom = safePadding.bottom + 16.0;
    final maxBottom = screenHeight - safePadding.top - 60.0;
    final effectiveBottom = (_panBottom ?? defaultBottom).clamp(minBottom, maxBottom);

    const double tuckWidth = 28.0;
    const double tuckHeight = 60.0;

    // =========================================================================
    // SUB-CASO A: PESTAÑA OCULTA AL RAS DEL BORDE (EDGE PEEK)
    // =========================================================================
    if (_isEdgeTucked) {
      final tuckLeft = _isLeftEdge ? 0.0 : (screenWidth - tuckWidth);

      return AnimatedPositioned(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        bottom: effectiveBottom,
        left: tuckLeft,
        width: tuckWidth,
        height: tuckHeight,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              _isEdgeTucked = false;
              _panX = null;
            });
            _syncSessionState();
          },
          onHorizontalDragUpdate: (details) {
            final pullingInward = _isLeftEdge ? details.delta.dx > 1 : details.delta.dx < -1;
            if (pullingInward) {
              setState(() {
                _isEdgeTucked = false;
                _panX = _isLeftEdge ? 24.0 : screenWidth - _measuredPillWidth - 24.0;
              });
              _syncSessionState();
            }
          },
          child: Container(
            width: tuckWidth,
            height: tuckHeight,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
              borderRadius: _isLeftEdge
                  ? const BorderRadius.horizontal(right: Radius.circular(18))
                  : const BorderRadius.horizontal(left: Radius.circular(18)),
              border: Border.all(
                color: currentTask.color,
                width: 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: currentTask.color.withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 1,
                  offset: Offset(_isLeftEdge ? 2 : -2, 2),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                _isLeftEdge ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
                color: currentTask.color,
                size: 20,
              ),
            ),
          ),
        ),
      );
    }

    // =========================================================================
    // SUB-CASO B: PÍLDORA FLOTANTE NORMAL (Arrastre libre 2D + Pulsación Estacionaria)
    // =========================================================================
    final double leftPos;
    if (_panX != null) {
      leftPos = _panX!.clamp(0.0, screenWidth - _measuredPillWidth);
    } else if (_isLeftEdge) {
      leftPos = 16.0;
    } else {
      leftPos = (screenWidth - _measuredPillWidth - 16.0).clamp(0.0, screenWidth - _measuredPillWidth);
    }

    return AnimatedPositioned(
      duration: _isDragging ? Duration.zero : const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      bottom: effectiveBottom,
      left: leftPos,
      child: Listener(
        onPointerDown: (event) {
          _pointerDownPos = event.position;
          _pointerStartPillPos = Offset(leftPos, effectiveBottom);
          _isDragging = false;
          _didTriggerStationaryLongPress = false;
          _stationaryTimer?.cancel();
          _stationaryTimer = Timer(const Duration(milliseconds: 450), () {
            if (!_isDragging && mounted) {
              _didTriggerStationaryLongPress = true;
              HapticFeedback.selectionClick();
              setState(() {});
            }
          });
        },
        onPointerMove: (event) {
          if (_pointerDownPos == null || _pointerStartPillPos == null) return;
          final delta = event.position - _pointerDownPos!;
          if (delta.distance > 8.0) {
            _stationaryTimer?.cancel();
            if (!_didTriggerStationaryLongPress) {
              if (!_isDragging) {
                _isDragging = true;
              }
              final newX = (_pointerStartPillPos!.dx + (event.position.dx - _pointerDownPos!.dx))
                  .clamp(0.0, screenWidth - _measuredPillWidth);
              final newBottom = (_pointerStartPillPos!.dy - (event.position.dy - _pointerDownPos!.dy))
                  .clamp(minBottom, maxBottom);
              setState(() {
                _panX = newX;
                _panBottom = newBottom;
              });
              _syncSessionState(notify: false);
            }
          }
        },
        onPointerUp: (event) {
          _stationaryTimer?.cancel();
          if (_didTriggerStationaryLongPress) {
            _didTriggerStationaryLongPress = false;
            _pointerDownPos = null;
            _pointerStartPillPos = null;
            _isDragging = false;
            if (activeTasks.length > 1) {
              setState(() {
                SecondaryBubbleSessionState.selectedTaskIndex =
                    (SecondaryBubbleSessionState.selectedTaskIndex + 1) % activeTasks.length;
              });
              HapticFeedback.selectionClick();
            } else {
              HapticFeedback.lightImpact();
            }
            _syncSessionState(notify: true);
            return;
          }

          if (_isDragging) {
            _isDragging = false;
            _pointerDownPos = null;
            _pointerStartPillPos = null;
            final currentX = _panX ?? leftPos;
            setState(() {
              if (currentX < 24.0) {
                _isEdgeTucked = true;
                _isLeftEdge = true;
              } else if (currentX > screenWidth - _measuredPillWidth - 24.0) {
                _isEdgeTucked = true;
                _isLeftEdge = false;
              } else {
                _isEdgeTucked = false;
                final bubbleCenterX = currentX + (_measuredPillWidth / 2.0);
                _isLeftEdge = bubbleCenterX < (screenWidth / 2.0);
              }
              _panX = null;
            });
            _syncSessionState(notify: true);
          } else {
            _pointerDownPos = null;
            _pointerStartPillPos = null;
            HapticFeedback.lightImpact();
            currentTask.onTap();
          }
        },
        onPointerCancel: (_) {
          _stationaryTimer?.cancel();
          _isDragging = false;
          _didTriggerStationaryLongPress = false;
          _pointerDownPos = null;
          _pointerStartPillPos = null;
        },
        child: Material(
          elevation: isDark ? 6 : 8,
          shadowColor: currentTask.color.withValues(alpha: isDark ? 0.35 : 0.25),
          borderRadius: BorderRadius.circular(28),
          color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            key: _pillKey,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: _didTriggerStationaryLongPress
                    ? currentTask.color
                    : currentTask.color.withValues(alpha: isDark ? 0.6 : 0.35),
                width: _didTriggerStationaryLongPress ? 2.5 : 1.5,
              ),
              boxShadow: _didTriggerStationaryLongPress
                  ? [
                      BoxShadow(
                        color: currentTask.color.withValues(alpha: 0.45),
                        blurRadius: 14,
                        spreadRadius: 2,
                      )
                    ]
                  : null,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.92, end: 1.0).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
                  ),
                  child: child,
                ),
              ),
              child: Row(
                key: ValueKey('${currentTask.id}_$taskIndex'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: currentTask.color.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        currentTask.icon,
                        size: 16,
                        color: currentTask.color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    currentTask.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: isDark ? Colors.white : const Color(0xFF1F2937),
                    ),
                  ),
                  if (totalTasks > 1) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: currentTask.color.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${taskIndex + 1}/$totalTasks',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: currentTask.color,
                        ),
                      ),
                    ),
                  ] else if (currentTask.itemCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: currentTask.color.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${currentTask.itemCount}',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: currentTask.color,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
