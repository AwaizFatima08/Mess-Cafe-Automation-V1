import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/employee_identity_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final EmployeeIdentityService _employeeIdentityService = EmployeeIdentityService();

  bool _isAuthorized = false;
  bool _isLoadingAccess = true;
  String? _accessError;
  String _searchQuery = '';

  static const List<String> _roleOptions = [
    'developer',
    'admin',
    'mess_manager',
    'mess_supervisor',
    'employee',
  ];

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

      final result = await _employeeIdentityService.resolveByAuthUid(authUser.uid);
      final role = result.user?['role'] ?? 'employee';

      // Governance Rule: Only Admin, Developer, or Mess Manager can manage users
      final canManage = role == 'admin' || role == 'developer' || role == 'mess_manager';

      setState(() {
        _isAuthorized = canManage;
        _isLoadingAccess = false;
        _accessError = canManage ? null : 'You are not authorized to manage users.';
      });
    } catch (e) {
      setState(() {
        _isAuthorized = false;
        _isLoadingAccess = false;
        _accessError = 'Failed to check access: $e';
      });
    }
  }

  String _effectiveStatus({required String rawStatus, required bool isActive}) {
    final normalized = rawStatus.trim().toLowerCase();
    if (isActive) return 'approved';
    if (normalized == 'rejected') return 'rejected';
    if (normalized == 'disabled') return 'disabled';
    return 'pending';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingAccess) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (!_isAuthorized) return Scaffold(body: Center(child: Text(_accessError ?? 'Unauthorized')));

    return Scaffold(
      appBar: AppBar(
        title: const Text("User Governance"),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("Search Employee"),
                  content: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: const InputDecoration(hintText: "Enter Name or Email"),
                  ),
                  actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close"))],
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestore.collection('users').orderBy('email').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final docs = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) => _buildUserCard(docs[index]),
          );
        },
      ),
    );
  }

  Widget _buildUserCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final uid = doc.id;
    final String email = data['email'] ?? '';
    final String role = data['role'] ?? 'employee';
    final bool isActive = data['is_active'] == true;
    final String status = _effectiveStatus(rawStatus: data['status'] ?? '', isActive: isActive);

    return FutureBuilder<EmployeeIdentityResult>(
      future: _employeeIdentityService.resolveByAuthUid(uid),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final identity = snapshot.data!;

        if (_searchQuery.isNotEmpty && !email.toLowerCase().contains(_searchQuery.toLowerCase())) {
          return const SizedBox.shrink();
        }

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        identity.employee?['full_name'] ?? email,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _statusChip(status),
                  ],
                ),
                const SizedBox(height: 8),
                Text("Emp #: ${identity.employeeNumber ?? 'Not Linked'}", style: TextStyle(color: Colors.grey[600])),
                const Divider(),
                _validLine("Master Link", identity.hasEmployeeLink),
                _validLine("Email Match", identity.emailMatches),
                _validLine("Master Active", identity.employeeIsActive),
                if (!identity.isBookingEligible)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      "Block Reason: ${identity.blockingReason}",
                      style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    DropdownButton<String>(
                      value: _roleOptions.contains(role) ? role : 'employee',
                      items: _roleOptions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                      onChanged: (val) => _updateRole(uid, val!),
                    ),
                    _buildWorkflowButton(uid, status, identity),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _validLine(String label, bool valid) {
    return Row(
      children: [
        Icon(valid ? Icons.check_circle : Icons.error, color: valid ? Colors.green : Colors.red, size: 14),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _statusChip(String status) {
    Color color = status == 'approved' ? Colors.green : (status == 'pending' ? Colors.orange : Colors.red);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildWorkflowButton(String uid, String status, EmployeeIdentityResult identity) {
    if (status == 'pending') {
      return ElevatedButton(
        onPressed: identity.isBookingEligible ? () => _setStatus(uid, 'approved') : null,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
        child: const Text("Approve"),
      );
    }
    return TextButton(
      onPressed: () => _setStatus(uid, status == 'approved' ? 'disabled' : 'approved'),
      child: Text(status == 'approved' ? "Disable" : "Reactivate"),
    );
  }

  Future<void> _updateRole(String uid, String role) async {
    await _firestore.collection('users').doc(uid).update({'role': role});
  }

  Future<void> _setStatus(String uid, String status) async {
    await _firestore.collection('users').doc(uid).update({
      'status': status,
      'is_active': status == 'approved',
      'updated_at': FieldValue.serverTimestamp(),
    });
  }
}
