import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../main.dart';
import '../../services/user_profile_service.dart';
import '../../services/user_role_service.dart';
import '../widgets/pending_approvals_card.dart';
import 'active_menu_preview_screen.dart';
import 'bulk_upload_screen.dart';
import 'dashboard_screen.dart';
import 'employee_master_management_screen.dart';
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
        subtitle: 'Operational overview and issuance',
        icon: Icons.dashboard_outlined,
      ),
      const _AdminSection(
        key: 'menu_management',
        title: 'Menu Items',
        subtitle: 'Create and manage food items',
        icon: Icons.restaurant_menu_outlined,
      ),
      const _AdminSection(
        key: 'weekly_templates',
        title: 'Weekly Templates',
        subtitle: 'Configure weekly meal templates',
        icon: Icons.view_week_outlined,
      ),
      const _AdminSection(
        key: 'menu_cycles',
        title: 'Menu Cycles',
        subtitle: 'Assign active date-based menu cycles',
        icon: Icons.event_repeat_outlined,
      ),
      const _AdminSection(
        key: 'active_menu_preview',
        title: 'Active Menu Preview',
        subtitle: 'Preview resolved menu by date',
        icon: Icons.visibility_outlined,
      ),
    ];

    if (_userRoleService.canManageUsers(role)) {
      sections.addAll(const [
        _AdminSection(
          key: 'pending_approvals',
          title: 'Pending Approvals',
          subtitle: 'Review pending registration requests',
          icon: Icons.pending_actions_outlined,
        ),
        _AdminSection(
          key: 'employee_master',
          title: 'Employee Master',
          subtitle: 'Manage employee master records',
          icon: Icons.badge_outlined,
        ),
        _AdminSection(
          key: 'user_management',
          title: 'User Management',
          subtitle: 'Approve users and validate linkage',
          icon: Icons.people_outline,
        ),
      ]);
    }

    if (role == AppUserRole.developer || role == AppUserRole.admin) {
      sections.addAll(const [
        _AdminSection(
          key: 'bulk_upload',
          title: 'Bulk Upload',
          subtitle: 'Upload menu and master data',
          icon: Icons.upload_file_outlined,
        ),
        _AdminSection(
          key: 'reports',
          title: 'Reports',
          subtitle: 'Operational and management reports',
          icon: Icons.bar_chart_outlined,
        ),
      ]);
    }

    return sections;
  }

  Widget _buildSelectedScreen(
    String userEmail,
    _AdminSection section,
    AppUserRole role,
  ) {
    switch (section.key) {
      case 'dashboard':
        return DashboardScreen(userEmail: userEmail);

      case 'menu_management':
        return MenuManagementScreen(userEmail: userEmail);

      case 'weekly_templates':
        return WeeklyMenuTemplateScreen(userEmail: userEmail);

      case 'menu_cycles':
        return MenuCycleManagementScreen(userEmail: userEmail);

      case 'active_menu_preview':
        return ActiveMenuPreviewScreen(userEmail: userEmail);

      case 'pending_approvals':
        return _PendingApprovalsScreen(
          userEmail: userEmail,
          onOpenUserManagement: () {
            final sections = _sectionsForRole(role);
            final userManagementIndex = sections.indexWhere(
              (item) => item.key == 'user_management',
            );

            if (userManagementIndex >= 0) {
              setState(() {
                selectedIndex = userManagementIndex;
              });
            }
          },
        );

      case 'employee_master':
        return EmployeeMasterManagementScreen(userEmail: userEmail);

      case 'user_management':
        return UserManagementScreen(userEmail: userEmail);

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
        final isAdminFamily = _userRoleService.isAdminFamily(role);

        if (!isAdminFamily) {
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
                                leading: section.key == 'pending_approvals'
                                    ? _PendingApprovalsNavIcon(
                                        selected: selectedIndex == index,
                                      )
                                    : Icon(section.icon),
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
                          icon: section.key == 'pending_approvals'
                              ? const _PendingApprovalsNavIcon(
                                  selected: false,
                                )
                              : Icon(section.icon),
                          selectedIcon: section.key == 'pending_approvals'
                              ? const _PendingApprovalsNavIcon(
                                  selected: true,
                                )
                              : Icon(section.icon),
                          label: Text(section.title),
                        ),
                      )
                      .toList(),
                ),
              Expanded(
                child: _buildSelectedScreen(
                  userEmail,
                  currentSection,
                  role,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PendingApprovalsScreen extends StatelessWidget {
  final String userEmail;
  final VoidCallback onOpenUserManagement;

  const _PendingApprovalsScreen({
    required this.userEmail,
    required this.onOpenUserManagement,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PendingApprovalsCard(
          onTap: onOpenUserManagement,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text(
                    'Failed to load pending registrations: ${snapshot.error}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pending Registration Summary',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      LinearProgressIndicator(),
                    ],
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                final count = docs.length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pending Registration Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Signed in as: $userEmail'),
                    const SizedBox(height: 12),
                    if (count == 0)
                      const Text(
                        'There are no pending registrations right now.',
                      )
                    else ...[
                      Text(
                        '$count pending registration${count == 1 ? '' : 's'} waiting for admin review.',
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: onOpenUserManagement,
                        icon: const Icon(Icons.people_outline),
                        label: const Text('Open User Management'),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _PendingApprovalsNavIcon extends StatelessWidget {
  final bool selected;

  const _PendingApprovalsNavIcon({
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        final showBadge = !snapshot.hasError && count > 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              Icons.pending_actions_outlined,
              color: selected ? Theme.of(context).colorScheme.primary : null,
            ),
            if (showBadge)
              Positioned(
                right: -8,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
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
