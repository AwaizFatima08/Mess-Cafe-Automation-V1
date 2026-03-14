import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class WeeklyMenuTemplateScreen extends StatefulWidget {
  final String userEmail;

  const WeeklyMenuTemplateScreen({super.key, required this.userEmail});

  @override
  State<WeeklyMenuTemplateScreen> createState() =>
      _WeeklyMenuTemplateScreenState();
}

class _WeeklyMenuTemplateScreenState extends State<WeeklyMenuTemplateScreen> {
  final TextEditingController templateNameController = TextEditingController();

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

  String selectedTemplateType = 'breakfast';

  final Map<String, Set<String>> daySelections = {};

  bool isSaving = false;
  String? statusMessage;

  @override
  void initState() {
    super.initState();
    for (final day in weekDays) {
      daySelections[day] = <String>{};
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> loadMenuItems() {
    return FirebaseFirestore.instance
        .collection('menu_items')
        .where('active', isEqualTo: true)
        .snapshots();
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
        'created_at': FieldValue.serverTimestamp(),
      };

      for (final day in weekDays) {
        templateData[day] = daySelections[day]!.toList();
      }

      await FirebaseFirestore.instance
          .collection('weekly_menu_templates')
          .doc(templateName)
          .set(templateData);

      setState(() {
        isSaving = false;
        statusMessage = 'Weekly template saved successfully.';
        templateNameController.clear();

        for (final day in weekDays) {
          daySelections[day]!.clear();
        }

        selectedTemplateType = 'breakfast';
      });
    } catch (e) {
      setState(() {
        isSaving = false;
        statusMessage = 'Error saving weekly template: $e';
      });
    }
  }

  Widget buildItemPicker({
    required String day,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> items,
    required Set<String> selectedItems,
  }) {
    return Column(
      children: items.map((doc) {
        final data = doc.data();
        final itemName = (data['name'] ?? doc.id).toString();
        final estimatedPrice = data['estimated_price'] ?? 0;
        final itemMode = (data['item_mode'] ?? 'inclusive').toString();

        return CheckboxListTile(
          dense: true,
          value: selectedItems.contains(doc.id),
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(itemName),
          subtitle: Text('Rs $estimatedPrice  •  ${formatLabel(itemMode)}'),
          onChanged: (value) {
            setState(() {
              if (value == true) {
                selectedItems.add(doc.id);
              } else {
                selectedItems.remove(doc.id);
              }
            });
          },
        );
      }).toList(),
    );
  }

  Widget buildDayCard({
    required String day,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> items,
  }) {
    final displayDay = '${day[0].toUpperCase()}${day.substring(1)}';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
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
          buildItemPicker(
            day: day,
            items: items,
            selectedItems: daySelections[day]!,
          ),
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
            Text(
              'Create Weekly Menu Template',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: templateNameController,
              decoration: const InputDecoration(
                labelText: 'Template Name',
                border: OutlineInputBorder(),
              ),
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
              'Create one template at a time. For example: Breakfast, Lunch Combo 1, Lunch Combo 2, Dinner Combo 1, or Dinner Combo 2.',
            ),
            SizedBox(height: 6),
            Text(
              'The selected items will be saved for each day of the week under this template.',
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    templateNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: loadMenuItems(),
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

        if (docs.isEmpty) {
          return const Center(child: Text('No active menu items found.'));
        }

        return Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
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
                  child: buildDayCard(day: day, items: docs),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: isSaving ? null : saveWeeklyTemplate,
                icon: const Icon(Icons.save),
                label: Text(isSaving ? 'Saving...' : 'Save Weekly Template'),
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
}
