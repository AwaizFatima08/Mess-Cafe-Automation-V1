import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'dashboard_screen.dart';
import 'employee_master_management_screen.dart';
import 'guest_meal_booking_screen.dart';
import 'meal_cost_dashboard_screen.dart';
import 'meal_feedback_dashboard_screen.dart';
import 'meal_rate_management_screen.dart';
import 'menu_management_screen.dart';
import 'monthly_menu_builder_screen.dart';
import 'user_management_screen.dart';
import 'weekly_menu_template_screen.dart';

class AdminDashboardShell extends StatefulWidget {
  const AdminDashboardShell({super.key});

  @override
  State<AdminDashboardShell> createState() => _AdminDashboardShellState();
}

class _AdminDashboardShellState extends State<AdminDashboardShell> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  Map<String, dynamic> _roleContext = <String, dynamic>{};

  int _selectedIndex = 0;
  List<_AdminNavItem> _navItems = <_AdminNavItem>[];

  String _userEmail = '';
  String _userUid = '';

  @override
  void initState() {
    super.initState();
    _loadRoleContext();
  }

  Future<void> _loadRoleContext() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = _auth.currentUser;

      if (currentUser == null) {
        throw Exception('No authenticated user found.');
      }

      _userUid = currentUser.uid;
      _userEmail = (currentUser.email ?? '').trim();

      final roleContext = await _resolveRoleContext(
        uid: _userUid,
        email: _userEmail,
      );

      final navItems = <_AdminNavItem>[
        _AdminNavItem(
          label: 'Dashboard',
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard,
          screen: DashboardScreen(userEmail: _userEmail),
        ),
      ];

      if (_flag(roleContext, 'canManageMenus')) {
        navItems.addAll([
          _AdminNavItem(
            label: 'Menu Items',
            icon: Icons.restaurant_menu_outlined,
            selectedIcon: Icons.restaurant_menu,
            screen: MenuManagementScreen(userEmail: _userEmail),
          ),
          _AdminNavItem(
            label: 'Monthly Menu',
            icon: Icons.calendar_month_outlined,
            selectedIcon: Icons.calendar_month,
            screen: MonthlyMenuBuilderScreen(userEmail: _userEmail),
          ),
          _AdminNavItem(
            label: 'Weekly Template',
            icon: Icons.view_week_outlined,
            selectedIcon: Icons.view_week,
            screen: WeeklyMenuTemplateScreen(userEmail: _userEmail),
          ),
        ]);
      }

      if (_flag(roleContext, 'canBookGuestMeals')) {
        navItems.add(
          _AdminNavItem(
            label: 'Guest Booking',
            icon: Icons.groups_outlined,
            selectedIcon: Icons.groups,
            screen: GuestMealBookingScreen(userEmail: _userEmail),
          ),
        );
      }

      if (_flag(roleContext, 'canEnterRates')) {
        navItems.add(
          const _AdminNavItem(
            label: 'Meal Rates',
            icon: Icons.price_change_outlined,
            selectedIcon: Icons.price_change,
            screen: MealRateManagementScreen(),
          ),
        );
      }

      if (_flag(roleContext, 'canViewCostDashboard')) {
        navItems.add(
          const _AdminNavItem(
            label: 'Cost Dashboard',
            icon: Icons.bar_chart_outlined,
            selectedIcon: Icons.bar_chart,
            screen: MealCostDashboardScreen(),
          ),
        );
      }

      if (_flag(roleContext, 'canViewFeedbackDashboard')) {
        navItems.add(
          const _AdminNavItem(
            label: 'Feedback Dashboard',
            icon: Icons.feedback_outlined,
            selectedIcon: Icons.feedback,
            screen: MealFeedbackDashboardScreen(),
          ),
        );
      }

      if (_flag(roleContext, 'canManageEmployeeMaster')) {
        navItems.add(
          _AdminNavItem(
            label: 'Employee Master',
            icon: Icons.badge_outlined,
            selectedIcon: Icons.badge,
            screen: EmployeeMasterManagementScreen(userEmail: _userEmail),
          ),
        );
      }

      if (_flag(roleContext, 'canManageUsers')) {
        navItems.add(
          _AdminNavItem(
            label: 'User Management',
            icon: Icons.admin_panel_settings_outlined,
            selectedIcon: Icons.admin_panel_settings,
            screen: UserManagementScreen(userEmail: _userEmail),
          ),
        );
      }

      if (!mounted) return;

      setState(() {
        _roleContext = roleContext;
        _navItems = navItems;
        _selectedIndex = 0;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _roleContext = <String, dynamic>{
          'role': 'unknown',
        };
        _navItems = _userEmail.isEmpty
            ? const <_AdminNavItem>[]
            : <_AdminNavItem>[
                _AdminNavItem(
                  label: 'Dashboard',
                  icon: Icons.dashboard_outlined,
                  selectedIcon: Icons.dashboard,
                  screen: DashboardScreen(userEmail: _userEmail),
                ),
              ];
        _selectedIndex = 0;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load access profile: $e')),
      );
    }
  }

  Future<Map<String, dynamic>> _resolveRoleContext({
    required String uid,
    required String email,
  }) async {
    final usersRef = _firestore.collection('users');

    Map<String, dynamic>? userDoc;

    if (uid.trim().isNotEmpty) {
      final byUid = await usersRef.where('uid', isEqualTo: uid.trim()).limit(1).get();
      if (byUid.docs.isNotEmpty) {
        userDoc = byUid.docs.first.data();
      }
    }

    if (userDoc == null && email.trim().isNotEmpty) {
      final byEmail =
          await usersRef.where('email', isEqualTo: email.trim()).limit(1).get();
      if (byEmail.docs.isNotEmpty) {
        userDoc = byEmail.docs.first.data();
      }
    }

    final role = (userDoc?['role'] ?? '').toString().trim().toLowerCase();
    return _buildRoleContext(role);
  }

  Map<String, dynamic> _buildRoleContext(String role) {
    final normalizedRole = role.trim().toLowerCase();

    final base = <String, dynamic>{
      'role': normalizedRole.isEmpty ? 'unknown' : normalizedRole,
      'canManageMenus': false,
      'canBookGuestMeals': false,
      'canEnterRates': false,
      'canViewCostDashboard': false,
      'canViewFeedbackDashboard': false,
      'canManageEmployeeMaster': false,
      'canManageUsers': false,
    };

    switch (normalizedRole) {
      case 'developer':
      case 'admin':
        base.addAll({
          'canManageMenus': true,
          'canBookGuestMeals': true,
          'canEnterRates': true,
          'canViewCostDashboard': true,
          'canViewFeedbackDashboard': true,
          'canManageEmployeeMaster': true,
          'canManageUsers': true,
        });
        break;

      case 'mess_manager':
        base.addAll({
          'canBookGuestMeals': true,
          'canEnterRates': true,
          'canViewCostDashboard': true,
          'canViewFeedbackDashboard': true,
        });
        break;

      case 'mess_supervisor':
      case 'mess_dashboard_operator':
        base.addAll({
          'canBookGuestMeals': true,
          'canEnterRates': true,
          'canViewCostDashboard': true,
          'canViewFeedbackDashboard': true,
        });
        break;

      default:
        break;
    }

    return base;
  }

  bool _flag(Map<String, dynamic> source, String key) {
    final value = source[key];
    return value is bool && value;
  }

  String _roleLabel() {
    final role = (_roleContext['role'] ?? '').toString().trim();
    if (role.isEmpty || role == 'unknown') return 'Admin Panel';

    return role
        .replaceAll('_', ' ')
        .split(' ')
        .map((e) => e.isEmpty ? e : e[0].toUpperCase() + e.substring(1))
        .join(' ');
  }

  Future<void> _logout() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Widget _buildDrawerHeader(BuildContext context) {
    final theme = Theme.of(context);

    return DrawerHeader(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: theme.colorScheme.primary,
            child: Icon(
              Icons.admin_panel_settings,
              color: theme.colorScheme.onPrimary,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Mess Administration',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(_roleLabel()),
          const SizedBox(height: 4),
          Text(
            _userEmail.isEmpty ? 'No email' : _userEmail,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          _buildDrawerHeader(context),
          Expanded(
            child: ListView.builder(
              itemCount: _navItems.length,
              itemBuilder: (context, index) {
                final item = _navItems[index];
                return ListTile(
                  leading: Icon(
                    index == _selectedIndex ? item.selectedIcon : item.icon,
                  ),
                  title: Text(item.label),
                  selected: index == _selectedIndex,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _selectedIndex = index);
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Reload Access'),
            onTap: () async {
              Navigator.pop(context);
              await _loadRoleContext();
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              Navigator.pop(context);
              await _logout();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_navItems.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Admin Panel'),
          actions: [
            IconButton(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
            ),
          ],
        ),
        drawer: _buildDrawer(),
        body: const Center(
          child: Text('No accessible modules available for this account.'),
        ),
      );
    }

    final safeIndex = _selectedIndex.clamp(0, _navItems.length - 1);
    final screen = _navItems[safeIndex].screen;

    return Scaffold(
      appBar: AppBar(
        title: Text(_navItems[safeIndex].label),
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: screen,
    );
  }
}

class _AdminNavItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget screen;

  const _AdminNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.screen,
  });
}
