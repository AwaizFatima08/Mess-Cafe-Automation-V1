import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'employee_dashboard_screen.dart'; // Keep this
import '../../services/employee_identity_service.dart';

class EmployeeDashboardShell extends StatefulWidget {
  const EmployeeDashboardShell({super.key});

  @override
  State<EmployeeDashboardShell> createState() => _EmployeeDashboardShellState();
}

class _EmployeeDashboardShellState extends State<EmployeeDashboardShell> {
  final EmployeeIdentityService _identityService = EmployeeIdentityService();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return FutureBuilder<EmployeeIdentityResult>(
      future: _identityService.resolveByAuthUid(user?.uid ?? ''),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        final result = snapshot.data;
        if (result == null || !result.exists) {
          return const Scaffold(body: Center(child: Text("Identity Verification Failed")));
        }

        return EmployeeDashboardScreen(
          userEmail: user?.email ?? '',
          userUid: user?.uid ?? '',
          employeeName: result.employee?['full_name'] ?? 'FFL User',
          employeeNumber: result.employee?['employee_number'] ?? 'N/A',
        );
      },
    );
  }
}
