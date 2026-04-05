import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EmployeeMasterManagementScreen extends StatefulWidget {
  final String userEmail;

  const EmployeeMasterManagementScreen({
    super.key,
    required this.userEmail,
  });

  @override
  State<EmployeeMasterManagementScreen> createState() =>
      _EmployeeMasterManagementScreenState();
}

class _EmployeeMasterManagementScreenState
    extends State<EmployeeMasterManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _employeeNumberController =
      TextEditingController();
  final TextEditingController _employeeNameController = TextEditingController();
  final TextEditingController _employeeEmailController = TextEditingController();
  final TextEditingController _employeeCnicLast4Controller =
      TextEditingController();

  final FocusNode _employeeNumberFocusNode = FocusNode();
  final FocusNode _employeeNameFocusNode = FocusNode();
  final FocusNode _employeeEmailFocusNode = FocusNode();
  final FocusNode _employeeCnicLast4FocusNode = FocusNode();

  bool _newEmployeeIsActive = true;
  bool _isSavingEmployeeMaster = false;
  String? _employeeMasterMessage;
  String? _editingEmployeeNumber;

  CollectionReference<Map<String, dynamic>> get _employeesRef =>
      _firestore.collection('employees');

  CollectionReference<Map<String, dynamic>> get _employeeProfilesRef =>
      _firestore.collection('employee_profiles');

  @override
  void dispose() {
    _employeeNumberController.dispose();
    _employeeNameController.dispose();
    _employeeEmailController.dispose();
    _employeeCnicLast4Controller.dispose();

    _employeeNumberFocusNode.dispose();
    _employeeNameFocusNode.dispose();
    _employeeEmailFocusNode.dispose();
    _employeeCnicLast4FocusNode.dispose();

    super.dispose();
  }

  void _resetEmployeeMasterForm() {
    _employeeNumberController.clear();
    _employeeNameController.clear();
    _employeeEmailController.clear();
    _employeeCnicLast4Controller.clear();
    _newEmployeeIsActive = true;
    _employeeMasterMessage = null;
    _editingEmployeeNumber = null;

    if (mounted) {
      setState(() {});
    }
  }

  void _loadEmployeeMasterForEdit(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    _employeeNumberController.text = doc.id;
    _employeeNameController.text = _resolveEmployeeName(data);
    _employeeEmailController.text = (data['email'] ?? '').toString().trim();
    _employeeCnicLast4Controller.text =
        (data['cnic_last_4'] ?? '').toString().trim();
    _newEmployeeIsActive = data['is_active'] == true;
    _editingEmployeeNumber = doc.id;
    _employeeMasterMessage = null;

    setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _employeeNameFocusNode.requestFocus();
    });
  }

  Future<void> _saveEmployeeMaster() async {
    final employeeNumber = _employeeNumberController.text.trim().toUpperCase();
    final employeeName = _employeeNameController.text.trim();
    final employeeEmail = _employeeEmailController.text.trim().toLowerCase();
    final cnicLast4 = _employeeCnicLast4Controller.text.trim();

    if (employeeNumber.isEmpty) {
      setState(() {
        _employeeMasterMessage = 'Employee number is required.';
      });
      return;
    }

    if (employeeName.isEmpty) {
      setState(() {
        _employeeMasterMessage = 'Employee name is required.';
      });
      return;
    }

    if (employeeEmail.isEmpty) {
      setState(() {
        _employeeMasterMessage = 'Official email is required.';
      });
      return;
    }

    if (cnicLast4.length != 4) {
      setState(() {
        _employeeMasterMessage = 'CNIC last 4 digits must be exactly 4.';
      });
      return;
    }

    try {
      setState(() {
        _isSavingEmployeeMaster = true;
        _employeeMasterMessage = null;
      });

      final duplicateEmailSnapshot =
          await _employeesRef.where('email', isEqualTo: employeeEmail).get();

      for (final doc in duplicateEmailSnapshot.docs) {
        if (doc.id != employeeNumber) {
          setState(() {
            _isSavingEmployeeMaster = false;
            _employeeMasterMessage =
                'Another employee master record already uses this email.';
          });
          return;
        }
      }

      final existingDoc = await _employeesRef.doc(employeeNumber).get();
      final now = FieldValue.serverTimestamp();

      await _employeesRef.doc(employeeNumber).set({
        'employee_number': employeeNumber,
        'name': employeeName,
        'employee_name': employeeName,
        'display_name': employeeName,
        'email': employeeEmail,
        'cnic_last_4': cnicLast4,
        'is_active': _newEmployeeIsActive,
        'status': _newEmployeeIsActive ? 'active' : 'inactive',
        if (!existingDoc.exists) 'created_at': now,
        'updated_at': now,
      }, SetOptions(merge: true));

      await _syncExistingEmployeeProfileFromMaster(
        employeeNumber: employeeNumber,
        employeeName: employeeName,
        employeeEmail: employeeEmail,
        isActive: _newEmployeeIsActive,
      );

      if (!mounted) return;

      final wasEdit = _editingEmployeeNumber != null;

      setState(() {
        _isSavingEmployeeMaster = false;
        _employeeMasterMessage = wasEdit
            ? 'Employee master record updated successfully.'
            : 'Employee master record created successfully.';
      });

      _resetEmployeeMasterForm();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasEdit
                ? 'Employee master updated successfully.'
                : 'Employee master created successfully.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSavingEmployeeMaster = false;
        _employeeMasterMessage = 'Failed to save employee master: $e';
      });
    }
  }

  Future<void> _toggleEmployeeMasterStatus(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final employeeNumber = doc.id;
    final employeeName = _resolveEmployeeName(data);
    final employeeEmail = (data['email'] ?? '').toString().trim().toLowerCase();
    final currentlyActive = data['is_active'] == true;
    final nextActive = !currentlyActive;

    try {
      await doc.reference.update({
        'is_active': nextActive,
        'status': nextActive ? 'active' : 'inactive',
        'updated_at': FieldValue.serverTimestamp(),
      });

      await _syncExistingEmployeeProfileFromMaster(
        employeeNumber: employeeNumber,
        employeeName: employeeName,
        employeeEmail: employeeEmail,
        isActive: nextActive,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextActive
                ? 'Employee master activated.'
                : 'Employee master deactivated.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update employee master: $e'),
        ),
      );
    }
  }

  Future<void> _syncExistingEmployeeProfileFromMaster({
    required String employeeNumber,
    required String employeeName,
    required String employeeEmail,
    required bool isActive,
  }) async {
    final profileDoc = await _employeeProfilesRef.doc(employeeNumber).get();

    if (!profileDoc.exists) {
      return;
    }

    await _employeeProfilesRef.doc(employeeNumber).set({
      'employee_number': employeeNumber,
      'display_name': employeeName,
      'employee_name': employeeName,
      'email': employeeEmail,
      'is_active': isActive,
      'updated_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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

    final name = (data['name'] ?? '').toString().trim();
    return name;
  }

  Widget _buildEmployeeMasterFormCard() {
    final isEditMode = _editingEmployeeNumber != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEditMode
                  ? 'Edit Employee Master Record'
                  : 'Add Employee Master Record',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Manage employee master records required before employee signup. Existing employee profiles, if already present, will be kept aligned for overlapping fields only.',
            ),
            if (isEditMode) ...[
              const SizedBox(height: 8),
              Text(
                'Editing employee: $_editingEmployeeNumber',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed:
                    _isSavingEmployeeMaster ? null : _resetEmployeeMasterForm,
                icon: const Icon(Icons.close),
                label: const Text('Cancel Edit'),
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _employeeNumberController,
                    focusNode: _employeeNumberFocusNode,
                    textCapitalization: TextCapitalization.characters,
                    enabled: !_isSavingEmployeeMaster && !isEditMode,
                    decoration: const InputDecoration(
                      labelText: 'Employee Number',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: _employeeNameController,
                    focusNode: _employeeNameFocusNode,
                    enabled: !_isSavingEmployeeMaster,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Employee Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: _employeeEmailController,
                    focusNode: _employeeEmailFocusNode,
                    enabled: !_isSavingEmployeeMaster,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Official Email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _employeeCnicLast4Controller,
                    focusNode: _employeeCnicLast4FocusNode,
                    enabled: !_isSavingEmployeeMaster,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: const InputDecoration(
                      labelText: 'CNIC Last 4',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _newEmployeeIsActive,
              title: const Text('Employee Master Active'),
              subtitle: Text(
                _newEmployeeIsActive
                    ? 'Employee can pass active-master validation'
                    : 'Employee master will remain inactive',
              ),
              onChanged: _isSavingEmployeeMaster
                  ? null
                  : (value) {
                      setState(() {
                        _newEmployeeIsActive = value;
                      });
                    },
            ),
            if (_employeeMasterMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _employeeMasterMessage!,
                style: TextStyle(
                  color: _employeeMasterMessage!
                              .toLowerCase()
                              .contains('successfully') ||
                          _employeeMasterMessage!
                              .toLowerCase()
                              .contains('created') ||
                          _employeeMasterMessage!
                              .toLowerCase()
                              .contains('updated')
                      ? Colors.green
                      : Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSavingEmployeeMaster ? null : _saveEmployeeMaster,
                icon: _isSavingEmployeeMaster
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  _isSavingEmployeeMaster
                      ? 'Saving...'
                      : isEditMode
                          ? 'Update Employee Master'
                          : 'Create Employee Master',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeMasterListCard() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _employeesRef.orderBy('employee_name').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Failed to load employee master records: ${snapshot.error}',
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Employee Master Records',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Total employee master records: ${docs.length}'),
                const SizedBox(height: 12),
                if (docs.isEmpty)
                  const Text('No employee master records found.')
                else
                  ...docs.map((doc) {
                    final data = doc.data();
                    final resolvedName = _resolveEmployeeName(data);
                    final employeeName = resolvedName.isEmpty
                        ? '(Unnamed Employee)'
                        : resolvedName;
                    final email = (data['email'] ?? '').toString().trim();
                    final cnicLast4 =
                        (data['cnic_last_4'] ?? '').toString().trim();
                    final isActive = data['is_active'] == true;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  employeeName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Chip(
                                  label: Text(isActive ? 'Active' : 'Inactive'),
                                  backgroundColor: isActive
                                      ? Colors.green.withValues(alpha: 0.12)
                                      : Colors.orange.withValues(alpha: 0.12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Employee Number: ${doc.id}'),
                            Text('Official Email: $email'),
                            Text('CNIC Last 4: $cnicLast4'),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _loadEmployeeMasterForEdit(doc),
                                  icon: const Icon(Icons.edit),
                                  label: const Text('Edit'),
                                ),
                                OutlinedButton.icon(
                                  onPressed: () => _toggleEmployeeMasterStatus(doc),
                                  icon: Icon(
                                    isActive
                                        ? Icons.visibility_off
                                        : Icons.visibility,
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
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Employee Master Management',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Signed in as: ${widget.userEmail}'),
                  const SizedBox(height: 4),
                  const Text(
                    'Manage business master records required before employee signup.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildEmployeeMasterFormCard(),
          const SizedBox(height: 16),
          _buildEmployeeMasterListCard(),
        ],
      ),
    );
  }
}
