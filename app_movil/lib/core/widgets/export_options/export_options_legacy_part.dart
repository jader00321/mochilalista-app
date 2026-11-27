part of '../export_options_modal.dart';

extension _ExportOptionsLegacyExt on _ExportOptionsModalState {
  void _handleLegacyOptionSelect(ExportOption option) {
    _updateState(() {
      _selectedOption = option;
      if (option.requiresPaymentMethodSelection ||
          option.requiresFormatSelection) {
        _step = 2;
      } else {
        _submitLegacy();
      }
    });
  }

  void _submitLegacy() {
    Navigator.pop(context);
    widget.onExportLegacy?.call(
      _selectedOption!.id,
      _selectedFormat,
      _selectedPaymentMethod,
    );
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
              Icon(
                Icons.download,
                color: widget.isDark ? Colors.blue[300] : Colors.blue[800],
                size: 28,
              ),
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
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: widget.options?.length ?? 0,
            separatorBuilder: (ctx, i) => Divider(
              height: 1,
              color: widget.isDark ? Colors.white12 : Colors.black12,
            ),
            itemBuilder: (ctx, i) {
              final opt = widget.options![i];
              return InkWell(
                onTap: () => _handleLegacyOptionSelect(opt),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color:
                              (widget.isDark
                                      ? Colors.blue[900]
                                      : Colors.blue[100])
                                  ?.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          opt.icon,
                          size: 20,
                          color: widget.isDark
                              ? Colors.blue[300]
                              : Colors.blue[700],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  opt.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                if (opt.count != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          (widget.isDark
                                                  ? Colors.blue[900]
                                                  : Colors.blue[100])
                                              ?.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color:
                                            (widget.isDark
                                                    ? Colors.blue[400]
                                                    : Colors.blue[700])!
                                                .withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Text(
                                      "${opt.count} ${opt.count == 1 ? 'lista' : 'listas'}",
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: widget.isDark
                                            ? Colors.blue[300]
                                            : Colors.blue[800],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              opt.description,
                              style: TextStyle(
                                fontSize: 13,
                                color: widget.isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right,
                        color: widget.isDark
                            ? Colors.grey[600]
                            : Colors.grey[400],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLegacyFormatSelection() {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => _updateState(() => _step = 1),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Formato del Reporte",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _selectedOption!.title,
                        style: TextStyle(
                          fontSize: 13,
                          color: widget.isDark
                              ? Colors.grey[400]
                              : Colors.grey[600],
                        ),
                      ),
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
                    onTap: () => _updateState(() => _selectedFormat = 'pdf'),
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
                    onTap: () => _updateState(() => _selectedFormat = 'csv'),
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
                  backgroundColor: widget.isDark
                      ? Colors.blue[700]
                      : Colors.blue[800],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _submitLegacy,
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "Generar y Descargar",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
