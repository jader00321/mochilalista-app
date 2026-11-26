part of '../smart_action_grid.dart';

mixin _SmartActionGridCardsMixin on _SmartActionGridStateBase {
  @override
  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    bool isDark,
    bool isGuest,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        if (!isGuest) ...[
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                HapticFeedback.mediumImpact();
                setState(() => _isEditing = !_isEditing);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _isEditing
                      ? (_columnsDensity == 3
                            ? Colors.indigoAccent.withValues(alpha: 0.2)
                            : Colors.blue.withValues(alpha: 0.2))
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.grey.withValues(alpha: 0.12)),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isEditing
                        ? Colors.blueAccent
                        : (isDark
                              ? Colors.white.withValues(alpha: 0.15)
                              : Colors.grey.withValues(alpha: 0.3)),
                    width: _isEditing ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          _isEditing
                              ? Icons.check_circle_outline_rounded
                              : Icons.tune_rounded,
                          size: 16,
                          color: _isEditing
                              ? Colors.blueAccent
                              : (isDark ? Colors.grey[300] : Colors.grey[800]),
                        ),
                        // Indicador de punto azul cuando el usuario tiene diseño personalizado
                        if (_isCustomized && !_isEditing)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Colors.blueAccent,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.blueAccent,
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _isEditing ? "Listo" : "Personalizar",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: _isEditing
                            ? Colors.blueAccent
                            : (isDark ? Colors.grey[300] : Colors.grey[800]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget _buildHeroCard(
    BuildContext context,
    _ActionCardDef def, {
    required bool isDark,
    required double screenWidth,
  }) {
    final color = def.colorBuilder(isDark);
    final badge = def.badgeBuilder(context, isDark);

    return Material(
      color: isDark ? const Color(0xFF23232F) : Colors.white,
      elevation: isDark ? 0 : 8,
      shadowColor: isDark ? Colors.transparent : color.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: color.withValues(alpha: isDark ? 0.35 : 0.45),
          width: 1.8,
        ),
      ),
      child: InkWell(
        onTap: def.onTapBuilder(context, isDark),
        onLongPress: !_isEditing && def.onLongPressBuilder != null
            ? def.onLongPressBuilder!(context, isDark)
            : null,
        borderRadius: BorderRadius.circular(24),
        splashColor: color.withValues(alpha: 0.15),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: isDark ? 0.18 : 0.12),
                Colors.transparent,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? color.withValues(alpha: 0.25)
                      : color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: color.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Icon(def.icon, color: color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.amber.withValues(alpha: 0.4),
                            ),
                          ),
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  color: Colors.amber,
                                  size: 12,
                                ),
                                SizedBox(width: 2),
                                Text(
                                  "ACCESO RÁPIDO",
                                  style: TextStyle(
                                    color: Colors.amber,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (badge != null) badge,
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      def.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        color: isDark ? Colors.white : Colors.black87,
                        letterSpacing: -0.4,
                      ),
                    ),
                    Text(
                      def.subtitle,
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: color.withValues(alpha: 0.7),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget _buildNormalCard(
    BuildContext context,
    _ActionCardDef def,
    int index,
    bool isDark,
    double screenWidth,
    int cols,
  ) {
    final color = def.colorBuilder(isDark);
    final badge = def.badgeBuilder(context, isDark);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final double delay = (index * 0.06).clamp(0.0, 0.6);
        final double effectiveValue = ((value - delay) / (1 - delay)).clamp(
          0.0,
          1.0,
        );
        return Transform.translate(
          offset: Offset(0, 20 * (1 - effectiveValue)),
          child: Opacity(opacity: effectiveValue, child: child),
        );
      },
      child: Material(
        color: isDark ? const Color(0xFF23232F) : Colors.white,
        elevation: isDark ? 0 : 7,
        shadowColor: isDark
            ? Colors.transparent
            : color.withValues(alpha: 0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: isDark
              ? BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1.5,
                )
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: def.onTapBuilder(context, isDark),
          onLongPress: def.onLongPressBuilder != null
              ? def.onLongPressBuilder!(context, isDark)
              : null,
          borderRadius: BorderRadius.circular(22),
          splashColor: color.withValues(alpha: 0.15),
          highlightColor: color.withValues(alpha: 0.05),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: isDark
                  ? LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.06),
                        Colors.transparent,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: cols == 3 ? 8 : (screenWidth > 400 ? 16 : 12),
              vertical: cols == 3 ? 6 : (screenWidth > 400 ? 12 : 10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: EdgeInsets.all(
                        cols == 3 ? 6 : (screenWidth > 400 ? 11 : 8),
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? color.withValues(alpha: 0.2)
                            : color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        def.icon,
                        color: color,
                        size: cols == 3 ? 18 : (screenWidth > 400 ? 26 : 22),
                      ),
                    ),
                    if (badge != null) Flexible(child: badge),
                  ],
                ),
                SizedBox(height: cols == 3 ? 6 : 10),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    def.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: cols == 3
                          ? 12.5
                          : (screenWidth > 400 ? 16 : 14),
                      color: isDark ? Colors.white : Colors.black87,
                      height: 1.1,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  def.subtitle,
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontSize: cols == 3 ? 9.5 : (screenWidth > 400 ? 12 : 11),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
