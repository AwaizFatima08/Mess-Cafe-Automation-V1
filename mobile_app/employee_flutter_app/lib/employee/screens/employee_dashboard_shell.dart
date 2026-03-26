import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../main.dart';
import '../../services/user_profile_service.dart';
import '../../services/user_role_service.dart';
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

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
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
        subtitle: 'Employee home and quick access',
        icon: Icons.home_outlined,
      ),
      _EmployeeSection(
        key: 'today_menu',
        title: 'Today’s Menu',
        subtitle: 'Book meals',
        icon: Icons.restaurant_menu,
      ),
      _EmployeeSection(
        key: 'meal_history',
        title: 'My Meal History',
        subtitle: 'View consumption and cost',
        icon: Icons.receipt_long_outlined,
      ),
      _EmployeeSection(
        key: 'feedback',
        title: 'Meal Feedback',
        subtitle: 'Rate meals and share feedback',
        icon: Icons.feedback_outlined,
      ),
    ];
  }

  Widget _buildSelectedScreen({
    required String userEmail,
    required String employeeNumber,
    required String employeeName,
    required String userUid,
    required _EmployeeSection section,
  }) {
    switch (section.key) {
      case 'dashboard':
        return EmployeeDashboardScreen(userEmail: userEmail);

      case 'today_menu':
        return TodayMenuScreen(userEmail: userEmail);

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
        return EmployeeDashboardScreen(userEmail: userEmail);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authUser = FirebaseAuth.instance.currentUser;
    final userEmail = authUser?.email ?? 'Unknown user';

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
              title: const Text('Employee Panel'),
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

        if (role != AppUserRole.employee || profile == null) {
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
                      'You do not have access to the employee panel.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'This section is only available for employee role users.',
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

        final employeeNumber = profile.employeeNumber.trim();
        final employeeName = profile.employeeName.trim();
        final userUid = authUser.uid;

        final sections = _sectionsForRole(role);

        if (sections.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Employee Panel'),
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
        final roleLabel = profile.roleLabel;

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
                              const SizedBox(height: 4),
                              Text(
                                employeeName.isEmpty ? '—' : employeeName,
                                style: const TextStyle(fontSize: 13),
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
                  destinations: sections
                      .map(
                        (section) => NavigationRailDestination(
                          icon: Icon(section.icon),
                          label: Text(section.title),
                        ),
                      )
                      .toList(),
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
                ),
              Expanded(
                child: _buildSelectedScreen(
                  userEmail: userEmail,
                  employeeNumber: employeeNumber,
                  employeeName: employeeName,
                  userUid: userUid,
                  section: currentSection,
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
