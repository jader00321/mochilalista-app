part of '../pdf_preview_screen.dart';

mixin _PdfConfigBusinessTabMixin on _PdfPreviewScreenStateBase {
  @override
  Widget _buildBusinessAndClientTab({
    required BuildContext context,
    required AuthProvider authProv,
    required ScrollController businessScrollController,
    required GlobalKey additionalInfoKey,
    required GlobalKey paymentAccountsKey,
    required bool isDark,
    required bool isQuickSale,
    required Color textColor,
    required void Function(VoidCallback) updateConfig,
  }) {
    return ListView(
      controller: businessScrollController,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(
        20,
        16,
        20,
        80 + kModalScrollBottomClearance,
      ),
      children: [
        _buildSectionTitle("Datos de Mi Negocio", Icons.store_rounded, isDark),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF14141E)
                : Colors.blue.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white12
                  : Colors.blue.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  "Mostrar Cabecera del Negocio",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                value: _config.showBusinessInfo,
                activeThumbColor: Colors.blue,
                onChanged: (v) =>
                    updateConfig(() => _config.showBusinessInfo = v),
              ),
              if (_config.showBusinessInfo) ...[
                const SizedBox(height: 8),
                _buildLogoPreview(
                  authProv.user?.business?.logoUrl,
                  isDark,
                  businessName: authProv.user?.business?.commercialName,
                ),
                const SizedBox(height: 12),
                Text(
                  "Campos a incluir en cabecera:",
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: const Text("Logo"),
                      selected: _config.includeLogo,
                      onSelected: (v) =>
                          updateConfig(() => _config.includeLogo = v),
                    ),
                    FilterChip(
                      label: const Text("Dirección"),
                      selected: _config.includeShopAddress,
                      onSelected: (v) =>
                          updateConfig(() => _config.includeShopAddress = v),
                    ),
                    FilterChip(
                      label: const Text("Teléfono"),
                      selected: _config.includeOwnerPhone,
                      onSelected: (v) =>
                          updateConfig(() => _config.includeOwnerPhone = v),
                    ),
                    FilterChip(
                      label: const Text("RUC"),
                      selected: _config.includeShopRuc,
                      onSelected: (v) =>
                          updateConfig(() => _config.includeShopRuc = v),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildSectionTitle(
          "Datos del Cliente & Notas al Pie",
          Icons.person_outline,
          isDark,
        ),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF14141E)
                : Colors.orange.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white12
                  : Colors.orange.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  "Mostrar Bloque de Cliente",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                value: _config.showClientName,
                activeThumbColor: Colors.orange,
                onChanged: (v) =>
                    updateConfig(() => _config.showClientName = v),
              ),
              if (_config.showClientName) ...[
                const SizedBox(height: 6),
                TextField(
                  controller: _clientNameCtrl,
                  style: TextStyle(color: textColor, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: "Nombre del Cliente en Documento",
                    hintText: "Ej: Juan Pérez / Empresa SAC",
                    labelStyle: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E1E2C) : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white12 : Colors.grey.shade300,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_clientNameCtrl.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            tooltip: "Limpiar cliente",
                            onPressed: () {
                              updateConfig(() {
                                _clientNameCtrl.clear();
                                _config.customClientName = null;
                              });
                            },
                          ),
                        IconButton(
                          icon: const Icon(Icons.search, size: 20),
                          tooltip: "Buscar en Agenda",
                          onPressed: () {
                            ClientSearchModal.show(
                              context,
                              onClientSelected: (client) {
                                final clean =
                                    PdfGenerator.cleanClientDisplayName(
                                      client.fullName,
                                    );
                                updateConfig(() {
                                  _clientNameCtrl.text = clean;
                                  _config.customClientName = clean.isEmpty
                                      ? null
                                      : clean;
                                });
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  onChanged: (v) {
                    final clean = PdfGenerator.cleanClientDisplayName(v);
                    updateConfig(
                      () => _config.customClientName = clean.isEmpty
                          ? null
                          : clean,
                    );
                  },
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    isQuickSale
                        ? "Mostrar Nota de Venta"
                        : "Información Adicional",
                    style: TextStyle(color: textColor, fontSize: 14),
                  ),
                  subtitle: Text(
                    isQuickSale
                        ? "Imprime la nota registrada"
                        : "Colegio / Grado / Notas",
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  value: _config.showInstitutionInfo,
                  activeThumbColor: Colors.orange,
                  onChanged: (v) {
                    updateConfig(() {
                      _config.showInstitutionInfo = v;
                      if (v) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (additionalInfoKey.currentContext != null) {
                            Scrollable.ensureVisible(
                              additionalInfoKey.currentContext!,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              alignment: 0.5,
                            );
                          }
                        });
                      }
                    });
                  },
                ),
                AnimatedSize(
                  key: additionalInfoKey,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: !_config.showInstitutionInfo
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 4),
                          child: Column(
                            children: [
                              if (!isQuickSale) ...[
                                TextField(
                                  controller: _instNameCtrl,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 13,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: "Colegio / Institución",
                                    labelStyle: TextStyle(
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[700],
                                    ),
                                    filled: true,
                                    fillColor: isDark
                                        ? const Color(0xFF1E1E2C)
                                        : Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: isDark
                                            ? Colors.white12
                                            : Colors.grey.shade300,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  onChanged: (v) => updateConfig(
                                    () => _config.customInstitutionName =
                                        v.trim().isEmpty ? null : v.trim(),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _gradeLevelCtrl,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 13,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: "Grado / Nivel / Sección",
                                    labelStyle: TextStyle(
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[700],
                                    ),
                                    filled: true,
                                    fillColor: isDark
                                        ? const Color(0xFF1E1E2C)
                                        : Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(
                                        color: isDark
                                            ? Colors.white12
                                            : Colors.grey.shade300,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  onChanged: (v) => updateConfig(
                                    () => _config.customGradeLevel =
                                        v.trim().isEmpty ? null : v.trim(),
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                              TextField(
                                controller: _notesCtrl,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 13,
                                ),
                                decoration: InputDecoration(
                                  labelText: isQuickSale
                                      ? "Nota de Venta / Observaciones"
                                      : "Notas / Observaciones del Cliente",
                                  labelStyle: TextStyle(
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[700],
                                  ),
                                  filled: true,
                                  fillColor: isDark
                                      ? const Color(0xFF1E1E2C)
                                      : Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(
                                      color: isDark
                                          ? Colors.white12
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                onChanged: (v) => updateConfig(
                                  () => _config.customNotes = v.trim().isEmpty
                                      ? null
                                      : v.trim(),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: _footerNoteCtrl,
                style: TextStyle(color: textColor, fontSize: 14),
                decoration: InputDecoration(
                  labelText: "Condiciones / Validez al Pie",
                  hintText: "Ej: Cotización válida por 7 días.",
                  labelStyle: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E1E2C) : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white12 : Colors.grey.shade300,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                onChanged: (v) => updateConfig(
                  () => _config.footerNote = v.trim().isEmpty ? null : v.trim(),
                ),
              ),
              const SizedBox(height: 10),
              _buildValiditySection(
                isDark: isDark,
                textColor: textColor,
                updateConfig: updateConfig,
              ),
              const SizedBox(height: 12),
              _buildConditionsSection(
                isDark: isDark,
                textColor: textColor,
                updateConfig: updateConfig,
              ),
              const SizedBox(height: 10),
              _buildPaymentAccountsSection(
                authProv: authProv,
                paymentAccountsKey: paymentAccountsKey,
                isDark: isDark,
                textColor: textColor,
                updateConfig: updateConfig,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
