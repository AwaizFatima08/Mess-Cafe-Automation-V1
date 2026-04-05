import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/meal_cost_reporting_service.dart';

class MealCostDashboardScreen extends StatefulWidget {
  const MealCostDashboardScreen({super.key});

  @override
  State<MealCostDashboardScreen> createState() =>
      _MealCostDashboardScreenState();
}

class _MealCostDashboardScreenState extends State<MealCostDashboardScreen> {
  final MealCostReportingService _reportingService =
      MealCostReportingService();

  late DateTime _selectedDate;
  bool _isLoading = true;
  MealCostDashboardData? _dashboardData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedDate = _resolveOperationalReferenceDate();
    _loadDashboard();
  }

  DateTime _resolveOperationalReferenceDate() {
    final now = DateTime.now();
    if (now.hour < 6) {
      return now.subtract(const Duration(days: 1));
    }
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _loadDashboard() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _reportingService.getDailyDashboard(_selectedDate);

      if (!mounted) return;

      setState(() {
        _dashboardData = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _dashboardData = null;
        _isLoading = false;
        _errorMessage = 'Failed to load cost dashboard: $e';
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now(),
    );

    if (picked == null) return;

    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
    });

    await _loadDashboard();
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

  Color _summaryCardColor(BuildContext context, int index) {
    final scheme = Theme.of(context).colorScheme;
    switch (index % 4) {
      case 0:
        return scheme.primaryContainer;
      case 1:
        return scheme.secondaryContainer;
      case 2:
        return scheme.tertiaryContainer;
      default:
        return scheme.surfaceContainerHighest;
    }
  }

  Widget _buildHeader() {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: _pickDate,
          icon: const Icon(Icons.calendar_today),
          label: Text(_formatDate(_selectedDate)),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Daily Meal Cost Dashboard',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          onPressed: _isLoading ? null : _loadDashboard,
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(MealCostDashboardData data) {
    final cards = <_SummaryCardData>[
      _SummaryCardData(
        title: 'Total Amount',
        value: _formatCurrency(data.totalAmount),
        subtitle: 'PKR',
        icon: Icons.payments_outlined,
      ),
      _SummaryCardData(
        title: 'Total Quantity',
        value: '${data.totalQuantity}',
        subtitle: 'meal units',
        icon: Icons.restaurant_outlined,
      ),
      _SummaryCardData(
        title: 'Avg Cost / Unit',
        value: _formatCurrency(data.averageCostPerMeal),
        subtitle: 'PKR',
        icon: Icons.calculate_outlined,
      ),
      _SummaryCardData(
        title: 'Active Lines',
        value: '${data.activeLines}',
        subtitle: 'reservations',
        icon: Icons.receipt_long_outlined,
      ),
      _SummaryCardData(
        title: 'Rated Lines',
        value: '${data.ratedLines}',
        subtitle: 'costed',
        icon: Icons.check_circle_outline,
      ),
      _SummaryCardData(
        title: 'Unrated Lines',
        value: '${data.unratedLines}',
        subtitle: 'pending rate',
        icon: Icons.pending_outlined,
      ),
      _SummaryCardData(
        title: 'Cancelled Lines',
        value: '${data.cancelledLines}',
        subtitle: 'ignored',
        icon: Icons.cancel_outlined,
      ),
      _SummaryCardData(
        title: 'Total Lines',
        value: '${data.totalLines}',
        subtitle: 'all records',
        icon: Icons.format_list_numbered,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int crossAxisCount = 1;
        double childAspectRatio = 2.8;

        if (width >= 1200) {
          crossAxisCount = 4;
          childAspectRatio = 2.3;
        } else if (width >= 800) {
          crossAxisCount = 3;
          childAspectRatio = 2.2;
        } else if (width >= 500) {
          crossAxisCount = 2;
          childAspectRatio = 2.0;
        }

        return GridView.builder(
          itemCount: cards.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (context, index) {
            final card = cards[index];

            return Card(
              color: _summaryCardColor(context, index),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(card.icon, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            card.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            card.value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            card.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMealTypeSection(MealCostDashboardData data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Meal-wise Costing',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Meal')),
                  DataColumn(label: Text('Lines')),
                  DataColumn(label: Text('Qty')),
                  DataColumn(label: Text('Amount (PKR)')),
                  DataColumn(label: Text('Avg / Unit')),
                ],
                rows: data.mealTypeSummaries.map((entry) {
                  return DataRow(
                    cells: [
                      DataCell(Text(_labelize(entry.mealType))),
                      DataCell(Text('${entry.lineCount}')),
                      DataCell(Text('${entry.totalQuantity}')),
                      DataCell(Text(_formatCurrency(entry.totalAmount))),
                      DataCell(Text(_formatCurrency(entry.averageCostPerUnit))),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectSection(MealCostDashboardData data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Employee vs Guest Costing',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Subject')),
                  DataColumn(label: Text('Lines')),
                  DataColumn(label: Text('Qty')),
                  DataColumn(label: Text('Amount (PKR)')),
                  DataColumn(label: Text('Avg / Unit')),
                ],
                rows: data.subjectSummaries.map((entry) {
                  return DataRow(
                    cells: [
                      DataCell(Text(_labelize(entry.subjectType))),
                      DataCell(Text('${entry.lineCount}')),
                      DataCell(Text('${entry.totalQuantity}')),
                      DataCell(Text(_formatCurrency(entry.totalAmount))),
                      DataCell(Text(_formatCurrency(entry.averageCostPerUnit))),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemSection(MealCostDashboardData data) {
    final items = data.itemSummaries;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Item-wise Costing',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Sorted by total amount (highest first)',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No item-wise cost data found for ${_formatDate(_selectedDate)}.',
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Item')),
                    DataColumn(label: Text('Category')),
                    DataColumn(label: Text('Meal Types')),
                    DataColumn(label: Text('Lines')),
                    DataColumn(label: Text('Qty')),
                    DataColumn(label: Text('Last Rate')),
                    DataColumn(label: Text('Total Amount')),
                    DataColumn(label: Text('Avg / Unit')),
                  ],
                  rows: items.map((entry) {
                    return DataRow(
                      cells: [
                        DataCell(Text(entry.itemName.isEmpty ? '—' : entry.itemName)),
                        DataCell(Text(entry.category.isEmpty ? '—' : entry.category)),
                        DataCell(Text(
                          entry.mealTypes.isEmpty
                              ? '—'
                              : entry.mealTypes.map(_labelize).join(', '),
                        )),
                        DataCell(Text('${entry.lineCount}')),
                        DataCell(Text('${entry.totalQuantity}')),
                        DataCell(Text(_formatCurrency(entry.lastUnitRate))),
                        DataCell(Text(_formatCurrency(entry.totalAmount))),
                        DataCell(Text(_formatCurrency(entry.averageCostPerUnit))),
                      ],
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final data = _dashboardData;

    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _errorMessage!,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (data == null) {
      return Center(
        child: Text(
          'No dashboard data available for ${_formatDate(_selectedDate)}.',
        ),
      );
    }

    if (data.totalLines == 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No costed reservation data found for ${_formatDate(_selectedDate)}.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildSummaryCards(data),
          const SizedBox(height: 16),
          _buildMealTypeSection(data),
          const SizedBox(height: 16),
          _buildSubjectSection(data),
          const SizedBox(height: 16),
          _buildItemSection(data),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Cost Dashboard'),
      ),
      body: _buildBody(),
    );
  }
}

class _SummaryCardData {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  const _SummaryCardData({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });
}
