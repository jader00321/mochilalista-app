part of '../whatsapp_preview_screen.dart';

mixin _WhatsAppStateAndHistoryMixin on _WhatsAppPreviewScreenStateBase {
  static String _normalizePaymentText(String raw) {
    return raw
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'[📱🏦🏛️]\s*'), '')
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .join('\n');
  }

  @override
  void _onMessageEdited(String newText) {
    if (!_isManualEdit) {
      setState(() => _isManualEdit = true);
    }
    if (_isApplyingUndoRedo) return;

    if (_typingDebounceTimer == null || !_typingDebounceTimer!.isActive) {
      if (_lastCommittedText.isNotEmpty && _lastCommittedText != newText) {
        if (_undoStack.isEmpty || _undoStack.last != _lastCommittedText) {
          _undoStack.add(_lastCommittedText);
          if (_undoStack.length > 50) _undoStack.removeAt(0);
          _redoStack.clear();
        }
      }
    }

    _typingDebounceTimer?.cancel();
    _typingDebounceTimer = Timer(const Duration(milliseconds: 350), () {
      _lastCommittedText = newText;
      if (mounted) setState(() {});
    });
  }

  void _recordUndoSnapshot() {
    if (_isApplyingUndoRedo) return;
    _typingDebounceTimer?.cancel();
    final current = _messageCtrl.text;
    if (_undoStack.isEmpty || _undoStack.last != current) {
      _undoStack.add(current);
      if (_undoStack.length > 50) _undoStack.removeAt(0);
      _redoStack.clear();
      _lastCommittedText = current;
      if (mounted) setState(() {});
    }
  }

  void _handleUndo() {
    _typingDebounceTimer?.cancel();
    final currentText = _messageCtrl.text;

    while (_undoStack.isNotEmpty && _undoStack.last == currentText) {
      _undoStack.removeLast();
    }
    if (_undoStack.isEmpty) return;

    HapticFeedback.selectionClick();
    _isApplyingUndoRedo = true;
    _redoStack.add(currentText);
    final previousText = _undoStack.removeLast();
    _messageCtrl.text = previousText;
    _messageCtrl.selection = TextSelection.collapsed(
      offset: previousText.length,
    );
    _lastCommittedText = previousText;
    _isManualEdit = true;
    setState(() {});
    _isApplyingUndoRedo = false;
  }

  void _handleRedo() {
    _typingDebounceTimer?.cancel();
    final currentText = _messageCtrl.text;

    while (_redoStack.isNotEmpty && _redoStack.last == currentText) {
      _redoStack.removeLast();
    }
    if (_redoStack.isEmpty) return;

    HapticFeedback.selectionClick();
    _isApplyingUndoRedo = true;
    _undoStack.add(currentText);
    final nextText = _redoStack.removeLast();
    _messageCtrl.text = nextText;
    _messageCtrl.selection = TextSelection.collapsed(offset: nextText.length);
    _lastCommittedText = nextText;
    _isManualEdit = true;
    setState(() {});
    _isApplyingUndoRedo = false;
  }

  @override
  Future<void> _loadData() async {
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final clientService = ClientService();

    try {
      if (widget.saleId != null) {
        final saleProv = Provider.of<SaleProvider>(context, listen: false);
        _saleData = await saleProv.getSaleDetailSilently(widget.saleId!);
        if (_saleData != null && _saleData!['cotizacion'] != null) {
          _quotation = SmartQuotationModel.fromJson(_saleData!['cotizacion']);
        }
      } else if (widget.quotationId != null) {
        final qProv = Provider.of<SmartQuotationProvider>(
          context,
          listen: false,
        );
        _quotation = await qProv.getQuotationById(widget.quotationId!);
      }

      if (_quotation != null) {
        final rawClientName =
            _saleData?['cliente_nombre'] ?? _quotation!.clientName;
        _clientNameCtrl.text = PdfGenerator.cleanClientDisplayName(
          rawClientName,
        );

        final int? targetClientId =
            _saleData?['cliente_id'] ?? _quotation!.clientId;
        if (targetClientId != null) {
          final clientData = await clientService.getClientById(targetClientId);
          if (clientData != null) {
            _originalClient = clientData;
            _clientNameCtrl.text = PdfGenerator.cleanClientDisplayName(
              clientData.fullName,
            );
            _clientPhoneCtrl.text = clientData.phone;
          }
        } else if (_saleData?['cliente_telefono'] != null) {
          _clientPhoneCtrl.text = _saleData!['cliente_telefono'];
        }

        final biz = authProv.currentBusiness;
        if (biz != null) {
          _originalBizAddress = (biz.address ?? "").trim();
          _originalBizRuc = (biz.ruc ?? "").trim();
          _originalBizPhone = (authProv.user?.phone ?? "").trim();
          _originalBizPayment =
              (biz.paymentInfo != null && biz.paymentInfo!.trim().isNotEmpty)
              ? biz.paymentInfo!.trim()
              : "";
          _originalBizLat = biz.latitud;
          _originalBizLng = biz.longitud;

          _bizAddressCtrl.text = _originalBizAddress;
          _bizRucCtrl.text = _originalBizRuc;
          _bizPhoneCtrl.text = _originalBizPhone;
          _bizPaymentCtrl.text = _originalBizPayment;
          _bizLat = _originalBizLat;
          _bizLng = _originalBizLng;
        }

        _config = await WhatsAppPreferencesService.applySavedPreferences(
          _config,
          contextKey: _currentContextKey,
        );

        final effectiveMode = widget.contextMode ?? _quotation?.contextMode;
        if (effectiveMode != null) {
          switch (effectiveMode) {
            case QuotationContextMode.general:
              _config.style = WhatsAppMessageStyle.commercial;
              break;
            case QuotationContextMode.wholesale:
              _config.style = WhatsAppMessageStyle.wholesale;
              break;
            case QuotationContextMode.school:
              _config.style = WhatsAppMessageStyle.school;
              break;
          }
        }
      }

      _regenerateMessage();
    } catch (e) {
      debugPrint("Error loading WA data: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Actualización reactiva a 0ms cuando cambia el texto del nombre del cliente
  @override
  void _onClientDataChanged() {
    final cleanName = _clientNameCtrl.text.trim();
    if (_isManualEdit) {
      final currentText = _messageCtrl.text;
      final greetingRegex = RegExp(
        r'^¡Hola(?:\s+\*[^*]+\*)?!\s*👋',
        multiLine: true,
      );
      final String newGreeting =
          cleanName.isEmpty || PdfGenerator.isInternalDraftCode(cleanName)
          ? '¡Hola! 👋'
          : '¡Hola *$cleanName*! 👋';
      if (greetingRegex.hasMatch(currentText)) {
        _messageCtrl.text = currentText.replaceFirst(
          greetingRegex,
          newGreeting,
        );
      }
    } else {
      _regenerateMessage();
    }
  }

  List<String> _computeChangedBusinessFields(BusinessModel? biz) {
    final List<String> changed = [];
    if (biz == null) return changed;

    if (_bizPhoneCtrl.text.trim() != _originalBizPhone) {
      changed.add("Teléfono");
    }
    if (_bizRucCtrl.text.trim() != _originalBizRuc) {
      changed.add("RUC");
    }
    final bool isGpsChanged =
        _bizLat != _originalBizLat || _bizLng != _originalBizLng;
    if (_bizAddressCtrl.text.trim() != _originalBizAddress || isGpsChanged) {
      changed.add("Dirección");
    }
    if (_normalizePaymentText(_bizPaymentCtrl.text) !=
        _normalizePaymentText(_originalBizPayment)) {
      changed.add("Cuentas de pago");
    }
    return changed;
  }
}
