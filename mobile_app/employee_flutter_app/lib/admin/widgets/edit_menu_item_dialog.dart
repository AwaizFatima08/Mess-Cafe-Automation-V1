import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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

  late String category;
  late bool isActive;

  bool isSaving = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();

    itemNameController = TextEditingController(
      text: (widget.existingData['item_name'] ?? '').toString(),
    );

    priceController = TextEditingController(
      text: (widget.existingData['estimated_price'] ?? 0).toString(),
    );

    category = (widget.existingData['category'] ?? 'other').toString();

    isActive = widget.existingData['is_active'] == true ||
        (widget.existingData['status'] ?? '')
                .toString()
                .trim()
                .toLowerCase() ==
            'active';
  }

  Future<void> updateMenuItem() async {
    final itemName = itemNameController.text.trim();
    final priceText = priceController.text.trim();

    if (itemName.isEmpty || priceText.isEmpty) {
      setState(() {
        errorMessage = 'Please fill all required fields.';
      });
      return;
    }

    final estimatedPrice = num.tryParse(priceText);
    if (estimatedPrice == null) {
      setState(() {
        errorMessage = 'Estimated price must be a valid number.';
      });
      return;
    }

    try {
      setState(() {
        isSaving = true;
        errorMessage = null;
      });

      await FirebaseFirestore.instance
          .collection('menu_items')
          .doc(widget.itemId)
          .update({
        'item_name': itemName,
        'category': category,
        'estimated_price': estimatedPrice,
        'is_active': isActive,
        'status': isActive ? 'active' : 'inactive',
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
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
    super.dispose();
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
              initialValue: category,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'bread', child: Text('bread')),
                DropdownMenuItem(value: 'rice', child: Text('rice')),
                DropdownMenuItem(value: 'main_course', child: Text('main_course')),
                DropdownMenuItem(value: 'side_item', child: Text('side_item')),
                DropdownMenuItem(value: 'salad', child: Text('salad')),
                DropdownMenuItem(value: 'sauce', child: Text('sauce')),
                DropdownMenuItem(value: 'dessert', child: Text('dessert')),
                DropdownMenuItem(value: 'beverage', child: Text('beverage')),
                DropdownMenuItem(value: 'hot_beverage', child: Text('hot_beverage')),
                DropdownMenuItem(value: 'other', child: Text('other')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  category = value;
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Estimated Price',
                prefixText: 'Rs ',
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
