import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EmployeeRegistrationService {
  EmployeeRegistrationService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _employeesRef =>
      _firestore.collection('employees');

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _registrationRequestsRef =>
      _firestore.collection('registration_requests');

  Future<String> registerEmployee({
    required String employeeNo,
    required String fullName,
    required String phone,
    required String cnicLast4,
    required String email,
    required String password,
  }) async {
    final normalizedEmployeeNo = employeeNo.trim().toUpperCase();
    final normalizedFullName = _normalizeText(fullName);
    final normalizedPhone = _normalizePhone(phone);
    final normalizedCnicLast4 = _normalizeDigits(cnicLast4);
    final normalizedEmail = email.trim().toLowerCase();

    if (normalizedEmployeeNo.isEmpty) {
      throw Exception('Employee number is required.');
    }

    if (normalizedFullName.isEmpty) {
      throw Exception('Full name is required.');
    }

    if (normalizedPhone.length < 11) {
      throw Exception('A valid phone number is required.');
    }

    if (normalizedCnicLast4.length != 4) {
      throw Exception('CNIC last 4 digits must be exactly 4 digits.');
    }

    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
      throw Exception('A valid email address is required.');
    }

    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }

    final existingUserByEmployee = await _usersRef
        .where('employee_no', isEqualTo: normalizedEmployeeNo)
        .limit(1)
        .get();

    if (existingUserByEmployee.docs.isNotEmpty) {
      throw Exception(
        'An account is already linked with this employee number.',
      );
    }

    final existingUserByEmail =
        await _usersRef.where('email', isEqualTo: normalizedEmail).limit(1).get();

    if (existingUserByEmail.docs.isNotEmpty) {
      throw Exception('An account already exists with this email address.');
    }

    final employeeDoc =
        await _findEmployeeDocumentByEmployeeNo(normalizedEmployeeNo);

    if (employeeDoc == null) {
      await _createRegistrationRequest(
        employeeNo: normalizedEmployeeNo,
        fullName: fullName.trim(),
        phone: normalizedPhone,
        cnicLast4: normalizedCnicLast4,
        email: normalizedEmail,
        matchedEmployee: false,
      );
      return 'requested';
    }

    final employeeData = employeeDoc.data();

    final storedEmployeeNo = _readString(employeeData, [
      'employee_no',
      'employee_number',
      'emp_no',
      'emp_code',
      'code',
    ]).toUpperCase();

    final storedName = _normalizeText(_readString(employeeData, [
      'full_name',
      'employee_name',
      'name',
      'display_name',
    ]));

    final storedPhone = _normalizePhone(_readString(employeeData, [
      'phone_number',
      'phone',
      'mobile_number',
      'mobile',
      'contact_number',
    ]));

    final storedCnicLast4 = _extractLast4Digits(_readString(employeeData, [
      'cnic_last4',
      'cnic_last_4',
      'cnic',
      'cnic_number',
      'national_id',
    ]));

    final employeeNoMatches = storedEmployeeNo == normalizedEmployeeNo;
    final nameMatches = storedName.isNotEmpty && storedName == normalizedFullName;
    final phoneMatches =
        storedPhone.isNotEmpty && storedPhone == normalizedPhone;
    final cnicMatches =
        storedCnicLast4.isNotEmpty && storedCnicLast4 == normalizedCnicLast4;

    final fullyMatched =
        employeeNoMatches && nameMatches && phoneMatches && cnicMatches;

    if (!fullyMatched) {
      await _createRegistrationRequest(
        employeeNo: normalizedEmployeeNo,
        fullName: fullName.trim(),
        phone: normalizedPhone,
        cnicLast4: normalizedCnicLast4,
        email: normalizedEmail,
        matchedEmployee: true,
      );
      return 'requested';
    }

    UserCredential credential;

    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_authErrorMessage(e));
    }

    final user = credential.user;
    if (user == null) {
      throw Exception('Failed to create authentication account.');
    }

    final displayName = _readString(employeeData, [
      'full_name',
      'employee_name',
      'name',
      'display_name',
    ]).trim();

    await _usersRef.doc(user.uid).set({
      'uid': user.uid,
      'email': normalizedEmail,
      'display_name': displayName.isNotEmpty ? displayName : fullName.trim(),
      'employee_no': normalizedEmployeeNo,
      'role': 'employee',
      'status': 'active',
      'created_at': FieldValue.serverTimestamp(),
    });

    await _auth.signOut();

    return 'created';
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?>
      _findEmployeeDocumentByEmployeeNo(String employeeNo) async {
    final primaryQuery = await _employeesRef
        .where('employee_no', isEqualTo: employeeNo)
        .limit(1)
        .get();

    if (primaryQuery.docs.isNotEmpty) {
      return primaryQuery.docs.first;
    }

    final secondaryQuery = await _employeesRef
        .where('employee_number', isEqualTo: employeeNo)
        .limit(1)
        .get();

    if (secondaryQuery.docs.isNotEmpty) {
      return secondaryQuery.docs.first;
    }

    final tertiaryQuery =
        await _employeesRef.where('emp_no', isEqualTo: employeeNo).limit(1).get();

    if (tertiaryQuery.docs.isNotEmpty) {
      return tertiaryQuery.docs.first;
    }

    return null;
  }

  Future<void> _createRegistrationRequest({
    required String employeeNo,
    required String fullName,
    required String phone,
    required String cnicLast4,
    required String email,
    required bool matchedEmployee,
  }) async {
    final existingPending = await _registrationRequestsRef
        .where('employee_no', isEqualTo: employeeNo)
        .where('request_status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (existingPending.docs.isNotEmpty) {
      throw Exception(
        'A pending registration request already exists for this employee number.',
      );
    }

    await _registrationRequestsRef.add({
      'full_name': fullName,
      'employee_no': employeeNo,
      'phone_number': phone,
      'cnic_last4': cnicLast4,
      'email': email,
      'requested_role': 'employee',
      'request_status': 'pending',
      'matched_employee': matchedEmployee,
      'submitted_at': FieldValue.serverTimestamp(),
      'reviewed_by': '',
      'decision_notes': '',
    });
  }

  String _readString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value != null) {
        final text = value.toString().trim();
        if (text.isNotEmpty) {
          return text;
        }
      }
    }
    return '';
  }

  String _normalizeText(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  String _normalizePhone(String value) {
    final digits = _normalizeDigits(value);

    if (digits.length == 11) {
      return digits;
    }

    if (digits.length > 11) {
      return digits.substring(digits.length - 11);
    }

    return digits;
  }

  String _normalizeDigits(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String _extractLast4Digits(String value) {
    final digits = _normalizeDigits(value);
    if (digits.length >= 4) {
      return digits.substring(digits.length - 4);
    }
    return digits;
  }

  String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An authentication account already exists with this email.';
      case 'invalid-email':
        return 'The email address format is invalid.';
      case 'weak-password':
        return 'The password is too weak.';
      case 'operation-not-allowed':
        return 'Email/password sign-up is not enabled in Firebase Authentication.';
      default:
        return e.message ?? 'Authentication account creation failed.';
    }
  }
}
