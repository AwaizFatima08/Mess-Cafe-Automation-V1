import 'package:flutter/material.dart';
import '../widgets/admin_section_placeholder_card.dart';

class MonthlyMenuBuilderScreen extends StatelessWidget {
  final String userEmail;

  const MonthlyMenuBuilderScreen({super.key, required this.userEmail});

  @override
  Widget build(BuildContext context) {
    return AdminSectionPlaceholderCard(
      title: 'Monthly Menu Builder',
      subtitle: 'Prepare and publish monthly menu plans',
      icon: Icons.calendar_month_outlined,
      userEmail: userEmail,
    );
  }
}
