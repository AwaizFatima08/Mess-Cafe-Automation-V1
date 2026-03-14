import 'package:flutter/material.dart';

class AdminSectionPlaceholderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String userEmail;

  const AdminSectionPlaceholderCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.userEmail,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 48),
                  const SizedBox(height: 16),
                  Text(title, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 12),
                  Text(
                    'Logged in as: $userEmail',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                  const Text(
                    'Status: Placeholder screen created successfully.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Backend integration, forms, and data workflows will be added in later steps.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
