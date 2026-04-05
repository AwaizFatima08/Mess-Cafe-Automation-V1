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
  final Map<String, dynamic>? employeeProfileData;
  final Map<String, dynamic>? employeeMasterData;

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
    this.employeeProfileData,
    this.employeeMasterData,
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

  bool get hasEmployeeProfile => employeeProfileData != null;

  bool get hasEmployeeMaster => employeeMasterData != null;

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

  CollectionReference<Map<String, dynamic>> get _employeeProfilesRef =>
      _firestore.collection('employee_profiles');

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

    final userDoc = await _getUserDocumentByUid(normalizedUid);
    if (userDoc == null) {
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

    final userData = userDoc.data();
    if (userData == null) {
      return EmployeeIdentityResult(
        found: false,
        reason: 'users.data_missing',
        uid: normalizedUid,
        userDocumentId: userDoc.id,
        userExists: false,
        employeeExists: false,
        userIsActive: false,
        employeeIsActive: false,
        emailMatches: false,
        isBookingEligible: false,
        blockingReason: 'User profile record is empty.',
      );
    }

    final employeeNumber = _normalizedString(userData['employee_number']);
    final userIsActive = _resolveUserIsActive(userData);

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

    final employeeProfileDoc =
        await _employeeProfilesRef.doc(employeeNumber).get();
    final employeeMasterDoc = await _employeesRef.doc(employeeNumber).get();

    final Map<String, dynamic>? employeeProfileData =
        employeeProfileDoc.exists ? employeeProfileDoc.data() : null;
    final Map<String, dynamic>? employeeMasterData =
        employeeMasterDoc.exists ? employeeMasterDoc.data() : null;

    final Map<String, dynamic>? effectiveEmployeeData =
        employeeProfileData ?? employeeMasterData;

    if (effectiveEmployeeData == null) {
      return EmployeeIdentityResult(
        found: false,
        reason: 'employee_profiles.doc_not_found',
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
            'Employee profile/master record was not found for this employee number.',
      );
    }

    final employeeIsActive = _resolveEmployeeIsActive(
      employeeProfileData,
      employeeMasterData,
    );

    final emailMatches = _emailsMatch(
      userData['email'],
      employeeProfileData != null
          ? employeeProfileData['email']
          : employeeMasterData != null
              ? employeeMasterData['email']
              : null,
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
      employeeDocumentId:
          employeeProfileDoc.exists ? employeeProfileDoc.id : employeeMasterDoc.id,
      userData: userData,
      employeeData: effectiveEmployeeData,
      employeeProfileData: employeeProfileData,
      employeeMasterData: employeeMasterData,
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

    final employeeProfileDoc =
        await _employeeProfilesRef.doc(normalizedEmployeeNumber).get();
    if (employeeProfileDoc.exists) {
      final data = employeeProfileDoc.data();
      if (data != null) {
        return data;
      }
    }

    final employeeMasterDoc =
        await _employeesRef.doc(normalizedEmployeeNumber).get();
    if (employeeMasterDoc.exists) {
      final data = employeeMasterDoc.data();
      if (data != null) {
        return data;
      }
    }

    return null;
  }

  Future<Map<String, dynamic>?> getEmployeeProfileByEmployeeNumber(
    String employeeNumber,
  ) async {
    final normalizedEmployeeNumber = employeeNumber.trim();

    if (normalizedEmployeeNumber.isEmpty) {
      return null;
    }

    final employeeProfileDoc =
        await _employeeProfilesRef.doc(normalizedEmployeeNumber).get();

    if (!employeeProfileDoc.exists) {
      return null;
    }

    return employeeProfileDoc.data();
  }

  Future<Map<String, dynamic>?> getEmployeeMasterByEmployeeNumber(
    String employeeNumber,
  ) async {
    final normalizedEmployeeNumber = employeeNumber.trim();

    if (normalizedEmployeeNumber.isEmpty) {
      return null;
    }

    final employeeMasterDoc =
        await _employeesRef.doc(normalizedEmployeeNumber).get();

    if (!employeeMasterDoc.exists) {
      return null;
    }

    return employeeMasterDoc.data();
  }

  Future<Map<String, dynamic>?> getUserByUid(String authUid) async {
    final normalizedUid = authUid.trim();

    if (normalizedUid.isEmpty) {
      return null;
    }

    final userDoc = await _getUserDocumentByUid(normalizedUid);
    return userDoc?.data();
  }

  Future<bool> isBookingEligibleForAuthUid(String authUid) async {
    final result = await resolveByAuthUid(authUid);
    return result.isBookingEligible;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _getUserDocumentByUid(
    String uid,
  ) async {
    final directDoc = await _usersRef.doc(uid).get();
    if (directDoc.exists && directDoc.data() != null) {
      return directDoc;
    }

    final userQuery = await _usersRef.where('uid', isEqualTo: uid).limit(1).get();
    if (userQuery.docs.isEmpty) {
      return null;
    }

    return userQuery.docs.first;
  }

  bool _resolveUserIsActive(Map<String, dynamic>? userData) {
    if (userData == null) {
      return false;
    }

    final isActive = userData['is_active'] == true;
    final status = _normalizedString(userData['status']).toLowerCase();

    if (!isActive) {
      return false;
    }

    if (status.isEmpty) {
      return true;
    }

    return status == 'approved' || status == 'active';
  }

  bool _resolveEmployeeIsActive(
    Map<String, dynamic>? employeeProfileData,
    Map<String, dynamic>? employeeMasterData,
  ) {
    if (employeeProfileData != null) {
      return employeeProfileData['is_active'] == true;
    }

    if (employeeMasterData != null) {
      return employeeMasterData['is_active'] == true;
    }

    return false;
  }

  bool _emailsMatch(dynamic userEmailRaw, dynamic employeeEmailRaw) {
    final userEmail = _normalizedString(userEmailRaw).toLowerCase();
    final employeeEmail = _normalizedString(employeeEmailRaw).toLowerCase();

    if (userEmail.isEmpty || employeeEmail.isEmpty) {
      return false;
    }

    return userEmail == employeeEmail;
  }

  String _normalizedString(dynamic value) {
    return (value ?? '').toString().trim();
  }

  String _resolveBlockingReason({
    required bool userIsActive,
    required bool employeeIsActive,
    required bool emailMatches,
  }) {
    if (!userIsActive) {
      return 'User account is inactive or not approved.';
    }

    if (!employeeIsActive) {
      return 'Employee profile/master record is inactive.';
    }

    if (!emailMatches) {
      return 'User email does not match employee profile/master email.';
    }

    return '';
  }
}
