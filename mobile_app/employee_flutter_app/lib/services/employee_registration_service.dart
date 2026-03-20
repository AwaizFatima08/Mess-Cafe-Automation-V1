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
  }) async {
    final normalizedEmployeeNumber = employeeNumber.trim().toUpperCase();
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedFullName = fullName.trim();
    final normalizedCnicLast4 = cnicLast4.trim();
    final normalizedRole = role.trim().toLowerCase();

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

    final employeeDoc = await _employeesRef.doc(normalizedEmployeeNumber).get();

    if (!employeeDoc.exists || employeeDoc.data() == null) {
      return const RegistrationResult(
        success: false,
        message: 'Employee record not found.',
      );
    }

    final employeeData = employeeDoc.data()!;
    final employeeName =
        (employeeData['name'] ?? employeeData['employee_name'] ?? '')
            .toString()
            .trim();

    final employeeEmail =
        (employeeData['email'] ?? '').toString().trim().toLowerCase();

    final employeeCnicLast4 =
        (employeeData['cnic_last_4'] ?? '').toString().trim();

    final employeeIsActive = employeeData['is_active'] == true;

    if (!employeeIsActive) {
      return const RegistrationResult(
        success: false,
        message: 'Employee record is inactive.',
      );
    }

    if (employeeEmail.isEmpty) {
      return const RegistrationResult(
        success: false,
        message:
            'Official email is missing in employee master record. Contact admin.',
      );
    }

    if (employeeEmail != normalizedEmail) {
      return const RegistrationResult(
        success: false,
        message: 'Email does not match official employee record.',
      );
    }

    if (employeeCnicLast4.isNotEmpty &&
        employeeCnicLast4 != normalizedCnicLast4) {
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
      return const RegistrationResult(
        success: false,
        message: 'A user account already exists for this employee number.',
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

    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: normalizedEmail,
      password: password,
    );

    final uid = userCredential.user?.uid;
    if (uid == null || uid.trim().isEmpty) {
      return const RegistrationResult(
        success: false,
        message: 'User account created but UID is missing.',
      );
    }

    final now = FieldValue.serverTimestamp();
    final effectiveStatus = requireApproval ? 'pending' : 'approved';
    final isActive = !requireApproval;

    await _usersRef.doc(uid).set({
      'uid': uid,
      'email': normalizedEmail,
      'employee_number': normalizedEmployeeNumber,
      'employee_name': employeeName.isNotEmpty ? employeeName : normalizedFullName,
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
        'employee_name': employeeName.isNotEmpty ? employeeName : normalizedFullName,
        'email': normalizedEmail,
        'role': normalizedRole,
        'status': 'pending',
        'requested_at': now,
        'created_at': now,
        'updated_at': now,
      });
    }

    await _auth.signOut();

    return RegistrationResult(
      success: true,
      message: requireApproval
          ? 'Registration submitted successfully and is pending approval.'
          : 'Registration completed successfully.',
      uid: uid,
      employeeNumber: normalizedEmployeeNumber,
      requestId: requestId,
    );
  }
}
