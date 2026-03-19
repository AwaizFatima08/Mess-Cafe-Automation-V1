import 'package:flutter/material.dart';

import '../../services/meal_reservation_service.dart';

class DashboardScreen extends StatefulWidget {
  final String userEmail;

  const DashboardScreen({
    super.key,
    required this.userEmail,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final MealReservationService _mealReservationService =
      MealReservationService();

  DateTime selectedDate = DateTime.now();

  bool _isLoading = true;
  String? _errorMessage;

  Map<String, int> _plannedCounts = {
    'breakfast': 0,
    'lunch': 0,
    'dinner': 0,
    'total': 0,
  };

  Map<String, int> _issuedCounts = {
    'breakfast': 0,
    'lunch': 0,
    'dinner': 0,
    'total': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final planned = await _mealReservationService.getMealCountsForDate(
        selectedDate,
      );

      final issued = await _mealReservationService.getIssuedMealCountsForDate(
        selectedDate,
      );

      if (!mounted) return;

      setState(() {
        _plannedCounts = planned;
        _issuedCounts = issued;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Failed to load dashboard data: $e';
        _isLoading = false;
      });
    }
  }

  int _remainingFor(String mealType) {
    final planned = _plannedCounts[mealType] ?? 0;
    final issued = _issuedCounts[mealType] ?? 0;
    final remaining = planned - issued;
    return remaining < 0 ? 0 : remaining;
  }

  int get _totalRemaining {
    final remaining = (_plannedCounts['total'] ?? 0) - (_issuedCounts['total'] ?? 0);
    return remaining < 0 ? 0 : remaining;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2035),
    );

    if (picked != null) {
      setState(() {
        selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
        );
      });
      await _loadDashboardData();
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day-$month-$year';
  }

  @override
  Widget build(BuildContext context) {
    final cards = [
      _MealSummaryCardData(
        mealLabel: 'Breakfast',
        planned: _plannedCounts['breakfast'] ?? 0,
        issued: _issuedCounts['breakfast'] ?? 0,
        remaining: _remainingFor('breakfast'),
        icon: Icons.free_breakfast_outlined,
      ),
      _MealSummaryCardData(
        mealLabel: 'Lunch',
        planned: _plannedCounts['lunch'] ?? 0,
        issued: _issuedCounts['lunch'] ?? 0,
        remaining: _remainingFor('lunch'),
        icon: Icons.lunch_dining_outlined,
      ),
      _MealSummaryCardData(
        mealLabel: 'Dinner',
        planned: _plannedCounts['dinner'] ?? 0,
        issued: _issuedCounts['dinner'] ?? 0,
        remaining: _remainingFor('dinner'),
        icon: Icons.dinner_dining_outlined,
      ),
    ];

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  runSpacing: 12,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Operational Dashboard',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Signed in as: ${widget.userEmail}',
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Date: ${_formatDate(selectedDate)}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_month_outlined),
                          label: const Text('Select Date'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _loadDashboardData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Refresh'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_errorMessage != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              )
            else ...[
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cards.length,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 320,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.25,
                ),
                itemBuilder: (context, index) {
                  final card = cards[index];
                  return _MealSummaryCard(card: card);
                },
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Daily Totals',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SummaryRow(
                        label: 'Planned Meals',
                        value: (_plannedCounts['total'] ?? 0).toString(),
                      ),
                      const SizedBox(height: 8),
                      _SummaryRow(
                        label: 'Issued Meals',
                        value: (_issuedCounts['total'] ?? 0).toString(),
                      ),
                      const SizedBox(height: 8),
                      _SummaryRow(
                        label: 'Remaining Meals',
                        value: _totalRemaining.toString(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Next Dashboard Evolution',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text('• Planned vs issued vs remaining is now aligned.'),
                      SizedBox(height: 6),
                      Text('• Next layer can add live issuance operations.'),
                      SizedBox(height: 6),
                      Text('• Later this dashboard can include guest split, dine-in vs takeaway, and rate-linked summaries.'),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MealSummaryCardData {
  final String mealLabel;
  final int planned;
  final int issued;
  final int remaining;
  final IconData icon;

  const _MealSummaryCardData({
    required this.mealLabel,
    required this.planned,
    required this.issued,
    required this.remaining,
    required this.icon,
  });
}

class _MealSummaryCard extends StatelessWidget {
  final _MealSummaryCardData card;

  const _MealSummaryCard({
    required this.card,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(card.icon),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    card.mealLabel,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            _MetricLine(label: 'Planned', value: card.planned),
            const SizedBox(height: 8),
            _MetricLine(label: 'Issued', value: card.issued),
            const SizedBox(height: 8),
            _MetricLine(label: 'Remaining', value: card.remaining),
          ],
        ),
      ),
    );
  }
}

class _MetricLine extends StatelessWidget {
  final String label;
  final int value;

  const _MetricLine({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          value.toString(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
