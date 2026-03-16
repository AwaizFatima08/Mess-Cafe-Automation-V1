import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../main.dart';
import 'employee_dashboard_screen.dart';
import 'today_menu_screen.dart';

class EmployeeDashboardShell extends StatefulWidget {
  const EmployeeDashboardShell({super.key});

  @override
  State<EmployeeDashboardShell> createState() => _EmployeeDashboardShellState();
}

class _EmployeeDashboardShellState extends State<EmployeeDashboardShell> {
  int selectedIndex = 0;

  final List<_EmployeeSection> sections = const [
    _EmployeeSection(
      title: 'Dashboard',
      subtitle: 'Employee home and quick access',
      icon: Icons.home_outlined,
    ),
    _EmployeeSection(
      title: 'Today’s Menu',
      subtitle: 'Book breakfast, lunch, and dinner',
      icon: Icons.restaurant_menu,
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
        return EmployeeDashboardScreen(userEmail: userEmail);
      case 1:
        return TodayMenuScreen(userEmail: userEmail);
      default:
        return EmployeeDashboardScreen(userEmail: userEmail);
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
                            'Employee Panel',
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

class _EmployeeSection {
  final String title;
  final String subtitle;
  final IconData icon;

  const _EmployeeSection({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}
