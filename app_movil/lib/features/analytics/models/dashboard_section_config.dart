import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardSectionConfig {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final String categoryGroup; // 'resumen', 'graficos', 'inventario', 'radar'
  bool isVisible;
  final bool isPermanent;

  DashboardSectionConfig({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.categoryGroup,
    this.isVisible = true,
    this.isPermanent = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'isVisible': isVisible,
  };

  DashboardSectionConfig copyWith({bool? isVisible}) {
    return DashboardSectionConfig(
      id: id,
      title: title,
      subtitle: subtitle,
      icon: icon,
      categoryGroup: categoryGroup,
      isVisible: isVisible ?? this.isVisible,
      isPermanent: isPermanent,
    );
  }

  static List<DashboardSectionConfig> getDefaultSections() {
    return [
      DashboardSectionConfig(
        id: 'financial_summary',
        title: 'Balance Financiero Destacado',
        subtitle: 'Ingresos, ganancia neta y margen con gráfico de barras',
        icon: Icons.account_balance_wallet,
        categoryGroup: 'resumen',
        isVisible: true,
        isPermanent: true,
      ),
      DashboardSectionConfig(
        id: 'kpi_grid',
        title: 'Cuadrícula de KPIs Rápidos',
        subtitle: 'Ventas, crecimiento simétrico, rotación y capital de stock',
        icon: Icons.dashboard_customize,
        categoryGroup: 'resumen',
        isVisible: true,
      ),
      DashboardSectionConfig(
        id: 'commercial_radar',
        title: 'Radar Comercial & Mercado IA',
        subtitle: 'Noticias locales, clima, carreteras y consejos de abastecimiento',
        icon: Icons.radar,
        categoryGroup: 'radar',
        isVisible: true,
      ),
      DashboardSectionConfig(
        id: 'predictive_engine',
        title: 'Motor Predictivo de Crecimiento',
        subtitle: 'Proyección y simulación de ventas con algoritmos inteligentes',
        icon: Icons.rocket_launch,
        categoryGroup: 'resumen',
        isVisible: true,
      ),
      DashboardSectionConfig(
        id: 'insights_carousel',
        title: 'Recomendaciones Estratégicas IA',
        subtitle: 'Carrusel de hallazgos automáticos y consejos clave',
        icon: Icons.auto_awesome,
        categoryGroup: 'resumen',
        isVisible: true,
      ),
      DashboardSectionConfig(
        id: 'restock_alerts',
        title: 'Riesgo de Quiebre de Stock',
        subtitle: 'Productos bajo el nivel mínimo para reposición inmediata',
        icon: Icons.warning_amber_rounded,
        categoryGroup: 'inventario',
        isVisible: true,
      ),
      DashboardSectionConfig(
        id: 'sales_evolution',
        title: 'Evolución de Ventas',
        subtitle: 'Gráfico interactivo con montos en eje Y y tooltips',
        icon: Icons.show_chart,
        categoryGroup: 'graficos',
        isVisible: true,
      ),
      DashboardSectionConfig(
        id: 'sales_by_day',
        title: 'Ventas por Día de la Semana',
        subtitle: 'Lunes a domingo destacando el mejor día del negocio',
        icon: Icons.bar_chart,
        categoryGroup: 'graficos',
        isVisible: true,
      ),
      DashboardSectionConfig(
        id: 'sales_by_origin',
        title: 'Ventas por Origen',
        subtitle: 'Dona interactiva por canal con centro dinámico',
        icon: Icons.pie_chart,
        categoryGroup: 'graficos',
        isVisible: true,
      ),
      DashboardSectionConfig(
        id: 'payment_methods',
        title: 'Ingresos por Método de Pago',
        subtitle: 'Efectivo, Yape, Plin, tarjeta con desglose interactivo',
        icon: Icons.payments,
        categoryGroup: 'graficos',
        isVisible: true,
      ),
      DashboardSectionConfig(
        id: 'top_categories',
        title: 'Top Categorías (\$ y 📦)',
        subtitle: 'Tarjeta inteligente con selector de Ingresos vs Unidades',
        icon: Icons.category,
        categoryGroup: 'graficos',
        isVisible: true,
      ),
      DashboardSectionConfig(
        id: 'top_products',
        title: 'Top Productos Más Vendidos',
        subtitle: 'Ranking de los artículos con mayor rotación comercial',
        icon: Icons.shopping_bag,
        categoryGroup: 'inventario',
        isVisible: true,
      ),
      DashboardSectionConfig(
        id: 'top_clients',
        title: 'Mejores Clientes',
        subtitle: 'Clientes VIP con número de compras y acceso a perfil',
        icon: Icons.people,
        categoryGroup: 'resumen',
        isVisible: true,
      ),
      DashboardSectionConfig(
        id: 'extra_metrics',
        title: 'Métricas de Eficiencia',
        subtitle: 'Margen promedio/venta, cobranza efectiva y proyección',
        icon: Icons.analytics,
        categoryGroup: 'resumen',
        isVisible: true,
      ),
      DashboardSectionConfig(
        id: 'dead_stock',
        title: 'Inventario Muerto',
        subtitle: 'Productos sin rotación con estrategia de liquidación',
        icon: Icons.hourglass_empty,
        categoryGroup: 'inventario',
        isVisible: true,
      ),
    ];
  }

  static String _prefsKey(int negocioId) => 'analytics_sections_order_v1_$negocioId';

  static Future<List<DashboardSectionConfig>> loadSections(int negocioId) async {
    final defaults = getDefaultSections();
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_prefsKey(negocioId));
      if (jsonStr == null || jsonStr.isEmpty) return defaults;

      final List<dynamic> list = jsonDecode(jsonStr);
      final Map<String, DashboardSectionConfig> defaultMap = {
        for (var s in defaults) s.id: s
      };

      List<DashboardSectionConfig> result = [];
      for (var item in list) {
        final id = item['id'];
        final isVisible = item['isVisible'] ?? true;
        if (defaultMap.containsKey(id)) {
          final section = defaultMap.remove(id)!;
          section.isVisible = section.isPermanent ? true : isVisible;
          result.add(section);
        }
      }

      // Añadir cualquier sección nueva que no estaba en las preferencias guardadas
      for (var remaining in defaultMap.values) {
        result.add(remaining);
      }

      return result;
    } catch (_) {
      return defaults;
    }
  }

  static Future<void> saveSections(int negocioId, List<DashboardSectionConfig> sections) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> rawList = sections.map((s) => s.toJson()).toList();
      await prefs.setString(_prefsKey(negocioId), jsonEncode(rawList));
    } catch (_) {}
  }

  static List<DashboardSectionConfig> applyPreset(
    List<DashboardSectionConfig> currentSections, 
    String presetName,
  ) {
    Set<String> activeIds = {};
    switch (presetName) {
      case 'Financiero':
        activeIds = {
          'financial_summary',
          'kpi_grid',
          'sales_evolution',
          'payment_methods',
          'extra_metrics',
        };
        break;
      case 'Operativo / Stock':
        activeIds = {
          'financial_summary',
          'kpi_grid',
          'dead_stock',
          'top_products',
          'top_categories',
        };
        break;
      case 'Comercial & Radar':
        activeIds = {
          'financial_summary',
          'commercial_radar',
          'top_clients',
          'sales_by_day',
          'sales_by_origin',
        };
        break;
      case 'Completo':
      default:
        activeIds = {for (var s in currentSections) s.id};
        break;
    }

    return currentSections.map((s) {
      if (s.isPermanent) return s.copyWith(isVisible: true);
      return s.copyWith(isVisible: activeIds.contains(s.id));
    }).toList();
  }
}
