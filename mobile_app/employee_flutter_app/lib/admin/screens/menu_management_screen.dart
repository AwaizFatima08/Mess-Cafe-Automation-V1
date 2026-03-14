import 'package:flutter/material.dart';
import '../widgets/admin_section_placeholder_card.dart';

class MenuManagementScreen extends StatelessWidget {
  final String userEmail;

  const MenuManagementScreen({super.key, required this.userEmail});

  @override
  Widget build(BuildContext context) {
    return AdminSectionPlaceholderCard(
      title: 'Menu Management',
      subtitle: 'Manage menu items and meal categories',
      icon: Icons.restaurant_menu,
      userEmail: userEmail,
    );
  }
}
