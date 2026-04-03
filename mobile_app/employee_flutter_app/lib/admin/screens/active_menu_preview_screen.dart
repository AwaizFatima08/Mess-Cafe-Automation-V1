import 'package:flutter/material.dart';
import '../../services/menu_resolver_service.dart';

class ActiveMenuPreviewScreen extends StatefulWidget {
  final String userEmail;

  const ActiveMenuPreviewScreen({super.key, required this.userEmail});

  @override
  State<ActiveMenuPreviewScreen> createState() => _ActiveMenuPreviewScreenState();
}

class _ActiveMenuPreviewScreenState extends State<ActiveMenuPreviewScreen> {
  final MenuResolverService _resolverService = MenuResolverService();
  DateTime selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Menu Preview"),
          actions: [
            IconButton(
              icon: const Icon(Icons.calendar_month),
              onPressed: _pickDate,
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: "Breakfast"),
              Tab(text: "Lunch"),
              Tab(text: "Dinner"),
            ],
          ),
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.blueGrey[50],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.event, size: 20, color: Colors.blueGrey),
                  const SizedBox(width: 8),
                  Text(
                    _formatFullDate(selectedDate),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildMealTab("breakfast"),
                  _buildMealTab("lunch"),
                  _buildMealTab("dinner"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealTab(String mealType) {
    return FutureBuilder<Map<String, dynamic>?>(
      // FIX: Use the new filtered method from MenuResolverService
      future: _resolverService.getMenuForDate(selectedDate, mealType: mealType),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data;
        // FIX: Handle cases where the menu key doesn't exist or is empty
        if (data == null || data[mealType] == null || (data[mealType] as List).isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.set_meal_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  "No $mealType menu defined for this date.",
                  style: TextStyle(color: Colors.grey[500], fontSize: 16),
                ),
              ],
            ),
          );
        }

        final List<dynamic> items = data[mealType];

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              leading: const Icon(Icons.restaurant, color: Colors.orange),
              title: Text(
                item['menu_item_name'] ?? "Unnamed Item",
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text("ID: ${item['menu_item_id']}"),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "Rs. ${item['unit_rate']?.toStringAsFixed(2) ?? '0.00'}",
                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                  const Text("per meal", style: TextStyle(fontSize: 10)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() => selectedDate = picked);
    }
  }

  String _formatFullDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return "${date.day} ${months[date.month - 1]} ${date.year}";
  }
}
