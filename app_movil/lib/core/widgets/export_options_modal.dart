import 'package:flutter/material.dart';

class ExportOption {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool requiresFormatSelection;
  final bool requiresPaymentMethodSelection;

  const ExportOption({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.requiresFormatSelection = true,
    this.requiresPaymentMethodSelection = false,
  });
}

class ExportOptionsModal extends StatefulWidget {
  final List<ExportOption> options;
  final Function(String selectedOptionId, String format, String? paymentMethod) onExport;
  final bool isDark;

  const ExportOptionsModal({
    super.key,
    required this.options,
    required this.onExport,
    required this.isDark,
  });

  static void show(BuildContext context, {
    required List<ExportOption> options,
    required Function(String selectedOptionId, String format, String? paymentMethod) onExport,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExportOptionsModal(
        options: options, 
        onExport: onExport,
        isDark: isDark,
      ),
    );
  }

  @override
  State<ExportOptionsModal> createState() => _ExportOptionsModalState();
}

class _ExportOptionsModalState extends State<ExportOptionsModal> {
  int _step = 1; // 1: Select Option, 2: Select Format or Sub-Option
  ExportOption? _selectedOption;
  String _selectedFormat = 'pdf'; // 'pdf' or 'csv'
  String? _selectedPaymentMethod;

  void _handleOptionSelect(ExportOption option) {
    setState(() {
      _selectedOption = option;
      if (option.requiresPaymentMethodSelection) {
        _step = 2; // Move to payment method selection
      } else if (option.requiresFormatSelection) {
        _step = 2; // Move to format selection
      } else {
        _submit();
      }
    });
  }
  
  void _submit() {
    Navigator.pop(context);
    widget.onExport(_selectedOption!.id, _selectedFormat, _selectedPaymentMethod);
  }

  Widget _buildStep1() {
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
            itemCount: widget.options.length,
            separatorBuilder: (ctx, i) => Divider(height: 1, color: widget.isDark ? Colors.white12 : Colors.black12),
            itemBuilder: (ctx, i) {
              final opt = widget.options[i];
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
                trailing: Icon(Icons.chevron_right, color: widget.isDark ? Colors.grey[600] : Colors.grey[400]),
                onTap: () => _handleOptionSelect(opt),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodSelection() {
    final methods = [
      {'id': 'efectivo', 'name': 'Efectivo', 'icon': Icons.money},
      {'id': 'transferencia', 'name': 'Transferencia', 'icon': Icons.account_balance},
      {'id': 'billetera_digital', 'name': 'Billetera Digital', 'icon': Icons.phone_android},
      {'id': 'credito', 'name': 'Deuda / Crédito', 'icon': Icons.credit_card},
    ];

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
              const Expanded(
                child: Text(
                  "Seleccionar Método",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: methods.length,
            itemBuilder: (ctx, i) {
              final m = methods[i];
              return RadioListTile<String>(
                value: m['id'] as String,
                // ignore: deprecated_member_use
                groupValue: _selectedPaymentMethod,
                // ignore: deprecated_member_use
                onChanged: (val) {
                  setState(() => _selectedPaymentMethod = val);
                },
                title: Row(
                  children: [
                    Icon(m['icon'] as IconData, size: 20, color: widget.isDark ? Colors.grey[400] : Colors.grey[600]),
                    const SizedBox(width: 12),
                    Text(m['name'] as String, style: const TextStyle(fontWeight: FontWeight.w500)),
                  ],
                ),
                activeColor: Colors.blue,
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.isDark ? Colors.blue[700] : Colors.blue[800],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _selectedPaymentMethod == null ? null : () {
                if (_selectedOption!.requiresFormatSelection) {
                  setState(() {
                    _step = 3; // format selection
                  });
                } else {
                  _submit();
                }
              },
              child: const Text("Continuar", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormatSelection() {
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
                onPressed: () => setState(() {
                  _step = _selectedOption!.requiresPaymentMethodSelection ? 2 : 1;
                }),
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
              onPressed: _submit,
              child: const Text("Generar y Descargar", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1E1E2C) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _step == 1 
            ? _buildStep1() 
            : (_step == 2 && _selectedOption!.requiresPaymentMethodSelection) 
              ? _buildPaymentMethodSelection()
              : _buildFormatSelection(),
        ),
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
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
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
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 4),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}
