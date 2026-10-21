import 'package:flutter/material.dart';

/// Indicador semáforo dinámico de margen comercial para presentaciones de producto.
/// Muestra si el margen actual representa pérdida, margen crítico, medio u óptimo.
class PresentationMarginIndicator extends StatelessWidget {
  final double costoPres;
  final double precioVenta;
  final bool isDark;

  const PresentationMarginIndicator({
    super.key,
    required this.costoPres,
    required this.precioVenta,
    required this.isDark,
  });

  static String calcularMargenTexto(double pVenta, double cPres) {
    if (pVenta <= 0 || cPres <= 0) return "N/D";
    final double margenPct = ((pVenta - cPres) / cPres) * 100;
    return "${margenPct.toStringAsFixed(1)}%";
  }

  static MaterialColor calcularMargenColor(double pVenta, double cPres) {
    if (pVenta <= 0 || cPres <= 0) return Colors.grey;
    final double margenPct = ((pVenta - cPres) / cPres) * 100;
    if (margenPct < 15) return Colors.red;
    if (margenPct <= 30) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    double margenPct = 0.0;
    if (costoPres > 0 && precioVenta > 0) {
      margenPct = ((precioVenta - costoPres) / costoPres) * 100;
    }

    Color semaforoColor;
    String semaforoTexto;
    IconData semaforoIcon;

    if (precioVenta <= 0 || costoPres <= 0) {
      semaforoColor = Colors.grey;
      semaforoTexto = "Define costo y precio de venta";
      semaforoIcon = Icons.info_outline;
    } else if (margenPct < 0) {
      semaforoColor = Colors.red;
      semaforoTexto =
          "🔴 ¡Pérdida! (${margenPct.toStringAsFixed(1)}%) - Bajo el costo";
      semaforoIcon = Icons.error_outline;
    } else if (margenPct < 15) {
      semaforoColor = Colors.red;
      semaforoTexto =
          "🔴 Margen Crítico (${margenPct.toStringAsFixed(1)}%) - Rentabilidad baja";
      semaforoIcon = Icons.warning_amber_rounded;
    } else if (margenPct <= 30) {
      semaforoColor = Colors.orange;
      semaforoTexto =
          "🟡 Margen Medio (${margenPct.toStringAsFixed(1)}%) - Ganancia moderada";
      semaforoIcon = Icons.trending_up;
    } else {
      semaforoColor = Colors.green;
      semaforoTexto =
          "🟢 Margen Óptimo (${margenPct.toStringAsFixed(1)}%) - Excelente margen";
      semaforoIcon = Icons.check_circle_outline;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: semaforoColor.withValues(alpha: isDark ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: semaforoColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(semaforoIcon, size: 16, color: semaforoColor),
            const SizedBox(width: 8),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  semaforoTexto,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: semaforoColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
