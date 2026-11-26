part of '../pdf_preview_screen.dart';

mixin _PdfConfigDesignTabMixin on _PdfPreviewScreenStateBase {
  @override
  Widget _buildDesignTab({
    required bool isDark,
    required Color textColor,
    required void Function(VoidCallback) updateConfig,
  }) {
    return ListView(
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
        _buildSectionTitle(
          "Plantilla Estructural del PDF",
          Icons.dashboard_outlined,
          isDark,
        ),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildLayoutSelectionCard(
                  title: "Ejecutivo Moderno",
                  subtitle: "Banda color superior y cabeceras ejecutivas",
                  icon: Icons.view_compact_outlined,
                  template: PdfLayoutTemplate.executiveModern,
                  isDark: isDark,
                  updateConfig: updateConfig,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildLayoutSelectionCard(
                  title: "Corporativo Formal",
                  subtitle: "Bordes dobles formales y sellos de aprobación",
                  icon: Icons.crop_square_outlined,
                  template: PdfLayoutTemplate.corporateFramed,
                  isDark: isDark,
                  updateConfig: updateConfig,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildLayoutSelectionCard(
                  title: "Catálogo Comercial",
                  subtitle: "Destaca fotos, badges y detalles de productos",
                  icon: Icons.photo_library_outlined,
                  template: PdfLayoutTemplate.commercialCatalog,
                  isDark: isDark,
                  updateConfig: updateConfig,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildLayoutSelectionCard(
                  title: "Mayorista Compacto",
                  subtitle:
                      "Máxima densidad de datos para cotizaciones extensas",
                  icon: Icons.table_rows_outlined,
                  template: PdfLayoutTemplate.compactWholesale,
                  isDark: isDark,
                  updateConfig: updateConfig,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _buildSectionTitle("Título del Documento", Icons.title, isDark),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF14141E) : Colors.grey[50],
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _titleCtrl,
            style: TextStyle(
              color: textColor,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: "Ej: COTIZACIÓN, NOTA DE VENTA",
              hintStyle: TextStyle(
                color: isDark ? Colors.grey[600] : Colors.grey,
              ),
            ),
            onChanged: (v) =>
                updateConfig(() => _config.documentTitle = v.toUpperCase()),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children:
              [
                "COTIZACIÓN",
                "PROFORMA COMERCIAL",
                "PRESUPUESTO MAYORISTA",
                "COTIZACIÓN ESCOLAR",
                "NOTA DE VENTA",
                "COMPROBANTE DE PAGO",
              ].map((chipTitle) {
                final bool isSelected = _config.documentTitle == chipTitle;
                return ChoiceChip(
                  label: Text(
                    chipTitle,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: isDark ? Colors.blue[900] : Colors.blue[100],
                  onSelected: (sel) {
                    if (sel) {
                      updateConfig(() {
                        _titleCtrl.text = chipTitle;
                        _config.documentTitle = chipTitle;
                      });
                    }
                  },
                );
              }).toList(),
        ),
        const SizedBox(height: 22),
        _buildSectionTitle("Tamaño de Hoja", Icons.aspect_ratio, isDark),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildChoiceCard(
                  title: "Hoja A4",
                  subtitle: "Ejecutiva completa",
                  icon: Icons.description_outlined,
                  isSelected: _config.pageSize == PdfPageSize.a4,
                  isDark: isDark,
                  onTap: () =>
                      updateConfig(() => _config.pageSize = PdfPageSize.a4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildChoiceCard(
                  title: "Ticket 80mm",
                  subtitle: "Rollo térmico POS",
                  icon: Icons.receipt_long_outlined,
                  isSelected: _config.pageSize == PdfPageSize.ticket80,
                  isDark: isDark,
                  onTap: () => updateConfig(
                    () => _config.pageSize = PdfPageSize.ticket80,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        _buildSectionTitle("Paleta de Color", Icons.palette_outlined, isDark),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildThemeSelectionCard(
                  "Azul Moderno",
                  const Color(0xFF1565C0),
                  PdfTheme.modern,
                  isDark,
                  updateConfig,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildThemeSelectionCard(
                  "Esmeralda",
                  const Color(0xFF00796B),
                  PdfTheme.emerald,
                  isDark,
                  updateConfig,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildThemeSelectionCard(
                  "Ejecutivo",
                  const Color(0xFF263238),
                  PdfTheme.dark,
                  isDark,
                  updateConfig,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildThemeSelectionCard(
                  "B&N (Ahorro)",
                  const Color(0xFF212121),
                  PdfTheme.classic,
                  isDark,
                  updateConfig,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildThemeSelectionCard(
                  "Vino Tinto",
                  const Color(0xFF880E4F),
                  PdfTheme.burgundy,
                  isDark,
                  updateConfig,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildThemeSelectionCard(
                  "Índigo Real",
                  const Color(0xFF283593),
                  PdfTheme.indigo,
                  isDark,
                  updateConfig,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
