import 'package:flutter/material.dart';
import '../widgets/admin_section_placeholder_card.dart';

class UserManagementScreen extends StatelessWidget {
  final String userEmail;

  const UserManagementScreen({super.key, required this.userEmail});

  @override
  Widget build(BuildContext context) {
    return AdminSectionPlaceholderCard(
      title: 'User Management',
      subtitle: 'Manage employees, customers, and access',
      icon: Icons.people_outline,
      userEmail: userEmail,
    );
  }
}
