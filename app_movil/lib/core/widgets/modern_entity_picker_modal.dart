import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

/// Modelo genérico para elementos dentro del selector moderno
class PickerItem<T> {
  final int? id;
  final String name;
  final T? rawValue;
  final bool isDeferred;
  final bool isSpecial; // "Ninguno" o "Usar Principal"

  const PickerItem({
    required this.id,
    required this.name,
    this.rawValue,
    this.isDeferred = false,
    this.isSpecial = false,
  });
}

/// 🌟 Modal interactivo con buscador instantáneo, chips y creación diferida en memoria
class ModernEntityPickerModal<T> extends StatefulWidget {
  final String title;
  final String searchHint;
  final List<PickerItem<T>> items;
  final int? selectedId;
  final String createButtonLabel;
  final String createDialogTitle;
  final String createDialogHint;
  final bool allowCreation;
  final bool isDark;

  const ModernEntityPickerModal({
    super.key,
    required this.title,
    required this.searchHint,
    required this.items,
    this.selectedId,
    this.createButtonLabel = "+ Crear Nuevo...",
    this.createDialogTitle = "Nuevo Registro",
    this.createDialogHint = "Ingresa el nombre...",
    this.allowCreation = true,
    required this.isDark,
  });

  static Future<PickerItem<T>?> show<T>({
    required BuildContext context,
    required String title,
    required String searchHint,
    required List<PickerItem<T>> items,
    int? selectedId,
    String createButtonLabel = "+ Crear Nuevo...",
    String createDialogTitle = "Nuevo Registro",
    String createDialogHint = "Ingresa el nombre...",
    bool allowCreation = true,
  }) {
    FocusManager.instance.primaryFocus?.unfocus();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    HapticFeedback.lightImpact();

    return InteractiveSheetWrapper.show<PickerItem<T>>(
      context: context,
      builder: (ctx) => ModernEntityPickerModal<T>(
        title: title,
        searchHint: searchHint,
        items: items,
        selectedId: selectedId,
        createButtonLabel: createButtonLabel,
        createDialogTitle: createDialogTitle,
        createDialogHint: createDialogHint,
        allowCreation: allowCreation,
        isDark: isDark,
      ),
    );
  }

  @override
  State<ModernEntityPickerModal<T>> createState() =>
      _ModernEntityPickerModalState<T>();
}

class _ModernEntityPickerModalState<T>
    extends State<ModernEntityPickerModal<T>> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _filterQuery = "";
  int? _currentSelectedId;

  @override
  void initState() {
    super.initState();
    _currentSelectedId = widget.selectedId;
    _searchCtrl.addListener(() {
      final q = _searchCtrl.text.trim().toLowerCase();
      if (q != _filterQuery) {
        setState(() => _filterQuery = q);
      }
    });
  }

  void _onItemTapped(PickerItem<T> item) {
    if (_currentSelectedId != item.id) {
      setState(() {
        _currentSelectedId = item.id;
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<PickerItem<T>> get _filteredItems {
    if (_filterQuery.isEmpty) {
      return widget.items.where((it) => !it.isSpecial).toList();
    }
    return widget.items.where((it) {
      return it.name.toLowerCase().contains(_filterQuery);
    }).toList();
  }

  Future<void> _handleCreateNew() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final TextEditingController nameCtrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:
            widget.isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          widget.createDialogTitle,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: widget.isDark ? Colors.white : Colors.black87,
            fontSize: 17,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: TextStyle(
                color: widget.isDark ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: widget.createDialogHint,
                hintStyle: TextStyle(
                  color: widget.isDark ? Colors.white38 : Colors.black38,
                ),
                filled: true,
                fillColor: widget.isDark
                    ? const Color(0xFF1A1A24)
                    : Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 13,
                  color: widget.isDark ? Colors.amber[300] : Colors.amber[800],
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "Se guardará en memoria hasta guardar el producto.",
                    style: TextStyle(
                      fontSize: 11,
                      color: widget.isDark
                          ? Colors.amber[200]
                          : Colors.amber[900],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              final text = nameCtrl.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(ctx, text);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text("Agregar"),
          ),
        ],
      ),
    );
    FocusManager.instance.primaryFocus?.unfocus();

    if (result != null && result.isNotEmpty && mounted) {
      // Generar ID temporal negativo único basado en microsegundos
      final tempId = -1 * (DateTime.now().microsecondsSinceEpoch % 1000000);
      final newItem = PickerItem<T>(
        id: tempId,
        name: result,
        isDeferred: true,
      );
      Navigator.pop(context, newItem);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems;
    final specialItems = widget.items.where((it) => it.isSpecial).toList();

    return InteractiveSheetWrapper(
      maxHeightFactor: 0.85,
      backgroundColor: widget.isDark ? const Color(0xFF1E1E2A) : Colors.white,
      contentPadding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabecera del modal
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: widget.isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (widget.allowCreation)
                  TextButton.icon(
                    onPressed: _handleCreateNew,
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(
                      "Nuevo",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: widget.isDark
                          ? const Color(0xFF64B5F6)
                          : const Color(0xFF1976D2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ),

          // Buscador instantáneo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: widget.isDark
                    ? const Color(0xFF14141C)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.isDark
                      ? Colors.white12
                      : Colors.grey.shade300,
                ),
              ),
              child: TextField(
                controller: _searchCtrl,
                style: TextStyle(
                  fontSize: 14,
                  color: widget.isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 16),
                          onPressed: () => _searchCtrl.clear(),
                          color: widget.isDark
                              ? Colors.grey[400]
                              : Colors.grey[600],
                        )
                      : null,
                  hintText: widget.searchHint,
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: widget.isDark ? Colors.grey[500] : Colors.grey[500],
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Elementos especiales ("Ninguno" o "Usar Principal") si no hay filtro activo
          if (_filterQuery.isEmpty && specialItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  ...specialItems.map((item) => _PickerItemTile<T>(
                        item: item,
                        isSelected: item.id == _currentSelectedId,
                        isDark: widget.isDark,
                        onTapConfirmed: _onItemTapped,
                        onSelect: (selectedItem) {
                          FocusManager.instance.primaryFocus?.unfocus();
                          Navigator.pop(context, selectedItem);
                        },
                      )),
                  Divider(
                    height: 12,
                    color: widget.isDark ? Colors.white10 : Colors.grey.shade200,
                  ),
                ],
              ),
            ),

          // Lista de resultados con scroll elástico
          Flexible(
            child: filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 40,
                          color: widget.isDark
                              ? Colors.grey[600]
                              : Colors.grey[400],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "No se encontraron resultados",
                          style: TextStyle(
                            fontSize: 13,
                            color: widget.isDark
                                ? Colors.grey[400]
                                : Colors.grey[600],
                          ),
                        ),
                        if (widget.allowCreation && _filterQuery.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () {
                              FocusManager.instance.primaryFocus?.unfocus();
                              final text = _searchCtrl.text.trim();
                              Navigator.pop(
                                context,
                                PickerItem<T>(
                                  id: -1 *
                                      (DateTime.now().microsecondsSinceEpoch %
                                          1000000),
                                  name: text,
                                  isDeferred: true,
                                ),
                              );
                            },
                            icon: const Icon(Icons.add_rounded, size: 16),
                            label: Text('Crear "$_filterQuery" en memoria'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2E7D32),
                              side: const BorderSide(
                                color: Color(0xFF2E7D32),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) => _PickerItemTile<T>(
                      item: filtered[i],
                      isSelected: filtered[i].id == _currentSelectedId,
                      isDark: widget.isDark,
                      onTapConfirmed: _onItemTapped,
                      onSelect: (selectedItem) {
                        FocusManager.instance.primaryFocus?.unfocus();
                        Navigator.pop(context, selectedItem);
                      },
                    ),
                  ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// 👆 Tile táctil con micro-animaciones de preselección, cancelación por arrastre
/// y confirmación al soltar limpiamente.
class _PickerItemTile<T> extends StatefulWidget {
  final PickerItem<T> item;
  final bool isSelected;
  final bool isDark;
  final ValueChanged<PickerItem<T>> onTapConfirmed;
  final ValueChanged<PickerItem<T>> onSelect;

  const _PickerItemTile({
    super.key,
    required this.item,
    required this.isSelected,
    required this.isDark,
    required this.onTapConfirmed,
    required this.onSelect,
  });

  @override
  State<_PickerItemTile<T>> createState() => _PickerItemTileState<T>();
}

class _PickerItemTileState<T> extends State<_PickerItemTile<T>> {
  bool _isPressed = false;
  bool _isConfirming = false;
  Offset? _downPos;
  bool _isCancelledByDrag = false;

  void _handleTapDown(TapDownDetails details) {
    if (_isConfirming || _isCancelledByDrag) return;
    setState(() => _isPressed = true);
    HapticFeedback.selectionClick();
  }

  void _handleTapCancel() {
    if (_isConfirming) return;
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  void _handleTapUp(TapUpDetails details) async {
    if (_isConfirming || _isCancelledByDrag) return;
    setState(() {
      _isPressed = false;
      _isConfirming = true;
    });
    HapticFeedback.mediumImpact();
    widget.onTapConfirmed(widget.item);
    await Future.delayed(const Duration(milliseconds: 140));
    if (mounted) {
      widget.onSelect(widget.item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveSelected = widget.isSelected;
    final scale = _isPressed ? 0.96 : (_isConfirming && effectiveSelected ? 1.02 : 1.0);

    final bgColor = effectiveSelected
        ? (widget.isDark
            ? Colors.green.withValues(alpha: 0.18)
            : Colors.green.shade50)
        : (_isPressed
            ? (widget.isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.grey.shade200)
            : Colors.transparent);

    final borderColor = effectiveSelected
        ? (widget.isDark
            ? Colors.green.withValues(alpha: 0.5)
            : Colors.green.shade300)
        : (_isPressed
            ? (widget.isDark
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.grey.shade400)
            : Colors.transparent);

    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          _downPos = event.localPosition;
          _isCancelledByDrag = false;
        },
        onPointerMove: (event) {
          if (_downPos != null && !_isCancelledByDrag) {
            final distance = (event.localPosition - _downPos!).distance;
            if (distance > 8.0) {
              _isCancelledByDrag = true;
              if (_isPressed) {
                setState(() => _isPressed = false);
              }
            }
          }
        },
        onPointerUp: (event) {
          _downPos = null;
        },
        onPointerCancel: (event) {
          _downPos = null;
          _isCancelledByDrag = true;
          if (_isPressed) {
            setState(() => _isPressed = false);
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _handleTapDown,
          onTapCancel: _handleTapCancel,
          onTapUp: _handleTapUp,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            margin: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: borderColor,
                width: effectiveSelected ? 1.4 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.item.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: effectiveSelected
                                ? FontWeight.bold
                                : FontWeight.w500,
                            color: effectiveSelected
                                ? (widget.isDark
                                    ? Colors.green[300]
                                    : const Color(0xFF1B5E20))
                                : (widget.isDark
                                    ? Colors.white
                                    : Colors.black87),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.item.isDeferred) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: widget.isDark
                                ? Colors.amber.withValues(alpha: 0.2)
                                : Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: widget.isDark
                                  ? Colors.amber.withValues(alpha: 0.4)
                                  : Colors.amber.shade300,
                            ),
                          ),
                          child: Text(
                            "Nuevo · Pendiente",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: widget.isDark
                                  ? Colors.amber[300]
                                  : Colors.amber[900],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (effectiveSelected)
                  AnimatedScale(
                    scale: _isConfirming ? 1.15 : 1.0,
                    duration: const Duration(milliseconds: 120),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 19,
                      color: widget.isDark
                          ? Colors.green[300]
                          : const Color(0xFF2E7D32),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
