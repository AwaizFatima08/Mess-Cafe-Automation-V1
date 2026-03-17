import 'package:flutter/material.dart';

import '../../core/constants/reservation_constants.dart';
import '../../services/meal_reservation_service.dart';

class DashboardScreen extends StatefulWidget {
  final String userEmail;

  const DashboardScreen({super.key, required this.userEmail});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final MealReservationService _mealReservationService =
      MealReservationService();

  final DateTime _selectedDate = DateTime.now();

  bool _isLoading = true;
  String? _errorMessage;

  MealOpsSummary _breakfastSummary = MealOpsSummary.empty();
  MealOpsSummary _lunchSummary = MealOpsSummary.empty();
  MealOpsSummary _dinnerSummary = MealOpsSummary.empty();

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait<MealOpsSummary>([
        _buildMealSummary(ReservationConstants.breakfast),
        _buildMealSummary(ReservationConstants.lunch),
        _buildMealSummary(ReservationConstants.dinner),
      ]);

      if (!mounted) return;

      setState(() {
        _breakfastSummary = results[0];
        _lunchSummary = results[1];
        _dinnerSummary = results[2];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Failed to load mess operations dashboard: $e';
        _isLoading = false;
      });
    }
  }

  Future<MealOpsSummary> _buildMealSummary(String mealType) async {
    final reservations = await _mealReservationService
        .getReservationsForDateAndMealType(
      reservationDate: _selectedDate,
      mealType: mealType,
    );

    int employeeDineIn = 0;
    int employeeTakeaway = 0;
    int officialGuest = 0;

    for (final reservation in reservations) {
      if (reservation.status != ReservationConstants.active) {
        continue;
      }

      final count = reservation.totalMealCount;

      if (reservation.reservationCategory == ReservationConstants.employee) {
        if (reservation.serviceMode == ReservationConstants.takeaway) {
          employeeTakeaway += count;
        } else {
          employeeDineIn += count;
        }
      } else if (reservation.reservationCategory ==
          ReservationConstants.officialGuest) {
        officialGuest += count;
      }
    }

    return MealOpsSummary(
      mealType: mealType,
      employeeDineIn: employeeDineIn,
      employeeTakeaway: employeeTakeaway,
      officialGuest: officialGuest,
    );
  }

  String _formattedDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day-$month-$year';
  }

  String _mealTitle(String mealType) {
    switch (mealType) {
      case ReservationConstants.breakfast:
        return 'Breakfast';
      case ReservationConstants.lunch:
        return 'Lunch';
      case ReservationConstants.dinner:
        return 'Dinner';
      default:
        return mealType;
    }
  }

  IconData _mealIcon(String mealType) {
    switch (mealType) {
      case ReservationConstants.breakfast:
        return Icons.free_breakfast_outlined;
      case ReservationConstants.lunch:
        return Icons.lunch_dining_outlined;
      case ReservationConstants.dinner:
        return Icons.dinner_dining_outlined;
      default:
        return Icons.restaurant_outlined;
    }
  }

  int get _grandTotal =>
      _breakfastSummary.total +
      _lunchSummary.total +
      _dinnerSummary.total;

  Widget _buildTopSummaryCard({
    required String title,
    required int count,
    required IconData icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              '$count',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealSection(MealOpsSummary summary) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(_mealIcon(summary.mealType)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _mealTitle(summary.mealType),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Total ${summary.total}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildMetricRow(
              label: 'Employee Dine-In',
              value: summary.employeeDineIn,
              icon: Icons.restaurant,
            ),
            const Divider(height: 20),
            _buildMetricRow(
              label: 'Employee Takeaway',
              value: summary.employeeTakeaway,
              icon: Icons.takeout_dining_outlined,
            ),
            const Divider(height: 20),
            _buildMetricRow(
              label: 'Official Guest',
              value: summary.officialGuest,
              icon: Icons.groups_outlined,
            ),
            const Divider(height: 20),
            _buildMetricRow(
              label: 'Total',
              value: summary.total,
              icon: Icons.summarize_outlined,
              emphasized: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow({
    required String label,
    required int value,
    required IconData icon,
    bool emphasized = false,
  }) {
    final textStyle = emphasized
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyLarge;

    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: textStyle,
          ),
        ),
        Text(
          '$value',
          style: emphasized
              ? Theme.of(context).textTheme.titleLarge
              : Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mess Operations Dashboard',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Operational meal headcount for today',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Date: ${_formattedDate(_selectedDate)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Logged in as: ${widget.userEmail}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 42,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 12),
                Text(
                  _errorMessage ?? 'Unknown error',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _loadDashboard,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardBody() {
    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeaderCard(),
          const SizedBox(height: 12),
          _buildTopSummaryCard(
            title: 'Breakfast Total',
            count: _breakfastSummary.total,
            icon: Icons.free_breakfast_outlined,
          ),
          _buildTopSummaryCard(
            title: 'Lunch Total',
            count: _lunchSummary.total,
            icon: Icons.lunch_dining_outlined,
          ),
          _buildTopSummaryCard(
            title: 'Dinner Total',
            count: _dinnerSummary.total,
            icon: Icons.dinner_dining_outlined,
          ),
          _buildTopSummaryCard(
            title: 'Grand Total',
            count: _grandTotal,
            icon: Icons.summarize_outlined,
          ),
          const SizedBox(height: 12),
          _buildMealSection(_breakfastSummary),
          const SizedBox(height: 12),
          _buildMealSection(_lunchSummary),
          const SizedBox(height: 12),
          _buildMealSection(_dinnerSummary),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorState()
              : _buildDashboardBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _loadDashboard,
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh'),
      ),
    );
  }
}

class MealOpsSummary {
  final String mealType;
  final int employeeDineIn;
  final int employeeTakeaway;
  final int officialGuest;

  const MealOpsSummary({
    required this.mealType,
    required this.employeeDineIn,
    required this.employeeTakeaway,
    required this.officialGuest,
  });

  factory MealOpsSummary.empty() {
    return const MealOpsSummary(
      mealType: '',
      employeeDineIn: 0,
      employeeTakeaway: 0,
      officialGuest: 0,
    );
  }

  int get total => employeeDineIn + employeeTakeaway + officialGuest;
}
