import 'dart:math' as math;

import 'package:flutter/material.dart';

class CostTrendChart extends StatelessWidget {
  const CostTrendChart({
    super.key,
    required this.dailyCostTrend,
    this.title = 'Cost Trend',
  });

  final Map<String, double> dailyCostTrend;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = dailyCostTrend.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: entries.isEmpty
            ? _buildEmptyState(theme)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 220,
                    child: CustomPaint(
                      painter: _CostTrendPainter(
                        values: entries.map((e) => e.value).toList(),
                        lineColor: theme.colorScheme.primary,
                        axisColor: Colors.grey.shade400,
                        gridColor: Colors.grey.shade300,
                      ),
                      child: Container(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: entries.map((entry) {
                      return _CostLegendChip(
                        label: _shortDate(entry.key),
                        value: entry.value,
                      );
                    }).toList(),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return SizedBox(
      height: 220,
      child: Center(
        child: Text(
          'No cost trend data available.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  String _shortDate(String input) {
    final parts = input.split('-');
    if (parts.length != 3) return input;
    return '${parts[2]}/${parts[1]}';
  }
}

class _CostLegendChip extends StatelessWidget {
  const _CostLegendChip({
    required this.label,
    required this.value,
  });

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        '$label: PKR ${value.toStringAsFixed(2)}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _CostTrendPainter extends CustomPainter {
  _CostTrendPainter({
    required this.values,
    required this.lineColor,
    required this.axisColor,
    required this.gridColor,
  });

  final List<double> values;
  final Color lineColor;
  final Color axisColor;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    const double leftPadding = 28;
    const double bottomPadding = 20;
    const double topPadding = 12;
    const double rightPadding = 12;

    final double chartWidth = size.width - leftPadding - rightPadding;
    final double chartHeight = size.height - topPadding - bottomPadding;

    if (chartWidth <= 0 || chartHeight <= 0) return;

    final Rect chartRect = Rect.fromLTWH(
      leftPadding,
      topPadding,
      chartWidth,
      chartHeight,
    );

    final Paint axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final Paint gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    final Paint linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final Paint dotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    for (int i = 0; i <= 4; i++) {
      final double y = chartRect.top + (chartHeight / 4) * i;
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
    }

    canvas.drawLine(
      Offset(chartRect.left, chartRect.top),
      Offset(chartRect.left, chartRect.bottom),
      axisPaint,
    );
    canvas.drawLine(
      Offset(chartRect.left, chartRect.bottom),
      Offset(chartRect.right, chartRect.bottom),
      axisPaint,
    );

    final double maxValue = math.max(
      1.0,
      values.reduce((a, b) => a > b ? a : b),
    );

    final Path path = Path();

    for (int i = 0; i < values.length; i++) {
      final double dx = values.length == 1
          ? chartRect.left + (chartWidth / 2)
          : chartRect.left + (chartWidth / (values.length - 1)) * i;

      final double normalized = values[i] / maxValue;
      final double dy = chartRect.bottom - (normalized * chartHeight);

      if (i == 0) {
        path.moveTo(dx, dy);
      } else {
        path.lineTo(dx, dy);
      }
    }

    canvas.drawPath(path, linePaint);

    for (int i = 0; i < values.length; i++) {
      final double dx = values.length == 1
          ? chartRect.left + (chartWidth / 2)
          : chartRect.left + (chartWidth / (values.length - 1)) * i;

      final double normalized = values[i] / maxValue;
      final double dy = chartRect.bottom - (normalized * chartHeight);

      canvas.drawCircle(Offset(dx, dy), 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CostTrendPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.gridColor != gridColor;
  }
}
