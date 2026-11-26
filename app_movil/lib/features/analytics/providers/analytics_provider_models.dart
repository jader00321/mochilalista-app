part of 'analytics_provider.dart';

enum AnalyticsStep { idle, starting, sales, inventory, clients, insights, done, error }
enum InsightType { success, warning, info, tip }
enum AnalyticsPeriod { today, week, month, sixMonths, year, allTime, custom }

class BusinessInsight {
  final IconData icon;
  final String title;
  final String description;
  final InsightType type;
  final String? suggestedAction;
  final String? actionLabel;
  final String? actionRoute;

  BusinessInsight(this.title, this.description, this.icon, this.type, {this.suggestedAction, this.actionLabel, this.actionRoute});
}

class FinancialHealthSummary {
  final String balanceHeadline;
  final String balanceDescription;
  final String healthDiagnosis;
  final String healthLevel;
  final String marginContext;

  FinancialHealthSummary({
    required this.balanceHeadline,
    required this.balanceDescription,
    required this.healthDiagnosis,
    required this.healthLevel,
    required this.marginContext,
  });
}

class AnalyticsData {
  final double totalSales;
  final double netProfit;
  final double estimatedMarginPercentage;
  final double inventoryTurnoverRatio;
  final double immobilizedCapital;
  final double recoveredLiquidity;
  
  final List<Map<String, dynamic>> topProducts;
  final List<Map<String, dynamic>> lowStockProducts;
  final List<Map<String, dynamic>> topClients;
  final List<Map<String, dynamic>> monthlySales;
  final List<Map<String, dynamic>> dailySalesData;
  final double averageTicket;
  final double nextMonthPrediction;
  
  final int totalTransactions;
  final double salesGrowthRate;
  final List<Map<String, dynamic>> topCategories;
  final List<Map<String, dynamic>> salesByDayOfWeek;
  final List<Map<String, dynamic>> salesByOrigin;
  final List<Map<String, dynamic>> salesByPaymentMethod;
  final double inventoryValue;
  final int deadStockCount;
  final List<Map<String, dynamic>> deadStockList;
  final List<BusinessInsight> insights;
  final FinancialHealthSummary? financialHealth;
  final String? categoryInsight;
  final double effectiveCollectionRate;
  final double averageMarginPerSale;
  final double previousPeriodSales;
  final DateTime? periodStartDate;
  final DateTime? periodEndDate;

  AnalyticsData({
    this.totalSales = 0.0,
    this.netProfit = 0.0,
    this.estimatedMarginPercentage = 0.0,
    this.recoveredLiquidity = 0.0,
    this.topProducts = const [],
    this.lowStockProducts = const [],
    this.topClients = const [],
    this.monthlySales = const [],
    this.dailySalesData = const [],
    this.averageTicket = 0.0,
    this.nextMonthPrediction = 0.0,
    this.totalTransactions = 0,
    this.salesGrowthRate = 0.0,
    this.topCategories = const [],
    this.salesByDayOfWeek = const [],
    this.salesByOrigin = const [],
    this.salesByPaymentMethod = const [],
    this.inventoryValue = 0.0,
    this.inventoryTurnoverRatio = 0.0,
    this.immobilizedCapital = 0.0,
    this.deadStockCount = 0,
    this.deadStockList = const [],
    this.insights = const [],
    this.financialHealth,
    this.categoryInsight,
    this.effectiveCollectionRate = 100.0,
    this.averageMarginPerSale = 0.0,
    this.previousPeriodSales = 0.0,
    this.periodStartDate,
    this.periodEndDate,
  });
}

class _PeriodDateRange {
  final DateTime startDate;
  final DateTime endDate;
  final DateTime prevStartDate;
  final DateTime prevEndDate;

  const _PeriodDateRange({
    required this.startDate,
    required this.endDate,
    required this.prevStartDate,
    required this.prevEndDate,
  });
}

class _SalesMetricsResult {
  final List<Map<String, dynamic>> periodVentas;
  final int totalTransactions;
  final double totalVentas;
  final double totalGananciaNeta;
  final double prevTotalVentas;
  final double growthRate;
  final double effectiveCollectionRate;
  final double margin;
  final String ventaIdsIn;
  final Map<String, double> salesByMonth;
  final Map<String, double> salesByDayListMap;
  final Map<String, double> salesByDayMap;
  final Map<String, double> salesByOriginMap;
  final Map<String, double> salesByPaymentMap;

  const _SalesMetricsResult({
    required this.periodVentas,
    required this.totalTransactions,
    required this.totalVentas,
    required this.totalGananciaNeta,
    required this.prevTotalVentas,
    required this.growthRate,
    required this.effectiveCollectionRate,
    required this.margin,
    required this.ventaIdsIn,
    required this.salesByMonth,
    required this.salesByDayListMap,
    required this.salesByDayMap,
    required this.salesByOriginMap,
    required this.salesByPaymentMap,
  });
}

class _TopRankingsResult {
  final List<Map<String, dynamic>> topProductsQuery;
  final List<Map<String, dynamic>> topClientsQuery;
  final List<Map<String, dynamic>> topCategoriesQuery;
  final double recoveredLiquidity;

  const _TopRankingsResult({
    required this.topProductsQuery,
    required this.topClientsQuery,
    required this.topCategoriesQuery,
    required this.recoveredLiquidity,
  });
}

class _InventoryValuationResult {
  final double invValue;
  final double immobilizedCapital;
  final List<Map<String, dynamic>> deadStockList;
  final int deadStockCount;
  final double inventoryTurnoverRatio;

  const _InventoryValuationResult({
    required this.invValue,
    required this.immobilizedCapital,
    required this.deadStockList,
    required this.deadStockCount,
    required this.inventoryTurnoverRatio,
  });
}
