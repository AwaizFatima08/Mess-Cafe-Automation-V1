import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MenuCycleManagementScreen extends StatefulWidget {
  final String userEmail;

  const MenuCycleManagementScreen({super.key, required this.userEmail});

  @override
  State<MenuCycleManagementScreen> createState() =>
      _MenuCycleManagementScreenState();
}

class _MenuCycleManagementScreenState extends State<MenuCycleManagementScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController cycleNameController = TextEditingController();
  final FocusNode cycleNameFocusNode = FocusNode();

  late final Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _allTemplatesFuture;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _cyclesStream;
  late final TabController _tabController;

  String? editingCycleId;

  String? selectedBreakfastTemplate;
  String? selectedLunch1Template;
  String? selectedLunch2Template;
  String? selectedDinner1Template;
  String? selectedDinner2Template;

  DateTime? startDate;
  DateTime? endDate;

  bool keepActive = true;
  bool isSaving = false;
  String? statusMessage;
  String cycleFilter = 'all';

  final List<Map<String, String>> templateTypes = const [
    {'value': 'breakfast', 'label': 'Breakfast'},
    {'value': 'lunch_combo_1', 'label': 'Lunch Combo 1'},
    {'value': 'lunch_combo_2', 'label': 'Lunch Combo 2'},
    {'value': 'dinner_combo_1', 'label': 'Dinner Combo 1'},
    {'value': 'dinner_combo_2', 'label': 'Dinner Combo 2'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _allTemplatesFuture = loadTemplates();
    _cyclesStream = FirebaseFirestore.instance
        .collection('menu_cycles')
        .orderBy('created_at', descending: true)
        .snapshots();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> loadTemplates() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('weekly_menu_templates')
        .where('active', isEqualTo: true)
        .get();

    final docs = snapshot.docs.toList();

    docs.sort((a, b) {
      final aName = (a.data()['name'] ?? a.id).toString().toLowerCase();
      final bName = (b.data()['name'] ?? b.id).toString().toLowerCase();
      return aName.compareTo(bName);
    });

    return docs;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> filterTemplatesByType(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String templateType,
  ) {
    return docs.where((doc) {
      final data = doc.data();
      return (data['template_type'] ?? '').toString() == templateType;
    }).toList();
  }

  String formatLabel(String value) {
    return value
        .split('_')
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }

  DateTime? toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String formatDate(DateTime? date) {
    if (date == null) return 'Not set';
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
      initialDate: startDate ?? DateTime.now(),
    );

    if (picked != null) {
      setState(() => startDate = picked);
    }
  }

  Future<void> pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
      initialDate: endDate ?? startDate ?? DateTime.now(),
    );

    if (picked != null) {
      setState(() => endDate = picked);
    }
  }

  void resetForm() {
    cycleNameController.clear();
    editingCycleId = null;
    selectedBreakfastTemplate = null;
    selectedLunch1Template = null;
    selectedLunch2Template = null;
    selectedDinner1Template = null;
    selectedDinner2Template = null;
    startDate = null;
    endDate = null;
    keepActive = true;
    statusMessage = null;
  }

  void loadCycleForEdit(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return;

    setState(() {
      editingCycleId = doc.id;
      cycleNameController.text = (data['cycle_name'] ?? '').toString();

      selectedBreakfastTemplate =
          (data['breakfast_template_id'] ?? '').toString().isEmpty
              ? null
              : (data['breakfast_template_id']).toString();

      selectedLunch1Template =
          (data['lunch_combo_1_template_id'] ??
                  data['lunch_combo1_template_id'] ??
                  '')
              .toString()
              .isEmpty
              ? null
              : (data['lunch_combo_1_template_id'] ??
                      data['lunch_combo1_template_id'])
                  .toString();

      selectedLunch2Template =
          (data['lunch_combo_2_template_id'] ??
                  data['lunch_combo2_template_id'] ??
                  '')
              .toString()
              .isEmpty
              ? null
              : (data['lunch_combo_2_template_id'] ??
                      data['lunch_combo2_template_id'])
                  .toString();

      selectedDinner1Template =
          (data['dinner_combo_1_template_id'] ??
                  data['dinner_combo1_template_id'] ??
                  '')
              .toString()
              .isEmpty
              ? null
              : (data['dinner_combo_1_template_id'] ??
                      data['dinner_combo1_template_id'])
                  .toString();

      selectedDinner2Template =
          (data['dinner_combo_2_template_id'] ??
                  data['dinner_combo2_template_id'] ??
                  '')
              .toString()
              .isEmpty
              ? null
              : (data['dinner_combo_2_template_id'] ??
                      data['dinner_combo2_template_id'])
                  .toString();

      startDate = toDateTime(data['start_date']);
      endDate = toDateTime(data['end_date']);
      keepActive = data['end_date'] == null;
      statusMessage = 'Editing cycle: ${doc.id}';
    });

    _tabController.animateTo(0);
  }

  Future<void> setOnlyOneActiveCycle(String cycleIdToActivate) async {
    final db = FirebaseFirestore.instance;
    final activeCycles = await db
        .collection('menu_cycles')
        .where('active', isEqualTo: true)
        .get();

    for (final doc in activeCycles.docs) {
      if (doc.id != cycleIdToActivate) {
        await doc.reference.update({'active': false});
      }
    }

    await db.collection('menu_cycles').doc(cycleIdToActivate).update({
      'active': true,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> toggleCycleActive(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    if (data == null) return;

    final isCurrentlyActive = (data['active'] ?? false) == true;
    final db = FirebaseFirestore.instance;

    if (isCurrentlyActive) {
      await db.collection('menu_cycles').doc(doc.id).update({
        'active': false,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } else {
      await setOnlyOneActiveCycle(doc.id);
    }
  }

  Future<void> saveMenuCycle() async {
    if (cycleNameController.text.trim().isEmpty) {
      setState(() {
        statusMessage = 'Please enter cycle name.';
      });
      return;
    }

    if (selectedBreakfastTemplate == null ||
        selectedLunch1Template == null ||
        selectedLunch2Template == null ||
        selectedDinner1Template == null ||
        selectedDinner2Template == null ||
        startDate == null) {
      setState(() {
        statusMessage = 'Please complete all required fields.';
      });
      return;
    }

    if (!keepActive && endDate == null) {
      setState(() {
        statusMessage =
            'Please select end date or keep cycle open-ended.';
      });
      return;
    }

    if (!keepActive && endDate!.isBefore(startDate!)) {
      setState(() {
        statusMessage = 'End date cannot be earlier than start date.';
      });
      return;
    }

    setState(() {
      isSaving = true;
      statusMessage = null;
    });

    try {
      final db = FirebaseFirestore.instance;

      final payload = {
        'cycle_name': cycleNameController.text.trim(),
        'breakfast_template_id': selectedBreakfastTemplate,
        'lunch_combo_1_template_id': selectedLunch1Template,
        'lunch_combo_2_template_id': selectedLunch2Template,
        'dinner_combo_1_template_id': selectedDinner1Template,
        'dinner_combo_2_template_id': selectedDinner2Template,
        'start_date': Timestamp.fromDate(startDate!),
        'end_date': keepActive || endDate == null
            ? null
            : Timestamp.fromDate(endDate!),
        'active': true,
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (editingCycleId == null) {
        final activeCycles = await db
            .collection('menu_cycles')
            .where('active', isEqualTo: true)
            .get();

        for (final doc in activeCycles.docs) {
          await doc.reference.update({'active': false});
        }

        await db.collection('menu_cycles').add({
          ...payload,
          'created_at': FieldValue.serverTimestamp(),
        });
      } else {
        final activeCycles = await db
            .collection('menu_cycles')
            .where('active', isEqualTo: true)
            .get();

        for (final doc in activeCycles.docs) {
          if (doc.id != editingCycleId) {
            await doc.reference.update({'active': false});
          }
        }

        await db.collection('menu_cycles').doc(editingCycleId).update(payload);
      }

      if (!mounted) return;

      setState(() {
        statusMessage = editingCycleId == null
            ? 'Menu cycle created successfully.'
            : 'Menu cycle updated successfully.';
        isSaving = false;
        resetForm();
      });

      FocusScope.of(context).unfocus();
      _tabController.animateTo(1);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isSaving = false;
        statusMessage = 'Error saving cycle: $e';
      });
    }
  }

  Widget templateDropdown({
    required String label,
    required String templateType,
    required String? value,
    required ValueChanged<String?> onChanged,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> allTemplates,
  }) {
    final templates = filterTemplatesByType(allTemplates, templateType);

    if (templates.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<String>(
          initialValue: value,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            helperText:
                'No templates found for type: $templateType. Create one first.',
          ),
          items: const [],
          onChanged: null,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          helperText: '${templates.length} template(s) available',
        ),
        items: templates.map((doc) {
          final data = doc.data();
          final displayName = (data['name'] ?? doc.id).toString();

          return DropdownMenuItem<String>(
            value: doc.id,
            child: Text(displayName),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget buildDateTile({
    required IconData icon,
    required String title,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(
          value == null ? 'Select date' : formatDate(value),
        ),
        trailing: const Icon(Icons.edit_calendar),
        onTap: onTap,
      ),
    );
  }

  Widget buildCreateEditTab() {
    return FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      future: _allTemplatesFuture,
      builder: (context, snapshot) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Logged in as: ${widget.userEmail}'),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      editingCycleId == null
                          ? 'Create Menu Cycle'
                          : 'Edit Menu Cycle',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (editingCycleId != null)
                    TextButton.icon(
                      onPressed: () {
                        setState(resetForm);
                      },
                      icon: const Icon(Icons.close),
                      label: const Text('Cancel Edit'),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: cycleNameController,
                focusNode: cycleNameFocusNode,
                decoration: const InputDecoration(
                  labelText: 'Cycle Name',
                  hintText: 'Enter menu cycle name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              if (snapshot.connectionState == ConnectionState.waiting) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 16),
                const Text('Loading weekly templates...'),
              ] else if (snapshot.hasError) ...[
                Text(
                  'Error loading templates: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              ] else ...[
                templateDropdown(
                  label: 'Breakfast Template',
                  templateType: 'breakfast',
                  value: selectedBreakfastTemplate,
                  allTemplates: snapshot.data ?? [],
                  onChanged: (v) =>
                      setState(() => selectedBreakfastTemplate = v),
                ),
                templateDropdown(
                  label: 'Lunch Combo 1 Template',
                  templateType: 'lunch_combo_1',
                  value: selectedLunch1Template,
                  allTemplates: snapshot.data ?? [],
                  onChanged: (v) =>
                      setState(() => selectedLunch1Template = v),
                ),
                templateDropdown(
                  label: 'Lunch Combo 2 Template',
                  templateType: 'lunch_combo_2',
                  value: selectedLunch2Template,
                  allTemplates: snapshot.data ?? [],
                  onChanged: (v) =>
                      setState(() => selectedLunch2Template = v),
                ),
                templateDropdown(
                  label: 'Dinner Combo 1 Template',
                  templateType: 'dinner_combo_1',
                  value: selectedDinner1Template,
                  allTemplates: snapshot.data ?? [],
                  onChanged: (v) =>
                      setState(() => selectedDinner1Template = v),
                ),
                templateDropdown(
                  label: 'Dinner Combo 2 Template',
                  templateType: 'dinner_combo_2',
                  value: selectedDinner2Template,
                  allTemplates: snapshot.data ?? [],
                  onChanged: (v) =>
                      setState(() => selectedDinner2Template = v),
                ),
              ],
              const SizedBox(height: 12),
              buildDateTile(
                icon: Icons.calendar_month,
                title: 'Start Date',
                value: startDate,
                onTap: pickStartDate,
              ),
              if (!keepActive)
                buildDateTile(
                  icon: Icons.calendar_month,
                  title: 'End Date',
                  value: endDate,
                  onTap: pickEndDate,
                ),
              SwitchListTile(
                value: keepActive,
                title: const Text('Keep this cycle active until next change'),
                subtitle: const Text('Do not set an end date'),
                onChanged: (value) {
                  setState(() {
                    keepActive = value;
                    if (keepActive) {
                      endDate = null;
                    }
                  });
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: Text(
                    isSaving
                        ? 'Saving...'
                        : editingCycleId == null
                            ? 'Save Menu Cycle'
                            : 'Update Menu Cycle',
                  ),
                  onPressed: isSaving ? null : saveMenuCycle,
                ),
              ),
              if (statusMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  statusMessage!,
                  style: TextStyle(
                    color: statusMessage!.startsWith('Error')
                        ? Colors.red
                        : Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget buildSavedCyclesTab() {
    return FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      future: _allTemplatesFuture,
      builder: (context, templateSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _cyclesStream,
          builder: (context, cycleSnapshot) {
            if (cycleSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (cycleSnapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Error loading cycles: ${cycleSnapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final cycleDocs =
                List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
              cycleSnapshot.data?.docs ?? [],
            );

            final templateDocs =
                List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
              templateSnapshot.data ?? [],
            );

            final Map<String, String> templateNameMap = {
              for (final doc in templateDocs)
                doc.id: (doc.data()['name'] ?? doc.id).toString(),
            };

            final filteredCycles = cycleDocs.where((doc) {
              final active = (doc.data()['active'] ?? false) == true;
              if (cycleFilter == 'all') return true;
              if (cycleFilter == 'active') return active;
              if (cycleFilter == 'inactive') return !active;
              return true;
            }).toList();

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: cycleFilter,
                    decoration: const InputDecoration(
                      labelText: 'Filter Cycles',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('All Cycles'),
                      ),
                      DropdownMenuItem(
                        value: 'active',
                        child: Text('Active Only'),
                      ),
                      DropdownMenuItem(
                        value: 'inactive',
                        child: Text('Inactive Only'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        cycleFilter = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: filteredCycles.isEmpty
                        ? const Center(child: Text('No menu cycles found.'))
                        : ListView.separated(
                            itemCount: filteredCycles.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final doc = filteredCycles[index];
                              final data = doc.data();
                              final cycleName =
                                  (data['cycle_name'] ?? doc.id).toString();
                              final active = (data['active'] ?? false) == true;

                              final breakfastId =
                                  (data['breakfast_template_id'] ?? '')
                                      .toString();
                              final lunch1Id =
                                  (data['lunch_combo_1_template_id'] ??
                                          data['lunch_combo1_template_id'] ??
                                          '')
                                      .toString();
                              final lunch2Id =
                                  (data['lunch_combo_2_template_id'] ??
                                          data['lunch_combo2_template_id'] ??
                                          '')
                                      .toString();
                              final dinner1Id =
                                  (data['dinner_combo_1_template_id'] ??
                                          data['dinner_combo1_template_id'] ??
                                          '')
                                      .toString();
                              final dinner2Id =
                                  (data['dinner_combo_2_template_id'] ??
                                          data['dinner_combo2_template_id'] ??
                                          '')
                                      .toString();

                              final start = toDateTime(data['start_date']);
                              final end = toDateTime(data['end_date']);

                              String templateDisplay(String id) {
                                if (id.isEmpty) return 'Not set';
                                return templateNameMap[id] ?? id;
                              }

                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              cycleName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: active
                                                  ? Colors.green.withValues(
                                                      alpha: 0.10,
                                                    )
                                                  : Colors.red.withValues(
                                                      alpha: 0.10,
                                                    ),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            child: Text(
                                              active ? 'Active' : 'Inactive',
                                              style: TextStyle(
                                                color: active
                                                    ? Colors.green
                                                    : Colors.red,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text('Start Date: ${formatDate(start)}'),
                                      Text(
                                        'End Date: ${end == null ? 'Open-ended' : formatDate(end)}',
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Breakfast: ${templateDisplay(breakfastId)}',
                                      ),
                                      Text(
                                        'Lunch Combo 1: ${templateDisplay(lunch1Id)}',
                                      ),
                                      Text(
                                        'Lunch Combo 2: ${templateDisplay(lunch2Id)}',
                                      ),
                                      Text(
                                        'Dinner Combo 1: ${templateDisplay(dinner1Id)}',
                                      ),
                                      Text(
                                        'Dinner Combo 2: ${templateDisplay(dinner2Id)}',
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: () =>
                                                loadCycleForEdit(doc),
                                            icon: const Icon(Icons.edit),
                                            label: const Text('Edit'),
                                          ),
                                          OutlinedButton.icon(
                                            onPressed: () =>
                                                toggleCycleActive(doc),
                                            icon: Icon(
                                              active
                                                  ? Icons.visibility_off
                                                  : Icons.visibility,
                                            ),
                                            label: Text(
                                              active
                                                  ? 'Deactivate'
                                                  : 'Activate',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
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
  void dispose() {
    cycleNameController.dispose();
    cycleNameFocusNode.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu Cycles'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Create / Edit'),
            Tab(text: 'Saved Cycles'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          buildCreateEditTab(),
          buildSavedCyclesTab(),
        ],
      ),
    );
  }
}
