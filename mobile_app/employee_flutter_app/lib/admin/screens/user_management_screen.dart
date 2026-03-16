import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserManagementScreen extends StatefulWidget {
  final String userEmail;

  const UserManagementScreen({super.key, required this.userEmail});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  static const List<String> _roleOptions = [
    'developer',
    'admin',
    'mess_manager',
    'mess_supervisor',
    'employee',
  ];

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      FirebaseFirestore.instance.collection('users');

  CollectionReference<Map<String, dynamic>> get _employeesRef =>
      FirebaseFirestore.instance.collection('employees');

  Future<void> _openUserDialog({
    String? documentId,
    Map<String, dynamic>? existingData,
  }) async {
    final emailController = TextEditingController(
      text: (existingData?['email'] ?? existingData?['user_email'] ?? '')
          .toString(),
    );
    final authUidController = TextEditingController(
      text: (existingData?['auth_uid'] ?? existingData?['uid'] ?? '').toString(),
    );
    final employeeNumberController = TextEditingController(
      text: (existingData?['employee_number'] ?? '').toString(),
    );
    final employeeNameController = TextEditingController(
      text: (existingData?['employee_name'] ??
              existingData?['name'] ??
              existingData?['full_name'] ??
              '')
          .toString(),
    );
    final notesController = TextEditingController(
      text: (existingData?['notes'] ?? '').toString(),
    );

    String selectedRole =
        (existingData?['role'] ?? existingData?['user_role'] ?? 'employee')
            .toString()
            .trim();

    if (!_roleOptions.contains(selectedRole)) {
      selectedRole = 'employee';
    }

    bool isActive = existingData?['is_active'] as bool? ?? true;
    bool isSaving = false;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    Future<void> pickEmployee(StateSetter setDialogState) async {
      final employee = await _showEmployeePickerDialog();

      if (employee == null) {
        return;
      }

      setDialogState(() {
        employeeNumberController.text = employee.employeeNumber;
        employeeNameController.text = employee.name;
      });
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: !isSaving,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> saveUser() async {
              final email = emailController.text.trim();
              final authUid = authUidController.text.trim();
              final employeeNumber = employeeNumberController.text.trim();
              final employeeName = employeeNameController.text.trim();
              final notes = notesController.text.trim();

              if (email.isEmpty) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Email is required.'),
                  ),
                );
                return;
              }

              setDialogState(() {
                isSaving = true;
              });

              try {
                final payload = <String, dynamic>{
                  'email': email,
                  'auth_uid': authUid,
                  'role': selectedRole,
                  'is_active': isActive,
                  'employee_number': employeeNumber,
                  'employee_name': employeeName,
                  'notes': notes,
                  'updated_at': FieldValue.serverTimestamp(),
                  'updated_by': widget.userEmail,
                };

                if (documentId == null) {
                  payload['created_at'] = FieldValue.serverTimestamp();
                  payload['created_by'] = widget.userEmail;
                  await _usersRef.add(payload);
                } else {
                  await _usersRef.doc(documentId).update(payload);
                }

                if (!mounted) return;

                navigator.pop();

                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      documentId == null
                          ? 'User access created successfully.'
                          : 'User access updated successfully.',
                    ),
                  ),
                );
              } catch (e) {
                if (!mounted) return;

                setDialogState(() {
                  isSaving = false;
                });

                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Unable to save user access: $e'),
                  ),
                );
              }
            }

            return AlertDialog(
              title: Text(
                documentId == null ? 'Create User Access' : 'Edit User Access',
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 460,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'Login Email',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: authUidController,
                        decoration: const InputDecoration(
                          labelText: 'Firebase Auth UID',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          border: OutlineInputBorder(),
                        ),
                        items: _roleOptions
                            .map(
                              (role) => DropdownMenuItem<String>(
                                value: role,
                                child: Text(role),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setDialogState(() {
                            selectedRole = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active Access'),
                        subtitle: const Text(
                          'Disable to block login access without deleting the record.',
                        ),
                        value: isActive,
                        onChanged: (value) {
                          setDialogState(() {
                            isActive = value;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: employeeNumberController,
                              decoration: const InputDecoration(
                                labelText: 'Linked Employee Number',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: isSaving
                                ? null
                                : () => pickEmployee(setDialogState),
                            icon: const Icon(Icons.search),
                            label: const Text('Lookup'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: employeeNameController,
                        decoration: const InputDecoration(
                          labelText: 'Linked Employee Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Use Lookup to search the employees collection and auto-fill employee details.',
                          style:
                              Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: notesController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving ? null : saveUser,
                  child: Text(isSaving ? 'Saving...' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<_EmployeeLookupResult?> _showEmployeePickerDialog() async {
    final searchController = TextEditingController();
    List<_EmployeeLookupResult> allEmployees = [];
    List<_EmployeeLookupResult> filteredEmployees = [];
    bool isLoading = true;
    String? errorMessage;

    try {
      final snapshot = await _employeesRef.orderBy('employee_number').get();

      allEmployees = snapshot.docs.map((doc) {
        final data = doc.data();

        return _EmployeeLookupResult(
          documentId: doc.id,
          employeeNumber: (data['employee_number'] ?? '').toString(),
          name: (data['name'] ?? '').toString(),
          prefix: (data['prefix'] ?? '').toString(),
          department: (data['department'] ?? '').toString(),
          designation: (data['designation'] ?? '').toString(),
        );
      }).toList();

      filteredEmployees = [...allEmployees];
      isLoading = false;
    } catch (e) {
      errorMessage = 'Unable to load employees: $e';
      isLoading = false;
    }

    if (!mounted) return null;

    return showDialog<_EmployeeLookupResult>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void applyFilter(String query) {
              final normalized = query.trim().toLowerCase();

              setDialogState(() {
                if (normalized.isEmpty) {
                  filteredEmployees = [...allEmployees];
                  return;
                }

                filteredEmployees = allEmployees.where((employee) {
                  final haystack = [
                    employee.employeeNumber,
                    employee.name,
                    employee.prefix,
                    employee.department,
                    employee.designation,
                    employee.displayCode,
                  ].join(' ').toLowerCase();

                  return haystack.contains(normalized);
                }).toList();
              });
            }

            return AlertDialog(
              title: const Text('Select Employee'),
              content: SizedBox(
                width: 520,
                height: 500,
                child: Column(
                  children: [
                    TextField(
                      controller: searchController,
                      onChanged: applyFilter,
                      decoration: const InputDecoration(
                        labelText: 'Search employee',
                        hintText:
                            'Search by employee number, name, department, designation',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (isLoading)
                      const Expanded(
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (errorMessage != null)
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              errorMessage,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ),
                      )
                    else if (filteredEmployees.isEmpty)
                      const Expanded(
                        child: Center(
                          child: Text('No matching employees found.'),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          itemCount: filteredEmployees.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final employee = filteredEmployees[index];

                            return Card(
                              child: ListTile(
                                onTap: () => Navigator.pop(dialogContext, employee),
                                leading: const Icon(Icons.badge_outlined),
                                title: Text(
                                  employee.name.isNotEmpty
                                      ? employee.name
                                      : 'Unnamed Employee',
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Emp No: ${employee.displayCode}'),
                                    if (employee.department.isNotEmpty)
                                      Text('Department: ${employee.department}'),
                                    if (employee.designation.isNotEmpty)
                                      Text(
                                        'Designation: ${employee.designation}',
                                      ),
                                  ],
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _toggleUserStatus({
    required String documentId,
    required bool currentStatus,
  }) async {
    try {
      await _usersRef.doc(documentId).update({
        'is_active': !currentStatus,
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': widget.userEmail,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !currentStatus
                ? 'User access activated.'
                : 'User access deactivated.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to update user status: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _HeaderCard(
            userEmail: widget.userEmail,
            onCreatePressed: () => _openUserDialog(),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _usersRef.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Error loading users: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = [...(snapshot.data?.docs ?? [])]
                  ..sort((a, b) {
                    final aEmail = (a.data()['email'] ?? '').toString();
                    final bEmail = (b.data()['email'] ?? '').toString();
                    return aEmail.toLowerCase().compareTo(bEmail.toLowerCase());
                  });

                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.admin_panel_settings_outlined,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No user access records found.',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Create the first access record in the users collection to manage login roles and permissions.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _openUserDialog(),
                            icon: const Icon(Icons.person_add_alt_1),
                            label: const Text('Create First User'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();

                    final email = (data['email'] ??
                            data['user_email'] ??
                            data['official_email'] ??
                            '')
                        .toString();
                    final authUid =
                        (data['auth_uid'] ?? data['uid'] ?? '').toString();
                    final role = (data['role'] ??
                            data['user_role'] ??
                            data['access_role'] ??
                            'unknown')
                        .toString();
                    final isActive = data['is_active'] as bool? ?? true;
                    final employeeNumber =
                        (data['employee_number'] ?? '').toString();
                    final employeeName = (data['employee_name'] ??
                            data['name'] ??
                            data['full_name'] ??
                            '')
                        .toString();
                    final notes = (data['notes'] ?? '').toString();
                    final createdBy = (data['created_by'] ?? '').toString();
                    final updatedBy = (data['updated_by'] ?? '').toString();

                    return Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    email.isNotEmpty ? email : 'No email set',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                _StatusBadge(isActive: isActive),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                _InfoChip(label: 'Role', value: role),
                                _InfoChip(
                                  label: 'Employee No',
                                  value: employeeNumber,
                                ),
                                _InfoChip(
                                  label: 'Employee Name',
                                  value: employeeName,
                                ),
                                _InfoChip(label: 'Auth UID', value: authUid),
                                _InfoChip(label: 'Created By', value: createdBy),
                                _InfoChip(label: 'Updated By', value: updatedBy),
                              ],
                            ),
                            if (notes.trim().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(
                                'Notes: $notes',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _openUserDialog(
                                    documentId: doc.id,
                                    existingData: data,
                                  ),
                                  icon: const Icon(Icons.edit_outlined),
                                  label: const Text('Edit'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _toggleUserStatus(
                                    documentId: doc.id,
                                    currentStatus: isActive,
                                  ),
                                  icon: Icon(
                                    isActive
                                        ? Icons.block_outlined
                                        : Icons.check_circle_outline,
                                  ),
                                  label: Text(
                                    isActive ? 'Deactivate' : 'Activate',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String userEmail;
  final VoidCallback onCreatePressed;

  const _HeaderCard({
    required this.userEmail,
    required this.onCreatePressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.admin_panel_settings_outlined, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'User Access Management',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Manage application login access, roles, and employee linkage from the users collection.',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Logged in as: $userEmail',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: onCreatePressed,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add User'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;

  const _InfoChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final displayValue = value.trim().isEmpty ? '-' : value.trim();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style.copyWith(fontSize: 13),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: displayValue),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;

  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.green.withValues(alpha: 0.10)
            : Colors.red.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: TextStyle(
          color: isActive ? Colors.green.shade800 : Colors.red.shade800,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmployeeLookupResult {
  final String documentId;
  final String employeeNumber;
  final String name;
  final String prefix;
  final String department;
  final String designation;

  const _EmployeeLookupResult({
    required this.documentId,
    required this.employeeNumber,
    required this.name,
    required this.prefix,
    required this.department,
    required this.designation,
  });

  String get displayCode {
    if (prefix.trim().isEmpty) {
      return employeeNumber;
    }
    return '$prefix-$employeeNumber';
  }
}
