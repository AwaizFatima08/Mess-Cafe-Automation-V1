import 'package:cloud_firestore/cloud_firestore.dart';

class EmployeeIdentity {
  final String documentId;
  final String employeeNumber;
  final String name;
  final String prefix;
  final String department;
  final String designation;
  final String userRole;

  const EmployeeIdentity({
    required this.documentId,
    required this.employeeNumber,
    required this.name,
    required this.prefix,
    required this.department,
    required this.designation,
    required this.userRole,
  });

  String get displayEmployeeCode {
    if (prefix.trim().isEmpty) {
      return employeeNumber;
    }
    return '$prefix-$employeeNumber';
  }
}

class EmployeeIdentityService {
  EmployeeIdentityService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _employeesRef =>
      _firestore.collection('employees');

  Future<EmployeeIdentity?> resolveForCurrentUser({
    required String userEmail,
    String? authUid,
  }) async {
    final normalizedEmail = userEmail.trim();
    final normalizedLowerEmail = normalizedEmail.toLowerCase();
    final normalizedUid = authUid?.trim() ?? '';

    const emailFields = [
      'email',
      'user_email',
      'official_email',
      'personal_email',
      'login_email',
    ];

    for (final field in emailFields) {
      final byExactEmail = await _employeesRef
          .where(field, isEqualTo: normalizedEmail)
          .limit(1)
          .get();

      final exactMatch = _readIdentityFromQuery(byExactEmail);
      if (exactMatch != null) {
        return exactMatch;
      }

      final byLowerEmail = await _employeesRef
          .where(field, isEqualTo: normalizedLowerEmail)
          .limit(1)
          .get();

      final lowerMatch = _readIdentityFromQuery(byLowerEmail);
      if (lowerMatch != null) {
        return lowerMatch;
      }
    }

    if (normalizedUid.isNotEmpty) {
      const uidFields = [
        'auth_uid',
        'uid',
        'user_id',
      ];

      for (final field in uidFields) {
        final byUid = await _employeesRef
            .where(field, isEqualTo: normalizedUid)
            .limit(1)
            .get();

        final uidMatch = _readIdentityFromQuery(byUid);
        if (uidMatch != null) {
          return uidMatch;
        }
      }
    }

    return null;
  }

  EmployeeIdentity? _readIdentityFromQuery(
    QuerySnapshot<Map<String, dynamic>> query,
  ) {
    if (query.docs.isEmpty) {
      return null;
    }

    final doc = query.docs.first;
    final data = doc.data();

    final employeeNumber = (data['employee_number'] ?? '').toString().trim();
    final name = (data['name'] ?? '').toString().trim();

    if (employeeNumber.isEmpty && name.isEmpty) {
      return null;
    }

    return EmployeeIdentity(
      documentId: doc.id,
      employeeNumber: employeeNumber,
      name: name,
      prefix: (data['prefix'] ?? '').toString().trim(),
      department: (data['department'] ?? '').toString().trim(),
      designation: (data['designation'] ?? '').toString().trim(),
      userRole: (data['user_role'] ?? '').toString().trim(),
    );
  }
}
