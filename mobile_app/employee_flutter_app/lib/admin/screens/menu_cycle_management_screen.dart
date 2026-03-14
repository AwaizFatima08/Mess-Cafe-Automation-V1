import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class MenuCycleManagementScreen extends StatefulWidget {
  final String userEmail;

  const MenuCycleManagementScreen({super.key, required this.userEmail});

  @override
  State<MenuCycleManagementScreen> createState() =>
      _MenuCycleManagementScreenState();
}

class _MenuCycleManagementScreenState extends State<MenuCycleManagementScreen> {
  final TextEditingController cycleNameController = TextEditingController();

  String? selectedBreakfastTemplate;
  String? selectedLunch1Template;
  String? selectedLunch2Template;
  String? selectedDinner1Template;
  String? selectedDinner2Template;

  DateTime? startDate;
  DateTime? endDate;

  bool keepActive = true;
  bool isSaving = false;

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> loadTemplates() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('weekly_menu_templates')
        .get();

    final docs = snapshot.docs.toList();

    docs.sort((a, b) {
      final aData = a.data();
      final bData = b.data();

      final aName = (aData['name'] ?? a.id).toString().toLowerCase();
      final bName = (bData['name'] ?? b.id).toString().toLowerCase();

      return aName.compareTo(bName);
    });

    return docs;
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

  Future<void> saveMenuCycle() async {
    if (cycleNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter cycle name')),
      );
      return;
    }

    if (selectedBreakfastTemplate == null ||
        selectedLunch1Template == null ||
        selectedLunch2Template == null ||
        selectedDinner1Template == null ||
        selectedDinner2Template == null ||
        startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all fields')),
      );
      return;
    }

    if (!keepActive && endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select end date or keep cycle open-ended')),
      );
      return;
    }

    if (!keepActive && endDate!.isBefore(startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End date cannot be earlier than start date')),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final db = FirebaseFirestore.instance;

      final activeCycles = await db
          .collection('menu_cycles')
          .where('active', isEqualTo: true)
          .get();

      for (final doc in activeCycles.docs) {
        await doc.reference.update({'active': false});
      }

      await db.collection('menu_cycles').add({
        'cycle_name': cycleNameController.text.trim(),
        'breakfast_template_id': selectedBreakfastTemplate,
        'lunch_combo1_template_id': selectedLunch1Template,
        'lunch_combo2_template_id': selectedLunch2Template,
        'dinner_combo1_template_id': selectedDinner1Template,
        'dinner_combo2_template_id': selectedDinner2Template,
        'start_date': Timestamp.fromDate(startDate!),
        'end_date': keepActive || endDate == null
            ? null
            : Timestamp.fromDate(endDate!),
        'active': true,
        'created_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Menu cycle created successfully')),
      );

      cycleNameController.clear();

      setState(() {
        selectedBreakfastTemplate = null;
        selectedLunch1Template = null;
        selectedLunch2Template = null;
        selectedDinner1Template = null;
        selectedDinner2Template = null;
        startDate = null;
        endDate = null;
        keepActive = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating cycle: $e')),
      );
    }

    if (mounted) {
      setState(() => isSaving = false);
    }
  }

  Widget templateDropdown({
    required String label,
    required String? value,
    required ValueChanged<String?> onChanged,
  }) {
    return FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      future: loadTemplates(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Error loading templates for $label: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final templates = snapshot.data ?? [];

        if (templates.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<String>(
              initialValue: value,
              decoration: InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
                helperText: 'No weekly templates found in Firestore',
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
      },
    );
  }

  @override
  void dispose() {
    cycleNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Logged in as: ${widget.userEmail}'),
            const SizedBox(height: 20),
            const Text(
              'Create Menu Cycle',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: cycleNameController,
              decoration: const InputDecoration(
                labelText: 'Cycle Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            templateDropdown(
              label: 'Breakfast Template',
              value: selectedBreakfastTemplate,
              onChanged: (v) => setState(() => selectedBreakfastTemplate = v),
            ),
            templateDropdown(
              label: 'Lunch Combo 1 Template',
              value: selectedLunch1Template,
              onChanged: (v) => setState(() => selectedLunch1Template = v),
            ),
            templateDropdown(
              label: 'Lunch Combo 2 Template',
              value: selectedLunch2Template,
              onChanged: (v) => setState(() => selectedLunch2Template = v),
            ),
            templateDropdown(
              label: 'Dinner Combo 1 Template',
              value: selectedDinner1Template,
              onChanged: (v) => setState(() => selectedDinner1Template = v),
            ),
            templateDropdown(
              label: 'Dinner Combo 2 Template',
              value: selectedDinner2Template,
              onChanged: (v) => setState(() => selectedDinner2Template = v),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('Start Date'),
              subtitle: Text(
                startDate == null
                    ? 'Select date'
                    : startDate.toString().split(' ')[0],
              ),
              trailing: const Icon(Icons.edit_calendar),
              onTap: pickStartDate,
            ),
            if (!keepActive)
              ListTile(
                leading: const Icon(Icons.calendar_month),
                title: const Text('End Date'),
                subtitle: Text(
                  endDate == null
                      ? 'Select date'
                      : endDate.toString().split(' ')[0],
                ),
                trailing: const Icon(Icons.edit_calendar),
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
                label: Text(isSaving ? 'Saving...' : 'Save Menu Cycle'),
                onPressed: isSaving ? null : saveMenuCycle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
