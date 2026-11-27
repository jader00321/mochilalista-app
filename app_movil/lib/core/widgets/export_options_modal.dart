import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

part 'export_options/export_options_cards_part.dart';
part 'export_options/export_options_combinable_part.dart';
part 'export_options/export_options_legacy_part.dart';

class ExportOption {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool requiresFormatSelection;
  final bool requiresPaymentMethodSelection;
  final int? count;

  const ExportOption({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.requiresFormatSelection = true,
    this.requiresPaymentMethodSelection = false,
    this.count,
  });
}

class ExportFilterSelection {
  final String scope; // 'current', 'period', 'full_history'
  final String
  operationType; // 'all_active', 'smart_quotation', 'pos_rapido', 'prestamo_personal', 'archived'
  final String financialStatus; // 'todos', 'pagados', 'con_deuda'
  final String grouping; // 'continuous', 'grouped_by_method', 'specific_method'
  final String?
  specificPaymentMethod; // 'efectivo', 'yape_plin', 'transferencia', 'credito'
  final String format; // 'pdf', 'csv'

  const ExportFilterSelection({
    required this.scope,
    required this.operationType,
    required this.financialStatus,
    required this.grouping,
    this.specificPaymentMethod,
    required this.format,
  });
}

class ExportOptionsModal extends StatefulWidget {
  final List<ExportOption>? options;
  final Function(String selectedOptionId, String format, String? paymentMethod)?
  onExportLegacy;

  // Soporte para Exportación Modular Combinable
  final bool isCombinable;
  final String? initialTab;
  final String? initialFinancialFilter;
  final String? activePeriodLabel;
  final Future<int> Function(ExportFilterSelection selection)? onCountRequest;
  final Function(ExportFilterSelection selection)? onExportCombinable;

  final bool isDark;

  const ExportOptionsModal({
    super.key,
    this.options,
    this.onExportLegacy,
    this.isCombinable = false,
    this.initialTab,
    this.initialFinancialFilter,
    this.activePeriodLabel,
    this.onCountRequest,
    this.onExportCombinable,
    required this.isDark,
  });

  /// Modal Clásico (retrocompatible para Workbench)
  static void show(
    BuildContext context, {
    required List<ExportOption> options,
    required Function(
      String selectedOptionId,
      String format,
      String? paymentMethod,
    )
    onExport,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    InteractiveSheetWrapper.show(
      context: context,
      builder: (_) => ExportOptionsModal(
        options: options,
        onExportLegacy: onExport,
        isDark: isDark,
      ),
    );
  }

  /// Modal Modular Combinable 360° (para Historial de Ventas)
  static void showCombinable(
    BuildContext context, {
    required String initialTab,
    required String initialFinancialFilter,
    required String activePeriodLabel,
    required Future<int> Function(ExportFilterSelection selection)
    onCountRequest,
    required Function(ExportFilterSelection selection) onExport,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    InteractiveSheetWrapper.show(
      context: context,
      isDismissible: true,
      builder: (_) => ExportOptionsModal(
        isCombinable: true,
        initialTab: initialTab,
        initialFinancialFilter: initialFinancialFilter,
        activePeriodLabel: activePeriodLabel,
        onCountRequest: onCountRequest,
        onExportCombinable: onExport,
        isDark: isDark,
      ),
    );
  }

  @override
  State<ExportOptionsModal> createState() => _ExportOptionsModalState();
}

class _ExportOptionsModalState extends State<ExportOptionsModal> {
  // Estado Legacy
  int _step = 1;
  ExportOption? _selectedOption;
  String _selectedFormat = 'pdf'; // 'pdf' or 'csv'
  String? _selectedPaymentMethod;

  // Estado Modular Combinable
  late String _scope; // 'current', 'period', 'full_history'
  late String
  _operationType; // 'all_active', 'smart_quotation', 'pos_rapido', 'prestamo_personal', 'archived'
  late String _financialStatus; // 'todos', 'pagados', 'con_deuda'
  String _grouping =
      'continuous'; // 'continuous', 'grouped_by_method', 'specific_method'
  String _specificPayment = 'efectivo';
  int? _liveCount;
  bool _isLoadingCount = false;

  @override
  void initState() {
    super.initState();
    if (widget.isCombinable) {
      _scope = 'period';
      if (widget.initialTab == 'pos_rapido') {
        _operationType = 'pos_rapido';
      } else if (widget.initialTab == 'smart_quotation') {
        _operationType = 'smart_quotation';
      } else if (widget.initialTab == 'prestamos' ||
          widget.initialTab == 'prestamo_personal') {
        _operationType = 'prestamo_personal';
      } else if (widget.initialTab == 'archivadas') {
        _operationType = 'archived';
      } else {
        _operationType = 'all_active';
      }

      _financialStatus = widget.initialFinancialFilter ?? 'todos';
      _refreshLiveCount();
    }
  }

  void _updateState(VoidCallback fn) {
    if (mounted) {
      setState(fn);
    }
  }

  ExportFilterSelection _buildSelection() {
    return ExportFilterSelection(
      scope: _scope,
      operationType: _operationType,
      financialStatus: _financialStatus,
      grouping: _grouping,
      specificPaymentMethod: _grouping == 'specific_method'
          ? _specificPayment
          : null,
      format: _selectedFormat,
    );
  }

  Future<void> _refreshLiveCount() async {
    if (widget.onCountRequest == null) {
      return;
    }
    _updateState(() => _isLoadingCount = true);
    try {
      final count = await widget.onCountRequest!(_buildSelection());
      if (mounted) {
        _updateState(() {
          _liveCount = count;
          _isLoadingCount = false;
        });
      }
    } catch (_) {
      if (mounted) {
        _updateState(() => _isLoadingCount = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isCombinable) {
      return InteractiveSheetWrapper(
        maxHeightFactor: 0.90,
        backgroundColor: widget.isDark ? const Color(0xFF1E1E2C) : Colors.white,
        showHandle: true,
        icon: Icons.file_download,
        iconColor: Colors.blue,
        titleWidget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Opciones de Exportación",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: widget.isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              "Personaliza tu reporte financiero",
              style: TextStyle(
                fontSize: 12,
                color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
        bottomAction: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.isDark
                  ? Colors.blue[700]
                  : Colors.blue[800],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 2,
            ),
            onPressed: () {
              Navigator.pop(context);
              widget.onExportCombinable?.call(_buildSelection());
            },
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.file_download_outlined, size: 22),
                  SizedBox(width: 8),
                  Text(
                    "Generar y Descargar Reporte",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          child: _buildCombinableBody(),
        ),
      );
    }

    return InteractiveSheetWrapper(
      maxHeightFactor: 0.90,
      backgroundColor: widget.isDark ? const Color(0xFF1E1E2C) : Colors.white,
      applyEffectiveBottomPadding: true,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _step == 1 ? _buildLegacyStep1() : _buildLegacyFormatSelection(),
      ),
    );
  }
}
