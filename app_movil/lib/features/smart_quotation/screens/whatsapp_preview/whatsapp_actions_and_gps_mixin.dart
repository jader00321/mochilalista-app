part of '../whatsapp_preview_screen.dart';

mixin _WhatsAppActionsAndGpsMixin on _WhatsAppPreviewScreenStateBase {
  /// Hidrata las rutas locales de fotos de productos desde SQLite para ítems sin imagen
  @override
  Future<void> _hydrateProductImages() async {
    if (_quotation == null || _quotation!.items.isEmpty) return;
    try {
      final db = await LocalDatabase.instance.database;
      final List<QuotationItem> updatedItems = [];

      for (final item in _quotation!.items) {
        if ((item.imageUrl == null || item.imageUrl!.trim().isEmpty) &&
            item.productId != null) {
          final res = await db.query(
            'productos',
            columns: ['imagen_url'],
            where: 'id = ?',
            whereArgs: [item.productId],
            limit: 1,
          );
          if (res.isNotEmpty && res.first['imagen_url'] != null) {
            final String? dbImg = res.first['imagen_url'] as String?;
            if (dbImg != null && dbImg.isNotEmpty) {
              updatedItems.add(
                QuotationItem(
                  id: item.id,
                  productId: item.productId,
                  presentationId: item.presentationId,
                  bundleId: item.bundleId,
                  productName: item.productName,
                  brandName: item.brandName,
                  specificName: item.specificName,
                  salesUnit: item.salesUnit,
                  quantity: item.quantity,
                  unitPriceApplied: item.unitPriceApplied,
                  originalUnitPrice: item.originalUnitPrice,
                  isAvailable: item.isAvailable,
                  isManualPrice: item.isManualPrice,
                  originalText: item.originalText,
                  imageUrl: dbImg,
                ),
              );
              continue;
            }
          }
        }
        updatedItems.add(item);
      }
      _quotation = _quotation!.copyWith(items: updatedItems);
    } catch (e) {
      debugPrint(
        "⚠️ Error hidratando fotos de productos desde SQLite en WhatsAppPreviewScreen: $e",
      );
    }
  }

  void _showClientSelectorModal(bool isDark) {
    ClientSearchModal.show(
      context,
      onClientSelected: (client) {
        setState(() {
          _selectedClient = client;
          _isUsingSelectedClient = true;
          _clientNameCtrl.text = PdfGenerator.cleanClientDisplayName(
            client.fullName,
          );
          _clientPhoneCtrl.text = client.phone;
          _onClientDataChanged();
        });
      },
    );
  }

  Future<void> _fillCurrentLocation() async {
    setState(() => _isGpsLoading = true);
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception(
          "El GPS está desactivado. Actívalo e intenta de nuevo.",
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception("Permiso de ubicación denegado.");
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          "Permiso denegado permanentemente. Habilítalo en configuración.",
        );
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (mounted) {
        setState(() {
          _bizLat = position.latitude;
          _bizLng = position.longitude;
          _regenerateMessage();
        });
        AppFeedbackHelper.showSuccess(context, "Ubicación agregada con éxito");
      }
    } catch (e) {
      if (mounted) {
        AppFeedbackHelper.showError(
          context,
          e.toString().replaceAll("Exception:", "").trim(),
        );
      }
    } finally {
      if (mounted) setState(() => _isGpsLoading = false);
    }
  }

  void _showFinalPreviewModal(bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => WaFinalPreviewModal(
        isDark: isDark,
        phone: _clientPhoneCtrl.text,
        messageCtrl: _messageCtrl,
        onMessageChanged: (text) {
          _onMessageEdited(text);
        },
        onSend: () {
          Navigator.pop(ctx);
          _executeSendProcess();
        },
        onSharePdfAndMessage: _quotation != null
            ? () {
                Navigator.pop(ctx);
                _sharePdfAndMessage();
              }
            : null,
      ),
    );
  }
}
