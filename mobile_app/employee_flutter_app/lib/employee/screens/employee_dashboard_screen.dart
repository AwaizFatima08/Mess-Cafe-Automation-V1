import 'package:flutter/material.dart';

import '../../admin/services/menu_resolver_service.dart';
import '../../models/daily_resolved_menu.dart';
import '../../models/resolved_meal_option.dart';
import 'today_menu_screen.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  final String userEmail;

  const EmployeeDashboardScreen({
    super.key,
    required this.userEmail,
  });

  @override
  State<EmployeeDashboardScreen> createState() =>
      _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  final MenuResolverService _menuResolverService = MenuResolverService();

  late Future<DailyResolvedMenu?> _menuFuture;

  @override
  void initState() {
    super.initState();
    _menuFuture = _loadTodayMenu();
  }

  Future<DailyResolvedMenu?> _loadTodayMenu() {
    final today = _startOfDay(DateTime.now());
    return _menuResolverService.getBookingMenuForDate(today);
  }

  Future<void> _refreshDashboard() async {
    final future = _loadTodayMenu();

    setState(() {
      _menuFuture = future;
    });

    await future;
  }

  DateTime _startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
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

  void _openDineInReservation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TodayMenuScreen(
          userEmail: widget.userEmail,
          initialDiningMode: 'dine_in',
        ),
      ),
    );
  }

  void _openTakeawayReservation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TodayMenuScreen(
          userEmail: widget.userEmail,
          initialDiningMode: 'takeaway',
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    final today = _startOfDay(DateTime.now());

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Employee Dashboard',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Welcome: ${widget.userEmail}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Today: ${_weekdayLabel(today)}, ${_formatDate(today)}',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Use this panel to view today’s menu and quickly open the reservation screen.',
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _refreshDashboard,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
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

  Widget _buildQuickAccessCard() {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.restaurant),
            title: const Text('Dine In Reservation'),
            subtitle: const Text('Open meal reservation screen in dine in mode'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 18),
            onTap: _openDineInReservation,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.takeout_dining),
            title: const Text('Takeaway Reservation'),
            subtitle:
                const Text('Open meal reservation screen in takeaway mode'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 18),
            onTap: _openTakeawayReservation,
          ),
        ],
      ),
    );
  }

  Widget _buildMealSection({
    required String title,
    required IconData icon,
    required List<ResolvedMealOption> options,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (options.isEmpty)
              const Text('No menu available for this meal.')
            else
              ...options.map(
                (option) => _DashboardMenuOptionCard(
                  optionLabel: option.optionLabel,
                  optionKey: option.optionKey,
                  itemsSummary: _buildItemsSummary(option),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayMenuCard(DailyResolvedMenu? menu) {
    if (menu == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Today’s Menu Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'No active menu could be resolved for today.',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
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
            padding: const EdgeInsets.all(16),
            child: Wrap(
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Today’s Menu Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cycle: ${menu.cycleName.isEmpty ? 'N/A' : menu.cycleName}',
                    ),
                    const SizedBox(height: 4),
                    Text('Weekday Key: ${menu.weekday}'),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
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
        const SizedBox(height: 12),
        _buildMealSection(
          title: 'Breakfast',
          icon: Icons.free_breakfast_outlined,
          options: menu.breakfastOptions,
        ),
        const SizedBox(height: 12),
        _buildMealSection(
          title: 'Lunch',
          icon: Icons.lunch_dining_outlined,
          options: menu.lunchOptions,
        ),
        const SizedBox(height: 12),
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
      onRefresh: _refreshDashboard,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeaderCard(),
          const SizedBox(height: 12),
          _buildQuickAccessCard(),
          const SizedBox(height: 12),
          FutureBuilder<DailyResolvedMenu?>(
            future: _menuFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Today’s Menu Summary',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Failed to load today’s menu: ${snapshot.error}',
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
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
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              optionLabel,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(itemsSummary),
            const SizedBox(height: 8),
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
