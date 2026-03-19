import 'package:cloud_firestore/cloud_firestore.dart';

class EmployeeIdentityResult {
  final bool found;
  final String reason;
  final String? uid;
  final String? userDocumentId;
  final String? employeeNumber;
  final String? employeeDocumentId;
  final Map<String, dynamic>? userData;
  final Map<String, dynamic>? employeeData;

  const EmployeeIdentityResult({
    required this.found,
    required this.reason,
    this.uid,
    this.userDocumentId,
    this.employeeNumber,
    this.employeeDocumentId,
    this.userData,
    this.employeeData,
  });

  bool get hasUser => userData != null;
  bool get hasEmployeeLink => employeeNumber != null && employeeNumber!.trim().isNotEmpty;
  bool get hasEmployee => employeeData != null;
}

class EmployeeIdentityService {
  EmployeeIdentityService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _employeesRef =>
      _firestore.collection('employees');

  Future<EmployeeIdentityResult> resolveByAuthUid(String authUid) async {
    final normalizedUid = authUid.trim();

    if (normalizedUid.isEmpty) {
      return const EmployeeIdentityResult(
        found: false,
        reason: 'missing_auth_uid',
      );
    }

    final userQuery =
        await _usersRef.where('uid', isEqualTo: normalizedUid).limit(1).get();

    if (userQuery.docs.isEmpty) {
      return EmployeeIdentityResult(
        found: false,
        reason: 'users.uid_not_found',
        uid: normalizedUid,
      );
    }

    final userDoc = userQuery.docs.first;
    final userData = userDoc.data();

    final employeeNumber = (userData['employee_number'] ?? '').toString().trim();

    if (employeeNumber.isEmpty) {
      return EmployeeIdentityResult(
        found: false,
        reason: 'users.employee_number_missing',
        uid: normalizedUid,
        userDocumentId: userDoc.id,
        userData: userData,
      );
    }

    final employeeDoc = await _employeesRef.doc(employeeNumber).get();

    if (!employeeDoc.exists || employeeDoc.data() == null) {
      return EmployeeIdentityResult(
        found: false,
        reason: 'employees.doc_not_found',
        uid: normalizedUid,
        userDocumentId: userDoc.id,
        employeeNumber: employeeNumber,
        userData: userData,
      );
    }

    return EmployeeIdentityResult(
      found: true,
      reason: 'resolved',
      uid: normalizedUid,
      userDocumentId: userDoc.id,
      employeeNumber: employeeNumber,
      employeeDocumentId: employeeDoc.id,
      userData: userData,
      employeeData: employeeDoc.data(),
    );
  }

  Future<Map<String, dynamic>?> getEmployeeByEmployeeNumber(
    String employeeNumber,
  ) async {
    final normalizedEmployeeNumber = employeeNumber.trim();

    if (normalizedEmployeeNumber.isEmpty) {
      return null;
    }

    final employeeDoc = await _employeesRef.doc(normalizedEmployeeNumber).get();

    if (!employeeDoc.exists) {
      return null;
    }

    return employeeDoc.data();
  }

  Future<Map<String, dynamic>?> getUserByUid(String authUid) async {
    final normalizedUid = authUid.trim();

    if (normalizedUid.isEmpty) {
      return null;
    }

    final userQuery =
        await _usersRef.where('uid', isEqualTo: normalizedUid).limit(1).get();

    if (userQuery.docs.isEmpty) {
      return null;
    }

    return userQuery.docs.first.data();
  }
}
