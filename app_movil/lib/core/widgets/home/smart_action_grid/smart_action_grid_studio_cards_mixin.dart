part of '../smart_action_grid.dart';

mixin _SmartActionGridStudioCardsMixin on _SmartActionGridStateBase {
  @override
  Widget _buildHomeStudioToolbar(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2230) : const Color(0xFFF0F5FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.blueAccent,
                size: 18,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  "Home Studio: Personaliza tus accesos",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
              TextButton.icon(
                onPressed: _resetToFactory,
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 14,
                  color: Colors.grey,
                ),
                label: const Text(
                  "Fábrica",
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "Mantén presionado para arrastrar y ordenar. Toca [★] para fijar en portada o [x] para ocultar.",
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                "Densidad:",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey[300] : Colors.grey[800],
                ),
              ),
              _buildDensityOption(title: "2 Columnas", cols: 2, isDark: isDark),
              _buildDensityOption(title: "3 Columnas", cols: 3, isDark: isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDensityOption({
    required String title,
    required int cols,
    required bool isDark,
  }) {
    final isSelected = _columnsDensity == cols;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _columnsDensity = cols);
        _saveCustomizations();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blueAccent
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.blueAccent
                : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.grey[300] : Colors.black87),
          ),
        ),
      ),
    );
  }

  @override
  Widget _buildDraggableEditCard(
    BuildContext context,
    _ActionCardDef def,
    bool isDark,
    double screenWidth,
    int cols,
  ) {
    final color = def.colorBuilder(isDark);
    final isHero = _heroCardId == def.id;

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != def.id,
      onAcceptWithDetails: (details) {
        _reorderCards(details.data, def.id);
      },
      builder: (context, candidateData, rejectedData) {
        final isTargeted = candidateData.isNotEmpty;

        return LongPressDraggable<String>(
          data: def.id,
          feedback: Material(
            color: Colors.transparent,
            elevation: 10,
            child: SizedBox(
              width: cols == 3 ? 110 : 150,
              height: cols == 3 ? 100 : 130,
              child: Opacity(
                opacity: 0.9,
                child: _buildCardFrame(
                  context,
                  def,
                  isDark,
                  color,
                  isHero,
                  isTargeted,
                  cols,
                  isDragging: true,
                ),
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.25,
            child: _buildCardFrame(
              context,
              def,
              isDark,
              color,
              isHero,
              isTargeted,
              cols,
            ),
          ),
          child: _buildCardFrame(
            context,
            def,
            isDark,
            color,
            isHero,
            isTargeted,
            cols,
          ),
        );
      },
    );
  }

  Widget _buildCardFrame(
    BuildContext context,
    _ActionCardDef def,
    bool isDark,
    Color color,
    bool isHero,
    bool isTargeted,
    int cols, {
    bool isDragging = false,
  }) {
    return AnimatedBuilder(
      animation: _editPulseController,
      builder: (context, child) {
        final pulseAlpha = 0.2 + (_editPulseController.value * 0.25);
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF20222F) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isTargeted
                  ? Colors.blueAccent
                  : (isHero
                        ? Colors.amber
                        : Colors.blueAccent.withValues(
                            alpha: isDragging ? 0.8 : pulseAlpha,
                          )),
              width: (isTargeted || isHero) ? 2.2 : 1.5,
            ),
            boxShadow: [
              if (isHero)
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(
                    Icons.drag_indicator_rounded,
                    color: isDark ? Colors.grey[500] : Colors.grey[400],
                    size: 18,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => _toggleHeroCard(def.id),
                        child: Icon(
                          isHero
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: isHero
                              ? Colors.amber
                              : (isDark ? Colors.grey[400] : Colors.grey[500]),
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => _toggleHideCard(def.id),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.redAccent,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      def.icon,
                      color: color,
                      size: cols == 3 ? 18 : 22,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        def.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: cols == 3 ? 12 : 14,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                isHero ? "En Portada" : def.subtitle,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isHero
                      ? Colors.amber
                      : (isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
}
