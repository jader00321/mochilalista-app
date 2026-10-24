import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

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
  final String operationType; // 'all_active', 'smart_quotation', 'pos_rapido', 'prestamo_personal', 'archived'
  final String financialStatus; // 'todos', 'pagados', 'con_deuda'
  final String grouping; // 'continuous', 'grouped_by_method', 'specific_method'
  final String? specificPaymentMethod; // 'efectivo', 'yape_plin', 'transferencia', 'credito'
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
  final Function(String selectedOptionId, String format, String? paymentMethod)? onExportLegacy;
  
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
    required Function(String selectedOptionId, String format, String? paymentMethod) onExport,
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
    required Future<int> Function(ExportFilterSelection selection) onCountRequest,
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
  late String _operationType; // 'all_active', 'smart_quotation', 'pos_rapido', 'prestamo_personal', 'archived'
  late String _financialStatus; // 'todos', 'pagados', 'con_deuda'
  String _grouping = 'continuous'; // 'continuous', 'grouped_by_method', 'specific_method'
  String _specificPayment = 'efectivo';
  int? _liveCount;
  bool _isLoadingCount = false;

  @override
  void initState() {
    super.initState();
    if (widget.isCombinable) {
      _scope = 'period';
      // Mapear tab activo
      if (widget.initialTab == 'pos_rapido') {
        _operationType = 'pos_rapido';
      } else if (widget.initialTab == 'smart_quotation') {
        _operationType = 'smart_quotation';
      } else if (widget.initialTab == 'prestamos' || widget.initialTab == 'prestamo_personal') {
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

  ExportFilterSelection _buildSelection() {
    return ExportFilterSelection(
      scope: _scope,
      operationType: _operationType,
      financialStatus: _financialStatus,
      grouping: _grouping,
      specificPaymentMethod: _grouping == 'specific_method' ? _specificPayment : null,
      format: _selectedFormat,
    );
  }

  void _refreshLiveCount() async {
    if (widget.onCountRequest == null) return;
    setState(() => _isLoadingCount = true);
    try {
      final count = await widget.onCountRequest!(_buildSelection());
      if (mounted) {
        setState(() {
          _liveCount = count;
          _isLoadingCount = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCount = false);
    }
  }

  // =========================================================================
  // UI COMBINABLE (Fases 2 y 3)
  // =========================================================================
  Widget _buildCombinableBody() {
    final activePeriodText = widget.activePeriodLabel ?? "Periodo Seleccionado";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // SELECTOR 1: Alcance Temporal
                _buildSectionHeader("1. ALCANCE TEMPORAL", Icons.date_range_outlined),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildChoicePill(
                        label: "Vista Actual",
                        isSelected: _scope == 'current',
                        onTap: () {
                          setState(() => _scope = 'current');
                          _refreshLiveCount();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildChoicePill(
                        label: activePeriodText,
                        isSelected: _scope == 'period',
                        onTap: () {
                          setState(() => _scope = 'period');
                          _refreshLiveCount();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildChoicePill(
                        label: "Histórico Total",
                        isSelected: _scope == 'full_history',
                        onTap: () {
                          setState(() => _scope = 'full_history');
                          _refreshLiveCount();
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // SELECTOR 2: Tipo de Registro y Estado Financiero
                _buildSectionHeader("2. TIPO DE REGISTRO", Icons.category_outlined),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildChoiceChip(
                      label: "Todas las Activas",
                      isSelected: _operationType == 'all_active',
                      onTap: () {
                        setState(() => _operationType = 'all_active');
                        _refreshLiveCount();
                      },
                    ),
                    _buildChoiceChip(
                      label: "Solo Cotizaciones",
                      isSelected: _operationType == 'smart_quotation',
                      onTap: () {
                        setState(() => _operationType = 'smart_quotation');
                        _refreshLiveCount();
                      },
                    ),
                    _buildChoiceChip(
                      label: "Solo Caja Rápida",
                      isSelected: _operationType == 'pos_rapido',
                      onTap: () {
                        setState(() => _operationType = 'pos_rapido');
                        _refreshLiveCount();
                      },
                    ),
                    _buildChoiceChip(
                      label: "Solo Préstamos",
                      isSelected: _operationType == 'prestamo_personal',
                      onTap: () {
                        setState(() => _operationType = 'prestamo_personal');
                        _refreshLiveCount();
                      },
                    ),
                    _buildChoiceChip(
                      label: "Solo Anuladas",
                      isSelected: _operationType == 'archived',
                      onTap: () {
                        setState(() => _operationType = 'archived');
                        _refreshLiveCount();
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                _buildSectionHeader("ESTADO FINANCIERO", Icons.account_balance_wallet_outlined),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildChoicePill(
                        label: "Todos",
                        isSelected: _financialStatus == 'todos',
                        onTap: () {
                          setState(() => _financialStatus = 'todos');
                          _refreshLiveCount();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildChoicePill(
                        label: "Solo Pagados",
                        isSelected: _financialStatus == 'pagados',
                        onTap: () {
                          setState(() => _financialStatus = 'pagados');
                          _refreshLiveCount();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildChoicePill(
                        label: "Con Deuda",
                        isSelected: _financialStatus == 'con_deuda',
                        onTap: () {
                          setState(() => _financialStatus = 'con_deuda');
                          _refreshLiveCount();
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // SELECTOR 3: Organización y Método de Pago
                _buildSectionHeader("3. ORGANIZACIÓN Y PAGO", Icons.account_tree_outlined),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildChoicePill(
                        label: "Continua",
                        isSelected: _grouping == 'continuous',
                        onTap: () {
                          setState(() => _grouping = 'continuous');
                          _refreshLiveCount();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildChoicePill(
                        label: "Agrupada",
                        isSelected: _grouping == 'grouped_by_method',
                        onTap: () {
                          setState(() => _grouping = 'grouped_by_method');
                          _refreshLiveCount();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildChoicePill(
                        label: "Por Método",
                        isSelected: _grouping == 'specific_method',
                        onTap: () {
                          setState(() => _grouping = 'specific_method');
                          _refreshLiveCount();
                        },
                      ),
                    ),
                  ],
                ),

                if (_grouping == 'specific_method') ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildMethodChip("Efectivo", 'efectivo', Icons.money),
                      _buildMethodChip("Yape / Plin", 'yape_plin', Icons.phone_android),
                      _buildMethodChip("Transferencia", 'transferencia', Icons.account_balance),
                      _buildMethodChip("Deuda / Crédito", 'credito', Icons.credit_card),
                    ],
                  ),
                ],

                const SizedBox(height: 20),

                // SELECTOR 4: Formato del Reporte
                _buildSectionHeader("4. FORMATO DE DESCARGA", Icons.print_outlined),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _FormatCard(
                        title: "PDF",
                        subtitle: "Visual y Profesional",
                        icon: Icons.picture_as_pdf,
                        color: Colors.red,
                        isSelected: _selectedFormat == 'pdf',
                        isDark: widget.isDark,
                        onTap: () => setState(() => _selectedFormat = 'pdf'),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _FormatCard(
                        title: "CSV (Excel)",
                        subtitle: "Hoja de Cálculo",
                        icon: Icons.table_chart,
                        color: Colors.green,
                        isSelected: _selectedFormat == 'csv',
                        isDark: widget.isDark,
                        onTap: () => setState(() => _selectedFormat = 'csv'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // 📊 RESUMEN PREVIO EN VIVO
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: widget.isDark ? const Color(0xFF262638) : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: widget.isDark ? 0.3 : 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.analytics_outlined, color: Colors.blue, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Resumen previo de exportación",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: widget.isDark ? Colors.white : Colors.blue.shade900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isLoadingCount
                                  ? "Calculando operaciones coincidentes..."
                                  : "${_liveCount ?? 0} operaciones encontradas para descargar",
                              style: TextStyle(
                                fontSize: 12,
                                color: widget.isDark ? Colors.grey[300] : Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: widget.isDark ? Colors.blue[300] : Colors.blue[700]),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: widget.isDark ? Colors.grey[400] : Colors.grey[700],
          ),
        ),
      ],
    );
  }

  Widget _buildChoicePill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = widget.isDark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.blue.withValues(alpha: 0.25) : Colors.blue.shade100)
              : (isDark ? const Color(0xFF262638) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? (isDark ? Colors.blue[400]! : Colors.blue[700]!)
                : (isDark ? Colors.white10 : Colors.black12),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? (isDark ? Colors.blue[300] : Colors.blue[900])
                : (isDark ? Colors.grey[300] : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = widget.isDark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.blue.withValues(alpha: 0.25) : Colors.blue.shade100)
              : (isDark ? const Color(0xFF262638) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? (isDark ? Colors.blue[400]! : Colors.blue[700]!)
                : (isDark ? Colors.white10 : Colors.black12),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? (isDark ? Colors.blue[300] : Colors.blue[900])
                : (isDark ? Colors.grey[300] : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildMethodChip(String name, String id, IconData icon) {
    final isSelected = _specificPayment == id;
    final isDark = widget.isDark;

    return InkWell(
      onTap: () {
        setState(() => _specificPayment = id);
        _refreshLiveCount();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? Colors.teal.withValues(alpha: 0.25) : Colors.teal.shade100)
              : (isDark ? const Color(0xFF262638) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.teal
                : (isDark ? Colors.white10 : Colors.black12),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: isSelected ? Colors.teal : Colors.grey),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? (isDark ? Colors.teal[300] : Colors.teal[900])
                    : (isDark ? Colors.grey[300] : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // UI LEGACY (retrocompatible para WorkbenchScreen)
  // =========================================================================
  void _handleLegacyOptionSelect(ExportOption option) {
    setState(() {
      _selectedOption = option;
      if (option.requiresPaymentMethodSelection) {
        _step = 2;
      } else if (option.requiresFormatSelection) {
        _step = 2;
      } else {
        _submitLegacy();
      }
    });
  }

  void _submitLegacy() {
    Navigator.pop(context);
    widget.onExportLegacy?.call(_selectedOption!.id, _selectedFormat, _selectedPaymentMethod);
  }

  Widget _buildLegacyStep1() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.download, color: widget.isDark ? Colors.blue[300] : Colors.blue[800], size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "Opciones de Exportación",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
        ),
        const Divider(height: 1),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: widget.options?.length ?? 0,
            separatorBuilder: (ctx, i) => Divider(height: 1, color: widget.isDark ? Colors.white12 : Colors.black12),
            itemBuilder: (ctx, i) {
              final opt = widget.options![i];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                leading: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (widget.isDark ? Colors.blue[900] : Colors.blue[100])?.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(opt.icon, color: widget.isDark ? Colors.blue[300] : Colors.blue[700]),
                ),
                title: Text(opt.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(opt.description, style: TextStyle(fontSize: 13, color: widget.isDark ? Colors.grey[400] : Colors.grey[700])),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (opt.count != null)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: (widget.isDark ? Colors.blue[900] : Colors.blue[100])?.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: (widget.isDark ? Colors.blue[400] : Colors.blue[700])!.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          "${opt.count} ${opt.count == 1 ? 'lista' : 'listas'}",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: widget.isDark ? Colors.blue[300] : Colors.blue[800],
                          ),
                        ),
                      ),
                    Icon(Icons.chevron_right, color: widget.isDark ? Colors.grey[600] : Colors.grey[400]),
                  ],
                ),
                onTap: () => _handleLegacyOptionSelect(opt),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLegacyFormatSelection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _step = 1),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Formato del Reporte", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(_selectedOption!.title, style: TextStyle(fontSize: 13, color: widget.isDark ? Colors.grey[400] : Colors.grey[600])),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: _FormatCard(
                  title: "PDF",
                  subtitle: "Visual y Profesional",
                  icon: Icons.picture_as_pdf,
                  color: Colors.red,
                  isSelected: _selectedFormat == 'pdf',
                  isDark: widget.isDark,
                  onTap: () => setState(() => _selectedFormat = 'pdf'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _FormatCard(
                  title: "CSV",
                  subtitle: "Hoja de Cálculo Excel",
                  icon: Icons.table_chart,
                  color: Colors.green,
                  isSelected: _selectedFormat == 'csv',
                  isDark: widget.isDark,
                  onTap: () => setState(() => _selectedFormat = 'csv'),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.isDark ? Colors.blue[700] : Colors.blue[800],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _submitLegacy,
              child: const Text("Generar y Descargar", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
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
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.isDark ? Colors.blue[700] : Colors.blue[800],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
            ),
            icon: const Icon(Icons.file_download_outlined, size: 22),
            label: const Text(
              "Generar y Descargar Reporte",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              Navigator.pop(context);
              widget.onExportCombinable?.call(_buildSelection());
            },
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

class _FormatCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _FormatCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : (isDark ? Colors.white12 : Colors.black12),
            width: isSelected ? 2 : 1,
          ),
          color: isSelected 
              ? color.withValues(alpha: 0.1) 
              : (isDark ? const Color(0xFF252535) : Colors.grey[50]),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: 10),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 3),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}
