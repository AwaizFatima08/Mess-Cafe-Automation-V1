import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../main.dart';
import '../../services/user_profile_service.dart';
import '../../services/user_role_service.dart';
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

  final UserProfileService _userProfileService = UserProfileService();
  final UserRoleService _userRoleService = UserRoleService();

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  List<_AdminSection> _sectionsForRole(AppUserRole role) {
    final sections = <_AdminSection>[
      const _AdminSection(
        key: 'dashboard',
        title: 'Dashboard',
        subtitle: 'Overview of mess and café operations',
        icon: Icons.dashboard_outlined,
      ),
    ];

    if (_userRoleService.canManageMenus(role)) {
      sections.addAll(const [
        _AdminSection(
          key: 'menu_management',
          title: 'Menu Management',
          subtitle: 'Manage menu items and item categories',
          icon: Icons.restaurant_menu,
        ),
        _AdminSection(
          key: 'weekly_templates',
          title: 'Weekly Menu Templates',
          subtitle:
              'Create reusable weekly breakfast, lunch, and dinner templates',
          icon: Icons.calendar_month_outlined,
        ),
        _AdminSection(
          key: 'menu_cycles',
          title: 'Menu Cycles',
          subtitle: 'Assign weekly templates to active date ranges',
          icon: Icons.schedule_outlined,
        ),
        _AdminSection(
          key: 'active_menu_preview',
          title: 'Active Menu Preview',
          subtitle: 'View resolved menus for selected dates',
          icon: Icons.visibility_outlined,
        ),
      ]);
    }

    if (_userRoleService.canManageUsers(role)) {
      sections.add(
        const _AdminSection(
          key: 'user_management',
          title: 'User Management',
          subtitle: 'Manage employees, accounts, and access',
          icon: Icons.people_outline,
        ),
      );
    }

    if (role == AppUserRole.developer || role == AppUserRole.admin) {
      sections.add(
        const _AdminSection(
          key: 'bulk_upload',
          title: 'Bulk Upload',
          subtitle: 'Upload menu items and master data in bulk',
          icon: Icons.upload_file_outlined,
        ),
      );
    }

    if (role == AppUserRole.developer ||
        role == AppUserRole.admin ||
        role == AppUserRole.messManager ||
        role == AppUserRole.messSupervisor) {
      sections.add(
        const _AdminSection(
          key: 'reports',
          title: 'Reports',
          subtitle: 'Reservation and operational reports',
          icon: Icons.bar_chart_outlined,
        ),
      );
    }

    return sections;
  }

  Widget _buildSelectedScreen(String userEmail, _AdminSection section) {
    switch (section.key) {
      case 'dashboard':
        return DashboardScreen(userEmail: userEmail);
      case 'menu_management':
        return MenuManagementScreen(userEmail: userEmail);
      case 'user_management':
        return UserManagementScreen(userEmail: userEmail);
      case 'weekly_templates':
        return WeeklyMenuTemplateScreen(userEmail: userEmail);
      case 'menu_cycles':
        return MenuCycleManagementScreen(userEmail: userEmail);
      case 'active_menu_preview':
        return ActiveMenuPreviewScreen(userEmail: userEmail);
      case 'bulk_upload':
        return BulkUploadScreen(userEmail: userEmail);
      case 'reports':
        return ReportsScreen(userEmail: userEmail);
      default:
        return DashboardScreen(userEmail: userEmail);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUser = FirebaseAuth.instance.currentUser;
    final userEmail = authUser?.email ?? 'Unknown user';

    if (authUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Admin Panel'),
        ),
        body: Center(
          child: ElevatedButton(
            onPressed: logout,
            child: const Text('Return to Login'),
          ),
        ),
      );
    }

    return FutureBuilder<AppUserProfile?>(
      future: _userProfileService.resolveCurrentUserProfile(
        authUid: authUser.uid,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Admin Panel'),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Unable to load your profile.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Please contact admin or sign out and try again.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: logout,
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final profile = snapshot.data;
        final role = profile?.role ?? AppUserRole.unknown;

        if (!_userRoleService.isAdminFamily(role)) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Access Restricted'),
            ),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'You do not have access to the admin panel.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'This section is only available for admin-family roles.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: logout,
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final sections = _sectionsForRole(role);

        if (sections.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Admin Panel'),
            ),
            body: const Center(
              child: Text('No sections are available for this role.'),
            ),
          );
        }

        if (selectedIndex >= sections.length) {
          selectedIndex = 0;
        }

        final currentSection = sections[selectedIndex];
        final isWideScreen = MediaQuery.of(context).size.width >= 900;
        final roleLabel = profile?.roleLabel ?? 'unknown';

        final content = _buildSelectedScreen(userEmail, currentSection);

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
                              const SizedBox(height: 4),
                              Text(
                                'Role: $roleLabel',
                                style: const TextStyle(fontSize: 13),
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
                                subtitle: Text(section.subtitle),
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
          body: isWideScreen
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: selectedIndex,
                      onDestinationSelected: (index) {
                        setState(() {
                          selectedIndex = index;
                        });
                      },
                      labelType: NavigationRailLabelType.all,
                      destinations: sections
                          .map(
                            (section) => NavigationRailDestination(
                              icon: Icon(section.icon),
                              label: Text(section.title),
                            ),
                          )
                          .toList(),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: content),
                  ],
                )
              : content,
        );
      },
    );
  }
}

class _AdminSection {
  final String key;
  final String title;
  final String subtitle;
  final IconData icon;

  const _AdminSection({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}
