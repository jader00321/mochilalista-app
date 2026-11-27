part of '../sale_provider.dart';

mixin _SaleFiltersAndMetricsMixin on _SaleProviderBase {
  void _initDefaultTimeFilter() {
    _activeQuickFilter = "seis_meses";
    final now = DateTime.now();
    _currentStartDate = DateTime(
      now.year,
      now.month - 6,
      now.day,
    ).toIso8601String();
    _currentEndDate = DateTime(
      now.year,
      now.month,
      now.day,
      23,
      59,
      59,
    ).toIso8601String();
  }

  Iterable<SaleModel> get _todayValidSales sync* {
    if (_salesHistory.isEmpty) return;
    final today = DateTime.now();
    for (final sale in _salesHistory) {
      if (sale.isArchived || sale.origenVenta == 'prestamo_personal') continue;
      try {
        final saleDate = DateTime.parse(sale.saleDate);
        if (saleDate.year == today.year &&
            saleDate.month == today.month &&
            saleDate.day == today.day) {
          yield sale;
        }
      } catch (_) {
        continue;
      }
    }
  }

  double get todaySalesTotal {
    double sum = 0.0;
    for (final sale in _todayValidSales) {
      sum += sale.totalAmount;
    }
    return sum;
  }

  int get todaySalesCount => _todayValidSales.length;

  Future<void> loadCurrentMonthMargin() async {
    if (_negocioId == null) return;
    try {
      final db = await _salesService.dbHelper.database;
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, 1).toIso8601String();

      final result = await db.rawQuery(
        '''
        SELECT 
          SUM(i.cantidad * i.precio_unitario) as ventas,
          SUM(i.cantidad * COALESCE(i.original_unit_price, i.precio_unitario)) as costos
        FROM venta_items i
        JOIN ventas v ON i.venta_id = v.id
        WHERE v.negocio_id = ? AND v.fecha_venta >= ? AND v.is_archived = 0 AND IFNULL(v.origen_venta, '') != 'prestamo_personal'
      ''',
        [_negocioId, start],
      );

      if (result.isNotEmpty) {
        final ventas = (result.first['ventas'] as num?)?.toDouble() ?? 0.0;
        final costos = (result.first['costos'] as num?)?.toDouble() ?? 0.0;
        if (ventas > 0) {
          _currentMonthSalesTotal = ventas;
          _currentMonthMargin = costos > 0
              ? ((ventas - costos) / ventas) * 100
              : 100.0;
        } else {
          _currentMonthSalesTotal = 0.0;
          _currentMonthMargin = 0.0;
        }
        notifyListeners();
      }
    } catch (_) {
      // ignore
    }
  }

  @override
  void resetFilters() {
    _currentTab = "todas";
    _searchQuery = "";
    _currentSortBy = "fecha_venta";
    _currentOrder = "desc";
    _financialStatus = "todos";
  }

  void setFinancialFilter(String status) {
    if (_financialStatus == status) return;
    _financialStatus = status;
    _applyTabFilterInMemory();
    notifyListeners();
  }

  @override
  List<SaleModel> getSalesForTab(String tabKey) {
    List<SaleModel> list;
    switch (tabKey) {
      case 'todas':
        list = _masterSales.where((s) => !s.isArchived).toList();
        break;
      case 'smart_quotation':
        list = _masterSales
            .where((s) => !s.isArchived && s.origenVenta == 'smart_quotation')
            .toList();
        break;
      case 'pos_rapido':
        list = _masterSales
            .where((s) => !s.isArchived && s.origenVenta == 'pos_rapido')
            .toList();
        break;
      case 'archivadas':
        list = _archivedSales.isNotEmpty
            ? List<SaleModel>.from(_archivedSales)
            : _masterSales.where((s) => s.isArchived).toList();
        break;
      default:
        list = List<SaleModel>.from(_salesHistory);
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((s) {
        final name = (s.clientName ?? '').toLowerCase();
        final idStr = s.id.toString();
        final displayId = s.displayId.toLowerCase();
        final notes = (s.notes ?? '').toLowerCase();
        return name.contains(q) ||
            idStr.contains(q) ||
            displayId.contains(q) ||
            notes.contains(q);
      }).toList();
    }

    if (_financialStatus == 'pagados') {
      list = list.where((s) => s.isFullyPaid).toList();
    } else if (_financialStatus == 'con_deuda') {
      list = list.where((s) => s.pendingDebt > 0.01).toList();
    }

    list.sort((a, b) {
      int comparison = 0;
      switch (_currentSortBy) {
        case 'monto_total':
          comparison = a.totalAmount.compareTo(b.totalAmount);
          break;
        case 'fecha_venta':
        default:
          final dateA =
              DateTime.tryParse(a.saleDate) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final dateB =
              DateTime.tryParse(b.saleDate) ??
              DateTime.fromMillisecondsSinceEpoch(0);
          comparison = dateA.compareTo(dateB);
          break;
      }
      return _currentOrder == 'desc' ? -comparison : comparison;
    });

    return list;
  }

  @override
  void _applyTabFilterInMemory() {
    _salesHistory = getSalesForTab(_currentTab);

    final int count = _salesHistory.length;
    double ingresos = 0.0;
    double deuda = 0.0;
    for (final s in _salesHistory) {
      ingresos += s.paidAmount;
      deuda += s.pendingDebt;
    }
    _currentStats = SalesStatsModel(
      cantidadVentas: count,
      totalIngresos: ingresos,
      totalDeuda: deuda,
      totalProductosVendidos: 0,
    );
  }

  List<SaleModel> _mergeSaleLists(
    List<SaleModel> existing,
    List<SaleModel> incoming, {
    bool replace = false,
  }) {
    final map = replace
        ? <int, SaleModel>{}
        : {for (final s in existing) s.id: s};
    for (final s in incoming) {
      map[s.id] = s;
    }
    return map.values.toList();
  }

  @override
  void _mergeSales(List<SaleModel> incoming, {bool replace = false}) {
    _masterSales = _mergeSaleLists(_masterSales, incoming, replace: replace);
  }

  @override
  void _mergeArchivedSales(List<SaleModel> incoming, {bool replace = false}) {
    _archivedSales = _mergeSaleLists(
      _archivedSales,
      incoming,
      replace: replace,
    );
  }

  void setQuickFilter(
    String filterType, {
    DateTime? customStart,
    DateTime? customEnd,
  }) {
    _activeQuickFilter = filterType;
    final now = DateTime.now();
    String? startStr;
    String? endStr;

    final String endOfToday = DateTime(
      now.year,
      now.month,
      now.day,
      23,
      59,
      59,
    ).toIso8601String();

    switch (filterType) {
      case 'hoy':
        startStr = DateTime(now.year, now.month, now.day).toIso8601String();
        endStr = endOfToday;
        break;
      case 'semana':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        startStr = DateTime(
          startOfWeek.year,
          startOfWeek.month,
          startOfWeek.day,
        ).toIso8601String();
        endStr = endOfToday;
        break;
      case 'este_mes':
        startStr = DateTime(now.year, now.month, 1).toIso8601String();
        endStr = endOfToday;
        break;
      case 'seis_meses':
        startStr = DateTime(now.year, now.month - 6, now.day).toIso8601String();
        endStr = endOfToday;
        break;
      case 'personalizado':
        if (customStart != null && customEnd != null) {
          startStr = customStart.toIso8601String();
          endStr = DateTime(
            customEnd.year,
            customEnd.month,
            customEnd.day,
            23,
            59,
            59,
          ).toIso8601String();
        }
        break;
      case 'todo':
      case 'todas':
      default:
        startStr = null;
        endStr = null;
        break;
    }

    _currentStartDate = startStr;
    _currentEndDate = endStr;
    loadFilteredHistory(reset: true);
  }

  void setSort(String sortBy, String order) {
    if (_currentSortBy == sortBy && _currentOrder == order) return;
    _currentSortBy = sortBy;
    _currentOrder = order;
    _applyTabFilterInMemory();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    _applyTabFilterInMemory();
    notifyListeners();
  }

  void setTab(String tabKey) {
    if (_currentTab == tabKey) return;
    _currentTab = tabKey;

    _applyTabFilterInMemory();
    notifyListeners();

    if (tabKey == 'archivadas' &&
        _archivedSales.isEmpty &&
        !_masterSales.any((s) => s.isArchived)) {
      loadFilteredHistory(reset: true);
    } else if (tabKey != 'archivadas' && _masterSales.isEmpty) {
      loadFilteredHistory(reset: true);
    }
  }
}
