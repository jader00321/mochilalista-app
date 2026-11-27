part of '../loyalty_whatsapp_service.dart';

Future<void> _showEditableWhatsAppPreviewModalImpl({
  required BuildContext context,
  required String title,
  required String phone,
  required String initialMessage,
  LoyaltyRulesModel? rules,
  List<RewardGoalModel>? activeGoals,
  String? businessName,
  String? clientName,
  int? puntosActuales,
  List<ClientModel>? availableClients,
  String? businessAddress,
  String? businessPhone,
  VoidCallback? onSent,
}) async {
  final msgCtrl = TextEditingController(text: initialMessage);
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  final bgColor = isDark ? const Color(0xFF1E1E2A) : Colors.white;
  final cardBg = isDark ? const Color(0xFF282838) : const Color(0xFFF8FAFC);
  final textColor = isDark ? Colors.white : const Color(0xFF1E293B);

  final effectiveBottom = InteractiveSheetWrapper.getEffectiveBottomPadding(
    context,
    minPadding: InteractiveSheetWrapper.kMinDefensiveBottomClearance,
  );

  // Estado local de personalización
  String currentFormat = 'COMPLETO'; // 'COMPLETO', 'RESUMEN', 'PROMO'
  bool secRules = true;
  bool secCatalog = true;
  bool secStore = true;
  ClientModel? selectedClient;
  String currentPhone = phone;
  String? currentClientName = clientName;
  int? currentPuntos = puntosActuales;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) {
        void updateMessageText([String? newFormat]) {
          if (newFormat != null) currentFormat = newFormat;
          if (rules != null && activeGoals != null && businessName != null) {
            if (currentFormat == 'COMPLETO') {
              msgCtrl.text =
                  LoyaltyWhatsAppService.buildLoyaltyGuideAndCatalogMessage(
                    businessName: businessName,
                    rules: rules,
                    activeGoals: activeGoals,
                    clientName: currentClientName,
                    puntosActuales: currentPuntos,
                    includeRules: secRules,
                    includeCatalog: secCatalog,
                    includeStoreInfo: secStore,
                    businessAddress: businessAddress,
                    businessPhone: businessPhone,
                  );
            } else if (currentFormat == 'RESUMEN') {
              msgCtrl.text = LoyaltyWhatsAppService.buildSummaryGuideMessage(
                businessName: businessName,
                rules: rules,
                activeGoals: activeGoals,
                clientName: currentClientName,
                puntosActuales: currentPuntos,
              );
            } else if (currentFormat == 'PROMO') {
              msgCtrl.text = LoyaltyWhatsAppService.buildPromoInviteMessage(
                businessName: businessName,
                activeGoals: activeGoals,
                clientName: currentClientName,
                puntosActuales: currentPuntos,
              );
            }
          }
        }

        final bool hasActivePhone =
            currentPhone.trim().isNotEmpty &&
            currentPhone.trim() != '000000000';

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(ctx).unfocus(),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.90,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: SafeArea(
              top: false,
              bottom: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(18, 14, 18, effectiveBottom),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Asa superior
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Encabezado
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF25D366,
                            ).withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.chat_bubble_rounded,
                            color: Color(0xFF25D366),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                hasActivePhone
                                    ? "Destino WhatsApp: $currentPhone"
                                    : "Compartir cartilla con clientes",
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (availableClients != null &&
                        availableClients.isNotEmpty &&
                        (phone.trim().isEmpty || phone.trim() == '000000000'))
                      _buildPreviewClientSelector(
                        availableClients: availableClients,
                        selectedClient: selectedClient,
                        isDark: isDark,
                        textColor: textColor,
                        onChanged: (newId) {
                          setModalState(() {
                            if (newId == null) {
                              selectedClient = null;
                              currentClientName = null;
                              currentPuntos = null;
                              currentPhone = "";
                            } else {
                              selectedClient = availableClients.firstWhere(
                                (c) => c.id == newId,
                              );
                              currentClientName = selectedClient!.fullName;
                              currentPuntos = selectedClient!.puntosActuales;
                              currentPhone = selectedClient!.phone;
                            }
                            updateMessageText();
                          });
                        },
                      ),

                    if (rules != null &&
                        activeGoals != null &&
                        businessName != null) ...[
                      _buildPreviewFormatToolbar(
                        currentFormat: currentFormat,
                        secRules: secRules,
                        secCatalog: secCatalog,
                        secStore: secStore,
                        isDark: isDark,
                        onFormatSelected: (fmt) =>
                            setModalState(() => updateMessageText(fmt)),
                        onToggleRules: (val) => setModalState(() {
                          secRules = val;
                          updateMessageText();
                        }),
                        onToggleCatalog: (val) => setModalState(() {
                          secCatalog = val;
                          updateMessageText();
                        }),
                        onToggleStore: (val) => setModalState(() {
                          secStore = val;
                          updateMessageText();
                        }),
                        onRestore: () {
                          setModalState(() {
                            secRules = true;
                            secCatalog = true;
                            secStore = true;
                            updateMessageText('COMPLETO');
                          });
                          LoyaltyToastFeedback.showInfo(
                            ctx,
                            "Mensaje restaurado al formato original",
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                    ],

                    // Campo de texto editable
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? Colors.white12
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: TextFormField(
                          controller: msgCtrl,
                          maxLines: null,
                          expands: true,
                          onTapOutside: (_) => FocusScope.of(ctx).unfocus(),
                          style: TextStyle(
                            fontSize: 13,
                            color: textColor,
                            height: 1.4,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    _buildPreviewBottomActions(
                      hostContext: context,
                      modalContext: ctx,
                      msgCtrl: msgCtrl,
                      hasActivePhone: hasActivePhone,
                      currentPhone: currentPhone,
                      businessName: businessName,
                      isDark: isDark,
                      onSent: onSent,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
