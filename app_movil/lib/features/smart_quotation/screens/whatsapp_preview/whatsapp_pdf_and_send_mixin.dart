part of '../whatsapp_preview_screen.dart';

mixin _WhatsAppPdfAndSendMixin on _WhatsAppPreviewScreenStateBase {
  /// Ejecuta la persistencia de datos del negocio y cliente si el usuario marcó las casillas correspondientes
  Future<void> _persistPendingDataIfRequested() async {
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final clientService = ClientService();
    bool savingError = false;

    if (authProv.activeBusinessId == null || authProv.activeUserId == null) {
      return;
    }

    if (_config.updateBusinessData) {
      try {
        bool showAddress = true;
        bool showRuc = true;

        final biz = authProv.currentBusiness;
        if (biz != null &&
            biz.printerConfig != null &&
            biz.printerConfig!.isNotEmpty) {
          try {
            final Map<String, dynamic> prefs = json.decode(biz.printerConfig!);
            showAddress = prefs['show_address'] ?? true;
            showRuc = prefs['show_ruc'] ?? true;
          } catch (_) {}
        }

        await authProv.updateBusinessProfile(
          authProv.businessName,
          _bizRucCtrl.text,
          _bizAddressCtrl.text,
          _bizPaymentCtrl.text,
          _bizLat,
          _bizLng,
          showAddress,
          showRuc,
        );

        // Actualización atómica del teléfono del titular en usuarios y AuthProvider
        if (authProv.user != null && _bizPhoneCtrl.text.trim().isNotEmpty) {
          await authProv.updateUserProfile(
            authProv.user!.fullName,
            _bizPhoneCtrl.text.trim(),
            email: authProv.user!.email,
          );
        }
      } catch (e) {
        savingError = true;
      }
    }

    final cleanPhone = _clientPhoneCtrl.text.replaceAll(RegExp(r'\D'), '');

    if (_config.updateClientData && _clientNameCtrl.text.trim().isNotEmpty) {
      try {
        final clientData = {
          'nombre_completo': _clientNameCtrl.text.trim(),
          'telefono': cleanPhone,
        };
        if (_isUsingSelectedClient && _selectedClient != null) {
          await clientService.updateClient(_selectedClient!.id, clientData);
        } else if (_originalClient != null && !_isUsingSelectedClient) {
          await clientService.updateClient(_originalClient!.id, clientData);
        } else {
          await clientService.createClient(
            clientData,
            authProv.activeBusinessId!,
            authProv.activeUserId!,
          );
        }
      } catch (e) {
        savingError = true;
      }
    }

    if (savingError) {
      if (mounted) {
        AppFeedbackHelper.showError(
          context,
          "Datos guardados con advertencias",
        );
      }
    } else if ((_config.updateBusinessData || _config.updateClientData) &&
        mounted) {
      AppFeedbackHelper.showSuccess(
        context,
        "Datos actualizados correctamente",
      );
    }
  }

  /// Sincronización Total de Compartir PDF + Texto con hidratación de imágenes y preferencias
  @override
  Future<void> _sharePdfAndMessage() async {
    if (_quotation == null) return;
    try {
      await _persistPendingDataIfRequested();
      if (!mounted) return;

      final authProv = Provider.of<AuthProvider>(context, listen: false);
      final bool isLoan = _currentContextKey == 'loan';

      final initialPdfConfig = PdfConfig(
        documentTitle: isLoan
            ? "COMPROBANTE DE PRÉSTAMO"
            : (_saleData != null ? "COMPROBANTE DE PAGO" : "COTIZACIÓN"),
        customClientName: _clientNameCtrl.text.trim().isNotEmpty
            ? _clientNameCtrl.text.trim()
            : null,
        showTransactionDetails: !isLoan,
        showInstallments:
            isLoan || (_saleData != null && _saleData!['cuotas'] != null),
      );

      final finalPdfConfig = await PdfPreferencesService.applySavedPreferences(
        initialPdfConfig,
      );

      if (finalPdfConfig.showImages) {
        await _hydrateProductImages();
      }

      UserModel? effectiveOwner = authProv.user;
      final currentBiz = authProv.currentBusiness;
      if (effectiveOwner != null && currentBiz != null) {
        final updatedBiz = BusinessModel(
          id: currentBiz.id,
          commercialName: currentBiz.commercialName,
          ruc: _bizRucCtrl.text.isNotEmpty ? _bizRucCtrl.text : currentBiz.ruc,
          address: _bizAddressCtrl.text.isNotEmpty
              ? _bizAddressCtrl.text
              : currentBiz.address,
          logoUrl: currentBiz.logoUrl,
          printerConfig: currentBiz.printerConfig,
          paymentInfo: _bizPaymentCtrl.text.isNotEmpty
              ? _bizPaymentCtrl.text
              : currentBiz.paymentInfo,
          moneda: currentBiz.moneda,
          latitud: _bizLat ?? currentBiz.latitud,
          longitud: _bizLng ?? currentBiz.longitud,
        );
        effectiveOwner = UserModel(
          id: effectiveOwner.id,
          fullName: effectiveOwner.fullName,
          phone: _bizPhoneCtrl.text.isNotEmpty
              ? _bizPhoneCtrl.text
              : effectiveOwner.phone,
          email: effectiveOwner.email,
          isActive: effectiveOwner.isActive,
          codigoUnicoUsuario: effectiveOwner.codigoUnicoUsuario,
          business: updatedBiz,
        );
      }

      final pdfBytes = await PdfGenerator.generatePdf(
        quotation: _quotation!,
        ownerInfo: effectiveOwner,
        config: finalPdfConfig,
        saleData: _saleData,
      );

      final tempDir = await getTemporaryDirectory();
      final fileName = "MochilaLista_${_quotation!.id}.pdf";
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(pdfBytes, flush: true);

      // ignore: deprecated_member_use
      await Share.shareXFiles([XFile(file.path)], text: _messageCtrl.text);
    } catch (e) {
      debugPrint("Error sharing PDF and WA message: $e");
      if (mounted) {
        AppFeedbackHelper.showError(context, "Error al compartir PDF: $e");
      }
    }
  }

  @override
  Future<void> _executeSendProcess() async {
    await _persistPendingDataIfRequested();
    if (!mounted) return;

    final Uri url = WhatsAppUriBuilder.buildSendUri(
      phone: _clientPhoneCtrl.text,
      message: _messageCtrl.text,
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        AppFeedbackHelper.showError(context, "No se pudo abrir WhatsApp");
      }
    } catch (e) {
      debugPrint("Error launching WA: $e");
    }
  }
}
