import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/event_attendance_response_model.dart';
import '../../models/event_model.dart';
import '../../services/event_attendance_service.dart';

class EventInvitationDetailScreen extends StatefulWidget {
  const EventInvitationDetailScreen({
    super.key,
    required this.eventId,
    required this.userUid,
    required this.employeeNumber,
    required this.employeeName,
    this.department = '',
    this.designation = '',
  });

  final String eventId;
  final String userUid;
  final String employeeNumber;
  final String employeeName;
  final String department;
  final String designation;

  @override
  State<EventInvitationDetailScreen> createState() =>
      _EventInvitationDetailScreenState();
}

class _EventInvitationDetailScreenState
    extends State<EventInvitationDetailScreen> {
  final EventAttendanceService _eventService = EventAttendanceService();

  final TextEditingController _employeeNoteController =
      TextEditingController();

  bool _loading = true;
  bool _saving = false;

  EventModel? _event;
  EventAttendanceResponseModel? _existingResponse;

  String _attendanceStatus = EventAttendanceResponseModel.statusAttending;

  final Map<String, int> _counts = <String, int>{
    for (final key in EventAttendanceResponseModel.categoryKeys) key: 0,
  };

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _employeeNoteController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _loading = true;
    });

    try {
      final event = await _eventService.getEventById(widget.eventId);
      final response = await _eventService.getEmployeeResponse(
        widget.eventId,
        widget.employeeNumber,
      );

      if (!mounted) return;

      if (event == null) {
        setState(() {
          _event = null;
          _existingResponse = null;
          _loading = false;
        });
        return;
      }

      _event = event;
      _existingResponse = response;

      if (response != null) {
        _attendanceStatus = response.attendanceStatus;
        _employeeNoteController.text = response.employeeNote;
        for (final key in EventAttendanceResponseModel.categoryKeys) {
          _counts[key] = response.counts[key] ?? 0;
        }
      } else {
        _attendanceStatus = EventAttendanceResponseModel.statusAttending;
        for (final key in EventAttendanceResponseModel.categoryKeys) {
          _counts[key] = 0;
        }
        _counts['employee'] = 1;
        _employeeNoteController.clear();
      }

      setState(() {
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load event: $e')),
      );
    }
  }

  bool get _isAttending =>
      _attendanceStatus == EventAttendanceResponseModel.statusAttending;

  bool get _isReadOnly {
    final event = _event;
    if (event == null) return true;

    if (!event.isResponseWindowOpen()) return true;

    if (_existingResponse?.submissionLocked == true) return true;

    if (_existingResponse != null && !event.canEmployeeEditResponse()) {
      return true;
    }

    return false;
  }

  int get _computedTotal =>
      EventAttendanceResponseModel.calculateTotal(_counts);

  void _setAttendanceStatus(String value) {
    setState(() {
      _attendanceStatus = value;

      if (_attendanceStatus ==
          EventAttendanceResponseModel.statusNotAttending) {
        for (final key in EventAttendanceResponseModel.categoryKeys) {
          _counts[key] = 0;
        }
      } else {
        _counts['employee'] = 1;
      }
    });
  }

  void _updateCounter(String key, int delta) {
    if (_isReadOnly) return;
    if (!_isAttending) return;
    if (!EventAttendanceResponseModel.categoryKeys.contains(key)) return;

    setState(() {
      final current = _counts[key] ?? 0;
      final next = current + delta;

      if (key == 'employee') {
        _counts[key] = next <= 1 ? 1 : 1;
      } else {
        _counts[key] = next < 0 ? 0 : next;
      }
    });
  }

  Future<void> _submitResponse() async {
    final event = _event;
    if (event == null) return;

    if (_isReadOnly) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attendance response is no longer editable.'),
        ),
      );
      return;
    }

    if (_isAttending) {
      _counts['employee'] = 1;
    } else {
      for (final key in EventAttendanceResponseModel.categoryKeys) {
        _counts[key] = 0;
      }
    }

    final total = EventAttendanceResponseModel.calculateTotal(_counts);

    if (_attendanceStatus ==
            EventAttendanceResponseModel.statusAttending &&
        total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('At least one attendee is required.'),
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final response = EventAttendanceResponseModel(
        documentId: EventAttendanceResponseModel.buildDocumentId(
          eventId: event.eventId,
          employeeNumber: widget.employeeNumber,
        ),
        eventId: event.eventId,
        userUid: widget.userUid,
        employeeNumber: widget.employeeNumber,
        employeeName: widget.employeeName,
        department: widget.department,
        designation: widget.designation,
        attendanceStatus: _attendanceStatus,
        submittedAt: _existingResponse?.submittedAt,
        updatedAt: Timestamp.now(),
        submissionLocked: false,
        counts: Map<String, int>.from(_counts),
        totalAttendees: total,
        employeeNote: _employeeNoteController.text.trim(),
        responseVersion: _existingResponse?.responseVersion ?? 1,
        source: 'mobile_app',
        rawData: const <String, dynamic>{},
      );

      await _eventService.submitAttendanceResponse(response);

      if (!mounted) return;

      await _loadInitialData();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _existingResponse == null
                ? 'Attendance submitted successfully.'
                : 'Attendance updated successfully.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save attendance: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final event = _event;
    if (event == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Event Invitation')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Event not found.'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Invitation'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.displayTitle,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  if (event.subtitle.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(event.subtitle.trim()),
                  ],
                  const SizedBox(height: 12),
                  _InfoRow(
                    label: 'Event Type',
                    value: event.eventType.trim().isEmpty
                        ? 'Not set'
                        : event.eventType.trim(),
                  ),
                  _InfoRow(
                    label: 'Venue',
                    value: event.venue.trim().isEmpty
                        ? 'Not set'
                        : event.venue.trim(),
                  ),
                  _InfoRow(
                    label: 'Start',
                    value: _formatDateTime(event.startDateTime),
                  ),
                  _InfoRow(
                    label: 'End',
                    value: _formatDateTime(event.endDateTime),
                  ),
                  _InfoRow(
                    label: 'Attendance Cutoff',
                    value: _formatDateTime(event.responseCutoffDateTime),
                  ),
                  _InfoRow(
                    label: 'Status',
                    value: event.status.toUpperCase(),
                  ),
                  if (event.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      event.description.trim(),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  if (event.notesSnapshot.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Important Notes',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    ...event.notesSnapshot.map(
                      (note) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• '),
                            Expanded(child: Text(note.body.trim())),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (event.customNotice.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Custom Notice: ${event.customNotice.trim()}',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Attendance Response',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment<String>(
                        value:
                            EventAttendanceResponseModel.statusAttending,
                        label: Text('Attending'),
                        icon: Icon(Icons.check_circle_outline),
                      ),
                      ButtonSegment<String>(
                        value:
                            EventAttendanceResponseModel.statusNotAttending,
                        label: Text('Not Attending'),
                        icon: Icon(Icons.cancel_outlined),
                      ),
                    ],
                    selected: <String>{_attendanceStatus},
                    onSelectionChanged: _isReadOnly
                        ? null
                        : (selection) {
                            if (selection.isEmpty) return;
                            _setAttendanceStatus(selection.first);
                          },
                  ),
                  const SizedBox(height: 16),
                  if (_isAttending) ...[
                    ...EventAttendanceResponseModel.categoryKeys.map(
                      (key) => _CounterTile(
                        label: _readableCategoryLabel(key),
                        value: _counts[key] ?? 0,
                        readOnly: _isReadOnly || key == 'employee',
                        onIncrement: () => _updateCounter(key, 1),
                        onDecrement: () => _updateCounter(key, -1),
                      ),
                    ),
                  ] else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'You have marked this event as not attending.',
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _employeeNoteController,
                    readOnly: _isReadOnly,
                    decoration: const InputDecoration(
                      labelText: 'Optional Note',
                      hintText: 'Add any clarification if needed',
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text('Total Attendees: $_computedTotal')),
                      Chip(
                        label: Text(
                          _existingResponse == null
                              ? 'New Response'
                              : 'Version ${_existingResponse!.responseVersion}',
                        ),
                      ),
                      if (_isReadOnly)
                        const Chip(label: Text('Read Only')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_existingResponse?.submittedAt != null)
                    Text(
                      'Submitted: ${_formatTimestamp(_existingResponse!.submittedAt)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (_existingResponse?.updatedAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Updated: ${_formatTimestamp(_existingResponse!.updatedAt)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: (_saving || _isReadOnly)
                              ? null
                              : _submitResponse,
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(
                            _existingResponse == null
                                ? 'Submit Attendance'
                                : 'Update Attendance',
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_isReadOnly) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Attendance is closed or no longer editable for this event.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
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

  static String _formatTimestamp(Timestamp? value) {
    if (value == null) return 'Not available';
    return _formatDateTime(value.toDate());
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _CounterTile extends StatelessWidget {
  const _CounterTile({
    required this.label,
    required this.value,
    required this.readOnly,
    required this.onIncrement,
    required this.onDecrement,
  });

  final String label;
  final int value;
  final bool readOnly;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            IconButton(
              onPressed: readOnly || value <= 0 ? null : onDecrement,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            SizedBox(
              width: 28,
              child: Text(
                value.toString(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            IconButton(
              onPressed: readOnly ? null : onIncrement,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ),
    );
  }
}

String _readableCategoryLabel(String key) {
  switch (key) {
    case 'employee':
      return 'Employee';
    case 'spouse':
      return 'Spouse';
    case 'kids_above_12':
      return 'Kids Above 12 Years';
    case 'kids_below_12':
      return 'Kids Below 12 Years';
    case 'permanent_resident_guests_adults':
      return 'Permanent Resident Guests (Adults)';
    case 'permanent_resident_guests_children_above_12':
      return 'Permanent Resident Guests (Children Above 12 Years)';
    case 'permanent_resident_guests_children_below_12':
      return 'Permanent Resident Guests (Children Below 12 Years)';
    case 'visiting_guests_adults':
      return 'Visiting Guests (Adults)';
    case 'visiting_guests_children_above_12':
      return 'Visiting Guests (Children Above 12 Years)';
    case 'visiting_guests_children_below_12':
      return 'Visiting Guests (Children Below 12 Years)';
    default:
      return key;
  }
}

