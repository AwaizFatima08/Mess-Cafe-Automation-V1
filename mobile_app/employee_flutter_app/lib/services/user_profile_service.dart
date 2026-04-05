import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_role_service.dart';

class AppUserProfile {
  final String documentId;
  final String authUid;
  final String email;
  final AppUserRole role;
  final String employeeNumber;
  final String employeeName;
  final bool isActive;
  final String status;
  final Map<String, dynamic> rawData;

  const AppUserProfile({
    required this.documentId,
    required this.authUid,
    required this.email,
    required this.role,
    required this.employeeNumber,
    required this.employeeName,
    required this.isActive,
    required this.status,
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
  UserProfileService({
    FirebaseFirestore? firestore,
    UserRoleService? userRoleService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _userRoleService = userRoleService ?? UserRoleService();

  final FirebaseFirestore _firestore;
  final UserRoleService _userRoleService;

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  Future<AppUserProfile?> resolveCurrentUserProfile({
    required String authUid,
  }) async {
    final normalizedUid = authUid.trim();

    if (normalizedUid.isEmpty) {
      return null;
    }

    DocumentSnapshot<Map<String, dynamic>>? doc;

    final directDoc = await _usersRef.doc(normalizedUid).get();
    if (directDoc.exists && directDoc.data() != null) {
      doc = directDoc;
    } else {
      final query =
          await _usersRef.where('uid', isEqualTo: normalizedUid).limit(1).get();

      if (query.docs.isEmpty) {
        return null;
      }

      doc = query.docs.first;
    }

    final data = doc.data();
    if (data == null) {
      return null;
    }

    final email = (data['email'] ?? '').toString().trim().toLowerCase();
    final employeeNumber =
        (data['employee_number'] ?? '').toString().trim();
    final employeeName = _resolveEmployeeName(data);
    final status = (data['status'] ?? '').toString().trim().toLowerCase();
    final isActive = data['is_active'] == true;

    return AppUserProfile(
      documentId: doc.id,
      authUid: (data['uid'] ?? normalizedUid).toString().trim(),
      email: email,
      role: _resolveEffectiveRole(data),
      employeeNumber: employeeNumber,
      employeeName: employeeName,
      isActive: isActive,
      status: status,
      rawData: data,
    );
  }

  Future<AppUserProfile?> getUserProfileByUid(String authUid) {
    return resolveCurrentUserProfile(authUid: authUid);
  }

  String _resolveEmployeeName(Map<String, dynamic> data) {
    final displayName = (data['display_name'] ?? '').toString().trim();
    if (displayName.isNotEmpty) {
      return displayName;
    }

    final employeeName = (data['employee_name'] ?? '').toString().trim();
    if (employeeName.isNotEmpty) {
      return employeeName;
    }

    final fallbackName = (data['name'] ?? '').toString().trim();
    return fallbackName;
  }

  AppUserRole _resolveEffectiveRole(Map<String, dynamic> data) {
    final isActive = data['is_active'] == true;
    final status = (data['status'] ?? '').toString().trim().toLowerCase();

    if (!isActive) {
      return AppUserRole.unknown;
    }

    if (status.isNotEmpty && status != 'approved' && status != 'active') {
      return AppUserRole.unknown;
    }

    return _userRoleService.parseRole(data['role']);
  }
}
