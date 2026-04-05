import 'package:flutter/material.dart';

import '../models/analytics_filter_model.dart';
import '../models/analytics_kpi_model.dart';
import '../models/attendance_analytics_result.dart';
import '../models/cost_analytics_result.dart';
import '../models/feedback_analytics_result.dart';
import '../services/attendance_analytics_service.dart';
import '../services/cost_analytics_service.dart';
import '../services/feedback_analytics_service.dart';
import '../widgets/analytics_filter_bar.dart';
import '../widgets/analytics_summary_card.dart';
import '../widgets/attendance_trend_chart.dart';
import '../widgets/cost_trend_chart.dart';
import '../widgets/feedback_distribution_chart.dart';
import '../widgets/meal_distribution_chart.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  State<AnalyticsDashboardScreen> createState() =>
      _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  final AttendanceAnalyticsService _attendanceAnalyticsService =
      AttendanceAnalyticsService();
  final CostAnalyticsService _costAnalyticsService = CostAnalyticsService();
  final FeedbackAnalyticsService _feedbackAnalyticsService =
      FeedbackAnalyticsService();

  late AnalyticsFilterModel _defaultFilter;
  late AnalyticsFilterModel _activeFilter;

  bool _isLoading = true;
  String? _errorMessage;

  AttendanceAnalyticsResult _attendanceResult =
      AttendanceAnalyticsResult.empty();
  CostAnalyticsResult _costResult = CostAnalyticsResult.empty();
  FeedbackAnalyticsResult _feedbackResult = FeedbackAnalyticsResult.empty();

  @override
  void initState() {
    super.initState();
    _defaultFilter = _buildDefaultFilter();
    _activeFilter = _defaultFilter;
    _loadAnalytics();
  }

  DateTime _resolveOperationalReferenceDate() {
    final now = DateTime.now();
    if (now.hour < 6) {
      final adjusted = now.subtract(const Duration(days: 1));
      return DateTime(adjusted.year, adjusted.month, adjusted.day);
    }
    return DateTime(now.year, now.month, now.day);
  }

  AnalyticsFilterModel _buildDefaultFilter() {
    final end = _resolveOperationalReferenceDate();
    final start = end.subtract(const Duration(days: 6));

    return AnalyticsFilterModel(
      startDate: start,
      endDate: end,
      mealTypes: const ['breakfast', 'lunch', 'dinner'],
      includeGuests: true,
    );
  }

  Future<void> _loadAnalytics() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait<dynamic>([
        _attendanceAnalyticsService.fetchAttendanceAnalytics(_activeFilter),
        _costAnalyticsService.fetchCostAnalytics(_activeFilter),
        _feedbackAnalyticsService.fetchFeedbackAnalytics(_activeFilter),
      ]);

      if (!mounted) return;

      setState(() {
        _attendanceResult = results[0] as AttendanceAnalyticsResult;
        _costResult = results[1] as CostAnalyticsResult;
        _feedbackResult = results[2] as FeedbackAnalyticsResult;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Failed to load analytics: $e';
        _isLoading = false;
      });
    }
  }

  void _applyFilter(AnalyticsFilterModel filter) {
    setState(() {
      _activeFilter = filter;
    });
    _loadAnalytics();
  }

  void _resetFilter() {
    final resetFilter = _buildDefaultFilter();

    setState(() {
      _defaultFilter = resetFilter;
      _activeFilter = resetFilter;
    });

    _loadAnalytics();
  }

  bool get _hasAnyAnalyticsData {
    return _attendanceResult.totalAttendance > 0 ||
        _costResult.totalCost > 0 ||
        _feedbackResult.totalResponses > 0;
  }

  List<AnalyticsKpiModel> _buildAttendanceKpis() {
    final breakfast = _attendanceResult.mealWiseAttendance['breakfast'] ?? 0;
    final lunch = _attendanceResult.mealWiseAttendance['lunch'] ?? 0;
    final dinner = _attendanceResult.mealWiseAttendance['dinner'] ?? 0;

    return [
      AnalyticsKpiModel(
        title: 'Total Attendance',
        value: _attendanceResult.totalAttendance.toString(),
        subtitle: _buildDateRangeLabel(),
      ),
      AnalyticsKpiModel(
        title: 'Employees',
        value: _attendanceResult.totalEmployees.toString(),
        subtitle: 'Employee attendance count',
      ),
      AnalyticsKpiModel(
        title: 'Guests',
        value: _attendanceResult.totalGuests.toString(),
        subtitle: 'Guest attendance count',
      ),
      AnalyticsKpiModel(
        title: 'Breakfast',
        value: breakfast.toString(),
        subtitle: 'Breakfast attendance',
      ),
      AnalyticsKpiModel(
        title: 'Lunch',
        value: lunch.toString(),
        subtitle: 'Lunch attendance',
      ),
      AnalyticsKpiModel(
        title: 'Dinner',
        value: dinner.toString(),
        subtitle: 'Dinner attendance',
      ),
    ];
  }

  List<AnalyticsKpiModel> _buildCostKpis() {
    return [
      AnalyticsKpiModel(
        title: 'Total Cost',
        value: _formatCurrency(_costResult.totalCost),
        subtitle: 'Overall meal cost',
      ),
      AnalyticsKpiModel(
        title: 'Employee Cost',
        value: _formatCurrency(_costResult.employeeCost),
        subtitle: 'Employee-linked cost',
      ),
      AnalyticsKpiModel(
        title: 'Guest Cost',
        value: _formatCurrency(_costResult.guestCost),
        subtitle: 'Guest-linked cost',
      ),
      AnalyticsKpiModel(
        title: 'Avg Cost / Head',
        value: _formatCurrency(_costResult.averageCostPerHead),
        subtitle: 'Average cost per meal head',
      ),
    ];
  }

  List<AnalyticsKpiModel> _buildFeedbackKpis() {
    final rating5 = _feedbackResult.ratingDistribution[5] ?? 0;
    final rating4 = _feedbackResult.ratingDistribution[4] ?? 0;
    final rating3 = _feedbackResult.ratingDistribution[3] ?? 0;

    return [
      AnalyticsKpiModel(
        title: 'Responses',
        value: _feedbackResult.totalResponses.toString(),
        subtitle: 'Total feedback responses',
      ),
      AnalyticsKpiModel(
        title: 'Avg Rating',
        value: _feedbackResult.averageRating.toStringAsFixed(2),
        subtitle: 'Average rating out of 5',
      ),
      AnalyticsKpiModel(
        title: '5-Star',
        value: rating5.toString(),
        subtitle: 'Top rating responses',
      ),
      AnalyticsKpiModel(
        title: '4-Star',
        value: rating4.toString(),
        subtitle: 'Strong positive responses',
      ),
      AnalyticsKpiModel(
        title: '3-Star',
        value: rating3.toString(),
        subtitle: 'Neutral responses',
      ),
    ];
  }

  String _buildDateRangeLabel() {
    return '${_formatDate(_activeFilter.startDate)} to ${_formatDate(_activeFilter.endDate)}';
  }

  String _buildMealTypeLabel() {
    final mealTypes = _activeFilter.mealTypes;
    if (mealTypes == null || mealTypes.isEmpty) {
      return 'All meal types';
    }

    return mealTypes
        .map((e) {
          final value = e.trim();
          if (value.isEmpty) return value;
          return value[0].toUpperCase() + value.substring(1);
        })
        .join(', ');
  }

  String _buildGuestScopeLabel() {
    return _activeFilter.includeGuests
        ? 'Employees + guests included'
        : 'Employees only';
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day-$month-$year';
  }

  String _formatCurrency(double value) {
    return 'PKR ${value.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final attendanceKpis = _buildAttendanceKpis();
    final costKpis = _buildCostKpis();
    final feedbackKpis = _buildFeedbackKpis();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadAnalytics,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAnalytics,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : _errorMessage != null
                ? _buildErrorState()
                : _buildContent(
                    attendanceKpis: attendanceKpis,
                    costKpis: costKpis,
                    feedbackKpis: feedbackKpis,
                  ),
      ),
    );
  }

  Widget _buildErrorState() {
    final theme = Theme.of(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 60),
        Icon(
          Icons.error_outline,
          size: 54,
          color: Colors.red.shade400,
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Failed to load analytics',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            _errorMessage ?? 'Unknown error',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: ElevatedButton.icon(
            onPressed: _loadAnalytics,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ),
      ],
    );
  }

  Widget _buildContent({
    required List<AnalyticsKpiModel> attendanceKpis,
    required List<AnalyticsKpiModel> costKpis,
    required List<AnalyticsKpiModel> feedbackKpis,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeaderCard(),
        const SizedBox(height: 16),
        AnalyticsFilterBar(
          key: ValueKey<String>(_buildFilterKey()),
          initialFilter: _activeFilter,
          onApply: _applyFilter,
          onReset: _resetFilter,
        ),
        const SizedBox(height: 16),
        if (!_hasAnyAnalyticsData)
          _buildEmptyState()
        else ...[
          _buildSectionTitle('Attendance KPIs'),
          const SizedBox(height: 10),
          _buildKpiGrid(
            attendanceKpis,
            iconMap: const <String, IconData>{
              'Total Attendance': Icons.groups_outlined,
              'Employees': Icons.badge_outlined,
              'Guests': Icons.person_add_alt_1_outlined,
              'Breakfast': Icons.free_breakfast_outlined,
              'Lunch': Icons.lunch_dining_outlined,
              'Dinner': Icons.dinner_dining_outlined,
            },
          ),
          const SizedBox(height: 16),
          AttendanceTrendChart(
            dailyTrend: _attendanceResult.dailyTrend,
          ),
          const SizedBox(height: 16),
          MealDistributionChart(
            mealWiseAttendance: _attendanceResult.mealWiseAttendance,
          ),
          const SizedBox(height: 20),
          _buildSectionTitle('Cost KPIs'),
          const SizedBox(height: 10),
          _buildKpiGrid(
            costKpis,
            iconMap: const <String, IconData>{
              'Total Cost': Icons.account_balance_wallet_outlined,
              'Employee Cost': Icons.badge_outlined,
              'Guest Cost': Icons.person_add_alt_1_outlined,
              'Avg Cost / Head': Icons.calculate_outlined,
            },
          ),
          const SizedBox(height: 16),
          CostTrendChart(
            dailyCostTrend: _costResult.dailyCostTrend,
          ),
          const SizedBox(height: 20),
          _buildSectionTitle('Feedback KPIs'),
          const SizedBox(height: 10),
          _buildKpiGrid(
            feedbackKpis,
            iconMap: const <String, IconData>{
              'Responses': Icons.rate_review_outlined,
              'Avg Rating': Icons.star_outline,
              '5-Star': Icons.star,
              '4-Star': Icons.star_half,
              '3-Star': Icons.star_border,
            },
          ),
          const SizedBox(height: 16),
          FeedbackDistributionChart(
            ratingDistribution: _feedbackResult.ratingDistribution,
          ),
        ],
      ],
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.analytics_outlined,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Integrated Analytics',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _buildDateRangeLabel(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _buildMealTypeLabel(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _buildGuestScopeLabel(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.insights_outlined,
              size: 44,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'No analytics data found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'No attendance, cost, or feedback records matched the selected filter range.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              '${_buildDateRangeLabel()} • ${_buildMealTypeLabel()} • ${_buildGuestScopeLabel()}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade700,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }

  Widget _buildKpiGrid(
    List<AnalyticsKpiModel> kpis, {
    required Map<String, IconData> iconMap,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        int crossAxisCount = 1;
        double childAspectRatio = 2.6;

        if (width >= 1100) {
          crossAxisCount = 4;
          childAspectRatio = 1.65;
        } else if (width >= 800) {
          crossAxisCount = 3;
          childAspectRatio = 1.45;
        } else if (width >= 520) {
          crossAxisCount = 2;
          childAspectRatio = 1.28;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: kpis.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (context, index) {
            final kpi = kpis[index];
            return AnalyticsSummaryCard(
              kpi: kpi,
              icon: iconMap[kpi.title],
            );
          },
        );
      },
    );
  }

  String _buildFilterKey() {
    final start = _activeFilter.startDate.toIso8601String();
    final end = _activeFilter.endDate.toIso8601String();
    final meals = (_activeFilter.mealTypes ?? const <String>[]).join(',');
    final guests = _activeFilter.includeGuests ? '1' : '0';
    final employee = _activeFilter.employeeNumber ?? '';
    return '$start|$end|$meals|$guests|$employee';
  }
}
