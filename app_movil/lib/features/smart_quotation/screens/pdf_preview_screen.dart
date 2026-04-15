import 'package:flutter/material.dart';
import 'package:printing/printing.dart'; 
import 'package:provider/provider.dart';

import '../providers/smart_quotation_provider.dart';
import '../providers/sale_provider.dart'; 
import '../../../providers/auth_provider.dart'; 
import '../models/smart_quotation_model.dart';
import '../models/pdf_config_model.dart'; 
import '../utils/pdf_generator.dart'; 

class PdfPreviewScreen extends StatefulWidget {
  final int? quotationId; 
  final int? saleId;      

  const PdfPreviewScreen({super.key, this.quotationId, this.saleId});

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  late PdfConfig _config;
  SmartQuotationModel? _quotation;
  Map<String, dynamic>? _saleData;
  bool _loadingData = true;

  final TextEditingController _titleCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _config = PdfConfig(); 
    _loadData();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      if (widget.saleId != null) {
        final saleProv = Provider.of<SaleProvider>(context, listen: false);
        _saleData = await saleProv.getSaleDetail(widget.saleId!);
        
        if (_saleData != null && _saleData!['cotizacion'] != null) {
          _quotation = SmartQuotationModel.fromJson(_saleData!['cotizacion']);
          _config.documentTitle = "COMPROBANTE DE PAGO"; 
          _config.showTransactionDetails = true;
        }
      } 
      else if (widget.quotationId != null) {
        final qProv = Provider.of<SmartQuotationProvider>(context, listen: false);
        _quotation = await qProv.getQuotationById(widget.quotationId!);
        _config.documentTitle = "COTIZACIÓN"; 
        _config.showTransactionDetails = false;
      }

      if (_quotation != null) {
        _titleCtrl.text = _config.documentTitle ?? "";
        _config.showClientName = (_quotation!.clientName != null && _quotation!.clientName!.isNotEmpty) || 
                                 (_saleData != null && _saleData!['cliente_nombre'] != null);
        
        final bool isQuickSale = _saleData != null && _saleData!['origen_venta'] == 'pos_rapido';
        final bool hasNotes = _saleData != null && _saleData!['cliente_notas'] != null && _saleData!['cliente_notas'].toString().isNotEmpty;
        final bool hasInst = !isQuickSale && ((_quotation!.institutionName?.isNotEmpty ?? false) || (_quotation!.gradeLevel?.isNotEmpty ?? false));
        
        _config.showInstitutionInfo = hasInst || hasNotes;
      }
    } catch (e) {
      debugPrint("Error cargando PDF: $e");
    }

    if (mounted) setState(() => _loadingData = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    
    if (_loadingData) return Scaffold(backgroundColor: bgColor, body: const Center(child: CircularProgressIndicator()));
    if (_quotation == null) return Scaffold(backgroundColor: bgColor, body: Center(child: Text("Error cargando datos del documento", style: TextStyle(color: isDark ? Colors.white : Colors.black87))));

    final authProv = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text("Vista Previa PDF", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: isDark ? const Color(0xFF1A1A24) : Colors.blue[900],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: isDark ? Colors.black12 : Colors.grey[200],
              child: PdfPreview(
                build: (format) => PdfGenerator.generatePdf(
                  quotation: _quotation!,
                  ownerInfo: authProv.user, 
                  config: _config,
                  saleData: _saleData, 
                ),
                useActions: false, 
                canChangeOrientation: false,
                canChangePageFormat: false,
                maxPageWidth: 700, 
                loadingWidget: const Center(child: CircularProgressIndicator()),
                pdfFileName: "${_config.documentTitle}_${_quotation!.id}.pdf",
              ),
            ),
          ),
          _buildBottomToolbar(context, isDark),
        ],
      ),
    );
  }

  Widget _buildBottomToolbar(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? Theme.of(context).colorScheme.surface : Colors.white, 
        boxShadow: [if (!isDark) const BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, -5))]
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: () => _showConfigModal(context, isDark),
                icon: const Icon(Icons.tune, size: 20),
                label: const Text("PERSONALIZAR", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.blueGrey[800] : Colors.grey[900], 
                  foregroundColor: Colors.white, 
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: _sharePdf, 
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))
                ), 
                child: Icon(Icons.share, color: isDark ? Colors.blue[300] : Colors.blue[700], size: 24)
              )
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _printPdf, 
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800], 
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))
                ), 
                child: const Icon(Icons.print, color: Colors.white, size: 24)
              )
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sharePdf() async {
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final bytes = await PdfGenerator.generatePdf(quotation: _quotation!, ownerInfo: authProv.user, config: _config, saleData: _saleData);
    await Printing.sharePdf(bytes: bytes, filename: '${_config.documentTitle}.pdf');
  }

  Future<void> _printPdf() async {
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final bytes = await PdfGenerator.generatePdf(quotation: _quotation!, ownerInfo: authProv.user, config: _config, saleData: _saleData);
    await Printing.layoutPdf(onLayout: (_) => bytes);
  }

  void _showConfigModal(BuildContext context, bool isDark) {
    final surfaceColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.transparent, // Fondo transparente del modal
      barrierColor: Colors.black26, // Sombrea suavemente la app atrás
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          void updateConfig(VoidCallback fn) {
            setModalState(fn);
            this.setState(fn);
          }

          final bool isQuickSale = _saleData != null && _saleData!['origen_venta'] == 'pos_rapido';
          final bool hasNotes = _saleData != null && _saleData!['cliente_notas'] != null && _saleData!['cliente_notas'].toString().isNotEmpty;
          final bool hasInst = !isQuickSale && ((_quotation!.institutionName?.isNotEmpty ?? false) || (_quotation!.gradeLevel?.isNotEmpty ?? false));
          final bool canToggleExtraInfo = hasInst || hasNotes;

          return Container(
            // 🔥 REQUERIMIENTO: Altura máxima 70% de la pantalla
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
            decoration: BoxDecoration(color: surfaceColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
            child: Column(
              children: [
                // Cabecera del Modal
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Opciones de Documento", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: textColor)),
                      IconButton(icon: Icon(Icons.close, size: 28, color: textColor), onPressed: () => Navigator.pop(context))
                    ],
                  ),
                ),
                Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
                
                // Contenido del Modal
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      _buildSectionHeader("Título del Documento", Icons.title, isDark),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(color: isDark ? const Color(0xFF14141C) : Colors.grey[50], border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                        child: TextField(
                          controller: _titleCtrl,
                          style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
                          decoration: InputDecoration(border: InputBorder.none, hintText: "Ej: BOLETA, TICKET, RECIBO", hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey)),
                          onChanged: (v) => updateConfig(() => _config.documentTitle = v.toUpperCase()),
                        ),
                      ),
                      const SizedBox(height: 24),

                      _buildSectionHeader("Estilo Visual", Icons.palette, isDark),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(color: isDark ? const Color(0xFF14141C) : Colors.grey[50], border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<PdfTheme>(
                            value: _config.theme,
                            dropdownColor: surfaceColor,
                            style: TextStyle(color: textColor, fontSize: 16),
                            isExpanded: true,
                            items: [
                              DropdownMenuItem(value: PdfTheme.modern, child: Text("✨ Moderno (Azul)", style: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue[800], fontWeight: FontWeight.bold))),
                              DropdownMenuItem(value: PdfTheme.classic, child: Text("📄 Clásico (B/N)", style: TextStyle(color: textColor))),
                              DropdownMenuItem(value: PdfTheme.minimal, child: Text("🖊️ Minimalista", style: TextStyle(color: textColor))),
                            ],
                            onChanged: (v) => updateConfig(() => _config.theme = v!),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 🔥 DATOS DE LOS PRODUCTOS (SISTEMA CASCADA / SUBNIVELES)
                      Container(
                        decoration: BoxDecoration(color: isDark ? Colors.green.withOpacity(0.05) : Colors.green[50], borderRadius: BorderRadius.circular(16)),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            title: Text("Datos de los Productos", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.green[300] : Colors.green[900])),
                            leading: Icon(Icons.list_alt, color: isDark ? Colors.green[400] : Colors.green[700]),
                            initiallyExpanded: true,
                            children: [
                              SwitchListTile(title: Text("Mostrar Columna: Unidad", style: TextStyle(color: textColor)), subtitle: Text("Ej: Docena, Empaque", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700])), value: _config.showProductUnit, activeColor: Colors.green, onChanged: (v) => updateConfig(() => _config.showProductUnit = v)),
                              
                              // Nivel principal: Precio Unitario
                              _buildMainSwitch(
                                title: "Mostrar Columna: Unitario",
                                subtitle: "Muestra el precio por 1 item",
                                value: _config.showProductUnitPrice,
                                isDark: isDark,
                                color: Colors.green,
                                textColor: textColor,
                                onChanged: (v) => updateConfig(() {
                                  _config.showProductUnitPrice = v;
                                  if (!v) _config.showProductSavings = false; // Cascada
                                })
                              ),
                              // Subnivel: Descuento Unitario (Depende del Precio Unitario)
                              _buildSubSwitch(
                                title: "Mostrar Descuento Unitario",
                                subtitle: "Precio original tachado",
                                value: _config.showProductSavings,
                                enabled: _config.showProductUnitPrice,
                                isDark: isDark,
                                color: Colors.green,
                                textColor: textColor,
                                onChanged: (v) => updateConfig(() => _config.showProductSavings = v)
                              ),

                              SwitchListTile(title: Text("Mostrar Columna: Subtotal", style: TextStyle(color: textColor)), subtitle: Text("Multiplica el precio por cantidad", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700])), value: _config.showProductSubtotal, activeColor: Colors.green, onChanged: (v) => updateConfig(() => _config.showProductSubtotal = v)),
                              const SizedBox(height: 10),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 🔥 TOTALES FINANCIEROS (SISTEMA CASCADA / SUBNIVELES)
                      Container(
                        decoration: BoxDecoration(color: isDark ? Colors.teal.withOpacity(0.05) : Colors.teal[50], borderRadius: BorderRadius.circular(16)),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            title: Text("Totales y Pago", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.teal[300] : Colors.teal[900])),
                            leading: Icon(Icons.attach_money, color: isDark ? Colors.teal[400] : Colors.teal[700]),
                            children: [
                              if (_saleData != null)
                                SwitchListTile(title: Text("Mostrar Info de Pago", style: TextStyle(color: textColor)), subtitle: Text("Método, Fecha y Deuda", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700])), value: _config.showTransactionDetails, activeColor: Colors.teal, onChanged: (v) => updateConfig(() => _config.showTransactionDetails = v)),
                              
                              // Nivel Principal: Total
                              _buildMainSwitch(
                                title: "Mostrar Total a Pagar",
                                subtitle: "Suma final de la transacción",
                                value: _config.showTotalGlobal,
                                isDark: isDark,
                                color: Colors.teal,
                                textColor: textColor,
                                onChanged: (v) => updateConfig(() {
                                  _config.showTotalGlobal = v;
                                  if (!v) _config.showTotalSavings = false; // Cascada
                                })
                              ),
                              // Subnivel: Ahorro Global (Depende del Total)
                              _buildSubSwitch(
                                title: "Mostrar Descuento Global",
                                subtitle: "Suma de todo lo ahorrado",
                                value: _config.showTotalSavings,
                                enabled: _config.showTotalGlobal,
                                isDark: isDark,
                                color: Colors.teal,
                                textColor: textColor,
                                onChanged: (v) => updateConfig(() => _config.showTotalSavings = v)
                              ),
                              const SizedBox(height: 10),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Container(
                        decoration: BoxDecoration(color: isDark ? Colors.blue.withOpacity(0.05) : Colors.blue[50], borderRadius: BorderRadius.circular(16)),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            title: Text("Mi Negocio", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.blue[300] : Colors.blue[900])),
                            leading: Icon(Icons.store, color: isDark ? Colors.blue[400] : Colors.blue[700]),
                            children: [
                              SwitchListTile(title: Text("Mostrar Cabecera", style: TextStyle(color: textColor)), value: _config.showBusinessInfo, activeColor: Colors.blue, onChanged: (v) => updateConfig(() => _config.showBusinessInfo = v)),
                              if (_config.showBusinessInfo) ...[
                                CheckboxListTile(title: Text("Logo", style: TextStyle(color: textColor)), activeColor: Colors.blue, value: _config.includeLogo, onChanged: (v) => updateConfig(() => _config.includeLogo = v!)),
                                CheckboxListTile(title: Text("Dirección", style: TextStyle(color: textColor)), activeColor: Colors.blue, value: _config.includeShopAddress, onChanged: (v) => updateConfig(() => _config.includeShopAddress = v!)),
                                CheckboxListTile(title: Text("Teléfono", style: TextStyle(color: textColor)), activeColor: Colors.blue, value: _config.includeOwnerPhone, onChanged: (v) => updateConfig(() => _config.includeOwnerPhone = v!)),
                                CheckboxListTile(title: Text("RUC", style: TextStyle(color: textColor)), activeColor: Colors.blue, value: _config.includeShopRuc, onChanged: (v) => updateConfig(() => _config.includeShopRuc = v!)),
                                const SizedBox(height: 10),
                              ]
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Container(
                        decoration: BoxDecoration(color: isDark ? Colors.orange.withOpacity(0.05) : Colors.orange[50], borderRadius: BorderRadius.circular(16)),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            title: Text("Datos del Cliente", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.orange[300] : Colors.orange[900])),
                            leading: Icon(Icons.person, color: isDark ? Colors.orange[400] : Colors.orange[700]),
                            children: [
                              SwitchListTile(
                                title: Text("Nombre / Teléfono", style: TextStyle(color: textColor)), 
                                value: _config.showClientName, 
                                activeColor: Colors.orange,
                                onChanged: (v) => updateConfig(() => _config.showClientName = v),
                              ),
                              SwitchListTile(
                                title: Text(isQuickSale ? "Mostrar Nota de Venta" : "Información Adicional", style: TextStyle(color: textColor)), 
                                subtitle: Text(isQuickSale ? "Imprime la nota registrada" : "Colegio / Grado / Notas", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700])),
                                value: _config.showInstitutionInfo, 
                                activeColor: Colors.orange,
                                onChanged: canToggleExtraInfo ? (v) => updateConfig(() => _config.showInstitutionInfo = v) : null,
                              ),
                              const SizedBox(height: 10),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                      Container(
                        decoration: BoxDecoration(color: isDark ? Colors.purple.withOpacity(0.05) : Colors.purple[50], borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.purple.withOpacity(0.2) : Colors.purple.shade100)),
                        child: SwitchListTile(
                          secondary: Icon(Icons.image, color: isDark ? Colors.purple[300] : Colors.purple[700]),
                          title: Text("Incluir Imágenes", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.purple[300] : Colors.purple[900])),
                          subtitle: Text("Estilo catálogo (Requiere internet)", style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700])),
                          value: _config.showImages,
                          activeColor: Colors.purple,
                          onChanged: (v) => updateConfig(() => _config.showImages = v),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: isDark ? Colors.blueGrey[300] : Colors.blueGrey),
          const SizedBox(width: 8),
          Text(title.toUpperCase(), style: TextStyle(color: isDark ? Colors.blueGrey[300] : Colors.blueGrey, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1)),
        ],
      ),
    );
  }

  // Helpers para el sistema en cascada
  Widget _buildMainSwitch({required String title, required String subtitle, required bool value, required bool isDark, required Color color, required Color textColor, required Function(bool) onChanged}) {
    return SwitchListTile(
      title: Text(title, style: TextStyle(color: textColor)),
      subtitle: Text(subtitle, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700])),
      value: value,
      activeColor: color,
      onChanged: onChanged,
    );
  }

  Widget _buildSubSwitch({required String title, required String subtitle, required bool value, required bool enabled, required bool isDark, required Color color, required Color textColor, required Function(bool) onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(left: 32), // Indentación para jerarquía visual
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: SwitchListTile(
          title: Text(title, style: TextStyle(color: textColor, fontSize: 14)),
          subtitle: Text(subtitle, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[700], fontSize: 12)),
          value: value,
          activeColor: color,
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
}