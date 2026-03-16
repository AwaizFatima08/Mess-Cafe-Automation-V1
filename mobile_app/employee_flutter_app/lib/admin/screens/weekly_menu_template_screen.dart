import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class WeeklyMenuTemplateScreen extends StatefulWidget {
  final String userEmail;

  const WeeklyMenuTemplateScreen({super.key, required this.userEmail});

  @override
  State<WeeklyMenuTemplateScreen> createState() =>
      _WeeklyMenuTemplateScreenState();
}

class _WeeklyMenuTemplateScreenState extends State<WeeklyMenuTemplateScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController templateNameController = TextEditingController();
  final FocusNode templateNameFocusNode = FocusNode();
  final ScrollController createScrollController = ScrollController();

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _menuItemsStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _templatesStream;
  late final TabController _tabController;

  final List<String> weekDays = const [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  final List<Map<String, String>> templateTypes = const [
    {'value': 'breakfast', 'label': 'Breakfast'},
    {'value': 'lunch_combo_1', 'label': 'Lunch Combo 1'},
    {'value': 'lunch_combo_2', 'label': 'Lunch Combo 2'},
    {'value': 'dinner_combo_1', 'label': 'Dinner Combo 1'},
    {'value': 'dinner_combo_2', 'label': 'Dinner Combo 2'},
  ];

  final List<String> itemModes = const ['inclusive', 'optional'];

  String selectedTemplateType = 'breakfast';
  String? editingTemplateId;

  final Map<String, List<Map<String, dynamic>>> daySelections = {};
  final Map<String, bool> expandedDays = {};

  bool isSaving = false;
  String? statusMessage;
  String savedTemplateFilter = 'all';

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 2, vsync: this);

    _menuItemsStream = FirebaseFirestore.instance
        .collection('menu_items')
        .where('active', isEqualTo: true)
        .snapshots();

    _templatesStream = FirebaseFirestore.instance
        .collection('weekly_menu_templates')
        .snapshots();

    for (final day in weekDays) {
      daySelections[day] = <Map<String, dynamic>>[];
      expandedDays[day] = false;
    }
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

  List<Map<String, dynamic>> normalizeDayEntries(dynamic rawDayEntries) {
    if (rawDayEntries == null || rawDayEntries is! List) {
      return [];
    }

    final List<Map<String, dynamic>> normalized = [];

    for (final entry in rawDayEntries) {
      if (entry is String) {
        if (entry.trim().isEmpty) continue;
        normalized.add({
          'item_id': entry.trim(),
          'item_mode': 'inclusive',
        });
      } else if (entry is Map) {
        final itemId = (entry['item_id'] ?? '').toString().trim();
        final itemMode = (entry['item_mode'] ?? 'inclusive').toString().trim();

        if (itemId.isEmpty) continue;

        normalized.add({
          'item_id': itemId,
          'item_mode': itemMode.isEmpty ? 'inclusive' : itemMode,
        });
      }
    }

    return normalized;
  }

  bool isItemSelected(String day, String itemId) {
    return daySelections[day]!.any(
      (entry) => (entry['item_id'] ?? '').toString() == itemId,
    );
  }

  void addItemToDay(String day, String itemId) {
    if (isItemSelected(day, itemId)) return;

    daySelections[day]!.add({
      'item_id': itemId,
      'item_mode': 'inclusive',
    });
  }

  void removeItemFromDay(String day, String itemId) {
    daySelections[day]!.removeWhere(
      (entry) => (entry['item_id'] ?? '').toString() == itemId,
    );
  }

  void updateItemMode(String day, String itemId, String newMode) {
    final index = daySelections[day]!.indexWhere(
      (entry) => (entry['item_id'] ?? '').toString() == itemId,
    );

    if (index == -1) return;

    daySelections[day]![index]['item_mode'] = newMode;
  }

  void resetForm() {
    templateNameController.clear();
    editingTemplateId = null;
    selectedTemplateType = 'breakfast';
    statusMessage = null;

    for (final day in weekDays) {
      daySelections[day]!.clear();
      expandedDays[day] = false;
    }
  }

  void loadTemplateForEdit(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) return;

    setState(() {
      editingTemplateId = doc.id;
      templateNameController.text = (data['name'] ?? doc.id).toString();
      selectedTemplateType = (data['template_type'] ?? 'breakfast').toString();
      statusMessage = 'Editing template: ${doc.id}';

      for (final day in weekDays) {
        daySelections[day] = normalizeDayEntries(data[day]);
        expandedDays[day] = daySelections[day]!.isNotEmpty;
      }
    });

    _tabController.animateTo(0);
  }

  Future<void> saveWeeklyTemplate() async {
    final templateName = templateNameController.text.trim();

    if (templateName.isEmpty) {
      setState(() {
        statusMessage = 'Please enter a template name.';
      });
      return;
    }

    try {
      setState(() {
        isSaving = true;
        statusMessage = null;
      });

      final Map<String, dynamic> templateData = {
        'name': templateName,
        'template_type': selectedTemplateType,
        'active': true,
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (editingTemplateId == null) {
        templateData['created_at'] = FieldValue.serverTimestamp();
      }

      for (final day in weekDays) {
        templateData[day] = daySelections[day]!
            .map(
              (entry) => {
                'item_id': (entry['item_id'] ?? '').toString(),
                'item_mode': (entry['item_mode'] ?? 'inclusive').toString(),
              },
            )
            .toList();
      }

      if (editingTemplateId == null) {
        await FirebaseFirestore.instance
            .collection('weekly_menu_templates')
            .doc(templateName)
            .set(templateData);
      } else {
        await FirebaseFirestore.instance
            .collection('weekly_menu_templates')
            .doc(editingTemplateId)
            .update(templateData);
      }

      if (!mounted) return;

      setState(() {
        isSaving = false;
        statusMessage = editingTemplateId == null
            ? 'Weekly template saved successfully.'
            : 'Weekly template updated successfully.';
        resetForm();
      });

      FocusScope.of(context).unfocus();
      _tabController.animateTo(1);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isSaving = false;
        statusMessage = 'Error saving weekly template: $e';
      });
    }
  }

  Future<void> toggleTemplateActive(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    if (data == null) return;

    final currentActive = (data['active'] ?? true) == true;

    await FirebaseFirestore.instance
        .collection('weekly_menu_templates')
        .doc(doc.id)
        .update({
      'active': !currentActive,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> scrollToTop() async {
    if (!createScrollController.hasClients) return;
    await createScrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  Future<void> scrollToBottom() async {
    if (!createScrollController.hasClients) return;
    await createScrollController.animateTo(
      createScrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOut,
    );
  }

  Widget buildSelectedItemsSection({
    required String day,
    required Map<String, Map<String, dynamic>> itemMap,
  }) {
    final selectedEntries = daySelections[day]!;

    if (selectedEntries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'No items selected yet.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      children: selectedEntries.map((entry) {
        final itemId = (entry['item_id'] ?? '').toString();
        final itemMode = (entry['item_mode'] ?? 'inclusive').toString();
        final itemData = itemMap[itemId] ?? {};
        final itemName = (itemData['name'] ?? itemId).toString();
        final estimatedPrice = itemData['estimated_price'] ?? 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: Colors.blueGrey.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        itemName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () {
                        setState(() {
                          removeItemFromDay(day, itemId);
                        });
                      },
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Rs $estimatedPrice',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      child: DropdownButtonFormField<String>(
                        initialValue: itemMode,
                        decoration: const InputDecoration(
                          labelText: 'Mode',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: itemModes.map((mode) {
                          return DropdownMenuItem<String>(
                            value: mode,
                            child: Text(formatLabel(mode)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            updateItemMode(day, itemId, value);
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget buildItemPicker({
    required String day,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> items,
  }) {
    return Column(
      children: items.map((doc) {
        final data = doc.data();
        final itemName = (data['name'] ?? doc.id).toString();
        final estimatedPrice = data['estimated_price'] ?? 0;
        final selected = isItemSelected(day, doc.id);

        return CheckboxListTile(
          dense: true,
          value: selected,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(itemName),
          subtitle: Text('Rs $estimatedPrice'),
          onChanged: (value) {
            setState(() {
              if (value == true) {
                addItemToDay(day, doc.id);
              } else {
                removeItemFromDay(day, doc.id);
              }
              expandedDays[day] = true;
            });
          },
        );
      }).toList(),
    );
  }

  Widget buildDayCard({
    required String day,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> items,
    required Map<String, Map<String, dynamic>> itemMap,
  }) {
    final displayDay = '${day[0].toUpperCase()}${day.substring(1)}';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        key: PageStorageKey('weekly_template_$day'),
        initiallyExpanded: expandedDays[day] ?? false,
        onExpansionChanged: (expanded) {
          setState(() {
            expandedDays[day] = expanded;
          });
        },
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
        title: Row(
          children: [
            const Icon(Icons.calendar_today, size: 18),
            const SizedBox(width: 8),
            Text(
              displayDay,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blueGrey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${daySelections[day]!.length} selected',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Text(
                'Selected Items',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          buildSelectedItemsSection(day: day, itemMap: itemMap),
          const Divider(),
          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Text(
                'Available Menu Items',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          buildItemPicker(day: day, items: items),
        ],
      ),
    );
  }

  Widget buildHeaderCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    editingTemplateId == null
                        ? 'Create Weekly Menu Template'
                        : 'Edit Weekly Menu Template',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                if (editingTemplateId != null)
                  TextButton.icon(
                    onPressed: () {
                      setState(resetForm);
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel Edit'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: templateNameController,
              focusNode: templateNameFocusNode,
              autofocus: false,
              enableSuggestions: true,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Template Name',
                hintText: 'Enter template name',
                border: OutlineInputBorder(),
              ),
              onTap: () {
                if (!templateNameFocusNode.hasFocus) {
                  templateNameFocusNode.requestFocus();
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: selectedTemplateType,
              decoration: const InputDecoration(
                labelText: 'Template Type',
                border: OutlineInputBorder(),
              ),
              items: templateTypes.map((type) {
                return DropdownMenuItem<String>(
                  value: type['value'],
                  child: Text(type['label']!),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  selectedTemplateType = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget buildInfoCard() {
    return Card(
      color: Colors.blueGrey.withValues(alpha: 0.06),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How this works',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Create one template at a time for Breakfast, Lunch Combo 1, Lunch Combo 2, Dinner Combo 1, or Dinner Combo 2.',
            ),
            SizedBox(height: 6),
            Text(
              'Each selected item is saved using the structure: item_id + item_mode.',
            ),
            SizedBox(height: 6),
            Text(
              'Use the Saved Templates tab to review, edit, and activate/deactivate templates.',
            ),
          ],
        ),
      ),
    );
  }

  Widget buildCreateTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _menuItemsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Error loading menu items: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
            List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
          snapshot.data?.docs ?? [],
        );

        docs.sort((a, b) {
          final aName = (a.data()['name'] ?? '').toString().toLowerCase();
          final bName = (b.data()['name'] ?? '').toString().toLowerCase();
          return aName.compareTo(bName);
        });

        final Map<String, Map<String, dynamic>> itemMap = {
          for (final doc in docs) doc.id: doc.data(),
        };

        if (docs.isEmpty) {
          return const Center(child: Text('No active menu items found.'));
        }

        return Stack(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                FocusScope.of(context).unfocus();
              },
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: ListView(
                  controller: createScrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    Text(
                      'Logged in as: ${widget.userEmail}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    buildHeaderCard(),
                    const SizedBox(height: 12),
                    buildInfoCard(),
                    const SizedBox(height: 16),
                    ...weekDays.map(
                      (day) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: buildDayCard(
                          day: day,
                          items: docs,
                          itemMap: itemMap,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: isSaving ? null : saveWeeklyTemplate,
                      icon: const Icon(Icons.save),
                      label: Text(
                        isSaving
                            ? 'Saving...'
                            : editingTemplateId == null
                                ? 'Save Weekly Template'
                                : 'Update Weekly Template',
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
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 88,
              child: FloatingActionButton.small(
                heroTag: 'weekly_template_up',
                onPressed: scrollToTop,
                child: const Icon(Icons.keyboard_arrow_up),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 24,
              child: FloatingActionButton.small(
                heroTag: 'weekly_template_down',
                onPressed: scrollToBottom,
                child: const Icon(Icons.keyboard_arrow_down),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget buildSavedTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _templatesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Error loading templates: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final docs =
            List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
          snapshot.data?.docs ?? [],
        );

        docs.sort((a, b) {
          final aName = (a.data()['name'] ?? a.id).toString().toLowerCase();
          final bName = (b.data()['name'] ?? b.id).toString().toLowerCase();
          return aName.compareTo(bName);
        });

        final filteredDocs = docs.where((doc) {
          if (savedTemplateFilter == 'all') return true;
          return (doc.data()['template_type'] ?? '').toString() ==
              savedTemplateFilter;
        }).toList();

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: savedTemplateFilter,
                decoration: const InputDecoration(
                  labelText: 'Filter Templates',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(
                    value: 'all',
                    child: Text('All Types'),
                  ),
                  ...templateTypes.map(
                    (type) => DropdownMenuItem(
                      value: type['value'],
                      child: Text(type['label']!),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    savedTemplateFilter = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              Expanded(
                child: filteredDocs.isEmpty
                    ? const Center(child: Text('No templates found.'))
                    : ListView.separated(
                        itemCount: filteredDocs.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final doc = filteredDocs[index];
                          final data = doc.data();
                          final name = (data['name'] ?? doc.id).toString();
                          final type =
                              (data['template_type'] ?? '').toString();
                          final active = (data['active'] ?? true) == true;

                          int totalItems = 0;
                          for (final day in weekDays) {
                            final entries = normalizeDayEntries(data[day]);
                            totalItems += entries.length;
                          }

                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          name,
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
                                  const SizedBox(height: 6),
                                  Text('Type: ${formatLabel(type)}'),
                                  Text('Document ID: ${doc.id}'),
                                  Text('Total selected items: $totalItems'),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () => loadTemplateForEdit(doc),
                                        icon: const Icon(Icons.edit),
                                        label: const Text('Edit'),
                                      ),
                                      OutlinedButton.icon(
                                        onPressed: () => toggleTemplateActive(doc),
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
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    templateNameController.dispose();
    templateNameFocusNode.dispose();
    createScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Menu Templates'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Create / Edit'),
            Tab(text: 'Saved Templates'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          buildCreateTab(),
          buildSavedTab(),
        ],
      ),
    );
  }
}
