import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app_movil/core/utils/currency_formatter.dart';
import 'package:app_movil/features/smart_quotation/models/crm_models.dart';

class ClientComplianceSparkline extends StatefulWidget {
  final ClientModel client;
  final List<SaleSummary>? sales;
  final bool isDark;

  const ClientComplianceSparkline({
    super.key,
    required this.client,
    this.sales,
    required this.isDark,
  });

  @override
  State<ClientComplianceSparkline> createState() => _ClientComplianceSparklineState();
}

class _ClientComplianceSparklineState extends State<ClientComplianceSparkline> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    // Tomamos las ventas filtradas pasadas por parámetro o las del cliente
    final rawSales = widget.sales ?? widget.client.lastSales;
    // Excluir préstamos y ordenar cronológicamente para la línea de tiempo
    final sales = rawSales.where((s) => s.origenVenta != 'prestamo_personal').toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final bool hasOverdue = widget.client.totalDebt > 0;
    final Color lineColor = hasOverdue
        ? (widget.isDark ? Colors.orangeAccent : Colors.deepOrange)
        : (widget.isDark ? Colors.tealAccent[400]! : Colors.teal[600]!);

    if (sales.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF1E1E2A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: widget.isDark ? Colors.white12 : Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.trending_neutral_rounded, color: widget.isDark ? Colors.grey[400] : Colors.grey[600], size: 20),
                const SizedBox(width: 8),
                Text(
                  "Tendencia Comercial",
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: widget.isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Icon(Icons.show_chart, size: 40, color: widget.isDark ? Colors.white12 : Colors.grey[300]),
            const SizedBox(height: 8),
            Text(
              "Sin compras registradas en este periodo",
              style: TextStyle(
                fontSize: 13,
                color: widget.isDark ? Colors.grey[500] : Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    final dataPoints = sales.map((s) => s.total).toList();
    final double maxAmount = dataPoints.reduce((a, b) => a > b ? a : b);
    final double minAmount = dataPoints.reduce((a, b) => a < b ? a : b);
    final double avgAmount = dataPoints.fold(0.0, (sum, val) => sum + val) / dataPoints.length;

    final bool isSingleSale = sales.length == 1;

    final selectedSale = (_selectedIndex != null && _selectedIndex! < sales.length)
        ? sales[_selectedIndex!]
        : sales.last;

    final String firstDateStr = sales.isNotEmpty
        ? DateFormat('dd/MM/yy').format(DateTime.tryParse(sales.first.date) ?? DateTime.now())
        : '';
    final String lastDateStr = sales.isNotEmpty
        ? DateFormat('dd/MM/yy').format(DateTime.tryParse(sales.last.date) ?? DateTime.now())
        : '';
    final String singleDateFullStr = sales.isNotEmpty
        ? DateFormat('dd/MM/yyyy').format(DateTime.tryParse(sales.first.date) ?? DateTime.now())
        : '';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1E1E2A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isDark ? Colors.white12 : Colors.grey.shade200,
        ),
        boxShadow: [
          if (!widget.isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: lineColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        hasOverdue ? Icons.trending_down_rounded : Icons.trending_up_rounded,
                        size: 18,
                        color: lineColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        "Tendencia Comercial",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: widget.isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: lineColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: lineColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  hasOverdue ? "Deuda Activa" : "Excelente Historial",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: lineColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Tarjeta interactiva del punto activo
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xFF14141C) : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: widget.isDark ? Colors.white10 : Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "COMPRA DEL ${DateFormat('dd/MM/yyyy').format(DateTime.tryParse(selectedSale.date) ?? DateTime.now())}",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        selectedSale.itemsCount > 0
                            ? "${selectedSale.itemsCount} ítems • Venta #${selectedSale.displayId}"
                            : "Venta #${selectedSale.displayId}",
                        style: TextStyle(
                          fontSize: 12,
                          color: widget.isDark ? Colors.white70 : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  AppCurrency.format(selectedSale.total),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: lineColor,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Gráfico CustomPaint
          GestureDetector(
            onPanDown: (details) => _handleTouch(details.localPosition, sales.length),
            onPanUpdate: (details) => _handleTouch(details.localPosition, sales.length),
            child: SizedBox(
              height: 70,
              width: double.infinity,
              child: CustomPaint(
                painter: _SparklinePainter(
                  data: dataPoints,
                  lineColor: lineColor,
                  isDark: widget.isDark,
                  selectedIndex: _selectedIndex,
                ),
              ),
            ),
          ),

          const SizedBox(height: 4),

          // Eje horizontal de fechas (Eje X)
          if (isSingleSale)
            Center(
              child: Text(
                singleDateFullStr,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    firstDateStr,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: widget.isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                  ),
                  Text(
                    "${sales.length} operaciones",
                    style: TextStyle(
                      fontSize: 9.5,
                      fontStyle: FontStyle.italic,
                      color: widget.isDark ? Colors.grey[500] : Colors.grey[500],
                    ),
                  ),
                  Text(
                    lastDateStr,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: widget.isDark ? Colors.grey[500] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          // Indicadores de resumen contextuales protegidos contra desbordamiento
          if (isSingleSale)
            Row(
              children: [
                _buildMetricChip("Operación", "Compra Única", widget.isDark, alignment: CrossAxisAlignment.start),
                _buildMetricChip("Fecha", singleDateFullStr, widget.isDark, alignment: CrossAxisAlignment.center),
                _buildMetricChip("Monto", AppCurrency.format(sales.first.total), widget.isDark, alignment: CrossAxisAlignment.end),
              ],
            )
          else if (minAmount == maxAmount)
            Row(
              children: [
                _buildMetricChip("Monto Fijo", AppCurrency.format(minAmount), widget.isDark, alignment: CrossAxisAlignment.start),
                _buildMetricChip("N° Ventas", "${sales.length}", widget.isDark, alignment: CrossAxisAlignment.center),
                _buildMetricChip("Monto Total", AppCurrency.format(sales.fold<double>(0.0, (s, e) => s + e.total)), widget.isDark, alignment: CrossAxisAlignment.end),
              ],
            )
          else
            Row(
              children: [
                _buildMetricChip("Mínimo", AppCurrency.format(minAmount), widget.isDark, alignment: CrossAxisAlignment.start),
                _buildMetricChip("Promedio", AppCurrency.format(avgAmount), widget.isDark, alignment: CrossAxisAlignment.center),
                _buildMetricChip("Máximo", AppCurrency.format(maxAmount), widget.isDark, alignment: CrossAxisAlignment.end),
              ],
            ),
        ],
      ),
    );
  }

  void _handleTouch(Offset localPosition, int totalCount) {
    if (totalCount <= 1) return;
    final RenderBox? box = context.findRenderBox();
    final width = box?.size.width ?? 300;
    final step = width / (totalCount - 1);
    final index = (localPosition.dx / step).round().clamp(0, totalCount - 1);
    if (index != _selectedIndex) {
      setState(() => _selectedIndex = index);
    }
  }

  Widget _buildMetricChip(String label, String value, bool isDark, {CrossAxisAlignment alignment = CrossAxisAlignment.start}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: alignment,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[500] : Colors.grey[600]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: alignment == CrossAxisAlignment.end
                ? Alignment.centerRight
                : (alignment == CrossAxisAlignment.center ? Alignment.center : Alignment.centerLeft),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[300] : Colors.grey[800],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension on BuildContext {
  RenderBox? findRenderBox() {
    final render = findRenderObject();
    if (render is RenderBox) return render;
    return null;
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color lineColor;
  final bool isDark;
  final int? selectedIndex;

  _SparklinePainter({
    required this.data,
    required this.lineColor,
    required this.isDark,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    // Caso 1: Una sola compra registrada en el periodo (Coherente, sin pendiente falsa)
    if (data.length == 1) {
      final double midY = size.height / 2;
      final double midX = size.width / 2;

      // Línea base horizontal guía
      final Paint baseLinePaint = Paint()
        ..color = lineColor.withValues(alpha: 0.25)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(0, midY), Offset(size.width, midY), baseLinePaint);

      // Halo circular exterior brillante
      final Paint haloPaint = Paint()
        ..color = lineColor.withValues(alpha: 0.25)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(midX, midY), 10.0, haloPaint);

      // Círculo principal
      final Paint mainDotPaint = Paint()
        ..color = lineColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(midX, midY), 6.0, mainDotPaint);

      // Núcleo interno
      final Paint innerDotPaint = Paint()
        ..color = isDark ? const Color(0xFF1E1E2A) : Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(midX, midY), 2.5, innerDotPaint);
      return;
    }

    // Caso 2: Múltiples compras (>= 2)
    final double minVal = data.reduce((a, b) => a < b ? a : b);
    final double maxVal = data.reduce((a, b) => a > b ? a : b);
    final double range = (maxVal - minVal) == 0 ? 1.0 : (maxVal - minVal);

    final double stepX = size.width / (data.length - 1);

    final Path path = Path();
    final Path fillPath = Path();

    for (int i = 0; i < data.length; i++) {
      final double normalizedY = (maxVal == minVal) ? 0.5 : (data[i] - minVal) / range;
      final double x = i * stepX;
      final double y = size.height - (normalizedY * (size.height - 16)) - 8;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        final double prevX = (i - 1) * stepX;
        final double prevNormY = (maxVal == minVal) ? 0.5 : (data[i - 1] - minVal) / range;
        final double prevY = size.height - (prevNormY * (size.height - 16)) - 8;

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

    // Sombra / Gradiente inferior
    final Paint fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          lineColor.withValues(alpha: isDark ? 0.35 : 0.20),
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
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, strokePaint);

    // Dibujar nodos interactivos para cada compra
    final Paint dotPaint = Paint()..color = lineColor;
    final Paint dotInnerPaint = Paint()..color = isDark ? const Color(0xFF1E1E2A) : Colors.white;

    for (int i = 0; i < data.length; i++) {
      final double normalizedY = (maxVal == minVal) ? 0.5 : (data[i] - minVal) / range;
      final double x = i * stepX;
      final double y = size.height - (normalizedY * (size.height - 16)) - 8;

      final bool isSelected = selectedIndex == i;
      final double radius = isSelected ? 5.5 : 3.5;

      canvas.drawCircle(Offset(x, y), radius, dotPaint);
      if (isSelected) {
        canvas.drawCircle(Offset(x, y), 2.5, dotInnerPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.data != data ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.selectedIndex != selectedIndex;
}
