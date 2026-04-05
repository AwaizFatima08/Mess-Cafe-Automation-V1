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

  late DateTime _selectedDate;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  List<MealRateEntryRow> _rows = [];
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _selectedDate = _resolveOperationalReferenceDate();
    _loadData();
  }

  DateTime _resolveOperationalReferenceDate() {
    final now = DateTime.now();
    if (now.hour < 6) {
      return now.subtract(const Duration(days: 1));
    }
    return DateTime(now.year, now.month, now.day);
  }

  String _rowKey(MealRateEntryRow row) {
    return '${row.summary.menuItemId}__${row.summary.mealType}';
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final rows = await _service.getRateEntryRowsForDate(_selectedDate);

      for (final controller in _controllers.values) {
        controller.dispose();
      }
      _controllers.clear();

      for (final row in rows) {
        final key = _rowKey(row);
        _controllers[key] = TextEditingController(
          text: row.initialRate > 0 ? row.initialRate.toStringAsFixed(0) : '',
        );
      }

      if (!mounted) return;

      setState(() {
        _rows = rows;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _rows = [];
        _isLoading = false;
        _errorMessage = 'Failed to load meal rates: $e';
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
      });
      await _loadData();
    }
  }

  Future<void> _saveRates() async {
    if (_isSaving || _rows.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      final drafts = _rows.map((row) {
        final key = _rowKey(row);
        final controller = _controllers[key];
        final rate = double.tryParse(controller?.text.trim() ?? '') ?? 0;

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

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rates saved and applied successfully')),
      );

      await _loadData();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save/apply rates: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
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
        const Expanded(
          child: Text(
            'Enter Actual Rates',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: _isLoading ? null : _loadData,
          icon: const Icon(Icons.refresh),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: (_isSaving || _rows.isEmpty) ? null : _saveRates,
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
      return Center(
        child: Text(
          'No consumption data found for ${DateFormat('dd MMM yyyy').format(_selectedDate)}',
          textAlign: TextAlign.center,
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Item')),
          DataColumn(label: Text('Category')),
          DataColumn(label: Text('Meal')),
          DataColumn(label: Text('Qty')),
          DataColumn(label: Text('Rate')),
        ],
        rows: _rows.map((row) {
          final key = _rowKey(row);
          final controller = _controllers[key]!;

          return DataRow(
            cells: [
              DataCell(Text(row.summary.itemName.isEmpty ? '—' : row.summary.itemName)),
              DataCell(Text(row.summary.category.isEmpty ? '—' : row.summary.category)),
              DataCell(Text(row.summary.mealType.isEmpty ? '—' : row.summary.mealType)),
              DataCell(Text(row.summary.totalQuantity.toString())),
              DataCell(
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
    final body = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _errorMessage != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 16),
                  Expanded(child: _buildTable()),
                ],
              );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Rate Management'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: body,
      ),
    );
  }
}
