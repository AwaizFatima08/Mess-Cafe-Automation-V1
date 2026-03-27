import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../main.dart';
import '../../services/notification_service.dart';
import '../../shared/screens/notifications_screen.dart';
import '../../shared/widgets/notification_badge.dart';
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
  bool _isLoading = true;
  Map<String, dynamic> _roleContext = <String, dynamic>{};

  int _selectedIndex = 0;
  List<_AdminNavItem> _navItems = <_AdminNavItem>[];

  final NotificationService _notificationService = NotificationService();

  String get _userEmail =>
      FirebaseAuth.instance.currentUser?.email?.trim().isNotEmpty == true
          ? FirebaseAuth.instance.currentUser!.email!.trim()
          : 'admin@local';

  String get _userUid =>
      FirebaseAuth.instance.currentUser?.uid.trim().isNotEmpty == true
          ? FirebaseAuth.instance.currentUser!.uid.trim()
          : 'admin_local_uid';

  @override
  void initState() {
    super.initState();
    _loadRoleContext();
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _loadRoleContext() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final roleContext = <String, dynamic>{
        'canManageMenus': true,
        'canBookGuestMeals': true,
        'canEnterRates': true,
        'canManageEmployeeMaster': true,
        'canManageUsers': true,
        'canViewFeedbackDashboard': true,
        'role': 'admin',
      };

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

      navItems.add(
        const _AdminNavItem(
          label: 'Cost Dashboard',
          icon: Icons.bar_chart_outlined,
          selectedIcon: Icons.bar_chart,
          screen: MealCostDashboardScreen(),
        ),
      );

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
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _navItems = [
          _AdminNavItem(
            label: 'Dashboard',
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard,
            screen: DashboardScreen(userEmail: _userEmail),
          ),
        ];
        _isLoading = false;
      });
    }
  }

  bool _flag(Map<String, dynamic> source, String key) {
    final value = source[key];
    return value is bool && value;
  }

  String _roleLabel() {
    final role = (_roleContext['role'] ?? '').toString().trim();
    if (role.isEmpty) return 'Admin Panel';

    return role
        .replaceAll('_', ' ')
        .split(' ')
        .map((e) => e.isEmpty ? e : e[0].toUpperCase() + e.substring(1))
        .join(' ');
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(
          userUid: _userUid,
          isAdminView: true,
        ),
      ),
    );
  }

  Widget _buildNotificationAction() {
    return StreamBuilder<int>(
      stream: _notificationService.unreadCountStream(userUid: _userUid),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;

        return IconButton(
          tooltip: 'Notifications',
          onPressed: _openNotifications,
          icon: NotificationBadge(
            count: count,
            child: const Icon(Icons.notifications_outlined),
          ),
        );
      },
    );
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
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(_roleLabel()),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: SafeArea(
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
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Notifications'),
              onTap: () async {
                Navigator.pop(context);
                await _openNotifications();
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: _logout,
            ),
          ],
        ),
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

    final safeIndex = _selectedIndex.clamp(0, _navItems.length - 1);
    final screen = _navItems[safeIndex].screen;

    return Scaffold(
      appBar: AppBar(
        title: Text(_navItems[safeIndex].label),
        actions: [
          _buildNotificationAction(),
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
