import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/services/client_service.dart';

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

class ClientBottomSheet extends StatefulWidget {
  const ClientBottomSheet({super.key});

  @override
  State<ClientBottomSheet> createState() => _ClientBottomSheetState();
}

class _ClientBottomSheetState extends State<ClientBottomSheet> with TickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  List<ClientModel> _searchResults = [];
  bool _isSearching = false;
  bool _isLoadingRecent = false;
  Timer? _debounce;

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dniCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _notesCtrl = TextEditingController(); 

  late TabController _tabController;
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _nameFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChange);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecentClients();
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == 0) {
      _nameFocusNode.unfocus();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _searchFocusNode.requestFocus();
      });
    } else {
      _searchFocusNode.unfocus();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _nameFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabController.dispose();
    _searchFocusNode.dispose();
    _nameFocusNode.dispose();
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _dniCtrl.dispose();
    _addressCtrl.dispose();
    _emailCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _loadRecentClients() async {
    setState(() => _isLoadingRecent = true);
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    if (authProv.activeBusinessId != null) {
      final results = await ClientService().getRecentClients(authProv.activeBusinessId!);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoadingRecent = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoadingRecent = false);
    }
  }

  void _search(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final q = query.trim();
      if (q.isEmpty) {
        _loadRecentClients();
        return;
      }
      final authProv = Provider.of<AuthProvider>(context, listen: false);
      final negocioId = authProv.activeBusinessId;
      if (negocioId == null) return;

      setState(() => _isSearching = true);
      final results = await ClientService().searchClients(q, negocioId);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    });
  }

  void _returnNewClient() {
    if (!_formKey.currentState!.validate()) return;

    // 🔥 CORRECCIÓN APLICADA AQUÍ: Se inyectan los parámetros requeridos
    final tempClient = ClientModel(
      id: -1, 
      negocioId: 0, // Dato temporal, el backend asigna el real
      creadoPorUsuarioId: 0, // Dato temporal
      fullName: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.replaceAll(' ', '').trim(), 
      docNumber: _dniCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      registeredDate: DateTime.now().toIso8601String(),
    );

    Navigator.pop(context, tempClient);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF23232F) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85, 
      padding: EdgeInsets.fromLTRB(0, 24, 0, bottomInset),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(width: 50, height: 5, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: isDark ? Colors.white24 : Colors.grey[300], borderRadius: BorderRadius.circular(10))),
          Text("Gestión de Clientes", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 16),
          
          TabBar(
            controller: _tabController,
            labelColor: isDark ? Colors.blue[300] : Colors.blue[800],
            unselectedLabelColor: isDark ? Colors.grey[500] : Colors.grey,
            indicatorColor: isDark ? Colors.blue[300] : Colors.blue[800],
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            tabs: const [
              Tab(icon: Icon(Icons.search), text: "Buscar Existente"),
              Tab(icon: Icon(Icons.person_add), text: "Crear Nuevo"),
            ],
          ),
          
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // --- TAB 1: BUSCAR ---
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchCtrl,
                        focusNode: _searchFocusNode,
                        style: TextStyle(color: textColor, fontSize: 16),
                          decoration: InputDecoration(
                            hintText: "Buscar por nombre o celular...",
                            hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey),
                            prefixIcon: Icon(Icons.search, color: isDark ? Colors.blue[300] : Colors.blue),
                            filled: true, fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100],
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                            suffixIcon: _isSearching ? Transform.scale(scale: 0.5, child: const CircularProgressIndicator()) : null
                          ),
                          onChanged: _search,
                        ),
                        const SizedBox(height: 20),
                      Expanded(
                        child: _isLoadingRecent 
                          ? const Center(child: CircularProgressIndicator())
                          : _searchResults.isEmpty && _searchCtrl.text.isEmpty
                            ? Center(child: Text("Busca un cliente para asignarlo", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 16)))
                            : _searchResults.isEmpty && _searchCtrl.text.isNotEmpty
                              ? Center(child: Text("No se encontraron coincidencias", style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 16)))
                              : ListView.separated(
                                  itemCount: _searchResults.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (ctx, i) {
                                    final c = _searchResults[i];
                                    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
                                    final hasDebt = c.totalDebt > 0;
                                    final hasSaldo = c.saldoAFavor > 0;

                                    return Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () => Navigator.pop(context, c),
                                        borderRadius: BorderRadius.circular(14),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF1B1B26) : Colors.grey[50],
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(
                                              color: isDark ? Colors.white12 : Colors.grey.shade200,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  CircleAvatar(
                                                    backgroundColor: isDark ? Colors.blue.withValues(alpha: 0.25) : Colors.blue.shade100,
                                                    radius: 20,
                                                    child: Text(
                                                      c.fullName.isNotEmpty ? c.fullName[0].toUpperCase() : "?",
                                                      style: TextStyle(
                                                        color: isDark ? Colors.blue[300] : Colors.blue[800],
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Flexible(
                                                              child: Text(
                                                                c.fullName,
                                                                style: TextStyle(
                                                                  fontWeight: FontWeight.bold,
                                                                  fontSize: 15,
                                                                  color: textColor,
                                                                ),
                                                                maxLines: 1,
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                            ),
                                                            if (c.usuarioVinculadoId != null) ...[
                                                              const SizedBox(width: 6),
                                                              Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                                decoration: BoxDecoration(
                                                                  color: Colors.teal.withValues(alpha: 0.15),
                                                                  borderRadius: BorderRadius.circular(4),
                                                                  border: Border.all(color: Colors.teal.withValues(alpha: 0.5)),
                                                                ),
                                                                child: const Text("APP", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.teal)),
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                        const SizedBox(height: 3),
                                                        Row(
                                                          children: [
                                                            Icon(Icons.phone_android, size: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                                            const SizedBox(width: 4),
                                                            Text(
                                                              c.phone.isNotEmpty ? c.phone : "Sin teléfono",
                                                              style: TextStyle(
                                                                fontSize: 13,
                                                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                                              ),
                                                            ),
                                                            if (c.docNumber != null && c.docNumber!.isNotEmpty) ...[
                                                              const SizedBox(width: 8),
                                                              Icon(Icons.badge_outlined, size: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                                              const SizedBox(width: 4),
                                                              Text(
                                                                c.docNumber!,
                                                                style: TextStyle(
                                                                  fontSize: 12,
                                                                  fontWeight: FontWeight.w500,
                                                                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                                                                ),
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF00C853),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: const Text(
                                                      "Asignar",
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              if (hasSaldo || hasDebt) ...[
                                                const SizedBox(height: 8),
                                                Wrap(
                                                  spacing: 8,
                                                  runSpacing: 4,
                                                  children: [
                                                    if (hasSaldo)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFF00E676).withValues(alpha: 0.15),
                                                          borderRadius: BorderRadius.circular(6),
                                                          border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.4)),
                                                        ),
                                                        child: Text(
                                                          "Saldo a favor: ${currency.format(c.saldoAFavor)}",
                                                          style: const TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.bold,
                                                            color: Color(0xFF00C853),
                                                          ),
                                                        ),
                                                      ),
                                                    if (hasDebt)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFFF5252).withValues(alpha: 0.15),
                                                          borderRadius: BorderRadius.circular(6),
                                                          border: Border.all(color: const Color(0xFFFF5252).withValues(alpha: 0.4)),
                                                        ),
                                                        child: Text(
                                                          "Deuda pendiente: ${currency.format(c.totalDebt)}",
                                                          style: const TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.bold,
                                                            color: Color(0xFFFF5252),
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                      )
                      ],
                    ),
                  ),

                  // --- TAB 2: CREAR ---
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          _buildTextField(
                            controller: _nameCtrl, 
                            focusNode: _nameFocusNode,
                            label: "Nombre Completo *", 
                            icon: Icons.person, 
                            isDark: isDark, 
                            validator: (v) => (v == null || v.length < 3) ? "Requerido" : null
                          ),
                          const SizedBox(height: 16),
                          
                          _buildTextField(
                            controller: _phoneCtrl, 
                            label: "Celular (9 dígitos) *", 
                            icon: Icons.phone, 
                            inputType: TextInputType.phone, 
                            isDark: isDark, 
                            formatters: [_PhoneNumberFormatter()],
                            validator: (v) => (v == null || v.replaceAll(' ', '').length < 9) ? "Debe tener 9 dígitos" : null
                          ),
                          const SizedBox(height: 16),
                          
                          _buildTextField(controller: _dniCtrl, label: "DNI / RUC (Opcional)", icon: Icons.badge, inputType: TextInputType.number, isDark: isDark),
                          const SizedBox(height: 16),
                          _buildTextField(controller: _addressCtrl, label: "Dirección (Opcional)", icon: Icons.location_on, isDark: isDark),
                          const SizedBox(height: 16),
                          _buildTextField(controller: _notesCtrl, label: "Notas / Detalles (Opcional)", icon: Icons.note_alt, maxLines: 2, isDark: isDark),
                          const SizedBox(height: 30),
                          
                          SizedBox(
                            width: double.infinity, height: 60,
                            child: ElevatedButton(
                              onPressed: _returnNewClient, 
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                              child: const Text("Asignar para la Venta", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller, 
    required String label, 
    required IconData icon, 
    required bool isDark, 
    TextInputType inputType = TextInputType.text, 
    String? Function(String?)? validator, 
    FocusNode? focusNode,
    int maxLines = 1,
    List<TextInputFormatter>? formatters,
  }) {
    return TextFormField(
      controller: controller, 
      focusNode: focusNode,
      keyboardType: inputType, 
      validator: validator, 
      maxLines: maxLines,
      inputFormatters: formatters,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.5),
      decoration: InputDecoration(
        labelText: label, 
        labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 15),
        prefixIcon: Icon(icon, color: isDark ? Colors.blueGrey[300] : Colors.blueGrey, size: 22),
        filled: true,
        fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100],
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), 
        isDense: true,
      ),
    );
  }
}