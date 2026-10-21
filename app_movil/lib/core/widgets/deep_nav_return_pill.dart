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

/// Modelo interno para discriminar tareas pendientes
class _PendingTaskItem {
  final String id;
  final String label;
  final String sublabel;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _PendingTaskItem({
    required this.id,
    required this.label,
    required this.sublabel,
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
/// 1. Solo se muestra si ModalRoute.canPop == true (oculto en IndexedStack de HomeScreen).
/// 2. Se auto-oculta si currentScreenId coincide con la tarea activa.
/// 3. Arrastre bidimensional libre (X e Y) por toda la pantalla (> 8px).
/// 4. Modo Edge Peek: al jalarla al borde o deslizarla hacia afuera, se contrae a una
///    pestaña luminosa en el borde, liberando el 100% de la pantalla sin estorbar.
/// 5. Pulsación Estacionaria (450ms sin mover <= 8px y soltar): NO navega, conmuta a la
///    siguiente tarea pendiente activa en `FloatingDockSessionState` con `AnimatedSwitcher` y `HapticFeedback`.
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
  // Estado de Arrastre 2D y Modo Oculto en Borde sincronizado en sesión
  late bool _isLeftEdge;
  late bool _isEdgeTucked;
  double? _panX;
  double? _panBottom;

  // Detección precisa de pulsación estacionaria vs arrastre vs toque
  Timer? _stationaryTimer;
  Offset? _pointerDownPos;
  bool _isDragging = false;
  bool _didTriggerStationaryLongPress = false;

  @override
  void initState() {
    super.initState();
    _isLeftEdge = FloatingDockSessionState.isLeftEdge;
    _isEdgeTucked = FloatingDockSessionState.isEdgeTucked;
    _panBottom = FloatingDockSessionState.panBottom;
    _panX = FloatingDockSessionState.panX;
  }

  @override
  void dispose() {
    _stationaryTimer?.cancel();
    super.dispose();
  }

  void _syncSessionState() {
    FloatingDockSessionState.isLeftEdge = _isLeftEdge;
    FloatingDockSessionState.isEdgeTucked = _isEdgeTucked;
    FloatingDockSessionState.panBottom = _panBottom;
    FloatingDockSessionState.panX = _panX;
  }

  List<_PendingTaskItem> _buildActiveTasks(BuildContext context) {
    final tasks = <_PendingTaskItem>[];

    final quickProv = Provider.of<QuickSaleProvider>(context, listen: false);
    final scannerProv = Provider.of<ScannerProvider>(context, listen: false);
    final matchingProv = Provider.of<MatchingProvider>(context, listen: false);
    final smartProv = Provider.of<SmartQuotationProvider>(context, listen: false);
    final invProv = Provider.of<InventoryProvider>(context, listen: false);

    // 1. Caja Rápida con productos en carrito
    if (quickProv.cartItems.isNotEmpty && widget.currentScreenId != 'quick_sale') {
      final count = quickProv.cartItems.length;
      final total = quickProv.totalToPay;
      tasks.add(_PendingTaskItem(
        id: 'quick_sale',
        label: 'Caja Rápida ($count)',
        sublabel: 'S/ ${total.toStringAsFixed(2)}',
        icon: Icons.point_of_sale_rounded,
        color: const Color(0xFF2E7D32),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const QuickSaleScreen()));
        },
      ));
    }

    // 2. Factura en Staging / Escáner
    if (scannerProv.stagingData != null &&
        scannerProv.stagingData!.productosAgrupados.isNotEmpty &&
        widget.currentScreenId != 'scanner_staging') {
      final count = scannerProv.stagingData!.productosAgrupados.length;
      tasks.add(_PendingTaskItem(
        id: 'scanner_staging',
        label: 'Factura en Staging',
        sublabel: '$count grupos pendientes',
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFFE65100),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoiceStagingScreen()));
        },
      ));
    }

    // 3. Conciliación / Matching de Lista Escolar
    if (matchingProv.pairs.isNotEmpty && widget.currentScreenId != 'matching') {
      final count = matchingProv.pairs.length;
      final total = matchingProv.totalNetAmount;
      tasks.add(_PendingTaskItem(
        id: 'matching',
        label: 'Conciliación Lista',
        sublabel: '$count ítems • S/ ${total.toStringAsFixed(2)}',
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
    if (smartProv.hasManualDraft && widget.currentScreenId != 'manual_quote') {
      final count = smartProv.draftManualItems?.length ?? 0;
      tasks.add(_PendingTaskItem(
        id: 'manual_quote',
        label: 'Cotización en curso',
        sublabel: '$count ítems',
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
    if (invProv.hasCreationDraft && widget.currentScreenId != 'product_create') {
      final draft = invProv.creationDraft!;
      final name = draft.name.trim().isNotEmpty ? draft.name.trim() : 'Nuevo Producto';
      final presCount = draft.presentations.length;
      tasks.add(_PendingTaskItem(
        id: 'product_create',
        label: 'Producto en espera',
        sublabel: presCount <= 1 ? name : '$name • $presCount var.',
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
    // 🛡️ Regla 1: Ocultar si estamos en el nivel raíz (ej. HomeScreen IndexedStack)
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    if (!canPop) return const SizedBox.shrink();

    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.hasActiveContext) return const SizedBox.shrink();

    // Re-evaluar dependencias reactivas
    Provider.of<QuickSaleProvider>(context);
    Provider.of<ScannerProvider>(context);
    Provider.of<MatchingProvider>(context);
    Provider.of<SmartQuotationProvider>(context);
    Provider.of<InventoryProvider>(context);

    final activeTasks = _buildActiveTasks(context);
    if (activeTasks.isEmpty) return const SizedBox.shrink();

    // Clamp del índice seleccionado
    int selectedIndex = FloatingDockSessionState.selectedTaskIndex;
    if (selectedIndex >= activeTasks.length) {
      selectedIndex = activeTasks.length - 1;
      FloatingDockSessionState.selectedTaskIndex = selectedIndex;
    }
    if (selectedIndex < 0) {
      selectedIndex = 0;
      FloatingDockSessionState.selectedTaskIndex = 0;
    }

    final currentTask = activeTasks[selectedIndex];
    final isDark = Theme.of(context).brightness == Brightness.dark;

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

    // =========================================================================
    // SUB-CASO A: PESTAÑA OCULTA EN EL BORDE (EDGE PEEK)
    // =========================================================================
    if (_isEdgeTucked) {
      return AnimatedPositioned(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        bottom: effectiveBottom,
        left: _isLeftEdge ? 0 : null,
        right: !_isLeftEdge ? 0 : null,
        width: 28,
        height: 60,
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
                _panX = _isLeftEdge ? 20.0 : screenWidth - 180.0;
              });
              _syncSessionState();
            }
          },
          child: Container(
            width: 28,
            height: 60,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF222230) : Colors.white,
              borderRadius: _isLeftEdge
                  ? const BorderRadius.horizontal(right: Radius.circular(16))
                  : const BorderRadius.horizontal(left: Radius.circular(16)),
              border: Border.all(
                color: currentTask.color,
                width: 2.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: currentTask.color.withValues(alpha: 0.45),
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
    // SUB-CASO B: PÍLDORA FLOTANTE NORMAL (Arrastre libre 2D en X e Y + Pulsación Estacionaria)
    // =========================================================================
    final double? leftPos;
    final double? rightPos;

    if (_panX != null) {
      leftPos = _panX!.clamp(0.0, screenWidth - 120.0);
      rightPos = null;
    } else if (_isLeftEdge) {
      leftPos = 16.0;
      rightPos = null;
    } else {
      leftPos = null;
      rightPos = 16.0;
    }

    return AnimatedPositioned(
      duration: _panX != null ? Duration.zero : const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      bottom: effectiveBottom,
      left: leftPos,
      right: rightPos,
      child: Listener(
        onPointerDown: (event) {
          _pointerDownPos = event.position;
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
          if (_pointerDownPos == null) return;
          final delta = event.position - _pointerDownPos!;
          if (delta.distance > 8.0) {
            _stationaryTimer?.cancel();
            if (!_didTriggerStationaryLongPress) {
              if (!_isDragging) {
                _isDragging = true;
              }
              setState(() {
                final startX = _panX ?? (_isLeftEdge ? 16.0 : screenWidth - 200.0);
                _panX = (startX + event.localDelta.dx).clamp(0.0, screenWidth - 120.0);
                _panBottom = (effectiveBottom - event.localDelta.dy).clamp(minBottom, maxBottom);
              });
              _syncSessionState();
            }
          }
        },
        onPointerUp: (event) {
          _stationaryTimer?.cancel();
          if (_didTriggerStationaryLongPress) {
            _didTriggerStationaryLongPress = false;
            _pointerDownPos = null;
            if (activeTasks.length > 1) {
              setState(() {
                FloatingDockSessionState.selectedTaskIndex =
                    (FloatingDockSessionState.selectedTaskIndex + 1) % activeTasks.length;
              });
              HapticFeedback.selectionClick();
            } else {
              HapticFeedback.lightImpact();
            }
            return;
          }

          if (_isDragging) {
            _isDragging = false;
            _pointerDownPos = null;
            final currentX = _panX ?? (_isLeftEdge ? 16.0 : screenWidth - 200.0);
            setState(() {
              if (currentX < 20.0) {
                _isEdgeTucked = true;
                _isLeftEdge = true;
              } else if (currentX > screenWidth - 100.0) {
                _isEdgeTucked = true;
                _isLeftEdge = false;
              } else {
                _isEdgeTucked = false;
                _isLeftEdge = currentX < (screenWidth / 2);
              }
              _panX = null;
            });
            _syncSessionState();
          } else {
            _pointerDownPos = null;
            HapticFeedback.lightImpact();
            currentTask.onTap();
          }
        },
        onPointerCancel: (_) {
          _stationaryTimer?.cancel();
          _isDragging = false;
          _didTriggerStationaryLongPress = false;
          _pointerDownPos = null;
        },
        child: Material(
          elevation: isDark ? 6 : 8,
          shadowColor: currentTask.color.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(30),
          color: isDark ? const Color(0xFF222230) : Colors.white,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: _didTriggerStationaryLongPress
                    ? currentTask.color
                    : currentTask.color.withValues(alpha: isDark ? 0.6 : 0.35),
                width: _didTriggerStationaryLongPress ? 2.5 : 1.5,
              ),
              boxShadow: _didTriggerStationaryLongPress
                  ? [
                      BoxShadow(
                        color: currentTask.color.withValues(alpha: 0.4),
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ]
                  : null,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              ),
              child: Row(
                key: ValueKey('${currentTask.id}_$taskIndex'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: currentTask.color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(currentTask.icon, size: 16, color: currentTask.color),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            currentTask.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          if (totalTasks > 1) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: currentTask.color.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${taskIndex + 1}/$totalTasks',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: currentTask.color,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        currentTask.sublabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 12,
                    color: currentTask.color,
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
