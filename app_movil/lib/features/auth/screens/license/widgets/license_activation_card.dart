part of '../license_status_and_activation_screen.dart';

mixin _LicenseActivationCardMixin on _LicenseScreenStateBase {
  /// Revisa si el portapapeles contiene un código válido (`ML9-` o ficha declarativa `MLC1-`).
  @override
  Future<void> _checkClipboardForCode() async {
    if (!mounted || _isCheckingClipboard) return;
    _isCheckingClipboard = true;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim() ?? '';
      final mlc1 = CommercialConfigSyncService.extractMlc1Token(text);
      if (mlc1.isNotEmpty) {
        if (mounted) {
          setState(() {
            _detectedClipboardCode = mlc1;
          });
        }
        return;
      }
      if (_isValidCandidateCode(text)) {
        final extracted = Ed25519LicenseValidator.extractClipboardLicenseToken(
          text,
        );
        if (mounted) {
          setState(() {
            _detectedClipboardCode = extracted;
          });
        }
      } else {
        if (mounted && _detectedClipboardCode != null) {
          setState(() {
            _detectedClipboardCode = null;
          });
        }
      }
    } catch (_) {
    } finally {
      _isCheckingClipboard = false;
    }
  }

  bool _isValidCandidateCode(String text) {
    if (text.isEmpty) return false;
    if (CommercialConfigSyncService.extractMlc1Token(text).isNotEmpty) {
      return true;
    }
    return Ed25519LicenseValidator.extractClipboardLicenseToken(
      text,
    ).isNotEmpty;
  }

  void _openQrScanner({Widget? scannerPreviewOverride}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QrScannerSheet(
        scannerPreviewOverride: scannerPreviewOverride,
        onCodeScanned: (scannedCode) {
          Navigator.of(ctx).pop();
          _codeController.text = scannedCode;
          _activateCode(scannedCode);
        },
      ),
    );
  }

  Future<void> _scanQrFromGallery() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      final controller = MobileScannerController();
      try {
        final code = await QrGalleryDecoderService.decodeFromImagePath(
          picked.path,
          analyzeFile: (path) async {
            final capture = await controller.analyzeImage(path);
            if (capture != null && capture.barcodes.isNotEmpty) {
              return capture.barcodes.first.rawValue;
            }
            return null;
          },
        );

        if (code != null && code.trim().isNotEmpty) {
          _codeController.text = code.trim();
          await _activateCode(code.trim());
          return;
        }

        if (mounted) {
          CustomSnackBar.show(
            context,
            message:
                "No se detectó ningún código QR en la imagen seleccionada.",
            isError: true,
          );
        }
      } finally {
        controller.dispose();
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(
          context,
          message: "No se pudo leer la imagen de galería: ${e.toString()}",
          isError: true,
        );
      }
    }
  }

  @override
  Widget _buildActivationCard(LicenseProvider? licenseProv, bool isDark) {
    final isLoading = (licenseProv?.isLoading ?? false) || _isVerifyingMlc1;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: isDark ? const Color(0xFF1E1E28) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.vpn_key_rounded, size: 20, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Activar Código de Licencia",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              "Ingresa el código proporcionado por soporte oficial o escanea el código QR oficial enviado a tu WhatsApp.",
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),

            // Input de código con botón rápido de pegado
            TextField(
              key: const ValueKey('input_license_activation_code'),
              controller: _codeController,
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
              decoration: InputDecoration(
                hintText: "Ejemplo: ML9-... o MLC1-...",
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
                prefixIcon: const Icon(Icons.key_rounded, size: 18),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.paste_rounded, size: 18),
                  tooltip: "Pegar del portapapeles",
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data?.text != null) {
                      final raw = data!.text!.trim();
                      final mlc1 = CommercialConfigSyncService.extractMlc1Token(
                        raw,
                      );
                      if (mlc1.isNotEmpty) {
                        _codeController.text = mlc1;
                        return;
                      }
                      final extracted =
                          Ed25519LicenseValidator.extractLicenseToken(raw);
                      _codeController.text = extracted.isNotEmpty
                          ? 'ML9-$extracted'
                          : raw;
                    }
                  },
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF14141C)
                    : const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ),
              ),
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 12),

            // Botón Principal de Ancho Completo
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                key: const ValueKey('btn_activate_license_code'),
                onPressed: isLoading
                    ? null
                    : () => _activateCode(_codeController.text),
                icon: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: Text(
                  isLoading ? "Validando..." : "Activar Código de Licencia",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Fila Secundaria de Botones QR con Simetría Geométrica y Misma Altura
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 300;
                final btnCamera = OutlinedButton.icon(
                  onPressed: _openQrScanner,
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 17),
                  label: const Text(
                    "Escanear QR",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    foregroundColor: Colors.blue[700],
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );

                final btnGallery = OutlinedButton.icon(
                  onPressed: isLoading ? null : _scanQrFromGallery,
                  icon: const Icon(
                    Icons.photo_library_rounded,
                    size: 17,
                    color: Colors.teal,
                  ),
                  label: const Text(
                    "QR desde Galería",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    foregroundColor: Colors.teal[800],
                    side: BorderSide(color: Colors.teal.withValues(alpha: 0.4)),
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      btnCamera,
                      const SizedBox(height: 6),
                      btnGallery,
                    ],
                  );
                }

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: btnCamera),
                      const SizedBox(width: 8),
                      Expanded(child: btnGallery),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
