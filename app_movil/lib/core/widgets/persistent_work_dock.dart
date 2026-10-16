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

/// Modelo ligero para representar un proceso de trabajo activo en el Dock.
class WorkTask {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onResume;
  final VoidCallback? onDiscard;

  const WorkTask({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onResume,
    this.onDiscard,
  });
}

/// 🌟 PersistentWorkDock - Mobile Awards Multi-Proceso
///
/// Muestra dinámicamente las tareas en pausa o segundo plano:
/// 1. Caja Rápida en curso
/// 2. Escáner / Staging de Facturas
/// 3. Conciliación / Matching de Listas Escolares
/// 4. Borrador de Cotización Manual
///
/// Aislado estrictamente por negocio (`activeBusinessId`) para evitar state leaks.
class PersistentWorkDock extends StatefulWidget {
  final bool isFloating;
  final EdgeInsetsGeometry? margin;

  const PersistentWorkDock({
    super.key,
    this.isFloating = true,
    this.margin,
  });

  @override
  State<PersistentWorkDock> createState() => _PersistentWorkDockState();
}

class _PersistentWorkDockState extends State<PersistentWorkDock>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  int _selectedTaskIndex = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
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

  @override
  Widget build(BuildContext context) {
    final tasks = _gatherActiveTasks(context);
    if (tasks.isEmpty) return const SizedBox.shrink();

    if (_selectedTaskIndex >= tasks.length) {
      _selectedTaskIndex = 0;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentTask = tasks[_selectedTaskIndex];
    final hasMultiple = tasks.length > 1;

    final effectiveBottom = widget.isFloating
        ? InteractiveSheetWrapper.getEffectiveBottomPadding(context, minPadding: 16)
        : 0.0;

    return Container(
      margin: widget.margin ??
          EdgeInsets.fromLTRB(16, 8, 16, effectiveBottom),
      child: Material(
        elevation: isDark ? 6 : 12,
        shadowColor: currentTask.color.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: currentTask.color.withValues(alpha: isDark ? 0.45 : 0.25),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Si hay múltiples tareas, mostramos barra de pestañas compacta
              if (hasMultiple)
                Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.3)
                        : Colors.grey.shade100,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
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
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? t.color.withValues(alpha: 0.18)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
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
                              const SizedBox(width: 6),
                              Text(
                                t.title,
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

              // Contenido principal de la tarea activa
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Avatar con pulso sutil
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final pulse = 1.0 + (_pulseController.value * 0.08);
                        return Transform.scale(
                          scale: pulse,
                          child: Container(
                            width: 44,
                            height: 44,
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
                              size: 22,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 12),

                    // Título y Subtítulo
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  currentTask.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: currentTask.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            currentTask.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Botón Descartar (opcional)
                    if (currentTask.onDiscard != null)
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        tooltip: 'Descartar',
                        color: isDark ? Colors.grey[500] : Colors.grey[400],
                        onPressed: currentTask.onDiscard,
                      ),

                    // Botón Reanudar
                    ElevatedButton.icon(
                      onPressed: currentTask.onResume,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: currentTask.color,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text(
                        'Reanudar',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
