import 'package:cloud_firestore/cloud_firestore.dart';

enum AppUserRole {
  developer,
  admin,
  messManager,
  messSupervisor,
  employee,
  unknown,
}

class AppUserProfile {
  final String documentId;
  final String authUid;
  final String email;
  final AppUserRole role;
  final String employeeNumber;
  final String employeeName;
  final bool isActive;
  final Map<String, dynamic> rawData;

  const AppUserProfile({
    required this.documentId,
    required this.authUid,
    required this.email,
    required this.role,
    required this.employeeNumber,
    required this.employeeName,
    required this.isActive,
    required this.rawData,
  });

  bool get hasEmployeeLink => employeeNumber.trim().isNotEmpty;

  String get roleLabel {
    switch (role) {
      case AppUserRole.developer:
        return 'developer';
      case AppUserRole.admin:
        return 'admin';
      case AppUserRole.messManager:
        return 'mess_manager';
      case AppUserRole.messSupervisor:
        return 'mess_supervisor';
      case AppUserRole.employee:
        return 'employee';
      case AppUserRole.unknown:
        return 'unknown';
    }
  }
}

class UserProfileService {
  UserProfileService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  Future<AppUserProfile?> resolveCurrentUserProfile({
    required String userEmail,
    String? authUid,
  }) async {
    final normalizedEmail = userEmail.trim();
    final normalizedLowerEmail = normalizedEmail.toLowerCase();
    final normalizedUid = authUid?.trim() ?? '';

    if (normalizedUid.isNotEmpty) {
      const uidFields = [
        'auth_uid',
        'uid',
        'user_id',
      ];

      for (final field in uidFields) {
        final query = await _usersRef
            .where(field, isEqualTo: normalizedUid)
            .limit(1)
            .get();

        final profile = _readProfileFromQuery(query);
        if (profile != null) {
          return profile;
        }
      }
    }

    const emailFields = [
      'email',
      'user_email',
      'official_email',
      'personal_email',
      'login_email',
    ];

    for (final field in emailFields) {
      final exactQuery = await _usersRef
          .where(field, isEqualTo: normalizedEmail)
          .limit(1)
          .get();

      final exactProfile = _readProfileFromQuery(exactQuery);
      if (exactProfile != null) {
        return exactProfile;
      }

      final lowerQuery = await _usersRef
          .where(field, isEqualTo: normalizedLowerEmail)
          .limit(1)
          .get();

      final lowerProfile = _readProfileFromQuery(lowerQuery);
      if (lowerProfile != null) {
        return lowerProfile;
      }
    }

    return null;
  }

  AppUserProfile? _readProfileFromQuery(
    QuerySnapshot<Map<String, dynamic>> query,
  ) {
    if (query.docs.isEmpty) {
      return null;
    }

    final doc = query.docs.first;
    final data = doc.data();

    return AppUserProfile(
      documentId: doc.id,
      authUid: _firstNonEmptyString([
        data['auth_uid'],
        data['uid'],
        data['user_id'],
      ]),
      email: _firstNonEmptyString([
        data['email'],
        data['user_email'],
        data['official_email'],
        data['personal_email'],
        data['login_email'],
      ]),
      role: _extractRole(data),
      employeeNumber: _firstNonEmptyString([
        data['employee_number'],
        data['emp_no'],
        data['employeeNo'],
      ]),
      employeeName: _firstNonEmptyString([
        data['employee_name'],
        data['name'],
        data['full_name'],
      ]),
      isActive: _extractActiveFlag(data),
      rawData: data,
    );
  }

  AppUserRole _extractRole(Map<String, dynamic> data) {
    final candidateFields = [
      data['role'],
      data['user_role'],
      data['access_role'],
      data['account_role'],
    ];

    for (final candidate in candidateFields) {
      final normalized = (candidate ?? '').toString().trim().toLowerCase();

      if (normalized == 'developer') {
        return AppUserRole.developer;
      }

      if (normalized == 'admin' ||
          normalized == 'administrator' ||
          normalized == 'super_admin') {
        return AppUserRole.admin;
      }

      if (normalized == 'mess_manager' ||
          normalized == 'mess manager' ||
          normalized == 'manager') {
        return AppUserRole.messManager;
      }

      if (normalized == 'mess_supervisor' ||
          normalized == 'mess supervisor' ||
          normalized == 'supervisor') {
        return AppUserRole.messSupervisor;
      }

      if (normalized == 'employee' ||
          normalized == 'staff' ||
          normalized == 'user') {
        return AppUserRole.employee;
      }
    }

    return AppUserRole.unknown;
  }

  bool _extractActiveFlag(Map<String, dynamic> data) {
    final value = data['is_active'];

    if (value is bool) {
      return value;
    }

    final normalized = (value ?? '').toString().trim().toLowerCase();

    if (normalized == 'false' ||
        normalized == '0' ||
        normalized == 'inactive' ||
        normalized == 'disabled') {
      return false;
    }

    return true;
  }

  String _firstNonEmptyString(List<dynamic> values) {
    for (final value in values) {
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return '';
  }
}
