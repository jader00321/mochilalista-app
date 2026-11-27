part of '../extraction_result_screen.dart';

extension _ExtractionResultMetadataAndListPart on _ExtractionResultScreenState {
  Widget _buildDataList(
    SmartQuotationProvider provider,
    bool isDark,
    bool isClient,
  ) {
    return Container(
      color: isDark ? const Color(0xFF14141C) : Colors.grey[50],
      child: Stack(
        children: [
          provider.items.isEmpty
              ? Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 60,
                          color: isDark ? Colors.white24 : Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No se detectaron items.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => provider.addItem(),
                          icon: const Icon(Icons.add),
                          label: const Text("Añadir Fila Manual"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark
                                ? Colors.blue[800]
                                : Colors.blue[50],
                            foregroundColor: isDark
                                ? Colors.white
                                : Colors.blue[800],
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        child: OutlinedButton.icon(
                          onPressed: () {
                            provider.addItem();
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _scrollController.animateTo(
                                _scrollController.position.maxScrollExtent +
                                    200,
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeOut,
                              );
                            });
                          },
                          icon: const Icon(Icons.add_circle_outline, size: 22),
                          label: const Text(
                            "Añadir Fila Manualmente",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            foregroundColor: isDark
                                ? Colors.blue[300]
                                : Colors.blue[800],
                            side: BorderSide(
                              color: isDark
                                  ? Colors.blue.withValues(alpha: 0.3)
                                  : Colors.blue.withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
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
                      onDeletePressed: () =>
                          _showDeleteConfirmation(context, item.id, isDark),
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
            ),
        ],
      ),
    );
  }

  Widget _buildMetadataCard(
    SmartQuotationProvider provider,
    bool isDark,
    bool isClient,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF23232F) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade300,
        ),
        boxShadow: [
          if (!isDark)
            const BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          iconColor: isDark ? Colors.blue[300] : Colors.blue[800],
          collapsedIconColor: isDark ? Colors.grey[400] : Colors.grey[600],
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Row(
            children: [
              Icon(
                _currentMode.icon,
                color: isDark ? Colors.blue[300] : Colors.blue[700],
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Datos de la Cotización",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildContextModeSelector(provider, isDark),
                  const SizedBox(height: 14),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _buildAdaptiveFields(isDark, isClient, provider),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContextModeSelector(
    SmartQuotationProvider provider,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14141C) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: QuotationContextMode.values.map((mode) {
          final isSelected = _currentMode == mode;
          final String label = switch (mode) {
            QuotationContextMode.general => "General",
            QuotationContextMode.wholesale => "Mayorista",
            QuotationContextMode.school => "Escolar",
          };
          return Expanded(
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                _updateContextMode(mode, provider);
              },
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? Colors.blue[800] : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected && !isDark
                      ? [
                          const BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            offset: Offset(0, 1),
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
                        mode.icon,
                        size: 14,
                        color: isSelected
                            ? (isDark ? Colors.white : Colors.blue[900])
                            : (isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        label,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w600,
                          color: isSelected
                              ? (isDark ? Colors.white : Colors.blue[900])
                              : (isDark ? Colors.grey[400] : Colors.grey[600]),
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

  Widget _buildAdaptiveFields(
    bool isDark,
    bool isClient,
    SmartQuotationProvider provider,
  ) {
    switch (_currentMode) {
      case QuotationContextMode.general:
        return _buildAdaptiveFieldGroup(
          key: const ValueKey('general_fields'),
          isDark: isDark,
          topField: _MetaInput(
            icon: Icons.person,
            hint: isClient ? "Tu Nombre (Cliente)" : "Cliente / Solicitante",
            ctrl: _studentCtrl,
            isDark: isDark,
            onChanged: (v) => provider.updateMetadata(student: v),
          ),
          leftField: _MetaInput(
            icon: Icons.phone,
            hint: "Teléfono / WhatsApp",
            ctrl: _phoneCtrl,
            isDark: isDark,
            keyboardType: TextInputType.phone,
            onChanged: (v) => provider.updateMetadata(phone: v),
          ),
          rightField: _MetaInput(
            icon: Icons.note_alt_outlined,
            hint: "Nota / Referencia",
            ctrl: _gradeCtrl,
            isDark: isDark,
            onChanged: (v) => provider.updateMetadata(grade: v),
          ),
        );
      case QuotationContextMode.wholesale:
        return _buildAdaptiveFieldGroup(
          key: const ValueKey('wholesale_fields'),
          isDark: isDark,
          topField: _MetaInput(
            icon: Icons.storefront_rounded,
            hint: "Negocio / Empresa / RUC",
            ctrl: _schoolCtrl,
            isDark: isDark,
            onChanged: (v) => provider.updateMetadata(institution: v),
          ),
          leftField: _MetaInput(
            icon: Icons.person,
            hint: "Contacto / Cliente",
            ctrl: _studentCtrl,
            isDark: isDark,
            onChanged: (v) => provider.updateMetadata(student: v),
          ),
          rightField: _MetaInput(
            icon: Icons.phone,
            hint: "Teléfono / WhatsApp",
            ctrl: _phoneCtrl,
            isDark: isDark,
            keyboardType: TextInputType.phone,
            onChanged: (v) => provider.updateMetadata(phone: v),
          ),
        );
      case QuotationContextMode.school:
        return _buildAdaptiveFieldGroup(
          key: const ValueKey('school_fields'),
          isDark: isDark,
          topField: _MetaInput(
            icon: Icons.school,
            hint: "Institución Educativa (Colegio)",
            ctrl: _schoolCtrl,
            isDark: isDark,
            onChanged: (v) => provider.updateMetadata(institution: v),
          ),
          leftField: _MetaInput(
            icon: Icons.person,
            hint: isClient
                ? "Nombre de tu hijo/a (Opcional)"
                : "Alumno/a o Apoderado",
            ctrl: _studentCtrl,
            isDark: isDark,
            onChanged: (v) => provider.updateMetadata(student: v),
          ),
          rightField: _MetaInput(
            icon: Icons.class_,
            hint: "Grado / Sección",
            ctrl: _gradeCtrl,
            isDark: isDark,
            onChanged: (v) => provider.updateMetadata(grade: v),
          ),
        );
    }
  }

  Widget _buildAdaptiveFieldGroup({
    required Key key,
    required bool isDark,
    required Widget topField,
    required Widget leftField,
    required Widget rightField,
  }) {
    return Column(
      key: key,
      children: [
        topField,
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Divider(
            height: 1,
            color: isDark ? Colors.white10 : Colors.grey[200],
          ),
        ),
        Row(
          children: [
            Expanded(child: leftField),
            Container(
              width: 1,
              height: 36,
              color: isDark ? Colors.white10 : Colors.grey[300],
              margin: const EdgeInsets.symmetric(horizontal: 12),
            ),
            Expanded(child: rightField),
          ],
        ),
      ],
    );
  }
}
