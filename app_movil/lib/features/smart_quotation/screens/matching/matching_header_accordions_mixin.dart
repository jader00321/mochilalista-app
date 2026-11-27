part of '../matching_screen.dart';

mixin _MatchingHeaderAccordionsMixin on _MatchingScreenBase {
  @override
  Future<void> _expandClientPanelForTour() async {
    if (!mounted) return;
    _clientExpandedBeforeTour ??= _isClientPanelExpanded;
    if (!_isClientPanelExpanded) {
      setState(() => _isClientPanelExpanded = true);
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  @override
  Future<void> _restoreClientPanelAfterTour() async {
    final prev = _clientExpandedBeforeTour;
    _clientExpandedBeforeTour = null;
    if (!mounted) return;
    if (prev != null && _isClientPanelExpanded != prev) {
      setState(() => _isClientPanelExpanded = prev);
      await Future.delayed(const Duration(milliseconds: 280));
    }
  }

  @override
  Future<void> _expandQuoteDataForTour() async {
    if (!mounted) return;
    _quoteExpandedBeforeTour ??= _isQuoteDataExpanded;
    if (!_isQuoteDataExpanded) {
      setState(() => _isQuoteDataExpanded = true);
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  @override
  Future<void> _restoreQuoteDataAfterTour() async {
    final prev = _quoteExpandedBeforeTour;
    _quoteExpandedBeforeTour = null;
    if (!mounted) return;
    if (prev != null && _isQuoteDataExpanded != prev) {
      setState(() => _isQuoteDataExpanded = prev);
      await Future.delayed(const Duration(milliseconds: 280));
    }
  }

  Widget _buildEditableHeader(
    MatchingProvider provider,
    bool isDark,
    TextTheme theme,
    bool isGuest,
    bool isClient,
  ) {
    final titleText = _quoteTitleCtrl.text.trim();
    final clientDisplayName =
        provider.selectedClient?.fullName ?? _clientNameCtrl.text.trim();
    final schoolText = _schoolCtrl.text.trim();

    return Container(
      color: isDark ? const Color(0xFF14141C) : Colors.grey[50],
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        children: [
          KeyedSubtree(
            key: _tourKeys.quoteNotesAccordionKey,
            child: MorphingAccordion(
              title: "Identificación de Cotización",
              icon: Icons.description_outlined,
              iconColor: isDark ? Colors.blue[300] : Colors.blue[800],
              initialExpanded: _isQuoteDataExpanded,
              onExpansionChanged: (val) =>
                  setState(() => _isQuoteDataExpanded = val),
              summaryBadge: titleText.isNotEmpty
                  ? _buildAccordionSummaryBadge(
                      label: titleText.length > 20
                          ? '${titleText.substring(0, 18)}...'
                          : titleText,
                      bgColor: isDark
                          ? Colors.blue[900]!.withValues(alpha: 0.3)
                          : Colors.blue.shade50,
                      textColor: isDark ? Colors.blue[200]! : Colors.blue[800]!,
                    )
                  : null,
              content: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _quoteTitleCtrl,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        labelText: "Nombre / Título de la Cotización",
                        labelStyle: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.blue[300] : Colors.blue[800],
                        ),
                        floatingLabelBehavior: FloatingLabelBehavior.auto,
                        prefixIcon: Icon(
                          Icons.description,
                          color: isDark ? Colors.blue[300] : Colors.blue,
                        ),
                        suffixIcon: !_isAutoTitleMode
                            ? IconButton(
                                icon: const Icon(Icons.restore_outlined),
                                color: isDark
                                    ? Colors.amber[300]
                                    : Colors.orange[800],
                                tooltip: "Restaurar nombre automático",
                                onPressed: _restoreAutoTitle,
                              )
                            : Tooltip(
                                message: "Nombre dinámico sincronizado",
                                child: Icon(
                                  Icons.auto_awesome,
                                  size: 18,
                                  color: isDark
                                      ? Colors.blue[300]
                                      : Colors.blue[600],
                                ),
                              ),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF14141C)
                            : Colors.blue.withValues(alpha: 0.05),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 15,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.white12
                                : Colors.grey.shade300,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.white10
                                : Colors.grey.shade300,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.blue[300]!
                                : Colors.blue[700]!,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _quoteNotesCtrl,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 2,
                      minLines: 1,
                      decoration: InputDecoration(
                        labelText: "Notas de Cotización (Opcional)",
                        labelStyle: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        floatingLabelBehavior: FloatingLabelBehavior.auto,
                        prefixIcon: Icon(
                          Icons.sticky_note_2_outlined,
                          color: isDark ? Colors.grey[400] : Colors.grey,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF14141C)
                            : Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.white12
                                : Colors.grey.shade300,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.white10
                                : Colors.grey.shade300,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.blue[300]!
                                : Colors.blue[700]!,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          KeyedSubtree(
            key: _tourKeys.clientAccordionKey,
            child: _buildClientAndModeAccordion(
              provider: provider,
              isDark: isDark,
              isGuest: isGuest,
              isClient: isClient,
              clientDisplayName: clientDisplayName,
              schoolText: schoolText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccordionSummaryBadge({
    required String label,
    required Color bgColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildClientAndModeAccordion({
    required MatchingProvider provider,
    required bool isDark,
    required bool isGuest,
    required bool isClient,
    required String clientDisplayName,
    required String schoolText,
  }) {
    final mode = _currentMode;
    final String accordionTitle;
    final IconData accordionIcon;
    switch (mode) {
      case QuotationContextMode.general:
        accordionTitle = isClient
            ? "Mis Datos de Pedido"
            : "Datos del Cliente y Pedido";
        accordionIcon = Icons.shopping_bag_outlined;
        break;
      case QuotationContextMode.wholesale:
        accordionTitle = isClient
            ? "Mis Datos de Negocio"
            : "Datos del Cliente y Negocio";
        accordionIcon = Icons.storefront_rounded;
        break;
      case QuotationContextMode.school:
        accordionTitle = isClient
            ? "Mis Datos y Colegio"
            : "Datos del Cliente y Colegio";
        accordionIcon = Icons.school_outlined;
        break;
    }

    final badgeRaw = clientDisplayName.isNotEmpty
        ? clientDisplayName
        : schoolText;

    return MorphingAccordion(
      title: accordionTitle,
      icon: accordionIcon,
      iconColor: isDark ? Colors.amber[300] : Colors.orange[800],
      initialExpanded: _isClientPanelExpanded,
      onExpansionChanged: (val) => setState(() => _isClientPanelExpanded = val),
      summaryBadge: badgeRaw.isNotEmpty
          ? _buildAccordionSummaryBadge(
              label: badgeRaw.length > 15
                  ? '${badgeRaw.substring(0, 13)}...'
                  : badgeRaw,
              bgColor: isDark
                  ? Colors.orange[900]!.withValues(alpha: 0.3)
                  : Colors.orange.shade50,
              textColor: isDark ? Colors.orange[200]! : Colors.orange[900]!,
            )
          : null,
      content: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          children: [
            _buildModeSelectorBar(provider, isDark),
            ManualQuoteInstitutionHeader(
              schoolCtrl: _schoolCtrl,
              gradeCtrl: _gradeCtrl,
              isDark: isDark,
              mode: _currentMode,
            ),
            const SizedBox(height: 10),
            ManualQuoteClientHeader(
              selectedClient: provider.selectedClient,
              nameCtrl: _clientNameCtrl,
              phoneCtrl: _clientPhoneCtrl,
              dniCtrl: _clientDniCtrl,
              addressCtrl: _clientAddressCtrl,
              emailCtrl: _clientEmailCtrl,
              notesCtrl: _clientNotesCtrl,
              isNewClientMode: _updateClientData,
              isDark: isDark,
              isGuest: isGuest,
              onNewClientModeChanged: (v) {
                setState(() {
                  _updateClientData = v ?? false;
                });
                _updateHeader();
              },
              onSearchClientTap: isClient
                  ? () => AppFeedbackHelper.showInfo(
                      context,
                      "Tu cuenta ya está vinculada automáticamente.",
                    )
                  : () => _showClientSearch(isDark),
              onClearClient: isClient
                  ? () => AppFeedbackHelper.showError(
                      context,
                      "No puedes desvincular tu propia cuenta.",
                    )
                  : _clearClient,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelectorBar(MatchingProvider provider, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2C) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: QuotationContextMode.values.map((m) {
          final isSelected = _currentMode == m;
          return Expanded(
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _currentMode = m;
                  provider.updateMetadata(mode: m);
                });
                _syncAutoTitle(force: true);
              },
              borderRadius: BorderRadius.circular(9),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark
                            ? Colors.blue[900]!.withValues(alpha: 0.6)
                            : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.3 : 0.08,
                            ),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        m.icon,
                        size: 14,
                        color: isSelected
                            ? (isDark ? Colors.blue[200] : Colors.blue[900])
                            : (isDark ? Colors.grey[400] : Colors.grey[700]),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        m == QuotationContextMode.general
                            ? "General"
                            : (m == QuotationContextMode.wholesale
                                  ? "Mayorista"
                                  : "Escolar"),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isSelected
                              ? (isDark ? Colors.blue[200] : Colors.blue[900])
                              : (isDark ? Colors.grey[400] : Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
