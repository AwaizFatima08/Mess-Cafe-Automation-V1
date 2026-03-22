import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/employee_identity_service.dart';
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
  final EmployeeIdentityService _employeeIdentityService =
      EmployeeIdentityService();
  final TextEditingController _searchController = TextEditingController();

  bool _isAuthorized = false;
  bool _isLoadingAccess = true;
  String? _accessError;

  String _filterMode = 'all';
  String _searchQuery = '';
  final Set<String> _busyUserIds = <String>{};

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  String _effectiveStatus({
    required String rawStatus,
    required bool isActive,
  }) {
    final normalized = rawStatus.trim().toLowerCase();

    if (isActive) {
      return 'approved';
    }

    if (normalized == 'rejected') {
      return 'rejected';
    }

    if (normalized == 'disabled') {
      return 'disabled';
    }

    if (normalized == 'approved') {
      return 'disabled';
    }

    return 'pending';
  }

  String _normalizeValue(String value) {
    return value.trim().toLowerCase();
  }

  Future<String> _resolveDisplayName(Map<String, dynamic> userData) async {
    final directName = (userData['employee_name'] ?? '').toString().trim();
    if (directName.isNotEmpty) {
      return directName.toUpperCase();
    }

    final employeeNumber = (userData['employee_number'] ?? '').toString().trim();
    if (employeeNumber.isEmpty) {
      return 'UNNAMED USER';
    }

    try {
      final employeeDoc =
          await _firestore.collection('employees').doc(employeeNumber).get();

      if (!employeeDoc.exists || employeeDoc.data() == null) {
        return 'UNNAMED USER';
      }

      final employeeName = (employeeDoc.data()!['name'] ?? '').toString().trim();

      if (employeeName.isEmpty) {
        return 'UNNAMED USER';
      }

      return employeeName.toUpperCase();
    } catch (_) {
      return 'UNNAMED USER';
    }
  }

  Future<List<String>> _collectApprovalBlockingReasons({
    required String uid,
    required Map<String, dynamic> userData,
    required EmployeeIdentityResult? identity,
  }) async {
    final reasons = <String>[];

    final email = (userData['email'] ?? '').toString().trim();
    final employeeNumber =
        (userData['employee_number'] ?? '').toString().trim();

    if (identity == null) {
      reasons.add('Identity validation could not be resolved.');
      return reasons;
    }

    if (!identity.userExists) {
      reasons.add('User record validation failed.');
    }

    if (!identity.hasEmployeeLink || employeeNumber.isEmpty) {
      reasons.add('Employee number is missing in user record.');
    }

    if (!identity.employeeExists) {
      reasons.add('Linked employee master record does not exist.');
    }

    if (identity.employeeExists && !identity.employeeIsActive) {
      reasons.add('Linked employee master record is inactive.');
    }

    if (!identity.emailMatches) {
      reasons.add('User email does not match employee master email.');
    }

    if (identity.blockingReason.trim().isNotEmpty &&
        !identity.isBookingEligible) {
      reasons.add(identity.blockingReason.trim());
    }

    if (employeeNumber.isNotEmpty) {
      final duplicateEmployeeSnapshot = await _firestore
          .collection('users')
          .where('employee_number', isEqualTo: employeeNumber)
          .get();

      final duplicateEmployeeDocs = duplicateEmployeeSnapshot.docs
          .where((doc) => doc.id != uid)
          .toList();

      if (duplicateEmployeeDocs.isNotEmpty) {
        reasons.add(
          'Another user record already exists for employee number $employeeNumber.',
        );
      }
    }

    final normalizedEmail = _normalizeValue(email);
    if (normalizedEmail.isNotEmpty) {
      final emailSnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .get();

      final duplicateEmailDocs = emailSnapshot.docs
          .where((doc) => doc.id != uid)
          .toList();

      if (duplicateEmailDocs.isEmpty) {
        final allUsersSnapshot = await _firestore.collection('users').get();
        final caseInsensitiveDuplicates = allUsersSnapshot.docs.where((doc) {
          if (doc.id == uid) return false;
          final otherEmail = _normalizeValue(
            (doc.data()['email'] ?? '').toString(),
          );
          return otherEmail.isNotEmpty && otherEmail == normalizedEmail;
        }).toList();

        if (caseInsensitiveDuplicates.isNotEmpty) {
          reasons.add('Another user record already exists for email $email.');
        }
      } else {
        reasons.add('Another user record already exists for email $email.');
      }
    }

    return reasons.toSet().toList();
  }

  Future<void> _updateUserRole({
    required String uid,
    required String newRole,
    required String effectiveStatus,
  }) async {
    if (_busyUserIds.contains(uid)) return;

    if (effectiveStatus == 'rejected' || effectiveStatus == 'disabled') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Role change blocked. ${effectiveStatus == 'disabled' ? 'Reactivate' : 'Approve'} the user first.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _busyUserIds.add(uid);
    });

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
    } finally {
      if (mounted) {
        setState(() {
          _busyUserIds.remove(uid);
        });
      }
    }
  }

  Future<void> _setUserWorkflowStatus({
    required String uid,
    required String targetStatus,
    required Map<String, dynamic> userData,
    required EmployeeIdentityResult? identity,
  }) async {
    if (_busyUserIds.contains(uid)) return;

    final normalizedTarget = targetStatus.trim().toLowerCase();
    final adminUid = FirebaseAuth.instance.currentUser?.uid;

    if (adminUid == null || adminUid.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin identity could not be resolved.')),
      );
      return;
    }

    final allowedStatuses = {'pending', 'approved', 'rejected', 'disabled'};
    if (!allowedStatuses.contains(normalizedTarget)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid target status: $targetStatus')),
      );
      return;
    }

    if (normalizedTarget == 'approved') {
      final blockingReasons = await _collectApprovalBlockingReasons(
        uid: uid,
        userData: userData,
        identity: identity,
      );

      if (blockingReasons.isNotEmpty) {
        if (!mounted) return;
        final message = blockingReasons.join(' | ');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Approval blocked: $message'),
            duration: const Duration(seconds: 6),
          ),
        );
        return;
      }
    }

    setState(() {
      _busyUserIds.add(uid);
    });

    try {
      final userRef = _firestore.collection('users').doc(uid);
      final userDoc = await userRef.get();

      if (!userDoc.exists || userDoc.data() == null) {
        throw Exception('User record not found.');
      }

      final latestUserData = userDoc.data()!;
      final employeeNumber =
          (latestUserData['employee_number'] ?? '').toString().trim();

      final now = FieldValue.serverTimestamp();

      final Map<String, dynamic> userUpdate = {
        'status': normalizedTarget,
        'is_active': normalizedTarget == 'approved',
        'updated_at': now,
      };

      if (normalizedTarget == 'approved') {
        userUpdate['approved_at'] = now;
        userUpdate['approved_by_uid'] = adminUid;
        userUpdate['rejected_at'] = null;
        userUpdate['rejected_by_uid'] = null;
        userUpdate['disabled_at'] = null;
        userUpdate['disabled_by_uid'] = null;
      } else if (normalizedTarget == 'rejected') {
        userUpdate['rejected_at'] = now;
        userUpdate['rejected_by_uid'] = adminUid;
        userUpdate['approved_at'] = null;
        userUpdate['approved_by_uid'] = null;
        userUpdate['disabled_at'] = null;
        userUpdate['disabled_by_uid'] = null;
      } else if (normalizedTarget == 'disabled') {
        userUpdate['disabled_at'] = now;
        userUpdate['disabled_by_uid'] = adminUid;
      }

      final batch = _firestore.batch();
      batch.update(userRef, userUpdate);

      Query<Map<String, dynamic>> requestQuery = _firestore
          .collection('registration_requests')
          .where('uid', isEqualTo: uid);

      if (employeeNumber.isNotEmpty) {
        requestQuery = requestQuery.where(
          'employee_number',
          isEqualTo: employeeNumber,
        );
      }

      final requestSnapshot = await requestQuery.get();

      for (final doc in requestSnapshot.docs) {
        final requestUpdate = <String, dynamic>{
          'updated_at': now,
        };

        if (normalizedTarget == 'approved') {
          requestUpdate['status'] = 'approved';
          requestUpdate['approved_at'] = now;
          requestUpdate['approved_by_uid'] = adminUid;
          requestUpdate['rejected_at'] = null;
          requestUpdate['rejected_by_uid'] = null;
        } else if (normalizedTarget == 'rejected') {
          requestUpdate['status'] = 'rejected';
          requestUpdate['rejected_at'] = now;
          requestUpdate['rejected_by_uid'] = adminUid;
          requestUpdate['approved_at'] = null;
          requestUpdate['approved_by_uid'] = null;
        } else if (normalizedTarget == 'disabled') {
          final currentRequestStatus =
              (doc.data()['status'] ?? '').toString().trim().toLowerCase();

          if (currentRequestStatus == 'approved') {
            requestUpdate['status'] = 'disabled';
          }
        }

        batch.update(doc.reference, requestUpdate);
      }

      await batch.commit();

      if (!mounted) return;

      String successMessage;
      switch (normalizedTarget) {
        case 'approved':
          successMessage = 'User approved and activated.';
          break;
        case 'rejected':
          successMessage = 'User registration rejected.';
          break;
        case 'disabled':
          successMessage = 'User disabled successfully.';
          break;
        case 'pending':
          successMessage = 'User moved to pending state.';
          break;
        default:
          successMessage = 'User status updated.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update workflow status: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyUserIds.remove(uid);
        });
      }
    }
  }

  bool _matchesFilter({
    required String filterMode,
    required String effectiveStatus,
    required EmployeeIdentityResult? identity,
  }) {
    switch (filterMode) {
      case 'approved':
        return effectiveStatus == 'approved';
      case 'pending':
        return effectiveStatus == 'pending';
      case 'rejected':
        return effectiveStatus == 'rejected';
      case 'disabled':
        return effectiveStatus == 'disabled';
      case 'eligible':
        return identity?.isBookingEligible == true;
      case 'blocked':
        return identity != null && !identity.isBookingEligible;
      case 'broken_linkage':
        return identity == null ||
            !identity.userExists ||
            !identity.hasEmployeeLink ||
            !identity.employeeExists;
      case 'email_mismatch':
        return identity != null &&
            identity.employeeExists &&
            !identity.emailMatches;
      case 'inactive_master':
        return identity != null &&
            identity.employeeExists &&
            !identity.employeeIsActive;
      case 'all':
      default:
        return true;
    }
  }

  bool _matchesSearch({
    required String email,
    required String employeeNumber,
    required String displayName,
  }) {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return true;
    }

    return email.toLowerCase().contains(query) ||
        employeeNumber.toLowerCase().contains(query) ||
        displayName.toLowerCase().contains(query);
  }

  Color _statusColorForWorkflow(String status, BuildContext context) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Theme.of(context).colorScheme.error;
      case 'disabled':
        return Colors.grey.shade700;
      default:
        return Colors.blueGrey;
    }
  }

  Color _statusColor(BuildContext context, bool ok) {
    return ok ? Colors.green : Theme.of(context).colorScheme.error;
  }

  String _workflowStatusLabel(String status) {
    switch (status) {
      case 'approved':
        return 'Approved';
      case 'pending':
        return 'Pending';
      case 'rejected':
        return 'Rejected';
      case 'disabled':
        return 'Disabled';
      default:
        return status;
    }
  }

  String _formatTimestamp(dynamic value) {
    if (value == null) {
      return '—';
    }

    if (value is Timestamp) {
      final dt = value.toDate().toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year.toString();
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$day-$month-$year $hour:$minute';
    }

    return value.toString();
  }

  Widget _buildBooleanStatusRow({
    required BuildContext context,
    required String label,
    required bool value,
    required String trueText,
    required String falseText,
  }) {
    final color = _statusColor(context, value);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value ? trueText : falseText,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditRow({
    required String label,
    required String uid,
    required String time,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              'UID: ${uid.isEmpty ? '—' : uid}\nTime: $time',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentitySummaryCard(EmployeeIdentityResult identity) {
    final bookingEligible = identity.isBookingEligible;
    final labelColor = bookingEligible ? Colors.green : Colors.orange;

    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Validation Summary',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Chip(
                  label: Text(identity.linkageStatusLabel),
                  backgroundColor: labelColor.withValues(alpha: 0.12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildBooleanStatusRow(
              context: context,
              label: 'User Record',
              value: identity.userExists,
              trueText: 'Found',
              falseText: 'Missing',
            ),
            _buildBooleanStatusRow(
              context: context,
              label: 'Employee Number',
              value: identity.hasEmployeeLink,
              trueText: identity.employeeNumber ?? 'Present',
              falseText: 'Missing in user record',
            ),
            _buildBooleanStatusRow(
              context: context,
              label: 'Employee Master',
              value: identity.employeeExists,
              trueText: 'Found',
              falseText: 'Missing',
            ),
            _buildBooleanStatusRow(
              context: context,
              label: 'User Active',
              value: identity.userIsActive,
              trueText: 'Active',
              falseText: 'Inactive',
            ),
            _buildBooleanStatusRow(
              context: context,
              label: 'Employee Active',
              value: identity.employeeIsActive,
              trueText: 'Active',
              falseText: 'Inactive',
            ),
            _buildBooleanStatusRow(
              context: context,
              label: 'Email Match',
              value: identity.emailMatches,
              trueText: 'Matched',
              falseText: 'Mismatch',
            ),
            _buildBooleanStatusRow(
              context: context,
              label: 'Booking Eligibility',
              value: identity.isBookingEligible,
              trueText: 'Eligible',
              falseText: 'Blocked',
            ),
            if (identity.blockingReason.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Blocking Reason: ${identity.blockingReason}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAuditTrailCard(Map<String, dynamic> userData) {
    final approvedByUid =
        (userData['approved_by_uid'] ?? '').toString().trim();
    final rejectedByUid =
        (userData['rejected_by_uid'] ?? '').toString().trim();
    final disabledByUid =
        (userData['disabled_by_uid'] ?? '').toString().trim();

    final approvedAt = _formatTimestamp(userData['approved_at']);
    final rejectedAt = _formatTimestamp(userData['rejected_at']);
    final disabledAt = _formatTimestamp(userData['disabled_at']);

    final hasAnyAuditData = approvedByUid.isNotEmpty ||
        rejectedByUid.isNotEmpty ||
        disabledByUid.isNotEmpty ||
        approvedAt != '—' ||
        rejectedAt != '—' ||
        disabledAt != '—';

    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Audit Trail',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            if (!hasAnyAuditData)
              const Text('No workflow audit actions recorded yet.')
            else ...[
              _buildAuditRow(
                label: 'Approved',
                uid: approvedByUid,
                time: approvedAt,
              ),
              _buildAuditRow(
                label: 'Rejected',
                uid: rejectedByUid,
                time: rejectedAt,
              ),
              _buildAuditRow(
                label: 'Disabled',
                uid: disabledByUid,
                time: disabledAt,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            labelText: 'Search (Name / Email / Employee Number)',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                        _searchController.clear();
                      });
                    },
                  )
                : null,
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Text(
              'Filter Users',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _filterMode,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Filter',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                ),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Users')),
                  DropdownMenuItem(
                    value: 'approved',
                    child: Text('Approved'),
                  ),
                  DropdownMenuItem(
                    value: 'pending',
                    child: Text('Pending'),
                  ),
                  DropdownMenuItem(
                    value: 'rejected',
                    child: Text('Rejected'),
                  ),
                  DropdownMenuItem(
                    value: 'disabled',
                    child: Text('Disabled'),
                  ),
                  DropdownMenuItem(
                    value: 'eligible',
                    child: Text('Booking Eligible'),
                  ),
                  DropdownMenuItem(
                    value: 'blocked',
                    child: Text('Booking Blocked'),
                  ),
                  DropdownMenuItem(
                    value: 'broken_linkage',
                    child: Text('Broken Linkage'),
                  ),
                  DropdownMenuItem(
                    value: 'email_mismatch',
                    child: Text('Email Mismatch'),
                  ),
                  DropdownMenuItem(
                    value: 'inactive_master',
                    child: Text('Inactive Employee Master'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _filterMode = value;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons({
    required String uid,
    required String effectiveStatus,
    required bool isBusy,
    required Map<String, dynamic> userData,
    required EmployeeIdentityResult? identity,
  }) {
    if (effectiveStatus == 'pending') {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ElevatedButton.icon(
            onPressed: isBusy
                ? null
                : () => _setUserWorkflowStatus(
                      uid: uid,
                      targetStatus: 'approved',
                      userData: userData,
                      identity: identity,
                    ),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Approve'),
          ),
          OutlinedButton.icon(
            onPressed: isBusy
                ? null
                : () => _setUserWorkflowStatus(
                      uid: uid,
                      targetStatus: 'rejected',
                      userData: userData,
                      identity: identity,
                    ),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Reject'),
          ),
        ],
      );
    }

    if (effectiveStatus == 'approved') {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: isBusy
                ? null
                : () => _setUserWorkflowStatus(
                      uid: uid,
                      targetStatus: 'disabled',
                      userData: userData,
                      identity: identity,
                    ),
            icon: const Icon(Icons.block_outlined),
            label: const Text('Disable'),
          ),
        ],
      );
    }

    if (effectiveStatus == 'rejected' || effectiveStatus == 'disabled') {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ElevatedButton.icon(
            onPressed: isBusy
                ? null
                : () => _setUserWorkflowStatus(
                      uid: uid,
                      targetStatus: 'approved',
                      userData: userData,
                      identity: identity,
                    ),
            icon: const Icon(Icons.restart_alt),
            label: Text(
              effectiveStatus == 'disabled' ? 'Reactivate' : 'Approve',
            ),
          ),
          if (effectiveStatus == 'disabled')
            OutlinedButton.icon(
              onPressed: isBusy
                  ? null
                  : () => _setUserWorkflowStatus(
                        uid: uid,
                        targetStatus: 'rejected',
                        userData: userData,
                        identity: identity,
                      ),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Reject'),
            ),
        ],
      );
    }

    return const SizedBox.shrink();
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
                    const SizedBox(height: 4),
                    Text('Total loaded users: ${docs.length}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildSearchBar(),
            const SizedBox(height: 16),
            _buildFilterBar(),
            const SizedBox(height: 16),
            ...docs.map((doc) {
              final data = doc.data();
              final uid = doc.id;
              final email = (data['email'] ?? '').toString().trim();
              final employeeNumber =
                  (data['employee_number'] ?? '').toString().trim();
              final role = (data['role'] ?? 'employee').toString().trim();
              final rawStatus = (data['status'] ?? '').toString().trim();
              final isActive = data['is_active'] == true;
              final effectiveStatus = _effectiveStatus(
                rawStatus: rawStatus,
                isActive: isActive,
              );
              final isBusy = _busyUserIds.contains(uid);

              return FutureBuilder<String>(
                future: _resolveDisplayName(data),
                builder: (context, nameSnapshot) {
                  final displayName = nameSnapshot.data ?? 'Loading...';

                  if (nameSnapshot.connectionState == ConnectionState.done &&
                      !_matchesSearch(
                        email: email,
                        employeeNumber: employeeNumber,
                        displayName: displayName,
                      )) {
                    return const SizedBox.shrink();
                  }

                  return FutureBuilder<EmployeeIdentityResult>(
                    future: _employeeIdentityService.resolveByAuthUid(uid),
                    builder: (context, identitySnapshot) {
                      if (identitySnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
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
                                const SizedBox(height: 12),
                                const LinearProgressIndicator(),
                              ],
                            ),
                          ),
                        );
                      }

                      final identity = identitySnapshot.data;

                      if (!_matchesFilter(
                        filterMode: _filterMode,
                        effectiveStatus: effectiveStatus,
                        identity: identity,
                      )) {
                        return const SizedBox.shrink();
                      }

                      if (!_matchesSearch(
                        email: email,
                        employeeNumber: employeeNumber,
                        displayName: displayName,
                      )) {
                        return const SizedBox.shrink();
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 24,
                                runSpacing: 16,
                                crossAxisAlignment: WrapCrossAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 340,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                        Text(
                                          'Employee Number: ${employeeNumber.isEmpty ? 'Not assigned' : employeeNumber}',
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Workflow Status: ${_workflowStatusLabel(effectiveStatus)}',
                                        ),
                                        const SizedBox(height: 12),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            Chip(label: Text(role)),
                                            Chip(
                                              label: Text(
                                                _workflowStatusLabel(
                                                  effectiveStatus,
                                                ),
                                              ),
                                              backgroundColor:
                                                  _statusColorForWorkflow(
                                                effectiveStatus,
                                                context,
                                              ).withValues(alpha: 0.12),
                                            ),
                                            Chip(
                                              label: Text(
                                                isActive
                                                    ? 'User Active'
                                                    : 'User Inactive',
                                              ),
                                              backgroundColor: isActive
                                                  ? Colors.green.withValues(
                                                      alpha: 0.12,
                                                    )
                                                  : Colors.orange.withValues(
                                                      alpha: 0.12,
                                                    ),
                                            ),
                                            if (identity != null)
                                              Chip(
                                                label: Text(
                                                  identity.isBookingEligible
                                                      ? 'Booking Eligible'
                                                      : 'Booking Blocked',
                                                ),
                                                backgroundColor:
                                                    identity.isBookingEligible
                                                        ? Colors.green
                                                            .withValues(
                                                            alpha: 0.12,
                                                          )
                                                        : Colors.red.withValues(
                                                            alpha: 0.12,
                                                          ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: 340,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        DropdownButtonFormField<String>(
                                          initialValue:
                                              _roleOptions.contains(role)
                                                  ? role
                                                  : 'employee',
                                          decoration: const InputDecoration(
                                            labelText: 'Role',
                                            border: OutlineInputBorder(),
                                          ),
                                          items: _roleOptions
                                              .map(
                                                (value) => DropdownMenuItem(
                                                  value: value,
                                                  child: Text(value),
                                                ),
                                              )
                                              .toList(),
                                          onChanged: isBusy
                                              ? null
                                              : (value) {
                                                  if (value == null ||
                                                      value == role) {
                                                    return;
                                                  }
                                                  _updateUserRole(
                                                    uid: uid,
                                                    newRole: value,
                                                    effectiveStatus:
                                                        effectiveStatus,
                                                  );
                                                },
                                        ),
                                        const SizedBox(height: 16),
                                        _buildActionButtons(
                                          uid: uid,
                                          effectiveStatus: effectiveStatus,
                                          isBusy: isBusy,
                                          userData: data,
                                          identity: identity,
                                        ),
                                        if (isBusy) ...[
                                          const SizedBox(height: 12),
                                          const LinearProgressIndicator(),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (identitySnapshot.hasError)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(
                                    'Validation load failed: ${identitySnapshot.error}',
                                    style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.error,
                                    ),
                                  ),
                                )
                              else if (identity != null)
                                _buildIdentitySummaryCard(identity),
                              _buildAuditTrailCard(data),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
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
