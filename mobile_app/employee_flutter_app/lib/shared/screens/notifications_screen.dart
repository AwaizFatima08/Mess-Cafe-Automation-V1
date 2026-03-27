import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/notification_service.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({
    super.key,
    required this.userUid,
    this.isAdminView = false,
  });

  final String userUid;
  final bool isAdminView;

  @override
  Widget build(BuildContext context) {
    if (isAdminView) {
      return _AdminNotificationsScreen(userUid: userUid);
    }

    return _EmployeeNotificationsScreen(userUid: userUid);
  }
}

class _EmployeeNotificationsScreen extends StatefulWidget {
  const _EmployeeNotificationsScreen({
    required this.userUid,
  });

  final String userUid;

  @override
  State<_EmployeeNotificationsScreen> createState() =>
      _EmployeeNotificationsScreenState();
}

class _EmployeeNotificationsScreenState
    extends State<_EmployeeNotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  bool _markingAll = false;

  Future<void> _markAllAsRead() async {
    setState(() {
      _markingAll = true;
    });

    try {
      await _notificationService.markAllVisibleAsRead(
        userUid: widget.userUid,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All visible notifications marked as read.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mark all as read: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _markingAll = false;
        });
      }
    }
  }

  Future<void> _markSingleAsRead(String deliveryId) async {
    try {
      await _notificationService.markDeliveryAsRead(deliveryId: deliveryId);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton.icon(
            onPressed: _markingAll ? null : _markAllAsRead,
            icon: _markingAll
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.done_all),
            label: const Text('Mark all read'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _notificationService.userDeliveriesStream(
          userUid: widget.userUid,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Failed to load notifications: ${snapshot.error}'),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? const [];

          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No notifications available yet.'),
              ),
            );
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();

              final title = (data['title_snapshot'] ?? '').toString().trim();
              final body = (data['body_snapshot'] ?? '').toString().trim();
              final type = (data['type'] ?? '').toString().trim();
              final status =
                  (data['in_app_status'] ?? '').toString().trim().toLowerCase();
              final isUnread = status == 'pending' || status == 'visible';
              final createdAt = data['created_at'];
              final createdAtLabel = _formatTimestamp(createdAt);

              return ListTile(
                tileColor: isUnread
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                leading: CircleAvatar(
                  child: Icon(_iconForType(type)),
                ),
                title: Text(
                  title.isEmpty ? 'Notification' : title,
                  style: TextStyle(
                    fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(body),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      createdAtLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                trailing: isUnread
                    ? const Icon(Icons.mark_email_unread_outlined)
                    : const Icon(Icons.done),
                onTap: () async {
                  if (isUnread) {
                    await _markSingleAsRead(doc.id);
                  }
                },
              );
            },
          );
        },
      ),
    );
  }

  String _formatTimestamp(dynamic value) {
    if (value is Timestamp) {
      final dt = value.toDate();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year.toString();
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$day-$month-$year $hour:$minute';
    }
    return 'Unknown time';
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'meal_booking_confirmed':
        return Icons.check_circle_outline;
      case 'meal_booking_cancelled':
        return Icons.cancel_outlined;
      case 'meal_issued':
        return Icons.restaurant_outlined;
      case 'menu_item_announcement':
        return Icons.restaurant_menu_outlined;
      case 'menu_cycle_announcement':
        return Icons.calendar_month_outlined;
      case 'special_event_announcement':
        return Icons.event_outlined;
      case 'club_announcement':
        return Icons.campaign_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }
}

class _AdminNotificationsScreen extends StatelessWidget {
  const _AdminNotificationsScreen({
    required this.userUid,
  });

  final String userUid;

  @override
  Widget build(BuildContext context) {
    final NotificationService notificationService = NotificationService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification History'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: notificationService.adminNotificationsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Failed to load notification history: ${snapshot.error}'),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? const [];

          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No notifications available yet.'),
              ),
            );
          }

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final title = (data['title'] ?? '').toString().trim();
              final body = (data['body'] ?? '').toString().trim();
              final type = (data['type'] ?? '').toString().trim();
              final layer =
                  (data['notification_layer'] ?? '').toString().trim();
              final status = (data['status'] ?? '').toString().trim();
              final createdAtLabel =
                  _formatTimestamp(data['created_at']);

              return ListTile(
                leading: CircleAvatar(
                  child: Icon(_iconForType(type)),
                ),
                title: Text(title.isEmpty ? 'Notification' : title),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(body),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _pill(context, layer.isEmpty ? 'unknown' : layer),
                        _pill(context, status.isEmpty ? 'unknown' : status),
                        _pill(context, createdAtLabel),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatTimestamp(dynamic value) {
    if (value is Timestamp) {
      final dt = value.toDate();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year.toString();
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$day-$month-$year $hour:$minute';
    }
    return 'Unknown time';
  }

  Widget _pill(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'meal_booking_confirmed':
        return Icons.check_circle_outline;
      case 'meal_booking_cancelled':
        return Icons.cancel_outlined;
      case 'meal_issued':
        return Icons.restaurant_outlined;
      case 'menu_item_announcement':
        return Icons.restaurant_menu_outlined;
      case 'menu_cycle_announcement':
        return Icons.calendar_month_outlined;
      case 'special_event_announcement':
        return Icons.event_outlined;
      case 'club_announcement':
        return Icons.campaign_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }
}
