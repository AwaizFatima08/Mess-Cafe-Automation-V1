import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/event_attendance_response_model.dart';
import '../../models/event_attendance_summary_model.dart';
import '../../models/event_model.dart';
import '../../models/event_note_template_model.dart';
import '../../services/event_attendance_service.dart';

class EventManagementScreen extends StatefulWidget {
  const EventManagementScreen({
    super.key,
    required this.currentUserUid,
    required this.currentEmployeeNumber,
    required this.currentUserName,
  });

  final String currentUserUid;
  final String currentEmployeeNumber;
  final String currentUserName;

  @override
  State<EventManagementScreen> createState() => _EventManagementScreenState();
}

class _EventManagementScreenState extends State<EventManagementScreen> {
  final EventAttendanceService _eventService = EventAttendanceService();

  String _statusFilter = 'all';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _seedDefaultNotes();
  }

  Future<void> _seedDefaultNotes() async {
    try {
      await _eventService.seedDefaultEventNotes();
    } catch (_) {}
  }

  Future<void> _openCreateDialog() async {
    final result = await showDialog<_EventFormResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _EventCreateEditDialog(
        currentUserUid: widget.currentUserUid,
        currentEmployeeNumber: widget.currentEmployeeNumber,
        currentUserName: widget.currentUserName,
        eventService: _eventService,
      ),
    );

    if (result == null) return;

    await _runGuardedAction(
      messageOnSuccess: result.publishNow
          ? 'Event created and published successfully.'
          : 'Event draft created successfully.',
      action: () async {
        final eventId = await _eventService.createEvent(result.event);
        if (result.publishNow) {
          await _eventService.publishEvent(eventId);
        }
      },
    );
  }

  Future<void> _openEditDialog(EventModel event) async {
    final result = await showDialog<_EventFormResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _EventCreateEditDialog(
        currentUserUid: widget.currentUserUid,
        currentEmployeeNumber: widget.currentEmployeeNumber,
        currentUserName: widget.currentUserName,
        eventService: _eventService,
        existingEvent: event,
      ),
    );

    if (result == null) return;

    await _runGuardedAction(
      messageOnSuccess: 'Event updated successfully.',
      action: () async {
        await _eventService.updateEvent(result.event);
        if (result.publishNow && event.status == EventModel.statusDraft) {
          await _eventService.publishEvent(event.eventId);
        }
      },
    );
  }

  Future<void> _publishEvent(EventModel event) async {
    final confirmed = await _confirmAction(
      title: 'Publish Event',
      message:
          'Publish "${event.displayTitle}" now? Employees will receive an in-app notification.',
    );

    if (!confirmed) return;

    await _runGuardedAction(
      messageOnSuccess: 'Event published successfully.',
      action: () => _eventService.publishEvent(event.eventId),
    );
  }

  Future<void> _closeEvent(EventModel event) async {
    final confirmed = await _confirmAction(
      title: 'Close Event',
      message:
          'Close "${event.displayTitle}" now? Attendance responses will be locked.',
    );

    if (!confirmed) return;

    await _runGuardedAction(
      messageOnSuccess: 'Event closed successfully.',
      action: () => _eventService.closeEvent(event.eventId),
    );
  }

  Future<void> _cancelEvent(EventModel event) async {
    final confirmed = await _confirmAction(
      title: 'Cancel Event',
      message:
          'Cancel "${event.displayTitle}"? This will stop further responses.',
    );

    if (!confirmed) return;

    await _runGuardedAction(
      messageOnSuccess: 'Event cancelled successfully.',
      action: () => _eventService.cancelEvent(event.eventId),
    );
  }

  Future<void> _viewPendingEmployees(EventModel event) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _PendingEmployeesSheet(
        event: event,
        eventService: _eventService,
      ),
    );
  }

  Future<void> _viewEventSummary(EventModel event) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _EventSummarySheet(
        event: event,
        eventService: _eventService,
      ),
    );
  }

  Future<void> _runGuardedAction({
    required Future<void> Function() action,
    required String messageOnSuccess,
  }) async {
    setState(() {
      _busy = true;
    });

    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(messageOnSuccess)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Operation failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  List<EventModel> _applyStatusFilter(List<EventModel> events) {
    if (_statusFilter == 'all') return events;
    return events.where((event) => event.status == _statusFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _openCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('Create Event'),
      ),
      body: Column(
        children: [
          _TopControlBar(
            statusFilter: _statusFilter,
            onFilterChanged: (value) {
              setState(() {
                _statusFilter = value;
              });
            },
          ),
          Expanded(
            child: StreamBuilder<List<EventModel>>(
              stream: _eventService.watchAdminEvents(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Failed to load events: ${snapshot.error}'),
                    ),
                  );
                }

                final allEvents = snapshot.data ?? const <EventModel>[];
                final filteredEvents = _applyStatusFilter(allEvents);

                if (filteredEvents.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No events found for the selected filter.'),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                  itemCount: filteredEvents.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final event = filteredEvents[index];
                    return _EventManagementCard(
                      event: event,
                      busy: _busy,
                      onEdit:
                          event.isDraft ? () => _openEditDialog(event) : null,
                      onPublish:
                          event.isDraft ? () => _publishEvent(event) : null,
                      onClose:
                          event.isPublished ? () => _closeEvent(event) : null,
                      onCancel: (event.isDraft || event.isPublished)
                          ? () => _cancelEvent(event)
                          : null,
                      onViewSummary: () => _viewEventSummary(event),
                      onViewPending: () => _viewPendingEmployees(event),
                      summaryStream:
                          _eventService.watchEventSummary(event.eventId),
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

class _TopControlBar extends StatelessWidget {
  const _TopControlBar({
    required this.statusFilter,
    required this.onFilterChanged,
  });

  final String statusFilter;
  final ValueChanged<String> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final filters = <String, String>{
      'all': 'All',
      EventModel.statusDraft: 'Draft',
      EventModel.statusPublished: 'Published',
      EventModel.statusClosed: 'Closed',
      EventModel.statusCancelled: 'Cancelled',
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: filters.entries.map((entry) {
          return ChoiceChip(
            label: Text(entry.value),
            selected: statusFilter == entry.key,
            onSelected: (_) => onFilterChanged(entry.key),
          );
        }).toList(),
      ),
    );
  }
}

class _EventManagementCard extends StatelessWidget {
  const _EventManagementCard({
    required this.event,
    required this.busy,
    required this.onEdit,
    required this.onPublish,
    required this.onClose,
    required this.onCancel,
    required this.onViewSummary,
    required this.onViewPending,
    required this.summaryStream,
  });

  final EventModel event;
  final bool busy;
  final VoidCallback? onEdit;
  final VoidCallback? onPublish;
  final VoidCallback? onClose;
  final VoidCallback? onCancel;
  final VoidCallback onViewSummary;
  final VoidCallback onViewPending;
  final Stream<EventAttendanceSummaryModel?> summaryStream;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<EventAttendanceSummaryModel?>(
          stream: summaryStream,
          builder: (context, snapshot) {
            final summary = snapshot.data;

            final responded =
                summary?.householdsResponded ?? event.householdsResponded;
            final pending =
                summary?.householdsPending ?? event.householdsPending;
            final total = summary?.grandTotal ?? event.grandTotalAttendees;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.displayTitle,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                    ),
                    _EventStatusBadge(status: event.status),
                  ],
                ),
                if (event.subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    event.subtitle.trim(),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _MiniInfo(
                      icon: Icons.event_outlined,
                      label: _formatDateTime(event.startDateTime),
                    ),
                    _MiniInfo(
                      icon: Icons.place_outlined,
                      label: event.venue.trim().isEmpty
                          ? 'Venue not set'
                          : event.venue.trim(),
                    ),
                    _MiniInfo(
                      icon: Icons.lock_clock_outlined,
                      label:
                          'Cutoff: ${_formatDateTime(event.responseCutoffDateTime)}',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SummaryChip(
                      label: 'Responded',
                      value: responded.toString(),
                    ),
                    _SummaryChip(
                      label: 'Pending',
                      value: pending.toString(),
                    ),
                    _SummaryChip(
                      label: 'Headcount',
                      value: total.toString(),
                    ),
                    _SummaryChip(
                      label: 'Target',
                      value: event.targetCountEstimate.toString(),
                    ),
                  ],
                ),
                if (event.customNotice.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Notice: ${event.customNotice.trim()}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (onEdit != null)
                      OutlinedButton.icon(
                        onPressed: busy ? null : onEdit,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit'),
                      ),
                    if (onPublish != null)
                      FilledButton.icon(
                        onPressed: busy ? null : onPublish,
                        icon: const Icon(Icons.publish_outlined),
                        label: const Text('Publish'),
                      ),
                    if (onClose != null)
                      FilledButton.tonalIcon(
                        onPressed: busy ? null : onClose,
                        icon: const Icon(Icons.lock_outline),
                        label: const Text('Close'),
                      ),
                    if (onCancel != null)
                      OutlinedButton.icon(
                        onPressed: busy ? null : onCancel,
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Cancel'),
                      ),
                    OutlinedButton.icon(
                      onPressed: onViewSummary,
                      icon: const Icon(Icons.analytics_outlined),
                      label: const Text('Report'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onViewPending,
                      icon: const Icon(Icons.pending_actions_outlined),
                      label: const Text('Pending'),
                    ),
                  ],
                ),
              ],
            );
          },
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
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Flexible(child: Text(label)),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label: $value'),
    );
  }
}

class _EventStatusBadge extends StatelessWidget {
  const _EventStatusBadge({
    required this.status,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color background;
    Color foreground;

    switch (status) {
      case EventModel.statusPublished:
        background = colorScheme.primaryContainer;
        foreground = colorScheme.onPrimaryContainer;
        break;
      case EventModel.statusClosed:
        background = colorScheme.secondaryContainer;
        foreground = colorScheme.onSecondaryContainer;
        break;
      case EventModel.statusCancelled:
        background = colorScheme.errorContainer;
        foreground = colorScheme.onErrorContainer;
        break;
      default:
        background = colorScheme.surfaceContainerHighest;
        foreground = colorScheme.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PendingEmployeesSheet extends StatelessWidget {
  const _PendingEmployeesSheet({
    required this.event,
    required this.eventService,
  });

  final EventModel event;
  final EventAttendanceService eventService;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: eventService.getPendingEmployees(event.eventId),
        builder: (context, snapshot) {
          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                    'Pending Employees — ${event.displayTitle}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Expanded(
                  child: Builder(
                    builder: (context) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Failed to load pending list: ${snapshot.error}',
                            ),
                          ),
                        );
                      }

                      final items =
                          snapshot.data ?? const <Map<String, dynamic>>[];
                      if (items.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('No pending employees found.'),
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final employeeNumber =
                              (item['employee_number'] ?? '').toString();
                          final employeeName =
                              (item['employee_name'] ?? '').toString();

                          return ListTile(
                            leading: const Icon(Icons.person_outline),
                            title: Text(
                              employeeName.isEmpty
                                  ? 'Unknown employee'
                                  : employeeName,
                            ),
                            subtitle: Text(employeeNumber),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EventSummarySheet extends StatefulWidget {
  const _EventSummarySheet({
    required this.event,
    required this.eventService,
  });

  final EventModel event;
  final EventAttendanceService eventService;

  @override
  State<_EventSummarySheet> createState() => _EventSummarySheetState();
}

class _EventSummarySheetState extends State<_EventSummarySheet> {
  bool _exporting = false;

  Future<void> _exportReport() async {
    if (_exporting) return;

    setState(() {
      _exporting = true;
    });

    try {
      final EventAttendanceSummaryModel? summary =
          await widget.eventService.getEventSummary(widget.event.eventId);

      final List<EventAttendanceResponseModel> responses =
          await widget.eventService
              .watchEventResponses(widget.event.eventId)
              .first;

      final List<Map<String, dynamic>> pendingEmployees =
          await widget.eventService.getPendingEmployees(widget.event.eventId);

      final Excel excel = Excel.createExcel();

      final String defaultSheetName = excel.getDefaultSheet() ?? 'Sheet1';
      if (excel.sheets.containsKey(defaultSheetName)) {
        excel.delete(defaultSheetName);
      }

      final Sheet summarySheet = excel[_safeSheetName('Summary')];
      final Sheet responsesSheet = excel[_safeSheetName('Responses')];
      final Sheet pendingSheet = excel[_safeSheetName('Pending')];

      _writeSummarySheet(
        sheet: summarySheet,
        event: widget.event,
        summary: summary,
        responses: responses,
        pendingEmployees: pendingEmployees,
      );

      _writeResponsesSheet(
        sheet: responsesSheet,
        responses: responses,
      );

      _writePendingSheet(
        sheet: pendingSheet,
        pendingEmployees: pendingEmployees,
      );

      final List<int>? bytes = excel.encode();
      if (bytes == null || bytes.isEmpty) {
        throw Exception('Failed to generate Excel workbook.');
      }

      final String fileName =
          'event_attendance_${_sanitizeFileName(widget.event.eventId)}_${_timestampForFile(DateTime.now())}.xlsx';

      final File outputFile = await _saveExportFile(
        bytes: bytes,
        fileName: fileName,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Attendance report exported: ${outputFile.path}'),
          duration: const Duration(seconds: 5),
        ),
      );

      await _openExportedFile(outputFile);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _exporting = false;
        });
      }
    }
  }

  Future<File> _saveExportFile({
    required List<int> bytes,
    required String fileName,
  }) async {
    final Directory appDir =
        await getExternalStorageDirectory() ??
            await getApplicationDocumentsDirectory();

    final File appFile = File('${appDir.path}/$fileName');
    await appFile.writeAsBytes(bytes, flush: true);

    if (!Platform.isAndroid) {
      return appFile;
    }

    final List<String> candidateDownloadPaths = <String>[
      '/storage/emulated/0/Download',
      '/storage/emulated/0/Downloads',
    ];

    for (final String path in candidateDownloadPaths) {
      try {
        final Directory dir = Directory(path);
        if (!await dir.exists()) {
          continue;
        }

        final File publicFile = File('${dir.path}/$fileName');
        await publicFile.writeAsBytes(bytes, flush: true);
        return publicFile;
      } catch (_) {}
    }

    return appFile;
  }

  Future<void> _openExportedFile(File file) async {
    final result = await OpenFilex.open(file.path);

    if (!mounted) return;

    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'File saved but could not be opened automatically: ${file.path}',
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _writeSummarySheet({
    required Sheet sheet,
    required EventModel event,
    required EventAttendanceSummaryModel? summary,
    required List<EventAttendanceResponseModel> responses,
    required List<Map<String, dynamic>> pendingEmployees,
  }) {
    int row = 0;

    _setCell(sheet, row, 0, 'Event Attendance Report');
    row++;

    _setCell(sheet, row, 0, 'Event ID');
    _setCell(sheet, row, 1, event.eventId);
    row++;

    _setCell(sheet, row, 0, 'Title');
    _setCell(sheet, row, 1, event.displayTitle);
    row++;

    _setCell(sheet, row, 0, 'Subtitle');
    _setCell(sheet, row, 1, event.subtitle.trim());
    row++;

    _setCell(sheet, row, 0, 'Status');
    _setCell(sheet, row, 1, event.status);
    row++;

    _setCell(sheet, row, 0, 'Venue');
    _setCell(sheet, row, 1, event.venue.trim());
    row++;

    _setCell(sheet, row, 0, 'Start');
    _setCell(sheet, row, 1, _formatDateTime(event.startDateTime));
    row++;

    _setCell(sheet, row, 0, 'Cutoff');
    _setCell(sheet, row, 1, _formatDateTime(event.responseCutoffDateTime));
    row++;

    _setCell(sheet, row, 0, 'Target Count');
    _setCell(sheet, row, 1, event.targetCountEstimate);
    row++;

    _setCell(sheet, row, 0, 'Generated At');
    _setCell(sheet, row, 1, _formatDateTime(DateTime.now()));
    row += 2;

    _setCell(sheet, row, 0, 'Summary Metrics');
    row++;

    _setCell(sheet, row, 0, 'Responded');
    _setCell(sheet, row, 1, summary?.householdsResponded ?? 0);
    row++;

    _setCell(sheet, row, 0, 'Pending');
    _setCell(sheet, row, 1, summary?.householdsPending ?? pendingEmployees.length);
    row++;

    _setCell(sheet, row, 0, 'Attending');
    _setCell(sheet, row, 1, summary?.householdsAttending ?? 0);
    row++;

    _setCell(sheet, row, 0, 'Not Attending');
    _setCell(sheet, row, 1, summary?.householdsNotAttending ?? 0);
    row++;

    _setCell(sheet, row, 0, 'Grand Total');
    _setCell(sheet, row, 1, summary?.grandTotal ?? 0);
    row += 2;

    _setCell(sheet, row, 0, 'Category');
    _setCell(sheet, row, 1, 'Count');
    row++;

    for (final String key in EventAttendanceSummaryModel.categoryKeys) {
      _setCell(sheet, row, 0, _readableCategoryLabel(key));
      _setCell(sheet, row, 1, summary?.categoryTotals[key] ?? 0);
      row++;
    }

    row += 2;
    _setCell(sheet, row, 0, 'Response Snapshot');
    row++;

    _setCell(sheet, row, 0, 'Total Responses Rows');
    _setCell(sheet, row, 1, responses.length);
    row++;

    _setCell(sheet, row, 0, 'Pending Employees Rows');
    _setCell(sheet, row, 1, pendingEmployees.length);
  }

  void _writeResponsesSheet({
    required Sheet sheet,
    required List<EventAttendanceResponseModel> responses,
  }) {
    final headers = <String>[
      'Employee Number',
      'Employee Name',
      'Attendance Status',
      'Total Attendees',
      'Employee',
      'Spouse',
      'Kids Above 12',
      'Kids Below 12',
      'Permanent Resident Guests Adults',
      'Permanent Resident Guests Children Above 12',
      'Permanent Resident Guests Children Below 12',
      'Visiting Guests Adults',
      'Visiting Guests Children Above 12',
      'Visiting Guests Children Below 12',
      'Submitted At',
      'Updated At',
      'Response Version',
      'Note',
      'Department',
      'Designation',
      'User UID',
    ];

    for (int col = 0; col < headers.length; col++) {
      _setCell(sheet, 0, col, headers[col]);
    }

    for (int i = 0; i < responses.length; i++) {
      final response = responses[i];
      final row = i + 1;

      _setCell(sheet, row, 0, response.employeeNumber);
      _setCell(sheet, row, 1, response.employeeName);
      _setCell(sheet, row, 2, response.attendanceStatus);
      _setCell(sheet, row, 3, response.totalAttendees);
      _setCell(sheet, row, 4, response.counts['employee'] ?? 0);
      _setCell(sheet, row, 5, response.counts['spouse'] ?? 0);
      _setCell(sheet, row, 6, response.counts['kids_above_12'] ?? 0);
      _setCell(sheet, row, 7, response.counts['kids_below_12'] ?? 0);
      _setCell(
        sheet,
        row,
        8,
        response.counts['permanent_resident_guests_adults'] ?? 0,
      );
      _setCell(
        sheet,
        row,
        9,
        response.counts['permanent_resident_guests_children_above_12'] ?? 0,
      );
      _setCell(
        sheet,
        row,
        10,
        response.counts['permanent_resident_guests_children_below_12'] ?? 0,
      );
      _setCell(sheet, row, 11, response.counts['visiting_guests_adults'] ?? 0);
      _setCell(
        sheet,
        row,
        12,
        response.counts['visiting_guests_children_above_12'] ?? 0,
      );
      _setCell(
        sheet,
        row,
        13,
        response.counts['visiting_guests_children_below_12'] ?? 0,
      );
      _setCell(sheet, row, 14, _formatTimestamp(response.submittedAt));
      _setCell(sheet, row, 15, _formatTimestamp(response.updatedAt));
      _setCell(sheet, row, 16, response.responseVersion);
      _setCell(sheet, row, 17, response.employeeNote);
      _setCell(sheet, row, 18, response.department);
      _setCell(sheet, row, 19, response.designation);
      _setCell(sheet, row, 20, response.userUid);
    }
  }

  void _writePendingSheet({
    required Sheet sheet,
    required List<Map<String, dynamic>> pendingEmployees,
  }) {
    _setCell(sheet, 0, 0, 'Employee Number');
    _setCell(sheet, 0, 1, 'Employee Name');
    _setCell(sheet, 0, 2, 'User UID');

    for (int i = 0; i < pendingEmployees.length; i++) {
      final row = i + 1;
      final item = pendingEmployees[i];

      _setCell(sheet, row, 0, (item['employee_number'] ?? '').toString());
      _setCell(sheet, row, 1, (item['employee_name'] ?? '').toString());
      _setCell(sheet, row, 2, (item['user_uid'] ?? '').toString());
    }
  }

  void _setCell(Sheet sheet, int row, int col, dynamic value) {
    final CellIndex index = CellIndex.indexByColumnRow(
      columnIndex: col,
      rowIndex: row,
    );

    if (value is int) {
      sheet.cell(index).value = IntCellValue(value);
      return;
    }

    if (value is double) {
      sheet.cell(index).value = DoubleCellValue(value);
      return;
    }

    if (value is bool) {
      sheet.cell(index).value = BoolCellValue(value);
      return;
    }

    sheet.cell(index).value = TextCellValue((value ?? '').toString());
  }

  String _safeSheetName(String value) {
    final cleaned = value.replaceAll(RegExp(r'[:\\/?*\[\]]'), '_').trim();

    if (cleaned.isEmpty) return 'Sheet';
    return cleaned.length <= 31 ? cleaned : cleaned.substring(0, 31);
  }

  String _sanitizeFileName(String value) {
    return value
        .replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .trim();
  }

  String _timestampForFile(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final second = value.second.toString().padLeft(2, '0');
    return '$year$month$day' '_$hour$minute$second';
  }

  String _formatTimestamp(Timestamp? value) {
    if (value == null) return '';
    return _formatDateTime(value.toDate());
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return '';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day-$month-$year $hour:$minute';
  }

  Widget _buildResponseSection(
    BuildContext context, {
    required String title,
    required List<EventAttendanceResponseModel> items,
    required bool isAttending,
  }) {
    final Color baseColor = isAttending ? Colors.green : Colors.red;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: baseColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        if (items.isEmpty)
          const Card(
            child: ListTile(
              title: Text('No records in this section.'),
            ),
          )
        else
          ...items.map((response) {
            return Card(
              child: ListTile(
                leading: Icon(
                  isAttending
                      ? Icons.check_circle_outline
                      : Icons.cancel_outlined,
                ),
                title: Text(
                  response.employeeName.trim().isEmpty
                      ? 'Unknown employee'
                      : response.employeeName.trim(),
                ),
                subtitle: Text(
                  '${response.employeeNumber} • Total: ${response.totalAttendees}',
                ),
                trailing: Text(
                  response.attendanceStatus ==
                          EventAttendanceResponseModel.statusAttending
                      ? 'ATTENDING'
                      : 'NOT ATTENDING',
                  style: TextStyle(
                    color: baseColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Event Report — ${widget.event.displayTitle}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _exporting ? null : _exportReport,
                    icon: _exporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_outlined),
                    label: Text(_exporting ? 'Exporting...' : 'Export XLSX'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<EventAttendanceSummaryModel?>(
                stream:
                    widget.eventService.watchEventSummary(widget.event.eventId),
                builder: (context, summarySnapshot) {
                  final summary = summarySnapshot.data;

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      if (summary == null)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: Text('No summary data available yet.'),
                        )
                      else ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _SummaryChip(
                              label: 'Responded',
                              value: summary.householdsResponded.toString(),
                            ),
                            _SummaryChip(
                              label: 'Pending',
                              value: summary.householdsPending.toString(),
                            ),
                            _SummaryChip(
                              label: 'Attending',
                              value: summary.householdsAttending.toString(),
                            ),
                            _SummaryChip(
                              label: 'Not Attending',
                              value: summary.householdsNotAttending.toString(),
                            ),
                            _SummaryChip(
                              label: 'Grand Total',
                              value: summary.grandTotal.toString(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Category Breakdown',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...EventAttendanceSummaryModel.categoryKeys.map((key) {
                          final value = summary.categoryTotals[key] ?? 0;
                          return Card(
                            child: ListTile(
                              title: Text(_readableCategoryLabel(key)),
                              trailing: Text(
                                value.toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 16),
                      ],
                      const Text(
                        'Responses (Live)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      StreamBuilder<List<EventAttendanceResponseModel>>(
                        stream: widget.eventService
                            .watchEventResponses(widget.event.eventId),
                        builder: (context, responseSnapshot) {
                          if (responseSnapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }

                          if (responseSnapshot.hasError) {
                            return Text(
                              'Failed to load responses: ${responseSnapshot.error}',
                            );
                          }

                          final responses = responseSnapshot.data ??
                              const <EventAttendanceResponseModel>[];

                          if (responses.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('No responses yet.'),
                            );
                          }

                          final attending = responses
                              .where(
                                (r) =>
                                    r.attendanceStatus ==
                                    EventAttendanceResponseModel.statusAttending,
                              )
                              .toList();

                          final notAttending = responses
                              .where(
                                (r) =>
                                    r.attendanceStatus !=
                                    EventAttendanceResponseModel.statusAttending,
                              )
                              .toList();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildResponseSection(
                                context,
                                title: 'Attending (${attending.length})',
                                items: attending,
                                isAttending: true,
                              ),
                              const SizedBox(height: 12),
                              _buildResponseSection(
                                context,
                                title: 'Not Attending (${notAttending.length})',
                                items: notAttending,
                                isAttending: false,
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventCreateEditDialog extends StatefulWidget {
  const _EventCreateEditDialog({
    required this.currentUserUid,
    required this.currentEmployeeNumber,
    required this.currentUserName,
    required this.eventService,
    this.existingEvent,
  });

  final String currentUserUid;
  final String currentEmployeeNumber;
  final String currentUserName;
  final EventAttendanceService eventService;
  final EventModel? existingEvent;

  @override
  State<_EventCreateEditDialog> createState() => _EventCreateEditDialogState();
}

class _EventCreateEditDialogState extends State<_EventCreateEditDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _subtitleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _venueController;
  late final TextEditingController _customNoticeController;
  late final TextEditingController _targetCountController;

  String _eventType = 'special';
  DateTime? _eventDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  DateTime? _cutoffDateTime;

  bool _allowEditUntilCutoff = true;
  bool _showOnEmployeeDashboard = true;
  bool _showPopupOnPublish = true;
  bool _publishNow = false;
  bool _loadingNotes = true;

  List<EventNoteTemplateModel> _availableNotes = <EventNoteTemplateModel>[];
  final Set<String> _selectedNoteIds = <String>{};

  bool get _isEditing => widget.existingEvent != null;

  @override
  void initState() {
    super.initState();

    final existing = widget.existingEvent;

    _titleController =
        TextEditingController(text: existing?.title.trim() ?? '');
    _subtitleController =
        TextEditingController(text: existing?.subtitle.trim() ?? '');
    _descriptionController =
        TextEditingController(text: existing?.description.trim() ?? '');
    _venueController =
        TextEditingController(text: existing?.venue.trim() ?? '');
    _customNoticeController =
        TextEditingController(text: existing?.customNotice.trim() ?? '');
    _targetCountController = TextEditingController(
      text: existing?.targetCountEstimate.toString() ?? '0',
    );

    _eventType = existing?.eventType.trim().isNotEmpty == true
        ? existing!.eventType.trim()
        : 'special';

    final start = existing?.startDateTime;
    if (start != null) {
      _eventDate = DateTime(start.year, start.month, start.day);
      _startTime = TimeOfDay(hour: start.hour, minute: start.minute);
    }

    final end = existing?.endDateTime;
    if (end != null) {
      _endTime = TimeOfDay(hour: end.hour, minute: end.minute);
    }

    _cutoffDateTime = existing?.responseCutoffDateTime;
    _allowEditUntilCutoff = existing?.allowEditUntilCutoff ?? true;
    _showOnEmployeeDashboard = existing?.showOnEmployeeDashboard ?? true;
    _showPopupOnPublish = existing?.showPopupOnPublish ?? true;

    _selectedNoteIds.addAll(existing?.selectedNoteIds ?? const <String>[]);

    _loadNotes();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _descriptionController.dispose();
    _venueController.dispose();
    _customNoticeController.dispose();
    _targetCountController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    try {
      final notes = await widget.eventService.getActiveNoteTemplates();
      if (!mounted) return;
      setState(() {
        _availableNotes = notes;
        _loadingNotes = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingNotes = false;
      });
    }
  }

  Future<void> _pickEventDate() async {
    final now = DateTime.now();
    final initial = _eventDate ?? now;
    final result = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );

    if (result == null) return;

    setState(() {
      _eventDate = DateTime(result.year, result.month, result.day);
      _cutoffDateTime ??=
          DateTime(result.year, result.month, result.day, 17, 0);
    });
  }

  Future<void> _pickStartTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: _startTime ?? const TimeOfDay(hour: 11, minute: 0),
    );

    if (result == null) return;

    setState(() {
      _startTime = result;
    });
  }

  Future<void> _pickEndTime() async {
    final result = await showTimePicker(
      context: context,
      initialTime: _endTime ?? const TimeOfDay(hour: 14, minute: 0),
    );

    if (result == null) return;

    setState(() {
      _endTime = result;
    });
  }

  Future<void> _pickCutoff() async {
    final now = DateTime.now();
    final initial = _cutoffDateTime ?? now;

    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );

    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );

    if (time == null) return;

    setState(() {
      _cutoffDateTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  DateTime? _combine(DateTime? date, TimeOfDay? time) {
    if (date == null || time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final start = _combine(_eventDate, _startTime);
    if (start == null) {
      _showMessage('Please select event date and start time.');
      return;
    }

    final end = _combine(_eventDate, _endTime);
    if (end != null && end.isBefore(start)) {
      _showMessage('End time must be after start time.');
      return;
    }

    if (_cutoffDateTime == null) {
      _showMessage('Please select attendance cutoff time.');
      return;
    }

    if (_cutoffDateTime!.isAfter(start)) {
      _showMessage('Attendance cutoff must be before event start time.');
      return;
    }

    final targetCount = int.tryParse(_targetCountController.text.trim()) ?? 0;
    final existing = widget.existingEvent;
    final eventDateOnly = DateTime(start.year, start.month, start.day);

    final documentId = existing?.documentId ??
        EventModel.buildEventDocumentId(
          slug: EventModel.buildSuggestedSlug(
            title: _titleController.text.trim(),
            eventDate: eventDateOnly,
          ),
        );

    final event = EventModel(
      documentId: documentId,
      eventId: documentId,
      title: _titleController.text.trim(),
      subtitle: _subtitleController.text.trim(),
      description: _descriptionController.text.trim(),
      eventType: _eventType.trim(),
      venue: _venueController.text.trim(),
      eventDate: Timestamp.fromDate(eventDateOnly),
      startAt: Timestamp.fromDate(start),
      endAt: end == null ? null : Timestamp.fromDate(end),
      responseCutoffAt: Timestamp.fromDate(_cutoffDateTime!),
      status: existing?.status ?? EventModel.statusDraft,
      createdByUid: existing?.createdByUid ?? widget.currentUserUid.trim(),
      createdByEmployeeNumber: existing?.createdByEmployeeNumber ??
          widget.currentEmployeeNumber.trim(),
      createdByName: existing?.createdByName ?? widget.currentUserName.trim(),
      createdAt: existing?.createdAt,
      updatedAt: existing?.updatedAt,
      publishedAt: existing?.publishedAt,
      closedAt: existing?.closedAt,
      cancelledAt: existing?.cancelledAt,
      dashboardPriority: existing?.dashboardPriority ?? 1,
      allowEditUntilCutoff: _allowEditUntilCutoff,
      showOnEmployeeDashboard: _showOnEmployeeDashboard,
      showPopupOnPublish: _showPopupOnPublish,
      selectedNoteIds: _selectedNoteIds.toList()..sort(),
      notesSnapshot: existing?.notesSnapshot ?? const <EventNoteSnapshot>[],
      customNotice: _customNoticeController.text.trim(),
      targetScope: 'all_active_employees',
      targetCountEstimate: targetCount,
      householdsResponded: existing?.householdsResponded ?? 0,
      householdsPending: existing?.householdsPending ?? targetCount,
      grandTotalAttendees: existing?.grandTotalAttendees ?? 0,
      reportLocked: existing?.reportLocked ?? false,
      isDeletedSoft: existing?.isDeletedSoft ?? false,
      rawData: existing?.rawData ?? const <String, dynamic>{},
    );

    Navigator.of(context).pop(
      _EventFormResult(
        event: event,
        publishNow: _publishNow,
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Event' : 'Create Event'),
      content: SizedBox(
        width: 720,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Event Title',
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Event title is required.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _subtitleController,
                  decoration: const InputDecoration(
                    labelText: 'Subtitle',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _eventType,
                  decoration: const InputDecoration(
                    labelText: 'Event Type',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'official',
                      child: Text('Official'),
                    ),
                    DropdownMenuItem(
                      value: 'social',
                      child: Text('Social'),
                    ),
                    DropdownMenuItem(
                      value: 'festival',
                      child: Text('Festival'),
                    ),
                    DropdownMenuItem(
                      value: 'special',
                      child: Text('Special'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _eventType = value ?? 'special';
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _venueController,
                  decoration: const InputDecoration(
                    labelText: 'Venue',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _DateTimeFieldButton(
                        label: 'Event Date',
                        value: _formatDate(_eventDate),
                        onTap: _pickEventDate,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DateTimeFieldButton(
                        label: 'Start Time',
                        value: _formatTime(_startTime),
                        onTap: _pickStartTime,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DateTimeFieldButton(
                        label: 'End Time',
                        value: _formatTime(_endTime),
                        onTap: _pickEndTime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _DateTimeFieldButton(
                  label: 'Attendance Cutoff',
                  value: _formatDateTime(_cutoffDateTime),
                  onTap: _pickCutoff,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _targetCountController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Target Employee Count',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customNoticeController,
                  decoration: const InputDecoration(
                    labelText: 'Custom Notice',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Standard Notes',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                const SizedBox(height: 8),
                if (_loadingNotes)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: CircularProgressIndicator(),
                  )
                else
                  Column(
                    children: _availableNotes.map((note) {
                      final selected =
                          _selectedNoteIds.contains(note.documentId);
                      return CheckboxListTile(
                        value: selected,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(note.title),
                        subtitle: Text(note.body),
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedNoteIds.add(note.documentId);
                            } else {
                              _selectedNoteIds.remove(note.documentId);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Allow edit until cutoff'),
                  value: _allowEditUntilCutoff,
                  onChanged: (value) {
                    setState(() {
                      _allowEditUntilCutoff = value;
                    });
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show on employee dashboard'),
                  value: _showOnEmployeeDashboard,
                  onChanged: (value) {
                    setState(() {
                      _showOnEmployeeDashboard = value;
                    });
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show popup on publish'),
                  value: _showPopupOnPublish,
                  onChanged: (value) {
                    setState(() {
                      _showPopupOnPublish = value;
                    });
                  },
                ),
                if (!_isEditing)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Publish immediately after save'),
                    value: _publishNow,
                    onChanged: (value) {
                      setState(() {
                        _publishNow = value;
                      });
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_isEditing ? 'Update' : 'Save'),
        ),
      ],
    );
  }

  static String _formatDate(DateTime? value) {
    if (value == null) return 'Select date';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    return '$day-$month-$year';
  }

  static String _formatTime(TimeOfDay? value) {
    if (value == null) return 'Select time';
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String _formatDateTime(DateTime? value) {
    if (value == null) return 'Select cutoff';
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day-$month-$year $hour:$minute';
  }
}

class _DateTimeFieldButton extends StatelessWidget {
  const _DateTimeFieldButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        alignment: Alignment.centerLeft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 4),
          Text(value),
        ],
      ),
    );
  }
}

class _EventFormResult {
  const _EventFormResult({
    required this.event,
    required this.publishNow,
  });

  final EventModel event;
  final bool publishNow;
}

String _readableCategoryLabel(String key) {
  switch (key) {
    case 'employee':
      return 'Employee';
    case 'spouse':
      return 'Spouse';
    case 'kids_above_12':
      return 'Kids Above 12';
    case 'kids_below_12':
      return 'Kids Below 12';
    case 'permanent_resident_guests_adults':
      return 'Permanent Resident Guests (Adults)';
    case 'permanent_resident_guests_children_above_12':
      return 'Permanent Resident Guests (Children Above 12)';
    case 'permanent_resident_guests_children_below_12':
      return 'Permanent Resident Guests (Children Below 12)';
    case 'visiting_guests_adults':
      return 'Visiting Guests (Adults)';
    case 'visiting_guests_children_above_12':
      return 'Visiting Guests (Children Above 12)';
    case 'visiting_guests_children_below_12':
      return 'Visiting Guests (Children Below 12)';
    default:
      return key;
  }
}
