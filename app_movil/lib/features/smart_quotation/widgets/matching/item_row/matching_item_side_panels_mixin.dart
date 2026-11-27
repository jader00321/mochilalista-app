part of '../matching_item_row.dart';

mixin _MatchingItemSidePanelsMixin on _MatchingItemRowBase {
  Widget _buildUnlinkedState(bool isDark) {
    return GestureDetector(
      key: const ValueKey('unlinked'),
      onTap: widget.onChangeRequest,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF14141C) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.red.withValues(alpha: 0.5)
                : Colors.red.shade300,
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.touch_app_outlined,
              color: isDark ? Colors.red[300] : Colors.red.shade400,
              size: 36,
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                "Tocar para vincular",
                style: TextStyle(
                  color: isDark ? Colors.red[300] : Colors.red.shade600,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceInfo(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.orange.withValues(alpha: 0.1)
            : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.transparent : Colors.orange.shade100,
        ),
      ),
      child: Column(
        crossAxisAlignment: _isExpanded
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.orange.withValues(alpha: 0.2)
                  : Colors.orange.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                "#${widget.index + 1}",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.orange[300] : Colors.orange.shade900,
                ),
              ),
            ),
          ),
          if (!_isExpanded) ...[
            const SizedBox(height: 6),
            Text(
              widget.pair.sourceItem.fullName,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
                height: 1.2,
              ),
              softWrap: true,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                "${widget.pair.sourceItem.quantity} ${widget.pair.sourceItem.unit ?? ''}",
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.orange[200] : Colors.brown.shade400,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeleteButton(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(
            Icons.delete_outline,
            size: 24,
            color: isDark ? Colors.red[400] : Colors.red,
          ),
          onPressed: widget.onDelete,
          padding: EdgeInsets.zero,
          tooltip: "Eliminar fila",
        ),
        const SizedBox(height: 8),
        Icon(
          Icons.arrow_forward,
          size: 16,
          color: isDark ? Colors.grey[600] : Colors.grey,
        ),
      ],
    );
  }
}
