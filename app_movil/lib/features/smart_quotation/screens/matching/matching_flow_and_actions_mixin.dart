part of '../matching_screen.dart';

mixin _MatchingFlowAndActionsMixin on _MatchingScreenBase {
  @override
  void _syncAutoTitle({bool force = false}) {
    if (_isGeneratingTitle) return;
    if (!_isAutoTitleMode && !force) return;

    final provider = Provider.of<MatchingProvider>(context, listen: false);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _isGeneratingTitle = true;

    final newTitle = QuotationNamingEngine.generateTitle(
      selectedClient: provider.selectedClient,
      typedClientName: _clientNameCtrl.text,
      schoolName: _schoolCtrl.text,
      gradeLevel: _gradeCtrl.text,
      quotationType: 'ai_scan',
      isClientRole: auth.isCommunityClient,
      clientUserName: auth.user?.fullName,
      contextMode: _currentMode,
    );

    if (mounted && _quoteTitleCtrl.text != newTitle) {
      _quoteTitleCtrl.text = newTitle;
      _isAutoTitleMode = true;
    }
    _isGeneratingTitle = false;
  }

  @override
  void _restoreAutoTitle() {
    setState(() => _isAutoTitleMode = true);
    _syncAutoTitle(force: true);
  }

  ScreenTourConfig _buildTourConfig() {
    return MatchingTour.buildConfig(
      keys: _tourKeys,
      onExpandClientPanel: _expandClientPanelForTour,
      onRestoreClientPanel: _restoreClientPanelAfterTour,
      onExpandQuoteData: _expandQuoteDataForTour,
      onRestoreQuoteData: _restoreQuoteDataAfterTour,
    );
  }

  void _startTour(BuildContext context) {
    InteractiveTourService.startManualTour(context, _buildTourConfig());
  }

  void _maybeStartAutoTour() {
    if (!widget.autoTriggerTour || _didAttemptAutoTour || !mounted) return;
    _didAttemptAutoTour = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await InteractiveTourService.maybeStartAutomaticTour(
        context,
        _buildTourConfig(),
      );
    });
  }

  @override
  void _updateHeader() {
    Provider.of<MatchingProvider>(context, listen: false).updateMetadata(
      institution: _schoolCtrl.text,
      student: _clientNameCtrl.text,
      grade: _gradeCtrl.text,
    );
  }

  void _selectClient(ClientModel client) {
    setState(() {
      _updateClientData = true;
      _clientNameCtrl.text = client.fullName;
      _clientPhoneCtrl.text = client.phone;
      _clientDniCtrl.text = client.docNumber ?? "";
      _clientAddressCtrl.text = client.address ?? "";
      _clientEmailCtrl.text = client.email ?? "";
      _clientNotesCtrl.text = client.notes ?? "";
    });
    Provider.of<MatchingProvider>(context, listen: false).setClient(client);
    _syncAutoTitle(force: true);
  }

  @override
  void _clearClient() {
    setState(() {
      _updateClientData = true;
      _clientNameCtrl.clear();
      _clientPhoneCtrl.clear();
      _clientDniCtrl.clear();
      _clientAddressCtrl.clear();
      _clientEmailCtrl.clear();
      _clientNotesCtrl.clear();
    });
    Provider.of<MatchingProvider>(context, listen: false).setClient(null);
    _syncAutoTitle(force: true);
  }

  @override
  void _showClientSearch(bool isDark) {
    ClientSearchModal.show(
      context,
      onClientSelected: (client) {
        _selectClient(client);
      },
    );
  }

  Future<bool> _onWillPop(bool isDark) async {
    final provider = Provider.of<MatchingProvider>(context, listen: false);
    if (provider.pairs.isEmpty) {
      provider.clearState();
      return true;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "¿Pausar Pedido?",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          "Tu progreso no se perderá. Podrás continuar editando esta lista cuando vuelvas a abrir el escáner.\n\n¿Deseas salir al menú principal?",
          style: TextStyle(
            color: isDark ? Colors.grey[300] : Colors.grey[700],
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              "Quedarme",
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[800],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "Pausar y Salir",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
    );
    return confirm ?? false;
  }

  Future<void> _handleActionWithConfirmation(
    String actionType,
    bool isDark,
  ) async {
    final provider = Provider.of<MatchingProvider>(context, listen: false);
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final isClient = authProv.isCommunityClient;

    if (isClient) {
      bool hasInvalidStock = false;
      for (final pair in provider.pairs) {
        if (pair.selectedProduct != null) {
          if (pair.selectedProduct!.stock <= 0 ||
              pair.selectedQuantity > pair.selectedProduct!.stock) {
            hasInvalidStock = true;
            break;
          }
        }
      }

      if (hasInvalidStock) {
        AppFeedbackHelper.showError(
          context,
          "Tienes productos agotados o que superan el stock disponible. Ajusta las cantidades para enviar el pedido.",
        );
        return;
      }
    }

    final bool hasWarnings = provider.hasStockWarnings;

    String title = "Guardar Cotización";
    String content =
        "Se generará la lista final en estado 'Pendiente' en tu Mesa de Trabajo.";
    String btnText = "Confirmar";
    bool showWarningIcon = false;

    if (actionType == 'client_send') {
      title = "Enviar Pedido a Tienda";
      content =
          "Tu pedido será enviado al negocio para verificar la disponibilidad. Podrás ver el estado en 'Mis Pedidos'.";
      btnText = "Enviar Pedido";
    } else if (hasWarnings &&
        (actionType == 'pdf' || actionType == 'whatsapp')) {
      title = "Problemas de Stock";
      content =
          "Tu lista contiene productos agotados o que superan el stock disponible.\n\n¿Estás seguro de que deseas guardar y generar el documento para el cliente?";
      btnText = "Generar Igual";
      showWarningIcon = true;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: showWarningIcon
            ? Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: isDark ? Colors.red[400] : Colors.red[800],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: isDark ? Colors.red[400] : Colors.red[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              )
            : Text(
                title,
                style: TextStyle(
                  color: hasWarnings
                      ? (isDark ? Colors.red[400] : Colors.red[800])
                      : (isDark ? Colors.white : Colors.black),
                  fontWeight: FontWeight.bold,
                ),
              ),
        content: Text(
          content,
          style: TextStyle(
            color: isDark ? Colors.grey[300] : Colors.grey[700],
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              "Cancelar",
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: hasWarnings
                  ? (isDark ? Colors.red[800] : Colors.red)
                  : (isClient ? Colors.green[700] : Colors.blue[800]),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              btnText,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final int? newId = await provider.saveQuotation(
      isClient ? 'PENDING_APPROVAL' : 'PENDING',
      manualClientName: _clientNameCtrl.text,
      manualClientPhone: _clientPhoneCtrl.text,
      manualClientDni: _clientDniCtrl.text,
      manualClientAddress: _clientAddressCtrl.text,
      manualClientEmail: _clientEmailCtrl.text,
      manualClientNotes: _clientNotesCtrl.text,
      updateClientData: _updateClientData,
      institutionName: _schoolCtrl.text,
      gradeLevel: _gradeCtrl.text,
      type: 'ai_scan',
      isClientRole: isClient,
      quoteTitle: _quoteTitleCtrl.text.trim(),
      quoteNotes: _quoteNotesCtrl.text.trim(),
      contextMode: _currentMode,
    );

    if (newId != null && mounted) {
      provider.clearState();
      Provider.of<SmartQuotationProvider>(context, listen: false).clearState();

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );

      if (actionType == 'client_send') {
        AppFeedbackHelper.showSuccess(
          context,
          "¡Tu pedido fue enviado a la tienda!",
        );
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ClientOrdersScreen()),
        );
      } else if (actionType == 'save') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WorkbenchScreen()),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => QuotationDetailScreen(quotationId: newId),
          ),
        );
        final activeMode = _currentMode;
        if (actionType == 'pdf') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  PdfPreviewScreen(quotationId: newId, contextMode: activeMode),
            ),
          );
        } else if (actionType == 'whatsapp') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WhatsAppPreviewScreen(
                quotationId: newId,
                contextMode: activeMode,
              ),
            ),
          );
        }
      }
    } else if (mounted) {
      AppFeedbackHelper.showError(context, "Error: ${provider.errorMessage}");
    }
  }

  void _resetToInitial(bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              Icons.settings_backup_restore,
              color: isDark ? Colors.orange[300] : Colors.orange,
              size: 28,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Reiniciar Análisis",
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          "¿Estás seguro de volver al estado original escaneado por la IA? Perderás tus modificaciones manuales y el cliente seleccionado.",
          style: TextStyle(
            color: isDark ? Colors.grey[300] : Colors.grey[700],
            fontSize: 15,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              "Cancelar",
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[800],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              final provider = Provider.of<MatchingProvider>(
                context,
                listen: false,
              );

              provider.resetToInitialState();

              setState(() {
                _updateClientData = true;
                _schoolCtrl.text = provider.metadata?.institutionName ?? "";
                _gradeCtrl.text = provider.metadata?.gradeLevel ?? "";
                _clientNameCtrl.text = provider.metadata?.studentName ?? "";

                _clientPhoneCtrl.clear();
                _clientDniCtrl.clear();
                _clientAddressCtrl.clear();
                _clientEmailCtrl.clear();
                _clientNotesCtrl.clear();
                _isAutoTitleMode = true;
              });
              _syncAutoTitle(force: true);
            },
            child: const Text(
              "Sí, reiniciar",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
