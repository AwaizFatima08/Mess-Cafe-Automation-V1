import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/add_menu_item_dialog.dart';

class MenuManagementScreen extends StatelessWidget {
  final String userEmail;

  const MenuManagementScreen({super.key, required this.userEmail});

  Stream<QuerySnapshot<Map<String, dynamic>>> loadMenuItems() {
    return FirebaseFirestore.instance
        .collection('menu_items')
        .orderBy('name')
        .snapshots();
  }

  String formatItemMode(String value) {
    if (value == 'optional') return 'Optional';
    return 'Inclusive';
  }

  IconData getItemIcon(String itemMode) {
    if (itemMode == 'optional') {
      return Icons.add_circle_outline;
    }
    return Icons.restaurant;
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

          if (docs.isEmpty) {
            return const Center(child: Text('No menu items found'));
          }

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
                Expanded(
                  child: ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data();

                      final name = (data['name'] ?? 'Unknown').toString();
                      final itemMode =
                          (data['item_mode'] ?? 'inclusive').toString();
                      final estimatedPrice = data['estimated_price'] ?? 0;
                      final active = data['active'] == true;

                      return Card(
                        child: ListTile(
                          leading: Icon(getItemIcon(itemMode)),
                          title: Text(name),
                          subtitle: Text(
                            'Rs $estimatedPrice • ${formatItemMode(itemMode)}',
                          ),
                          trailing: Icon(
                            active ? Icons.check_circle : Icons.cancel,
                            color: active ? Colors.green : Colors.red,
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
