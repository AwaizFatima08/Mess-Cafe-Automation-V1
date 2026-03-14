import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AddMenuItemDialog extends StatefulWidget {
  const AddMenuItemDialog({super.key});

  @override
  State<AddMenuItemDialog> createState() => _AddMenuItemDialogState();
}

class _AddMenuItemDialogState extends State<AddMenuItemDialog> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();

  String itemMode = 'inclusive';
  bool isSaving = false;
  String? errorMessage;

  Future<void> createMenuItem() async {
    final name = nameController.text.trim();
    final priceText = priceController.text.trim();

    if (name.isEmpty || priceText.isEmpty) {
      setState(() {
        errorMessage = 'Please fill all required fields.';
      });
      return;
    }

    final estimatedPrice = int.tryParse(priceText);
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

      await FirebaseFirestore.instance.collection('menu_items').add({
        'name': name,
        'item_mode': itemMode,
        'estimated_price': estimatedPrice,
        'active': true,
        'created_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      setState(() {
        errorMessage = 'Failed to create menu item: $e';
        isSaving = false;
      });
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    priceController.dispose();
    super.dispose();
  }

  String formatItemModeLabel(String value) {
    if (value == 'optional') return 'Optional';
    return 'Inclusive';
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
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Item Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Estimated Price',
                prefixText: 'Rs ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: itemMode,
              decoration: const InputDecoration(
                labelText: 'Item Type',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'inclusive',
                  child: Text('Inclusive'),
                ),
                DropdownMenuItem(
                  value: 'optional',
                  child: Text('Optional'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  itemMode = value;
                });
              },
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                itemMode == 'optional'
                    ? 'Optional items can be shown as add-ons or extras in menus.'
                    : 'Inclusive items are part of the standard meal by default.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
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
