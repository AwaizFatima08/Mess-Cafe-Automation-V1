import 'package:flutter/material.dart';

import '../models/analytics_kpi_model.dart';

class AnalyticsSummaryCard extends StatelessWidget {
  const AnalyticsSummaryCard({
    super.key,
    required this.kpi,
    this.icon,
  });

  final AnalyticsKpiModel kpi;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Color trendColor = kpi.isPositiveTrend
        ? Colors.green.shade700
        : Colors.red.shade700;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 14),
            ],
            Text(
              kpi.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              kpi.value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (kpi.subtitle != null && kpi.subtitle!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                kpi.subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade700,
                ),
              ),
            ],
            if (kpi.trendLabel != null && kpi.trendLabel!.trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    kpi.isPositiveTrend
                        ? Icons.trending_up
                        : Icons.trending_down,
                    size: 18,
                    color: trendColor,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      kpi.trendLabel!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: trendColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
