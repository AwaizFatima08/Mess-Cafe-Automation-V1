import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/user_profile_service.dart';
import '../../services/user_role_service.dart';

class UserManagementScreen extends StatefulWidget {
  final String userEmail;

  const UserManagementScreen({
    super.key,
    required this.userEmail,
  });

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserProfileService _userProfileService = UserProfileService();
  final UserRoleService _userRoleService = UserRoleService();

  bool _isAuthorized = false;
  bool _isLoadingAccess = true;
  String? _accessError;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    try {
      final authUser = FirebaseAuth.instance.currentUser;

      if (authUser == null) {
        setState(() {
          _isAuthorized = false;
          _isLoadingAccess = false;
          _accessError = 'No authenticated user found.';
        });
        return;
      }

      final profile = await _userProfileService.resolveCurrentUserProfile(
        authUid: authUser.uid,
      );

      final role = profile?.role ?? AppUserRole.unknown;
      final allowed = _userRoleService.canManageUsers(role);

      setState(() {
        _isAuthorized = allowed;
        _isLoadingAccess = false;
        _accessError =
            allowed ? null : 'Only developer and admin can access user management.';
      });
    } catch (e) {
      setState(() {
        _isAuthorized = false;
        _isLoadingAccess = false;
        _accessError = 'Failed to verify access: $e';
      });
    }
  }

  Future<void> _updateUserRole(String docId, String role) async {
    await _firestore.collection('users').doc(docId).update({
      'role': role,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _updateUserStatus(String docId, bool isActive) async {
    await _firestore.collection('users').doc(docId).update({
      'is_active': isActive,
      'status': isActive ? 'approved' : 'inactive',
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Widget _buildAccessDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'Access Restricted',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _accessError ?? 'You do not have permission to view this screen.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleChip(String role) {
    return Chip(
      label: Text(role),
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingAccess) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_isAuthorized) {
      return Scaffold(
        body: _buildAccessDenied(),
      );
    }

    return Scaffold(
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection('users')
            .orderBy('employee_number')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading users: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'User Management',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Signed in as: ${widget.userEmail}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Allowed roles: developer, admin',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (docs.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No users found.'),
                  ),
                )
              else
                ...docs.map((doc) {
                  final data = doc.data();

                  final email = (data['email'] ?? '').toString().trim();
                  final employeeNumber =
                      (data['employee_number'] ?? '').toString().trim();
                  final employeeName =
                      (data['employee_name'] ?? '').toString().trim();
                  final role = (data['role'] ?? 'unknown').toString().trim();
                  final isActive = data['is_active'] == true;
                  final status = (data['status'] ?? '').toString().trim();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        runSpacing: 12,
                        spacing: 16,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: 360,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  employeeName.isEmpty
                                      ? 'Unnamed User'
                                      : employeeName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text('Email: $email'),
                                const SizedBox(height: 4),
                                Text('Employee Number: $employeeNumber'),
                                const SizedBox(height: 4),
                                Text('Status: $status'),
                                const SizedBox(height: 8),
                                _buildRoleChip(role),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 320,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                DropdownButtonFormField<String>(
                                  initialValue: role,
                                  decoration: const InputDecoration(
                                    labelText: 'Role',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'developer',
                                      child: Text('developer'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'admin',
                                      child: Text('admin'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'mess_manager',
                                      child: Text('mess_manager'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'mess_supervisor',
                                      child: Text('mess_supervisor'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'employee',
                                      child: Text('employee'),
                                    ),
                                  ],
                                  onChanged: (value) async {
                                    if (value == null || value == role) return;

                                    final messenger = ScaffoldMessenger.of(context);

                                    await _updateUserRole(doc.id, value);

                                    if (!mounted) return;
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('User role updated.'),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Active'),
                                  subtitle: Text(
                                    isActive
                                        ? 'User can access the system'
                                        : 'User access is disabled',
                                  ),
                                  value: isActive,
                                  onChanged: (value) async {
                                    final messenger = ScaffoldMessenger.of(context);

                                    await _updateUserStatus(doc.id, value);

                                    if (!mounted) return;
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('User status updated.'),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}
