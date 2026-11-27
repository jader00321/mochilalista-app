part of '../persistent_work_dock.dart';

extension _PersistentWorkDockBubbleAndBarPart on _PersistentWorkDockState {
  Widget _buildEdgePeekTab({
    required bool isDark,
    required WorkTask currentTask,
    required double screenWidth,
    required double minBottom,
    required double maxBottom,
  }) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      bottom: _bubbleBottom.clamp(minBottom, maxBottom),
      left: _isLeftEdge ? 0 : null,
      right: !_isLeftEdge ? 0 : null,
      width: 28,
      height: 64,
      child: RepaintBoundary(
        child: GestureDetector(
          onTap: _untuckFromTap,
          onHorizontalDragUpdate: (details) {
            final pullingInward = _isLeftEdge
                ? details.delta.dx > 1
                : details.delta.dx < -1;
            if (pullingInward) {
              _untuckFromDrag(screenWidth);
            }
          },
          child: Container(
            width: 28,
            height: 64,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
              borderRadius: _isLeftEdge
                  ? const BorderRadius.horizontal(right: Radius.circular(18))
                  : const BorderRadius.horizontal(left: Radius.circular(18)),
              border: Border.all(color: currentTask.color, width: 2.2),
              boxShadow: [
                BoxShadow(
                  color: currentTask.color.withValues(alpha: 0.45),
                  blurRadius: 14,
                  spreadRadius: 1,
                  offset: Offset(_isLeftEdge ? 2 : -2, 2),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                _isLeftEdge
                    ? Icons.chevron_right_rounded
                    : Icons.chevron_left_rounded,
                color: currentTask.color,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingBubble({
    required bool isDark,
    required List<WorkTask> tasks,
    required WorkTask currentTask,
    required double screenWidth,
    required double minBottom,
    required double maxBottom,
  }) {
    final double? leftPos;
    final double? rightPos;

    if (_bubblePanX != null) {
      leftPos = _bubblePanX!.clamp(0.0, screenWidth - 58.0);
      rightPos = null;
    } else if (_isLeftEdge) {
      leftPos = 16.0;
      rightPos = null;
    } else {
      leftPos = null;
      rightPos = 16.0;
    }

    return AnimatedPositioned(
      duration: _bubblePanX != null
          ? Duration.zero
          : const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      bottom: _bubbleBottom.clamp(minBottom, maxBottom),
      left: leftPos,
      right: rightPos,
      width: 58,
      height: 58,
      child: RepaintBoundary(
        child: GestureDetector(
          onTap: _expandFromBubble,
          onPanUpdate: (details) => _updateBubblePan(
            details,
            screenWidth: screenWidth,
            minBottom: minBottom,
            maxBottom: maxBottom,
          ),
          onPanEnd: (details) => _snapBubbleToEdge(details, screenWidth),
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final pulse = 1.0 + (_pulseController.value * 0.08);
              return Transform.scale(
                scale: pulse,
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: currentTask.color, width: 2.2),
                    boxShadow: [
                      BoxShadow(
                        color: currentTask.color.withValues(alpha: 0.4),
                        blurRadius: 16,
                        spreadRadius: 1,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        currentTask.icon,
                        color: currentTask.color,
                        size: 26,
                      ),
                      if (tasks.length > 1)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              "${tasks.length}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedDockBar({
    required BuildContext context,
    required bool isDark,
    required List<WorkTask> tasks,
    required WorkTask currentTask,
  }) {
    final hasMultiple = tasks.length > 1;
    final effectiveBottom = widget.isFloating
        ? InteractiveSheetWrapper.getEffectiveBottomPadding(
            context,
            minPadding: 16,
          )
        : 0.0;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: RepaintBoundary(
        child: GestureDetector(
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0.0;
            if (velocity < -250) {
              _minimizeToBubble(isLeft: true);
            } else if (velocity > 250) {
              _minimizeToBubble(isLeft: false);
            }
          },
          child: Container(
            margin:
                widget.margin ??
                EdgeInsets.fromLTRB(16, 8, 16, effectiveBottom),
            child: Material(
              elevation: isDark ? 6 : 14,
              shadowColor: currentTask.color.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(22),
              color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: currentTask.color.withValues(
                      alpha: isDark ? 0.45 : 0.3,
                    ),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasMultiple) _buildTaskTabsStrip(tasks, isDark),
                    _buildMainTaskRow(currentTask, isDark),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskTabsStrip(List<WorkTask> tasks, bool isDark) {
    return GestureDetector(
      onHorizontalDragStart: (_) {},
      onHorizontalDragUpdate: (_) {},
      onHorizontalDragEnd: (_) {},
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.black.withValues(alpha: 0.3)
              : Colors.grey.shade100,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(21)),
        ),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: tasks.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (ctx, i) {
            final t = tasks[i];
            final isSelected = i == _selectedTaskIndex;
            return InkWell(
              onTap: () => _selectTaskIndex(i),
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? t.color.withValues(alpha: 0.18)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? t.color.withValues(alpha: 0.6)
                        : Colors.transparent,
                  ),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        t.icon,
                        size: 14,
                        color: isSelected ? t.color : Colors.grey,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        t.shortTitle,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isSelected
                              ? t.color
                              : (isDark ? Colors.grey[400] : Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMainTaskRow(WorkTask currentTask, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final pulse = 1.0 + (_pulseController.value * 0.08);
              return Transform.scale(
                scale: pulse,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: currentTask.color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: currentTask.color.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    currentTask.icon,
                    color: currentTask.color,
                    size: 20,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    currentTask.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  currentTask.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          if (currentTask.onDiscard != null) ...[
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18),
              tooltip: 'Descartar',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                minimumSize: const Size(28, 28),
                padding: EdgeInsets.zero,
              ),
              color: isDark ? Colors.grey[400] : Colors.grey[500],
              onPressed: currentTask.onDiscard,
            ),
            const SizedBox(width: 2),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 102),
            child: ElevatedButton(
              onPressed: currentTask.onResume,
              style: ElevatedButton.styleFrom(
                backgroundColor: currentTask.color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 1.5,
              ),
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow_rounded, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Reanudar',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 2),
          IconButton(
            icon: Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 28),
            style: IconButton.styleFrom(
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              minimumSize: const Size(24, 28),
              padding: EdgeInsets.zero,
            ),
            tooltip: 'Minimizar a globo',
            onPressed: () => _minimizeToBubble(isLeft: false),
          ),
        ],
      ),
    );
  }
}
