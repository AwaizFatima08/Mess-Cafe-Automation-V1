import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserManagementScreen extends StatelessWidget {
  final String userEmail;

  const UserManagementScreen({super.key, required this.userEmail});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Management'),
      ),
      body: Column(
        children: [
          _HeaderCard(userEmail: userEmail),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('employees')
                  .orderBy('employee_number')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Error loading employees: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Center(
                    child: Text('No employee records found.'),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;

                    final prefix = (data['prefix'] ?? '').toString();
                    final employeeNumber =
                        (data['employee_number'] ?? '').toString();
                    final name = (data['name'] ?? '').toString();
                    final department = (data['department'] ?? '').toString();
                    final designation =
                        (data['designation'] ?? '').toString();
                    final grade = (data['grade'] ?? '').toString();
                    final status = (data['status'] ?? '').toString();
                    final houseType = (data['house_type'] ?? '').toString();
                    final houseNumber =
                        (data['house_number'] ?? '').toString();
                    final extension =
                        (data['landline_extension'] ?? '').toString();
                    final phoneNumber =
                        (data['phone_number'] ?? '').toString();
                    final userRole = (data['user_role'] ?? '').toString();

                    final employeeCode = prefix.isNotEmpty
                        ? '$prefix-$employeeNumber'
                        : employeeNumber;

                    return Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.isNotEmpty ? name : 'Unnamed Employee',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              children: [
                                _InfoChip(
                                  label: 'Emp No',
                                  value: employeeCode,
                                ),
                                _InfoChip(
                                  label: 'Department',
                                  value: department,
                                ),
                                _InfoChip(
                                  label: 'Designation',
                                  value: designation,
                                ),
                                _InfoChip(
                                  label: 'Grade',
                                  value: grade,
                                ),
                                _InfoChip(
                                  label: 'Role',
                                  value: userRole,
                                ),
                                _InfoChip(
                                  label: 'Status',
                                  value: status,
                                ),
                                _InfoChip(
                                  label: 'House Type',
                                  value: houseType,
                                ),
                                _InfoChip(
                                  label: 'House No',
                                  value: houseNumber,
                                ),
                                _InfoChip(
                                  label: 'Extension',
                                  value: extension,
                                ),
                                _InfoChip(
                                  label: 'Phone',
                                  value: phoneNumber,
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

  const _HeaderCard({required this.userEmail});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.people_outline, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Employee Management',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Live employee master data from Firestore',
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Logged in as: $userEmail',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
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
