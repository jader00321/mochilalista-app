import 'package:flutter/material.dart';
import '../../models/crm_models.dart';
import 'manual_quote_institution_header.dart';
import 'manual_quote_client_header.dart';

class ManualQuoteHeadersSection extends StatelessWidget {
  final bool isDark;
  final Color surfaceColor;
  final Color textColor;
  final bool isGuest; // 🔥 FASE 4: Recibe si es invitado
  
  // Controles de expansión
  final bool isQuoteDataExpanded;
  final bool isClientPanelExpanded;
  final Function(bool) onQuoteDataExpansionChanged;
  final Function(bool) onClientPanelExpansionChanged;

  // Controladores de texto - Cotización
  final TextEditingController quoteTitleCtrl;
  final TextEditingController quoteNotesCtrl;

  // Controladores de texto - Institución
  final TextEditingController schoolCtrl;
  final TextEditingController gradeCtrl;

  // Controladores y datos - Cliente
  final ClientModel? selectedClient;
  final TextEditingController clientNameCtrl;
  final TextEditingController clientPhoneCtrl;
  final TextEditingController clientDniCtrl;
  final TextEditingController clientAddressCtrl;
  final TextEditingController clientEmailCtrl;
  final TextEditingController clientNotesCtrl;
  
  final bool isNewClientMode;
  final Function(bool?) onNewClientModeChanged;
  final VoidCallback onSearchClientTap;
  final VoidCallback onClearClient;

  const ManualQuoteHeadersSection({
    super.key,
    required this.isDark,
    required this.surfaceColor,
    required this.textColor,
    required this.isGuest,
    required this.isQuoteDataExpanded,
    required this.isClientPanelExpanded,
    required this.onQuoteDataExpansionChanged,
    required this.onClientPanelExpansionChanged,
    required this.quoteTitleCtrl,
    required this.quoteNotesCtrl,
    required this.schoolCtrl,
    required this.gradeCtrl,
    required this.selectedClient,
    required this.clientNameCtrl,
    required this.clientPhoneCtrl,
    required this.clientDniCtrl,
    required this.clientAddressCtrl,
    required this.clientEmailCtrl,
    required this.clientNotesCtrl,
    required this.isNewClientMode,
    required this.onNewClientModeChanged,
    required this.onSearchClientTap,
    required this.onClearClient,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: surfaceColor,
          child: Column(
            children: [
              // 🔥 SECCIÓN 1: Título y Notas de la Cotización
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: isQuoteDataExpanded,
                  iconColor: isDark ? Colors.blue[300] : Colors.blue[800],
                  collapsedIconColor: isDark ? Colors.grey[400] : Colors.grey,
                  title: Text(
                    "Identificación de la Cotización", 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)
                  ),
                  subtitle: Text(
                    "Nombre de la lista y notas internas", 
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[500] : Colors.grey)
                  ),
                  onExpansionChanged: onQuoteDataExpansionChanged,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: quoteTitleCtrl,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                            decoration: InputDecoration(
                              labelText: "Nombre / Título de la Cotización",
                              labelStyle: TextStyle(color: isDark ? Colors.blue[300] : Colors.blue[700]),
                              prefixIcon: Icon(Icons.description, color: isDark ? Colors.blue[300] : Colors.blue),
                              filled: true,
                              fillColor: isDark ? Colors.blue.withOpacity(0.05) : Colors.blue.shade50,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: quoteNotesCtrl,
                            style: TextStyle(fontSize: 14, color: textColor),
                            maxLines: 2,
                            minLines: 1,
                            decoration: InputDecoration(
                              labelText: "Notas de Cotización (Opcional)",
                              labelStyle: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                              prefixIcon: Icon(Icons.sticky_note_2_outlined, color: isDark ? Colors.grey[400] : Colors.grey),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF14141C) : Colors.grey[100],
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),

              // 🔥 SECCIÓN 2: Datos del Cliente y Colegio
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: isClientPanelExpanded,
                  iconColor: isDark ? Colors.blue[300] : Colors.blue[800],
                  collapsedIconColor: isDark ? Colors.grey[400] : Colors.grey,
                  title: Text(
                    "Datos del Cliente y Colegio", 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)
                  ),
                  subtitle: Text(
                    "Toca para desplegar y editar", 
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[500] : Colors.grey)
                  ),
                  onExpansionChanged: onClientPanelExpansionChanged,
                  children: [
                    ManualQuoteInstitutionHeader(
                      schoolCtrl: schoolCtrl,
                      gradeCtrl: gradeCtrl,
                      isDark: isDark,
                    ),
                    ManualQuoteClientHeader(
                      selectedClient: selectedClient,
                      nameCtrl: clientNameCtrl,
                      phoneCtrl: clientPhoneCtrl,
                      dniCtrl: clientDniCtrl,
                      addressCtrl: clientAddressCtrl,
                      emailCtrl: clientEmailCtrl,
                      notesCtrl: clientNotesCtrl,
                      isNewClientMode: isNewClientMode,
                      isDark: isDark,
                      isGuest: isGuest, // 🔥 Pasamos si es invitado
                      onNewClientModeChanged: onNewClientModeChanged,
                      onSearchClientTap: onSearchClientTap,
                      onClearClient: onClearClient,
                    ),
                    const SizedBox(height: 10)
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
        const SizedBox(height: 16), 
      ],
    );
  }
}