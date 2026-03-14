import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../main.dart';

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
      subtitle: 'Manage menu items and meal categories',
      icon: Icons.restaurant_menu,
    ),
    _AdminSection(
      title: 'User Management',
      subtitle: 'Manage employees, customers, and access',
      icon: Icons.people_outline,
    ),
    _AdminSection(
      title: 'Monthly Menu Builder',
      subtitle: 'Prepare and publish monthly menu plans',
      icon: Icons.calendar_month_outlined,
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
                          Text(userEmail, style: const TextStyle(fontSize: 14)),
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
          Expanded(
            child: _AdminSectionPlaceholder(
              title: currentSection.title,
              subtitle: currentSection.subtitle,
              icon: currentSection.icon,
              userEmail: userEmail,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminSectionPlaceholder extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String userEmail;

  const _AdminSectionPlaceholder({
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
