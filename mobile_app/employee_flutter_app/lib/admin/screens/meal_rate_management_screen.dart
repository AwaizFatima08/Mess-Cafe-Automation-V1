import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/meal_rate_service.dart';

class MealRateManagementScreen extends StatefulWidget {
  const MealRateManagementScreen({super.key});

  @override
  State<MealRateManagementScreen> createState() =>
      _MealRateManagementScreenState();
}

class _MealRateManagementScreenState extends State<MealRateManagementScreen> {
  final MealRateService _service = MealRateService();

  late DateTime _selectedDate;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;

  List<MealRateEntryRow> _rows = [];
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String> _initialValues = {};
  final Set<String> _dirtyRowKeys = <String>{};

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

  String _normalizedRateText(double value) {
    if (value <= 0) return '';
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  String _normalizeInputValue(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '';

    final parsed = double.tryParse(text);
    if (parsed == null) {
      return text;
    }

    if (parsed == parsed.roundToDouble()) {
      return parsed.toStringAsFixed(0);
    }
    return parsed.toStringAsFixed(2);
  }

  int get _dirtyCount => _dirtyRowKeys.length;

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
      _initialValues.clear();
      _dirtyRowKeys.clear();

      for (final row in rows) {
        final key = _rowKey(row);
        final initialText = _normalizedRateText(row.initialRate);
        _initialValues[key] = initialText;
        _controllers[key] = TextEditingController(text: initialText);
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

  void _markDirty(MealRateEntryRow row, String value) {
    final key = _rowKey(row);
    final normalizedCurrent = _normalizeInputValue(value);
    final normalizedInitial = _initialValues[key] ?? '';

    final isDirty = normalizedCurrent != normalizedInitial;

    if (isDirty == _dirtyRowKeys.contains(key)) {
      return;
    }

    setState(() {
      if (isDirty) {
        _dirtyRowKeys.add(key);
      } else {
        _dirtyRowKeys.remove(key);
      }
    });
  }

  Future<void> _saveRates() async {
    if (_isSaving || _rows.isEmpty || _dirtyRowKeys.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      final drafts = <MealRateDraft>[];

      for (final row in _rows) {
        final key = _rowKey(row);
        if (!_dirtyRowKeys.contains(key)) {
          continue;
        }

        final controller = _controllers[key];
        final rate = double.tryParse(controller?.text.trim() ?? '') ?? 0;

        drafts.add(
          MealRateDraft(
            menuItemId: row.summary.menuItemId,
            itemName: row.summary.itemName,
            category: row.summary.category,
            unitRate: rate,
          ),
        );
      }

      final result = await _service.saveRatesBatchAndApplyToReservationsForDate(
        rateDate: _selectedDate,
        drafts: drafts,
      );

      if (!mounted) return;

      final updatedRows = _rows.map((row) {
        final key = _rowKey(row);
        if (!_dirtyRowKeys.contains(key)) {
          return row;
        }

        final controller = _controllers[key];
        final newRate = double.tryParse(controller?.text.trim() ?? '') ?? 0;

        final now = DateTime.now();
        return MealRateEntryRow(
          summary: row.summary,
          existingRate: MealRateEntry(
            documentId: _service.buildRateDocumentId(
              rateDate: _selectedDate,
              menuItemId: row.summary.menuItemId,
            ),
            menuItemId: row.summary.menuItemId,
            rateTargetKey: row.summary.menuItemId,
            itemName: row.summary.itemName,
            category: row.summary.category,
            rateDate: _selectedDate,
            unitRate: newRate,
            isActive: true,
            enteredByUid: row.existingRate?.enteredByUid ?? '',
            enteredByName: row.existingRate?.enteredByName ?? '',
            createdAt: row.existingRate?.createdAt ?? now,
            updatedAt: now,
          ),
        );
      }).toList();

      for (final row in updatedRows) {
        final key = _rowKey(row);
        _initialValues[key] = _normalizeInputValue(_controllers[key]?.text ?? '');
      }

      setState(() {
        _rows = updatedRows;
        _dirtyRowKeys.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved ${result.savedRateCount} rate(s) and applied to ${result.updatedReservationCount} reservation(s).',
          ),
        ),
      );
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
          onPressed: _isSaving ? null : _pickDate,
          icon: const Icon(Icons.calendar_today),
          label: Text(
            DateFormat('dd MMM yyyy').format(_selectedDate),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            _dirtyCount > 0
                ? 'Enter Actual Rates • $_dirtyCount changed'
                : 'Enter Actual Rates',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: (_isLoading || _isSaving) ? null : _loadData,
          icon: const Icon(Icons.refresh),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: (_isSaving || _rows.isEmpty || _dirtyRowKeys.isEmpty)
              ? null
              : _saveRates,
          icon: const Icon(Icons.save),
          label: _isSaving
              ? const Text('Saving...')
              : Text(_dirtyCount > 0 ? 'Save $_dirtyCount' : 'Save Rates'),
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
          final isDirty = _dirtyRowKeys.contains(key);

          return DataRow(
            cells: [
              DataCell(Text(row.summary.itemName.isEmpty ? '—' : row.summary.itemName)),
              DataCell(Text(row.summary.category.isEmpty ? '—' : row.summary.category)),
              DataCell(Text(row.summary.mealType.isEmpty ? '—' : row.summary.mealType)),
              DataCell(Text(row.summary.totalQuantity.toString())),
              DataCell(
                SizedBox(
                  width: 110,
                  child: TextField(
                    controller: controller,
                    enabled: !_isSaving,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) => _markDirty(row, value),
                    decoration: InputDecoration(
                      hintText: '0',
                      suffixIcon: isDirty
                          ? const Icon(Icons.edit, size: 18)
                          : null,
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
