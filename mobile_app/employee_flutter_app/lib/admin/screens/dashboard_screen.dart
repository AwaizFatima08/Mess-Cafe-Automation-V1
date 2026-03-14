import 'package:flutter/material.dart';
import '../widgets/admin_section_placeholder_card.dart';

class DashboardScreen extends StatelessWidget {
  final String userEmail;

  const DashboardScreen({super.key, required this.userEmail});

  @override
  Widget build(BuildContext context) {
    return AdminSectionPlaceholderCard(
      title: 'Dashboard',
      subtitle: 'Overview of mess and cafe operations',
      icon: Icons.dashboard_outlined,
      userEmail: userEmail,
    );
  }
}
