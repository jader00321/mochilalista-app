part of '../notification_settings_modal.dart';

extension _NotificationSettingsControlsPart on _NotificationSettingsModalState {
  Widget _buildJumpPill(
    String title,
    IconData icon,
    VoidCallback onTap,
    bool isDark,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF23232F) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isDark ? Colors.blue[300] : Colors.blue[700],
            ),
            const SizedBox(width: 5),
            Text(
              title,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.grey[200] : Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.1,
          color: isDark ? Colors.grey[400] : Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildContainer(List<Widget> children, Color bgColor, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildCardDivider(bool isDark, {double indent = 60}) {
    return Divider(
      height: 1,
      indent: indent,
      color: isDark ? Colors.white10 : Colors.grey[200],
    );
  }

  Widget _buildInboxAccessTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required int count,
    required Color subtitleColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: iconBg,
        child: Icon(icon, color: iconColor),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: subtitleColor),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              "$count",
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
      onTap: onTap,
    );
  }

  Widget _buildPremiumSwitchCard({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: isDark ? Colors.white : Colors.black87,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Transform.scale(
              scale: 0.88,
              child: Switch.adaptive(
                value: value,
                onChanged: onChanged,
                activeThumbColor: Colors.blue[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionChip({
    required String label,
    required bool selected,
    required MaterialColor palette,
    required bool isDark,
    required VoidCallback onSelected,
    double fontSize = 12.5,
  }) {
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: fontSize)),
      selected: selected,
      onSelected: (v) {
        if (v) {
          onSelected();
        }
      },
      selectedColor: palette.withValues(alpha: isDark ? 0.3 : 0.15),
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        color: selected
            ? (isDark ? palette[200] : palette[800])
            : (isDark ? Colors.grey[400] : Colors.grey[700]),
      ),
    );
  }

  Widget _buildGraceChip(int days, String label, bool isDark) {
    return _buildOptionChip(
      label: label,
      selected: _localPrefs.diasGraciaStockBajo == days,
      palette: Colors.teal,
      isDark: isDark,
      fontSize: 12,
      onSelected: () =>
          _updatePreference(_localPrefs.copyWith(diasGraciaStockBajo: days)),
    );
  }

  Widget _buildAnticipationChip(int days, String label, bool isDark) {
    return _buildOptionChip(
      label: label,
      selected: _localPrefs.diasAnticipacionCuotas == days,
      palette: Colors.blue,
      isDark: isDark,
      onSelected: () =>
          _updatePreference(_localPrefs.copyWith(diasAnticipacionCuotas: days)),
    );
  }

  Widget _buildPriorityChip(String id, String label, bool isDark) {
    return _buildOptionChip(
      label: label,
      selected: _localPrefs.prioridadMinima == id,
      palette: Colors.blue,
      isDark: isDark,
      onSelected: () =>
          _updatePreference(_localPrefs.copyWith(prioridadMinima: id)),
    );
  }

  Widget _buildSwipeModeBtn({
    required String id,
    required String label,
    required IconData icon,
    required bool isDark,
  }) {
    final isSel = _localPrefs.comportamientoSwipe == id;
    final color = isSel
        ? Colors.blue
        : (isDark ? Colors.grey[600]! : Colors.grey[400]!);

    return InkWell(
      onTap: () =>
          _updatePreference(_localPrefs.copyWith(comportamientoSwipe: id)),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSel
              ? Colors.blue.withValues(alpha: isDark ? 0.25 : 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: isSel ? 0.8 : 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: isSel ? Colors.blue[400] : color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                  color: isSel
                      ? (isDark ? Colors.white : Colors.blue[900])
                      : color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
