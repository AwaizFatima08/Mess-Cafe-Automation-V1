import 'package:cloud_firestore/cloud_firestore.dart';

enum AppUserRole {
  developer,
  admin,
  messManager,
  messSupervisor,
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

  bool get isAdminFamily {
    return role == AppUserRole.developer ||
        role == AppUserRole.admin ||
        role == AppUserRole.messManager ||
        role == AppUserRole.messSupervisor;
  }

  bool get canManageMenus {
    return role == AppUserRole.developer ||
        role == AppUserRole.admin ||
        role == AppUserRole.messManager;
  }

  bool get canConfirmIssuance {
    return role == AppUserRole.developer ||
        role == AppUserRole.admin ||
        role == AppUserRole.messManager ||
        role == AppUserRole.messSupervisor;
  }

  bool get canEnterRates {
    return role == AppUserRole.developer ||
        role == AppUserRole.admin ||
        role == AppUserRole.messManager;
  }

  bool get canManageUsers {
    return role == AppUserRole.developer || role == AppUserRole.admin;
  }
}

class UserRoleService {
  UserRoleService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  Future<ResolvedUserRole> resolveRole({
    required String authUid,
  }) async {
    final normalizedUid = authUid.trim();

    if (normalizedUid.isEmpty) {
      return const ResolvedUserRole(
        role: AppUserRole.unknown,
        source: 'missing_auth_uid',
      );
    }

    final directDoc = await _usersRef.doc(normalizedUid).get();
    if (directDoc.exists && directDoc.data() != null) {
      final data = directDoc.data()!;
      return ResolvedUserRole(
        role: _resolveEffectiveRole(data),
        source: 'users.doc_uid',
        documentId: directDoc.id,
        rawData: data,
      );
    }

    final query =
        await _usersRef.where('uid', isEqualTo: normalizedUid).limit(1).get();

    if (query.docs.isEmpty) {
      return const ResolvedUserRole(
        role: AppUserRole.unknown,
        source: 'users.uid_not_found',
      );
    }

    final doc = query.docs.first;
    final data = doc.data();

    return ResolvedUserRole(
      role: _resolveEffectiveRole(data),
      source: 'users.uid',
      documentId: doc.id,
      rawData: data,
    );
  }

  AppUserRole _resolveEffectiveRole(Map<String, dynamic>? data) {
    if (data == null) {
      return AppUserRole.unknown;
    }

    final isActive = data['is_active'] == true;
    final status = (data['status'] ?? '').toString().trim().toLowerCase();

    if (!isActive) {
      return AppUserRole.unknown;
    }

    if (status.isNotEmpty && status != 'approved' && status != 'active') {
      return AppUserRole.unknown;
    }

    return parseRole(data['role']);
  }

  AppUserRole parseRole(dynamic value) {
    final normalized = (value ?? '').toString().trim().toLowerCase();

    switch (normalized) {
      case 'developer':
        return AppUserRole.developer;
      case 'admin':
        return AppUserRole.admin;
      case 'mess_manager':
        return AppUserRole.messManager;
      case 'mess_supervisor':
        return AppUserRole.messSupervisor;
      case 'employee':
        return AppUserRole.employee;
      default:
        return AppUserRole.unknown;
    }
  }

  String roleToFirestoreValue(AppUserRole role) {
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

  bool isAdminFamily(AppUserRole role) {
    return role == AppUserRole.developer ||
        role == AppUserRole.admin ||
        role == AppUserRole.messManager ||
        role == AppUserRole.messSupervisor;
  }

  bool canManageMenus(AppUserRole role) {
    return role == AppUserRole.developer ||
        role == AppUserRole.admin ||
        role == AppUserRole.messManager;
  }

  bool canConfirmIssuance(AppUserRole role) {
    return role == AppUserRole.developer ||
        role == AppUserRole.admin ||
        role == AppUserRole.messManager ||
        role == AppUserRole.messSupervisor;
  }

  bool canEnterRates(AppUserRole role) {
    return role == AppUserRole.developer ||
        role == AppUserRole.admin ||
        role == AppUserRole.messManager;
  }

  bool canManageUsers(AppUserRole role) {
    return role == AppUserRole.developer || role == AppUserRole.admin;
  }
}
