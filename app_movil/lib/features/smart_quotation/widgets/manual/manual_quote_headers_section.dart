import 'package:flutter/material.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';
import 'package:app_movil/features/smart_quotation/widgets/manual/manual_quote_institution_header.dart';
import 'package:app_movil/features/smart_quotation/widgets/manual/manual_quote_client_header.dart';
import 'package:app_movil/core/widgets/morphing_accordion.dart';

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
    final titleText = quoteTitleCtrl.text.trim();
    final clientDisplayName = selectedClient?.fullName ?? clientNameCtrl.text.trim();
    final schoolText = schoolCtrl.text.trim();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            children: [
              // 🪗 SECCIÓN 1: Identificación con MorphingAccordion
              MorphingAccordion(
                title: "Identificación de Cotización",
                icon: Icons.description_outlined,
                iconColor: isDark ? Colors.blue[300] : Colors.blue[800],
                initialExpanded: isQuoteDataExpanded,
                onExpansionChanged: onQuoteDataExpansionChanged,
                summaryBadge: titleText.isNotEmpty
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.blue[900]!.withValues(alpha: 0.3) : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          titleText.length > 20 ? '${titleText.substring(0, 18)}...' : titleText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.blue[200] : Colors.blue[800],
                          ),
                        ),
                      )
                    : null,
                content: Padding(
                  padding: const EdgeInsets.only(top: 8),
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
                          fillColor: isDark ? Colors.blue.withValues(alpha: 0.05) : Colors.blue.shade50,
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
              ),

              const SizedBox(height: 8),

              // 🪗 SECCIÓN 2: Cliente y Colegio con MorphingAccordion
              MorphingAccordion(
                title: "Cliente y Colegio",
                icon: Icons.school_outlined,
                iconColor: isDark ? Colors.green[300] : Colors.green[800],
                initialExpanded: isClientPanelExpanded,
                onExpansionChanged: onClientPanelExpansionChanged,
                summaryBadge: (clientDisplayName.isNotEmpty || schoolText.isNotEmpty)
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.green[900]!.withValues(alpha: 0.3) : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          clientDisplayName.isNotEmpty
                              ? (clientDisplayName.length > 16 ? '${clientDisplayName.substring(0, 14)}...' : clientDisplayName)
                              : schoolText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.green[300] : Colors.green[800],
                          ),
                        ),
                      )
                    : null,
                content: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
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
                        isGuest: isGuest,
                        onNewClientModeChanged: onNewClientModeChanged,
                        onSearchClientTap: onSearchClientTap,
                        onClearClient: onClearClient,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
        const SizedBox(height: 8),
      ],
    );
  }
}