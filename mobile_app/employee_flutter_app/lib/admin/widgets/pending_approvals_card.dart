import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class PendingApprovalsCard extends StatelessWidget {
  final VoidCallback onTap;

  const PendingApprovalsCard({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        final pendingCount = snapshot.data?.docs.length ?? 0;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final hasError = snapshot.hasError;

        return Card(
          elevation: 2,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: hasError ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.pending_actions_outlined,
                      color: Colors.orange,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pending Approvals',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (hasError)
                          Text(
                            'Failed to load pending users',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          )
                        else if (isLoading)
                          const Text('Loading...')
                        else if (pendingCount == 0)
                          const Text('No registrations waiting for approval')
                        else if (pendingCount == 1)
                          const Text('1 registration is waiting for approval')
                        else
                          Text('$pendingCount registrations are waiting for approval'),
                      ],
                    ),
                  ),
                  if (isLoading)
                    const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  else
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: pendingCount > 0
                          ? Colors.orange.withValues(alpha: 0.14)
                          : Colors.grey.withValues(alpha: 0.12),
                      child: Text(
                        '$pendingCount',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: pendingCount > 0 ? Colors.orange : Colors.grey,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
