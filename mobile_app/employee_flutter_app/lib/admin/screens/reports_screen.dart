import 'package:flutter/material.dart';
import '../widgets/admin_section_placeholder_card.dart';

class ReportsScreen extends StatelessWidget {
  final String userEmail;

  const ReportsScreen({super.key, required this.userEmail});

  @override
  Widget build(BuildContext context) {
    return AdminSectionPlaceholderCard(
      title: 'Reports',
      subtitle: 'Reservation, billing, and operational reports',
      icon: Icons.bar_chart_outlined,
      userEmail: userEmail,
    );
  }
}
