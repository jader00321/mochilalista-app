import 'package:flutter/material.dart';
import 'package:app_movil/features/smart_quotation/models/sale_and_installment_models.dart';

class ReputationTier {
  final String key;
  final String displayName;
  final int minScore;
  final int maxScore;
  final Color primaryColor;
  final Color badgeDarkColor;
  final Color badgeLightColor;
  final IconData icon;
  final double creditFactor;

  const ReputationTier({
    required this.key,
    required this.displayName,
    required this.minScore,
    required this.maxScore,
    required this.primaryColor,
    required this.badgeDarkColor,
    required this.badgeLightColor,
    required this.icon,
    required this.creditFactor,
  });

  int get colorHex => primaryColor.toARGB32();
  String get name => key;

  String get badgeText {
    switch (key) {
      case 'DIAMANTE_VIP':
        return 'Diamante VIP';
      case 'ORO':
        return 'Oro';
      case 'PLATA':
        return 'Plata';
      case 'BRONCE':
        return 'Bronce';
      case 'OBSERVACION':
      default:
        return 'Observación';
    }
  }

  double get limiteCreditoSugerido {
    switch (key) {
      case 'DIAMANTE_VIP':
        return 1500.0;
      case 'ORO':
        return 700.0;
      case 'PLATA':
        return 350.0;
      case 'BRONCE':
        return 150.0;
      case 'OBSERVACION':
      default:
        return 0.0;
    }
  }

  static const observacion = ReputationTier(
    key: 'OBSERVACION',
    displayName: 'En Observación',
    minScore: 0,
    maxScore: 349,
    primaryColor: Color(0xFFEF4444),
    badgeDarkColor: Color(0x33EF4444),
    badgeLightColor: Color(0x25EF4444),
    icon: Icons.warning_amber_rounded,
    creditFactor: 0.0,
  );

  static const bronce = ReputationTier(
    key: 'BRONCE',
    displayName: 'Bronce',
    minScore: 350,
    maxScore: 499,
    primaryColor: Color(0xFFCD7F32),
    badgeDarkColor: Color(0x33CD7F32),
    badgeLightColor: Color(0x25CD7F32),
    icon: Icons.shield_outlined,
    creditFactor: 1.0,
  );

  static const plata = ReputationTier(
    key: 'PLATA',
    displayName: 'Plata',
    minScore: 500,
    maxScore: 749,
    primaryColor: Color(0xFFA8B2C1),
    badgeDarkColor: Color(0x33A8B2C1),
    badgeLightColor: Color(0x25A8B2C1),
    icon: Icons.verified_rounded,
    creditFactor: 2.0,
  );

  static const oro = ReputationTier(
    key: 'ORO',
    displayName: 'Oro',
    minScore: 750,
    maxScore: 899,
    primaryColor: Color(0xFFFFB800),
    badgeDarkColor: Color(0x33FFB800),
    badgeLightColor: Color(0x25FFB800),
    icon: Icons.military_tech_rounded,
    creditFactor: 3.5,
  );

  static const diamanteVip = ReputationTier(
    key: 'DIAMANTE_VIP',
    displayName: 'Diamante VIP',
    minScore: 900,
    maxScore: 1000,
    primaryColor: Color(0xFF00E5FF),
    badgeDarkColor: Color(0x3300E5FF),
    badgeLightColor: Color(0x2500E5FF),
    icon: Icons.diamond_rounded,
    creditFactor: 5.0,
  );

  static const List<ReputationTier> allTiers = [
    diamanteVip,
    oro,
    plata,
    bronce,
    observacion,
  ];

  static ReputationTier fromScore(int score) {
    if (score >= 900) return diamanteVip;
    if (score >= 750) return oro;
    if (score >= 500) return plata;
    if (score >= 350) return bronce;
    return observacion;
  }

  static ReputationTier fromKey(String? key) {
    final clean = (key ?? 'PLATA').toUpperCase().trim();
    switch (clean) {
      case 'DIAMANTE_VIP':
      case 'DIAMANTE':
      case 'VIP':
        return diamanteVip;
      case 'ORO':
        return oro;
      case 'BRONCE':
        return bronce;
      case 'OBSERVACION':
      case 'MOROSO':
      case 'MALO':
        return observacion;
      case 'PLATA':
      default:
        return plata;
    }
  }

  double calculateCreditLimit(List<SaleSummary> sales, int streak, double totalDebt) {
    // Si está en observación o tiene deudas activas impagas, crédito es 0.0
    if (creditFactor <= 0.0 || totalDebt > 0.01) return 0.0;

    final validSales = sales.where((s) => !s.isArchived).toList();
    if (validSales.isEmpty) {
      return 50.0 * creditFactor;
    }

    double sum = 0.0;
    for (var s in validSales) {
      sum += s.trueTotal;
    }
    double avgTicket = sum / validSales.length;
    if (avgTicket < 30.0) avgTicket = 30.0;

    double punctualityBonus = 1.0 + (streak * 0.05).clamp(0.0, 0.4);
    double limit = avgTicket * creditFactor * punctualityBonus;

    // Redondear a múltiplos de 10
    return ((limit / 10).round() * 10).toDouble();
  }
}
