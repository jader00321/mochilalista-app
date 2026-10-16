import 'package:flutter/material.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';

class ClientComplianceSparkline extends StatelessWidget {
  final ClientModel client;
  final bool isDark;

  const ClientComplianceSparkline({
    super.key,
    required this.client,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // Generamos puntos basados en el historial o deuda
    List<double> dataPoints = [];
    if (client.lastSales.isNotEmpty) {
      dataPoints = client.lastSales.map((s) => s.total).toList();
    } else {
      dataPoints = [0.0, 50.0, 30.0, 80.0, 40.0, 100.0];
    }

    if (dataPoints.length < 2) {
      dataPoints = [dataPoints.firstOrNull ?? 10.0, (dataPoints.firstOrNull ?? 10.0) * 1.2];
    }

    final bool hasOverdue = client.totalDebt > 0;
    final Color lineColor = hasOverdue
        ? (isDark ? Colors.orangeAccent : Colors.deepOrange)
        : (isDark ? Colors.greenAccent : Colors.teal);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14141C) : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.white24,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    hasOverdue ? Icons.trending_down_rounded : Icons.trending_up_rounded,
                    size: 16,
                    color: lineColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "Tendencia Comercial",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: lineColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  hasOverdue ? "Deuda Activa" : "Excelente Historial",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: lineColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 40,
            width: double.infinity,
            child: CustomPaint(
              painter: _SparklinePainter(
                data: dataPoints,
                lineColor: lineColor,
                isDark: isDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color lineColor;
  final bool isDark;

  _SparklinePainter({
    required this.data,
    required this.lineColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final double minVal = data.reduce((a, b) => a < b ? a : b);
    final double maxVal = data.reduce((a, b) => a > b ? a : b);
    final double range = (maxVal - minVal) == 0 ? 1.0 : (maxVal - minVal);

    final double stepX = size.width / (data.length - 1);

    final Path path = Path();
    final Path fillPath = Path();

    for (int i = 0; i < data.length; i++) {
      final double normalizedY = (data[i] - minVal) / range;
      final double x = i * stepX;
      final double y = size.height - (normalizedY * (size.height - 8)) - 4;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        final double prevX = (i - 1) * stepX;
        final double prevNormY = (data[i - 1] - minVal) / range;
        final double prevY = size.height - (prevNormY * (size.height - 8)) - 4;

        final double cx1 = prevX + (stepX / 2);
        final double cy1 = prevY;
        final double cx2 = prevX + (stepX / 2);
        final double cy2 = y;

        path.cubicTo(cx1, cy1, cx2, cy2, x, y);
        fillPath.cubicTo(cx1, cy1, cx2, cy2, x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Sombra/Gradiente inferior
    final Paint fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          lineColor.withValues(alpha: isDark ? 0.35 : 0.25),
          lineColor.withValues(alpha: 0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    // Línea principal
    final Paint strokePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, strokePaint);

    // Punto final brillante
    final double lastNormY = (data.last - minVal) / range;
    final double lastX = size.width;
    final double lastY = size.height - (lastNormY * (size.height - 8)) - 4;

    final Paint dotPaint = Paint()..color = lineColor;
    canvas.drawCircle(Offset(lastX, lastY), 3.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) => true;
}
