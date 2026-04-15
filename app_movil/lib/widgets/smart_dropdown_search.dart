import 'package:flutter/material.dart';

class SmartDropdownSearch<T> extends StatelessWidget {
  final String label;
  final T? selectedValue;
  final List<T> items;
  final String Function(T) itemAsString;
  final Function(T?) onChanged;
  final Function(String) onAddNew;
  final bool isLoading;
  final String? hintText; 

  const SmartDropdownSearch({
    super.key,
    required this.label,
    required this.items,
    required this.itemAsString,
    required this.onChanged,
    required this.onAddNew,
    this.selectedValue,
    this.isLoading = false,
    this.hintText, 
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String displayText = "Seleccionar...";
    Color textColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    FontWeight fontWeight = FontWeight.normal;

    if (selectedValue != null) {
      displayText = itemAsString(selectedValue as T);
      textColor = isDark ? Colors.white : Colors.black87;
      fontWeight = FontWeight.bold;
    } else if (hintText != null && hintText!.isNotEmpty) {
      displayText = hintText!;
      textColor = isDark ? Colors.blue.shade300 : Colors.blue.shade800; 
      fontWeight = FontWeight.bold;
    }

    return InkWell(
      onTap: () => _showSearchModal(context, isDark),
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[700]),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          suffixIcon: Icon(Icons.arrow_drop_down, color: isDark ? Colors.white54 : Colors.grey[700]),
          filled: true,
          fillColor: isDark ? const Color(0xFF1A1A24) : Colors.white,
        ),
        child: Text(
          displayText,
          style: TextStyle(
            color: textColor,
            fontSize: 15,
            fontWeight: fontWeight,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  void _showSearchModal(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SearchModal<T>(
        items: items,
        itemAsString: itemAsString,
        isDark: isDark,
        onSelected: (val) {
          onChanged(val);
          Navigator.pop(context);
        },
        onAddNew: (text) {
          onAddNew(text);
          Navigator.pop(context);
        },
        label: label,
      ),
    );
  }
}

class _SearchModal<T> extends StatefulWidget {
  final List<T> items;
  final String Function(T) itemAsString;
  final Function(T) onSelected;
  final Function(String) onAddNew;
  final String label;
  final bool isDark;

  const _SearchModal({
    required this.items, 
    required this.itemAsString, 
    required this.onSelected, 
    required this.onAddNew, 
    required this.label,
    required this.isDark,
  });

  @override
  State<_SearchModal<T>> createState() => _SearchModalState<T>();
}

class _SearchModalState<T> extends State<_SearchModal<T>> {
  String _query = "";

  @override
  Widget build(BuildContext context) {
    final filtered = widget.items.where((i) => 
      widget.itemAsString(i).toLowerCase().contains(_query.toLowerCase())
    ).toList();
    
    final textColor = widget.isDark ? Colors.white : Colors.black87;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: (MediaQuery.of(context).size.height * 0.6) + bottomInset,
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF23232F) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24))
      ),
      child: Column(
        children: [
          Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: widget.isDark ? Colors.white24 : Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 20),
          Text("Seleccionar ${widget.label}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: textColor)),
          const SizedBox(height: 20),
          TextField(
            autofocus: true,
            style: TextStyle(color: textColor, fontSize: 16),
            decoration: InputDecoration(
              hintText: "Buscar o escribir nuevo...",
              hintStyle: TextStyle(color: widget.isDark ? Colors.grey[500] : Colors.grey),
              prefixIcon: Icon(Icons.search, color: widget.isDark ? Colors.blue[300] : Colors.blue),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              filled: true, 
              fillColor: widget.isDark ? const Color(0xFF14141C) : Colors.grey[100]
            ),
            onChanged: (val) => setState(() => _query = val),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length + 1,
              separatorBuilder: (_, __) => Divider(height: 1, color: widget.isDark ? Colors.white10 : Colors.grey[200]),
              itemBuilder: (ctx, i) {
                if (i == filtered.length) {
                  if (_query.isNotEmpty && !filtered.any((x) => widget.itemAsString(x).toLowerCase() == _query.toLowerCase())) {
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: widget.isDark ? Colors.blue.withOpacity(0.2) : Colors.blue[50], shape: BoxShape.circle), child: Icon(Icons.add_circle, color: widget.isDark ? Colors.blue[300] : Colors.blue)),
                      title: Text("Crear nuevo: '$_query'", style: TextStyle(color: widget.isDark ? Colors.blue[300] : Colors.blue[800], fontWeight: FontWeight.bold, fontSize: 16)),
                      onTap: () => widget.onAddNew(_query),
                    );
                  }
                  return const SizedBox.shrink();
                }
                
                final item = filtered[i];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  title: Text(widget.itemAsString(item), style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                  onTap: () => widget.onSelected(item),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}