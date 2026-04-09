import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../main.dart';
import '../../services/notification_service.dart';
import '../../services/user_profile_service.dart';
import '../../services/user_role_service.dart';
import '../../shared/screens/notifications_screen.dart';
import '../../shared/widgets/change_password_dialog.dart';
import '../../shared/widgets/notification_badge.dart';
import 'employee_dashboard_screen.dart';
import 'meal_feedback_submission_screen.dart';
import 'my_meal_history_screen.dart';
import 'today_menu_screen.dart';

class EmployeeDashboardShell extends StatefulWidget {
  const EmployeeDashboardShell({super.key});

  @override
  State<EmployeeDashboardShell> createState() =>
      _EmployeeDashboardShellState();
}

class _EmployeeDashboardShellState extends State<EmployeeDashboardShell> {
  int selectedIndex = 0;

  final UserProfileService _userProfileService = UserProfileService();
  final NotificationService _notificationService = NotificationService();

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _openNotifications(String userUid) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(userUid: userUid),
      ),
    );
  }

  Future<void> _openChangePassword() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const ChangePasswordDialog(),
    );
  }

  List<_EmployeeSection> _sectionsForRole(AppUserRole role) {
    if (role != AppUserRole.employee) {
      return const [];
    }

    return const [
      _EmployeeSection(
        key: 'dashboard',
        title: 'Dashboard',
        subtitle: 'Employee home',
        icon: Icons.home_outlined,
      ),
      _EmployeeSection(
        key: 'today_menu',
        title: 'Today Menu',
        subtitle: 'Book meals',
        icon: Icons.restaurant_menu,
      ),
      _EmployeeSection(
        key: 'meal_history',
        title: 'Meal History',
        subtitle: 'View usage',
        icon: Icons.receipt_long_outlined,
      ),
      _EmployeeSection(
        key: 'feedback',
        title: 'Feedback',
        subtitle: 'Rate meals',
        icon: Icons.feedback_outlined,
      ),
    ];
  }

  Widget _buildScreen({
    required String userEmail,
    required String employeeNumber,
    required String employeeName,
    required String userUid,
    required _EmployeeSection section,
  }) {
    switch (section.key) {
      case 'dashboard':
        return EmployeeDashboardScreen(
          userEmail: userEmail,
          userUid: userUid,
          employeeNumber: employeeNumber,
          employeeName: employeeName,
          department: '',
          designation: '',
        );

      case 'today_menu':
        return TodayMenuScreen(
          userEmail: userEmail,
        );

      case 'meal_history':
        return MyMealHistoryScreen(
          employeeNumber: employeeNumber,
          employeeName: employeeName,
          userUid: userUid,
        );

      case 'feedback':
        return MealFeedbackSubmissionScreen(
          employeeNumber: employeeNumber,
          employeeName: employeeName,
          userUid: userUid,
        );

      default:
        return EmployeeDashboardScreen(
          userEmail: userEmail,
          userUid: userUid,
          employeeNumber: employeeNumber,
          employeeName: employeeName,
          department: '',
          designation: '',
        );
    }
  }

  Widget _notificationButton(String userUid) {
    return StreamBuilder<int>(
      stream: _notificationService.unreadCountStream(userUid: userUid),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;

        return IconButton(
          tooltip: 'Notifications',
          onPressed: () => _openNotifications(userUid),
          icon: NotificationBadge(
            count: count,
            child: const Icon(Icons.notifications_outlined),
          ),
        );
      },
    );
  }

  Widget _accountMenu() {
    return PopupMenuButton<String>(
      tooltip: 'Account',
      onSelected: (value) {
        if (value == 'change_password') {
          _openChangePassword();
        } else if (value == 'logout') {
          logout();
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem<String>(
          value: 'change_password',
          child: Text('Change Password'),
        ),
        PopupMenuItem<String>(
          value: 'logout',
          child: Text('Logout'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authUser = FirebaseAuth.instance.currentUser;

    if (authUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Employee Panel'),
        ),
        body: Center(
          child: ElevatedButton(
            onPressed: logout,
            child: const Text('Return to Login'),
          ),
        ),
      );
    }

    final userEmail = authUser.email ?? 'Unknown';
    final userUid = authUser.uid;

    return FutureBuilder<AppUserProfile?>(
      future: _userProfileService.resolveCurrentUserProfile(
        authUid: userUid,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final profile = snapshot.data;

        if (profile == null || profile.role != AppUserRole.employee) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Access Restricted'),
            ),
            body: Center(
              child: ElevatedButton(
                onPressed: logout,
                child: const Text('Sign Out'),
              ),
            ),
          );
        }

        final employeeNumber = profile.employeeNumber;
        final employeeName = profile.employeeName;
        final sections = _sectionsForRole(profile.role);

        if (sections.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Employee Panel'),
              actions: [
                _notificationButton(userUid),
                _accountMenu(),
              ],
            ),
            body: const Center(
              child: Text('No sections available'),
            ),
          );
        }

        if (selectedIndex >= sections.length) {
          selectedIndex = 0;
        }

        final current = sections[selectedIndex];
        final isWide = MediaQuery.of(context).size.width >= 900;

        return Scaffold(
          appBar: AppBar(
            title: Text(current.title),
            actions: [
              _notificationButton(userUid),
              _accountMenu(),
            ],
          ),
          drawer: isWide
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
                              const SizedBox(height: 4),
                              Text(
                                employeeName.isEmpty ? '—' : employeeName,
                                style: const TextStyle(fontSize: 13),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Role: ${profile.roleLabel}',
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
                              final s = sections[index];
                              return ListTile(
                                leading: Icon(s.icon),
                                title: Text(s.title),
                                subtitle: Text(s.subtitle),
                                selected: selectedIndex == index,
                                onTap: () {
                                  setState(() => selectedIndex = index);
                                  Navigator.pop(context);
                                },
                              );
                            },
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.notifications_outlined),
                          title: const Text('Notifications'),
                          onTap: () async {
                            Navigator.pop(context);
                            await _openNotifications(userUid);
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.lock_outline),
                          title: const Text('Change Password'),
                          onTap: () async {
                            Navigator.pop(context);
                            await _openChangePassword();
                          },
                        ),
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
              if (isWide)
                NavigationRail(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (i) =>
                      setState(() => selectedIndex = i),
                  labelType: NavigationRailLabelType.all,
                  destinations: sections
                      .map(
                        (s) => NavigationRailDestination(
                          icon: Icon(s.icon),
                          label: Text(s.title),
                        ),
                      )
                      .toList(),
                ),
              Expanded(
                child: _buildScreen(
                  userEmail: userEmail,
                  employeeNumber: employeeNumber,
                  employeeName: employeeName,
                  userUid: userUid,
                  section: current,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmployeeSection {
  final String key;
  final String title;
  final String subtitle;
  final IconData icon;

  const _EmployeeSection({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}
