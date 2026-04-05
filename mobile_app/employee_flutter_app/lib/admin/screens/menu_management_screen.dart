import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/add_menu_item_dialog.dart';
import '../widgets/edit_menu_item_dialog.dart';

class MenuManagementScreen extends StatelessWidget {
  final String userEmail;

  const MenuManagementScreen({
    super.key,
    required this.userEmail,
  });

  Stream<QuerySnapshot<Map<String, dynamic>>> loadMenuItems() {
    return FirebaseFirestore.instance.collection('menu_items').snapshots();
  }

  bool isItemActive(Map<String, dynamic> data) {
    return data['is_active'] == true;
  }

  bool isItemVisible(Map<String, dynamic> data) {
    final raw = data['is_visible'];
    if (raw is bool) return raw;
    return true;
  }

  String formatStatus(Map<String, dynamic> data) {
    return isItemActive(data) ? 'Active' : 'Inactive';
  }

  String getItemName(Map<String, dynamic> data, String docId) {
    final name = (data['name'] ?? '').toString().trim();
    if (name.isNotEmpty) return name;

    final legacyName = (data['item_name'] ?? '').toString().trim();
    if (legacyName.isNotEmpty) return legacyName;

    return docId;
  }

  String getItemCode(Map<String, dynamic> data, String docId) {
    final itemId = (data['item_Id'] ?? '').toString().trim();
    if (itemId.isNotEmpty) return itemId;
    return docId;
  }

  String getFoodTypeLabel(Map<String, dynamic> data) {
    final foodTypeName = (data['food_type_name'] ?? '').toString().trim();
    if (foodTypeName.isNotEmpty) return foodTypeName;

    final foodTypeCode = (data['food_type_code'] ?? '').toString().trim();
    if (foodTypeCode.isNotEmpty) return foodTypeCode;

    return 'unspecified';
  }

  double getEstimatedPrice(Map<String, dynamic> data) {
    final raw = data['estimated_price'];

    if (raw is num) return raw.toDouble();

    if (raw is String) {
      final cleaned = raw.replaceAll(',', '').trim();
      return double.tryParse(cleaned) ?? 0;
    }

    return 0;
  }

  int getSortOrder(Map<String, dynamic> data) {
    final raw = data['sort_order'];

    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim()) ?? 999999;

    return 999999;
  }

  List<String> getMealTypes(Map<String, dynamic> data) {
    final raw = data['available_meal_types'];

    if (raw is Iterable) {
      return raw
          .map((e) => e.toString().trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
    }

    if (raw is String) {
      final normalized = raw
          .replaceAll('[', '')
          .replaceAll(']', '')
          .replaceAll('“', '')
          .replaceAll('”', '')
          .replaceAll('"', '')
          .replaceAll("'", '');

      return normalized
          .split(',')
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
    }

    final legacyCategory = (data['category'] ?? '').toString().trim().toLowerCase();
    if (legacyCategory.isNotEmpty) {
      return [legacyCategory];
    }

    return const [];
  }

  IconData getItemIcon(List<String> mealTypes, String foodType) {
    final normalizedFoodType = foodType.trim().toLowerCase();

    if (mealTypes.contains('breakfast')) {
      return Icons.free_breakfast_outlined;
    }
    if (mealTypes.contains('lunch')) {
      return Icons.lunch_dining_outlined;
    }
    if (mealTypes.contains('dinner')) {
      return Icons.dinner_dining_outlined;
    }
    if (mealTypes.contains('cafe') ||
        normalizedFoodType == 'beverage' ||
        normalizedFoodType == 'hot_beverage') {
      return Icons.local_drink_outlined;
    }

    return Icons.restaurant_menu;
  }

  Map<String, dynamic> buildEditPayload(
    Map<String, dynamic> data,
    String docId,
  ) {
    final mealTypes = getMealTypes(data);
    final itemName = getItemName(data, docId);

    return {
      ...data,

      // Normalized locked-schema aliases
      'name': itemName,
      'item_Id': getItemCode(data, docId),
      'available_meal_types': mealTypes,
      'food_type_name': (data['food_type_name'] ?? '').toString().trim(),
      'food_type_code': (data['food_type_code'] ?? '').toString().trim(),
      'estimated_price': getEstimatedPrice(data),
      'is_active': isItemActive(data),
      'is_visible': isItemVisible(data),

      // Legacy compatibility aliases for any dialog still expecting them
      'item_name': itemName,
      'category': mealTypes.isNotEmpty ? mealTypes.first : '',
    };
  }

  Future<void> toggleItemActive(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) async {
    try {
      final nextActive = !isItemActive(data);

      await FirebaseFirestore.instance.collection('menu_items').doc(docId).update({
        'is_active': nextActive,
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextActive ? 'Menu item activated.' : 'Menu item deactivated.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update menu item: $e'),
        ),
      );
    }
  }

  Color _statusColor(bool active) {
    return active ? Colors.green : Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => const AddMenuItemDialog(),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
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

          final docs = [...(snapshot.data?.docs ?? [])]
            ..sort((a, b) {
              final aData = a.data();
              final bData = b.data();

              final sortCompare =
                  getSortOrder(aData).compareTo(getSortOrder(bData));
              if (sortCompare != 0) return sortCompare;

              final nameCompare = getItemName(aData, a.id)
                  .toLowerCase()
                  .compareTo(getItemName(bData, b.id).toLowerCase());
              if (nameCompare != 0) return nameCompare;

              return a.id.compareTo(b.id);
            });

          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Logged in as: $userEmail',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Menu Items',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text('Total: ${docs.length}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (docs.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text('No menu items found'),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data();

                        final itemName = getItemName(data, doc.id);
                        final itemCode = getItemCode(data, doc.id);
                        final mealTypes = getMealTypes(data);
                        final foodType = getFoodTypeLabel(data);
                        final estimatedPrice = getEstimatedPrice(data);
                        final active = isItemActive(data);
                        final visible = isItemVisible(data);

                        return Card(
                          child: ListTile(
                            leading: Icon(
                              getItemIcon(mealTypes, foodType),
                            ),
                            title: Text(itemName),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  'ID: $itemCode • Food Type: $foodType • Rs ${estimatedPrice.toStringAsFixed(0)}',
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    ...mealTypes.map(
                                      (mealType) => Chip(
                                        label: Text(mealType),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                    Chip(
                                      label: Text(
                                        visible ? 'Visible' : 'Hidden',
                                      ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: Wrap(
                              spacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  formatStatus(data),
                                  style: TextStyle(
                                    color: _statusColor(active),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Edit',
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (_) => EditMenuItemDialog(
                                        itemId: doc.id,
                                        existingData: buildEditPayload(data, doc.id),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                                IconButton(
                                  tooltip: active ? 'Deactivate' : 'Activate',
                                  onPressed: () =>
                                      toggleItemActive(context, doc.id, data),
                                  icon: Icon(
                                    active ? Icons.toggle_on : Icons.toggle_off,
                                    color: active ? Colors.green : Colors.grey,
                                    size: 30,
                                  ),
                                ),
                              ],
                            ),
                            isThreeLine: true,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
