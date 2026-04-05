import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AddMenuItemDialog extends StatefulWidget {
  const AddMenuItemDialog({super.key});

  @override
  State<AddMenuItemDialog> createState() => _AddMenuItemDialogState();
}

class _AddMenuItemDialogState extends State<AddMenuItemDialog> {
  final TextEditingController itemNameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController sortOrderController =
      TextEditingController(text: '0');

  final List<Map<String, String>> _foodTypes = const [
    {'code': 'bread', 'label': 'Bread'},
    {'code': 'rice', 'label': 'Rice'},
    {'code': 'main_course', 'label': 'Main Course'},
    {'code': 'side_item', 'label': 'Side Item'},
    {'code': 'salad', 'label': 'Salad'},
    {'code': 'sauce', 'label': 'Sauce'},
    {'code': 'dessert', 'label': 'Dessert'},
    {'code': 'beverage', 'label': 'Beverage'},
    {'code': 'hot_beverage', 'label': 'Hot Beverage'},
    {'code': 'other', 'label': 'Other'},
  ];


  String selectedFoodTypeCode = 'other';
  bool breakfastSelected = false;
  bool lunchSelected = true;
  bool dinnerSelected = true;
  bool isVisible = true;
  bool supportsFeedback = true;
  bool supportsRate = true;
  bool isSaving = false;
  String? errorMessage;

  String _foodTypeLabelFromCode(String code) {
    for (final type in _foodTypes) {
      if (type['code'] == code) {
        return type['label']!;
      }
    }
    return 'Other';
  }

  List<String> _selectedMealTypes() {
    final mealTypes = <String>[];
    if (breakfastSelected) mealTypes.add('breakfast');
    if (lunchSelected) mealTypes.add('lunch');
    if (dinnerSelected) mealTypes.add('dinner');
    return mealTypes;
  }

  Future<String> _generateNextItemId() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('menu_items').get();

    var maxNumber = 0;
    final regex = RegExp(r'^ITEM(\d+)$');

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final candidates = <String>[
        (data['item_Id'] ?? '').toString().trim().toUpperCase(),
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

    final nextNumber = maxNumber + 1;
    return 'ITEM${nextNumber.toString().padLeft(3, '0')}';
  }

  Future<void> createMenuItem() async {
    final itemName = itemNameController.text.trim();
    final priceText = priceController.text.trim();
    final sortOrderText = sortOrderController.text.trim();
    final selectedMealTypes = _selectedMealTypes();

    if (itemName.isEmpty || priceText.isEmpty) {
      setState(() {
        errorMessage = 'Please fill all required fields.';
      });
      return;
    }

    if (selectedMealTypes.isEmpty) {
      setState(() {
        errorMessage = 'Select at least one meal type.';
      });
      return;
    }

    final estimatedPrice = double.tryParse(priceText);
    if (estimatedPrice == null) {
      setState(() {
        errorMessage = 'Estimated price must be a valid number.';
      });
      return;
    }

    final sortOrder = int.tryParse(sortOrderText) ?? 0;

    try {
      setState(() {
        isSaving = true;
        errorMessage = null;
      });

      final itemCode = await _generateNextItemId();

      await FirebaseFirestore.instance.collection('menu_items').doc(itemCode).set({
        'item_Id': itemCode,
        'name': itemName,
        'food_type_code': selectedFoodTypeCode,
        'food_type_name': _foodTypeLabelFromCode(selectedFoodTypeCode),
        'available_meal_types': selectedMealTypes,
        'estimated_price': estimatedPrice,
        'is_active': true,
        'is_visible': isVisible,
        'supports_feedback': supportsFeedback,
        'supports_rate': supportsRate,
        'sort_order': sortOrder,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Failed to create menu item: $e';
        isSaving = false;
      });
    }
  }

  @override
  void dispose() {
    itemNameController.dispose();
    priceController.dispose();
    sortOrderController.dispose();
    super.dispose();
  }

  Widget _buildMealTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Available Meal Types',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          value: breakfastSelected,
          contentPadding: EdgeInsets.zero,
          title: const Text('Breakfast'),
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: (value) {
            setState(() {
              breakfastSelected = value ?? false;
            });
          },
        ),
        CheckboxListTile(
          value: lunchSelected,
          contentPadding: EdgeInsets.zero,
          title: const Text('Lunch'),
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: (value) {
            setState(() {
              lunchSelected = value ?? false;
            });
          },
        ),
        CheckboxListTile(
          value: dinnerSelected,
          contentPadding: EdgeInsets.zero,
          title: const Text('Dinner'),
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: (value) {
            setState(() {
              dinnerSelected = value ?? false;
            });
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Menu Item'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: itemNameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Item Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedFoodTypeCode,
              decoration: const InputDecoration(
                labelText: 'Food Type',
                border: OutlineInputBorder(),
              ),
              items: _foodTypes
                  .map(
                    (type) => DropdownMenuItem<String>(
                      value: type['code'],
                      child: Text(type['label']!),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  selectedFoodTypeCode = value;
                });
              },
            ),
            const SizedBox(height: 12),
            _buildMealTypeSelector(),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Estimated Price',
                prefixText: 'Rs ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: sortOrderController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: const InputDecoration(
                labelText: 'Sort Order',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: isVisible,
              contentPadding: EdgeInsets.zero,
              title: const Text('Visible'),
              onChanged: (value) {
                setState(() {
                  isVisible = value;
                });
              },
            ),
            SwitchListTile(
              value: supportsFeedback,
              contentPadding: EdgeInsets.zero,
              title: const Text('Supports Feedback'),
              onChanged: (value) {
                setState(() {
                  supportsFeedback = value;
                });
              },
            ),
            SwitchListTile(
              value: supportsRate,
              contentPadding: EdgeInsets.zero,
              title: const Text('Supports Rate'),
              onChanged: (value) {
                setState(() {
                  supportsRate = value;
                });
              },
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: isSaving ? null : createMenuItem,
          child: Text(isSaving ? 'Saving...' : 'Create'),
        ),
      ],
    );
  }
}
