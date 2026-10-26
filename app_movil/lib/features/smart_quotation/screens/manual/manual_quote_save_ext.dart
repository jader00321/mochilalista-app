part of '../manual_quotation_screen.dart';

extension _ManualQuoteSaveExt on _ManualQuotationScreenState {

  void _clearWholeList() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool? confirm = await ManualQuoteDialogHelper.showClearWholeListDialog(context, isDark);
    
    if (confirm == true) {
      updateState(() {
        _items.clear(); _quantities.clear(); _overriddenPrices.clear(); _customNames.clear();
        _clearClient(); _quoteTitleCtrl.clear(); _quoteNotesCtrl.clear(); _schoolCtrl.clear(); _gradeCtrl.clear();
        _hasUnsavedChanges = true;
      });
      if (!mounted) return;
      Provider.of<SmartQuotationProvider>(context, listen: false).clearManualDraft();
      _generateDynamicName();
    }
  }

  Future<bool> _onWillPop() async {
    final prov = Provider.of<SmartQuotationProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = Provider.of<AuthProvider>(context, listen: false);

    if (_currentQuotationId == null) {
      if (_items.isNotEmpty || _clientNameCtrl.text.isNotEmpty || _quoteTitleCtrl.text.isNotEmpty) {
        prov.saveManualDraft(
          items: _items, quantities: _quantities, prices: _overriddenPrices, names: _customNames,
          client: _selectedClient, cName: _clientNameCtrl.text, cPhone: _clientPhoneCtrl.text, cDni: _clientDniCtrl.text, 
          cAddr: _clientAddressCtrl.text, cEmail: _clientEmailCtrl.text, cNotes: _clientNotesCtrl.text, school: _schoolCtrl.text, 
          grade: _gradeCtrl.text, qTitle: _quoteTitleCtrl.text, qNotes: _quoteNotesCtrl.text, quotationId: _currentQuotationId,
        );
      }
      return true; 
    }

    if (_currentQuotationId != null && _hasUnsavedChanges && !auth.isCommunityClient) {
      bool? shouldPop = await ManualQuoteDialogHelper.showUnsavedChangesDialog(context, isDark);
      if (shouldPop == true) prov.clearManualDraft(); 
      return shouldPop ?? false;
    }

    return true;
  }

  void _onSellPressed() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    if (!auth.hasActiveContext) {
      _showExplorationModal(context, isDark);
      return;
    }

    if (_items.isEmpty) {
      CustomSnackBar.show(context, message: "Agrega al menos un producto", isError: true);
      return;
    }

    if (auth.isCommunityClient) {
       _showClientOrderConfirmation(isDark);
       return;
    }

    bool hasStockIssues = _items.any((item) => (_quantities[item.presentationId] ?? 1) > item.stock || item.stock <= 0);

    if (hasStockIssues) {
      bool? proceed = await ManualQuoteDialogHelper.showStockIssuesDialog(context, isDark);
      if (proceed == true) _executeSave(status: 'PENDING', type: 'manual', navigateToDetail: true); 
    } else {
      bool? proceed = await ManualQuoteDialogHelper.showConfirmSaleDialog(context, isDark);
      if (proceed == true) _executeSave(status: 'PENDING', type: 'manual', navigateToCheckout: true);
    }
  }

  void _showClientOrderConfirmation(bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Enviar Pedido a Tienda", style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
        content: Text(
          "Tu pedido será enviado al negocio para verificar la disponibilidad de los productos.\n\n"
          "Podrás ver el estado de tu pedido en la sección 'Mis Pedidos'. ¿Deseas enviarlo ahora?",
          style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 16)
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              Navigator.pop(ctx);
              _executeSave(status: 'PENDING_APPROVAL', type: 'manual', navigateToDetail: true, isClientEnd: true);
            },
            child: const Text("Sí, Enviar Pedido", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      )
    );
  }

  void _showExplorationModal(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF23232F) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.explore, color: Colors.orange[400]),
            const SizedBox(width: 10),
            const Text("Modo Exploración", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          "Para guardar esta cotización o enviarla a la caja, necesitas registrar tu propio negocio.\n\n"
          "Dirígete a tu Perfil cuando estés listo para empezar a vender.",
          style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 16, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Entendido", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          )
        ],
      )
    );
  }

  Future<void> _executeSave({required String status, required String type, bool navigateToDetail = false, bool navigateToCheckout = false, bool isClientEnd = false, bool forceClone = false}) async {
    updateState(() => _isSaving = true);
    
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final clientService = ClientService();
    int? finalClientId = _selectedClient?.id;

    if (!authProv.isCommunityClient && _updateClientData && _clientNameCtrl.text.isNotEmpty) {
      final clientData = {
        'nombre_completo': _clientNameCtrl.text, 'telefono': _clientPhoneCtrl.text.replaceAll(" ", ""),
        'dni_ruc': _clientDniCtrl.text, 'direccion': _clientAddressCtrl.text,
        'correo': _clientEmailCtrl.text, 'notas': _clientNotesCtrl.text
      };
      try {
        if (_selectedClient != null) {
          await clientService.updateClient(_selectedClient!.id, clientData);
        } else {
          final newClient = await clientService.createClient(clientData, authProv.activeBusinessId!, authProv.activeUserId!);
          finalClientId = newClient.id;
        }
      } catch (e) { debugPrint("Error saving client: $e"); }
    }

    final itemsPayload = _items.map((item) {
      final qty = _quantities[item.presentationId] ?? 1;
      final manualPrice = _overriddenPrices[item.presentationId];
      
      return {
        "product_id": item.bundleId != null ? null : item.productId, 
        "presentation_id": item.bundleId != null ? null : item.presentationId, 
        "bundle_id": item.bundleId,
        "quantity": qty,
        "unit_price_applied": manualPrice ?? (item.offerPrice ?? item.price), 
        "original_unit_price": item.price, 
        "product_name": item.productName,
        "brand_name": item.brand,
        "specific_name": item.specificName,
        "sales_unit": item.unit,
        "is_manual_price": manualPrice != null, 
        "image_url": item.imageUrl 
      };
    }).toList();

    if (!mounted) return;
    final wbProv = Provider.of<WorkbenchProvider>(context, listen: false);
    final qProv = Provider.of<SmartQuotationProvider>(context, listen: false);
    
    String finalQuoteName = _quoteTitleCtrl.text.trim();

    if (finalQuoteName.isEmpty || finalQuoteName == "Cliente General") {
      finalQuoteName = QuotationNamingEngine.generateTitle(
        selectedClient: _selectedClient,
        typedClientName: _clientNameCtrl.text,
        schoolName: _schoolCtrl.text,
        gradeLevel: _gradeCtrl.text,
        quotationType: type,
        isClientRole: authProv.isCommunityClient,
        clientUserName: authProv.user?.fullName,
      );
    }

    int? targetQuotationId = forceClone ? null : _currentQuotationId;

    final newId = await wbProv.saveManualQuotation(
      id: targetQuotationId, clientId: finalClientId, clientName: finalQuoteName, notas: _quoteNotesCtrl.text,
      institution: _schoolCtrl.text, grade: _gradeCtrl.text, totalAmount: _totalAmount, totalSavings: _totalSavings,
      items: itemsPayload, status: status, type: type 
    );

    if (mounted) {
      updateState(() { _isSaving = false; _hasUnsavedChanges = false; });

      if (newId != null) {
        _currentQuotationId = newId;
        qProv.clearManualDraft(); 

        if (isClientEnd) {
           CustomSnackBar.show(context, message: "¡Tu pedido fue enviado a la tienda!", isError: false);
           Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ClientOrdersScreen()));
           return;
        }

        if (navigateToCheckout) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => SalesCheckoutScreen(quotationId: newId)));
        } else if (navigateToDetail) {
          if (widget.quotationId != null && widget.quotationId == newId) {
            Navigator.pop(context, true);
          } else {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => QuotationDetailScreen(quotationId: newId)));
          }
        } else {
          CustomSnackBar.show(context, message: forceClone ? "Pedido clonado exitosamente" : "Guardado exitosamente", isError: false);
        }
      } else {
        CustomSnackBar.show(context, message: "Error al guardar localmente", isError: true);
      }
    }
  }

  void _openSaveModal() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (!auth.hasActiveContext) {
      _showExplorationModal(context, isDark);
      return;
    }

    if (_items.isEmpty) {
      CustomSnackBar.show(context, message: "La lista está vacía", isError: true);
      return;
    }
    
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (ctx) => ManualQuoteSaveModal(
        isEditing: _currentQuotationId != null,
        isAppOrder: _isAppOrder,
        onSave: (status, type, {bool forceClone = false}) {
          String finalStatus = status == 'MAINTAIN_CURRENT' ? (widget.quotationSnapshot?.status ?? 'DRAFT') : status;
          _executeSave(status: finalStatus, type: type, navigateToDetail: true, forceClone: forceClone);
        },
      ),
    );
  }

}

