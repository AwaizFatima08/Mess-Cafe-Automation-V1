import 'package:flutter/material.dart';
import '../../services/menu_resolver_service.dart';
import '../../core/theme/app_theme.dart';
import '../../services/meal_reservation_service.dart';

class TodayMenuScreen extends StatefulWidget {
  final String userEmail;
  final String userUid;
  final String employeeName;
  final String employeeNumber;

  const TodayMenuScreen({
    super.key,
    required this.userEmail,
    required this.userUid,
    required this.employeeName,
    required this.employeeNumber,
  });

  @override
  State<TodayMenuScreen> createState() => _TodayMenuScreenState();
}

class _TodayMenuScreenState extends State<TodayMenuScreen> {
  final MenuResolverService _menuResolverService = MenuResolverService();
  final MealReservationService _mealReservationService = MealReservationService();
  final DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: _getInitialTabIndex(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('FFL Menu'),
          bottom: const TabBar(
            tabs: [Tab(text: "Breakfast"), Tab(text: "Lunch"), Tab(text: "Dinner")],
          ),
        ),
        body: TabBarView(
          children: [
            _buildLazyMealSection('breakfast'),
            _buildLazyMealSection('lunch'),
            _buildLazyMealSection('dinner'),
          ],
        ),
      ),
    );
  }

  int _getInitialTabIndex() {
    final hour = DateTime.now().hour;
    if (hour < 10) return 0; 
    if (hour < 15) return 1; 
    return 2; 
  }

  Widget _buildLazyMealSection(String mealType) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeroCard(),
        const SizedBox(height: 16),
        FutureBuilder<Map<String, dynamic>?>(
          future: _menuResolverService.getMenuForDate(_selectedDate, mealType: mealType),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            final data = snapshot.data;
            final hasMenu = data != null && data.containsKey(mealType.toLowerCase()) && (data[mealType.toLowerCase()] as List).isNotEmpty;
            return _buildMealCard(mealType, hasMenu, data?[mealType.toLowerCase()] ?? []);
          },
        ),
      ],
    );
  }

  Widget _buildMealCard(String mealType, bool hasMenu, List<dynamic> options) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _mealReservationService.getFilteredReservations(
        date: _selectedDate, 
        mealType: mealType,
        employeeNumber: widget.employeeNumber,
      ),
      builder: (context, resSnapshot) {
        final reservations = resSnapshot.data ?? [];
        final hasReservation = reservations.isNotEmpty;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mealType.toUpperCase(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                if (hasReservation) 
                   _buildExistingReservationInfo(reservations.first)
                else if (!hasMenu)
                  const Text("Menu not published.")
                else
                  ...options.map((opt) => ListTile(title: Text(opt['menu_item_name']))).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExistingReservationInfo(Map<String, dynamic> res) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text("Reserved: ${res['menu_item_name']}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.employeeName.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          Text("ID: ${widget.employeeNumber}", style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}
