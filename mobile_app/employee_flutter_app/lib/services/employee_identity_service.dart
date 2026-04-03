import 'package:cloud_firestore/cloud_firestore.dart';

class EmployeeIdentityResult {
  final Map<String, dynamic>? employee;
  final Map<String, dynamic>? user;
  final bool exists;

  EmployeeIdentityResult({this.employee, this.user, required this.exists});

  // RESTORE: Validation getters for UserManagementScreen
  bool get userExists => user != null;
  bool get employeeExists => employee != null;
  bool get hasEmployeeLink => user != null && user!['employee_number'] != null;
  bool get employeeIsActive => employee != null && employee!['is_active'] == true;
  bool get userIsActive => user != null && user!['is_active'] == true;
  bool get emailMatches => (user != null && employee != null) && 
                           (user!['email'].toString().toLowerCase() == employee!['email'].toString().toLowerCase());
  
  bool get isBookingEligible => userExists && employeeExists && hasEmployeeLink && employeeIsActive && emailMatches;

  String get linkageStatusLabel => isBookingEligible ? "Linked & Active" : "Incomplete/Blocked";
  
  String get blockingReason {
    if (!userExists) return "No User Profile Found";
    if (!hasEmployeeLink) return "Not Linked to Employee Master";
    if (!employeeExists) return "Employee Number not in Master List";
    if (!employeeIsActive) return "Employee Account is Inactive";
    if (!emailMatches) return "Email Mismatch (Auth vs Master)";
    return "None";
  }

  String? get employeeNumber => user?['employee_number'];
}

class EmployeeIdentityService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> getEmployeeByEmail(String email) async {
    final snap = await _db.collection('employees').where('email', isEqualTo: email).limit(1).get();
    return snap.docs.isNotEmpty ? snap.docs.first.data() : null;
  }

  Future<EmployeeIdentityResult> resolveByAuthUid(String uid) async {
    final userSnap = await _db.collection('users').where('uid', isEqualTo: uid).limit(1).get();
    if (userSnap.docs.isEmpty) return EmployeeIdentityResult(exists: false);

    final userData = userSnap.docs.first.data();
    final empSnap = await _db.collection('employees')
        .where('employee_number', isEqualTo: userData['employee_number'])
        .limit(1).get();

    return EmployeeIdentityResult(
      exists: true,
      user: userData,
      employee: empSnap.docs.isNotEmpty ? empSnap.docs.first.data() : null,
    );
  }
}
