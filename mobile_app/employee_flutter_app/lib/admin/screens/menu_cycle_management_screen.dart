import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MenuCycleManagementScreen extends StatefulWidget {
  final String userEmail;

  const MenuCycleManagementScreen({
    super.key,
    required this.userEmail,
  });

  @override
  State<MenuCycleManagementScreen> createState() =>
      _MenuCycleManagementScreenState();
}

class _MenuCycleManagementScreenState extends State<MenuCycleManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController cycleNameController = TextEditingController();
  final FocusNode cycleNameFocusNode = FocusNode();

  String? breakfastTemplateId;
  String? lunchTemplate1Id;
  String? lunchTemplate2Id;
  String? dinnerTemplate1Id;
  String? dinnerTemplate2Id;

  DateTime? startDate;
  DateTime? endDate;

  bool keepActiveUntilNextChange = true;
  bool activateImmediately = true;
  bool isSaving = false;
  String? statusMessage;
  String? editingCycleId;

  static const List<String> weekDays = <String>[
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  @override
  void dispose() {
    cycleNameController.dispose();
    cycleNameFocusNode.dispose();
    super.dispose();
  }

  DateTime _normalizeDate(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  void _dismissKeyboard() {
    final currentFocus = FocusScope.of(context);
    if (!currentFocus.hasPrimaryFocus && currentFocus.focusedChild != null) {
      currentFocus.unfocus();
    }
  }

  void resetForm({bool clearStatusMessage = true}) {
    _dismissKeyboard();

    cycleNameController.clear();
    breakfastTemplateId = null;
    lunchTemplate1Id = null;
    lunchTemplate2Id = null;
    dinnerTemplate1Id = null;
    dinnerTemplate2Id = null;
    startDate = null;
    endDate = null;
    keepActiveUntilNextChange = true;
    activateImmediately = true;
    isSaving = false;
    editingCycleId = null;

    if (clearStatusMessage) {
      statusMessage = null;
    }

    if (mounted) {
      setState(() {});
    }
  }

  bool isTemplateActive(Map<String, dynamic> data) {
    return data['is_active'] == true ||
        (data['status'] ?? '').toString().trim().toLowerCase() == 'active';
  }

  bool isCycleActive(Map<String, dynamic> data) {
    return data['is_active'] == true ||
        (data['status'] ?? '').toString().trim().toLowerCase() == 'active';
  }

  String formatDate(DateTime? date) {
    if (date == null) return 'Select date';
    final normalized = _normalizeDate(date);
    final day = normalized.day.toString().padLeft(2, '0');
    final month = normalized.month.toString().padLeft(2, '0');
    return '$day-$month-${normalized.year}';
  }

  Future<void> pickDate({required bool forStartDate}) async {
    _dismissKeyboard();

    final initialDate =
        (forStartDate ? startDate : endDate) ?? DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      if (forStartDate) {
        startDate = _normalizeDate(picked);
        if (endDate != null && endDate!.isBefore(startDate!)) {
          endDate = startDate;
        }
      } else {
        endDate = _normalizeDate(picked);
      }
    });
  }

  Future<void> _deactivateOtherCycles({
    required WriteBatch batch,
    required String? excludeCycleId,
  }) async {
    final snapshot = await _firestore
        .collection('menu_cycles')
        .where('is_active', isEqualTo: true)
        .get();

    for (final doc in snapshot.docs) {
      if (excludeCycleId != null && doc.id == excludeCycleId) {
        continue;
      }

      batch.update(doc.reference, {
        'is_active': false,
        'status': 'inactive',
        'updated_at': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> saveCycle() async {
    _dismissKeyboard();

    final cycleName = cycleNameController.text.trim();

    if (cycleName.isEmpty) {
      setState(() {
        statusMessage = 'Cycle name is required.';
      });
      return;
    }

    if (breakfastTemplateId == null ||
        lunchTemplate1Id == null ||
        lunchTemplate2Id == null ||
        dinnerTemplate1Id == null ||
        dinnerTemplate2Id == null) {
      setState(() {
        statusMessage = 'Please select all required templates.';
      });
      return;
    }

    if (startDate == null) {
      setState(() {
        statusMessage = 'Start date is required.';
      });
      return;
    }

    if (!keepActiveUntilNextChange && endDate == null) {
      setState(() {
        statusMessage = 'End date is required when cycle is not open-ended.';
      });
      return;
    }

    if (!keepActiveUntilNextChange &&
        endDate != null &&
        endDate!.isBefore(startDate!)) {
      setState(() {
        statusMessage = 'End date cannot be before start date.';
      });
      return;
    }

    final wasEditing = editingCycleId != null;

    try {
      setState(() {
        isSaving = true;
        statusMessage = null;
      });

      final normalizedStartDate = _normalizeDate(startDate!);
      final normalizedEndDate = keepActiveUntilNextChange || endDate == null
          ? null
          : _normalizeDate(endDate!);

      final batch = _firestore.batch();
      final cyclesRef = _firestore.collection('menu_cycles');

      if (activateImmediately) {
        await _deactivateOtherCycles(
          batch: batch,
          excludeCycleId: editingCycleId,
        );
      }

      final payload = <String, dynamic>{
        'cycle_name': cycleName,
        'breakfast_template_id': breakfastTemplateId,
        'lunch_template_1_id': lunchTemplate1Id,
        'lunch_template_2_id': lunchTemplate2Id,
        'dinner_template_1_id': dinnerTemplate1Id,
        'dinner_template_2_id': dinnerTemplate2Id,
        'start_date': Timestamp.fromDate(normalizedStartDate),
        'end_date': normalizedEndDate == null
            ? null
            : Timestamp.fromDate(normalizedEndDate),
        'is_active': activateImmediately,
        'status': activateImmediately ? 'active' : 'inactive',
        'updated_by': widget.userEmail,
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (!wasEditing) {
        final newDoc = cyclesRef.doc();
        batch.set(newDoc, {
          ...payload,
          'created_by': widget.userEmail,
          'created_at': FieldValue.serverTimestamp(),
        });
      } else {
        final docRef = cyclesRef.doc(editingCycleId);
        batch.update(docRef, payload);
      }

      await batch.commit();

      if (!mounted) return;

      resetForm(clearStatusMessage: false);

      setState(() {
        isSaving = false;
        statusMessage = wasEditing
            ? 'Menu cycle updated successfully.'
            : 'Menu cycle created successfully.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isSaving = false;
        statusMessage = 'Failed to save menu cycle: $e';
      });
    }
  }

  void loadCycleForEdit(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    Map<String, _TemplateGroup> templateGroupMap,
  ) {
    _dismissKeyboard();

    final data = doc.data();

    cycleNameController.text = (data['cycle_name'] ?? '').toString().trim();

    breakfastTemplateId =
        _normalizeTemplateIdForEdit(data['breakfast_template_id'], templateGroupMap);
    lunchTemplate1Id =
        _normalizeTemplateIdForEdit(data['lunch_template_1_id'], templateGroupMap);
    lunchTemplate2Id =
        _normalizeTemplateIdForEdit(data['lunch_template_2_id'], templateGroupMap);
    dinnerTemplate1Id =
        _normalizeTemplateIdForEdit(data['dinner_template_1_id'], templateGroupMap);
    dinnerTemplate2Id =
        _normalizeTemplateIdForEdit(data['dinner_template_2_id'], templateGroupMap);

    final startTs = data['start_date'];
    final endTs = data['end_date'];

    startDate = startTs is Timestamp ? _normalizeDate(startTs.toDate()) : null;
    endDate = endTs is Timestamp ? _normalizeDate(endTs.toDate()) : null;
    keepActiveUntilNextChange = endDate == null;
    activateImmediately = isCycleActive(data);
    editingCycleId = doc.id;
    statusMessage = null;

    setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      cycleNameFocusNode.requestFocus();
    });
  }

  String? _normalizeTemplateIdForEdit(
    dynamic rawValue,
    Map<String, _TemplateGroup> templateGroupMap,
  ) {
    final value = (rawValue ?? '').toString().trim();
    if (value.isEmpty) return null;

    if (templateGroupMap.containsKey(value)) {
      return value;
    }

    for (final entry in templateGroupMap.entries) {
      if (entry.value.rowDocIds.contains(value)) {
        return entry.key;
      }
    }

    return value;
  }

  Future<void> toggleCycleActive(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    _dismissKeyboard();

    try {
      final data = doc.data();
      final currentlyActive = isCycleActive(data);
      final nextActive = !currentlyActive;

      final batch = _firestore.batch();

      if (nextActive) {
        await _deactivateOtherCycles(
          batch: batch,
          excludeCycleId: doc.id,
        );
      }

      batch.update(doc.reference, {
        'is_active': nextActive,
        'status': nextActive ? 'active' : 'inactive',
        'updated_by': widget.userEmail,
        'updated_at': FieldValue.serverTimestamp(),
      });

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextActive ? 'Cycle activated.' : 'Cycle deactivated.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update cycle: $e')),
      );
    }
  }

  List<_TemplateGroup> _groupTemplateRows(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> grouped =
        <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};

    for (final doc in docs) {
      final data = doc.data();
      final templateId = (data['template_id'] ?? '').toString().trim();
      final mealType = (data['meal_type'] ?? '').toString().trim().toLowerCase();
      final weekday = (data['weekday'] ?? '').toString().trim().toLowerCase();

      if (templateId.isEmpty || mealType.isEmpty || weekday.isEmpty) {
        continue;
      }

      final key = '$templateId|$mealType';
      grouped.putIfAbsent(key, () => <QueryDocumentSnapshot<Map<String, dynamic>>>[]);
      grouped[key]!.add(doc);
    }

    final groups = grouped.entries.map((entry) {
      final rows = entry.value;

      rows.sort((a, b) {
        final aDay = (a.data()['weekday'] ?? '').toString().trim().toLowerCase();
        final bDay = (b.data()['weekday'] ?? '').toString().trim().toLowerCase();
        return weekDays.indexOf(aDay).compareTo(weekDays.indexOf(bDay));
      });

      final first = rows.first.data();
      final templateId = (first['template_id'] ?? '').toString().trim();
      final templateName = (first['template_name'] ?? '').toString().trim().isEmpty
          ? templateId
          : (first['template_name'] ?? '').toString().trim();
      final mealType = (first['meal_type'] ?? '').toString().trim().toLowerCase();

      bool anyActive = false;
      int totalItems = 0;
      final Set<String> rowDocIds = <String>{};

      for (final row in rows) {
        final data = row.data();
        final itemIds = (data['item_ids'] is Iterable)
            ? List<String>.from(
                (data['item_ids'] as Iterable).map((e) => e.toString().trim()),
              )
            : const <String>[];

        totalItems += itemIds.length;
        rowDocIds.add(row.id);

        if (isTemplateActive(data)) {
          anyActive = true;
        }
      }

      return _TemplateGroup(
        templateId: templateId,
        templateName: templateName,
        mealType: mealType,
        isActive: anyActive,
        totalItems: totalItems,
        rowDocIds: rowDocIds,
      );
    }).toList();

    groups.sort((a, b) {
      if (a.mealType != b.mealType) {
        return a.mealType.compareTo(b.mealType);
      }
      return a.templateName.toLowerCase().compareTo(b.templateName.toLowerCase());
    });

    return groups;
  }

  List<_TemplateGroup> _filterTemplateGroupsByMealType(
    List<_TemplateGroup> groups,
    String mealType,
  ) {
    return groups
        .where((group) => group.isActive && group.mealType == mealType)
        .toList();
  }

  String _selectedTemplateName({
    required List<_TemplateGroup> filtered,
    required String? value,
  }) {
    if (value == null || value.trim().isEmpty) {
      return 'Select template';
    }

    for (final group in filtered) {
      if (group.templateId == value) {
        return '${group.templateName} (${group.templateId})';
      }
    }

    return 'Selected template not found';
  }

  String _templateDisplayName(
    Map<String, _TemplateGroup> groupMap,
    dynamic storedValue,
  ) {
    final value = (storedValue ?? '').toString().trim();
    if (value.isEmpty) return '—';

    if (groupMap.containsKey(value)) {
      final group = groupMap[value]!;
      return '${group.templateName} (${group.templateId})';
    }

    for (final group in groupMap.values) {
      if (group.rowDocIds.contains(value)) {
        return '${group.templateName} (${group.templateId})';
      }
    }

    return value;
  }

  Future<void> _showTemplateSelector({
    required String label,
    required List<_TemplateGroup> filtered,
    required ValueChanged<String?> onChanged,
  }) async {
    _dismissKeyboard();

    if (filtered.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No active templates available for $label.')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final group = filtered[index];

                    return ListTile(
                      title: Text(group.templateName),
                      subtitle: Text(
                        'Template ID: ${group.templateId} • Total items: ${group.totalItems}',
                      ),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        onChanged(group.templateId);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _templateSelector({
    required String label,
    required String mealType,
    required String? value,
    required ValueChanged<String?> onChanged,
    required List<_TemplateGroup> allTemplateGroups,
  }) {
    final filtered = _filterTemplateGroupsByMealType(allTemplateGroups, mealType);
    final selectedName = _selectedTemplateName(
      filtered: filtered,
      value: value,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _showTemplateSelector(
            label: label,
            filtered: filtered,
            onChanged: onChanged,
          ),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              suffixIcon: const Icon(Icons.arrow_drop_down),
            ),
            child: Text(
              selectedName,
              style: TextStyle(
                color: value == null ? Colors.grey.shade700 : Colors.black,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          filtered.isEmpty
              ? 'No active templates found for $mealType.'
              : '${filtered.length} template(s) available for $mealType.',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildStaticFormSection() {
    final inEditMode = editingCycleId != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              inEditMode ? 'Edit Menu Cycle' : 'Create Menu Cycle',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select logical weekly templates here. The cycle stores template IDs, not per-weekday row document IDs.',
            ),
            if (inEditMode) ...[
              const SizedBox(height: 8),
              Text(
                'Editing cycle: $editingCycleId',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: resetForm,
                icon: const Icon(Icons.close),
                label: const Text('Cancel Edit'),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: cycleNameController,
              focusNode: cycleNameFocusNode,
              textInputAction: TextInputAction.done,
              onTapOutside: (_) => _dismissKeyboard(),
              onSubmitted: (_) => _dismissKeyboard(),
              decoration: const InputDecoration(
                labelText: 'Cycle Name',
                border: OutlineInputBorder(),
              ),
            ),
            if (statusMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                statusMessage!,
                style: TextStyle(
                  color: statusMessage!.toLowerCase().contains('failed') ||
                          statusMessage!.toLowerCase().contains('required')
                      ? Colors.red
                      : Colors.green,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicSection(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> templateDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> cycleDocs,
  ) {
    final templateGroups = _groupTemplateRows(templateDocs);
    final templateGroupMap = <String, _TemplateGroup>{
      for (final group in templateGroups) group.templateId: group,
    };

    final sortedCycles =
        List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(cycleDocs)
          ..sort((a, b) {
            final aData = a.data();
            final bData = b.data();

            final aActive = isCycleActive(aData);
            final bActive = isCycleActive(bData);
            if (aActive != bActive) {
              return aActive ? -1 : 1;
            }

            final aStart = aData['start_date'];
            final bStart = bData['start_date'];

            final aDate = aStart is Timestamp ? aStart.toDate() : DateTime(1900);
            final bDate = bStart is Timestamp ? bStart.toDate() : DateTime(1900);

            return bDate.compareTo(aDate);
          });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _templateSelector(
                  label: 'Breakfast Template',
                  mealType: 'breakfast',
                  value: breakfastTemplateId,
                  onChanged: (value) => setState(() {
                    breakfastTemplateId = value;
                  }),
                  allTemplateGroups: templateGroups,
                ),
                const SizedBox(height: 16),
                _templateSelector(
                  label: 'Lunch Template 1',
                  mealType: 'lunch',
                  value: lunchTemplate1Id,
                  onChanged: (value) => setState(() {
                    lunchTemplate1Id = value;
                  }),
                  allTemplateGroups: templateGroups,
                ),
                const SizedBox(height: 16),
                _templateSelector(
                  label: 'Lunch Template 2',
                  mealType: 'lunch',
                  value: lunchTemplate2Id,
                  onChanged: (value) => setState(() {
                    lunchTemplate2Id = value;
                  }),
                  allTemplateGroups: templateGroups,
                ),
                const SizedBox(height: 16),
                _templateSelector(
                  label: 'Dinner Template 1',
                  mealType: 'dinner',
                  value: dinnerTemplate1Id,
                  onChanged: (value) => setState(() {
                    dinnerTemplate1Id = value;
                  }),
                  allTemplateGroups: templateGroups,
                ),
                const SizedBox(height: 16),
                _templateSelector(
                  label: 'Dinner Template 2',
                  mealType: 'dinner',
                  value: dinnerTemplate2Id,
                  onChanged: (value) => setState(() {
                    dinnerTemplate2Id = value;
                  }),
                  allTemplateGroups: templateGroups,
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Start Date'),
                  subtitle: Text(formatDate(startDate)),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_calendar),
                    onPressed: () => pickDate(forStartDate: true),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Keep this cycle active until next change'),
                  subtitle: const Text('Do not set an end date'),
                  value: keepActiveUntilNextChange,
                  onChanged: (value) {
                    _dismissKeyboard();
                    setState(() {
                      keepActiveUntilNextChange = value;
                      if (value) {
                        endDate = null;
                      }
                    });
                  },
                ),
                if (!keepActiveUntilNextChange)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('End Date'),
                    subtitle: Text(formatDate(endDate)),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit_calendar),
                      onPressed: () => pickDate(forStartDate: false),
                    ),
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Activate immediately'),
                  subtitle: const Text(
                    'If enabled, this cycle becomes the only active cycle.',
                  ),
                  value: activateImmediately,
                  onChanged: (value) {
                    setState(() {
                      activateImmediately = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: isSaving ? null : saveCycle,
                    icon: const Icon(Icons.save),
                    label: Text(
                      isSaving
                          ? 'Saving...'
                          : editingCycleId == null
                              ? 'Create Menu Cycle'
                              : 'Update Menu Cycle',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Saved Cycles',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (sortedCycles.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('No menu cycles found.'),
            ),
          )
        else
          ...sortedCycles.map((doc) {
            final data = doc.data();
            final cycleName =
                (data['cycle_name'] ?? '').toString().trim().isEmpty
                    ? '(Untitled Cycle)'
                    : (data['cycle_name'] ?? '').toString().trim();

            final active = isCycleActive(data);

            final startTs = data['start_date'];
            final endTs = data['end_date'];

            final start = startTs is Timestamp ? startTs.toDate() : null;
            final end = endTs is Timestamp ? endTs.toDate() : null;

            return Card(
              key: ValueKey(doc.id),
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        Text(
                          cycleName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Chip(label: Text(active ? 'Active' : 'Inactive')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Document ID: ${doc.id}'),
                    Text('Start Date: ${formatDate(start)}'),
                    Text(
                      'End Date: ${end == null ? 'Open-ended' : formatDate(end)}',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Linked Templates',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Breakfast: ${_templateDisplayName(templateGroupMap, data['breakfast_template_id'])}',
                    ),
                    Text(
                      'Lunch Template 1: ${_templateDisplayName(templateGroupMap, data['lunch_template_1_id'])}',
                    ),
                    Text(
                      'Lunch Template 2: ${_templateDisplayName(templateGroupMap, data['lunch_template_2_id'])}',
                    ),
                    Text(
                      'Dinner Template 1: ${_templateDisplayName(templateGroupMap, data['dinner_template_1_id'])}',
                    ),
                    Text(
                      'Dinner Template 2: ${_templateDisplayName(templateGroupMap, data['dinner_template_2_id'])}',
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => loadCycleForEdit(doc, templateGroupMap),
                          icon: const Icon(Icons.edit),
                          label: const Text('Edit'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => toggleCycleActive(doc),
                          icon: Icon(
                            active ? Icons.visibility_off : Icons.visibility,
                          ),
                          label: Text(active ? 'Deactivate' : 'Activate'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu Cycles'),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 0,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Logged in as: ${widget.userEmail}'),
                  ),
                  const SizedBox(height: 16),
                  _buildStaticFormSection(),
                ],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestore.collection('weekly_menu_templates').snapshots(),
              builder: (context, templateSnapshot) {
                if (templateSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (templateSnapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Failed to load templates: ${templateSnapshot.error}',
                      ),
                    ),
                  );
                }

                final templateDocs = templateSnapshot.data?.docs ?? [];

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _firestore.collection('menu_cycles').snapshots(),
                  builder: (context, cycleSnapshot) {
                    if (cycleSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (cycleSnapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            'Failed to load cycles: ${cycleSnapshot.error}',
                          ),
                        ),
                      );
                    }

                    final cycleDocs = cycleSnapshot.data?.docs ?? [];

                    return ListView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildDynamicSection(templateDocs, cycleDocs),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateGroup {
  final String templateId;
  final String templateName;
  final String mealType;
  final bool isActive;
  final int totalItems;
  final Set<String> rowDocIds;

  const _TemplateGroup({
    required this.templateId,
    required this.templateName,
    required this.mealType,
    required this.isActive,
    required this.totalItems,
    required this.rowDocIds,
  });
}
