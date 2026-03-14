import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MonthlyMenuBuilderScreen extends StatefulWidget {
  final String userEmail;

  const MonthlyMenuBuilderScreen({super.key, required this.userEmail});

  @override
  State<MonthlyMenuBuilderScreen> createState() =>
      _MonthlyMenuBuilderScreenState();
}

class _MonthlyMenuBuilderScreenState extends State<MonthlyMenuBuilderScreen> {
  DateTime selectedDate = DateTime.now();

  final Set<String> selectedBreakfastItems = {};
  final Set<String> selectedLunchItems = {};
  final Set<String> selectedDinnerItems = {};

  bool isSaving = false;
  String? statusMessage;

  String get documentId {
    final year = selectedDate.year.toString().padLeft(4, '0');
    final month = selectedDate.month.toString().padLeft(2, '0');
    final day = selectedDate.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<void> pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
    );

    if (picked == null) return;

    setState(() {
      selectedDate = picked;
      statusMessage = null;
      selectedBreakfastItems.clear();
      selectedLunchItems.clear();
      selectedDinnerItems.clear();
    });
  }

  Future<void> saveDailyMenu() async {
    try {
      setState(() {
        isSaving = true;
        statusMessage = null;
      });

      await FirebaseFirestore.instance
          .collection('daily_menus')
          .doc(documentId)
          .set({
            'date': documentId,
            'active': true,
            'booking_deadline': '07:30',
            'breakfast_items': selectedBreakfastItems.toList(),
            'lunch_items': selectedLunchItems.toList(),
            'dinner_items': selectedDinnerItems.toList(),
            'created_at': FieldValue.serverTimestamp(),
          });

      setState(() {
        isSaving = false;
        statusMessage = 'Daily menu saved successfully for $documentId';
      });
    } catch (e) {
      setState(() {
        isSaving = false;
        statusMessage = 'Error saving daily menu: $e';
      });
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> loadMenuItems() {
    return FirebaseFirestore.instance
        .collection('menu_items')
        .where('active', isEqualTo: true)
        .snapshots();
  }

  Widget buildMealSection({
    required String title,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> items,
    required Set<String> selectedItems,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          initiallyExpanded: true,
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          children: items.map((doc) {
            final data = doc.data();
            final itemName = data['name'] ?? doc.id;
            final estimatedPrice = data['estimated_price'] ?? 0;
            final checked = selectedItems.contains(doc.id);

            return CheckboxListTile(
              value: checked,
              title: Text(itemName),
              subtitle: Text('Rs $estimatedPrice'),
              controlAffinity: ListTileControlAffinity.leading,
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
        ),
      ),
    );
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
          return const Center(child: Text('No active menu items found'));
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
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Selected Date: $documentId',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: pickDate,
                        icon: const Icon(Icons.calendar_month),
                        label: const Text('Pick Date'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              buildMealSection(
                title: 'Breakfast',
                items: docs,
                selectedItems: selectedBreakfastItems,
              ),
              const SizedBox(height: 12),
              buildMealSection(
                title: 'Lunch',
                items: docs,
                selectedItems: selectedLunchItems,
              ),
              const SizedBox(height: 12),
              buildMealSection(
                title: 'Dinner',
                items: docs,
                selectedItems: selectedDinnerItems,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: isSaving ? null : saveDailyMenu,
                icon: const Icon(Icons.save),
                label: Text(isSaving ? 'Saving...' : 'Generate Daily Menu'),
              ),
              if (statusMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  statusMessage!,
                  style: TextStyle(
                    color: statusMessage!.startsWith('Error')
                        ? Colors.red
                        : Colors.green,
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
