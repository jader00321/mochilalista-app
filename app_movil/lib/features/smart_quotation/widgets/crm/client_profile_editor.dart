import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/providers/tracking_provider.dart';
import 'package:app_movil/core/widgets/custom_snackbar.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

class _PhoneNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text.replaceAll(RegExp(r'\D'), ''); 
    if (text.length > 9) return oldValue; 
    
    StringBuffer buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 3 == 0) buffer.write(' ');
      buffer.write(text[i]);
    }
    
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.toString().length),
    );
  }
}

class ClientProfileEditor extends StatefulWidget {
  final ClientModel client;
  final bool isNew;

  const ClientProfileEditor({super.key, required this.client, this.isNew = false});

  @override
  State<ClientProfileEditor> createState() => _ClientProfileEditorState();
}

class _ClientProfileEditorState extends State<ClientProfileEditor> {
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _dniCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _notesCtrl;
  final TextEditingController _newTagCtrl = TextEditingController();

  List<String> _currentTags = [];
  String _currentConfidence = "bueno";
  bool _isLoading = false;

  final List<String> _suggestedTags = ["VIP", "Mayorista", "Problemático", "Familiar", "Institución"];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.client.fullName);
    
    String formattedPhone = widget.client.phone;
    if (formattedPhone.length == 9 && !formattedPhone.contains(' ')) {
       formattedPhone = "${formattedPhone.substring(0,3)} ${formattedPhone.substring(3,6)} ${formattedPhone.substring(6,9)}";
    }
    _phoneCtrl = TextEditingController(text: formattedPhone);
    
    _dniCtrl = TextEditingController(text: widget.client.docNumber);
    _addressCtrl = TextEditingController(text: widget.client.address);
    _emailCtrl = TextEditingController(text: widget.client.email);
    _notesCtrl = TextEditingController(text: widget.client.notes);
    _currentTags = List.from(widget.client.etiquetas);
    _currentConfidence = widget.client.nivelConfianza.isNotEmpty ? widget.client.nivelConfianza : "bueno";
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _dniCtrl.dispose();
    _addressCtrl.dispose();
    _emailCtrl.dispose();
    _notesCtrl.dispose();
    _newTagCtrl.dispose();
    super.dispose();
  }

  void _addTag(String tag) {
    String t = tag.trim().toUpperCase();
    if (t.isNotEmpty && !_currentTags.contains(t)) {
      HapticFeedback.selectionClick();
      setState(() => _currentTags.add(t));
      _newTagCtrl.clear();
    }
  }

  void _removeTag(String tag) {
    HapticFeedback.selectionClick();
    setState(() => _currentTags.remove(tag));
  }

  Future<void> _handleSave() async {
    if (_nameCtrl.text.trim().isEmpty) {
      CustomSnackBar.show(context, message: "El nombre es obligatorio", isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final data = {
        "nombre_completo": _nameCtrl.text.trim(),
        "telefono": _phoneCtrl.text.replaceAll(' ', '').trim().isEmpty ? "000000000" : _phoneCtrl.text.replaceAll(' ', '').trim(),
        "dni_ruc": _dniCtrl.text.trim(),
        "direccion": _addressCtrl.text.trim(),
        "correo": _emailCtrl.text.trim(),
        "notas": _notesCtrl.text.trim(),
        "etiquetas": _currentTags,
        "nivel_confianza": _currentConfidence,
      };

      final provider = Provider.of<TrackingProvider>(context, listen: false);
      
      ClientModel? updatedClient;
      if (widget.isNew) {
        updatedClient = await provider.createClient(data); 
      } else {
        updatedClient = await provider.updateClientProfile(widget.client.id, data);
      }

      if (mounted) {
        if (updatedClient != null) {
          CustomSnackBar.show(context, message: widget.isNew ? "Cliente registrado exitosamente" : "Perfil actualizado exitosamente", isError: false);
          Navigator.pop(context, updatedClient);
        } else {
          CustomSnackBar.show(context, message: "Error al guardar el cliente", isError: true);
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _getValidationWarning(String level) {
    if (widget.isNew) return null; 
    
    final debts = Provider.of<TrackingProvider>(context, listen: false).currentClientDebts;
    int maxDaysOverdue = 0;
    DateTime today = DateTime.now();
    today = DateTime(today.year, today.month, today.day);

    for (var sale in debts) {
      for (var cuota in sale.installments) {
        if (cuota.status != 'pagado') {
          DateTime dueDate = DateTime.tryParse(cuota.dueDate) ?? DateTime.now();
          dueDate = DateTime(dueDate.year, dueDate.month, dueDate.day);
          if (dueDate.isBefore(today)) {
            int days = today.difference(dueDate).inDays;
            if (days > maxDaysOverdue) maxDaysOverdue = days;
          }
        }
      }
    }

    if (level == "excelente" && maxDaysOverdue > 0) {
      return "⚠️ Este cliente tiene cuotas vencidas hace $maxDaysOverdue días. 'Excelente' podría no ser adecuado.";
    }
    if (level == "excelente" && widget.client.totalDebt > 500) {
      return "⚠️ Este cliente tiene una deuda alta de S/ ${widget.client.totalDebt.toStringAsFixed(2)}.";
    }
    if (level == "bueno" && maxDaysOverdue > 15) {
      return "⚠️ Este cliente tiene cuotas vencidas hace $maxDaysOverdue días. Sugerimos nivel 'Regular'.";
    }
    if ((level == "excelente" || level == "bueno") && maxDaysOverdue > 30) {
      return "⚠️ El cliente tiene deudas de más de 30 días. Su nivel debería ser 'Moroso'.";
    }
    
    return null;
  }

  Widget _buildConfidenceSelector(bool isDark) {
    final options = [
      {"val": "excelente", "title": "Excelente", "desc": "Pago Puntual, VIP", "color": Colors.green},
      {"val": "bueno", "title": "Bueno", "desc": "Confiable, historial normal", "color": Colors.blue},
      {"val": "regular", "title": "Regular", "desc": "Observado, atrasos", "color": Colors.orange},
      {"val": "moroso", "title": "Moroso", "desc": "Crítico, solo contado", "color": Colors.red},
    ];

    String? warning = _getValidationWarning(_currentConfidence);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth - 12) / 2;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: options.map((opt) {
                bool isSelected = _currentConfidence == opt["val"];
                Color baseColor = isDark ? (opt["color"] as MaterialColor)[400]! : (opt["color"] as MaterialColor)[600]!;
                
                return InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _currentConfidence = opt["val"] as String);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: cardWidth, 
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? baseColor.withValues(alpha: 0.15) : (isDark ? const Color(0xFF14141C) : Colors.grey[100]),
                      border: Border.all(
                        color: isSelected ? baseColor : (isDark ? Colors.white10 : Colors.grey.shade300),
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                              color: isSelected ? baseColor : (isDark ? Colors.grey[600] : Colors.grey[400]),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                opt["title"] as String, 
                                style: TextStyle(
                                  color: isSelected ? baseColor : (isDark ? Colors.white : Colors.black87), 
                                  fontWeight: FontWeight.bold, 
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          opt["desc"] as String, 
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600], 
                            fontSize: 11, 
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
        
        if (warning != null)
          Container(
            margin: const EdgeInsets.only(top: 14),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.1),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.redAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    warning, 
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildInputField(
    TextEditingController ctrl,
    String label,
    IconData icon,
    bool isDark, {
    String? hint,
    TextInputType type = TextInputType.text,
    int maxLines = 1,
    int? maxLength,
    bool isNumber = false,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? formatters,
  }) {
    List<TextInputFormatter> finalFormatters = [];
    if (isNumber) finalFormatters.add(FilteringTextInputFormatter.digitsOnly);
    if (formatters != null) finalFormatters.addAll(formatters);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: isDark ? Colors.blueGrey[300] : Colors.blueGrey[600]),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.grey[300] : Colors.grey[800],
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          keyboardType: type,
          maxLines: maxLines,
          maxLength: maxLength,
          textCapitalization: textCapitalization,
          inputFormatters: finalFormatters.isNotEmpty ? finalFormatters : null,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint ?? "Ingresar...",
            hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400], fontSize: 14),
            counterText: "",
            isDense: true,
            filled: true,
            fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100],
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark ? Colors.white10 : Colors.grey.shade300,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark ? Colors.white10 : Colors.grey.shade300,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: Colors.blue.withValues(alpha: 0.8),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 15,
        color: isDark ? Colors.blue[300] : Colors.blue[800],
        letterSpacing: 0.3,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        widget.isNew ? Icons.person_add : Icons.manage_accounts,
                        color: isDark ? Colors.blue[300] : Colors.blue[700],
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        widget.isNew ? "Nuevo Cliente" : "Editar Perfil",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: textColor, size: 26),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),

            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                children: [
                  _buildSectionTitle("Datos Principales", isDark),
                  const SizedBox(height: 14),
                  _buildInputField(
                    _nameCtrl,
                    "Nombre Completo / Razón Social *",
                    Icons.person,
                    isDark,
                    hint: "Ej: Juan Pérez / Librería Central",
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInputField(
                          _phoneCtrl,
                          "Celular",
                          Icons.phone,
                          isDark,
                          hint: "999 888 777",
                          type: TextInputType.phone,
                          formatters: [_PhoneNumberFormatter()],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _buildInputField(
                          _dniCtrl,
                          "DNI / RUC",
                          Icons.badge,
                          isDark,
                          hint: "8 u 11 dígitos",
                          type: TextInputType.number,
                          maxLength: 11,
                          isNumber: true,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 26),
                  _buildSectionTitle("Contacto y Ubicación", isDark),
                  const SizedBox(height: 14),
                  _buildInputField(
                    _emailCtrl,
                    "Correo Electrónico",
                    Icons.email,
                    isDark,
                    hint: "cliente@correo.com",
                    type: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    _addressCtrl,
                    "Dirección Completa",
                    Icons.location_on,
                    isDark,
                    hint: "Av. Principal 123, Distrito",
                    textCapitalization: TextCapitalization.words,
                  ),

                  const SizedBox(height: 26),
                  _buildSectionTitle("Nivel de Confianza", isDark),
                  const SizedBox(height: 14),
                  _buildConfidenceSelector(isDark),

                  const SizedBox(height: 26),
                  _buildSectionTitle("Perfilamiento CRM (Etiquetas)", isDark),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newTagCtrl,
                          textCapitalization: TextCapitalization.characters,
                          style: TextStyle(color: textColor, fontSize: 15),
                          decoration: InputDecoration(
                            hintText: "Ej: VIP, MAYORISTA...",
                            hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey),
                            isDense: true,
                            filled: true,
                            fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100],
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300),
                            ),
                          ),
                          onSubmitted: _addTag,
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () => _addTag(_newTagCtrl.text),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple[800],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("Agregar", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _suggestedTags.where((t) => !_currentTags.contains(t.toUpperCase())).map((tag) => ActionChip(
                      label: Text(
                        "+ $tag",
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.purple[200] : Colors.purple[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      backgroundColor: isDark ? Colors.purple.withValues(alpha: 0.12) : Colors.purple[50],
                      side: BorderSide(color: isDark ? Colors.purple.withValues(alpha: 0.3) : Colors.purple.shade200),
                      onPressed: () => _addTag(tag),
                    )).toList(),
                  ),

                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF14141C) : Colors.grey[50],
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
                    ),
                    child: _currentTags.isEmpty 
                      ? Text(
                          "No hay etiquetas asignadas",
                          style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey, fontStyle: FontStyle.italic, fontSize: 14),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _currentTags.map((tag) => Chip(
                            label: Text(
                              tag,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white : Colors.black87),
                            ),
                            backgroundColor: isDark ? Colors.purple.withValues(alpha: 0.3) : Colors.purple[100],
                            deleteIcon: Icon(Icons.cancel, size: 16, color: isDark ? Colors.purple[200] : Colors.black54),
                            onDeleted: () => _removeTag(tag),
                            side: BorderSide.none,
                          )).toList(),
                        ),
                  ),

                  const SizedBox(height: 26),
                  _buildSectionTitle("Notas Internas", isDark),
                  const SizedBox(height: 14),
                  _buildInputField(
                    _notesCtrl,
                    "Comentarios sobre el cliente",
                    Icons.note_alt,
                    isDark,
                    hint: "Ej: Preferencia de horarios, acuerdos de pago...",
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  
                  const SizedBox(height: InteractiveSheetWrapper.kModalScrollBottomClearance),
                ],
              ),
            ),

            Builder(
              builder: (bCtx) {
                final effectiveBottom = InteractiveSheetWrapper.getEffectiveBottomPadding(
                  bCtx,
                  minPadding: InteractiveSheetWrapper.kMinDefensiveBottomClearance,
                );
                return Container(
                  padding: EdgeInsets.fromLTRB(24, 14, 24, effectiveBottom),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[800],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isLoading 
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text(
                            "GUARDAR CLIENTE",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.8),
                          ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}