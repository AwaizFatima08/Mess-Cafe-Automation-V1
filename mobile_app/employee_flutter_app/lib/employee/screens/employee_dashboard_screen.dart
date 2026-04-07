import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../admin/services/menu_resolver_service.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/daily_resolved_menu.dart';
import '../../models/resolved_meal_option.dart';
import '../../services/notification_service.dart';
import '../widgets/employee_event_invitations_section.dart';
import 'event_invitation_detail_screen.dart';
import 'today_menu_screen.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  final String userEmail;
  final String userUid;
  final String employeeNumber;
  final String employeeName;
  final String department;
  final String designation;

  const EmployeeDashboardScreen({
    super.key,
    required this.userEmail,
    required this.userUid,
    required this.employeeNumber,
    required this.employeeName,
    this.department = '',
    this.designation = '',
  });

  @override
  State<EmployeeDashboardScreen> createState() =>
      _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  final MenuResolverService _menuResolverService = MenuResolverService();
  final NotificationService _notificationService = NotificationService();

  late Future<DailyResolvedMenu?> _menuFuture;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _popupSubscription;
  final Set<String> _sessionPopupHandled = <String>{};
  bool _popupShowing = false;

  @override
  void initState() {
    super.initState();
    _menuFuture = _loadTodayMenu();
    _bindEventPopupWatcher();
  }

  @override
  void dispose() {
    _popupSubscription?.cancel();
    super.dispose();
  }

  void _bindEventPopupWatcher() {
    _popupSubscription?.cancel();

    _popupSubscription = _notificationService
        .eventInvitationPopupStream(userUid: widget.userUid)
        .listen((snapshot) {
      if (!mounted || _popupShowing) return;

      final docs = snapshot.docs.where((doc) {
        final data = doc.data();

        final popupAcknowledgedAt = data['popup_acknowledged_at'];
        if (popupAcknowledgedAt != null) {
          return false;
        }

        final contextId = (data['context_id'] ?? '').toString().trim();
        if (contextId.isEmpty) {
          return false;
        }

        if (_sessionPopupHandled.contains(doc.id)) {
          return false;
        }

        return true;
      }).toList();

      if (docs.isEmpty) return;

      final latest = docs.first;
      _sessionPopupHandled.add(latest.id);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showEventInvitationPopup(latest);
      });
    });
  }

  DateTime _startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _resolveOperationalReferenceDate() {
    final now = DateTime.now();
    if (now.hour < 6) {
      return _startOfDay(now.subtract(const Duration(days: 1)));
    }
    return _startOfDay(now);
  }

  Future<DailyResolvedMenu?> _loadTodayMenu() {
    final operationalDate = _resolveOperationalReferenceDate();
    return _menuResolverService.getBookingMenuForDate(operationalDate);
  }

  Future<void> _refreshDashboard() async {
    final future = _loadTodayMenu();

    setState(() {
      _menuFuture = future;
    });

    await future;
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day-$month-$year';
  }

  String _weekdayLabel(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
        return 'Monday';
      case DateTime.tuesday:
        return 'Tuesday';
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.thursday:
        return 'Thursday';
      case DateTime.friday:
        return 'Friday';
      case DateTime.saturday:
        return 'Saturday';
      case DateTime.sunday:
        return 'Sunday';
      default:
        return '';
    }
  }

  String _formatTimestamp(dynamic value) {
    if (value is Timestamp) {
      final dt = value.toDate();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year.toString();
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$day-$month-$year $hour:$minute';
    }
    return 'Unknown time';
  }

  String _buildItemsSummary(ResolvedMealOption option) {
    if (option.items.isEmpty) {
      return 'No items listed';
    }

    final names = option.items
        .map((item) {
          return (item['item_name'] ?? item['name'] ?? item['item_id'] ?? '')
              .toString()
              .trim();
        })
        .where((name) => name.isNotEmpty)
        .toList();

    if (names.isEmpty) {
      return 'No items listed';
    }

    return names.join(', ');
  }

  Future<void> _openReservation({
    required String diningMode,
  }) async {
    await Navigator.push(
      context,
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
            ),
            child: TodayMenuScreen(
              userEmail: widget.userEmail,
              initialDiningMode: diningMode,
            ),
          );
        },
      ),
    );

    if (!mounted) return;
    await _refreshDashboard();
  }

  Future<void> _openDineInReservation() {
    return _openReservation(diningMode: 'dine_in');
  }

  Future<void> _openTakeawayReservation() {
    return _openReservation(diningMode: 'takeaway');
  }

  Future<void> _showEventInvitationPopup(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    if (!mounted) return;

    _popupShowing = true;

    final data = doc.data();
    final title = (data['title_snapshot'] ?? '').toString().trim();
    final body = (data['body_snapshot'] ?? '').toString().trim();
    final eventId = (data['context_id'] ?? '').toString().trim();
    final createdAtLabel = _formatTimestamp(data['created_at']);

    final action = await showDialog<_EventPopupAction>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: const Icon(
                  Icons.campaign_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'New Event Invitation',
                  style: theme.textTheme.titleLarge,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title.isEmpty ? 'Event Invitation' : title,
                  style: theme.textTheme.titleMedium,
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    body,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Received: $createdAtLabel',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(_EventPopupAction.later);
              },
              child: const Text('Later'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(dialogContext).pop(_EventPopupAction.open);
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open Event'),
            ),
          ],
        );
      },
    );

    try {
      await _notificationService.acknowledgePopup(deliveryId: doc.id);

      if (action == _EventPopupAction.open && mounted && eventId.isNotEmpty) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EventInvitationDetailScreen(
              eventId: eventId,
              userUid: widget.userUid,
              employeeNumber: widget.employeeNumber,
              employeeName: widget.employeeName,
              department: widget.department,
              designation: widget.designation,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to process event popup: $e')),
      );
    } finally {
      _popupShowing = false;
    }
  }

  Widget _buildHeaderCard() {
    final theme = Theme.of(context);
    final operationalDate = _resolveOperationalReferenceDate();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        gradient: const LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primaryDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Wrap(
          runSpacing: AppSpacing.lg,
          spacing: AppSpacing.lg,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppConstants.visibleAppName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Welcome, ${widget.employeeName}',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Employee No: ${widget.employeeNumber}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Operational Date: ${_weekdayLabel(operationalDate)}, ${_formatDate(operationalDate)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                  ),
                  if (widget.department.trim().isNotEmpty ||
                      widget.designation.trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      [
                        widget.designation.trim(),
                        widget.department.trim(),
                      ].where((e) => e.isNotEmpty).join(' • '),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'View today’s menu, check your event invitations, and open reservation in one tap.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: _refreshDashboard,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
                ElevatedButton.icon(
                  onPressed: _openDineInReservation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                  ),
                  icon: const Icon(Icons.restaurant),
                  label: const Text('Dine In'),
                ),
                ElevatedButton.icon(
                  onPressed: _openTakeawayReservation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.takeout_dining),
                  label: const Text('Takeaway'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAccessCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Access',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _QuickActionTile(
                    icon: Icons.restaurant,
                    title: 'Dine In',
                    subtitle: 'Reserve meals for dine in',
                    color: AppColors.primaryLight,
                    iconColor: AppColors.primary,
                    onTap: _openDineInReservation,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: _QuickActionTile(
                    icon: Icons.takeout_dining,
                    title: 'Takeaway',
                    subtitle: 'Reserve meals for takeaway',
                    color: AppColors.accentSoft,
                    iconColor: AppColors.success,
                    onTap: _openTakeawayReservation,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMealSection({
    required String title,
    required IconData icon,
    required List<ResolvedMealOption> options,
  }) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  title,
                  style: theme.textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (options.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Text(
                  'No menu available for this meal.',
                  style: theme.textTheme.bodyMedium,
                ),
              )
            else
              ...options.map(
                (option) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _DashboardMenuOptionCard(
                    optionLabel: option.optionLabel,
                    optionKey: option.optionKey,
                    itemsSummary: _buildItemsSummary(option),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayMenuCard(DailyResolvedMenu? menu) {
    final theme = Theme.of(context);

    if (menu == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Today’s Menu Summary',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'No active menu could be resolved for the operational date.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  ElevatedButton.icon(
                    onPressed: _openDineInReservation,
                    icon: const Icon(Icons.restaurant),
                    label: const Text('Dine In'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _openTakeawayReservation,
                    icon: const Icon(Icons.takeout_dining),
                    label: const Text('Takeaway'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Wrap(
              runSpacing: AppSpacing.sm,
              spacing: AppSpacing.lg,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today’s Menu Summary',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Cycle: ${menu.cycleName.isEmpty ? 'N/A' : menu.cycleName}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Weekday Key: ${menu.weekday}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _openDineInReservation,
                      icon: const Icon(Icons.restaurant),
                      label: const Text('Dine In'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _openTakeawayReservation,
                      icon: const Icon(Icons.takeout_dining),
                      label: const Text('Takeaway'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _buildMealSection(
          title: 'Breakfast',
          icon: Icons.free_breakfast_outlined,
          options: menu.breakfastOptions,
        ),
        const SizedBox(height: AppSpacing.md),
        _buildMealSection(
          title: 'Lunch',
          icon: Icons.lunch_dining_outlined,
          options: menu.lunchOptions,
        ),
        const SizedBox(height: AppSpacing.md),
        _buildMealSection(
          title: 'Dinner',
          icon: Icons.dinner_dining_outlined,
          options: menu.dinnerOptions,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _refreshDashboard,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _buildHeaderCard(),
          const SizedBox(height: AppSpacing.md),
          EmployeeEventInvitationsSection(
            userUid: widget.userUid,
            employeeNumber: widget.employeeNumber,
            employeeName: widget.employeeName,
            department: widget.department,
            designation: widget.designation,
          ),
          const SizedBox(height: AppSpacing.md),
          _buildQuickAccessCard(),
          const SizedBox(height: AppSpacing.md),
          FutureBuilder<DailyResolvedMenu?>(
            future: _menuFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    child: Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Loading today’s menu...',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Today’s Menu Summary',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Failed to load today’s menu: ${snapshot.error}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _refreshDashboard,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                            ElevatedButton.icon(
                              onPressed: _openDineInReservation,
                              icon: const Icon(Icons.restaurant),
                              label: const Text('Dine In'),
                            ),
                            ElevatedButton.icon(
                              onPressed: _openTakeawayReservation,
                              icon: const Icon(Icons.takeout_dining),
                              label: const Text('Takeaway'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }

              return _buildTodayMenuCard(snapshot.data);
            },
          ),
        ],
      ),
    );
  }
}

enum _EventPopupAction {
  later,
  open,
}

class _QuickActionTile extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color iconColor;
  final Future<void> Function() onTap;

  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  @override
  State<_QuickActionTile> createState() => _QuickActionTileState();
}

class _QuickActionTileState extends State<_QuickActionTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedScale(
      duration: const Duration(milliseconds: 120),
      scale: _pressed ? 0.98 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          child: Ink(
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(color: AppColors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.iconColor,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    widget.title,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    widget.subtitle,
                    style: theme.textTheme.bodySmall,
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

class _DashboardMenuOptionCard extends StatelessWidget {
  final String optionLabel;
  final String optionKey;
  final String itemsSummary;

  const _DashboardMenuOptionCard({
    required this.optionLabel,
    required this.optionKey,
    required this.itemsSummary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              optionLabel,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              itemsSummary,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Chip(
              label: Text(optionKey),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}
