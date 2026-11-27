import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/core/services/lifecycle_resume_coordinator.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/core/widgets/floating_dock_session_state.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/features/catalog/providers/inventory_provider.dart';
import 'package:app_movil/features/catalog/screens/product_create_screen.dart';
import 'package:app_movil/features/scanner/providers/scanner_provider.dart';
import 'package:app_movil/features/scanner/screens/invoice_staging_screen.dart';
import 'package:app_movil/features/smart_quotation/providers/matching_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/quick_sale_provider.dart';
import 'package:app_movil/features/smart_quotation/providers/smart_quotation_provider.dart';
import 'package:app_movil/features/smart_quotation/screens/manual_quotation_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/matching_screen.dart';
import 'package:app_movil/features/smart_quotation/screens/quick_sale_screen.dart';

part 'persistent_work_dock/persistent_work_dock_tasks_part.dart';
part 'persistent_work_dock/persistent_work_dock_bubble_and_bar_part.dart';

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

/// Dock persistente multi-proceso con modo globo flotante magnético y edge peek.
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

  late bool _isBubble;
  late bool _isLeftEdge;
  late bool _isEdgeTucked;
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
    LifecycleResumeCoordinator.instance.registerController(_pulseController);
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
    LifecycleResumeCoordinator.instance.unregisterController(_pulseController);
    _pulseController.dispose();
    super.dispose();
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

  void _untuckFromTap() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isEdgeTucked = false;
    });
    _syncSessionState();
  }

  void _untuckFromDrag(double screenWidth) {
    setState(() {
      _isEdgeTucked = false;
      _bubblePanX = _isLeftEdge ? 24.0 : screenWidth - 82.0;
    });
    _syncSessionState();
  }

  void _updateBubblePan(
    DragUpdateDetails details, {
    required double screenWidth,
    required double minBottom,
    required double maxBottom,
  }) {
    setState(() {
      final currentStartX =
          _bubblePanX ?? (_isLeftEdge ? 16.0 : screenWidth - 74.0);
      _bubblePanX = (currentStartX + details.delta.dx).clamp(
        0.0,
        screenWidth - 58.0,
      );
      _bubbleBottom = (_bubbleBottom - details.delta.dy).clamp(
        minBottom,
        maxBottom,
      );
    });
    _syncSessionState();
  }

  void _snapBubbleToEdge(DragEndDetails details, double screenWidth) {
    final velocityX = details.velocity.pixelsPerSecond.dx;
    final currentX = _bubblePanX ?? (_isLeftEdge ? 16.0 : screenWidth - 74.0);

    setState(() {
      if (currentX < 24.0 || velocityX < -650) {
        _isEdgeTucked = true;
        _isLeftEdge = true;
      } else if (currentX > screenWidth - 82.0 || velocityX > 650) {
        _isEdgeTucked = true;
        _isLeftEdge = false;
      } else {
        _isEdgeTucked = false;
        _isLeftEdge = currentX < (screenWidth / 2);
      }
      _bubblePanX = null;
    });
    _syncSessionState();
  }

  void _selectTaskIndex(int index) {
    HapticFeedback.selectionClick();
    setState(() => _selectedTaskIndex = index);
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

    if (!hasTasks) {
      return const SizedBox.shrink();
    }

    if (_selectedTaskIndex >= tasks.length) {
      _selectedTaskIndex = 0;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentTask = tasks[_selectedTaskIndex];
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final safePadding = mediaQuery.padding;

    final minBottom = safePadding.bottom + 16.0;
    final maxBottom = screenHeight - safePadding.top - 74.0;

    if (_isBubble) {
      if (_isEdgeTucked) {
        return _buildEdgePeekTab(
          isDark: isDark,
          currentTask: currentTask,
          screenWidth: screenWidth,
          minBottom: minBottom,
          maxBottom: maxBottom,
        );
      }

      return _buildFloatingBubble(
        isDark: isDark,
        tasks: tasks,
        currentTask: currentTask,
        screenWidth: screenWidth,
        minBottom: minBottom,
        maxBottom: maxBottom,
      );
    }

    return _buildExpandedDockBar(
      context: context,
      isDark: isDark,
      tasks: tasks,
      currentTask: currentTask,
    );
  }
}
