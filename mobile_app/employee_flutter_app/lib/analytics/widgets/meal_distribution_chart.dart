import 'package:flutter/material.dart';

class MealDistributionChart extends StatelessWidget {
  const MealDistributionChart({
    super.key,
    required this.mealWiseAttendance,
    this.title = 'Meal Distribution',
  });

  final Map<String, int> mealWiseAttendance;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final normalized = <String, int>{
      'breakfast': mealWiseAttendance['breakfast'] ?? 0,
      'lunch': mealWiseAttendance['lunch'] ?? 0,
      'dinner': mealWiseAttendance['dinner'] ?? 0,
    };

    final total = normalized.values.fold<int>(0, (sum, item) => sum + item);
    final highest = normalized.values.fold<int>(0, (max, item) => item > max ? item : max);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: total == 0
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
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      'Total attendance: $total',
                      style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  ...normalized.entries.map((entry) {
                    final ratio = total == 0 ? 0.0 : entry.value / total;
                    final relativeWidth = highest == 0 ? 0.0 : entry.value / highest;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _MealBarRow(
                        label: _formatLabel(entry.key),
                        value: entry.value,
                        ratio: ratio,
                        relativeWidth: relativeWidth,
                      ),
                    );
                  }),
                ],
              ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return SizedBox(
      height: 180,
      child: Center(
        child: Text(
          'No meal distribution data available.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  String _formatLabel(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1).toLowerCase();
  }
}

class _MealBarRow extends StatelessWidget {
  const _MealBarRow({
    required this.label,
    required this.value,
    required this.ratio,
    required this.relativeWidth,
  });

  final String label;
  final int value;
  final double ratio;
  final double relativeWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safeRatio = ratio.clamp(0.0, 1.0);
    final safeRelativeWidth = relativeWidth.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '$value',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: safeRelativeWidth,
            minHeight: 14,
            backgroundColor: Colors.grey.shade300,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${(safeRatio * 100).toStringAsFixed(1)}% of total',
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}
