import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/meal_feedback_service.dart';
import '../../services/my_meal_history_service.dart';

class MyMealHistoryScreen extends StatefulWidget {
  final String employeeNumber;
  final String employeeName;
  final String userUid;

  const MyMealHistoryScreen({
    super.key,
    required this.employeeNumber,
    required this.employeeName,
    required this.userUid,
  });

  @override
  State<MyMealHistoryScreen> createState() => _MyMealHistoryScreenState();
}

class _MyMealHistoryScreenState extends State<MyMealHistoryScreen> {
  final MyMealHistoryService _service = MyMealHistoryService();
  final MealFeedbackService _feedbackService = MealFeedbackService();

  late DateTime _selectedMonth;
  bool _isLoading = true;
  String? _errorMessage;
  MyMealHistoryData? _history;
  final Map<String, bool> _feedbackSubmittedMap = {};

  @override
  void initState() {
    super.initState();
    final defaultDate = _resolveOperationalReferenceDate();
    _selectedMonth = DateTime(defaultDate.year, defaultDate.month, 1);
    _loadHistory();
  }

  DateTime _resolveOperationalReferenceDate() {
    final now = DateTime.now();
    if (now.day == 1 && now.hour < 6) {
      return now.subtract(const Duration(days: 1));
    }
    return now;
  }

  Future<void> _loadHistory() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final nextMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + 1,
        1,
      );

      final data = await _service.getMealHistory(
        employeeNumber: widget.employeeNumber,
        fromDate: _selectedMonth,
        toDateExclusive: nextMonth,
      );

      final futures = data.entries.map((entry) async {
        try {
          final submitted = await _feedbackService.hasFeedbackForReservation(
            reservationId: entry.id,
            submittedByUid: widget.userUid,
          );
          return MapEntry(entry.id, submitted);
        } catch (_) {
          return MapEntry(entry.id, false);
        }
      }).toList();

      final submittedEntries = await Future.wait(futures);
      final submittedMap = <String, bool>{
        for (final entry in submittedEntries) entry.key: entry.value,
      };

      if (!mounted) return;

      setState(() {
        _history = data;
        _feedbackSubmittedMap
          ..clear()
          ..addAll(submittedMap);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _history = null;
        _feedbackSubmittedMap.clear();
        _isLoading = false;
        _errorMessage = 'Failed to load meal history: $e';
      });
    }
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(now.year - 2, 1, 1),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: 'Select any date in target month',
    );

    if (picked == null) return;

    setState(() {
      _selectedMonth = DateTime(picked.year, picked.month, 1);
    });

    await _loadHistory();
  }

  Future<void> _openFeedbackDialog(MyMealHistoryEntry entry) async {
    if (entry.feedbackTargetKey.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Feedback target could not be resolved for this entry.'),
        ),
      );
      return;
    }

    int selectedRating = 0;
    String selectedIssueType = '';
    bool isAnonymous = false;
    final controller = TextEditingController();

    try {
      final submitted = await showDialog<bool>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setLocalState) {
              return AlertDialog(
                title: Text(
                  'Feedback — ${entry.itemName.isEmpty ? 'Meal' : entry.itemName}',
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_labelize(entry.mealType)} • ${_labelize(entry.diningMode)}',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: List.generate(5, (i) {
                          return IconButton(
                            onPressed: () {
                              setLocalState(() {
                                selectedRating = i + 1;
                              });
                            },
                            icon: Icon(
                              i < selectedRating
                                  ? Icons.star
                                  : Icons.star_border,
                              color: Colors.orange,
                            ),
                          );
                        }),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: selectedIssueType,
                        decoration: const InputDecoration(
                          labelText: 'Issue Type (optional)',
                        ),
                        items: const [
                          DropdownMenuItem(value: '', child: Text('None')),
                          DropdownMenuItem(value: 'taste', child: Text('Taste')),
                          DropdownMenuItem(value: 'quality', child: Text('Quality')),
                          DropdownMenuItem(value: 'quantity', child: Text('Quantity')),
                          DropdownMenuItem(value: 'service', child: Text('Service')),
                        ],
                        onChanged: (value) {
                          setLocalState(() {
                            selectedIssueType = value ?? '';
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: controller,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Comments',
                          hintText: 'Write your feedback...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        value: isAnonymous,
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Submit anonymously'),
                        onChanged: (value) {
                          setLocalState(() {
                            isAnonymous = value ?? false;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: selectedRating <= 0
                        ? null
                        : () => Navigator.pop(context, true),
                    child: const Text('Submit'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (submitted != true) {
        return;
      }

      await _feedbackService.submitFeedback(
        reservationId: entry.id,
        submittedByUid: widget.userUid,
        submittedByName: widget.employeeName,
        employeeNumber: widget.employeeNumber,
        employeeName: widget.employeeName,
        reservationDate: entry.reservationDate,
        mealType: entry.mealType,
        menuItemId: entry.feedbackTargetKey,
        itemName: entry.itemName.isEmpty ? 'Meal' : entry.itemName,
        category: entry.category,
        rating: selectedRating,
        feedbackText: controller.text.trim(),
        issueType: selectedIssueType,
        isAnonymous: isAnonymous,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Feedback submitted successfully')),
      );

      await _loadHistory();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Feedback submission failed: $e')),
      );
    } finally {
      controller.dispose();
    }
  }

  String _formatMonth(DateTime value) {
    return DateFormat('MMM yyyy').format(value);
  }

  String _formatDate(DateTime value) {
    return DateFormat('dd MMM yyyy').format(value);
  }

  String _formatCurrency(double value) {
    return value.toStringAsFixed(2);
  }

  String _labelize(String value) {
    if (value.trim().isEmpty) return '—';

    return value
        .replaceAll('_', ' ')
        .split(' ')
        .map((part) {
          if (part.isEmpty) return part;
          return part[0].toUpperCase() + part.substring(1);
        })
        .join(' ');
  }

  Color _statusColor(String status) {
    switch (status.trim().toLowerCase()) {
      case 'issued':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'active':
        return Colors.orange;
      default:
        return Colors.blueGrey;
    }
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(icon, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(MyMealHistoryData data) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int crossAxisCount = 1;
        double childAspectRatio = 2.5;

        if (width >= 1100) {
          crossAxisCount = 5;
          childAspectRatio = 2.2;
        } else if (width >= 850) {
          crossAxisCount = 3;
          childAspectRatio = 2.15;
        } else if (width >= 600) {
          crossAxisCount = 2;
          childAspectRatio = 2.2;
        }

        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: childAspectRatio,
          children: [
            _buildSummaryCard(
              title: 'Total Amount',
              value: _formatCurrency(data.totalAmount),
              subtitle: 'month billed',
              icon: Icons.payments_outlined,
            ),
            _buildSummaryCard(
              title: 'Total Quantity',
              value: '${data.totalQuantity}',
              subtitle: 'meal units',
              icon: Icons.restaurant_outlined,
            ),
            _buildSummaryCard(
              title: 'Issued Lines',
              value: '${data.issuedCount}',
              subtitle: 'consumed / issued',
              icon: Icons.check_circle_outline,
            ),
            _buildSummaryCard(
              title: 'Active Lines',
              value: '${data.activeCount}',
              subtitle: 'non-cancelled',
              icon: Icons.receipt_long_outlined,
            ),
            _buildSummaryCard(
              title: 'Cancelled',
              value: '${data.cancelledCount}',
              subtitle: 'excluded from totals',
              icon: Icons.cancel_outlined,
            ),
          ],
        );
      },
    );
  }

  Widget _buildHistoryTable(MyMealHistoryData data) {
    if (data.entries.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text('No meal history found for selected month.'),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Meal')),
              DataColumn(label: Text('Item')),
              DataColumn(label: Text('Category')),
              DataColumn(label: Text('Mode')),
              DataColumn(label: Text('Qty')),
              DataColumn(label: Text('Unit Rate')),
              DataColumn(label: Text('Amount')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Feedback')),
            ],
            rows: data.entries.map((entry) {
              final alreadySubmitted = _feedbackSubmittedMap[entry.id] == true;
              final canGiveFeedback = entry.status != 'cancelled' &&
                  entry.isIssued &&
                  !alreadySubmitted &&
                  entry.feedbackTargetKey.trim().isNotEmpty;

              return DataRow(
                cells: [
                  DataCell(Text(_formatDate(entry.reservationDate))),
                  DataCell(Text(_labelize(entry.mealType))),
                  DataCell(Text(entry.itemName.isEmpty ? '—' : entry.itemName)),
                  DataCell(Text(entry.category.isEmpty ? '—' : _labelize(entry.category))),
                  DataCell(Text(_labelize(entry.diningMode))),
                  DataCell(Text('${entry.quantity}')),
                  DataCell(Text(_formatCurrency(entry.unitRate))),
                  DataCell(Text(_formatCurrency(entry.amount))),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _statusColor(entry.status).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _statusColor(entry.status).withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        _labelize(entry.status),
                        style: TextStyle(
                          color: _statusColor(entry.status),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    alreadySubmitted
                        ? const Text(
                            'Submitted',
                            style: TextStyle(color: Colors.green),
                          )
                        : canGiveFeedback
                            ? OutlinedButton(
                                onPressed: () => _openFeedbackDialog(entry),
                                child: const Text('Give Feedback'),
                              )
                            : const Text('—'),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _errorMessage!,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final history = _history;
    if (history == null) {
      return const Center(child: Text('Unable to load meal history.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _pickMonth,
                icon: const Icon(Icons.calendar_today),
                label: Text(_formatMonth(_selectedMonth)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'My Meal History — ${widget.employeeName}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                onPressed: _isLoading ? null : _loadHistory,
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSummary(history),
          const SizedBox(height: 16),
          _buildHistoryTable(history),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Meal History'),
      ),
      body: _buildBody(),
    );
  }
}
