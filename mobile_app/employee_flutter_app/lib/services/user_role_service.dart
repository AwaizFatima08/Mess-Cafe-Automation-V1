import 'package:cloud_firestore/cloud_firestore.dart';

enum AppUserRole {
  admin,
  employee,
  unknown,
}

class ResolvedUserRole {
  final AppUserRole role;
  final String source;
  final String? documentId;
  final Map<String, dynamic>? rawData;

  const ResolvedUserRole({
    required this.role,
    required this.source,
    this.documentId,
    this.rawData,
  });
}

class UserRoleService {
  UserRoleService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  Future<ResolvedUserRole> resolveRole({
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

        final resolved = _readRoleFromQuery(query, source: 'users.$field');
        if (resolved != null) {
          return resolved;
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

      final exactResolved =
          _readRoleFromQuery(exactQuery, source: 'users.$field');
      if (exactResolved != null) {
        return exactResolved;
      }

      final lowerQuery = await _usersRef
          .where(field, isEqualTo: normalizedLowerEmail)
          .limit(1)
          .get();

      final lowerResolved =
          _readRoleFromQuery(lowerQuery, source: 'users.$field');
      if (lowerResolved != null) {
        return lowerResolved;
      }
    }

    return const ResolvedUserRole(
      role: AppUserRole.employee,
      source: 'fallback_default_employee',
    );
  }

  ResolvedUserRole? _readRoleFromQuery(
    QuerySnapshot<Map<String, dynamic>> query, {
    required String source,
  }) {
    if (query.docs.isEmpty) {
      return null;
    }

    final doc = query.docs.first;
    final data = doc.data();

    final role = _extractRole(data);

    return ResolvedUserRole(
      role: role,
      source: source,
      documentId: doc.id,
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

      if (normalized == 'admin' ||
          normalized == 'administrator' ||
          normalized == 'super_admin') {
        return AppUserRole.admin;
      }

      if (normalized == 'employee' ||
          normalized == 'staff' ||
          normalized == 'user') {
        return AppUserRole.employee;
      }
    }

    return AppUserRole.unknown;
  }
}
