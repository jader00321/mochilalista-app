import 'package:flutter/material.dart';
import 'package:app_movil/core/widgets/tour/tour_step_model.dart';

/// Claves de widgets para anclaje visual en [AnalyticsDashboardScreen]
class AnalyticsDashboardTourKeys {
  final radarInsightsKey = GlobalKey();
  final financialKpisKey = GlobalKey();
  final salesPaymentChartsKey = GlobalKey();
  final restockAlertsKey = GlobalKey();
}

/// Configuración pedagógica de la Guía Turística para [AnalyticsDashboardScreen]
class AnalyticsDashboardTour {
  static ScreenTourConfig buildConfig({
    required AnalyticsDashboardTourKeys keys,
  }) {
    return ScreenTourConfig(
      screenId: 'analytics_dashboard_screen',
      screenTitle: 'Inteligencia de Negocio y Métricas',
      welcomeSummary:
          'Monitorea el pulso financiero de tu negocio, proyecta ventas con inteligencia artificial y detecta oportunidades de reposición oportuna de mercadería.',
      icon: Icons.analytics_rounded,
      steps: [
        TourStep(
          id: 'analytics_radar_insights',
          targetKey: keys.radarInsightsKey,
          title: 'Radar Comercial y Noticias del Mercado',
          description:
              'Sintoniza factores externos que impactan tu comercio: tendencias estacionales escolares, cambios tributarios y alertas comerciales en tiempo real.',
          tip:
              'Anticípate a los picos de demanda antes de que comience la campaña escolar.',
          icon: Icons.radar_rounded,
          borderRadius: 16.0,
        ),
        TourStep(
          id: 'analytics_financial_kpis',
          targetKey: keys.financialKpisKey,
          title: 'KPIs y Rentabilidad Financiera',
          description:
              'Visualiza tus ingresos brutos, margen neto real tras costos de adquisición, ganancia estimada y ticket promedio de venta.',
          tip:
              'Usa el ícono del ojo en la barra superior para ocultar los montos monetarios si atiendes con clientes cerca.',
          icon: Icons.insights_rounded,
          borderRadius: 16.0,
        ),
        TourStep(
          id: 'analytics_sales_charts',
          targetKey: keys.salesPaymentChartsKey,
          title: 'Gráficas y Medios de Pago',
          description:
              'Compara la evolución diaria y mensual de tus ventas y supervisa la participación de efectivo, transferencias bancarias y billeteras digitales.',
          tip:
              'Un desglose claro de métodos de pago facilita tu conciliación de caja al cierre del día.',
          icon: Icons.bar_chart_rounded,
          borderRadius: 16.0,
        ),
        TourStep(
          id: 'analytics_restock_alerts',
          targetKey: keys.restockAlertsKey,
          title: 'Alertas de Reabastecimiento',
          description:
              'Detecta artículos críticos bajo su stock mínimo, productos agotados y capital inmovilizado para optimizar tus órdenes de compra a proveedores.',
          tip:
              'Pulsa el botón flotante para acceder a la lista inteligente de reposición recomendada.',
          icon: Icons.notification_important_rounded,
          borderRadius: 16.0,
        ),
      ],
    );
  }
}
