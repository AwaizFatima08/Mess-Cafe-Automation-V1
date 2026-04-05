import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegistrationResult {
  final bool success;
  final String message;
  final String? uid;
  final String? employeeNumber;
  final String? requestId;

  const RegistrationResult({
    required this.success,
    required this.message,
    this.uid,
    this.employeeNumber,
    this.requestId,
  });
}

class EmployeeRegistrationService {
  EmployeeRegistrationService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _employeesRef =>
      _firestore.collection('employees');

  CollectionReference<Map<String, dynamic>> get _employeeProfilesRef =>
      _firestore.collection('employee_profiles');

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _registrationRequestsRef =>
      _firestore.collection('registration_requests');

  Future<RegistrationResult> registerEmployee({
    required String employeeNumber,
    required String email,
    required String password,
    required String fullName,
    required String cnicLast4,
    String role = 'employee',
    bool requireApproval = true,
    bool selfRegistrationEnabled = true,
  }) async {
    final normalizedEmployeeNumber = employeeNumber.trim().toUpperCase();
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPassword = password.trim();
    final normalizedFullName = fullName.trim();
    final normalizedCnicLast4 = cnicLast4.trim();
    final normalizedRole = role.trim().toLowerCase();

    if (!selfRegistrationEnabled) {
      return const RegistrationResult(
        success: false,
        message:
            'Self-registration is currently disabled. Please contact admin.',
      );
    }

    if (normalizedEmployeeNumber.isEmpty) {
      return const RegistrationResult(
        success: false,
        message: 'Employee number is required.',
      );
    }

    if (normalizedEmail.isEmpty) {
      return const RegistrationResult(
        success: false,
        message: 'Email is required.',
      );
    }

    if (normalizedPassword.isEmpty) {
      return const RegistrationResult(
        success: false,
        message: 'Password is required.',
      );
    }

    if (normalizedPassword.length < 6) {
      return const RegistrationResult(
        success: false,
        message: 'Password must be at least 6 characters long.',
      );
    }

    if (normalizedFullName.isEmpty) {
      return const RegistrationResult(
        success: false,
        message: 'Full name is required.',
      );
    }

    if (normalizedCnicLast4.isEmpty || normalizedCnicLast4.length != 4) {
      return const RegistrationResult(
        success: false,
        message: 'CNIC last 4 digits are required.',
      );
    }

    if (!_isAllowedSelfRegistrationRole(normalizedRole)) {
      return const RegistrationResult(
        success: false,
        message: 'Invalid role for self-registration.',
      );
    }

    try {
      final employeeContext =
          await _loadEmployeeContext(normalizedEmployeeNumber);

      if (!employeeContext.exists) {
        return const RegistrationResult(
          success: false,
          message: 'Employee master/profile record not found.',
        );
      }

      if (!employeeContext.isActive) {
        return const RegistrationResult(
          success: false,
          message: 'Employee master/profile record is inactive.',
        );
      }

      if (employeeContext.officialEmail.isEmpty) {
        return const RegistrationResult(
          success: false,
          message:
              'Official email is missing in employee master/profile record. Contact admin.',
        );
      }

      if (employeeContext.officialEmail != normalizedEmail) {
        return const RegistrationResult(
          success: false,
          message: 'Email does not match official employee record.',
        );
      }

      if (employeeContext.officialCnicLast4.isEmpty) {
        return const RegistrationResult(
          success: false,
          message:
              'CNIC last 4 digits are missing in employee master/profile record. Contact admin.',
        );
      }

      if (employeeContext.officialCnicLast4 != normalizedCnicLast4) {
        return const RegistrationResult(
          success: false,
          message: 'CNIC last 4 digits do not match employee record.',
        );
      }

      final existingUserByEmployee = await _usersRef
          .where('employee_number', isEqualTo: normalizedEmployeeNumber)
          .limit(1)
          .get();

      if (existingUserByEmployee.docs.isNotEmpty) {
        final existingData = existingUserByEmployee.docs.first.data();
        final existingIsActive = existingData['is_active'] == true;
        final existingStatus = _normalizedString(existingData['status'])
            .toLowerCase();

        if (existingIsActive || existingStatus == 'approved') {
          return const RegistrationResult(
            success: false,
            message:
                'An approved user account already exists for this employee.',
          );
        }

        return const RegistrationResult(
          success: false,
          message:
              'A user account already exists for this employee and is awaiting admin action.',
        );
      }

      final existingUserByEmail = await _usersRef
          .where('email', isEqualTo: normalizedEmail)
          .limit(1)
          .get();

      if (existingUserByEmail.docs.isNotEmpty) {
        return const RegistrationResult(
          success: false,
          message: 'A user account already exists for this email.',
        );
      }

      final existingPendingRequest = await _registrationRequestsRef
          .where('employee_number', isEqualTo: normalizedEmployeeNumber)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (existingPendingRequest.docs.isNotEmpty) {
        return const RegistrationResult(
          success: false,
          message: 'A registration request is already pending approval.',
        );
      }

      UserCredential userCredential;
      try {
        userCredential = await _auth.createUserWithEmailAndPassword(
          email: normalizedEmail,
          password: normalizedPassword,
        );
      } on FirebaseAuthException catch (e) {
        return RegistrationResult(
          success: false,
          message: _firebaseAuthErrorMessage(e),
        );
      }

      final uid = userCredential.user?.uid;
      if (uid == null || uid.trim().isEmpty) {
        await _safeDeleteCurrentAuthUser();
        return const RegistrationResult(
          success: false,
          message: 'User account created but UID is missing.',
        );
      }

      final effectiveEmployeeName = employeeContext.officialName.isNotEmpty
          ? employeeContext.officialName
          : normalizedFullName;

      final now = FieldValue.serverTimestamp();
      final effectiveStatus = requireApproval ? 'pending' : 'approved';
      final isActive = !requireApproval;

      try {
        await _usersRef.doc(uid).set({
          'uid': uid,
          'email': normalizedEmail,
          'employee_number': normalizedEmployeeNumber,
          'employee_name': effectiveEmployeeName,
          'display_name': effectiveEmployeeName,
          'role': normalizedRole,
          'is_active': isActive,
          'status': effectiveStatus,
          'created_at': now,
          'updated_at': now,
        });

        String? requestId;

        if (requireApproval) {
          final requestRef = _registrationRequestsRef.doc();
          requestId = requestRef.id;

          await requestRef.set({
            'request_id': requestId,
            'uid': uid,
            'employee_number': normalizedEmployeeNumber,
            'employee_name': effectiveEmployeeName,
            'display_name': effectiveEmployeeName,
            'email': normalizedEmail,
            'role': normalizedRole,
            'status': 'pending',
            'requested_at': now,
            'created_at': now,
            'updated_at': now,
          });

          await _auth.signOut();

          return RegistrationResult(
            success: true,
            message:
                'Registration submitted successfully and is pending admin approval.',
            uid: uid,
            employeeNumber: normalizedEmployeeNumber,
            requestId: requestId,
          );
        }

        await _upsertApprovedEmployeeProfile(
          uid: uid,
          employeeNumber: normalizedEmployeeNumber,
          email: normalizedEmail,
          displayName: effectiveEmployeeName,
          sourceProfileData: employeeContext.profileData,
          sourceMasterData: employeeContext.masterData,
        );

        await _auth.signOut();

        return RegistrationResult(
          success: true,
          message: 'Registration completed successfully.',
          uid: uid,
          employeeNumber: normalizedEmployeeNumber,
        );
      } catch (e) {
        await _safeDeleteCurrentAuthUser();

        return RegistrationResult(
          success: false,
          message:
              'Registration could not be completed because profile records failed to save: $e',
        );
      }
    } catch (e) {
      return RegistrationResult(
        success: false,
        message: 'Registration failed: $e',
      );
    }
  }

  bool _isAllowedSelfRegistrationRole(String role) {
    return role == 'employee';
  }

  Future<_EmployeeRegistrationContext> _loadEmployeeContext(
    String employeeNumber,
  ) async {
    final profileDoc = await _employeeProfilesRef.doc(employeeNumber).get();
    final masterDoc = await _employeesRef.doc(employeeNumber).get();

    final profileData = profileDoc.exists ? profileDoc.data() : null;
    final masterData = masterDoc.exists ? masterDoc.data() : null;

    final exists = profileData != null || masterData != null;

    final officialName = _pickFirstNonEmpty([
      profileData?['display_name'],
      profileData?['employee_name'],
      profileData?['name'],
      masterData?['employee_name'],
      masterData?['name'],
      masterData?['full_name'],
    ]);

    final officialEmail = _pickFirstNonEmpty([
      profileData?['email'],
      masterData?['email'],
    ]).toLowerCase();

    final officialCnicLast4 = _pickFirstNonEmpty([
      profileData?['cnic_last_4'],
      masterData?['cnic_last_4'],
    ]);

    final isActive = _resolveEmployeeIsActive(profileData, masterData);

    return _EmployeeRegistrationContext(
      exists: exists,
      isActive: isActive,
      officialName: officialName,
      officialEmail: officialEmail,
      officialCnicLast4: officialCnicLast4,
      profileData: profileData,
      masterData: masterData,
    );
  }

  Future<void> _upsertApprovedEmployeeProfile({
    required String uid,
    required String employeeNumber,
    required String email,
    required String displayName,
    Map<String, dynamic>? sourceProfileData,
    Map<String, dynamic>? sourceMasterData,
  }) async {
    final now = FieldValue.serverTimestamp();

    final existingProfileDoc = await _employeeProfilesRef.doc(employeeNumber).get();
    final existingProfileData =
        existingProfileDoc.exists ? existingProfileDoc.data() : null;

    final mergedFamilyMembers =
        existingProfileData?['family_members'] ??
            sourceProfileData?['family_members'] ??
            <dynamic>[];

    final houseNumber = _pickFirstNonEmpty([
      existingProfileData?['house_number'],
      sourceProfileData?['house_number'],
      sourceMasterData?['house_number'],
    ]);

    final phoneNumber = _pickFirstNonEmpty([
      existingProfileData?['phone_number'],
      sourceProfileData?['phone_number'],
      sourceMasterData?['phone_number'],
    ]);

    await _employeeProfilesRef.doc(employeeNumber).set({
      'employee_number': employeeNumber,
      'uid': uid,
      'display_name': displayName,
      'employee_name': displayName,
      'email': email,
      'phone_number': phoneNumber,
      'house_number': houseNumber,
      'is_active': true,
      'family_members': mergedFamilyMembers,
      'updated_at': now,
      if (!existingProfileDoc.exists) 'created_at': now,
    }, SetOptions(merge: true));
  }

  bool _resolveEmployeeIsActive(
    Map<String, dynamic>? profileData,
    Map<String, dynamic>? masterData,
  ) {
    if (profileData != null) {
      return profileData['is_active'] == true;
    }

    if (masterData != null) {
      return masterData['is_active'] == true;
    }

    return false;
  }

  String _pickFirstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final normalized = _normalizedString(value);
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return '';
  }

  String _normalizedString(dynamic value) {
    return (value ?? '').toString().trim();
  }

  String _firebaseAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already in use.';
      case 'invalid-email':
        return 'Email address is invalid.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'operation-not-allowed':
        return 'Email/password sign-up is not enabled.';
      case 'network-request-failed':
        return 'Network error occurred during registration.';
      default:
        return e.message ?? 'Authentication error occurred during registration.';
    }
  }

  Future<void> _safeDeleteCurrentAuthUser() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser != null) {
        await currentUser.delete();
      }
    } catch (_) {
      // Intentionally ignored to avoid masking the primary failure.
    } finally {
      try {
        await _auth.signOut();
      } catch (_) {
        // Intentionally ignored.
      }
    }
  }
}

class _EmployeeRegistrationContext {
  final bool exists;
  final bool isActive;
  final String officialName;
  final String officialEmail;
  final String officialCnicLast4;
  final Map<String, dynamic>? profileData;
  final Map<String, dynamic>? masterData;

  const _EmployeeRegistrationContext({
    required this.exists,
    required this.isActive,
    required this.officialName,
    required this.officialEmail,
    required this.officialCnicLast4,
    required this.profileData,
    required this.masterData,
  });
}
