import 'package:flutter/material.dart';

class FeedbackDistributionChart extends StatelessWidget {
  const FeedbackDistributionChart({
    super.key,
    required this.ratingDistribution,
    this.title = 'Feedback Distribution',
  });

  final Map<int, int> ratingDistribution;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final normalized = <int, int>{
      1: ratingDistribution[1] ?? 0,
      2: ratingDistribution[2] ?? 0,
      3: ratingDistribution[3] ?? 0,
      4: ratingDistribution[4] ?? 0,
      5: ratingDistribution[5] ?? 0,
    };

    final int total = normalized.values.fold<int>(0, (sum, item) => sum + item);

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
                  const SizedBox(height: 18),
                  ...normalized.entries.toList().reversed.map((entry) {
                    final double ratio = total == 0 ? 0.0 : entry.value / total;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _RatingBarRow(
                        rating: entry.key,
                        value: entry.value,
                        ratio: ratio,
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
          'No feedback distribution data available.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}

class _RatingBarRow extends StatelessWidget {
  const _RatingBarRow({
    required this.rating,
    required this.value,
    required this.ratio,
  });

  final int rating;
  final int value;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double safeRatio = ratio.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(
                '$rating Star',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: safeRatio,
                  minHeight: 14,
                  backgroundColor: Colors.grey.shade300,
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 36,
              child: Text(
                '$value',
                textAlign: TextAlign.end,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '${(safeRatio * 100).toStringAsFixed(1)}%',
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}
