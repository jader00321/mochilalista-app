part of '../extraction_result_screen.dart';

class _MetaInput extends StatelessWidget {
  final IconData icon;
  final String hint;
  final TextEditingController ctrl;
  final Function(String) onChanged;
  final bool isDark;
  final TextInputType? keyboardType;

  const _MetaInput({
    required this.icon,
    required this.hint,
    required this.ctrl,
    required this.onChanged,
    required this.isDark,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isDark ? Colors.blue[300] : Colors.blue[800],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: ctrl,
            keyboardType: keyboardType,
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white : Colors.blue[900],
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 6),
              hintStyle: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[600] : Colors.grey[400],
                fontStyle: FontStyle.italic,
              ),
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _InternalItemCard extends StatefulWidget {
  final ExtractedItem item;
  final int index;
  final bool isDark;
  final VoidCallback onDeletePressed;

  const _InternalItemCard({
    super.key,
    required this.item,
    required this.index,
    required this.isDark,
    required this.onDeletePressed,
  });

  @override
  State<_InternalItemCard> createState() => _InternalItemCardState();
}

class _InternalItemCardState extends State<_InternalItemCard>
    with SingleTickerProviderStateMixin {
  late TextEditingController _nameCtrl;
  late TextEditingController _qtyCtrl;
  late TextEditingController _unitCtrl;
  late TextEditingController _brandCtrl;
  late TextEditingController _notesCtrl;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _initControllers();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));

    Future.delayed(Duration(milliseconds: widget.index * 50), () {
      if (mounted) {
        _animCtrl.forward();
      }
    });
  }

  void _initControllers() {
    _nameCtrl = TextEditingController(text: widget.item.fullName);
    _qtyCtrl = TextEditingController(text: widget.item.quantity.toString());
    _unitCtrl = TextEditingController(text: widget.item.unit ?? "");
    _brandCtrl = TextEditingController(text: widget.item.brand ?? "");
    _notesCtrl = TextEditingController(text: widget.item.notes ?? "");
  }

  @override
  void didUpdateWidget(covariant _InternalItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.id != oldWidget.item.id) {
      _nameCtrl.text = widget.item.fullName;
      _qtyCtrl.text = widget.item.quantity.toString();
      _unitCtrl.text = widget.item.unit ?? "";
      _brandCtrl.text = widget.item.brand ?? "";
      _notesCtrl.text = widget.item.notes ?? "";
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _unitCtrl.dispose();
    _brandCtrl.dispose();
    _notesCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _saveToProvider() {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        Provider.of<SmartQuotationProvider>(context, listen: false).updateItem(
          widget.item.id,
          fullName: _nameCtrl.text,
          quantity: int.tryParse(_qtyCtrl.text) ?? 1,
          unit: _unitCtrl.text,
          brand: _brandCtrl.text,
          notes: _notesCtrl.text,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = widget.isDark ? const Color(0xFF23232F) : Colors.white;

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isDark ? Colors.white10 : Colors.grey.shade300,
            ),
            boxShadow: [
              if (!widget.isDark)
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      flex: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: widget.isDark
                              ? Colors.blue.withValues(alpha: 0.15)
                              : Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "Fila #${widget.index + 1}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: widget.isDark
                                ? Colors.blue[300]
                                : Colors.blue[900],
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    if (widget.item.originalText.isNotEmpty &&
                        widget.item.originalText != "Agregado manual")
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            "IA leyó: \"${widget.item.originalText}\"",
                            style: TextStyle(
                              fontSize: 13,
                              color: widget.isDark
                                  ? Colors.grey[500]
                                  : Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: widget.isDark ? Colors.red[300] : Colors.red,
                        size: 28,
                      ),
                      onPressed: widget.onDeletePressed,
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                      tooltip: "Eliminar fila",
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _nameCtrl,
                  label: "Producto / Descripción extraída",
                  icon: Icons.edit_note,
                  isBold: true,
                  isDark: widget.isDark,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildTextField(
                        controller: _qtyCtrl,
                        label: "Cant.",
                        isNumber: true,
                        isDark: widget.isDark,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: _buildTextField(
                        controller: _unitCtrl,
                        label: "Unidad",
                        isDark: widget.isDark,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 5,
                      child: _buildTextField(
                        controller: _brandCtrl,
                        label: "Marca",
                        isDark: widget.isDark,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _notesCtrl,
                  label: "Detalles adicionales (Colores, tamaños...)",
                  icon: Icons.info_outline,
                  isSoft: true,
                  isDark: widget.isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    bool isNumber = false,
    bool isBold = false,
    bool isSoft = false,
    required bool isDark,
    EdgeInsetsGeometry? contentPadding,
  }) {
    return TextFormField(
      controller: controller,
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
      onChanged: (_) => _saveToProvider(),
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: TextStyle(
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        fontSize: 16,
        color: isDark ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 14,
          color: isDark ? Colors.grey[500] : Colors.grey[700],
        ),
        isDense: true,
        filled: true,
        fillColor: isDark
            ? (isSoft
                  ? Colors.orange.withValues(alpha: 0.05)
                  : const Color(0xFF14141C))
            : (isSoft ? Colors.orange[50] : Colors.white),
        prefixIcon: icon != null
            ? Icon(
                icon,
                size: 20,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: isDark
                ? Colors.blue.withValues(alpha: 0.5)
                : Colors.blue.withValues(alpha: 0.3),
          ),
        ),
        contentPadding:
            contentPadding ??
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class _PulsingDragHandle extends StatefulWidget {
  final bool isDark;
  final bool dragging;

  const _PulsingDragHandle({required this.isDark, required this.dragging});

  @override
  State<_PulsingDragHandle> createState() => _PulsingDragHandleState();
}

class _PulsingDragHandleState extends State<_PulsingDragHandle>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseCtrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: widget.isDark ? const Color(0xFF1A1A24) : Colors.grey[100],
      alignment: Alignment.center,
      child: AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (context, child) {
          final scale = widget.dragging
              ? 1.05
              : 1.0 + (_pulseCtrl.value * 0.03);
          return Transform.scale(
            scale: scale,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
              decoration: BoxDecoration(
                color: widget.dragging
                    ? (widget.isDark
                          ? Colors.blue.withValues(alpha: 0.3)
                          : Colors.blue[100])
                    : (widget.isDark ? const Color(0xFF23232F) : Colors.white),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.dragging
                      ? Colors.transparent
                      : (widget.isDark ? Colors.white10 : Colors.grey.shade300),
                ),
                boxShadow: [
                  if (!widget.dragging && !widget.isDark)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.drag_handle,
                    size: 22,
                    color: widget.dragging
                        ? Colors.blue
                        : (widget.isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "ARRASTRAR",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: widget.dragging
                          ? Colors.blue
                          : (widget.isDark
                                ? Colors.grey[400]
                                : Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
