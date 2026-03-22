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

  final bool userExists;
  final bool employeeExists;
  final bool userIsActive;
  final bool employeeIsActive;
  final bool emailMatches;
  final bool isBookingEligible;
  final String blockingReason;

  const EmployeeIdentityResult({
    required this.found,
    required this.reason,
    this.uid,
    this.userDocumentId,
    this.employeeNumber,
    this.employeeDocumentId,
    this.userData,
    this.employeeData,
    required this.userExists,
    required this.employeeExists,
    required this.userIsActive,
    required this.employeeIsActive,
    required this.emailMatches,
    required this.isBookingEligible,
    required this.blockingReason,
  });

  bool get hasUser => userData != null;

  bool get hasEmployeeLink =>
      employeeNumber != null && employeeNumber!.trim().isNotEmpty;

  bool get hasEmployee => employeeData != null;

  String get linkageStatusLabel {
    if (isBookingEligible) {
      return 'Eligible';
    }

    if (!userExists) {
      return 'User Missing';
    }

    if (!hasEmployeeLink) {
      return 'Employee Number Missing';
    }

    if (!employeeExists) {
      return 'Employee Record Missing';
    }

    if (!userIsActive) {
      return 'User Inactive';
    }

    if (!employeeIsActive) {
      return 'Employee Inactive';
    }

    if (!emailMatches) {
      return 'Email Mismatch';
    }

    return 'Blocked';
  }
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
        userExists: false,
        employeeExists: false,
        userIsActive: false,
        employeeIsActive: false,
        emailMatches: false,
        isBookingEligible: false,
        blockingReason: 'Authentication UID is missing.',
      );
    }

    final userQuery =
        await _usersRef.where('uid', isEqualTo: normalizedUid).limit(1).get();

    if (userQuery.docs.isEmpty) {
      return EmployeeIdentityResult(
        found: false,
        reason: 'users.uid_not_found',
        uid: normalizedUid,
        userExists: false,
        employeeExists: false,
        userIsActive: false,
        employeeIsActive: false,
        emailMatches: false,
        isBookingEligible: false,
        blockingReason: 'User profile record was not found.',
      );
    }

    final userDoc = userQuery.docs.first;
    final userData = userDoc.data();

    final employeeNumber = (userData['employee_number'] ?? '').toString().trim();
    final userIsActive = userData['is_active'] == true;

    if (employeeNumber.isEmpty) {
      return EmployeeIdentityResult(
        found: false,
        reason: 'users.employee_number_missing',
        uid: normalizedUid,
        userDocumentId: userDoc.id,
        userData: userData,
        userExists: true,
        employeeExists: false,
        userIsActive: userIsActive,
        employeeIsActive: false,
        emailMatches: false,
        isBookingEligible: false,
        blockingReason:
            'User profile exists but employee number is missing.',
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
        userExists: true,
        employeeExists: false,
        userIsActive: userIsActive,
        employeeIsActive: false,
        emailMatches: false,
        isBookingEligible: false,
        blockingReason:
            'Employee master record was not found for this employee number.',
      );
    }

    final employeeData = employeeDoc.data()!;
    final employeeIsActive = employeeData['is_active'] == true;
    final emailMatches = _emailsMatch(
      userData['email'],
      employeeData['email'],
    );

    final blockingReason = _resolveBlockingReason(
      userIsActive: userIsActive,
      employeeIsActive: employeeIsActive,
      emailMatches: emailMatches,
    );

    final isBookingEligible = blockingReason.isEmpty;

    return EmployeeIdentityResult(
      found: isBookingEligible,
      reason: isBookingEligible ? 'resolved' : 'resolved_but_blocked',
      uid: normalizedUid,
      userDocumentId: userDoc.id,
      employeeNumber: employeeNumber,
      employeeDocumentId: employeeDoc.id,
      userData: userData,
      employeeData: employeeData,
      userExists: true,
      employeeExists: true,
      userIsActive: userIsActive,
      employeeIsActive: employeeIsActive,
      emailMatches: emailMatches,
      isBookingEligible: isBookingEligible,
      blockingReason: blockingReason,
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

  Future<bool> isBookingEligibleForAuthUid(String authUid) async {
    final result = await resolveByAuthUid(authUid);
    return result.isBookingEligible;
  }

  bool _emailsMatch(dynamic userEmailRaw, dynamic employeeEmailRaw) {
    final userEmail = (userEmailRaw ?? '').toString().trim().toLowerCase();
    final employeeEmail =
        (employeeEmailRaw ?? '').toString().trim().toLowerCase();

    if (userEmail.isEmpty || employeeEmail.isEmpty) {
      return false;
    }

    return userEmail == employeeEmail;
  }

  String _resolveBlockingReason({
    required bool userIsActive,
    required bool employeeIsActive,
    required bool emailMatches,
  }) {
    if (!userIsActive) {
      return 'User account is inactive.';
    }

    if (!employeeIsActive) {
      return 'Employee master record is inactive.';
    }

    if (!emailMatches) {
      return 'User email does not match employee master email.';
    }

    return '';
  }
}
