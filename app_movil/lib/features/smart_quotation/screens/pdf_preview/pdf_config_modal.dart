part of '../pdf_preview_screen.dart';

mixin _PdfConfigModalMixin on _PdfPreviewScreenStateBase {
  @override
  void _showConfigModal(BuildContext context, bool isDark) {
    final surfaceColor = isDark ? const Color(0xFF1E1E2C) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final businessScrollController = ScrollController();
    final additionalInfoKey = GlobalKey();
    final paymentAccountsKey = GlobalKey();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black45,
      builder: (ctx) => DefaultTabController(
        length: 3,
        child: StatefulBuilder(
          builder: (context, setModalState) {
            void updateConfig(VoidCallback fn) {
              setModalState(fn);
              setState(fn);
            }

            final bool isQuickSale =
                _saleData != null && _saleData!['origen_venta'] == 'pos_rapido';
            final bool isLoan =
                _saleData != null &&
                _saleData!['origen_venta'] == 'prestamo_personal';
            final bool isSale = _saleData != null;

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.82,
              ),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: SafeArea(
                top: false,
                bottom: true,
                maintainBottomViewPadding: true,
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 16, 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  Icons.tune_rounded,
                                  size: 22,
                                  color: isDark
                                      ? Colors.blue[300]
                                      : Colors.blue[800],
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      "Opciones de Documento",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, size: 24, color: textColor),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    TabBar(
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                      labelColor: isDark ? Colors.blue[300] : Colors.blue[800],
                      unselectedLabelColor: isDark
                          ? Colors.grey[400]
                          : Colors.grey[600],
                      indicatorColor: isDark
                          ? Colors.blue[400]
                          : Colors.blue[800],
                      indicatorWeight: 3,
                      labelStyle: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                      unselectedLabelStyle: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                      tabs: const [
                        Tab(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.palette_outlined, size: 15),
                                SizedBox(width: 4),
                                Text("Diseño"),
                              ],
                            ),
                          ),
                        ),
                        Tab(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.storefront_outlined, size: 15),
                                SizedBox(width: 4),
                                Text("Negocio y Cliente"),
                              ],
                            ),
                          ),
                        ),
                        Tab(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.table_chart_outlined, size: 15),
                                SizedBox(width: 4),
                                Text("Tabla y Totales"),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    Divider(
                      height: 1,
                      color: isDark ? Colors.white12 : Colors.grey[200],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildDesignTab(
                            isDark: isDark,
                            textColor: textColor,
                            updateConfig: updateConfig,
                          ),
                          _buildBusinessAndClientTab(
                            context: context,
                            authProv: authProv,
                            businessScrollController: businessScrollController,
                            additionalInfoKey: additionalInfoKey,
                            paymentAccountsKey: paymentAccountsKey,
                            isDark: isDark,
                            isQuickSale: isQuickSale,
                            textColor: textColor,
                            updateConfig: updateConfig,
                          ),
                          _buildTableAndTotalsTab(
                            isDark: isDark,
                            isLoan: isLoan,
                            isSale: isSale,
                            textColor: textColor,
                            updateConfig: updateConfig,
                          ),
                        ],
                      ),
                    ),
                    Builder(
                      builder: (bCtx) {
                        final effectiveBottom =
                            InteractiveSheetWrapper.getEffectiveBottomPadding(
                              bCtx,
                              minPadding: kMinDefensiveBottomClearance,
                            );
                        return Container(
                          padding: EdgeInsets.fromLTRB(
                            20,
                            12,
                            20,
                            effectiveBottom,
                          ),
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            border: Border(
                              top: BorderSide(
                                color: isDark
                                    ? Colors.white12
                                    : Colors.grey.shade200,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final success =
                                        await PdfPreferencesService.saveDefaultConfig(
                                          _config,
                                        );
                                    if (context.mounted && success) {
                                      HapticFeedback.mediumImpact();
                                      AppFeedbackHelper.showSuccess(
                                        context,
                                        "¡Configuración guardada como diseño por defecto!",
                                      );
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.bookmark_added_outlined,
                                    size: 18,
                                  ),
                                  label: const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      "Guardar mi diseño por defecto",
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 13,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              FilledButton(
                                onPressed: () => Navigator.pop(context),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 13,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  "Aplicar",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ).whenComplete(businessScrollController.dispose);
  }

  @override
  Widget _buildSectionTitle(String title, IconData icon, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isDark ? Colors.blueGrey[300] : Colors.blueGrey,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                color: isDark ? Colors.blueGrey[300] : Colors.blueGrey,
                fontWeight: FontWeight.w900,
                fontSize: 12,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget _buildChoiceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final activeBorder = isDark ? Colors.blue[400] : Colors.blue[700];
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                    ? Colors.blue.withValues(alpha: 0.15)
                    : Colors.blue.withValues(alpha: 0.08))
              : (isDark ? const Color(0xFF14141E) : Colors.grey[50]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? activeBorder!
                : (isDark ? Colors.white12 : Colors.grey.shade300),
            width: isSelected ? 1.8 : 0.8,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? activeBorder
                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget _buildLayoutSelectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required PdfLayoutTemplate template,
    required bool isDark,
    required Function(VoidCallback) updateConfig,
  }) {
    final bool isSelected = _config.layoutTemplate == template;
    final activeColor = isDark ? Colors.blue[400]! : Colors.blue[800]!;

    return InkWell(
      onTap: () => updateConfig(() => _config.layoutTemplate = template),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                    ? Colors.blue.withValues(alpha: 0.18)
                    : Colors.blue.withValues(alpha: 0.08))
              : (isDark ? const Color(0xFF14141E) : Colors.grey[50]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isDark ? Colors.white12 : Colors.grey.shade300),
            width: isSelected ? 2.0 : 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected
                      ? activeColor
                      : (isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: isSelected
                      ? Icon(
                          Icons.check_circle_rounded,
                          key: const ValueKey('checked'),
                          size: 17,
                          color: activeColor,
                        )
                      : Icon(
                          Icons.radio_button_unchecked_rounded,
                          key: const ValueKey('unchecked'),
                          size: 17,
                          color: isDark ? Colors.white24 : Colors.grey.shade400,
                        ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                height: 1.3,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget _buildThemeSelectionCard(
    String name,
    Color color,
    PdfTheme theme,
    bool isDark,
    Function(VoidCallback) updateConfig,
  ) {
    final bool isSelected = _config.theme == theme;
    return InkWell(
      onTap: () => updateConfig(() => _config.theme = theme),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.12)
              : (isDark ? const Color(0xFF14141E) : Colors.grey[50]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? color
                : (isDark ? Colors.white12 : Colors.grey.shade300),
            width: isSelected ? 2 : 0.8,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
            if (isSelected) Icon(Icons.check, size: 16, color: color),
          ],
        ),
      ),
    );
  }

  @override
  Widget _buildLogoPreview(
    String? logoUrl,
    bool isDark, {
    String? businessName,
  }) {
    if (logoUrl != null && logoUrl.isNotEmpty && logoUrl != 'null') {
      return Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: UniversalImage(
              path: logoUrl,
              width: 44,
              height: 44,
              fit: BoxFit.cover,
              productName: businessName ?? "Mi Negocio",
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Logo actual detectado",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  "Se incluirá en el encabezado del documento",
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Icon(Icons.info_outline, size: 20, color: Colors.amber[700]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            "Aún no tienes un logo subido en tu perfil. Puedes agregarlo en Ajustes > Mi Negocio.",
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
          ),
        ),
      ],
    );
  }
}
