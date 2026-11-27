part of '../sale_provider.dart';

mixin _SaleActionsAndMorosidadMixin on _SaleProviderBase {
  Future<bool> updateFullClient(
    int clientId,
    Map<String, dynamic> clientData,
  ) async {
    if (_negocioId == null) return false;
    try {
      await _clientService.updateClient(clientId, clientData);
      return true;
    } catch (e) {
      _handleException(e);
      return false;
    }
  }

  Future<bool> updateClientNote(int clientId, String newNote) async {
    if (_negocioId == null) return false;
    try {
      await _clientService.updateClient(clientId, {'notas': newNote});
      return true;
    } catch (e) {
      _handleException(e);
      return false;
    }
  }

  Future<bool> updateQuotationNote(int quotationId, String newNote) async {
    if (_negocioId == null || _usuarioId == null) return false;
    try {
      await _quotationService.saveManualQuotation(
        negocioId: _negocioId!,
        usuarioId: _usuarioId!,
        id: quotationId,
        totalAmount: 0,
        totalSavings: 0,
        items: [],
        notas: newNote,
      );
      final idx = _salesHistory.indexWhere((s) => s.quotationId == quotationId);
      if (idx != -1) {
        _salesHistory[idx] = _salesHistory[idx].copyWith(notes: newNote);
      }
      final mIdx = _masterSales.indexWhere((s) => s.quotationId == quotationId);
      if (mIdx != -1) {
        _masterSales[mIdx] = _masterSales[mIdx].copyWith(notes: newNote);
      }
      notifyListeners();
      return true;
    } catch (e) {
      _handleException(e);
      return false;
    }
  }

  Future<bool> updateSaleNote(int saleId, String newNote) async {
    if (_negocioId == null) return false;
    try {
      final success = await _salesService.updateSaleNote(saleId, newNote);
      if (success) {
        final idx = _salesHistory.indexWhere((s) => s.id == saleId);
        if (idx != -1) {
          _salesHistory[idx] = _salesHistory[idx].copyWith(notes: newNote);
        }
        final mIdx = _masterSales.indexWhere((s) => s.id == saleId);
        if (mIdx != -1) {
          _masterSales[mIdx] = _masterSales[mIdx].copyWith(notes: newNote);
        }
        notifyListeners();
      }
      return success;
    } catch (e) {
      _handleException(e);
      return false;
    }
  }

  Future<SmartQuotationModel?> prepareForSale(
    SmartQuotationModel current,
    int? newClientId,
  ) async {
    if (_negocioId == null || _usuarioId == null) return null;
    _isLoading = true;
    notifyListeners();

    try {
      final bool mustClone =
          current.isTemplate ||
          (current.clientId != null && current.clientId != newClientId);
      if (mustClone) {
        return await _quotationService.cloneQuotation(
          current.id,
          _usuarioId!,
          targetClientId: newClientId,
        );
      }
      return current;
    } catch (e) {
      _handleException(e);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> processCheckout({
    required int quotationId,
    required int? clientId,
    String? clientName,
    String? saleNote,
    required String paymentMethod,
    required String paymentStatus,
    required String deliveryStatus,
    String? deliveryDate,
    required double total,
    required double paid,
    double discount = 0.0,
    double abonoInicial = 0.0,
    double porcentajeInteres = 0.0,
    List<InstallmentModel>? installments,
    String origenVenta = "smart_quotation",
    List<Map<String, dynamic>>? detalleVenta,
    int? recompensaCanjeId,
  }) async {
    if (_negocioId == null || _usuarioId == null) {
      return "Error: Sesión no válida.";
    }

    _isLoading = true;
    notifyListeners();

    try {
      final saleData = {
        "cotizacion_id": origenVenta == "pos_rapido" ? null : quotationId,
        "cliente_id": clientId,
        "client_name_override": clientName,
        "notas": saleNote,
        "origen_venta": origenVenta,
        "metodo_pago": paymentMethod,
        "estado_pago": paymentStatus,
        "estado_entrega": deliveryStatus,
        "fecha_entrega": deliveryDate,
        "monto_total": total,
        "monto_pagado": paid,
        "descuento_aplicado": discount,
        "abono_inicial": abonoInicial,
        "porcentaje_interes": porcentajeInteres,
        "cuotas": installments?.map((e) => e.toJson()).toList() ?? [],
        "items": detalleVenta ?? [],
        if (recompensaCanjeId != null) "recompensa_canje_id": recompensaCanjeId,
      };

      await _salesService.createSale(saleData, _negocioId!, _usuarioId!);
      await loadFilteredHistory(reset: true);
      await loadRecentHomeActivity();
      return null;
    } catch (e) {
      _handleException(e);
      return _errorMessage;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ClientModel?> getClientById(int id) async {
    if (_negocioId == null) return null;
    try {
      return await _clientService.getClientById(id);
    } catch (e) {
      _handleException(e);
      return null;
    }
  }

  Future<List<ClientModel>> searchClients(String query) async {
    if (_negocioId == null || query.isEmpty) return [];
    try {
      return await _clientService.searchClients(query, _negocioId!);
    } catch (e) {
      _handleException(e);
      return [];
    }
  }

  Future<ClientModel?> registerClient(Map<String, dynamic> data) async {
    if (_negocioId == null || _usuarioId == null) return null;
    try {
      return await _clientService.createClient(data, _negocioId!, _usuarioId!);
    } catch (e) {
      _handleException(e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> getSaleDetail(int saleId) async {
    if (_negocioId == null) return null;
    _isLoading = true;
    notifyListeners();

    try {
      final detail = await _salesService.getSaleDetail(saleId);
      if (detail['cliente_id'] != null) {
        final clientData = await getClientById(detail['cliente_id']);
        if (clientData != null && clientData.notes != null) {
          detail['cliente_notas'] = clientData.notes;
        }
      }
      return detail;
    } catch (e) {
      _handleException(e);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _updateListPaymentForSale(
    List<SaleModel> list,
    int saleId,
    double newPaidAmount,
    String? newPaymentStatus,
  ) {
    final idx = list.indexWhere((s) => s.id == saleId);
    if (idx == -1) return;
    final old = list[idx];
    final status =
        newPaymentStatus ??
        (newPaidAmount >= old.trueTotalAmount - 0.01 ? 'pagado' : 'pendiente');
    list[idx] = old.copyWith(paidAmount: newPaidAmount, paymentStatus: status);
  }

  /// Sincroniza inmediatamente un cobro en memoria (_masterSales y _salesHistory)
  /// y recalcula las estadísticas y KPIs a 0ms sin esperar a SQLite.
  void updateSalePaymentInMaster({
    required int saleId,
    required double newPaidAmount,
    String? newPaymentStatus,
  }) {
    _updateListPaymentForSale(
      _masterSales,
      saleId,
      newPaidAmount,
      newPaymentStatus,
    );
    _updateListPaymentForSale(
      _archivedSales,
      saleId,
      newPaidAmount,
      newPaymentStatus,
    );
    _applyTabFilterInMemory();
    notifyListeners();
  }

  Future<bool> updateDeliveryStatus(
    int saleId,
    String newStatus, {
    String? fotoPath,
  }) async {
    if (_negocioId == null) return false;
    _isLoading = true;
    notifyListeners();

    try {
      await _salesService.updateDeliveryStatus(
        saleId,
        newStatus,
        fotoPath: fotoPath,
      );
      return true;
    } catch (e) {
      _handleException(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _syncQuotaSaleAndNotify(
    int cuotaId, {
    int? saleId,
    bool notifyIfUnresolved = true,
  }) async {
    final int? sId = saleId ?? await _salesService.getVentaIdFromCuota(cuotaId);
    if (sId != null) {
      await syncSaleInMemory(sId);
    } else if (notifyIfUnresolved) {
      notifyListeners();
    }
  }

  Future<bool> updateInstallmentDate(
    int cuotaId,
    String newDate, {
    int? saleId,
  }) async {
    if (_negocioId == null) return false;
    _isLoading = true;
    notifyListeners();

    try {
      final success = await _clientService.updateInstallmentDueDate(
        cuotaId,
        newDate,
      );
      if (success) {
        await _syncQuotaSaleAndNotify(
          cuotaId,
          saleId: saleId,
          notifyIfUnresolved: false,
        );
      }
      return success;
    } catch (e) {
      _handleException(e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> voidSale(int saleId, String motivoAnulacion) async {
    if (_negocioId == null) return;
    try {
      await _salesService.voidSale(saleId, _negocioId!, motivoAnulacion);
      final mIdx = _masterSales.indexWhere((element) => element.id == saleId);
      if (mIdx != -1) {
        final archived = _masterSales[mIdx].copyWith(
          isArchived: true,
          motivoAnulacion: motivoAnulacion,
        );
        _masterSales[mIdx] = archived;
        _archivedSales.removeWhere((s) => s.id == saleId);
        _archivedSales.insert(0, archived);
      }
      _applyTabFilterInMemory();
      notifyListeners();
      _loadDynamicStats();
      loadRecentHomeActivity();
    } catch (e) {
      _handleException(e);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> restoreSale(int saleId) async {
    if (_negocioId == null) return;
    try {
      await _salesService.restoreSale(saleId, _negocioId!);
      _archivedSales.removeWhere((s) => s.id == saleId);
      final mIdx = _masterSales.indexWhere((element) => element.id == saleId);
      if (mIdx != -1) {
        _masterSales[mIdx] = _masterSales[mIdx].copyWith(
          isArchived: false,
          motivoAnulacion: null,
        );
      }
      _applyTabFilterInMemory();
      notifyListeners();
      _loadDynamicStats();
      loadRecentHomeActivity();
    } catch (e) {
      _handleException(e);
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getSaleDetailSilently(int saleId) async {
    if (_negocioId == null) return null;
    try {
      final detail = await _salesService.getSaleDetail(saleId);
      if (detail['cliente_id'] != null) {
        final clientData = await getClientById(detail['cliente_id']);
        if (clientData != null && clientData.notes != null) {
          detail['cliente_notas'] = clientData.notes;
        }
      }
      return detail;
    } catch (_) {
      return null;
    }
  }

  Future<void> syncSaleInMemory(int saleId) async {
    try {
      final updated = await _salesService.getSaleModel(saleId);
      if (updated != null) {
        final idx = _salesHistory.indexWhere((s) => s.id == saleId);
        if (idx != -1) {
          _salesHistory[idx] = updated;
        }
        final mIdx = _masterSales.indexWhere((s) => s.id == saleId);
        if (mIdx != -1) {
          _masterSales[mIdx] = updated;
        }
        _applyTabFilterInMemory();
        notifyListeners();
      }
    } catch (_) {}
  }

  // DELEGACIONES DEL MOTOR DE MOROSIDAD

  Future<bool> aplicarMorosidadManual(
    int cuotaId, {
    required String tipo,
    required double valor,
    double? nuevoMontoTotal,
    int? saleId,
  }) async {
    final success = await _salesService.aplicarMorosidadManual(
      cuotaId,
      tipo: tipo,
      valor: valor,
      nuevoMontoTotal: nuevoMontoTotal,
    );
    if (success) {
      await _syncQuotaSaleAndNotify(cuotaId, saleId: saleId);
    }
    return success;
  }

  Future<bool> quitarMorosidad(int cuotaId, {int? saleId}) async {
    final success = await _salesService.quitarMorosidad(cuotaId);
    if (success) {
      await _syncQuotaSaleAndNotify(cuotaId, saleId: saleId);
    }
    return success;
  }

  Future<bool> configurarMorosidadAutomatica(
    int cuotaId, {
    required bool activa,
    String? frecuencia,
    int? intervaloDias,
    String? tipo,
    double? valor,
    bool calcularDesdeVencimiento = true,
    int? saleId,
  }) async {
    final success = await _salesService.configurarMorosidadAutomatica(
      cuotaId,
      activa: activa,
      frecuencia: frecuencia,
      intervaloDias: intervaloDias,
      tipo: tipo,
      valor: valor,
      calcularDesdeVencimiento: calcularDesdeVencimiento,
    );
    if (success) {
      await _syncQuotaSaleAndNotify(cuotaId, saleId: saleId);
    }
    return success;
  }

  Future<void> evaluarMorosidadPeriodica({
    int? ventaId,
    int? clienteId,
    DateTime? referenceDate,
  }) async {
    await _salesService.evaluarMorosidadPeriodica(
      ventaId: ventaId,
      clienteId: clienteId,
      referenceDate: referenceDate,
    );
  }
}
