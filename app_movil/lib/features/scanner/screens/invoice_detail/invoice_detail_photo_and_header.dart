part of '../invoice_detail_screen.dart';

mixin _InvoiceDetailPhotoAndHeaderMixin on _InvoiceDetailScreenStateBase {
  void _openFullscreenPhotoViewer(BuildContext context) {
    if (_invoice == null ||
        _invoice!.imagenUrl.trim().isEmpty ||
        _invoice!.imagenUrl == 'local_ia_scan' ||
        _invoice!.imagenUrl == 'null') {
      return;
    }

    final TransformationController transformController =
        TransformationController();

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.95),
      builder: (ctx) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.black45,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 28,
              ),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            title: Text(
              "Comprobante #${_invoice!.displayId}",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.restart_alt_rounded,
                  color: Colors.white,
                ),
                tooltip: "Restaurar Zoom",
                onPressed: () => transformController.value = Matrix4.identity(),
              ),
              if (_downloadedPhotoFile != null)
                IconButton(
                  icon: const Icon(Icons.share_rounded, color: Colors.white),
                  tooltip: "Compartir Foto",
                  onPressed: () async {
                    try {
                      await SharePlus.instance.share(
                        ShareParams(
                          files: [XFile(_downloadedPhotoFile!.path)],
                          text:
                              'Comprobante #${_invoice!.displayId} - MochilaLista',
                        ),
                      );
                    } catch (_) {
                      try {
                        // ignore: deprecated_member_use
                        await Share.shareXFiles([
                          XFile(_downloadedPhotoFile!.path),
                        ]);
                      } catch (_) {}
                    }
                  },
                ),
            ],
          ),
          body: Center(
            child: GestureDetector(
              onDoubleTapDown: (details) {
                if (transformController.value != Matrix4.identity()) {
                  transformController.value = Matrix4.identity();
                } else {
                  final position = details.localPosition;
                  final matrix = Matrix4.diagonal3Values(2.5, 2.5, 1.0)
                    ..setTranslationRaw(
                      -position.dx * 1.5,
                      -position.dy * 1.5,
                      0.0,
                    );
                  transformController.value = matrix;
                }
              },
              child: InteractiveViewer(
                transformationController: transformController,
                minScale: 1.0,
                maxScale: 6.0,
                child: UniversalImage(
                  path: _invoice!.imagenUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget _buildImageZone() {
    // ZONA 1: VISOR DE IMAGEN
    final bool hasImage =
        _invoice!.imagenUrl.trim().isNotEmpty &&
        _invoice!.imagenUrl != 'local_ia_scan' &&
        _invoice!.imagenUrl != 'null';

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          InteractiveViewer(
            minScale: 1.0,
            maxScale: 5.0,
            child: Center(
              child: !hasImage
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_not_supported_rounded,
                          size: 60,
                          color: Colors.grey[700],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Imagen no disponible\n(Factura Legacy)",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                  : GestureDetector(
                      onTap: () => _openFullscreenPhotoViewer(context),
                      child: UniversalImage(
                        path: _invoice!.imagenUrl,
                        fit: BoxFit.contain,
                      ),
                    ),
            ),
          ),
          if (hasImage)
            Positioned(
              bottom: 12,
              right: 12,
              child: GestureDetector(
                onTap: () => _openFullscreenPhotoViewer(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24, width: 0.8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.fullscreen_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      SizedBox(width: 4),
                      Text(
                        "Pantalla Completa",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
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

  @override
  Widget _buildSummaryHeaderSection({
    required bool isDark,
    required bool isManualInvoice,
    required Color statusColor,
    required String providerName,
    required String? providerRuc,
  }) {
    return Column(
      children: [
        // 1. ESTADO Y FECHA
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Fecha Escaneo:",
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                  ),
                  // 🔧 TAREA 1.4: Mostrar tipo de factura debajo de la fecha
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        isManualInvoice
                            ? Icons.edit_note_rounded
                            : Icons.document_scanner_outlined,
                        size: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          isManualInvoice
                              ? "Factura Manual"
                              : "Escaneada con IA",
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    AppDateFormatter.ddMMMyyyyHhmma.format(
                      _invoice!.fechaCarga.toLocal(),
                    ),
                    style: TextStyle(
                      color: isDark ? Colors.grey[300] : Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => _showStatusDialog(isDark),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Text(
                      _invoice!.estado.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.edit, size: 14, color: statusColor),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 2. MONTO TOTAL Y FECHA EMISIÓN (Visual Impactante)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [Colors.teal.shade900, Colors.teal.shade800]
                  : [Colors.teal.shade50, Colors.white],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.teal.shade700 : Colors.teal.shade100,
            ),
          ),
          child: Column(
            children: [
              Text(
                "MONTO TOTAL FACTURADO",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.teal[200] : Colors.teal[800],
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppCurrency.format(_invoice!.montoTotalFactura),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : Colors.teal[900],
                ),
              ),
              if (_invoice!.fechaEmision != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : Colors.white54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "F. Emisión: ${AppDateFormatter.formatDate(_invoice!.fechaEmision!)}",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.teal[100] : Colors.teal[900],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ACCIONES PROFESIONALES DE DESCARGA
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: _downloadedPhotoFile != null
                    ? const Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: Colors.green,
                      )
                    : const Icon(Icons.download_rounded, size: 18),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _downloadedPhotoFile != null
                        ? "✓ Foto Guardada"
                        : "Descargar Foto",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(
                    color: _downloadedPhotoFile != null
                        ? Colors.green.shade600
                        : (isDark
                              ? Colors.blue.withValues(alpha: 0.5)
                              : Colors.blue.shade300),
                  ),
                  foregroundColor: _downloadedPhotoFile != null
                      ? (isDark ? Colors.greenAccent : Colors.green.shade800)
                      : (isDark ? Colors.blue[300] : Colors.blue[800]),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _handleScannedImageAction(providerName),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                icon: _downloadedPdfFile != null
                    ? const Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: Colors.white,
                      )
                    : const Icon(Icons.picture_as_pdf_rounded, size: 18),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _downloadedPdfFile != null
                        ? "✓ PDF Guardado"
                        : "Reporte PDF",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _downloadedPdfFile != null
                      ? (isDark ? Colors.green.shade800 : Colors.green.shade700)
                      : (isDark ? Colors.teal.shade700 : Colors.teal.shade800),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                onPressed: () => _handlePdfReportAction(
                  providerName,
                  providerRuc: providerRuc,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget _buildProviderCard(bool isDark, String providerName) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF23232F) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "PROVEEDOR VINCULADO",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _showProviderSearchModal(context, isDark),
                child: Text(
                  "Cambiar",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.blue[300] : Colors.blue[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                backgroundColor: isDark
                    ? Colors.blue.withValues(alpha: 0.15)
                    : Colors.blue[50],
                child: Icon(
                  Icons.store,
                  color: isDark ? Colors.blue[300] : Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  providerName.isNotEmpty
                      ? providerName
                      : "Sin proveedor asignado",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
