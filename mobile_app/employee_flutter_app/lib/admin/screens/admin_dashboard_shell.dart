import 'package:flutter/material.dart';
import 'dashboard_screen.dart';
import 'active_menu_preview_screen.dart';
import 'meal_rate_management_screen.dart';
import 'meal_feedback_dashboard_screen.dart';
import 'user_management_screen.dart';
import '../../services/user_profile_service.dart';

class AdminDashboardShell extends StatefulWidget {
  final String userEmail;
  const AdminDashboardShell({super.key, required this.userEmail});

  @override
  State<AdminDashboardShell> createState() => _AdminDashboardShellState();
}

class _AdminDashboardShellState extends State<AdminDashboardShell> {
  int _selectedIndex = 0;
  final UserProfileService _profileService = UserProfileService();

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0: return DashboardScreen(userEmail: widget.userEmail);
      case 1: return ActiveMenuPreviewScreen(userEmail: widget.userEmail);
      case 2: return const MealRateManagementScreen();
      case 3: return const MealFeedbackDashboardScreen();
      case 4: return const UserManagementScreen();
      default: return DashboardScreen(userEmail: widget.userEmail);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Console'),
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () => _profileService.signOut())],
      ),
      body: _buildBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Ops'),
          NavigationDestination(icon: Icon(Icons.restaurant_menu), label: 'Menu'),
          NavigationDestination(icon: Icon(Icons.payments), label: 'Rates'),
          NavigationDestination(icon: Icon(Icons.reviews), label: 'Feedback'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Users'),
        ],
      ),
    );
  }
}
