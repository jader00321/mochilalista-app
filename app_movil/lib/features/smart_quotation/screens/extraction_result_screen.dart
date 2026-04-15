import 'dart:io';
import 'package:app_movil/features/smart_quotation/screens/matching_screen.dart';
import 'package:app_movil/features/smart_quotation/providers/matching_provider.dart'; 
import 'package:app_movil/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:multi_split_view/multi_split_view.dart';
import '../providers/smart_quotation_provider.dart';
import '../models/extracted_list_model.dart';
import '../../../widgets/universal_image.dart';

class ExtractionResultScreen extends StatefulWidget {
  const ExtractionResultScreen({super.key});

  @override
  State<ExtractionResultScreen> createState() => _ExtractionResultScreenState();
}

class _ExtractionResultScreenState extends State<ExtractionResultScreen> {
  final _schoolCtrl = TextEditingController();
  final _studentCtrl = TextEditingController();
  final _gradeCtrl = TextEditingController();

  late MultiSplitViewController _splitController;
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _splitController = MultiSplitViewController(
      areas: [
        Area(size: 0.35, min: 0.20), 
        Area(size: 0.65, min: 0.45) 
      ],
    );

    _scrollController.addListener(() {
      if (_scrollController.offset > 200 && !_showScrollToTop) {
        setState(() => _showScrollToTop = true);
      } else if (_scrollController.offset <= 200 && _showScrollToTop) {
        setState(() => _showScrollToTop = false);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = Provider.of<SmartQuotationProvider>(context, listen: false);
      if (provider.metadata != null) {
        _schoolCtrl.text = provider.metadata!.institutionName ?? "";
        _studentCtrl.text = provider.metadata!.studentName ?? "";
        _gradeCtrl.text = provider.metadata!.gradeLevel ?? "";
      }
    });
  }

  @override
  void dispose() {
    _schoolCtrl.dispose();
    _studentCtrl.dispose();
    _gradeCtrl.dispose();
    _splitController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0, 
      duration: const Duration(milliseconds: 500), 
      curve: Curves.easeInOutCubic
    );
  }

  void _showDeleteConfirmation(BuildContext parentContext, int itemId, bool isDark) {
    showDialog(
      context: parentContext,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [Icon(Icons.warning_amber_rounded, color: isDark ? Colors.orange[300] : Colors.orange, size: 30), const SizedBox(width: 10), Text("¿Eliminar ítem?", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold))]),
        content: Text("Se eliminará este producto de la lista. Esta acción no se puede deshacer.", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700], fontSize: 16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar", style: TextStyle(color: Colors.grey, fontSize: 16))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.red[800] : Colors.red[50], foregroundColor: isDark ? Colors.white : Colors.red, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () {
              Provider.of<SmartQuotationProvider>(parentContext, listen: false).deleteItem(itemId);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(parentContext).showSnackBar(const SnackBar(content: Text("Producto eliminado", style: TextStyle(fontWeight: FontWeight.bold)), duration: Duration(milliseconds: 1500), behavior: SnackBarBehavior.floating));
            },
            child: const Text("Eliminar", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isClient = auth.isCommunityClient; // 🔥 Variable de Rol

    return Consumer<SmartQuotationProvider>(
      builder: (context, provider, child) {
        final File? image = provider.currentImage;

        if (image == null) {
          return Scaffold(backgroundColor: bgColor, appBar: AppBar(title: const Text("Error")), body: const Center(child: Text("No se pudo cargar la imagen.")));
        }

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔥 Título dinámico
                Text(isClient ? "Revisa tu Lista Escolar" : "Validar Datos Extraídos", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text("${provider.items.length} productos identificados", style: TextStyle(fontSize: 13, color: isDark ? Colors.blue[200] : Colors.blue[100], fontWeight: FontWeight.w500)),
              ],
            ),
            backgroundColor: isDark ? const Color(0xFF1A1A24) : Colors.blue[900],
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: FilledButton.icon(
                  onPressed: () {
                    final smartProvider = Provider.of<SmartQuotationProvider>(context, listen: false);
                    final matchingProvider = Provider.of<MatchingProvider>(context, listen: false); 
                    final auth = Provider.of<AuthProvider>(context, listen: false);
                    
                    final updatedMetadata = ExtractedMetadata(
                      institutionName: _schoolCtrl.text,
                      studentName: _studentCtrl.text,
                      gradeLevel: _gradeCtrl.text,
                    );

                    matchingProvider.setEvidence(
                        smartProvider.currentImage, 
                        smartProvider.fullExtractedText
                    );

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MatchingScreen(
                          metadata: updatedMetadata, 
                          extractedItems: smartProvider.items,
                          token: auth.token ?? "",
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  // 🔥 Botón dinámico
                  label: Text(isClient ? "BUSCAR PRODUCTOS" : "COTIZAR", style: const TextStyle(fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(backgroundColor: isDark ? Colors.blue[600] : Colors.blue[700], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                ),
              ),
            ],
          ),

          body: SafeArea(
            child: Container(
              color: isDark ? const Color(0xFF14141C) : Colors.grey[200],
              child: MultiSplitViewTheme(
                data: MultiSplitViewThemeData(dividerThickness: 35),
                child: MultiSplitView(
                  axis: Axis.vertical,
                  controller: _splitController,
                  dividerBuilder: (axis, index, resizable, dragging, highlighted, themeData) {
                    return Container(
                      color: isDark ? const Color(0xFF1A1A24) : Colors.grey[100], 
                      alignment: Alignment.center,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                        decoration: BoxDecoration(
                          color: dragging ? (isDark ? Colors.blue.withOpacity(0.3) : Colors.blue[100]) : (isDark ? const Color(0xFF23232F) : Colors.white),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: dragging ? Colors.transparent : (isDark ? Colors.white10 : Colors.grey.shade300)),
                          boxShadow: [if (!dragging && !isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.drag_handle, size: 22, color: dragging ? Colors.blue : (isDark ? Colors.grey[400] : Colors.grey[600])),
                            const SizedBox(width: 10),
                            Text("ARRASTRAR", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: dragging ? Colors.blue : (isDark ? Colors.grey[400] : Colors.grey[600]))),
                          ],
                        ),
                      ),
                    );
                  },
                  builder: (BuildContext context, Area area) {
                    if (area.index == 0) {
                      return _buildImageViewer(image);
                    } else {
                      return _buildDataList(provider, isDark, isClient);
                    }
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageViewer(File imageFile) {
    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          InteractiveViewer(
            minScale: 1.0, 
            maxScale: 5.0, 
            boundaryMargin: EdgeInsets.zero, 
            panEnabled: true, 
            child: UniversalImage(path: imageFile.path, fit: BoxFit.contain)
          ),
          Positioned(
            bottom: 12, left: 0, right: 0, 
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), 
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)), 
                child: const Text("🔍 Pellizca para hacer zoom a la lista", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold))
              )
            )
          ),
        ],
      ),
    );
  }

  Widget _buildDataList(SmartQuotationProvider provider, bool isDark, bool isClient) {
    return Container(
      color: isDark ? const Color(0xFF14141C) : Colors.grey[50],
      child: Stack(
        children: [
          provider.items.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 60, color: isDark ? Colors.white24 : Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text("No se detectaron items.", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => provider.addItem(), 
                      icon: const Icon(Icons.add), 
                      label: const Text("Añadir Fila Manual"),
                      style: ElevatedButton.styleFrom(backgroundColor: isDark ? Colors.blue[800] : Colors.blue[50], foregroundColor: isDark ? Colors.white : Colors.blue[800], elevation: 0),
                    )
                  ],
                ),
              )
            : ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), 
                itemCount: provider.items.length + 2, 
                separatorBuilder: (_, __) => const SizedBox(height: 16),
                itemBuilder: (ctx, i) {
                  if (i == 0) {
                    return _buildMetadataCard(provider, isDark, isClient);
                  }
                  
                  if (i == provider.items.length + 1) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: OutlinedButton.icon(
                        onPressed: () => provider.addItem(),
                        icon: const Icon(Icons.add_circle_outline, size: 22),
                        label: const Text("Añadir Fila Manualmente", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          foregroundColor: isDark ? Colors.blue[300] : Colors.blue[800],
                          side: BorderSide(color: isDark ? Colors.blue.withOpacity(0.3) : Colors.blue.withOpacity(0.5), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    );
                  }
                  
                  final actualIndex = i - 1;
                  final item = provider.items[actualIndex];
                  return _InternalItemCard(
                    key: ValueKey(item.id), 
                    item: item, 
                    index: actualIndex, 
                    isDark: isDark, 
                    onDeletePressed: () => _showDeleteConfirmation(context, item.id, isDark)
                  );
                },
              ),

          if (_showScrollToTop)
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton(
                mini: true,
                onPressed: _scrollToTop,
                backgroundColor: isDark ? Colors.blueGrey[800] : Colors.white,
                foregroundColor: isDark ? Colors.white : Colors.black87,
                elevation: 4,
                child: const Icon(Icons.keyboard_arrow_up, size: 24),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildMetadataCard(SmartQuotationProvider provider, bool isDark, bool isClient) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF23232F) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
        boxShadow: [if (!isDark) const BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))]
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          iconColor: isDark ? Colors.blue[300] : Colors.blue[800],
          collapsedIconColor: isDark ? Colors.grey[400] : Colors.grey[600],
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          title: Row(
            children: [
              Icon(Icons.info_outline, color: isDark ? Colors.blue[300] : Colors.blue[700]),
              const SizedBox(width: 10),
              Text(
                "Datos de la Cotización",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  _MetaInput(icon: Icons.school, hint: "Institución Educativa (Colegio)", ctrl: _schoolCtrl, isDark: isDark, onChanged: (v) => provider.updateMetadata(institution: v)),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200])),
                  Row(
                    children: [
                      // 🔥 Dinámico: Si es cliente, sugerimos que deje el nombre de su hijo o el suyo.
                      Expanded(child: _MetaInput(icon: Icons.person, hint: isClient ? "Nombre de tu hijo/a (Opcional)" : "Alumno/a (Opcional)", ctrl: _studentCtrl, isDark: isDark, onChanged: (v) => provider.updateMetadata(student: v))),
                      Container(width: 1, height: 40, color: isDark ? Colors.white10 : Colors.grey[300], margin: const EdgeInsets.symmetric(horizontal: 16)),
                      Expanded(child: _MetaInput(icon: Icons.class_, hint: "Grado / Sección", ctrl: _gradeCtrl, isDark: isDark, onChanged: (v) => provider.updateMetadata(grade: v))),
                    ],
                  ),
                ],
              ),
            ),
          ]
        ),
      )
    );
  }
}

class _MetaInput extends StatelessWidget {
  final IconData icon;
  final String hint;
  final TextEditingController ctrl;
  final Function(String) onChanged;
  final bool isDark;

  const _MetaInput({required this.icon, required this.hint, required this.ctrl, required this.onChanged, required this.isDark});
  
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 24, color: isDark ? Colors.blue[300] : Colors.blue[800]), 
        const SizedBox(width: 12), 
        Expanded(
          child: TextField(
            controller: ctrl, 
            decoration: InputDecoration(
              hintText: hint, 
              isDense: true, 
              border: InputBorder.none, 
              hintStyle: TextStyle(fontSize: 15, color: isDark ? Colors.grey[600] : Colors.grey[400], fontStyle: FontStyle.italic)
            ), 
            style: TextStyle(fontSize: 16, color: isDark ? Colors.white : Colors.blue[900], fontWeight: FontWeight.w600), 
            onChanged: onChanged
          )
        )
      ]
    );
  }
}

class _InternalItemCard extends StatefulWidget {
  final ExtractedItem item;
  final int index;
  final bool isDark;
  final VoidCallback onDeletePressed;
  
  const _InternalItemCard({super.key, required this.item, required this.index, required this.isDark, required this.onDeletePressed});
  
  @override
  State<_InternalItemCard> createState() => _InternalItemCardState();
}

class _InternalItemCardState extends State<_InternalItemCard> {
  late TextEditingController _nameCtrl;
  late TextEditingController _qtyCtrl;
  late TextEditingController _unitCtrl;
  late TextEditingController _brandCtrl;
  late TextEditingController _notesCtrl;

  @override
  void initState() { super.initState(); _initControllers(); }
  
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
  void dispose() { _nameCtrl.dispose(); _qtyCtrl.dispose(); _unitCtrl.dispose(); _brandCtrl.dispose(); _notesCtrl.dispose(); super.dispose(); }
  
  void _saveToProvider() {
    Provider.of<SmartQuotationProvider>(context, listen: false).updateItem(widget.item.id, fullName: _nameCtrl.text, quantity: int.tryParse(_qtyCtrl.text) ?? 1, unit: _unitCtrl.text, brand: _brandCtrl.text, notes: _notesCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = widget.isDark ? const Color(0xFF23232F) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.isDark ? Colors.white10 : Colors.grey.shade300),
        boxShadow: [if (!widget.isDark) BoxShadow(color: Colors.grey.shade200, blurRadius: 6, offset: const Offset(0, 3))]
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, 
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), 
                  decoration: BoxDecoration(color: widget.isDark ? Colors.blue.withOpacity(0.15) : Colors.blue[50], borderRadius: BorderRadius.circular(8)), 
                  child: Text("Fila #${widget.index + 1}", style: TextStyle(color: widget.isDark ? Colors.blue[300] : Colors.blue[900], fontWeight: FontWeight.bold, fontSize: 14))
                ),
                if (widget.item.originalText.isNotEmpty && widget.item.originalText != "Agregado manual") 
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12), 
                      child: Text("IA leyó: \"${widget.item.originalText}\"", style: TextStyle(fontSize: 13, color: widget.isDark ? Colors.grey[500] : Colors.grey[600], fontStyle: FontStyle.italic), maxLines: 1, overflow: TextOverflow.ellipsis)
                    )
                  ),
                IconButton(icon: Icon(Icons.close, color: widget.isDark ? Colors.red[300] : Colors.red, size: 28), onPressed: widget.onDeletePressed, constraints: const BoxConstraints(), padding: EdgeInsets.zero, tooltip: "Eliminar fila"),
              ]
            ),
            const SizedBox(height: 16),
            _buildTextField(controller: _nameCtrl, label: "Producto / Descripción extraída", icon: Icons.edit_note, isBold: true, isDark: widget.isDark),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(flex: 2, child: _buildTextField(controller: _qtyCtrl, label: "Cant.", isNumber: true, isDark: widget.isDark)), 
                const SizedBox(width: 12), 
                Expanded(flex: 3, child: _buildTextField(controller: _unitCtrl, label: "Unidad", isDark: widget.isDark)), 
                const SizedBox(width: 12), 
                Expanded(flex: 4, child: _buildTextField(controller: _brandCtrl, label: "Marca (Opcional)", icon: Icons.branding_watermark, isDark: widget.isDark))
              ]
            ),
            const SizedBox(height: 12),
            _buildTextField(controller: _notesCtrl, label: "Detalles adicionales (Colores, tamaños...)", icon: Icons.info_outline, isSoft: true, isDark: widget.isDark),
          ]
        ),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, IconData? icon, bool isNumber = false, bool isBold = false, bool isSoft = false, required bool isDark}) {
    return TextFormField(
      controller: controller, 
      onChanged: (_) => _saveToProvider(), 
      keyboardType: isNumber ? TextInputType.number : TextInputType.text, 
      style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, fontSize: 16, color: isDark ? Colors.white : Colors.black87), 
      decoration: InputDecoration(
        labelText: label, 
        labelStyle: TextStyle(fontSize: 14, color: isDark ? Colors.grey[500] : Colors.grey[700]), 
        isDense: true, 
        filled: true, 
        fillColor: isDark 
            ? (isSoft ? Colors.orange.withOpacity(0.05) : const Color(0xFF14141C)) 
            : (isSoft ? Colors.orange[50] : Colors.white), 
        prefixIcon: icon != null ? Icon(icon, size: 20, color: isDark ? Colors.grey[400] : Colors.grey[600]) : null, 
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none), 
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300)), 
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? Colors.blue.withOpacity(0.5) : Colors.blue.withOpacity(0.3))), 
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)
      )
    );
  }
}