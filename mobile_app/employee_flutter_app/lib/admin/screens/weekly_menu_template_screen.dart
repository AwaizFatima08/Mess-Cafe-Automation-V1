import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class WeeklyMenuTemplateScreen extends StatefulWidget {
  final String userEmail;

  const WeeklyMenuTemplateScreen({
    super.key,
    required this.userEmail,
  });

  @override
  State<WeeklyMenuTemplateScreen> createState() =>
      _WeeklyMenuTemplateScreenState();
}

class _WeeklyMenuTemplateScreenState extends State<WeeklyMenuTemplateScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController templateNameController = TextEditingController();
  final FocusNode templateNameFocusNode = FocusNode();

  final TextEditingController itemSearchController = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  final List<String> weekDays = const [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  final List<Map<String, String>> mealTypes = const [
    {'value': 'breakfast', 'label': 'Breakfast'},
    {'value': 'lunch', 'label': 'Lunch'},
    {'value': 'dinner', 'label': 'Dinner'},
  ];

  static const String _defaultOptionKey = 'default';
  static const String _defaultOptionLabel = 'Default Option';

  String selectedMealType = 'breakfast';
  String savedTemplateFilter = 'all';
  String selectedFoodTypeFilter = 'all';
  String appliedItemSearchQuery = '';
  String? editingTemplateId;
  bool isSaving = false;
  String? statusMessage;

  final Map<String, List<String>> daySelections = {
    'monday': <String>[],
    'tuesday': <String>[],
    'wednesday': <String>[],
    'thursday': <String>[],
    'friday': <String>[],
    'saturday': <String>[],
    'sunday': <String>[],
  };

  final Map<String, bool> dayExpandedState = {
    'monday': false,
    'tuesday': false,
    'wednesday': false,
    'thursday': false,
    'friday': false,
    'saturday': false,
    'sunday': false,
  };

  @override
  void dispose() {
    templateNameController.dispose();
    templateNameFocusNode.dispose();
    itemSearchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _applyItemSearch() {
    final value = itemSearchController.text.trim().toLowerCase();
    if (value == appliedItemSearchQuery) return;

    setState(() {
      appliedItemSearchQuery = value;
    });
  }

  String formatLabel(String value) {
    return value
        .split('_')
        .map((word) {
          if (word.isEmpty) return word;
          return '${word[0].toUpperCase()}${word.substring(1)}';
        })
        .join(' ');
  }

  bool isItemActive(Map<String, dynamic> data) {
    return data['is_active'] == true;
  }

  bool isItemVisible(Map<String, dynamic> data) {
    final raw = data['is_visible'];
    if (raw is bool) return raw;
    return true;
  }

  bool isTemplateRowActive(Map<String, dynamic> data) {
    return data['is_active'] == true;
  }

  bool isTemplateRowVisible(Map<String, dynamic> data) {
    final raw = data['is_visible'];
    if (raw is bool) return raw;
    return true;
  }

  String getMenuItemName(Map<String, dynamic> data, String docId) {
    final name = (data['name'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;

    final legacy = (data['item_name'] ?? '').toString().trim();
    if (legacy.isNotEmpty) return legacy;

    return docId;
  }

  String getMenuItemCode(Map<String, dynamic> data, String docId) {
    final code = (data['item_Id'] ?? '').toString().trim();
    if (code.isNotEmpty) return code;
    return docId;
  }

  String getFoodTypeLabel(Map<String, dynamic> data) {
    final name = (data['food_type_name'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;

    final code = (data['food_type_code'] ?? '').toString().trim();
    if (code.isNotEmpty) return code;

    return 'unspecified';
  }

  List<String> getMealTypes(Map<String, dynamic> data) {
    final raw = data['available_meal_types'];

    if (raw is Iterable) {
      return raw
          .map((e) => e.toString().trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
    }

    if (raw is String) {
      return raw
          .replaceAll('[', '')
          .replaceAll(']', '')
          .replaceAll('“', '')
          .replaceAll('”', '')
          .replaceAll('"', '')
          .replaceAll("'", '')
          .split(',')
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
    }

    final legacyCategory =
        (data['category'] ?? '').toString().trim().toLowerCase();
    if (legacyCategory.isNotEmpty) {
      return [legacyCategory];
    }

    return const [];
  }

  int getSortOrder(Map<String, dynamic> data) {
    final raw = data['sort_order'];

    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim()) ?? 999999;

    return 999999;
  }

  List<String> _normalizeStringList(dynamic raw) {
    if (raw is Iterable) {
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
    }

    if (raw is String) {
      return raw
          .replaceAll('[', '')
          .replaceAll(']', '')
          .replaceAll('"', '')
          .replaceAll("'", '')
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
    }

    return <String>[];
  }

  List<String> _buildFoodTypeOptions(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final values = docs
        .map((doc) => getFoodTypeLabel(doc.data()).trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return ['all', ...values];
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applySelectionFilters(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.where((doc) {
      final data = doc.data();
      final itemName = getMenuItemName(data, doc.id).toLowerCase();
      final itemCode = getMenuItemCode(data, doc.id).toLowerCase();
      final foodType = getFoodTypeLabel(data).toLowerCase();
      final mealTypes = getMealTypes(data);

      final matchesSearch = appliedItemSearchQuery.isEmpty ||
          itemName.contains(appliedItemSearchQuery) ||
          itemCode.contains(appliedItemSearchQuery);

      final matchesFoodType = selectedFoodTypeFilter == 'all' ||
          foodType == selectedFoodTypeFilter.toLowerCase();

      final matchesMealType = mealTypes.contains(selectedMealType);

      return isItemActive(data) &&
          isItemVisible(data) &&
          matchesMealType &&
          matchesSearch &&
          matchesFoodType;
    }).toList();
  }

  Future<String> _generateNextTemplateId() async {
    final snapshot = await _firestore.collection('weekly_menu_templates').get();

    int maxNumber = 0;
    final regex = RegExp(r'^WMT(\d+)$');

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final candidates = <String>[
        (data['template_id'] ?? '').toString().trim().toUpperCase(),
        doc.id.trim().toUpperCase(),
      ];

      for (final candidate in candidates) {
        final match = regex.firstMatch(candidate);
        if (match == null) continue;
        final number = int.tryParse(match.group(1) ?? '0') ?? 0;
        if (number > maxNumber) {
          maxNumber = number;
        }
      }
    }

    return 'WMT${(maxNumber + 1).toString().padLeft(4, '0')}';
  }

  String _buildTemplateRowDocId({
    required String templateId,
    required String mealType,
    required String weekday,
    required String optionKey,
  }) {
    return '${templateId}_${mealType}_${weekday}_$optionKey';
  }

  void _resetSelectionFilters() {
    selectedFoodTypeFilter = 'all';
    appliedItemSearchQuery = '';
    itemSearchController.clear();
  }

  void resetForm() {
    templateNameController.clear();
    selectedMealType = 'breakfast';
    editingTemplateId = null;
    statusMessage = null;
    _resetSelectionFilters();

    for (final day in weekDays) {
      daySelections[day] = <String>[];
      dayExpandedState[day] = false;
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> saveTemplate() async {
    final templateName = templateNameController.text.trim();

    if (templateName.isEmpty) {
      setState(() {
        statusMessage = 'Template name is required.';
      });
      return;
    }

    if (!['breakfast', 'lunch', 'dinner'].contains(selectedMealType)) {
      setState(() {
        statusMessage = 'Please select a valid meal type.';
      });
      return;
    }

    final hasAnySelection =
        weekDays.any((day) => (daySelections[day] ?? []).isNotEmpty);

    if (!hasAnySelection) {
      setState(() {
        statusMessage = 'Select at least one item for at least one day.';
      });
      return;
    }

    try {
      setState(() {
        isSaving = true;
        statusMessage = null;
      });

      final templateId = editingTemplateId ?? await _generateNextTemplateId();
      final batch = _firestore.batch();
      final templatesRef = _firestore.collection('weekly_menu_templates');
      final now = FieldValue.serverTimestamp();

      if (editingTemplateId != null) {
        final existing = await templatesRef
            .where('template_id', isEqualTo: editingTemplateId)
            .where('meal_type', isEqualTo: selectedMealType)
            .get();

        for (final doc in existing.docs) {
          batch.delete(doc.reference);
        }
      }

      for (final day in weekDays) {
        final itemIds =
            List<String>.from(daySelections[day] ?? const <String>[]);

        if (itemIds.isEmpty) {
          continue;
        }

        final rowDocId = _buildTemplateRowDocId(
          templateId: templateId,
          mealType: selectedMealType,
          weekday: day,
          optionKey: _defaultOptionKey,
        );

        final rowRef = templatesRef.doc(rowDocId);

        batch.set(
          rowRef,
          {
            'template_id': templateId,
            'template_name': templateName,
            'weekday': day,
            'meal_type': selectedMealType,
            'menu_option_key': _defaultOptionKey,
            'option_label': _defaultOptionLabel,
            'item_ids': itemIds,
            'is_active': true,
            'is_visible': true,
            'updated_at': now,
            if (editingTemplateId == null) 'created_at': now,
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();

      if (!mounted) return;

      final wasEdit = editingTemplateId != null;

      setState(() {
        isSaving = false;
        statusMessage = wasEdit
            ? 'Template updated successfully.'
            : 'Template created successfully with ID $templateId.';
      });

      resetForm();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isSaving = false;
        statusMessage = 'Failed to save template: $e';
      });
    }
  }

  void loadTemplateGroupForEdit(_TemplateGroup group) {
    templateNameController.text = group.templateName;
    selectedMealType = group.mealType;
    editingTemplateId = group.templateId;
    statusMessage = null;
    _resetSelectionFilters();

    for (final day in weekDays) {
      daySelections[day] =
          List<String>.from(group.daySelections[day] ?? const []);
      dayExpandedState[day] = false;
    }

    setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      templateNameFocusNode.requestFocus();
    });
  }

  Future<void> toggleTemplateGroupActive(_TemplateGroup group) async {
    try {
      final batch = _firestore.batch();
      final nextActive = !group.isActive;

      for (final row in group.rows) {
        batch.update(row.reference, {
          'is_active': nextActive,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextActive ? 'Template activated.' : 'Template deactivated.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update template: $e')),
      );
    }
  }

  Widget _buildStaticFormSection() {
    final inEditMode = editingTemplateId != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              inEditMode
                  ? 'Edit Weekly Menu Template'
                  : 'Create Weekly Menu Template',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (inEditMode) ...[
              const SizedBox(height: 8),
              Text(
                'Editing template ID: $editingTemplateId',
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
              controller: templateNameController,
              focusNode: templateNameFocusNode,
              decoration: const InputDecoration(
                labelText: 'Template Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: selectedMealType,
              decoration: const InputDecoration(
                labelText: 'Meal Type',
                border: OutlineInputBorder(),
              ),
              items: mealTypes
                  .map(
                    (type) => DropdownMenuItem<String>(
                      value: type['value'],
                      child: Text(type['label']!),
                    ),
                  )
                  .toList(),
              onChanged: isSaving
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() {
                        selectedMealType = value;
                        _resetSelectionFilters();
                      });
                    },
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

  Widget _buildSelectionFilterSection(
    List<String> foodTypeOptions,
  ) {
    final effectiveFoodType = foodTypeOptions.contains(selectedFoodTypeFilter)
        ? selectedFoodTypeFilter
        : 'all';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: itemSearchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _applyItemSearch(),
              decoration: InputDecoration(
                hintText: 'Search item by name or ID',
                prefixIcon: IconButton(
                  tooltip: 'Search',
                  onPressed: _applyItemSearch,
                  icon: const Icon(Icons.search),
                ),
                suffixIcon: itemSearchController.text.trim().isNotEmpty
                    ? IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          setState(() {
                            _resetSelectionFilters();
                          });
                        },
                        icon: const Icon(Icons.clear),
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final vertical = constraints.maxWidth < 700;

                final foodTypeDropdown = DropdownButtonFormField<String>(
                  initialValue: effectiveFoodType,
                  decoration: const InputDecoration(
                    labelText: 'Food Type Filter',
                    border: OutlineInputBorder(),
                  ),
                  items: foodTypeOptions
                      .map(
                        (value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                            value == 'all' ? 'All Food Types' : formatLabel(value),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() {
                      selectedFoodTypeFilter = value;
                    });
                  },
                );

                final searchButton = SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: _applyItemSearch,
                    icon: const Icon(Icons.search),
                    label: const Text('Search'),
                  ),
                );

                final clearButton = SizedBox(
                  height: 56,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _resetSelectionFilters();
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Clear Filters'),
                  ),
                );

                if (vertical) {
                  return Column(
                    children: [
                      foodTypeDropdown,
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: searchButton,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: clearButton,
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: foodTypeDropdown),
                    const SizedBox(width: 12),
                    searchButton,
                    const SizedBox(width: 12),
                    clearButton,
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollButtons() {
    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        spacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: () {
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
              );
            },
            icon: const Icon(Icons.arrow_upward),
            label: const Text('Top'),
          ),
          OutlinedButton.icon(
            onPressed: () {
              if (!_scrollController.hasClients) return;
              final max = _scrollController.position.maxScrollExtent;
              _scrollController.animateTo(
                max,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
              );
            },
            icon: const Icon(Icons.arrow_downward),
            label: const Text('Bottom'),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCard({
    required String day,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> activeMenuItems,
  }) {
    final selectedIds = daySelections[day] ?? <String>[];
    final isExpanded = dayExpandedState[day] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        key: PageStorageKey('weekly-template-$day'),
        initiallyExpanded: isExpanded,
        maintainState: true,
        onExpansionChanged: (expanded) {
          setState(() {
            dayExpandedState[day] = expanded;
          });
        },
        title: Text(formatLabel(day)),
        subtitle: Text(
          selectedIds.isEmpty
              ? 'No items selected'
              : '${selectedIds.length} item(s) selected',
        ),
        children: [
          if (activeMenuItems.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No active menu items found for current meal type / filters.',
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: activeMenuItems.map((doc) {
                  final data = doc.data();
                  final itemId = doc.id;
                  final itemCode = getMenuItemCode(data, doc.id);
                  final itemName = getMenuItemName(data, doc.id);
                  final baseUnit = (data['base_unit'] ?? '').toString().trim();
                  final displayName = baseUnit.isNotEmpty
                      ? '$itemName ($baseUnit)'
                      : itemName;
                  final foodType = getFoodTypeLabel(data);
                  final checked = selectedIds.contains(itemId);

                  return CheckboxListTile(
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: checked,
                    title: Text(displayName),
                    subtitle: Text('$itemCode • $foodType'),
                    onChanged: (value) {
                      setState(() {
                        final updated = List<String>.from(
                          daySelections[day] ?? const <String>[],
                        );

                        if (value == true) {
                          if (!updated.contains(itemId)) {
                            updated.add(itemId);
                          }
                        } else {
                          updated.remove(itemId);
                        }

                        daySelections[day] = updated;
                        dayExpandedState[day] = true;
                      });
                    },
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSavedTemplateCard(_TemplateGroup group) {
    final totalItems = group.daySelections.values
        .fold<int>(0, (sum, items) => sum + items.length);

    return Card(
      key: ValueKey('${group.templateId}_${group.mealType}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  group.templateName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Chip(label: Text(group.isActive ? 'Active' : 'Inactive')),
              ],
            ),
            const SizedBox(height: 8),
            Text('Template ID: ${group.templateId}'),
            Text('Meal Type: ${formatLabel(group.mealType)}'),
            Text('Total selected items: $totalItems'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: weekDays.map((day) {
                final count = group.daySelections[day]?.length ?? 0;
                return Chip(
                  label: Text('${formatLabel(day)}: $count'),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => loadTemplateGroupForEdit(group),
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                ),
                OutlinedButton.icon(
                  onPressed: () => toggleTemplateGroupActive(group),
                  icon: Icon(
                    group.isActive ? Icons.visibility_off : Icons.visibility,
                  ),
                  label: Text(group.isActive ? 'Deactivate' : 'Activate'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<_TemplateGroup> _groupTemplateRows(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> grouped =
        {};

    for (final doc in docs) {
      final data = doc.data();
      final templateId = (data['template_id'] ?? '').toString().trim();
      final mealType = (data['meal_type'] ?? '').toString().trim().toLowerCase();
      final weekday = (data['weekday'] ?? '').toString().trim().toLowerCase();

      if (templateId.isEmpty || mealType.isEmpty || weekday.isEmpty) {
        continue;
      }

      final key = '$templateId|$mealType';
      grouped.putIfAbsent(key, () => []).add(doc);
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
      final templateName =
          (first['template_name'] ?? '').toString().trim().isEmpty
              ? templateId
              : (first['template_name'] ?? '').toString().trim();
      final mealType = (first['meal_type'] ?? '').toString().trim().toLowerCase();

      final Map<String, List<String>> dayMap = {
        for (final day in weekDays) day: <String>[],
      };

      bool anyActive = false;

      for (final row in rows) {
        final data = row.data();
        final day = (data['weekday'] ?? '').toString().trim().toLowerCase();
        final itemIds = _normalizeStringList(data['item_ids']);

        if (weekDays.contains(day)) {
          dayMap[day] = itemIds;
        }

        if (isTemplateRowActive(data)) {
          anyActive = true;
        }
      }

      return _TemplateGroup(
        templateId: templateId,
        templateName: templateName,
        mealType: mealType,
        rows: rows,
        isActive: anyActive,
        daySelections: dayMap,
      );
    }).toList();

    groups.sort((a, b) {
      final nameCompare =
          a.templateName.toLowerCase().compareTo(b.templateName.toLowerCase());
      if (nameCompare != 0) return nameCompare;

      final mealCompare = a.mealType.compareTo(b.mealType);
      if (mealCompare != 0) return mealCompare;

      return a.templateId.compareTo(b.templateId);
    });

    return groups;
  }

  Widget _buildDynamicDataSection(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> filteredActiveMenuItems,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> templateRows,
    List<String> foodTypeOptions,
  ) {
    var groups = _groupTemplateRows(templateRows);

    if (savedTemplateFilter != 'all') {
      groups = groups
          .where((group) => group.mealType == savedTemplateFilter)
          .toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Day-wise Item Selection',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildSelectionFilterSection(foodTypeOptions),
        const SizedBox(height: 12),
        _buildScrollButtons(),
        const SizedBox(height: 8),
        ...weekDays.map(
          (day) => _buildDayCard(
            day: day,
            activeMenuItems: filteredActiveMenuItems,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: isSaving ? null : saveTemplate,
            icon: const Icon(Icons.save),
            label: Text(
              isSaving
                  ? 'Saving...'
                  : editingTemplateId == null
                      ? 'Create Template'
                      : 'Update Template',
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Saved Templates',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<String>(
                    initialValue: savedTemplateFilter,
                    decoration: const InputDecoration(
                      labelText: 'Filter',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(
                        value: 'breakfast',
                        child: Text('Breakfast'),
                      ),
                      DropdownMenuItem(value: 'lunch', child: Text('Lunch')),
                      DropdownMenuItem(value: 'dinner', child: Text('Dinner')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        savedTemplateFilter = value;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (groups.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('No templates found.'),
            ),
          )
        else
          ...groups.map(_buildSavedTemplateCard),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Menu Templates'),
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
              stream: _firestore.collection('menu_items').snapshots(),
              builder: (context, itemSnapshot) {
                if (itemSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (itemSnapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Failed to load menu items: ${itemSnapshot.error}',
                      ),
                    ),
                  );
                }

                final List<QueryDocumentSnapshot<Map<String, dynamic>>> allItems =
                    List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
                  itemSnapshot.data?.docs ??
                      const <QueryDocumentSnapshot<Map<String, dynamic>>>[],
                )..sort((a, b) {
                        final aData = a.data();
                        final bData = b.data();

                        final sortCompare =
                            getSortOrder(aData).compareTo(getSortOrder(bData));
                        if (sortCompare != 0) return sortCompare;

                        final nameCompare = getMenuItemName(aData, a.id)
                            .toLowerCase()
                            .compareTo(
                              getMenuItemName(bData, b.id).toLowerCase(),
                            );
                        if (nameCompare != 0) return nameCompare;

                        return a.id.compareTo(b.id);
                      });

                final mealTypeMatchedItems = allItems.where((doc) {
                  final data = doc.data();
                  final mealTypes = getMealTypes(data);

                  return isItemActive(data) &&
                      isItemVisible(data) &&
                      mealTypes.contains(selectedMealType);
                }).toList();

                final foodTypeOptions =
                    _buildFoodTypeOptions(mealTypeMatchedItems);

                if (!foodTypeOptions.contains(selectedFoodTypeFilter)) {
                  selectedFoodTypeFilter = 'all';
                }

                final filteredActiveMenuItems =
                    _applySelectionFilters(mealTypeMatchedItems);

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _firestore.collection('weekly_menu_templates').snapshots(),
                  builder: (context, templateSnapshot) {
                    if (templateSnapshot.connectionState ==
                        ConnectionState.waiting) {
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

                    final List<QueryDocumentSnapshot<Map<String, dynamic>>>
                        templateRows =
                        List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
                      templateSnapshot.data?.docs ??
                          const <QueryDocumentSnapshot<Map<String, dynamic>>>[],
                    ).where((doc) {
                      final data = doc.data();
                      final weekday = (data['weekday'] ?? '')
                          .toString()
                          .trim()
                          .toLowerCase();
                      final mealType = (data['meal_type'] ?? '')
                          .toString()
                          .trim()
                          .toLowerCase();

                      return weekDays.contains(weekday) &&
                          mealType.isNotEmpty &&
                          isTemplateRowVisible(data);
                    }).toList();

                    return ListView(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildDynamicDataSection(
                          filteredActiveMenuItems,
                          templateRows,
                          foodTypeOptions,
                        ),
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
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> rows;
  final bool isActive;
  final Map<String, List<String>> daySelections;

  const _TemplateGroup({
    required this.templateId,
    required this.templateName,
    required this.mealType,
    required this.rows,
    required this.isActive,
    required this.daySelections,
  });
}
