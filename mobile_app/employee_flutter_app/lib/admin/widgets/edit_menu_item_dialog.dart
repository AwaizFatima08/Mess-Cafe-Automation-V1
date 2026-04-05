import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EditMenuItemDialog extends StatefulWidget {
  final String itemId;
  final Map<String, dynamic> existingData;

  const EditMenuItemDialog({
    super.key,
    required this.itemId,
    required this.existingData,
  });

  @override
  State<EditMenuItemDialog> createState() => _EditMenuItemDialogState();
}

class _EditMenuItemDialogState extends State<EditMenuItemDialog> {
  late final TextEditingController itemNameController;
  late final TextEditingController priceController;
  late final TextEditingController sortOrderController;

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

  late String selectedFoodTypeCode;
  late bool breakfastSelected;
  late bool lunchSelected;
  late bool dinnerSelected;
  late bool isActive;
  late bool isVisible;
  late bool supportsFeedback;
  late bool supportsRate;

  bool isSaving = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();

    itemNameController = TextEditingController(
      text: _getItemName(widget.existingData),
    );

    priceController = TextEditingController(
      text: _getEstimatedPrice(widget.existingData).toString(),
    );

    sortOrderController = TextEditingController(
      text: _getSortOrder(widget.existingData).toString(),
    );

    selectedFoodTypeCode = _getFoodTypeCode(widget.existingData);
    final mealTypes = _getMealTypes(widget.existingData);

    breakfastSelected = mealTypes.contains('breakfast');
    lunchSelected = mealTypes.contains('lunch');
    dinnerSelected = mealTypes.contains('dinner');

    isActive = _getBool(widget.existingData['is_active'], defaultValue: true);
    isVisible = _getBool(widget.existingData['is_visible'], defaultValue: true);
    supportsFeedback = _getBool(
      widget.existingData['supports_feedback'],
      defaultValue: true,
    );
    supportsRate = _getBool(
      widget.existingData['supports_rate'],
      defaultValue: true,
    );
  }

  String _getItemName(Map<String, dynamic> data) {
    final name = (data['name'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;

    final legacy = (data['item_name'] ?? '').toString().trim();
    if (legacy.isNotEmpty) return legacy;

    return '';
  }

  String _getFoodTypeCode(Map<String, dynamic> data) {
    final code = (data['food_type_code'] ?? '').toString().trim();
    if (code.isNotEmpty) return code;

    final legacy = (data['category'] ?? '').toString().trim();
    if (legacy.isNotEmpty) return legacy;

    return 'other';
  }

  String _foodTypeLabelFromCode(String code) {
    for (final type in _foodTypes) {
      if (type['code'] == code) {
        return type['label']!;
      }
    }
    return 'Other';
  }

  double _getEstimatedPrice(Map<String, dynamic> data) {
    final raw = data['estimated_price'];

    if (raw is num) return raw.toDouble();

    if (raw is String) {
      return double.tryParse(raw.trim()) ?? 0;
    }

    return 0;
  }

  int _getSortOrder(Map<String, dynamic> data) {
    final raw = data['sort_order'];

    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim()) ?? 0;

    return 0;
  }

  bool _getBool(dynamic raw, {required bool defaultValue}) {
    if (raw is bool) return raw;

    if (raw is String) {
      final normalized = raw.trim().toLowerCase();
      if (normalized == 'true') return true;
      if (normalized == 'false') return false;
      if (normalized == 'active') return true;
      if (normalized == 'inactive') return false;
    }

    return defaultValue;
  }

  List<String> _getMealTypes(Map<String, dynamic> data) {
    final raw = data['available_meal_types'];

    if (raw is Iterable) {
      return raw
          .map((e) => e.toString().trim().toLowerCase())
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
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
    }

    final legacyCategory = (data['category'] ?? '').toString().trim().toLowerCase();
    if (legacyCategory == 'breakfast' ||
        legacyCategory == 'lunch' ||
        legacyCategory == 'dinner') {
      return [legacyCategory];
    }

    return const [];
  }

  List<String> _selectedMealTypes() {
    final mealTypes = <String>[];
    if (breakfastSelected) mealTypes.add('breakfast');
    if (lunchSelected) mealTypes.add('lunch');
    if (dinnerSelected) mealTypes.add('dinner');
    return mealTypes;
  }

  Future<void> updateMenuItem() async {
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

      await FirebaseFirestore.instance
          .collection('menu_items')
          .doc(widget.itemId)
          .update({
        'item_Id': (widget.existingData['item_Id'] ?? widget.itemId)
            .toString()
            .trim()
            .isEmpty
            ? widget.itemId
            : (widget.existingData['item_Id'] ?? widget.itemId).toString().trim(),
        'name': itemName,
        'food_type_code': selectedFoodTypeCode,
        'food_type_name': _foodTypeLabelFromCode(selectedFoodTypeCode),
        'available_meal_types': selectedMealTypes,
        'estimated_price': estimatedPrice,
        'is_active': isActive,
        'is_visible': isVisible,
        'supports_feedback': supportsFeedback,
        'supports_rate': supportsRate,
        'sort_order': sortOrder,
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Failed to update menu item: $e';
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
      title: Text('Edit Menu Item (${widget.itemId})'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Item ID',
                border: OutlineInputBorder(),
              ),
              child: Text(widget.itemId),
            ),
            const SizedBox(height: 12),
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
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              subtitle: Text(
                isActive ? 'Item is active' : 'Item is inactive',
              ),
              value: isActive,
              onChanged: (value) {
                setState(() {
                  isActive = value;
                });
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Visible'),
              value: isVisible,
              onChanged: (value) {
                setState(() {
                  isVisible = value;
                });
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Supports Feedback'),
              value: supportsFeedback,
              onChanged: (value) {
                setState(() {
                  supportsFeedback = value;
                });
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Supports Rate'),
              value: supportsRate,
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
          onPressed: isSaving ? null : updateMenuItem,
          child: Text(isSaving ? 'Saving...' : 'Update'),
        ),
      ],
    );
  }
}
