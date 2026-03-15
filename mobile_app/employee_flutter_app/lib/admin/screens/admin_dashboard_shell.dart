import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../main.dart';
import 'active_menu_preview_screen.dart';
import 'bulk_upload_screen.dart';
import 'dashboard_screen.dart';
import 'menu_cycle_management_screen.dart';
import 'menu_management_screen.dart';
import 'reports_screen.dart';
import 'user_management_screen.dart';
import 'weekly_menu_template_screen.dart';

class AdminDashboardShell extends StatefulWidget {
  const AdminDashboardShell({super.key});

  @override
  State<AdminDashboardShell> createState() => _AdminDashboardShellState();
}

class _AdminDashboardShellState extends State<AdminDashboardShell> {
  int selectedIndex = 0;

  final List<_AdminSection> sections = const [
    _AdminSection(
      title: 'Dashboard',
      subtitle: 'Overview of mess and cafe operations',
      icon: Icons.dashboard_outlined,
    ),
    _AdminSection(
      title: 'Menu Management',
      subtitle: 'Manage menu items and item types',
      icon: Icons.restaurant_menu,
    ),
    _AdminSection(
      title: 'User Management',
      subtitle: 'Manage employees, customers, and access',
      icon: Icons.people_outline,
    ),
    _AdminSection(
      title: 'Weekly Menu Templates',
      subtitle: 'Create reusable weekly breakfast, lunch, and dinner templates',
      icon: Icons.calendar_month_outlined,
    ),
    _AdminSection(
      title: 'Menu Cycles',
      subtitle: 'Assign weekly templates to active date ranges',
      icon: Icons.schedule_outlined,
    ),
    _AdminSection(
      title: 'Active Menu Preview',
      subtitle: 'View the consolidated resolved menu for any selected date',
      icon: Icons.visibility_outlined,
    ),
    _AdminSection(
      title: 'Bulk Upload',
      subtitle: 'Upload menu items and master data in bulk',
      icon: Icons.upload_file_outlined,
    ),
    _AdminSection(
      title: 'Reports',
      subtitle: 'Reservation, billing, and operational reports',
      icon: Icons.bar_chart_outlined,
    ),
  ];

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Widget buildSelectedScreen(String userEmail) {
    switch (selectedIndex) {
      case 0:
        return DashboardScreen(userEmail: userEmail);
      case 1:
        return MenuManagementScreen(userEmail: userEmail);
      case 2:
        return UserManagementScreen(userEmail: userEmail);
      case 3:
        return WeeklyMenuTemplateScreen(userEmail: userEmail);
      case 4:
        return MenuCycleManagementScreen(userEmail: userEmail);
      case 5:
        return ActiveMenuPreviewScreen(userEmail: userEmail);
      case 6:
        return BulkUploadScreen(userEmail: userEmail);
      case 7:
        return ReportsScreen(userEmail: userEmail);
      default:
        return DashboardScreen(userEmail: userEmail);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentSection = sections[selectedIndex];
    final isWideScreen = MediaQuery.of(context).size.width >= 900;
    final userEmail =
        FirebaseAuth.instance.currentUser?.email ?? 'Unknown user';

    return Scaffold(
      appBar: AppBar(
        title: Text(currentSection.title),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      drawer: isWideScreen
          ? null
          : Drawer(
              child: SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Admin Panel',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            userEmail,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        itemCount: sections.length,
                        itemBuilder: (context, index) {
                          final section = sections[index];
                          return ListTile(
                            leading: Icon(section.icon),
                            title: Text(section.title),
                            selected: selectedIndex == index,
                            onTap: () {
                              setState(() {
                                selectedIndex = index;
                              });
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.logout),
                      title: const Text('Logout'),
                      onTap: logout,
                    ),
                  ],
                ),
              ),
            ),
      body: Row(
        children: [
          if (isWideScreen)
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) {
                setState(() {
                  selectedIndex = index;
                });
              },
              labelType: NavigationRailLabelType.all,
              trailing: Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: 'Logout',
                        onPressed: logout,
                        icon: const Icon(Icons.logout),
                      ),
                    ],
                  ),
                ),
              ),
              destinations: sections
                  .map(
                    (section) => NavigationRailDestination(
                      icon: Icon(section.icon),
                      label: Text(section.title),
                    ),
                  )
                  .toList(),
            ),
          Expanded(child: buildSelectedScreen(userEmail)),
        ],
      ),
    );
  }
}

class _AdminSection {
  final String title;
  final String subtitle;
  final IconData icon;

  const _AdminSection({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}
