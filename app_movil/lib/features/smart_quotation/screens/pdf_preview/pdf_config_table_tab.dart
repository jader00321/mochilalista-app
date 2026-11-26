part of '../pdf_preview_screen.dart';

mixin _PdfConfigTableTabMixin on _PdfPreviewScreenStateBase {
  @override
  Widget _buildTableAndTotalsTab({
    required bool isDark,
    required bool isLoan,
    required bool isSale,
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
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF14141E)
                : Colors.purple.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.purple.withValues(alpha: 0.2)
                  : Colors.purple.shade100,
            ),
          ),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Icon(
              Icons.image,
              color: isDark ? Colors.purple[300] : Colors.purple[700],
            ),
            title: Text(
              "Incluir Imágenes de Productos",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: isDark ? Colors.purple[200] : Colors.purple[900],
              ),
            ),
            subtitle: Text(
              "Muestra fotos en miniatura de tus productos (Local / Catálogo)",
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[700],
                fontSize: 12,
              ),
            ),
            value: _config.showImages,
            activeThumbColor: Colors.purple,
            onChanged: (v) => updateConfig(() => _config.showImages = v),
          ),
        ),
        const SizedBox(height: 16),
        if (!isLoan) ...[
          _buildSectionTitle(
            "Columnas de Productos",
            Icons.view_column_outlined,
            isDark,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF14141E)
                  : Colors.green.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white12
                    : Colors.green.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    "Mostrar Columna: Unidad",
                    style: TextStyle(color: textColor, fontSize: 14),
                  ),
                  subtitle: Text(
                    "Ej: Docena, Empaque, Kilo",
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  value: _config.showProductUnit,
                  activeThumbColor: Colors.green,
                  onChanged: (v) =>
                      updateConfig(() => _config.showProductUnit = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    "Mostrar Columna: Precio Unitario",
                    style: TextStyle(color: textColor, fontSize: 14),
                  ),
                  subtitle: Text(
                    "Precio por 1 artículo",
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  value: _config.showProductUnitPrice,
                  activeThumbColor: Colors.green,
                  onChanged: (v) => updateConfig(() {
                    _config.showProductUnitPrice = v;
                    if (!v) _config.showProductSavings = false;
                  }),
                ),
                if (_config.showProductUnitPrice)
                  Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        "Mostrar Descuento Unitario",
                        style: TextStyle(color: textColor, fontSize: 13),
                      ),
                      subtitle: Text(
                        "Precio original tachado",
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 11,
                        ),
                      ),
                      value: _config.showProductSavings,
                      activeThumbColor: Colors.green,
                      onChanged: (v) =>
                          updateConfig(() => _config.showProductSavings = v),
                    ),
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    "Mostrar Columna: Subtotal",
                    style: TextStyle(color: textColor, fontSize: 14),
                  ),
                  subtitle: Text(
                    "Multiplica precio por cantidad",
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  value: _config.showProductSubtotal,
                  activeThumbColor: Colors.green,
                  onChanged: (v) =>
                      updateConfig(() => _config.showProductSubtotal = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        _buildSectionTitle(
          "Totales Financieros",
          Icons.payments_outlined,
          isDark,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF14141E)
                : Colors.teal.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white12
                  : Colors.teal.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  "Mostrar Total a Pagar",
                  style: TextStyle(color: textColor, fontSize: 14),
                ),
                value: _config.showTotalGlobal,
                activeThumbColor: Colors.teal,
                onChanged: (v) => updateConfig(() {
                  _config.showTotalGlobal = v;
                  if (!v) _config.showTotalSavings = false;
                }),
              ),
              if (_config.showTotalGlobal)
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      "Mostrar Descuento / Ahorro Global",
                      style: TextStyle(color: textColor, fontSize: 13),
                    ),
                    value: _config.showTotalSavings,
                    activeThumbColor: Colors.teal,
                    onChanged: (v) =>
                        updateConfig(() => _config.showTotalSavings = v),
                  ),
                ),
              if (isSale) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    "Mostrar Info de Pago y Deuda",
                    style: TextStyle(color: textColor, fontSize: 14),
                  ),
                  value: _config.showTransactionDetails,
                  activeThumbColor: Colors.teal,
                  onChanged: (v) =>
                      updateConfig(() => _config.showTransactionDetails = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    "Mostrar Cronograma de Cuotas",
                    style: TextStyle(color: textColor, fontSize: 14),
                  ),
                  value: _config.showInstallments,
                  activeThumbColor: Colors.teal,
                  onChanged: (v) =>
                      updateConfig(() => _config.showInstallments = v),
                ),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  "Sello Visual de Estado (Pagado/Pendiente)",
                  style: TextStyle(color: textColor, fontSize: 14),
                ),
                value: _config.showStatusStamp,
                activeThumbColor: Colors.teal,
                onChanged: (v) =>
                    updateConfig(() => _config.showStatusStamp = v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
