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
      final canManageUsers = _userRoleService.canManageUsers(role);

      setState(() {
        _isAuthorized = canManageUsers;
        _isLoadingAccess = false;
        _accessError =
            canManageUsers ? null : 'You are not allowed to manage users.';
      });
    } catch (e) {
      setState(() {
        _isAuthorized = false;
        _isLoadingAccess = false;
        _accessError = 'Failed to check access: $e';
      });
    }
  }

  Future<String> _resolveDisplayName(Map<String, dynamic> userData) async {
    final directName = (userData['employee_name'] ?? '').toString().trim();
    if (directName.isNotEmpty) {
      return directName.toUpperCase();
    }

    final employeeNumber = (userData['employee_number'] ?? '').toString().trim();
    if (employeeNumber.isEmpty) {
      return 'Unnamed User';
    }

    try {
      final employeeDoc =
          await _firestore.collection('employees').doc(employeeNumber).get();

      if (!employeeDoc.exists || employeeDoc.data() == null) {
        return 'Unnamed User';
      }

      final employeeName =
          (employeeDoc.data()!['name'] ?? '').toString().trim();

      if (employeeName.isEmpty) {
        return 'Unnamed User';
      }

      return employeeName.toUpperCase();
    } catch (_) {
      return 'Unnamed User';
    }
  }

  Future<void> _updateUserRole(String uid, String newRole) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'role': newRole,
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User role updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update role: $e')),
      );
    }
  }

  Future<void> _updateUserStatus(
    String uid,
    bool isActive,
  ) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'is_active': isActive,
        'status': isActive ? 'approved' : 'pending',
        'updated_at': FieldValue.serverTimestamp(),
        if (isActive) 'approved_at': FieldValue.serverTimestamp(),
        if (isActive)
          'approved_by_uid': FirebaseAuth.instance.currentUser?.uid,
      });

      final requestSnapshot = await _firestore
          .collection('registration_requests')
          .where('uid', isEqualTo: uid)
          .where('status', isEqualTo: 'pending')
          .get();

      for (final doc in requestSnapshot.docs) {
        await doc.reference.update({
          'status': isActive ? 'approved' : 'pending',
          'updated_at': FieldValue.serverTimestamp(),
          if (isActive) 'approved_at': FieldValue.serverTimestamp(),
          if (isActive)
            'approved_by_uid': FirebaseAuth.instance.currentUser?.uid,
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User status updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update user status: $e')),
      );
    }
  }

  Widget _buildAccessState() {
    if (_isLoadingAccess) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_isAuthorized) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            _accessError ?? 'Access denied.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('users').orderBy('email').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Failed to load users: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'User Management',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Signed in as: ${widget.userEmail}'),
                    const SizedBox(height: 4),
                    const Text('Allowed roles: developer, admin'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...docs.map((doc) {
              final data = doc.data();
              final uid = doc.id;
              final email = (data['email'] ?? '').toString().trim();
              final employeeNumber =
                  (data['employee_number'] ?? '').toString().trim();
              final role = (data['role'] ?? 'employee').toString().trim();
              final status = (data['status'] ?? '').toString().trim();
              final isActive = data['is_active'] == true;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FutureBuilder<String>(
                    future: _resolveDisplayName(data),
                    builder: (context, nameSnapshot) {
                      final displayName =
                          nameSnapshot.data ?? 'Loading...';

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 24,
                            runSpacing: 16,
                            crossAxisAlignment: WrapCrossAlignment.start,
                            children: [
                              SizedBox(
                                width: 320,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text('Email: $email'),
                                    const SizedBox(height: 6),
                                    Text('Employee Number: $employeeNumber'),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Status: ${status.isEmpty ? (isActive ? 'approved' : 'pending') : status}',
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 8,
                                      children: [
                                        Chip(label: Text(role)),
                                      ],
                                    ),
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
                                      onChanged: (value) {
                                        if (value == null || value == role) {
                                          return;
                                        }
                                        _updateUserRole(uid, value);
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    SwitchListTile(
                                      value: isActive,
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text('Active'),
                                      subtitle: Text(
                                        isActive
                                            ? 'User can access the system'
                                            : 'User access is disabled',
                                      ),
                                      onChanged: (value) {
                                        _updateUserStatus(uid, value);
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildAccessState(),
    );
  }
}
