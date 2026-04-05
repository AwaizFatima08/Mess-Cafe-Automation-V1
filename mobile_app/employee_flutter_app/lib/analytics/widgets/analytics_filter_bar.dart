import 'package:flutter/material.dart';

import '../models/analytics_filter_model.dart';

class AnalyticsFilterBar extends StatefulWidget {
  const AnalyticsFilterBar({
    super.key,
    required this.initialFilter,
    required this.onApply,
    required this.onReset,
  });

  final AnalyticsFilterModel initialFilter;
  final ValueChanged<AnalyticsFilterModel> onApply;
  final VoidCallback onReset;

  @override
  State<AnalyticsFilterBar> createState() => _AnalyticsFilterBarState();
}

class _AnalyticsFilterBarState extends State<AnalyticsFilterBar> {
  late DateTime _startDate;
  late DateTime _endDate;
  late bool _includeGuests;

  late bool _breakfastSelected;
  late bool _lunchSelected;
  late bool _dinnerSelected;

  @override
  void initState() {
    super.initState();
    _hydrateFromFilter(widget.initialFilter);
  }

  @override
  void didUpdateWidget(covariant AnalyticsFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.initialFilter != widget.initialFilter) {
      _hydrateFromFilter(widget.initialFilter);
    }
  }

  void _hydrateFromFilter(AnalyticsFilterModel filter) {
    final mealTypes = (filter.mealTypes ?? const <String>[])
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toList();

    final hasExplicitMeals = mealTypes.isNotEmpty;

    _startDate = _normalizeDate(filter.startDate);
    _endDate = _normalizeDate(filter.endDate);
    _includeGuests = filter.includeGuests;

    _breakfastSelected = !hasExplicitMeals || mealTypes.contains('breakfast');
    _lunchSelected = !hasExplicitMeals || mealTypes.contains('lunch');
    _dinnerSelected = !hasExplicitMeals || mealTypes.contains('dinner');

    if (_endDate.isBefore(_startDate)) {
      _endDate = _startDate;
    }
  }

  DateTime _normalizeDate(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  DateTime _maxSelectableDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: _endDate,
    );

    if (picked == null) return;

    setState(() {
      _startDate = _normalizeDate(picked);

      if (_endDate.isBefore(_startDate)) {
        _endDate = _startDate;
      }
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: _maxSelectableDate(),
    );

    if (picked == null) return;

    setState(() {
      _endDate = _normalizeDate(picked);

      if (_endDate.isBefore(_startDate)) {
        _endDate = _startDate;
      }
    });
  }

  List<String> _selectedMealTypes() {
    final selected = <String>[];

    if (_breakfastSelected) selected.add('breakfast');
    if (_lunchSelected) selected.add('lunch');
    if (_dinnerSelected) selected.add('dinner');

    return selected;
  }

  void _selectAllMeals() {
    setState(() {
      _breakfastSelected = true;
      _lunchSelected = true;
      _dinnerSelected = true;
    });
  }

  void _clearAllMeals() {
    setState(() {
      _breakfastSelected = false;
      _lunchSelected = false;
      _dinnerSelected = false;
    });
  }

  void _toggleMeal(String mealType, bool selected) {
    setState(() {
      switch (mealType) {
        case 'breakfast':
          _breakfastSelected = selected;
          break;
        case 'lunch':
          _lunchSelected = selected;
          break;
        case 'dinner':
          _dinnerSelected = selected;
          break;
      }
    });
  }

  void _applyFilters() {
    final selectedMeals = _selectedMealTypes();

    if (selectedMeals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select at least one meal type to apply analytics filter.'),
        ),
      );
      return;
    }

    final resolvedMeals =
        selectedMeals.length == 3 ? <String>[] : selectedMeals;

    final updatedFilter = widget.initialFilter.copyWith(
      startDate: _startDate,
      endDate: _endDate,
      mealTypes: resolvedMeals,
      includeGuests: _includeGuests,
    );

    widget.onApply(updatedFilter);
  }

  void _resetFilters() {
    widget.onReset();
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day-$month-$year';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allMealsSelected =
        _breakfastSelected && _lunchSelected && _dinnerSelected;
    final noMealsSelected =
        !_breakfastSelected && !_lunchSelected && !_dinnerSelected;

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
            Text(
              'Filters',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _DateFilterChip(
                  label: 'Start',
                  value: _formatDate(_startDate),
                  icon: Icons.date_range_outlined,
                  onTap: _pickStartDate,
                ),
                _DateFilterChip(
                  label: 'End',
                  value: _formatDate(_endDate),
                  icon: Icons.event_outlined,
                  onTap: _pickEndDate,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Meal Types',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: allMealsSelected,
                  onSelected: (_) => _selectAllMeals(),
                ),
                FilterChip(
                  label: const Text('None'),
                  selected: noMealsSelected,
                  onSelected: (_) => _clearAllMeals(),
                ),
                FilterChip(
                  label: const Text('Breakfast'),
                  selected: _breakfastSelected,
                  onSelected: (value) => _toggleMeal('breakfast', value),
                ),
                FilterChip(
                  label: const Text('Lunch'),
                  selected: _lunchSelected,
                  onSelected: (value) => _toggleMeal('lunch', value),
                ),
                FilterChip(
                  label: const Text('Dinner'),
                  selected: _dinnerSelected,
                  onSelected: (value) => _toggleMeal('dinner', value),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Include Guests'),
              subtitle: const Text('Toggle guest attendance in analytics'),
              value: _includeGuests,
              onChanged: (value) {
                setState(() {
                  _includeGuests = value;
                });
              },
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 420;

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _applyFilters,
                        icon: const Icon(Icons.filter_alt_outlined),
                        label: const Text('Apply Filters'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _resetFilters,
                        icon: const Icon(Icons.restart_alt),
                        label: const Text('Reset'),
                      ),
                    ],
                  );
                }

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _applyFilters,
                      icon: const Icon(Icons.filter_alt_outlined),
                      label: const Text('Apply Filters'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _resetFilters,
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Reset'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DateFilterChip extends StatelessWidget {
  const _DateFilterChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(14),
            color: Colors.grey.shade50,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
