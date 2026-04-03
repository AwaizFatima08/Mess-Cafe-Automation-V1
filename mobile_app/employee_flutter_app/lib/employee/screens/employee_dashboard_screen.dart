import 'package:flutter/material.dart';
import 'today_menu_screen.dart';

class EmployeeDashboardScreen extends StatefulWidget {
  final String userEmail;
  final String userUid;
  final String employeeName;
  final String employeeNumber;

  const EmployeeDashboardScreen({
    super.key,
    required this.userEmail,
    required this.userUid,
    required this.employeeName,
    required this.employeeNumber,
  });

  @override
  State<EmployeeDashboardScreen> createState() => _EmployeeDashboardScreenState();
}

class _EmployeeDashboardScreenState extends State<EmployeeDashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _selectedIndex == 0 
          ? TodayMenuScreen(
              userEmail: widget.userEmail,
              userUid: widget.userUid,
              employeeName: widget.employeeName,
              employeeNumber: widget.employeeNumber,
            ) 
          : const Center(child: Text("History Screen")),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.restaurant), label: 'Meals'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
        ],
      ),
    );
  }
}
