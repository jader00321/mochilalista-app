part of '../manual_quotation_screen.dart';

extension _ManualQuoteDataExt on _ManualQuotationScreenState {
  
  double get _totalAmount {
    return _items.fold(0.0, (sum, item) {
      final price = _overriddenPrices[item.presentationId] ?? (item.offerPrice ?? item.price);
      return sum + (price * (_quantities[item.presentationId] ?? 1)); 
    });
  }

  double get _totalSavings {
    double totalListPrice = _items.fold(0.0, (sum, item) => sum + (item.price * (_quantities[item.presentationId] ?? 1)));
    final savings = totalListPrice - _totalAmount;
    return savings > 0 ? savings : 0.0;
  }

  void _generateDynamicName() async {
    if (_isGeneratingName) return;
    
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    bool shouldGenerate = _quoteTitleCtrl.text.isEmpty || 
                          _quoteTitleCtrl.text.startsWith("Cotización") ||
                          _quoteTitleCtrl.text.contains("- Pedido") ||
                          _quoteTitleCtrl.text == "Cliente General";

    if (shouldGenerate) {
        _isGeneratingName = true;
        final prov = Provider.of<SmartQuotationProvider>(context, listen: false);
        
        final newName = await prov.generateDynamicQuoteName(
            _selectedClient, 
            _clientNameCtrl.text, 
            isClientRole: auth.isCommunityClient,
            clientUserName: auth.user?.fullName,
            type: 'manual' 
        );
        
        if (mounted && _quoteTitleCtrl.text != newName) {
           _quoteTitleCtrl.text = newName;
        }
        _isGeneratingName = false;
    }
  }

  Future<void> _initData() async {
    final prov = Provider.of<SmartQuotationProvider>(context, listen: false);

    if (widget.initialItems != null && widget.initialItems!.isNotEmpty) {
      updateState(() {
        _items = List.from(widget.initialItems!);
        for (var item in _items) {
          int qty = widget.initialQuantities?[item.presentationId] ?? 1;
          _quantities[item.presentationId] = qty; 
        }
        _hasUnsavedChanges = true; 
      });
      _generateDynamicName();
      return;
    }

    if (_currentQuotationId != null) {
      updateState(() => _isLoading = true);
      final invProv = Provider.of<InventoryProvider>(context, listen: false); 
      final clientService = ClientService();
      final authProv = Provider.of<AuthProvider>(context, listen: false);
      final promoProv = Provider.of<PromotionProvider>(context, listen: false);
      
      SmartQuotationModel? data = widget.quotationSnapshot ?? await prov.getQuotationById(_currentQuotationId!);

      if (data != null) {
        _quoteTitleCtrl.text = data.clientName ?? "";
        _quoteNotesCtrl.text = data.notas ?? "";
        _schoolCtrl.text = data.institutionName ?? "";
        _gradeCtrl.text = data.gradeLevel ?? "";
        
        _isAppOrder = (data.clientName ?? "").contains("- Pedido");
        
        if (data.clientId != null && !authProv.isCommunityClient) {
          try {
            final client = await clientService.getClientById(data.clientId!);
            if (client != null) {
              _selectedClient = client;
              _clientNameCtrl.text = client.fullName;
              _clientPhoneCtrl.text = client.phone;
              _clientDniCtrl.text = client.docNumber ?? "";
              _clientAddressCtrl.text = client.address ?? "";
              _clientEmailCtrl.text = client.email ?? "";
              _clientNotesCtrl.text = client.notes ?? "";
            }
          } catch (_) {}
        }

        List<MatchedProduct> convertedItems = [];
        int outdatedItemsCount = 0; 

        for (var qItem in data.items) {
          int realStock = 0;
          String? realImageUrl = qItem.imageUrl;
          String currentUnit = qItem.salesUnit ?? "Unidad";
          int currentConversion = 1;
          
          String realProductName = qItem.productName ?? "";
          String realBrandName = qItem.brandName ?? "";
          String realSpecificName = qItem.specificName ?? "";
          double currentPrice = qItem.originalUnitPrice;
          double? currentOffer;
          
          if (qItem.bundleId != null) {
            try {
              final bundle = promoProv.bundles.firstWhere((b) => b.id == qItem.bundleId);
              realStock = promoProv.calculateBundleMaxStock(qItem.bundleId!);
              realImageUrl = bundle.imagenUrl;
              currentUnit = "Paquete";
              currentConversion = 1;
              
              realProductName = bundle.nombrePaquete;
              realBrandName = "OFERTA";
              realSpecificName = bundle.descripcion ?? "";
              
              currentPrice = bundle.precioVentaTotal;
            } catch(e) { debugPrint("Paquete no encontrado: $e"); }
          } else {
            try {
              final realProduct = await invProv.fetchProductById(qItem.productId ?? 0);
              if (realProduct != null) {
                 final presIndex = realProduct.presentaciones.indexWhere((p) => p.id == qItem.presentationId);
                 if (presIndex != -1) {
                   final pres = realProduct.presentaciones[presIndex];
                   realStock = pres.stockActual;
                   realImageUrl = pres.imagenUrl ?? realProduct.imagenUrl;
                   currentUnit = pres.unidadVenta ?? "Unidad";
                   currentConversion = pres.unidadesPorVenta;
                   
                   realProductName = realProduct.nombre;
                   realBrandName = realProduct.marcaNombre ?? qItem.brandName ?? "";
                   realSpecificName = pres.nombreEspecifico ?? "";
                   
                   currentPrice = pres.precioVentaFinal;
                   currentOffer = (pres.precioOferta != null && pres.precioOferta! > 0) 
                       ? pres.precioOferta 
                       : null;
                 }
              }
            } catch(e) { debugPrint("Producto no encontrado: $e"); }
          }

          bool isOutdated = false;
          if (realProductName != (qItem.productName ?? "")) isOutdated = true;
          if (realSpecificName != (qItem.specificName ?? "")) isOutdated = true;
          
          final effectivePrice = currentOffer ?? currentPrice;
          if (!qItem.isManualPrice && (qItem.unitPriceApplied - effectivePrice).abs() > 0.01) isOutdated = true;
          
          // Detección especial para bundles si su composición interna hizo que el maxStock cayera
          if (qItem.bundleId != null && realStock < qItem.quantity) isOutdated = true;
          
          if (isOutdated) outdatedItemsCount++;

          final matched = MatchedProduct(
            productId: qItem.productId ?? 0, 
            presentationId: qItem.bundleId != null ? -(qItem.bundleId!) : (qItem.presentationId ?? 0),
            fullName: qItem.bundleId != null ? realProductName : qItem.displayName,
            productName: realProductName,
            specificName: realSpecificName,
            brand: realBrandName,
            price: currentPrice,
            offerPrice: currentOffer, 
            stock: realStock, 
            imageUrl: realImageUrl, 
            unit: currentUnit,
            conversionFactor: currentConversion,
            isOriginalItem: true,
            bundleId: qItem.bundleId,
          );

          
          _quantities[matched.presentationId] = qItem.quantity;
          
          if (qItem.isManualPrice) {
             _overriddenPrices[matched.presentationId] = qItem.unitPriceApplied;
          } else if (!qItem.isManualPrice && qItem.bundleId == null) {
             if ((qItem.unitPriceApplied - effectivePrice).abs() > 0.01) {
                 _overriddenPrices[matched.presentationId] = qItem.unitPriceApplied;
             }
          }
          
          if (qItem.productName == null || qItem.productName!.isEmpty) {
              _customNames[matched.presentationId] = qItem.displayName;
          }

          convertedItems.add(matched);
        }
        
        updateState(() { 
           _items = convertedItems; 
           _hasUnsavedChanges = false; 
           _outdatedItemsCount = outdatedItemsCount;
        });
      }
      if (mounted) updateState(() => _isLoading = false);
      return;
    }

    if (prov.hasManualDraft && _currentQuotationId == null) {
      updateState(() {
        _items = List.from(prov.draftManualItems!);
        _quantities.addAll(prov.draftManualQuantities!);
        _overriddenPrices.addAll(prov.draftManualPrices!);
        _customNames.addAll(prov.draftManualNames!);
        if (prov.draftClient != null) _selectClient(prov.draftClient!);
        
        _clientNameCtrl.text = prov.draftClientName ?? ""; _clientPhoneCtrl.text = prov.draftClientPhone ?? "";
        _clientDniCtrl.text = prov.draftClientDni ?? ""; _clientAddressCtrl.text = prov.draftClientAddress ?? "";
        _clientEmailCtrl.text = prov.draftClientEmail ?? ""; _clientNotesCtrl.text = prov.draftClientNotes ?? "";
        
        _quoteTitleCtrl.text = prov.draftQuoteTitle ?? ""; _quoteNotesCtrl.text = prov.draftQuoteNotes ?? "";
        _schoolCtrl.text = prov.draftSchool ?? ""; _gradeCtrl.text = prov.draftGrade ?? "";
        
        _currentQuotationId = prov.draftQuotationId;
        _hasUnsavedChanges = true; 
      });
    } else {
        _generateDynamicName();
    }
  }
}

