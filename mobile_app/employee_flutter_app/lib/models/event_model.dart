import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  static const String collectionName = 'events';

  static const String statusDraft = 'draft';
  static const String statusPublished = 'published';
  static const String statusClosed = 'closed';
  static const String statusCancelled = 'cancelled';

  static const List<String> allowedStatuses = <String>[
    statusDraft,
    statusPublished,
    statusClosed,
    statusCancelled,
  ];

  static const String targetScopeAllActiveEmployees = 'all_active_employees';

  static const List<String> allowedTargetScopes = <String>[
    targetScopeAllActiveEmployees,
    'selected_employees',
    'custom',
  ];

  static const Object _unset = Object();

  final String documentId;
  final String eventId;
  final String title;
  final String subtitle;
  final String description;
  final String eventType;
  final String venue;

  final Timestamp? eventDate;
  final Timestamp? startAt;
  final Timestamp? endAt;
  final Timestamp? responseCutoffAt;

  final String status;

  final String createdByUid;
  final String createdByEmployeeNumber;
  final String createdByName;

  final Timestamp? createdAt;
  final Timestamp? updatedAt;
  final Timestamp? publishedAt;
  final Timestamp? closedAt;
  final Timestamp? cancelledAt;

  final int dashboardPriority;
  final bool allowEditUntilCutoff;
  final bool showOnEmployeeDashboard;
  final bool showPopupOnPublish;

  final List<String> selectedNoteIds;
  final List<EventNoteSnapshot> notesSnapshot;
  final String customNotice;

  final String targetScope;
  final int targetCountEstimate;
  final int householdsResponded;
  final int householdsPending;
  final int grandTotalAttendees;

  final bool reportLocked;
  final bool isDeletedSoft;

  final Map<String, dynamic> rawData;

  const EventModel({
    required this.documentId,
    required this.eventId,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.eventType,
    required this.venue,
    required this.eventDate,
    required this.startAt,
    required this.endAt,
    required this.responseCutoffAt,
    required this.status,
    required this.createdByUid,
    required this.createdByEmployeeNumber,
    required this.createdByName,
    required this.createdAt,
    required this.updatedAt,
    required this.publishedAt,
    required this.closedAt,
    required this.cancelledAt,
    required this.dashboardPriority,
    required this.allowEditUntilCutoff,
    required this.showOnEmployeeDashboard,
    required this.showPopupOnPublish,
    required this.selectedNoteIds,
    required this.notesSnapshot,
    required this.customNotice,
    required this.targetScope,
    required this.targetCountEstimate,
    required this.householdsResponded,
    required this.householdsPending,
    required this.grandTotalAttendees,
    required this.reportLocked,
    required this.isDeletedSoft,
    required this.rawData,
  });

  factory EventModel.empty({
    required String documentId,
    required String createdByUid,
    required String createdByEmployeeNumber,
    required String createdByName,
  }) {
    return EventModel(
      documentId: documentId.trim(),
      eventId: documentId.trim(),
      title: '',
      subtitle: '',
      description: '',
      eventType: '',
      venue: '',
      eventDate: null,
      startAt: null,
      endAt: null,
      responseCutoffAt: null,
      status: statusDraft,
      createdByUid: createdByUid.trim(),
      createdByEmployeeNumber: createdByEmployeeNumber.trim(),
      createdByName: createdByName.trim(),
      createdAt: null,
      updatedAt: null,
      publishedAt: null,
      closedAt: null,
      cancelledAt: null,
      dashboardPriority: 1,
      allowEditUntilCutoff: true,
      showOnEmployeeDashboard: true,
      showPopupOnPublish: true,
      selectedNoteIds: const <String>[],
      notesSnapshot: const <EventNoteSnapshot>[],
      customNotice: '',
      targetScope: targetScopeAllActiveEmployees,
      targetCountEstimate: 0,
      householdsResponded: 0,
      householdsPending: 0,
      grandTotalAttendees: 0,
      reportLocked: false,
      isDeletedSoft: false,
      rawData: const <String, dynamic>{},
    );
  }

  factory EventModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    return EventModel.fromMap(
      data,
      documentId: document.id,
    );
  }

  factory EventModel.fromMap(
    Map<String, dynamic> map, {
    required String documentId,
  }) {
    final selectedNoteIdsRaw = map['selected_note_ids'];
    final notesSnapshotRaw = map['notes_snapshot'];

    return EventModel(
      documentId: documentId.trim(),
      eventId: _readString(map['event_id'], fallback: documentId),
      title: _readString(map['title']),
      subtitle: _readString(map['subtitle']),
      description: _readString(map['description']),
      eventType: _readString(map['event_type']),
      venue: _readString(map['venue']),
      eventDate: _readTimestamp(map['event_date']),
      startAt: _readTimestamp(map['start_at']),
      endAt: _readTimestamp(map['end_at']),
      responseCutoffAt: _readTimestamp(map['response_cutoff_at']),
      status: _normalizeStatus(map['status']),
      createdByUid: _readString(map['created_by_uid']),
      createdByEmployeeNumber: _readString(map['created_by_employee_number']),
      createdByName: _readString(map['created_by_name']),
      createdAt: _readTimestamp(map['created_at']),
      updatedAt: _readTimestamp(map['updated_at']),
      publishedAt: _readTimestamp(map['published_at']),
      closedAt: _readTimestamp(map['closed_at']),
      cancelledAt: _readTimestamp(map['cancelled_at']),
      dashboardPriority: _readInt(map['dashboard_priority'], fallback: 1),
      allowEditUntilCutoff:
          _readBool(map['allow_edit_until_cutoff'], fallback: true),
      showOnEmployeeDashboard:
          _readBool(map['show_on_employee_dashboard'], fallback: true),
      showPopupOnPublish:
          _readBool(map['show_popup_on_publish'], fallback: true),
      selectedNoteIds: _readStringList(selectedNoteIdsRaw),
      notesSnapshot: _readNotesSnapshotList(notesSnapshotRaw),
      customNotice: _readString(map['custom_notice']),
      targetScope: _normalizeTargetScope(map['target_scope']),
      targetCountEstimate:
          _readInt(map['target_count_estimate'], fallback: 0),
      householdsResponded:
          _readInt(map['households_responded'], fallback: 0),
      householdsPending:
          _readInt(map['households_pending'], fallback: 0),
      grandTotalAttendees:
          _readInt(map['grand_total_attendees'], fallback: 0),
      reportLocked: _readBool(map['report_locked'], fallback: false),
      isDeletedSoft: _readBool(map['is_deleted_soft'], fallback: false),
      rawData: Map<String, dynamic>.from(map),
    );
  }

  Map<String, dynamic> toMap({
    bool includeNulls = false,
  }) {
    final map = <String, dynamic>{
      'event_id': eventId.trim(),
      'title': title.trim(),
      'subtitle': subtitle.trim(),
      'description': description.trim(),
      'event_type': eventType.trim(),
      'venue': venue.trim(),
      'status': normalizedStatus,
      'created_by_uid': createdByUid.trim(),
      'created_by_employee_number': createdByEmployeeNumber.trim(),
      'created_by_name': createdByName.trim(),
      'dashboard_priority': dashboardPriority,
      'allow_edit_until_cutoff': allowEditUntilCutoff,
      'show_on_employee_dashboard': showOnEmployeeDashboard,
      'show_popup_on_publish': showPopupOnPublish,
      'selected_note_ids': selectedNoteIds
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
      'notes_snapshot':
          notesSnapshot.map((note) => note.toMap()).toList(growable: false),
      'custom_notice': customNotice.trim(),
      'target_scope': normalizedTargetScope,
      'target_count_estimate': targetCountEstimate,
      'households_responded': householdsResponded,
      'households_pending': householdsPending,
      'grand_total_attendees': grandTotalAttendees,
      'report_locked': reportLocked,
      'is_deleted_soft': isDeletedSoft,
    };

    _writeTimestamp(map, 'event_date', eventDate, includeNulls: includeNulls);
    _writeTimestamp(map, 'start_at', startAt, includeNulls: includeNulls);
    _writeTimestamp(map, 'end_at', endAt, includeNulls: includeNulls);
    _writeTimestamp(
      map,
      'response_cutoff_at',
      responseCutoffAt,
      includeNulls: includeNulls,
    );
    _writeTimestamp(map, 'created_at', createdAt, includeNulls: includeNulls);
    _writeTimestamp(map, 'updated_at', updatedAt, includeNulls: includeNulls);
    _writeTimestamp(
      map,
      'published_at',
      publishedAt,
      includeNulls: includeNulls,
    );
    _writeTimestamp(map, 'closed_at', closedAt, includeNulls: includeNulls);
    _writeTimestamp(
      map,
      'cancelled_at',
      cancelledAt,
      includeNulls: includeNulls,
    );

    return map;
  }

  EventModel copyWith({
    String? documentId,
    String? eventId,
    String? title,
    String? subtitle,
    String? description,
    String? eventType,
    String? venue,
    Object? eventDate = _unset,
    Object? startAt = _unset,
    Object? endAt = _unset,
    Object? responseCutoffAt = _unset,
    String? status,
    String? createdByUid,
    String? createdByEmployeeNumber,
    String? createdByName,
    Object? createdAt = _unset,
    Object? updatedAt = _unset,
    Object? publishedAt = _unset,
    Object? closedAt = _unset,
    Object? cancelledAt = _unset,
    int? dashboardPriority,
    bool? allowEditUntilCutoff,
    bool? showOnEmployeeDashboard,
    bool? showPopupOnPublish,
    List<String>? selectedNoteIds,
    List<EventNoteSnapshot>? notesSnapshot,
    String? customNotice,
    String? targetScope,
    int? targetCountEstimate,
    int? householdsResponded,
    int? householdsPending,
    int? grandTotalAttendees,
    bool? reportLocked,
    bool? isDeletedSoft,
    Map<String, dynamic>? rawData,
  }) {
    return EventModel(
      documentId: documentId ?? this.documentId,
      eventId: eventId ?? this.eventId,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      eventType: eventType ?? this.eventType,
      venue: venue ?? this.venue,
      eventDate:
          identical(eventDate, _unset) ? this.eventDate : eventDate as Timestamp?,
      startAt: identical(startAt, _unset) ? this.startAt : startAt as Timestamp?,
      endAt: identical(endAt, _unset) ? this.endAt : endAt as Timestamp?,
      responseCutoffAt: identical(responseCutoffAt, _unset)
          ? this.responseCutoffAt
          : responseCutoffAt as Timestamp?,
      status: status ?? this.status,
      createdByUid: createdByUid ?? this.createdByUid,
      createdByEmployeeNumber:
          createdByEmployeeNumber ?? this.createdByEmployeeNumber,
      createdByName: createdByName ?? this.createdByName,
      createdAt:
          identical(createdAt, _unset) ? this.createdAt : createdAt as Timestamp?,
      updatedAt:
          identical(updatedAt, _unset) ? this.updatedAt : updatedAt as Timestamp?,
      publishedAt: identical(publishedAt, _unset)
          ? this.publishedAt
          : publishedAt as Timestamp?,
      closedAt:
          identical(closedAt, _unset) ? this.closedAt : closedAt as Timestamp?,
      cancelledAt: identical(cancelledAt, _unset)
          ? this.cancelledAt
          : cancelledAt as Timestamp?,
      dashboardPriority: dashboardPriority ?? this.dashboardPriority,
      allowEditUntilCutoff:
          allowEditUntilCutoff ?? this.allowEditUntilCutoff,
      showOnEmployeeDashboard:
          showOnEmployeeDashboard ?? this.showOnEmployeeDashboard,
      showPopupOnPublish: showPopupOnPublish ?? this.showPopupOnPublish,
      selectedNoteIds: selectedNoteIds ?? this.selectedNoteIds,
      notesSnapshot: notesSnapshot ?? this.notesSnapshot,
      customNotice: customNotice ?? this.customNotice,
      targetScope: targetScope ?? this.targetScope,
      targetCountEstimate: targetCountEstimate ?? this.targetCountEstimate,
      householdsResponded: householdsResponded ?? this.householdsResponded,
      householdsPending: householdsPending ?? this.householdsPending,
      grandTotalAttendees: grandTotalAttendees ?? this.grandTotalAttendees,
      reportLocked: reportLocked ?? this.reportLocked,
      isDeletedSoft: isDeletedSoft ?? this.isDeletedSoft,
      rawData: rawData ?? this.rawData,
    );
  }

  String get normalizedStatus => _normalizeStatus(status);
  String get normalizedTargetScope => _normalizeTargetScope(targetScope);

  bool get isDraft => normalizedStatus == statusDraft;
  bool get isPublished => normalizedStatus == statusPublished;
  bool get isClosed => normalizedStatus == statusClosed;
  bool get isCancelled => normalizedStatus == statusCancelled;

  bool get isActiveForEmployees =>
      isPublished && !isDeletedSoft && !reportLocked;

  bool get hasCutoff => responseCutoffAt != null;
  bool get hasStarted => startAt != null;
  bool get hasEnded => endAt != null;
  bool get hasNotes => selectedNoteIds.isNotEmpty || notesSnapshot.isNotEmpty;
  bool get hasCustomNotice => customNotice.trim().isNotEmpty;

  DateTime? get eventDateTime => eventDate?.toDate();
  DateTime? get startDateTime => startAt?.toDate();
  DateTime? get endDateTime => endAt?.toDate();
  DateTime? get responseCutoffDateTime => responseCutoffAt?.toDate();

  bool isResponseWindowOpen({
    DateTime? now,
  }) {
    if (!isPublished || isCancelled || isClosed) {
      return false;
    }

    if (reportLocked) {
      return false;
    }

    final cutoff = responseCutoffDateTime;
    if (cutoff == null) {
      return true;
    }

    final current = now ?? DateTime.now();
    return !current.isAfter(cutoff);
  }

  bool canEmployeeEditResponse({
    DateTime? now,
  }) {
    if (!allowEditUntilCutoff) {
      return false;
    }

    return isResponseWindowOpen(now: now);
  }

  String get displayTitle => title.trim().isEmpty ? eventId : title.trim();
  String get displayVenue => venue.trim();

  @override
  String toString() {
    return 'EventModel(documentId: $documentId, eventId: $eventId, title: $title, status: $status)';
  }

  static String buildEventDocumentId({
    required String slug,
  }) {
    final normalized = _sanitizeKey(slug);
    return normalized.isEmpty ? 'event' : normalized;
  }

  static String buildSuggestedSlug({
    required String title,
    DateTime? eventDate,
  }) {
    final normalizedTitle = _sanitizeKey(title);
    if (normalizedTitle.isEmpty) {
      return eventDate == null
          ? 'event'
          : 'event_${eventDate.year.toString().padLeft(4, '0')}';
    }

    if (eventDate == null) {
      return normalizedTitle;
    }

    final year = eventDate.year.toString().padLeft(4, '0');
    return '${normalizedTitle}_$year';
  }

  static String _sanitizeKey(String value) {
    final lower = value.trim().toLowerCase();
    if (lower.isEmpty) {
      return '';
    }

    final replaced = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final collapsed = replaced.replaceAll(RegExp(r'_+'), '_');
    return collapsed.replaceAll(RegExp(r'^_|_$'), '');
  }

  static String _normalizeStatus(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase() ?? statusDraft;
    if (allowedStatuses.contains(normalized)) {
      return normalized;
    }
    return statusDraft;
  }

  static String _normalizeTargetScope(dynamic value) {
    final normalized =
        value?.toString().trim().toLowerCase() ?? targetScopeAllActiveEmployees;

    if (normalized.isEmpty) {
      return targetScopeAllActiveEmployees;
    }

    if (normalized == 'all_employees') {
      return targetScopeAllActiveEmployees;
    }

    if (allowedTargetScopes.contains(normalized)) {
      return normalized;
    }

    return targetScopeAllActiveEmployees;
  }

  static String _readString(dynamic value, {String fallback = ''}) {
    final parsed = value?.toString() ?? fallback;
    return parsed.trim();
  }

  static int _readInt(dynamic value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value == null) {
      return fallback;
    }
    return int.tryParse(value.toString().trim()) ?? fallback;
  }

  static bool _readBool(dynamic value, {bool fallback = false}) {
    if (value is bool) {
      return value;
    }
    if (value == null) {
      return fallback;
    }

    final normalized = value.toString().trim().toLowerCase();
    if (normalized == 'true') {
      return true;
    }
    if (normalized == 'false') {
      return false;
    }

    return fallback;
  }

  static Timestamp? _readTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value;
    }
    return null;
  }

  static List<String> _readStringList(dynamic value) {
    if (value is! Iterable) {
      return const <String>[];
    }

    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static List<EventNoteSnapshot> _readNotesSnapshotList(dynamic value) {
    if (value is! Iterable) {
      return const <EventNoteSnapshot>[];
    }

    return value
        .whereType<Map>()
        .map(
          (item) => EventNoteSnapshot.fromMap(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList(growable: false);
  }

  static void _writeTimestamp(
    Map<String, dynamic> target,
    String key,
    Timestamp? value, {
    required bool includeNulls,
  }) {
    if (value != null || includeNulls) {
      target[key] = value;
    }
  }
}

class EventNoteSnapshot {
  final String noteId;
  final String title;
  final String body;

  const EventNoteSnapshot({
    required this.noteId,
    required this.title,
    required this.body,
  });

  factory EventNoteSnapshot.fromMap(Map<String, dynamic> map) {
    return EventNoteSnapshot(
      noteId: (map['note_id'] ?? '').toString().trim(),
      title: (map['title'] ?? '').toString().trim(),
      body: (map['body'] ?? '').toString().trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'note_id': noteId.trim(),
      'title': title.trim(),
      'body': body.trim(),
    };
  }

  EventNoteSnapshot copyWith({
    String? noteId,
    String? title,
    String? body,
  }) {
    return EventNoteSnapshot(
      noteId: noteId ?? this.noteId,
      title: title ?? this.title,
      body: body ?? this.body,
    );
  }

  @override
  String toString() {
    return 'EventNoteSnapshot(noteId: $noteId, title: $title)';
  }
}
