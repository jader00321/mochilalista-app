part of '../pdf_preview_screen.dart';

mixin _PdfPreviewToolbarsMixin on _PdfPreviewScreenStateBase {
  @override
  Widget _buildZoomHintPill() {
    return Positioned(
      top: 14,
      left: 16,
      right: 16,
      child: Center(
        child: AnimatedOpacity(
          opacity: _showZoomPill ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 350),
          child: IgnorePointer(
            ignoring: !_showZoomPill,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24, width: 0.8),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.zoom_in, color: Colors.white70, size: 16),
                    SizedBox(width: 6),
                    Text(
                      "Pellizca o toca 2 veces para Zoom",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget _buildZoomFloatingBar(bool isDark) {
    return Positioned(
      bottom: 14,
      left: 16,
      right: 16,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E1E2C).withValues(alpha: 0.92)
                  : Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                width: 0.8,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, size: 18),
                  visualDensity: VisualDensity.compact,
                  tooltip: "Alejar",
                  onPressed: _currentScale > 1.01 ? _zoomOut : null,
                ),
                Container(
                  constraints: const BoxConstraints(minWidth: 44),
                  alignment: Alignment.center,
                  child: Text(
                    "${(_currentScale * 100).round()}%",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 18),
                  visualDensity: VisualDensity.compact,
                  tooltip: "Acercar",
                  onPressed: _currentScale < 2.99 ? _zoomIn : null,
                ),
                Container(
                  height: 16,
                  width: 1,
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                ),
                IconButton(
                  icon: const Icon(Icons.fit_screen_outlined, size: 18),
                  visualDensity: VisualDensity.compact,
                  tooltip: "Restablecer 100%",
                  onPressed: (_currentScale - 1.0).abs() > 0.02
                      ? _resetZoom
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Barra flotante compacta para cambiar Formato (A4 vs Ticket 80mm) y Tema al vuelo
  @override
  Widget _buildQuickControlsBar(bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E1E2C) : Colors.white;
    final borderColor = isDark ? Colors.white12 : Colors.grey.shade300;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(bottom: BorderSide(color: borderColor, width: 0.8)),
      ),
      child: Row(
        children: [
          Flexible(
            flex: 4,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF14141E) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor, width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFormatButton(
                      title: "A4",
                      icon: Icons.description_outlined,
                      isSelected: _config.pageSize == PdfPageSize.a4,
                      isDark: isDark,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _config.pageSize = PdfPageSize.a4);
                      },
                    ),
                    _buildFormatButton(
                      title: "Ticket",
                      icon: Icons.receipt_long_outlined,
                      isSelected: _config.pageSize == PdfPageSize.ticket80,
                      isDark: isDark,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _config.pageSize = PdfPageSize.ticket80);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 6,
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildThemeCircle(
                      PdfTheme.modern,
                      const Color(0xFF1565C0),
                      "Azul",
                      isDark,
                    ),
                    const SizedBox(width: 6),
                    _buildThemeCircle(
                      PdfTheme.emerald,
                      const Color(0xFF00796B),
                      "Verde",
                      isDark,
                    ),
                    const SizedBox(width: 6),
                    _buildThemeCircle(
                      PdfTheme.dark,
                      const Color(0xFF263238),
                      "Oscuro",
                      isDark,
                    ),
                    const SizedBox(width: 6),
                    _buildThemeCircle(
                      PdfTheme.classic,
                      const Color(0xFF212121),
                      "B&N",
                      isDark,
                    ),
                    const SizedBox(width: 6),
                    _buildThemeCircle(
                      PdfTheme.burgundy,
                      const Color(0xFF880E4F),
                      "Vino",
                      isDark,
                    ),
                    const SizedBox(width: 6),
                    _buildThemeCircle(
                      PdfTheme.indigo,
                      const Color(0xFF283593),
                      "Índigo",
                      isDark,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final activeBg = isDark ? Colors.blue[800] : Colors.blue[700];
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.grey[400] : Colors.grey[700]),
            ),
            const SizedBox(width: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.grey[300] : Colors.grey[800]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeCircle(
    PdfTheme theme,
    Color color,
    String label,
    bool isDark,
  ) {
    final bool isSelected = _config.theme == theme;
    // Borde de contraste alto para que B&N sea 100% visible en modo oscuro
    final Color borderColor = isSelected
        ? Colors.white
        : (isDark
              ? Colors.white38
              : (theme == PdfTheme.classic
                    ? Colors.black45
                    : Colors.transparent));

    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _config.theme = theme);
        },
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: borderColor,
              width: isSelected ? 2.4 : 1.2,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: color.withValues(alpha: 0.6),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
            ],
          ),
          child: isSelected
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : null,
        ),
      ),
    );
  }

  /// Barra de herramientas inferior con botón Descargar directo y feedback háptico
  @override
  Widget _buildBottomToolbar(BuildContext context, bool isDark) {
    final surfaceColor = isDark ? const Color(0xFF1B1B26) : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: surfaceColor,
        boxShadow: [
          if (!isDark)
            const BoxShadow(
              color: Colors.black12,
              blurRadius: 15,
              offset: Offset(0, -4),
            ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: ElevatedButton.icon(
                onPressed: () => _showConfigModal(context, isDark),
                icon: const Icon(Icons.tune, size: 18),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "OPCIONES",
                    maxLines: 1,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? const Color(0xFF2C2C3E)
                      : Colors.grey[900],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: ElevatedButton.icon(
                onPressed: _downloadPdf,
                icon: const Icon(Icons.file_download_outlined, size: 18),
                label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    "GUARDAR",
                    maxLines: 1,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[700],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: _sharePdf,
              icon: const Icon(Icons.share, size: 20),
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _printPdf,
              icon: const Icon(Icons.print, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: Colors.blue[800],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Guarda el PDF en la carpeta Descargas y abre el modal animado de éxito
  Future<void> _downloadPdf() async {
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final String cleanTitle = (_config.documentTitle ?? "DOCUMENTO").replaceAll(
      RegExp(r'\s+'),
      '_',
    );
    final String fileName = "${cleanTitle}_${_quotation!.id}.pdf";

    await DownloadFeedbackModal.show(
      context,
      title: "Descargar Documento PDF",
      loadingMessage: "Generando archivo y guardando en Descargas...",
      downloadTask: () async {
        final bytes = await PdfGenerator.generatePdf(
          quotation: _quotation!,
          ownerInfo: authProv.user,
          config: _config,
          saleData: _saleData,
        );
        return await InvoiceFileService.saveBytesToDownloads(
          bytes: bytes,
          fileName: fileName,
        );
      },
    );
  }

  Future<void> _sharePdf() async {
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final bytes = await PdfGenerator.generatePdf(
      quotation: _quotation!,
      ownerInfo: authProv.user,
      config: _config,
      saleData: _saleData,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: '${_config.documentTitle ?? "Documento"}.pdf',
    );
  }

  Future<void> _printPdf() async {
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final bytes = await PdfGenerator.generatePdf(
      quotation: _quotation!,
      ownerInfo: authProv.user,
      config: _config,
      saleData: _saleData,
    );
    await Printing.layoutPdf(onLayout: (_) => bytes);
  }
}
