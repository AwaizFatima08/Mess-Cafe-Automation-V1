import 'package:flutter/material.dart';

class EmployeeDashboardScreen extends StatelessWidget {
  final String userEmail;

  const EmployeeDashboardScreen({
    super.key,
    required this.userEmail,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Employee Dashboard',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Welcome: $userEmail',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Use this panel to access daily menu booking and future employee services.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.restaurant_menu),
            title: const Text('Today’s Menu'),
            subtitle: const Text('Book breakfast, lunch, and dinner'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 18),
          ),
        ),
      ],
    );
  }
}
