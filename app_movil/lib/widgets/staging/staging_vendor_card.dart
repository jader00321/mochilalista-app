import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/scanner_provider.dart';
import '../../../providers/inventory_provider.dart';
import '../../../models/scanner_models.dart';

class StagingVendorCard extends StatelessWidget {
  final ScannerProvider provider;
  final StagingResponse staging;
  final bool isDark;

  const StagingVendorCard({
    super.key,
    required this.provider,
    required this.staging,
    required this.isDark,
  });

  void _showProviderSearchModal(BuildContext context) {
    final invProv = Provider.of<InventoryProvider>(context, listen: false);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LocalProviderSearch(
        providers: invProv.providers, 
        isDark: isDark,
        onSelect: (prov) {
          provider.updateStagingProvider(
            nombre: prov.nombreEmpresa, 
            idExistente: prov.id,
            ruc: prov.ruc 
          );
          Navigator.pop(ctx);
        },
        onCreate: (name) {
          provider.updateStagingProvider(nombre: name, idExistente: null);
          Navigator.pop(ctx);
        }
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isMatch = staging.proveedorMatch.estado.contains("MATCH_EXACTO");
    bool isManualOverride = staging.proveedorMatch.estado == "MATCH_MANUAL";
    
    String originalName = provider.aiRawData?.proveedorDetectado ?? "Desconocido";
    String originalRuc = provider.aiRawData?.rucDetectado ?? "Sin RUC";
    
    String selectedName = staging.proveedorMatch.datos?.nombre ?? staging.proveedorTexto;
    String? selectedRuc = staging.rucProveedor; 
    String displayRuc = selectedRuc ?? originalRuc;

    // 🔥 DATO EXTRA DE CONTEXTO: Monto Total
    String totalDisplay = staging.montoTotalFactura != null 
        ? "Monto a registrar: S/ ${staging.montoTotalFactura!.toStringAsFixed(2)}"
        : "Factura sin monto total detectado";

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF23232F) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
        boxShadow: [if (!isDark) const BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))]
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false, 
          iconColor: isDark ? Colors.blue[300] : Colors.blue[800],
          collapsedIconColor: isDark ? Colors.grey[400] : Colors.grey[700],
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "DATOS DEL PROVEEDOR", 
                style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[700], fontWeight: FontWeight.bold, letterSpacing: 1)
              ),
              if (isManualOverride)
                InkWell(
                  onTap: () {
                    provider.updateStagingProvider(
                      nombre: originalName, 
                      idExistente: null,
                      ruc: provider.aiRawData?.rucDetectado,
                      fecha: provider.aiRawData?.fechaDetectada
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text("Restaurar", style: TextStyle(fontSize: 13, color: isDark ? Colors.red[300] : Colors.red, fontWeight: FontWeight.bold)),
                  ),
                )
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  // 🔥 CONTEXTO FINANCIERO
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.green.withOpacity(0.1) : Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      totalDisplay,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: isDark ? Colors.green[300] : Colors.green[800], fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),

                  if (isManualOverride) ...[
                    _buildVendorOptionTile(
                      icon: Icons.radio_button_off,
                      title: originalName,
                      subtitle: "Detectado en Factura (RUC: ${provider.aiRawData?.rucDetectado ?? 'N/A'})",
                      color: isDark ? Colors.grey[500]! : Colors.grey,
                      isDark: isDark,
                      onTap: () => provider.updateStagingProvider(
                        nombre: originalName, 
                        idExistente: null,
                        ruc: provider.aiRawData?.rucDetectado
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(children: [Expanded(child: Divider(color: isDark ? Colors.white10 : Colors.grey[300])), Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Icon(Icons.arrow_downward, size: 20, color: isDark ? Colors.grey[600] : Colors.grey)), Expanded(child: Divider(color: isDark ? Colors.white10 : Colors.grey[300]))]),
                    ),
                    _buildVendorOptionTile(
                      icon: Icons.radio_button_checked,
                      title: selectedName,
                      subtitle: "Seleccionado BD (ID: ${staging.proveedorMatch.datos?.id})",
                      color: isDark ? Colors.green[400]! : Colors.green,
                      isDark: isDark,
                      onTap: () {}, 
                      trailing: TextButton.icon(
                        icon: const Icon(Icons.search, size: 18),
                        label: const Text("Cambiar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        style: TextButton.styleFrom(foregroundColor: isDark ? Colors.blue[300] : Colors.blue),
                        onPressed: () => _showProviderSearchModal(context),
                      )
                    ),
                  ] 
                  else ...[
                    _buildVendorOptionTile(
                      icon: isMatch ? Icons.check_circle : Icons.add_business,
                      title: selectedName,
                      subtitle: isMatch 
                          ? "Vinculado a Base de Datos (RUC: $displayRuc)" 
                          : "Se creará nuevo proveedor (RUC: $displayRuc)",
                      color: isMatch ? (isDark ? Colors.green[400]! : Colors.green) : (isDark ? Colors.blue[300]! : Colors.blue),
                      isDark: isDark,
                      onTap: () {},
                      trailing: TextButton.icon(
                        icon: const Icon(Icons.search, size: 18),
                        label: const Text("Buscar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        style: TextButton.styleFrom(foregroundColor: isDark ? Colors.blue[300] : Colors.blue),
                        onPressed: () => _showProviderSearchModal(context),
                      )
                    ),
                  ]
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildVendorOptionTile({required IconData icon, required String title, required String subtitle, required Color color, required bool isDark, required VoidCallback onTap, Widget? trailing}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: isDark ? color.withOpacity(0.15) : color.withOpacity(0.1),
              radius: 22,
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : color.withOpacity(0.9))),
                ],
              ),
            ),
            if (trailing != null) trailing
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// MODAL INTERNO DE BÚSQUEDA DE PROVEEDOR
// ----------------------------------------------------------------------
class _LocalProviderSearch extends StatefulWidget {
  final List<dynamic> providers; 
  final bool isDark;
  final Function(dynamic) onSelect;
  final Function(String) onCreate;

  const _LocalProviderSearch({required this.providers, required this.isDark, required this.onSelect, required this.onCreate});

  @override
  State<_LocalProviderSearch> createState() => _LocalProviderSearchState();
}

class _LocalProviderSearchState extends State<_LocalProviderSearch> {
  String query = "";

  @override
  Widget build(BuildContext context) {
    final filtered = widget.providers.where((p) => 
      p.nombreEmpresa.toLowerCase().contains(query.toLowerCase())
    ).toList();
    final textColor = widget.isDark ? Colors.white : Colors.black87;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF23232F) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24))
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          children: [
            Center(child: Container(width: 50, height: 5, decoration: BoxDecoration(color: widget.isDark ? Colors.white24 : Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 20),
            Text("Buscar Proveedor", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: textColor)),
            const SizedBox(height: 20),
            TextField(
              autofocus: true,
              style: TextStyle(color: textColor, fontSize: 16),
              decoration: InputDecoration(
                hintText: "Escribe para buscar...", 
                hintStyle: TextStyle(color: widget.isDark ? Colors.grey[500] : Colors.grey),
                prefixIcon: Icon(Icons.search, color: widget.isDark ? Colors.blue[300] : Colors.blue), 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                filled: true,
                fillColor: widget.isDark ? const Color(0xFF14141C) : Colors.grey[100]
              ),
              onChanged: (val) => setState(() => query = val),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: filtered.length + 1,
                separatorBuilder: (_, __) => Divider(height: 1, color: widget.isDark ? Colors.white10 : Colors.grey[200]),
                itemBuilder: (ctx, i) {
                  if (i == filtered.length) {
                    if (query.isNotEmpty && !filtered.any((p) => p.nombreEmpresa.toLowerCase() == query.toLowerCase())) {
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: widget.isDark ? Colors.blue.withOpacity(0.2) : Colors.blue[50], shape: BoxShape.circle), child: Icon(Icons.add_business, color: widget.isDark ? Colors.blue[300] : Colors.blue)),
                        title: Text("Crear nuevo: '$query'", style: TextStyle(color: widget.isDark ? Colors.blue[300] : Colors.blue[800], fontWeight: FontWeight.bold, fontSize: 16)),
                        onTap: () => widget.onCreate(query),
                      );
                    }
                    return const SizedBox.shrink();
                  }
                  final prov = filtered[i];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    title: Text(prov.nombreEmpresa, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                    subtitle: prov.ruc != null ? Text("RUC: ${prov.ruc}", style: TextStyle(color: widget.isDark ? Colors.grey[400] : Colors.grey[700])) : null,
                    onTap: () => widget.onSelect(prov),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}