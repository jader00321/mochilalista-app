import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:app_movil/core/providers/auth_provider.dart';
import 'package:app_movil/features/smart_quotation/services/client_service.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/core/widgets/interactive_sheet_wrapper.dart';

/// 🏆 MODAL UNIFICADO DE BÚSQUEDA DE CLIENTES (Mobile Awards Standard)
/// Diseñado con aislamiento total de estado (cero búsquedas pegajosas entre ventanas),
/// motor de búsqueda multi-palabra con tolerancia a tildes (_sqlUnaccent) y
/// tarjetas responsivas con separación física garantizada (anti-colisiones).
class ClientSearchModal extends StatefulWidget {
  final Function(ClientModel) onClientSelected;

  const ClientSearchModal({super.key, required this.onClientSelected});

  /// 🏆 Despliegue seguro con InteractiveSheetWrapper (Swipe down to dismiss + Blindaje BUG-07)
  static Future<ClientModel?> show(
    BuildContext context, {
    required Function(ClientModel) onClientSelected,
  }) {
    return InteractiveSheetWrapper.show<ClientModel>(
      context: context,
      builder: (_) => ClientSearchModal(onClientSelected: onClientSelected),
    );
  }

  @override
  State<ClientSearchModal> createState() => _ClientSearchModalState();
}

class _ClientSearchModalState extends State<ClientSearchModal> {
  final TextEditingController _ctrl = TextEditingController();
  final ClientService _clientService = ClientService();
  Timer? _debounce;

  List<ClientModel> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecentClients();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _loadRecentClients() async {
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    if (authProv.activeBusinessId == null) return;

    if (mounted) setState(() => _isLoading = true);
    final clients = await _clientService.getRecentClients(authProv.activeBusinessId!, limit: 10);
    if (!mounted) return;

    setState(() {
      _results = clients.where((c) => !c.fullName.startsWith("Caja Rápida -")).toList();
      _isLoading = false;
      _hasSearched = false;
    });
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      _performSearch(val.trim());
    });
  }

  void _performSearch(String query) async {
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    if (authProv.activeBusinessId == null) return;

    if (query.isEmpty) {
      _loadRecentClients();
      return;
    }

    if (mounted) setState(() => _isLoading = true);
    final clients = await _clientService.searchClients(query, authProv.activeBusinessId!);
    if (!mounted) return;

    setState(() {
      _results = clients.where((c) => !c.fullName.startsWith("Caja Rápida -")).toList();
      _isLoading = false;
      _hasSearched = true;
    });
  }

  String _formatPhone(String phone) {
    String clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.length == 9) {
      return "${clean.substring(0, 3)} ${clean.substring(3, 6)} ${clean.substring(6, 9)}";
    }
    return phone;
  }

  void _selectAndClose(ClientModel client) {
    widget.onClientSelected(client);
    Navigator.pop(context, client);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');
    final primaryColor = isDark ? const Color(0xFF64B5F6) : const Color(0xFF1976D2);

    return InteractiveSheetWrapper(
      maxHeightFactor: 0.92,
      backgroundColor: isDark ? const Color(0xFF1E1E2A) : Colors.white,
      applyEffectiveBottomPadding: true,
      child: Column(
        children: [
          // Header del Modal
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person_search_rounded, color: primaryColor, size: 26),
                        const SizedBox(width: 10),
                        Text(
                          "Directorio de Clientes",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: isDark ? Colors.white70 : Colors.black54),
                      onPressed: () => Navigator.pop(context),
                      tooltip: "Cerrar",
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _ctrl,
                  autofocus: false,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: "Buscar por nombre, teléfono, DNI o notas...",
                    hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[600], fontSize: 14),
                    prefixIcon: Icon(Icons.search_rounded, color: primaryColor),
                    suffixIcon: _ctrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 20),
                            onPressed: () {
                              _ctrl.clear();
                              _loadRecentClients();
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onChanged: _onSearchChanged,
                ),
              ],
            ),
          ),

          // Indicador de filtro / subtítulo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Icon(
                  _hasSearched ? Icons.filter_alt_outlined : Icons.history_rounded,
                  size: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
                const SizedBox(width: 6),
                Text(
                  _hasSearched
                      ? "Resultados de búsqueda (${_results.length})"
                      : "Clientes agregados recientemente",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Lista de Resultados
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty && _hasSearched
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_off_outlined, size: 60, color: isDark ? Colors.white24 : Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text(
                                "No encontramos a '${_ctrl.text}'",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Puedes utilizarlo como cliente de paso o registrarlo rápidamente.",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 18),
                              ElevatedButton.icon(
                                onPressed: () {
                                  final query = _ctrl.text.trim();
                                  final isDigits = RegExp(r'^[0-9]+$').hasMatch(query);
                                  final quickClient = ClientModel(
                                    id: 0,
                                    negocioId: 0,
                                    creadoPorUsuarioId: 0,
                                    fullName: isDigits ? "Cliente Paso" : query,
                                    phone: isDigits ? query : "",
                                    registeredDate: DateTime.now().toIso8601String(),
                                  );
                                  _selectAndClose(quickClient);
                                },
                                icon: const Icon(Icons.flash_on_rounded, size: 18),
                                label: const Text("Usar como Cliente de Paso"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _results.isEmpty
                        ? Center(
                            child: Text(
                              "No hay clientes registrados en este negocio.",
                              style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: _results.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final c = _results[index];
                              return _buildClientCard(context, c, isDark, currency, primaryColor);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientCard(
    BuildContext context,
    ClientModel c,
    bool isDark,
    NumberFormat currency,
    Color primaryColor,
  ) {
    final hasDebt = c.totalDebt > 0;
    final hasSaldo = c.saldoAFavor > 0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252536) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasDebt
              ? (isDark ? Colors.redAccent.withValues(alpha: 0.3) : Colors.red.shade200)
              : (isDark ? Colors.white10 : Colors.grey.shade200),
          width: hasDebt ? 1.2 : 1.0,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _selectAndClose(c),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fila Superior: Avatar + Nombre + Badge APP
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: isDark
                          ? primaryColor.withValues(alpha: 0.2)
                          : primaryColor.withValues(alpha: 0.12),
                      child: Text(
                        c.fullName.isNotEmpty ? c.fullName[0].toUpperCase() : "?",
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
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
                              Expanded(
                                child: Text(
                                  c.fullName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (c.usuarioVinculadoId != null)
                                Container(
                                  margin: const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.teal.withValues(alpha: 0.4)),
                                  ),
                                  child: const Text(
                                    "APP",
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.teal),
                                  ),
                                ),
                            ],
                          ),
                          if (c.docNumber != null && c.docNumber!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Row(
                                children: [
                                  Icon(Icons.badge_outlined, size: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    "DNI/RUC: ${c.docNumber}",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // Fila Media: Teléfono y Dirección
                Row(
                  children: [
                    if (c.phone.isNotEmpty) ...[
                      Icon(Icons.phone_iphone_rounded, size: 14, color: isDark ? Colors.grey[400] : Colors.grey[700]),
                      const SizedBox(width: 4),
                      Text(
                        _formatPhone(c.phone),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.grey[300] : Colors.grey[800],
                        ),
                      ),
                    ],
                    if (c.address != null && c.address!.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.location_on_outlined, size: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          c.address!,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 10),

                // Fila Inferior: Badges Financieros + Botón Asignar (Garantía física anti-colisiones)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Badges independientes de Deuda y Saldo a Favor
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (hasDebt)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.arrow_downward_rounded, size: 12, color: Colors.redAccent),
                                  const SizedBox(width: 4),
                                  Text(
                                    "Deuda: -${currency.format(c.totalDebt)}",
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (hasSaldo)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E676).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.savings_outlined, size: 12, color: Color(0xFF00E676)),
                                  const SizedBox(width: 4),
                                  Text(
                                    "A favor: +${currency.format(c.saldoAFavor)}",
                                    style: const TextStyle(
                                      color: Color(0xFF00E676),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Botón Asignar Ergonómico
                    ElevatedButton.icon(
                      onPressed: () => _selectAndClose(c),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: const Text(
                        "Asignar",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}