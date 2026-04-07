import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'menu_cycle_management_screen.dart';

class MonthlyMenuBuilderScreen extends StatefulWidget {
  final String userEmail;

  const MonthlyMenuBuilderScreen({
    super.key,
    required this.userEmail,
  });

  @override
  State<MonthlyMenuBuilderScreen> createState() =>
      _MonthlyMenuBuilderScreenState();
}

class _MonthlyMenuBuilderScreenState extends State<MonthlyMenuBuilderScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late DateTime _selectedMonth;
  bool _isLoading = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _selectedMonth = _resolveOperationalMonth();
  }

  DateTime _startOfMonth(DateTime value) {
    return DateTime(value.year, value.month, 1);
  }

  DateTime _endOfMonthExclusive(DateTime value) {
    return DateTime(value.year, value.month + 1, 1);
  }

  DateTime _resolveOperationalMonth() {
    final now = DateTime.now();
    final operationalDate =
        now.day == 1 && now.hour < 6 ? now.subtract(const Duration(days: 1)) : now;
    return DateTime(operationalDate.year, operationalDate.month, 1);
  }

  String _formatMonth(DateTime date) {
    const monthNames = <String>[
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${monthNames[date.month]} ${date.year}';
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    final normalized = DateTime(date.year, date.month, date.day);
    final day = normalized.day.toString().padLeft(2, '0');
    final month = normalized.month.toString().padLeft(2, '0');
    final year = normalized.year.toString();
    return '$day-$month-$year';
  }

  DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  bool _isCycleActive(Map<String, dynamic> data) {
    return data['is_active'] == true ||
        (data['status'] ?? '').toString().trim().toLowerCase() == 'active';
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Select any date in target month',
    );

    if (picked == null) return;

    setState(() {
      _selectedMonth = DateTime(picked.year, picked.month, 1);
      _statusMessage = null;
    });
  }

  Future<void> _refreshView() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _statusMessage = null;
    });

    await Future<void>.delayed(const Duration(milliseconds: 250));

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _statusMessage = 'Monthly cycle view refreshed.';
    });
  }

  Future<void> _openMenuCycleManagement() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MenuCycleManagementScreen(
          userEmail: widget.userEmail,
        ),
      ),
    );

    await _refreshView();
  }

  bool _cycleTouchesSelectedMonth(Map<String, dynamic> data) {
    final start = _readDate(data['start_date']);
    final end = _readDate(data['end_date']);

    final monthStart = _startOfMonth(_selectedMonth);
    final monthEndExclusive = _endOfMonthExclusive(_selectedMonth);

    if (start == null) return false;

    final normalizedStart = DateTime(start.year, start.month, start.day);
    final normalizedEnd = end == null
        ? null
        : DateTime(end.year, end.month, end.day).add(const Duration(days: 1));

    final startsBeforeMonthEnds = normalizedStart.isBefore(monthEndExclusive);
    final endsAfterMonthStarts =
        normalizedEnd == null || normalizedEnd.isAfter(monthStart);

    return startsBeforeMonthEnds && endsAfterMonthStarts;
  }

  Map<String, String> _buildTemplateLabelMap(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final Map<String, String> labels = <String, String>{};

    for (final doc in docs) {
      final data = doc.data();
      final templateId = (data['template_id'] ?? '').toString().trim();
      final templateName = (data['template_name'] ?? '').toString().trim();

      if (templateId.isEmpty) continue;
      labels[templateId] = templateName.isEmpty ? templateId : templateName;
    }

    return labels;
  }

  String _templateDisplayName(
    Map<String, String> templateLabelMap,
    String templateId,
  ) {
    final normalizedId = templateId.trim();
    if (normalizedId.isEmpty) return '—';

    final resolvedName = (templateLabelMap[normalizedId] ?? '').trim();
    if (resolvedName.isEmpty) {
      return normalizedId;
    }

    return '$resolvedName ($normalizedId)';
  }

  Widget _buildHeaderCard() {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Monthly Menu Planner',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'This screen is the month-wise review of saved operational cycles. Build or edit actual cycles through Menu Cycle Management.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Logged in as: ${widget.userEmail}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickMonth,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(_formatMonth(_selectedMonth)),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _refreshView,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(_isLoading ? 'Refreshing' : 'Refresh'),
                ),
                ElevatedButton.icon(
                  onPressed: _openMenuCycleManagement,
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('Manage Cycles'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthWindowCard() {
    final start = _startOfMonth(_selectedMonth);
    final endExclusive = _endOfMonthExclusive(_selectedMonth);
    final endInclusive = endExclusive.subtract(const Duration(days: 1));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 24,
          runSpacing: 12,
          children: [
            _InfoTile(
              label: 'Selected Month',
              value: _formatMonth(_selectedMonth),
            ),
            _InfoTile(
              label: 'Window Start',
              value: _formatDate(start),
            ),
            _InfoTile(
              label: 'Window End',
              value: _formatDate(endInclusive),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    if (_statusMessage == null) {
      return const SizedBox.shrink();
    }

    final isError = _statusMessage!.toLowerCase().contains('failed') ||
        _statusMessage!.toLowerCase().contains('error');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.info_outline,
              color: isError ? Colors.red : Colors.blue,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(_statusMessage!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCycleSummaryChips(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> monthCycles,
  ) {
    final activeCount = monthCycles.where((doc) => _isCycleActive(doc.data())).length;
    final openEndedCount = monthCycles.where((doc) {
      final data = doc.data();
      return data['end_date'] == null;
    }).length;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        Chip(label: Text('Cycles in month: ${monthCycles.length}')),
        Chip(label: Text('Active in month: $activeCount')),
        Chip(label: Text('Open-ended: $openEndedCount')),
      ],
    );
  }

  Widget _buildCycleCard(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    Map<String, String> templateLabelMap,
  ) {
    final data = doc.data();
    final cycleName =
        (data['cycle_name'] ?? '').toString().trim().isEmpty
            ? '(Untitled Cycle)'
            : (data['cycle_name'] ?? '').toString().trim();

    final isActive = _isCycleActive(data);

    final breakfastTemplateId =
        (data['breakfast_template_id'] ?? '').toString().trim();
    final lunchTemplate1Id =
        (data['lunch_template_1_id'] ?? '').toString().trim();
    final lunchTemplate2Id =
        (data['lunch_template_2_id'] ?? '').toString().trim();
    final dinnerTemplate1Id =
        (data['dinner_template_1_id'] ?? '').toString().trim();
    final dinnerTemplate2Id =
        (data['dinner_template_2_id'] ?? '').toString().trim();

    final startDate = _readDate(data['start_date']);
    final endDate = _readDate(data['end_date']);
    final createdBy = (data['created_by'] ?? '').toString().trim();
    final updatedBy = (data['updated_by'] ?? '').toString().trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  cycleName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Chip(
                  label: Text(isActive ? 'Active' : 'Inactive'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('Document ID: ${doc.id}'),
            const SizedBox(height: 6),
            Text('Start Date: ${_formatDate(startDate)}'),
            Text(
              'End Date: ${endDate == null ? 'Open-ended' : _formatDate(endDate)}',
            ),
            const SizedBox(height: 10),
            const Text(
              'Linked Templates',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Breakfast: ${_templateDisplayName(templateLabelMap, breakfastTemplateId)}',
            ),
            Text(
              'Lunch Template 1: ${_templateDisplayName(templateLabelMap, lunchTemplate1Id)}',
            ),
            Text(
              'Lunch Template 2: ${_templateDisplayName(templateLabelMap, lunchTemplate2Id)}',
            ),
            Text(
              'Dinner Template 1: ${_templateDisplayName(templateLabelMap, dinnerTemplate1Id)}',
            ),
            Text(
              'Dinner Template 2: ${_templateDisplayName(templateLabelMap, dinnerTemplate2Id)}',
            ),
            const SizedBox(height: 10),
            Text('Created By: ${createdBy.isEmpty ? '—' : createdBy}'),
            Text('Updated By: ${updatedBy.isEmpty ? '—' : updatedBy}'),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('weekly_menu_templates').snapshots(),
      builder: (context, templateSnapshot) {
        if (templateSnapshot.connectionState == ConnectionState.waiting &&
            !_isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (templateSnapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Failed to load templates: ${templateSnapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final templateDocs = templateSnapshot.data?.docs ?? [];
        final templateLabelMap = _buildTemplateLabelMap(templateDocs);

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _firestore.collection('menu_cycles').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !_isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Failed to load menu cycles: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final docs = snapshot.data?.docs ?? [];

            final monthCycles = docs.where((doc) {
              return _cycleTouchesSelectedMonth(doc.data());
            }).toList()
              ..sort((a, b) {
                final aData = a.data();
                final bData = b.data();

                final aActive = _isCycleActive(aData);
                final bActive = _isCycleActive(bData);

                if (aActive != bActive) {
                  return aActive ? -1 : 1;
                }

                final aStart = _readDate(aData['start_date']) ?? DateTime(1900);
                final bStart = _readDate(bData['start_date']) ?? DateTime(1900);

                return bStart.compareTo(aStart);
              });

            return RefreshIndicator(
              onRefresh: _refreshView,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeaderCard(),
                  const SizedBox(height: 12),
                  _buildMonthWindowCard(),
                  const SizedBox(height: 12),
                  _buildStatusCard(),
                  if (_statusMessage != null) const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Cycle Coverage for Selected Month',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'This planner is read-only for monthly review. Use Manage Cycles to create, edit, or activate the operational cycle.',
                          ),
                          const SizedBox(height: 14),
                          _buildCycleSummaryChips(monthCycles),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (monthCycles.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'No menu cycles overlap with the selected month.',
                        ),
                      ),
                    )
                  else
                    ...monthCycles.map(
                      (doc) => _buildCycleCard(doc, templateLabelMap),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Menu Builder'),
      ),
      body: _buildBody(),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTile({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
