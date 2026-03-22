import 'package:cloud_firestore/cloud_firestore.dart';
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
  bool _isIssuing = false;
  String? _errorMessage;
  String? _debugStage;

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

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _pendingReservations = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _debugStage = null;
    });

    try {
      _debugStage = 'Loading planned counts';
      final planned = await _mealReservationService.getMealCountsForDate(
        selectedDate,
      );

      _debugStage = 'Loading issued counts';
      final issued = await _mealReservationService.getIssuedMealCountsForDate(
        selectedDate,
      );

      _debugStage = 'Loading pending reservations';
      final pendingDocs =
          await _mealReservationService.getPendingReservationsForDate(
        reservationDate: selectedDate,
      );

      if (!mounted) return;

      setState(() {
        _plannedCounts = planned;
        _issuedCounts = issued;
        _pendingReservations = pendingDocs;
        _isLoading = false;
        _debugStage = 'All dashboard data loaded';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage =
            'Failed during: ${_debugStage ?? 'unknown stage'}\n\n$e';
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
    final remaining =
        (_plannedCounts['total'] ?? 0) - (_issuedCounts['total'] ?? 0);
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

  Future<void> _issueMeal(String docId) async {
    if (_isIssuing) return;

    setState(() {
      _isIssuing = true;
    });

    try {
      await _mealReservationService.markReservationIssued(
        reservationId: docId,
        issuedByUid: widget.userEmail,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Meal issued successfully.'),
        ),
      );

      await _loadDashboardData();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Issue failed: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isIssuing = false;
        });
      }
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
                  child: SelectableText(
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
                    children: [
                      const Text(
                        'Booked Meals (Issuance)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_pendingReservations.isEmpty)
                        const Text('No pending reservations.')
                      else
                        ..._pendingReservations.map(
                          (doc) => _ReservationLineTile(
                            data: doc.data(),
                            docId: doc.id,
                            isBusy: _isIssuing,
                            onIssue: () => _issueMeal(doc.id),
                          ),
                        ),
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

class _ReservationLineTile extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final bool isBusy;
  final VoidCallback onIssue;

  const _ReservationLineTile({
    required this.data,
    required this.docId,
    required this.isBusy,
    required this.onIssue,
  });

  String _mealLabel(String value) {
    switch (value.toLowerCase()) {
      case 'breakfast':
        return 'Breakfast';
      case 'lunch':
        return 'Lunch';
      case 'dinner':
        return 'Dinner';
      default:
        return value;
    }
  }

  String _diningModeLabel(String value) {
    switch (value.toLowerCase()) {
      case 'dine_in':
        return 'Dine In';
      case 'takeaway':
        return 'Takeaway';
      default:
        return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    final employee = (data['employee_name'] ?? '').toString();
    final empNo = (data['employee_number'] ?? '').toString();
    final option = (data['option_label'] ?? '').toString();
    final mealType = (data['meal_type'] ?? '').toString();
    final mode = (data['dining_mode'] ?? '').toString();
    final qty = (data['quantity'] ?? 0).toString();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              employee.isEmpty ? 'Unknown Employee' : employee,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text('Employee No: $empNo'),
            const SizedBox(height: 4),
            Text('Meal: ${_mealLabel(mealType)}'),
            const SizedBox(height: 4),
            Text('Option: $option'),
            const SizedBox(height: 4),
            Text('Dining Mode: ${_diningModeLabel(mode)}'),
            const SizedBox(height: 4),
            Text('Quantity: $qty'),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: isBusy ? null : onIssue,
                icon: isBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: const Text('Issue Meal'),
              ),
            ),
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
