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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController cycleNameController = TextEditingController();
  final FocusNode cycleNameFocusNode = FocusNode();

  late final TabController _tabController;

  String? breakfastTemplateId;
  String? lunchTemplate1Id;
  String? lunchTemplate2Id;
  String? dinnerTemplate1Id;
  String? dinnerTemplate2Id;

  DateTime? startDate;
  DateTime? endDate;
  bool keepActiveUntilNextChange = true;
  bool isSaving = false;
  String? statusMessage;
  String? editingCycleId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  void resetForm() {
    cycleNameController.clear();
    breakfastTemplateId = null;
    lunchTemplate1Id = null;
    lunchTemplate2Id = null;
    dinnerTemplate1Id = null;
    dinnerTemplate2Id = null;
    startDate = null;
    endDate = null;
    keepActiveUntilNextChange = true;
    statusMessage = null;
    editingCycleId = null;

    if (mounted) {
      setState(() {});
    }
  }

  String formatDate(DateTime? date) {
    if (date == null) return 'Select date';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day-$month-${date.year}';
  }

  String templateDisplay(
    String? templateId,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    if (templateId == null || templateId.isEmpty) return 'Not selected';

    for (final doc in docs) {
      if (doc.id == templateId) {
        final data = doc.data();
        final name = (data['template_name'] ?? doc.id).toString();
        return '$name ($templateId)';
      }
    }

    return templateId;
  }

  bool isTemplateActive(Map<String, dynamic> data) {
    return data['is_active'] == true ||
        data['status'] == true ||
        (data['status'] ?? '').toString().trim().toLowerCase() == 'active';
  }

  bool isCycleActive(Map<String, dynamic> data) {
    return data['is_active'] == true ||
        (data['status'] ?? '').toString().trim().toLowerCase() == 'active';
  }

  Future<void> pickDate({required bool forStartDate}) async {
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
        startDate = picked;
      } else {
        endDate = picked;
      }
    });
  }

  Future<void> saveCycle() async {
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
        statusMessage = 'Select all required templates.';
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

    try {
      setState(() {
        isSaving = true;
        statusMessage = null;
      });

      final now = FieldValue.serverTimestamp();
      final cyclesRef = _firestore.collection('menu_cycles');

      if (editingCycleId == null) {
        await cyclesRef.add({
          'cycle_name': cycleName,
          'breakfast_template_id': breakfastTemplateId,
          'lunch_template_1_id': lunchTemplate1Id,
          'lunch_template_2_id': lunchTemplate2Id,
          'dinner_template_1_id': dinnerTemplate1Id,
          'dinner_template_2_id': dinnerTemplate2Id,
          'start_date': Timestamp.fromDate(startDate!),
          'end_date': keepActiveUntilNextChange || endDate == null
              ? null
              : Timestamp.fromDate(endDate!),
          'is_active': true,
          'status': 'active',
          'created_at': now,
          'updated_at': now,
        });

        if (!mounted) return;
        setState(() {
          isSaving = false;
          statusMessage = 'Menu cycle created successfully.';
        });
      } else {
        await cyclesRef.doc(editingCycleId).update({
          'cycle_name': cycleName,
          'breakfast_template_id': breakfastTemplateId,
          'lunch_template_1_id': lunchTemplate1Id,
          'lunch_template_2_id': lunchTemplate2Id,
          'dinner_template_1_id': dinnerTemplate1Id,
          'dinner_template_2_id': dinnerTemplate2Id,
          'start_date': Timestamp.fromDate(startDate!),
          'end_date': keepActiveUntilNextChange || endDate == null
              ? null
              : Timestamp.fromDate(endDate!),
          'updated_at': now,
        });

        if (!mounted) return;
        setState(() {
          isSaving = false;
          statusMessage = 'Menu cycle updated successfully.';
        });
      }

      _tabController.animateTo(1);
      resetForm();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isSaving = false;
        statusMessage = 'Failed to save menu cycle: $e';
      });
    }
  }

  void loadCycleForEdit(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();

    cycleNameController.text = (data['cycle_name'] ?? '').toString().trim();
    breakfastTemplateId =
        (data['breakfast_template_id'] ?? '').toString().trim().isEmpty
            ? null
            : (data['breakfast_template_id'] ?? '').toString().trim();
    lunchTemplate1Id =
        (data['lunch_template_1_id'] ?? '').toString().trim().isEmpty
            ? null
            : (data['lunch_template_1_id'] ?? '').toString().trim();
    lunchTemplate2Id =
        (data['lunch_template_2_id'] ?? '').toString().trim().isEmpty
            ? null
            : (data['lunch_template_2_id'] ?? '').toString().trim();
    dinnerTemplate1Id =
        (data['dinner_template_1_id'] ?? '').toString().trim().isEmpty
            ? null
            : (data['dinner_template_1_id'] ?? '').toString().trim();
    dinnerTemplate2Id =
        (data['dinner_template_2_id'] ?? '').toString().trim().isEmpty
            ? null
            : (data['dinner_template_2_id'] ?? '').toString().trim();

    final startTs = data['start_date'];
    final endTs = data['end_date'];

    startDate = startTs is Timestamp ? startTs.toDate() : null;
    endDate = endTs is Timestamp ? endTs.toDate() : null;
    keepActiveUntilNextChange = endDate == null;
    editingCycleId = doc.id;
    statusMessage = null;

    setState(() {});
    _tabController.animateTo(0);
  }

  Future<void> toggleCycleActive(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    try {
      final data = doc.data();
      final currentlyActive = isCycleActive(data);
      final nextActive = !currentlyActive;

      await doc.reference.update({
        'is_active': nextActive,
        'status': nextActive ? 'active' : 'inactive',
        'updated_at': FieldValue.serverTimestamp(),
      });

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

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterTemplatesByMealType(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    String mealType,
  ) {
    return docs.where((doc) {
      final data = doc.data();
      return isTemplateActive(data) &&
          (data['meal_type'] ?? '').toString().trim() == mealType;
    }).toList()
      ..sort((a, b) {
        final aName = (a.data()['template_name'] ?? a.id).toString().toLowerCase();
        final bName = (b.data()['template_name'] ?? b.id).toString().toLowerCase();
        return aName.compareTo(bName);
      });
  }

  Widget _templateDropdown({
    required String label,
    required String mealType,
    required String? value,
    required ValueChanged<String?> onChanged,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> allTemplates,
  }) {
    final filtered = _filterTemplatesByMealType(allTemplates, mealType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: value,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          items: filtered
              .map(
                (doc) => DropdownMenuItem<String>(
                  value: doc.id,
                  child: Text(
                    '${(doc.data()['template_name'] ?? doc.id)} (${doc.id})',
                  ),
                ),
              )
              .toList(),
          onChanged: filtered.isEmpty ? null : onChanged,
        ),
        const SizedBox(height: 4),
        Text(
          filtered.isEmpty
              ? 'No active templates found for meal type: $mealType. Create one first.'
              : '${filtered.length} template(s) available for $mealType.',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget buildCreateEditTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Logged in as: ${widget.userEmail}'),
                  const SizedBox(height: 16),
                  Text(
                    editingCycleId == null ? 'Create Menu Cycle' : 'Edit Menu Cycle',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (editingCycleId != null) ...[
                    const SizedBox(height: 8),
                    Text('Editing cycle: $editingCycleId'),
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
                    decoration: const InputDecoration(
                      labelText: 'Cycle Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _templateDropdown(
                    label: 'Breakfast Template',
                    mealType: 'breakfast',
                    value: breakfastTemplateId,
                    onChanged: (value) => setState(() {
                      breakfastTemplateId = value;
                    }),
                    allTemplates: templateDocs,
                  ),
                  const SizedBox(height: 16),
                  _templateDropdown(
                    label: 'Lunch Template 1',
                    mealType: 'lunch',
                    value: lunchTemplate1Id,
                    onChanged: (value) => setState(() {
                      lunchTemplate1Id = value;
                    }),
                    allTemplates: templateDocs,
                  ),
                  const SizedBox(height: 16),
                  _templateDropdown(
                    label: 'Lunch Template 2',
                    mealType: 'lunch',
                    value: lunchTemplate2Id,
                    onChanged: (value) => setState(() {
                      lunchTemplate2Id = value;
                    }),
                    allTemplates: templateDocs,
                  ),
                  const SizedBox(height: 16),
                  _templateDropdown(
                    label: 'Dinner Template 1',
                    mealType: 'dinner',
                    value: dinnerTemplate1Id,
                    onChanged: (value) => setState(() {
                      dinnerTemplate1Id = value;
                    }),
                    allTemplates: templateDocs,
                  ),
                  const SizedBox(height: 16),
                  _templateDropdown(
                    label: 'Dinner Template 2',
                    mealType: 'dinner',
                    value: dinnerTemplate2Id,
                    onChanged: (value) => setState(() {
                      dinnerTemplate2Id = value;
                    }),
                    allTemplates: templateDocs,
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
                  if (statusMessage != null) ...[
                    const SizedBox(height: 12),
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
        );
      },
    );
  }

  Widget buildSavedCyclesTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('menu_cycles').snapshots(),
      builder: (context, cycleSnapshot) {
        if (cycleSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (cycleSnapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Failed to load cycles: ${cycleSnapshot.error}'),
            ),
          );
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _firestore.collection('weekly_menu_templates').snapshots(),
          builder: (context, templateSnapshot) {
            if (templateSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final templateDocs = templateSnapshot.data?.docs ?? [];
            final cycles = cycleSnapshot.data?.docs ?? [];

            cycles.sort((a, b) {
              final aName = (a.data()['cycle_name'] ?? a.id).toString().toLowerCase();
              final bName = (b.data()['cycle_name'] ?? b.id).toString().toLowerCase();
              return aName.compareTo(bName);
            });

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
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
                const SizedBox(height: 16),
                if (cycles.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('No menu cycles found.'),
                    ),
                  )
                else
                  ...cycles.map((doc) {
                    final data = doc.data();
                    final cycleName =
                        (data['cycle_name'] ?? doc.id).toString().trim();
                    final active = isCycleActive(data);

                    final breakfastId =
                        (data['breakfast_template_id'] ?? '').toString().trim();
                    final lunch1Id =
                        (data['lunch_template_1_id'] ?? '').toString().trim();
                    final lunch2Id =
                        (data['lunch_template_2_id'] ?? '').toString().trim();
                    final dinner1Id =
                        (data['dinner_template_1_id'] ?? '').toString().trim();
                    final dinner2Id =
                        (data['dinner_template_2_id'] ?? '').toString().trim();

                    final startTs = data['start_date'];
                    final endTs = data['end_date'];

                    final start = startTs is Timestamp ? startTs.toDate() : null;
                    final end = endTs is Timestamp ? endTs.toDate() : null;

                    return Card(
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
                                Chip(
                                  label: Text(active ? 'Active' : 'Inactive'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Document ID: ${doc.id}'),
                            Text('Start Date: ${formatDate(start)}'),
                            Text(
                              'End Date: ${end == null ? 'Open-ended' : formatDate(end)}',
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Breakfast: ${templateDisplay(breakfastId, templateDocs)}',
                            ),
                            Text(
                              'Lunch Template 1: ${templateDisplay(lunch1Id, templateDocs)}',
                            ),
                            Text(
                              'Lunch Template 2: ${templateDisplay(lunch2Id, templateDocs)}',
                            ),
                            Text(
                              'Dinner Template 1: ${templateDisplay(dinner1Id, templateDocs)}',
                            ),
                            Text(
                              'Dinner Template 2: ${templateDisplay(dinner2Id, templateDocs)}',
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => loadCycleForEdit(doc),
                                  icon: const Icon(Icons.edit),
                                  label: const Text('Edit'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => toggleCycleActive(doc),
                                  icon: Icon(
                                    active
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  label: Text(
                                    active ? 'Deactivate' : 'Activate',
                                  ),
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
