part of '../sale_provider.dart';

mixin _SaleHistoryLoaderMixin on _SaleProviderBase {
  Future<void> silentRefresh() async {
    if (_negocioId == null) return;
    try {
      final bool isArchivedTab = _currentTab == "archivadas";
      final targetLimit =
          (_masterSales.length > _salesHistory.length
                  ? _masterSales.length
                  : _salesHistory.length)
              .clamp(_limit, 500);

      final newSales = await _salesService.getHistory(
        _negocioId!,
        skip: 0,
        limit: targetLimit,
        startDate: _currentStartDate,
        endDate: _currentEndDate,
        searchQuery: _searchQuery,
        isArchived: isArchivedTab,
        origenVenta: null,
        sortBy: _currentSortBy,
        order: _currentOrder,
        financialStatus: _financialStatus != 'todos' ? _financialStatus : null,
      );

      if (isArchivedTab) {
        _mergeArchivedSales(newSales, replace: true);
      } else {
        _mergeSales(newSales, replace: true);
      }

      _applyTabFilterInMemory();
      _currentSkip = isArchivedTab
          ? _archivedSales.length
          : _masterSales.length;
      _hasMoreData = newSales.length >= targetLimit;

      _currentStats = await _salesService.getStats(
        _negocioId!,
        startDate: _currentStartDate,
        endDate: _currentEndDate,
        isArchived: isArchivedTab,
        origenVenta: null,
        financialStatus: _financialStatus != 'todos' ? _financialStatus : null,
      );

      await loadRecentHomeActivity();
      notifyListeners();
    } catch (_) {
      // Ignoramos errores en silent refresh para no alertar al usuario
    }
  }

  Future<void> loadSalesHistory({bool silent = false}) async {
    resetFilters();
    await _loadFilteredHistoryInternal(reset: true, silent: silent);
  }

  @override
  Future<void> loadFilteredHistory({bool reset = false}) async {
    await _loadFilteredHistoryInternal(reset: reset, silent: false);
  }

  Future<void> _loadFilteredHistoryInternal({
    bool reset = false,
    bool silent = false,
  }) async {
    if (_negocioId == null) return;
    final bool hasCachedData =
        _hasLoadedOnce || _salesHistory.isNotEmpty || _masterSales.isNotEmpty;
    final bool useSilent = silent || hasCachedData;

    if (reset) {
      if (!useSilent) {
        _isLoading = true;
        _isRefreshing = true;
      }
      _currentSkip = 0;
      _hasMoreData = true;
      if (!useSilent) {
        notifyListeners();
      }
      _loadDynamicStats();
    } else {
      if (_isLoadingMore || !_hasMoreData || _isRefreshing) return;
      _isLoadingMore = true;
      notifyListeners();
    }

    try {
      final bool isArchivedTab = _currentTab == "archivadas";

      final newSales = await _salesService.getHistory(
        _negocioId!,
        skip: _currentSkip,
        limit: _limit,
        startDate: _currentStartDate,
        endDate: _currentEndDate,
        searchQuery: _searchQuery,
        isArchived: isArchivedTab,
        origenVenta: null,
        sortBy: _currentSortBy,
        order: _currentOrder,
        financialStatus: _financialStatus != 'todos' ? _financialStatus : null,
      );

      if (newSales.length < _limit) _hasMoreData = false;

      if (isArchivedTab) {
        _mergeArchivedSales(newSales, replace: reset);
      } else {
        _mergeSales(newSales, replace: reset);
        if (reset) {
          _salesService
              .getHistory(
                _negocioId!,
                skip: 0,
                limit: _limit,
                startDate: _currentStartDate,
                endDate: _currentEndDate,
                isArchived: true,
                origenVenta: null,
                sortBy: _currentSortBy,
                order: _currentOrder,
              )
              .then((archivedList) {
                _mergeArchivedSales(archivedList, replace: true);
                _applyTabFilterInMemory();
                notifyListeners();
              })
              .catchError((_) {});
        }
      }

      _applyTabFilterInMemory();
      _currentSkip = isArchivedTab
          ? _archivedSales.length
          : _masterSales.length;
    } catch (e) {
      _handleException(e);
    } finally {
      _hasLoadedOnce = true;
      _isLoading = false;
      _isRefreshing = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  @override
  Future<void> _loadDynamicStats() async {
    if (_negocioId == null) return;
    try {
      final bool isArchivedTab = _currentTab == "archivadas";

      _currentStats = await _salesService.getStats(
        _negocioId!,
        startDate: _currentStartDate,
        endDate: _currentEndDate,
        isArchived: isArchivedTab,
        origenVenta: null,
        financialStatus: _financialStatus != 'todos' ? _financialStatus : null,
      );
      notifyListeners();
    } catch (e) {
      _handleException(e);
    }
  }

  Future<List<SaleModel>> loadAllForExport({
    bool ignoreDateFilter = false,
    bool onlyArchived = false,
    String? origenVenta,
    String? financialStatus,
    String? paymentMethod,
    String? sortBy,
    String? order,
  }) async {
    if (_negocioId == null) return [];

    try {
      final String? startDate = ignoreDateFilter ? null : _currentStartDate;
      final String? endDate = ignoreDateFilter ? null : _currentEndDate;

      final effectiveOrigen = (origenVenta != null && origenVenta != 'todas')
          ? origenVenta
          : null;

      final effectiveFinancial =
          (financialStatus != null && financialStatus != 'todos')
          ? financialStatus
          : (_financialStatus != 'todos' ? _financialStatus : null);

      return await _salesService.getHistory(
        _negocioId!,
        skip: 0,
        limit: 999999,
        startDate: startDate,
        endDate: endDate,
        searchQuery: _searchQuery,
        isArchived: onlyArchived,
        origenVenta: effectiveOrigen,
        sortBy: sortBy ?? _currentSortBy,
        order: order ?? _currentOrder,
        financialStatus: effectiveFinancial,
        paymentMethod: paymentMethod,
      );
    } catch (e) {
      _handleException(e);
      return [];
    }
  }

  Future<int> countForExport({
    bool ignoreDateFilter = false,
    bool onlyArchived = false,
    String? origenVenta,
    String? financialStatus,
    String? paymentMethod,
  }) async {
    final list = await loadAllForExport(
      ignoreDateFilter: ignoreDateFilter,
      onlyArchived: onlyArchived,
      origenVenta: origenVenta,
      financialStatus: financialStatus,
      paymentMethod: paymentMethod,
    );
    return list.length;
  }

  Future<String> exportFilteredHistoryCsv(String currencyName) async {
    if (_negocioId == null) return "";
    try {
      final bool isArchivedTab = _currentTab == "archivadas";
      final String? origen =
          (_currentTab == "todas" || _currentTab == "archivadas")
          ? null
          : _currentTab;

      final allSales = await _salesService.getHistory(
        _negocioId!,
        skip: 0,
        limit: -1,
        startDate: _currentStartDate,
        endDate: _currentEndDate,
        searchQuery: _searchQuery,
        isArchived: isArchivedTab,
        origenVenta: origen,
        sortBy: _currentSortBy,
        order: _currentOrder,
        financialStatus: _financialStatus != 'todos' ? _financialStatus : null,
      );

      if (allSales.isEmpty) return "";

      final String curr = currencyName.split(' ').first;
      final StringBuffer csv = StringBuffer(
        "ID Venta,Fecha,Cliente,Origen Venta,Metodo Pago,Estado Pago,Estado Entrega,Total($curr),Pagado($curr),Descuento($curr),Deuda($curr)\n",
      );

      for (final sale in allSales) {
        if (sale.origenVenta == 'prestamo_personal') continue;
        final dateFormatted = AppDateFormatter.formatDateTime(
          DateTime.parse(sale.saleDate),
        );

        final String clientName = (sale.clientName ?? "Cliente General")
            .replaceAll(',', ' ');

        final String originName = sale.origenVenta == 'smart_quotation'
            ? 'Listas Escolares'
            : sale.origenVenta == 'pos_rapido'
            ? 'Caja Rapida'
            : sale.origenVenta;

        final double debt =
            (sale.trueTotalAmount > sale.paidAmount &&
                sale.paymentStatus != 'pagado')
            ? (sale.trueTotalAmount - sale.paidAmount)
            : 0.0;

        csv.write(
          "${sale.displayId},$dateFormatted,$clientName,$originName,${sale.paymentMethod},${sale.paymentStatus},${sale.deliveryStatus},${sale.trueTotalAmount},${sale.paidAmount},${sale.discount},$debt\n",
        );
      }
      return csv.toString();
    } catch (e) {
      _handleException(e);
      return "";
    }
  }
}
