part of '../filter_drawer.dart';

extension _FilterDrawerControlsPart on _FilterDrawerState {
  Widget _buildBottomApplyBar({
    required ThemeData theme,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required double effectiveBottom,
    required int displayCount,
  }) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, effectiveBottom),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(top: BorderSide(color: borderColor)),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black45 : Colors.black12,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? Colors.blue[700] : theme.primaryColor,
            foregroundColor: Colors.white,
            elevation: isDark ? 0 : 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: _apply,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_rounded, size: 20),
                const SizedBox(width: 8),
                Text(
                  displayCount > 0
                      ? "Mostrar $displayCount ${displayCount == 1 ? 'Producto' : 'Productos'}"
                      : "Aplicar Filtros",
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardSection({
    required String title,
    required IconData icon,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    Widget? trailing,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: 16,
                      color: isDark ? Colors.blue[300] : Colors.blue[800],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildAccordionCard({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required int selectedCount,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required VoidCallback onToggle,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          icon,
                          size: 16,
                          color: isDark ? Colors.blue[300] : Colors.blue[800],
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        if (selectedCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$selectedCount',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: isDark ? Colors.white60 : Colors.grey[600],
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: child,
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState: isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    Color activeColor = Colors.blue,
    IconData? icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: isDark ? 0.25 : 0.12)
              : (isDark ? Colors.white10 : Colors.grey[100]),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isDark ? Colors.white12 : Colors.grey.shade300),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? activeColor
                    : (isDark ? Colors.grey[400] : Colors.grey[700]),
              ),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? (isDark ? Colors.white : activeColor)
                      : (isDark ? Colors.grey[300] : Colors.grey[800]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceChip(
    String label,
    bool selected,
    VoidCallback onSelected, {
    Color color = Colors.grey,
    required bool isDark,
  }) {
    final Color activeColor = color == Colors.grey
        ? (isDark ? Colors.grey[300]! : Colors.black87)
        : color;

    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? activeColor.withValues(alpha: isDark ? 0.25 : 0.12)
              : (isDark ? Colors.white10 : Colors.grey[100]),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? activeColor
                : (isDark ? Colors.white12 : Colors.grey.shade300),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected
                ? (isDark ? Colors.white : activeColor)
                : (isDark ? Colors.grey[300] : Colors.grey[800]),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniNumericInput({
    required String label,
    required String prefix,
    required TextEditingController controller,
    required bool isDark,
    required Function(String) onSubmitted,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onSubmitted: onSubmitted,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 11,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
        prefixText: prefix,
        prefixStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.blue[300] : Colors.blue[800],
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade300,
          ),
        ),
      ),
    );
  }
}
