import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';
import 'package:app_movil/features/analytics/models/dashboard_section_config.dart';

class DashboardCustomizerModal extends StatefulWidget {
  final int negocioId;
  final bool isDark;
  final List<DashboardSectionConfig> initialSections;
  final void Function(List<DashboardSectionConfig>) onSaved;

  const DashboardCustomizerModal({
    super.key,
    required this.negocioId,
    required this.isDark,
    required this.initialSections,
    required this.onSaved,
  });

  static Future<void> show({
    required BuildContext context,
    required int negocioId,
    required bool isDark,
    required List<DashboardSectionConfig> currentSections,
    required void Function(List<DashboardSectionConfig>) onSaved,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DashboardCustomizerModal(
        negocioId: negocioId,
        isDark: isDark,
        initialSections: currentSections,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<DashboardCustomizerModal> createState() => _DashboardCustomizerModalState();
}

class _DashboardCustomizerModalState extends State<DashboardCustomizerModal> {
  late List<DashboardSectionConfig> _sections;
  late String _selectedPreset;
  bool _showHelpBanner = true;

  @override
  void initState() {
    super.initState();
    _sections = widget.initialSections.map((s) => s.copyWith()).toList();
    _selectedPreset = DashboardSectionConfig.detectPreset(_sections);
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _sections.removeAt(oldIndex);
      _sections.insert(newIndex, item);
      _selectedPreset = DashboardSectionConfig.detectPreset(_sections);
    });
  }

  void _applyPreset(String preset) {
    setState(() {
      _selectedPreset = preset;
      _sections = DashboardSectionConfig.applyPreset(_sections, preset);
    });
  }

  void _resetToDefault() {
    setState(() {
      _selectedPreset = 'Completo';
      _sections = DashboardSectionConfig.getDefaultSections();
    });
  }

  void _enableAllSections() {
    setState(() {
      _selectedPreset = 'Completo';
      _sections = _sections.map((s) => s.copyWith(isVisible: true)).toList();
    });
  }

  Future<void> _saveAndClose() async {
    await DashboardSectionConfig.saveSections(widget.negocioId, _sections);
    widget.onSaved(_sections);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBg = widget.isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = widget.isDark ? Colors.white12 : Colors.grey[200]!;

    return InteractiveSheetWrapper(
      backgroundColor: bgColor,
      maxHeightFactor: 0.90,
      applyEffectiveBottomPadding: false,
      showHandle: true,
      bottomAction: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.check, size: 18),
              label: const Text(
                "Guardar Cambios", 
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: _saveAndClose,
            ),
          ),
        ],
      ),
      child: Column(
          children: [
            // Header (1 sola manija nativa provista por InteractiveSheetWrapper)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.dashboard_customize, color: Colors.blueAccent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Personalizar Dashboard",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "Reordena o activa solo lo que necesitas",
                          style: TextStyle(
                            fontSize: 12, 
                            color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _showHelpBanner ? Icons.info : Icons.info_outline,
                      size: 20,
                      color: _showHelpBanner ? Colors.blueAccent : (widget.isDark ? Colors.white60 : Colors.black54),
                    ),
                    tooltip: _showHelpBanner ? "Ocultar ayuda" : "Mostrar ayuda",
                    onPressed: () => setState(() => _showHelpBanner = !_showHelpBanner),
                  ),
                  IconButton(
                    icon: const Icon(Icons.restart_alt, size: 20),
                    tooltip: "Restablecer a valores de fábrica",
                    onPressed: _resetToDefault,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            const Divider(height: 1),

            // Presets Bar (1 sola línea horizontal deslizable fluida)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildPresetChip("✨ Completo", 'Completo'),
                    const SizedBox(width: 8),
                    _buildPresetChip("💼 Financiero", 'Financiero'),
                    const SizedBox(width: 8),
                    _buildPresetChip("📦 Operativo / Stock", 'Operativo / Stock'),
                    const SizedBox(width: 8),
                    _buildPresetChip("📰 Comercial & Radar", 'Comercial & Radar'),
                    if (_selectedPreset == 'Personalizado') ...[
                      const SizedBox(width: 8),
                      _buildPresetChip("🎨 Personalizado", 'Personalizado'),
                    ],
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _enableAllSections,
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 14),
                      label: const Text("Activar Todo", style: TextStyle(fontSize: 11.5)),
                    ),
                  ],
                ),
              ),
            ),

            // Helper instruction banner (Colapsable fluidamente con AnimatedSize)
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOutCubic,
              child: _showHelpBanner
                  ? Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: widget.isDark ? Colors.blue.withValues(alpha: 0.1) : Colors.blue[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: widget.isDark ? Colors.blue.withValues(alpha: 0.25) : Colors.blue[200]!,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 16, color: Colors.blueAccent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Mantén presionada una tarjeta para arrastrarla. Tu configuración se guarda automáticamente por negocio.",
                              style: TextStyle(
                                fontSize: 11, 
                                color: widget.isDark ? Colors.blue[200] : Colors.blue[900],
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _showHelpBanner = false),
                            child: Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Icon(
                                Icons.close, 
                                size: 16, 
                                color: widget.isDark ? Colors.blue[300] : Colors.blue[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            // Reorderable list con tarjetas sin textos recortados (Mandatory Technical Rule #3)
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, InteractiveSheetWrapper.kModalScrollBottomClearance),
                physics: const BouncingScrollPhysics(),
                itemCount: _sections.length,
                onReorder: _onReorder,
                itemBuilder: (context, index) {
                  final section = _sections[index];
                  return Container(
                    key: ValueKey(section.id),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: section.isVisible ? borderColor : borderColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.drag_indicator, 
                            color: widget.isDark ? Colors.grey[600] : Colors.grey[400], 
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (section.isVisible ? Colors.blueAccent : Colors.grey).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              section.icon, 
                              color: section.isVisible ? Colors.blueAccent : Colors.grey, 
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  section.title,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.bold,
                                    color: section.isVisible 
                                        ? (widget.isDark ? Colors.white : Colors.black87)
                                        : Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  section.subtitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.25,
                                    color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                  softWrap: true,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          section.isPermanent
                              ? Tooltip(
                                  message: "Esta tarjeta es obligatoria para el cálculo central",
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blueAccent.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      "Fijo",
                                      style: TextStyle(
                                        fontSize: 11, 
                                        fontWeight: FontWeight.bold, 
                                        color: Colors.blueAccent,
                                      ),
                                    ),
                                  ),
                                )
                              : Switch.adaptive(
                                  value: section.isVisible,
                                  activeTrackColor: Colors.blueAccent,
                                  onChanged: (val) {
                                    setState(() {
                                      section.isVisible = val;
                                      _selectedPreset = DashboardSectionConfig.detectPreset(_sections);
                                    });
                                  },
                                ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
    );
  }

  Widget _buildPresetChip(String label, String presetKey) {
    final bool isSelected = _selectedPreset == presetKey;
    return GestureDetector(
      onTap: () => _applyPreset(presetKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? Colors.blueAccent 
              : (widget.isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[200]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected 
                ? Colors.white 
                : (widget.isDark ? Colors.grey[300] : Colors.grey[800]),
          ),
        ),
      ),
    );
  }
}
