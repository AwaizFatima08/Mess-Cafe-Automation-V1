import 'package:flutter/material.dart';

import '../../models/event_attendance_response_model.dart';
import '../../models/event_model.dart';
import '../../services/event_attendance_service.dart';
import '../screens/event_invitation_detail_screen.dart';

class EmployeeEventInvitationsSection extends StatelessWidget {
  const EmployeeEventInvitationsSection({
    super.key,
    required this.userUid,
    required this.employeeNumber,
    required this.employeeName,
    this.department = '',
    this.designation = '',
    this.maxItems = 5,
  });

  final String userUid;
  final String employeeNumber;
  final String employeeName;
  final String department;
  final String designation;
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    final EventAttendanceService eventService = EventAttendanceService();

    return StreamBuilder<List<EventModel>>(
      stream: eventService.watchEmployeeVisibleEvents(),
      builder: (context, eventSnapshot) {
        if (eventSnapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Expanded(child: Text('Loading event invitations...')),
                ],
              ),
            ),
          );
        }

        if (eventSnapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Failed to load event invitations: ${eventSnapshot.error}',
              ),
            ),
          );
        }

        final List<EventModel> visibleEvents =
            eventSnapshot.data ?? const <EventModel>[];

        if (visibleEvents.isEmpty) {
          return const SizedBox.shrink();
        }

        final List<EventModel> limitedEvents =
            visibleEvents.take(maxItems).toList(growable: false);

        return Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.event_available_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Event Invitations',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Respond to upcoming events before cutoff time.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                ...limitedEvents.map(
                  (event) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _EmployeeEventInvitationCard(
                      event: event,
                      userUid: userUid,
                      employeeNumber: employeeNumber,
                      employeeName: employeeName,
                      department: department,
                      designation: designation,
                      eventService: eventService,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmployeeEventInvitationCard extends StatelessWidget {
  const _EmployeeEventInvitationCard({
    required this.event,
    required this.userUid,
    required this.employeeNumber,
    required this.employeeName,
    required this.department,
    required this.designation,
    required this.eventService,
  });

  final EventModel event;
  final String userUid;
  final String employeeNumber;
  final String employeeName;
  final String department;
  final String designation;
  final EventAttendanceService eventService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<EventAttendanceResponseModel?>(
      stream: eventService.watchEmployeeResponse(
        event.eventId,
        employeeNumber,
      ),
      builder: (context, responseSnapshot) {
        final EventAttendanceResponseModel? response = responseSnapshot.data;

        final _EmployeeEventCardState cardState = _resolveState(
          event: event,
          response: response,
        );

        return Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.displayTitle,
                        style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                    ),
                    _StatusPill(
                      label: cardState.label,
                      variant: cardState.variant,
                    ),
                  ],
                ),
                if (event.subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(event.subtitle.trim()),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _MiniInfo(
                      icon: Icons.schedule_outlined,
                      label: _formatDateTime(event.startDateTime),
                    ),
                    _MiniInfo(
                      icon: Icons.lock_clock_outlined,
                      label:
                          'Cutoff: ${_formatDateTime(event.responseCutoffDateTime)}',
                    ),
                    _MiniInfo(
                      icon: Icons.place_outlined,
                      label: event.venue.trim().isEmpty
                          ? 'Venue not set'
                          : event.venue.trim(),
                    ),
                  ],
                ),
                if (response != null) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(
                        label: Text(
                          response.attendanceStatus ==
                                  EventAttendanceResponseModel.statusAttending
                              ? 'Attending'
                              : 'Not Attending',
                        ),
                      ),
                      Chip(
                        label: Text('Total: ${response.totalAttendees}'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => _openEvent(context),
                        icon: Icon(cardState.icon),
                        label: Text(cardState.actionText),
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
  }

  _EmployeeEventCardState _resolveState({
    required EventModel event,
    required EventAttendanceResponseModel? response,
  }) {
    if (event.isCancelled) {
      return const _EmployeeEventCardState(
        label: 'Cancelled',
        actionText: 'View',
        icon: Icons.visibility_outlined,
        variant: _StatusPillVariant.error,
      );
    }

    if (event.isClosed || !event.isResponseWindowOpen()) {
      if (response == null) {
        return const _EmployeeEventCardState(
          label: 'Closed',
          actionText: 'View',
          icon: Icons.visibility_outlined,
          variant: _StatusPillVariant.neutral,
        );
      }

      return const _EmployeeEventCardState(
        label: 'Submitted',
        actionText: 'View',
        icon: Icons.visibility_outlined,
        variant: _StatusPillVariant.success,
      );
    }

    if (response == null) {
      return const _EmployeeEventCardState(
        label: 'Pending Response',
        actionText: 'Respond Now',
        icon: Icons.edit_outlined,
        variant: _StatusPillVariant.primary,
      );
    }

    return const _EmployeeEventCardState(
      label: 'Submitted',
      actionText: 'Update Response',
      icon: Icons.edit_note_outlined,
      variant: _StatusPillVariant.success,
    );
  }

  Future<void> _openEvent(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventInvitationDetailScreen(
          eventId: event.eventId,
          userUid: userUid,
          employeeNumber: employeeNumber,
          employeeName: employeeName,
          department: department,
          designation: designation,
        ),
      ),
    );
  }

  static String _formatDateTime(DateTime? value) {
    if (value == null) return 'Not set';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day-$month-$year $hour:$minute';
  }
}

class _EmployeeEventCardState {
  const _EmployeeEventCardState({
    required this.label,
    required this.actionText,
    required this.icon,
    required this.variant,
  });

  final String label;
  final String actionText;
  final IconData icon;
  final _StatusPillVariant variant;
}

enum _StatusPillVariant {
  primary,
  success,
  error,
  neutral,
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.variant,
  });

  final String label;
  final _StatusPillVariant variant;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    late final Color background;
    late final Color foreground;

    switch (variant) {
      case _StatusPillVariant.primary:
        background = scheme.primaryContainer;
        foreground = scheme.onPrimaryContainer;
        break;
      case _StatusPillVariant.success:
        background = scheme.secondaryContainer;
        foreground = scheme.onSecondaryContainer;
        break;
      case _StatusPillVariant.error:
        background = scheme.errorContainer;
        foreground = scheme.onErrorContainer;
        break;
      case _StatusPillVariant.neutral:
        background = scheme.surfaceContainerHighest;
        foreground = scheme.onSurfaceVariant;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  const _MiniInfo({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
