import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/crm_models.dart';

class SmartUpdateModal extends StatelessWidget {
  final ValidationResult validation;
  final VoidCallback onUpdatePrices;
  final VoidCallback onFixStock;
  final VoidCallback onFixAll;
  
  final Function(int itemId, int newQty)? onFixSingleStock;
  final Function(int itemId)? onRemoveSingleItem;
  final Function(int itemId, double newPrice, double newBase)? onAcceptSinglePrice;

  const SmartUpdateModal({
    super.key,
    required this.validation,
    required this.onUpdatePrices,
    required this.onFixStock,
    required this.onFixAll,
    this.onFixSingleStock,
    this.onRemoveSingleItem,
    this.onAcceptSinglePrice,
  });

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final stockIssues = validation.stockWarnings;
    final priceIssues = validation.priceChanges;
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    bool hasNoRealIssues = stockIssues.isEmpty && priceIssues.isEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 20),
            
            if (hasNoRealIssues) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: isDark ? Colors.green.withOpacity(0.15) : Colors.green[100], shape: BoxShape.circle),
                    child: Icon(Icons.check_circle, color: isDark ? Colors.green[300] : Colors.green[700], size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Text("Todo en orden", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor))),
                ],
              ),
              const SizedBox(height: 12),
              Text("Hemos revisado el inventario y todos los productos de esta cotización están disponibles y con los precios correctos.", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700], fontSize: 15)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.green[700] : Colors.green[700], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: const Text("CONTINUAR", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5)),
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: isDark ? Colors.orange.withOpacity(0.15) : Colors.orange[100], shape: BoxShape.circle),
                    child: Icon(Icons.build_circle, color: isDark ? Colors.orange[300] : Colors.orange[900], size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Text("Centro de Resoluciones", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor))),
                ],
              ),
              const SizedBox(height: 12),
              Text("El inventario ha cambiado desde que se creó esta cotización. Revisa y aplica los cambios si lo deseas.", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700], fontSize: 15)),
              const SizedBox(height: 24),
          
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // 1. BLOQUE DE STOCK (Agotados)
                      if (stockIssues.isNotEmpty) ...[
                        _buildSectionHeader("Problemas de Stock", Icons.remove_shopping_cart, isDark ? Colors.red[300]! : Colors.red[800]!),
                        Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(color: isDark ? Colors.red.withOpacity(0.1) : Colors.red[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.red.withOpacity(0.3) : Colors.red.shade200)),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.warning_amber, color: isDark ? Colors.red[300] : Colors.red[800], size: 24),
                              const SizedBox(width: 12),
                              Expanded(child: Text("Hay productos agotados o que superan el stock. Para poder vender esta lista, debes eliminarlos o corregir su cantidad.", style: TextStyle(fontSize: 14, color: isDark ? Colors.red[100] : Colors.red[900]))),
                            ],
                          ),
                        ),
                        ...stockIssues.map((s) => _buildStockRow(s, isDark, context)),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity, height: 50,
                          child: OutlinedButton.icon(
                            onPressed: () { Navigator.pop(context); onFixStock(); },
                            icon: const Icon(Icons.delete_sweep, size: 20),
                            label: const Text("Eliminar Productos Agotados", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            style: OutlinedButton.styleFrom(foregroundColor: isDark ? Colors.red[300] : Colors.red[800], side: BorderSide(color: isDark ? Colors.red.withOpacity(0.5) : Colors.red[300]!), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          ),
                        ),
                        Divider(height: 40, thickness: 1.5, color: isDark ? Colors.white10 : Colors.grey[200]),
                      ],

                      // 2. BLOQUE DE PRECIOS (Advertencia No Bloqueante)
                      if (priceIssues.isNotEmpty) ...[
                        _buildSectionHeader("Advertencia de Precios", Icons.monetization_on, isDark ? Colors.orange[300]! : Colors.orange[800]!),
                        Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(color: isDark ? Colors.orange.withOpacity(0.1) : Colors.orange[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.orange.withOpacity(0.3) : Colors.orange.shade200)),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline, color: isDark ? Colors.orange[300] : Colors.orange[800], size: 24),
                              const SizedBox(width: 12),
                              Expanded(child: Text("El precio en tienda ha cambiado. Tu precio cotizado SE MANTENDRÁ a menos que decidas aceptar el nuevo precio.", style: TextStyle(fontSize: 14, color: isDark ? Colors.orange[100] : Colors.orange[900]))),
                            ],
                          ),
                        ),
                        ...priceIssues.map((p) => _buildPriceRow(p, currency, isDark, context)),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity, height: 50,
                          child: OutlinedButton.icon(
                            onPressed: () { Navigator.pop(context); onUpdatePrices(); },
                            icon: const Icon(Icons.refresh, size: 20),
                            label: const Text("Actualizar Todo a Precios de Hoy", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            style: OutlinedButton.styleFrom(foregroundColor: isDark ? Colors.orange[300] : Colors.orange[800], side: BorderSide(color: isDark ? Colors.orange.withOpacity(0.5) : Colors.orange[300]!), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          ),
                        ),
                        Divider(height: 40, thickness: 1.5, color: isDark ? Colors.white10 : Colors.grey[200]),
                      ],
                    ],
                  ),
                ),
              ),
          
              const SizedBox(height: 10),
          
              // BOTÓN GLOBAL (ACCIÓN RÁPIDA)
              SizedBox(
                width: double.infinity, height: 60,
                child: ElevatedButton.icon(
                  onPressed: () { Navigator.pop(context); onFixAll(); },
                  icon: const Icon(Icons.auto_awesome, size: 24),
                  label: const Text("CORREGIR Y ACTUALIZAR TODO", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.green[700] : Colors.green[700], foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: isDark ? 0 : 4,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancelar y revisar manualmente", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(width: 10),
          Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 18)),
        ],
      ),
    );
  }

  // 🔥 TARJETA DE PRECIO MEJORADA (Mantiene diseño original)
  Widget _buildPriceRow(PriceChange p, NumberFormat currency, bool isDark, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF14141C) : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: isDark ? Colors.white10 : Colors.orange.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.productName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis),
          if (p.message.isNotEmpty)
             Padding(padding: const EdgeInsets.only(top: 8, bottom: 12), child: Text(p.message, style: TextStyle(fontSize: 13, color: isDark ? Colors.orange[200] : Colors.orange[800], fontStyle: FontStyle.italic))),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Cotizado Originalmente:", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey, fontSize: 12)),
                    Text(currency.format(p.oldPrice), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.grey[300] : Colors.black87)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("Actual en Tienda:", style: TextStyle(color: isDark ? Colors.orange[300] : Colors.orange[800], fontSize: 12, fontWeight: FontWeight.bold)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(p.newPrice > p.oldPrice ? Icons.arrow_upward : Icons.arrow_downward, size: 16, color: isDark ? Colors.orange[300] : Colors.orange),
                        const SizedBox(width: 4),
                        Text(currency.format(p.newPrice), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isDark ? Colors.orange[300] : Colors.orange[900])),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (onAcceptSinglePrice != null) onAcceptSinglePrice!(p.itemId, p.newPrice, p.newBasePrice);
              },
              style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.orange[800] : Colors.orange, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              child: const Text("Aceptar Precio de Tienda", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          )
        ],
      ),
    );
  }

  // 🔥 TARJETA DE STOCK MEJORADA
  Widget _buildStockRow(StockWarning s, bool isDark, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF14141C) : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: isDark ? Colors.white10 : Colors.red.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.productName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87), maxLines: 2, overflow: TextOverflow.ellipsis),
          if (s.message.isNotEmpty)
             Padding(padding: const EdgeInsets.only(top: 8, bottom: 12), child: Text(s.message, style: TextStyle(fontSize: 13, color: isDark ? Colors.red[300] : Colors.red[800], fontStyle: FontStyle.italic))),
          
          Row(
            children: [
              if (s.available > 0)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      if (onFixSingleStock != null) onFixSingleStock!(s.itemId, s.available);
                    },
                    icon: const Icon(Icons.check, size: 16),
                    label: Text("Ajustar a ${s.available}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), backgroundColor: isDark ? Colors.green[700] : Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                ),
              if (s.available > 0) const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    if (onRemoveSingleItem != null) onRemoveSingleItem!(s.itemId);
                  },
                  icon: const Icon(Icons.delete, size: 16),
                  label: const Text("Descartar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12), foregroundColor: isDark ? Colors.red[300] : Colors.red, side: BorderSide(color: isDark ? Colors.red[300]! : Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                ),
              )
            ],
          )
        ],
      ),
    );
  }
}