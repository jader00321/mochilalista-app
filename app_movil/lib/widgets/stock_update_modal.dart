import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../providers/inventory_provider.dart';

class StockUpdateModal extends StatefulWidget {
  final ProductPresentation presentation;
  final InventoryProvider provider;
  final bool isDark;
  
  const StockUpdateModal({
    super.key, 
    required this.presentation, 
    required this.provider, 
    required this.isDark
  });

  @override
  State<StockUpdateModal> createState() => _StockUpdateModalState();
}

class _StockUpdateModalState extends State<StockUpdateModal> {
  late int currentStock;
  late TextEditingController ctrl;

  @override
  void initState() {
    super.initState();
    currentStock = widget.presentation.stockActual;
    ctrl = TextEditingController(text: currentStock.toString());
  }

  void _update(int val) {
    setState(() {
      currentStock = val < 0 ? 0 : val;
      ctrl.text = currentStock.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: widget.isDark ? const Color(0xFF23232F) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Center(child: Text("Ajustar Stock", style: TextStyle(fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black87))),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(onPressed: () => _update(currentStock - 1), icon: const Icon(Icons.remove)),
              Container(
                width: 100,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: widget.isDark ? const Color(0xFF14141C) : Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                child: TextField(
                  controller: ctrl,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black87),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(border: InputBorder.none),
                  onChanged: (v) => currentStock = int.tryParse(v) ?? 0,
                ),
              ),
              IconButton.filledTonal(onPressed: () => _update(currentStock + 1), icon: const Icon(Icons.add)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            currentStock == 0 ? "¡Producto Agotado!" : (currentStock <= 5 ? "¡Advertencia: Stock Bajo!" : "Stock Saludable"),
            style: TextStyle(
              color: currentStock == 0 ? (widget.isDark ? Colors.red[300] : Colors.red) : (currentStock <= 5 ? (widget.isDark ? Colors.orange[300] : Colors.orange) : (widget.isDark ? Colors.green[400] : Colors.green)),
              fontWeight: FontWeight.bold,
              fontSize: 15
            ),
          )
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text("Cancelar", style: TextStyle(color: widget.isDark ? Colors.grey[400] : Colors.grey, fontSize: 16))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: widget.isDark ? Colors.blue[300] : Theme.of(context).primaryColor, foregroundColor: widget.isDark ? Colors.black87 : Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: () async {
            await widget.provider.updatePresentation(widget.presentation.id!, stock: currentStock);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text("Actualizar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        )
      ],
    );
  }
}
