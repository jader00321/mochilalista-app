part of '../smart_update_modal.dart';

extension _SmartUpdateSectionsPart on SmartUpdateModal {
  List<Widget> _buildConflictSections({
    required BuildContext context,
    required bool isDark,
    required bool onlyPriceIssues,
    required List<StockWarning> stockIssues,
    required List<SharedStockConflict> sharedIssues,
    required List<PriceChange> priceIssues,
    required List<NameChange> nameIssues,
    required List<BundleChange> bundleIssues,
    required List<UnitChange> unitIssues,
  }) {
    return [
      if (stockIssues.isNotEmpty) ...[
        _buildSectionHeader(
          "Problemas de Stock",
          Icons.remove_shopping_cart,
          isDark ? Colors.red[300]! : Colors.red[800]!,
        ),
        _buildAlertBanner(
          icon: Icons.warning_amber,
          message:
              "Hay productos agotados o que superan el stock. Para poder vender esta lista, debes eliminarlos o corregir su cantidad.",
          bgColor: isDark ? Colors.red.withValues(alpha: 0.1) : Colors.red[50]!,
          borderColor: isDark
              ? Colors.red.withValues(alpha: 0.3)
              : Colors.red.shade200,
          iconColor: isDark ? Colors.red[300]! : Colors.red[800]!,
          textColor: isDark ? Colors.red[100]! : Colors.red[900]!,
        ),
        ...stockIssues.map((s) => _buildStockRow(s, isDark, context)),
        const SizedBox(height: 12),
        _buildSectionOutlinedButton(
          onPressed: () {
            Navigator.pop(context);
            onFixStock();
          },
          icon: Icons.delete_sweep,
          label: "Eliminar Productos Agotados",
          fgColor: isDark ? Colors.red[300]! : Colors.red[800]!,
          borderColor: isDark
              ? Colors.red.withValues(alpha: 0.5)
              : Colors.red[300]!,
        ),
        _buildSectionDivider(isDark),
      ],
      if (sharedIssues.isNotEmpty) ...[
        _buildSectionHeader(
          "Conflictos de Stock Compartido",
          Icons.hub_rounded,
          isDark ? Colors.orange[300]! : Colors.orange[800]!,
        ),
        _buildAlertBanner(
          icon: Icons.hub_rounded,
          message:
              "La suma de variantes en la cotización supera el inventario base compartido del producto en almacén.",
          bgColor: isDark
              ? Colors.orange.withValues(alpha: 0.1)
              : Colors.orange[50]!,
          borderColor: isDark
              ? Colors.orange.withValues(alpha: 0.3)
              : Colors.orange.shade200,
          iconColor: isDark ? Colors.orange[300]! : Colors.orange[800]!,
          textColor: isDark ? Colors.orange[100]! : Colors.orange[900]!,
        ),
        ...sharedIssues.map((c) => _buildSharedConflictRow(c, isDark, context)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onFixStock();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.orange[800] : Colors.orange[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_fix_high, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "Ajustar al Stock Disponible",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
        ),
        _buildSectionDivider(isDark),
      ],
      if (priceIssues.isNotEmpty) ...[
        _buildSectionHeader(
          "Advertencia de Precios",
          Icons.monetization_on,
          isDark ? Colors.orange[300]! : Colors.orange[800]!,
        ),
        _buildAlertBanner(
          icon: Icons.info_outline,
          message:
              "El precio en tienda ha cambiado. Tu precio cotizado SE MANTENDRÁ a menos que decidas aceptar el nuevo precio.",
          bgColor: isDark
              ? Colors.orange.withValues(alpha: 0.1)
              : Colors.orange[50]!,
          borderColor: isDark
              ? Colors.orange.withValues(alpha: 0.3)
              : Colors.orange.shade200,
          iconColor: isDark ? Colors.orange[300]! : Colors.orange[800]!,
          textColor: isDark ? Colors.orange[100]! : Colors.orange[900]!,
        ),
        ...priceIssues.map((p) => _buildPriceRow(p, isDark, context)),
        if (!onlyPriceIssues) ...[
          const SizedBox(height: 12),
          _buildSectionOutlinedButton(
            onPressed: () {
              Navigator.pop(context);
              onUpdatePrices();
            },
            icon: Icons.refresh,
            label: "Actualizar Todo a Precios de Hoy",
            fgColor: isDark ? Colors.orange[300]! : Colors.orange[800]!,
            borderColor: isDark
                ? Colors.orange.withValues(alpha: 0.5)
                : Colors.orange[300]!,
          ),
        ],
        _buildSectionDivider(isDark),
      ],
      if (nameIssues.isNotEmpty) ...[
        _buildSectionHeader(
          "Cambios en Inventario",
          Icons.edit_note,
          isDark ? Colors.indigo[300]! : Colors.indigo[800]!,
        ),
        _buildAlertBanner(
          icon: Icons.sync_problem,
          message:
              "Algunos productos han cambiado de nombre en el catálogo. Te recomendamos actualizarlos.",
          bgColor: isDark
              ? Colors.indigo.withValues(alpha: 0.1)
              : Colors.indigo[50]!,
          borderColor: isDark
              ? Colors.indigo.withValues(alpha: 0.3)
              : Colors.indigo.shade200,
          iconColor: isDark ? Colors.indigo[300]! : Colors.indigo[800]!,
          textColor: isDark ? Colors.indigo[200]! : Colors.indigo[900]!,
        ),
        ...nameIssues.map((n) => _buildNameRow(n, isDark, context)),
        const SizedBox(height: 12),
        if (onUpdateNames != null)
          _buildSectionOutlinedButton(
            onPressed: () {
              Navigator.pop(context);
              onUpdateNames!();
            },
            icon: Icons.drive_file_rename_outline,
            label: "Actualizar Todos los Nombres",
            fgColor: isDark ? Colors.indigo[300]! : Colors.indigo[800]!,
            borderColor: isDark
                ? Colors.indigo.withValues(alpha: 0.5)
                : Colors.indigo[300]!,
          ),
        _buildSectionDivider(isDark),
      ],
      if (bundleIssues.isNotEmpty) ...[
        _buildSectionHeader(
          "Ofertas Desactualizadas",
          Icons.sync_problem,
          isDark ? Colors.deepPurple[300]! : Colors.deepPurple[800]!,
        ),
        _buildAlertBanner(
          icon: Icons.inventory_2,
          message:
              "La composición, nombre o precio de estas ofertas ha cambiado, o han sido eliminadas/desactivadas.",
          bgColor: isDark
              ? Colors.deepPurple.withValues(alpha: 0.1)
              : Colors.deepPurple[50]!,
          borderColor: isDark
              ? Colors.deepPurple.withValues(alpha: 0.3)
              : Colors.deepPurple.shade200,
          iconColor: isDark ? Colors.deepPurple[300]! : Colors.deepPurple[800]!,
          textColor: isDark ? Colors.deepPurple[200]! : Colors.deepPurple[900]!,
        ),
        ...bundleIssues.map((b) => _buildBundleRow(b, isDark)),
        const SizedBox(height: 12),
        if (onSyncBundles != null)
          _buildSectionOutlinedButton(
            onPressed: () {
              Navigator.pop(context);
              onSyncBundles!();
            },
            icon: Icons.sync,
            label: "Sincronizar Ofertas",
            fgColor: isDark ? Colors.deepPurple[300]! : Colors.deepPurple[800]!,
            borderColor: isDark
                ? Colors.deepPurple.withValues(alpha: 0.5)
                : Colors.deepPurple[300]!,
          ),
        _buildSectionDivider(isDark),
      ],
      if (unitIssues.isNotEmpty) ...[
        _buildSectionHeader(
          "Cambio de Unidad de Venta",
          Icons.straighten,
          isDark ? Colors.cyan[300]! : Colors.cyan[800]!,
        ),
        _buildAlertBanner(
          icon: Icons.warning_amber,
          message:
              "La unidad de venta de algunos productos cambió en el catálogo. Debes sincronizar antes de vender para evitar descuentos de stock incorrectos.",
          bgColor: isDark
              ? Colors.cyan.withValues(alpha: 0.1)
              : Colors.cyan[50]!,
          borderColor: isDark
              ? Colors.cyan.withValues(alpha: 0.3)
              : Colors.cyan.shade200,
          iconColor: isDark ? Colors.cyan[300]! : Colors.cyan[800]!,
          textColor: isDark ? Colors.cyan[100]! : Colors.cyan[900]!,
        ),
        ...unitIssues.map((u) => _buildUnitRow(u, isDark)),
        const SizedBox(height: 12),
        if (onSyncUnits != null)
          _buildSectionOutlinedButton(
            onPressed: () {
              Navigator.pop(context);
              onSyncUnits!();
            },
            icon: Icons.sync,
            label: "Sincronizar Unidades de Venta",
            fgColor: isDark ? Colors.cyan[300]! : Colors.cyan[800]!,
            borderColor: isDark
                ? Colors.cyan.withValues(alpha: 0.5)
                : Colors.cyan[300]!,
          ),
        _buildSectionDivider(isDark),
      ],
    ];
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: color,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertBanner({
    required IconData icon,
    required String message,
    required Color bgColor,
    required Color borderColor,
    required Color iconColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 14, color: textColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionOutlinedButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color fgColor,
    required Color borderColor,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: fgColor,
          side: BorderSide(color: borderColor),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionDivider(bool isDark) {
    return Divider(
      height: 40,
      thickness: 1.5,
      color: isDark ? Colors.white10 : Colors.grey[200],
    );
  }
}
