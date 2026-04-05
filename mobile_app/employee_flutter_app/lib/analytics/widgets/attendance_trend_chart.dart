import 'dart:math' as math;

import 'package:flutter/material.dart';

class AttendanceTrendChart extends StatelessWidget {
  const AttendanceTrendChart({
    super.key,
    required this.dailyTrend,
    this.title = 'Attendance Trend',
  });

  final Map<String, int> dailyTrend;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = dailyTrend.entries.toList()
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
                    height: 260,
                    child: _AttendanceTrendPlot(entries: entries),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: entries.map((entry) {
                      return _TrendLegendChip(
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
      height: 240,
      child: Center(
        child: Text(
          'No attendance trend data available.',
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

class _AttendanceTrendPlot extends StatelessWidget {
  const _AttendanceTrendPlot({
    required this.entries,
  });

  final List<MapEntry<String, int>> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final values = entries.map((e) => e.value.toDouble()).toList();
    final maxValue = values.isEmpty
        ? 1
        : math.max(1, values.reduce((a, b) => a > b ? a : b).toInt());

    final yTicks = _buildYAxisTicks(maxValue);

    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 40,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: yTicks.reversed.map((tick) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        '$tick',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              Expanded(
                child: CustomPaint(
                  painter: _AttendanceTrendPainter(
                    values: values,
                    yTicks: yTicks,
                    lineColor: theme.colorScheme.primary,
                    axisColor: Colors.grey.shade400,
                    gridColor: Colors.grey.shade300,
                    pointFillColor: theme.colorScheme.primary,
                    pointStrokeColor: theme.colorScheme.surface,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 20,
          child: Row(
            children: List.generate(entries.length, (index) {
              final label = _compactBottomLabel(
                entries: entries,
                index: index,
              );

              return Expanded(
                child: Align(
                  alignment: index == 0
                      ? Alignment.centerLeft
                      : index == entries.length - 1
                          ? Alignment.centerRight
                          : Alignment.center,
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  List<int> _buildYAxisTicks(int maxValue) {
    if (maxValue <= 4) {
      return List<int>.generate(maxValue + 1, (index) => index);
    }

    final step = (maxValue / 4).ceil();
    return <int>[
      0,
      step,
      step * 2,
      step * 3,
      step * 4,
    ];
  }

  String _compactBottomLabel({
    required List<MapEntry<String, int>> entries,
    required int index,
  }) {
    final total = entries.length;
    final raw = entries[index].key;
    final parts = raw.split('-');
    if (parts.length != 3) return raw;

    final compact = '${parts[2]}/${parts[1]}';

    if (total <= 7) return compact;

    if (index == 0 || index == total - 1) return compact;

    final interval = (total / 4).ceil();
    if (index % interval == 0) return compact;

    return '';
  }
}

class _TrendLegendChip extends StatelessWidget {
  const _TrendLegendChip({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

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
        '$label: $value',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _AttendanceTrendPainter extends CustomPainter {
  _AttendanceTrendPainter({
    required this.values,
    required this.yTicks,
    required this.lineColor,
    required this.axisColor,
    required this.gridColor,
    required this.pointFillColor,
    required this.pointStrokeColor,
  });

  final List<double> values;
  final List<int> yTicks;
  final Color lineColor;
  final Color axisColor;
  final Color gridColor;
  final Color pointFillColor;
  final Color pointStrokeColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    const double topPadding = 10;
    const double bottomPadding = 12;
    const double leftPadding = 4;
    const double rightPadding = 10;

    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;

    if (chartWidth <= 0 || chartHeight <= 0) return;

    final chartRect = Rect.fromLTWH(
      leftPadding,
      topPadding,
      chartWidth,
      chartHeight,
    );

    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final pointFillPaint = Paint()
      ..color = pointFillColor
      ..style = PaintingStyle.fill;

    final pointStrokePaint = Paint()
      ..color = pointStrokeColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final maxValue = yTicks.isEmpty ? 1 : yTicks.last.clamp(1, 1 << 30);

    for (final tick in yTicks) {
      final ratio = maxValue == 0 ? 0.0 : tick / maxValue;
      final y = chartRect.bottom - (ratio * chartHeight);
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

    final points = <Offset>[];

    for (int i = 0; i < values.length; i++) {
      final dx = values.length == 1
          ? chartRect.left + (chartWidth / 2)
          : chartRect.left + (chartWidth / (values.length - 1)) * i;

      final normalized = maxValue == 0 ? 0.0 : (values[i] / maxValue);
      final dy = chartRect.bottom - (normalized * chartHeight);

      points.add(Offset(dx, dy));
    }

    if (points.isNotEmpty) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);

      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }

      canvas.drawPath(path, linePaint);

      for (final point in points) {
        canvas.drawCircle(point, 4.5, pointFillPaint);
        canvas.drawCircle(point, 4.5, pointStrokePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AttendanceTrendPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.yTicks != yTicks ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.pointFillColor != pointFillColor ||
        oldDelegate.pointStrokeColor != pointStrokeColor;
  }
}
