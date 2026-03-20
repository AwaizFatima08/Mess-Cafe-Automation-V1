import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/add_menu_item_dialog.dart';
import '../widgets/edit_menu_item_dialog.dart';

class MenuManagementScreen extends StatelessWidget {
  final String userEmail;

  const MenuManagementScreen({super.key, required this.userEmail});

  Stream<QuerySnapshot<Map<String, dynamic>>> loadMenuItems() {
    return FirebaseFirestore.instance
        .collection('menu_items')
        .orderBy('item_name')
        .snapshots();
  }

  String formatStatus(Map<String, dynamic> data) {
    final isActive = data['is_active'] == true ||
        (data['status'] ?? '').toString().trim().toLowerCase() == 'active';
    return isActive ? 'Active' : 'Inactive';
  }

  bool isItemActive(Map<String, dynamic> data) {
    return data['is_active'] == true ||
        (data['status'] ?? '').toString().trim().toLowerCase() == 'active';
  }

  IconData getItemIcon(String category) {
    switch (category.trim().toLowerCase()) {
      case 'breakfast':
        return Icons.free_breakfast_outlined;
      case 'lunch':
        return Icons.lunch_dining_outlined;
      case 'dinner':
        return Icons.dinner_dining_outlined;
      case 'beverage':
      case 'hot_beverage':
        return Icons.local_drink_outlined;
      default:
        return Icons.restaurant_menu;
    }
  }

  Future<void> toggleItemActive(
    BuildContext context,
    String docId,
    Map<String, dynamic> data,
  ) async {
    try {
      final currentlyActive = isItemActive(data);
      final nextActive = !currentlyActive;

      await FirebaseFirestore.instance.collection('menu_items').doc(docId).update({
        'is_active': nextActive,
        'status': nextActive ? 'active' : 'inactive',
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(nextActive
              ? 'Menu item activated.'
              : 'Menu item deactivated.'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update menu item: $e')),
      );
    }
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

          final docs = snapshot.data?.docs ?? [];

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
                    child: Center(child: Text('No menu items found')),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data();

                        final itemName =
                            (data['item_name'] ?? doc.id).toString().trim();
                        final category =
                            (data['category'] ?? 'uncategorized').toString();
                        final estimatedPrice = data['estimated_price'] ?? 0;
                        final active = isItemActive(data);

                        return Card(
                          child: ListTile(
                            leading: Icon(getItemIcon(category)),
                            title: Text(itemName),
                            subtitle: Text(
                              'ID: ${doc.id} • Category: $category • Rs $estimatedPrice',
                            ),
                            trailing: Wrap(
                              spacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  formatStatus(data),
                                  style: TextStyle(
                                    color: active ? Colors.green : Colors.red,
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
                                        existingData: data,
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
