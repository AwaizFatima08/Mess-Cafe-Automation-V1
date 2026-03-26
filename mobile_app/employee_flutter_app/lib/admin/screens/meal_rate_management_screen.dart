import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/meal_rate_service.dart';

class MealRateManagementScreen extends StatefulWidget {
  const MealRateManagementScreen({super.key});

  @override
  State<MealRateManagementScreen> createState() =>
      _MealRateManagementScreenState();
}

class _MealRateManagementScreenState
    extends State<MealRateManagementScreen> {
  final MealRateService _service = MealRateService();

  DateTime _selectedDate = DateTime.now().subtract(const Duration(days: 1));
  bool _isLoading = true;
  bool _isSaving = false;

  List<MealRateEntryRow> _rows = [];

  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final rows = await _service.getRateEntryRowsForDate(_selectedDate);

    _controllers.clear();
    for (final row in rows) {
      _controllers[row.summary.menuItemId] = TextEditingController(
        text: row.initialRate > 0
            ? row.initialRate.toStringAsFixed(0)
            : '',
      );
    }

    setState(() {
      _rows = rows;
      _isLoading = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
      await _loadData();
    }
  }

  Future<void> _saveRates() async {
    setState(() => _isSaving = true);

    final drafts = _rows.map((row) {
      final controller = _controllers[row.summary.menuItemId];
      final rate = double.tryParse(controller?.text ?? '') ?? 0;

      return MealRateDraft(
        menuItemId: row.summary.menuItemId,
        itemName: row.summary.itemName,
        category: row.summary.category,
        unitRate: rate,
      );
    }).toList();

    await _service.saveRatesBatch(
      rateDate: _selectedDate,
      drafts: drafts,
    );

    await _service.applyRatesToReservationsForDate(_selectedDate);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rates saved and applied successfully')),
      );
    }

    setState(() => _isSaving = false);

    await _loadData();
  }

  Widget _buildHeader() {
    return Row(
      children: [
        ElevatedButton.icon(
          onPressed: _pickDate,
          icon: const Icon(Icons.calendar_today),
          label: Text(
            DateFormat('dd MMM yyyy').format(_selectedDate),
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'Enter Actual Rates (Previous Day)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _saveRates,
          icon: const Icon(Icons.save),
          label: _isSaving
              ? const Text('Saving...')
              : const Text('Save Rates'),
        ),
      ],
    );
  }

  Widget _buildTable() {
    if (_rows.isEmpty) {
      return const Center(
        child: Text('No consumption data found for this date'),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Item')),
          DataColumn(label: Text('Category')),
          DataColumn(label: Text('Qty')),
          DataColumn(label: Text('Rate')),
        ],
        rows: _rows.map((row) {
          final controller = _controllers[row.summary.menuItemId]!;

          return DataRow(
            cells: [
              DataCell(Text(row.summary.itemName)),
              DataCell(Text(row.summary.category)),
              DataCell(Text(row.summary.totalQuantity.toString())),
              DataCell(
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: '0',
                    ),
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Rate Management'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  Expanded(child: _buildTable()),
                ],
              ),
      ),
    );
  }
}
