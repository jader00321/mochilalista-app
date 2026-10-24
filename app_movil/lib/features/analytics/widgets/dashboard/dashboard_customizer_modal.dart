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
  String _selectedPreset = 'Completo';

  @override
  void initState() {
    super.initState();
    _sections = widget.initialSections.map((s) => s.copyWith()).toList();
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _sections.removeAt(oldIndex);
      _sections.insert(newIndex, item);
      _selectedPreset = 'Personalizado';
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
      applyEffectiveBottomPadding: true,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            
            // Header
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
                    icon: const Icon(Icons.restart_alt, size: 20),
                    tooltip: "Restablecer orden predeterminado",
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

            // Presets Bar
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
                  ],
                ),
              ),
            ),

            // Helper instruction banner
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.blue.withValues(alpha: 0.1) : Colors.blue[50],
                borderRadius: BorderRadius.circular(10),
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
                ],
              ),
            ),

            // Reorderable list
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
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
                        ],
                      ),
                      title: Text(
                        section.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: section.isVisible 
                              ? (widget.isDark ? Colors.white : Colors.black87)
                              : Colors.grey,
                        ),
                      ),
                      subtitle: Text(
                        section.subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: section.isPermanent
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
                                  _selectedPreset = 'Personalizado';
                                });
                              },
                            ),
                    ),
                  );
                },
              ),
            ),

            // Bottom action buttons
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: bgColor,
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: Row(
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
            ),
          ],
        ),
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
