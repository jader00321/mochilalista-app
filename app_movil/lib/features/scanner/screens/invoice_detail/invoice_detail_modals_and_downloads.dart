part of '../invoice_detail_screen.dart';

mixin _InvoiceDetailModalsAndDownloadsMixin on _InvoiceDetailScreenStateBase {
  @override
  void _showStatusDialog(bool isDark) {
    if (_invoice == null) {
      return;
    }

    String tempStatus = _invoice!.estado;
    final List<String> opciones = ['procesando', 'revision', 'completado'];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Cambiar Estado",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateDialog) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: opciones.map((opcion) {
                return RadioListTile<String>(
                  title: Text(
                    opcion.toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(opcion, isDark),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  value: opcion,
                  // ignore: deprecated_member_use
                  groupValue: tempStatus,
                  activeColor: isDark ? Colors.blue[300] : Colors.blue,
                  // ignore: deprecated_member_use
                  onChanged: (val) {
                    setStateDialog(() => tempStatus = val!);
                  },
                );
              }).toList(),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.blue[700] : Colors.blue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              if (tempStatus != _invoice!.estado) {
                _updateInvoice(estado: tempStatus);
              }
            },
            child: const Text(
              "Guardar",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void _showProviderSearchModal(BuildContext context, bool isDark) {
    final invProv = Provider.of<InventoryProvider>(context, listen: false);
    String query = "";

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          final effectiveBottom =
              InteractiveSheetWrapper.getEffectiveBottomPadding(
                context,
                minPadding: kMinDefensiveBottomClearance,
              );
          final filtered = invProv.providers
              .where(
                (p) =>
                    p.nombreEmpresa.toLowerCase().contains(query.toLowerCase()),
              )
              .toList();

          return SafeArea(
            top: false,
            bottom: true,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF23232F) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  children: [
                    Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "Vincular Proveedor",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      autofocus: true,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: "Buscar proveedor registrado...",
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF14141C)
                            : Colors.grey[100],
                      ),
                      onChanged: (val) => setModalState(() => query = val),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.separated(
                        padding: EdgeInsets.only(
                          bottom: effectiveBottom + kModalScrollBottomClearance,
                        ),
                        physics: const BouncingScrollPhysics(),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: isDark ? Colors.white10 : Colors.grey[200],
                        ),
                        itemBuilder: (ctx, i) {
                          final ProviderModel prov = filtered[i];
                          return ListTile(
                            title: Text(
                              prov.nombreEmpresa,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            subtitle: prov.ruc != null
                                ? Text("RUC: ${prov.ruc}")
                                : null,
                            onTap: () {
                              Navigator.pop(ctx);
                              _updateInvoice(proveedorId: prov.id);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showAlreadyDownloadedSheet({
    required File file,
    required bool isPdf,
    required Future<void> Function() onReDownload,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fileName = file.path.split(Platform.pathSeparator).last;
    final dotIndex = fileName.lastIndexOf('.');
    final baseName = dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
    final extension = dotIndex > 0
        ? fileName.substring(dotIndex).toUpperCase()
        : '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return InteractiveSheetWrapper(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E28) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.grey.shade200,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.greenAccent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isPdf
                                ? 'Reporte PDF ya descargado'
                                : 'Foto ya descargada',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'El archivo ya se encuentra en tu carpeta Descargas',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isPdf
                            ? Icons.picture_as_pdf_rounded
                            : Icons.image_rounded,
                        size: 20,
                        color: isPdf ? Colors.redAccent : Colors.blueAccent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          baseName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      if (extension.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isPdf
                                ? Colors.redAccent.withValues(alpha: 0.15)
                                : Colors.blueAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isPdf
                                  ? Colors.redAccent
                                  : Colors.blueAccent,
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            extension,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: isPdf
                                  ? Colors.redAccent
                                  : Colors.blueAccent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark
                        ? Colors.blue.shade700
                        : Colors.blue.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text(
                    'Abrir Archivo',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    OpenFilex.open(file.path);
                  },
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(
                      color: isDark ? Colors.tealAccent : Colors.teal.shade700,
                    ),
                    foregroundColor: isDark
                        ? Colors.tealAccent
                        : Colors.teal.shade800,
                  ),
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text(
                    'Compartir Archivo',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                      await SharePlus.instance.share(
                        ShareParams(
                          files: [XFile(file.path)],
                          text: isPdf
                              ? 'Reporte PDF Factura #${_invoice?.displayId}'
                              : 'Foto Factura #${_invoice?.displayId}',
                        ),
                      );
                    } catch (_) {
                      try {
                        // ignore: deprecated_member_use
                        await Share.shareXFiles([XFile(file.path)]);
                      } catch (_) {}
                    }
                  },
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: isDark
                        ? Colors.grey[400]
                        : Colors.grey[600],
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Volver a Descargar (reemplazar)'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    onReDownload();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Future<void> _handleScannedImageAction([String? providerName]) async {
    if (_invoice == null) {
      return;
    }
    if (_invoice!.imagenUrl.trim().isEmpty ||
        _invoice!.imagenUrl == 'local_ia_scan' ||
        _invoice!.imagenUrl == 'null') {
      CustomSnackBar.show(
        context,
        message:
            "Esta factura no cuenta con una imagen original disponible para descargar.",
        isError: true,
      );
      return;
    }

    if (_downloadedPhotoFile != null && await _downloadedPhotoFile!.exists()) {
      _showAlreadyDownloadedSheet(
        file: _downloadedPhotoFile!,
        isPdf: false,
        onReDownload: () => _executeDownloadImage(providerName),
      );
      return;
    }

    await _executeDownloadImage(providerName);
  }

  Future<void> _executeDownloadImage(String? providerName) async {
    final invProv = Provider.of<InventoryProvider>(context, listen: false);
    final String resolvedProviderName =
        (providerName != null &&
            providerName.isNotEmpty &&
            providerName != "Sin proveedor")
        ? providerName
        : invProv.getProviderName(_invoice!.proveedorId);

    final file = await DownloadFeedbackModal.show(
      context,
      title: "Descargando Imagen",
      loadingMessage:
          "Guardando foto de comprobante en la carpeta Descargas...",
      downloadTask: () => InvoiceFileService.saveScannedImageToDownloads(
        sourcePath: _invoice!.imagenUrl,
        displayId: _invoice!.displayId,
        providerName: resolvedProviderName,
      ),
    );

    if (file != null && mounted) {
      setState(() {
        _downloadedPhotoFile = file;
      });
    }
  }

  @override
  Future<void> _handlePdfReportAction(
    String? providerName, {
    String? providerRuc,
  }) async {
    if (_invoice == null) {
      return;
    }

    if (_downloadedPdfFile != null && await _downloadedPdfFile!.exists()) {
      _showAlreadyDownloadedSheet(
        file: _downloadedPdfFile!,
        isPdf: true,
        onReDownload: () =>
            _executeDownloadPdf(providerName, providerRuc: providerRuc),
      );
      return;
    }

    await _executeDownloadPdf(providerName, providerRuc: providerRuc);
  }

  Future<void> _executeDownloadPdf(
    String? providerName, {
    String? providerRuc,
  }) async {
    final auth = Provider.of<AuthProvider>(context, listen: false).user;
    final invProv = Provider.of<InventoryProvider>(context, listen: false);
    final String resolvedProviderName =
        (providerName != null &&
            providerName.isNotEmpty &&
            providerName != "Sin proveedor")
        ? providerName
        : invProv.getProviderName(_invoice!.proveedorId);
    final provider = invProv.providers
        .where((p) => p.id == _invoice!.proveedorId)
        .firstOrNull;
    final String? resolvedProviderRuc = providerRuc ?? provider?.ruc;

    final file = await DownloadFeedbackModal.show(
      context,
      title: "Generando Reporte PDF",
      loadingMessage:
          "Estructurando auditoría y datos extraídos en formato ejecutivo...",
      downloadTask: () => InvoicePdfReportService.generateAndSavePdfReport(
        invoice: _invoice!,
        providerName: resolvedProviderName,
        providerRuc: resolvedProviderRuc,
        currentUser: auth,
        linkedPresentations: _linkedPresentations,
      ),
    );

    if (file != null && mounted) {
      setState(() {
        _downloadedPdfFile = file;
      });
    }
  }
}
