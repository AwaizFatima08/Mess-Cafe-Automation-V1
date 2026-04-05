import 'package:cloud_firestore/cloud_firestore.dart';

class EventAttendanceResponseModel {
  static const String collectionName = 'event_attendance_responses';

  static const String statusAttending = 'attending';
  static const String statusNotAttending = 'not_attending';

  static const List<String> allowedStatuses = <String>[
    statusAttending,
    statusNotAttending,
  ];

  // Locked count-based attendance categories
  static const List<String> categoryKeys = <String>[
    'employee',
    'spouse',
    'kids_above_12',
    'kids_below_12',
    'permanent_resident_guests_adults',
    'permanent_resident_guests_children_above_12',
    'permanent_resident_guests_children_below_12',
    'visiting_guests_adults',
    'visiting_guests_children_above_12',
    'visiting_guests_children_below_12',
  ];

  final String documentId;
  final String eventId;
  final String userUid;
  final String employeeNumber;
  final String employeeName;
  final String department;
  final String designation;
  final String attendanceStatus;
  final Timestamp? submittedAt;
  final Timestamp? updatedAt;
  final bool submissionLocked;
  final Map<String, int> counts;
  final int totalAttendees;
  final String employeeNote;
  final int responseVersion;
  final String source;
  final Map<String, dynamic> rawData;

  const EventAttendanceResponseModel({
    required this.documentId,
    required this.eventId,
    required this.userUid,
    required this.employeeNumber,
    required this.employeeName,
    required this.department,
    required this.designation,
    required this.attendanceStatus,
    required this.submittedAt,
    required this.updatedAt,
    required this.submissionLocked,
    required this.counts,
    required this.totalAttendees,
    required this.employeeNote,
    required this.responseVersion,
    required this.source,
    required this.rawData,
  });

  factory EventAttendanceResponseModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? <String, dynamic>{};
    return EventAttendanceResponseModel.fromMap(
      data,
      documentId: document.id,
    );
  }

  factory EventAttendanceResponseModel.fromMap(
    Map<String, dynamic> map, {
    required String documentId,
  }) {
    final Map<String, int> normalizedCounts = _normalizeCounts(map['counts']);

    final String normalizedStatus = _normalizeStatus(map['attendance_status']);

    final int computedTotal = calculateTotalForStatus(
      counts: normalizedCounts,
      attendanceStatus: normalizedStatus,
    );

    return EventAttendanceResponseModel(
      documentId: documentId.trim(),
      eventId: _readString(map['event_id']),
      userUid: _readString(map['user_uid']),
      employeeNumber: _readString(map['employee_number']),
      employeeName: _readString(map['employee_name']),
      department: _readString(map['department']),
      designation: _readString(map['designation']),
      attendanceStatus: normalizedStatus,
      submittedAt: _readTimestamp(map['submitted_at']),
      updatedAt: _readTimestamp(map['updated_at']),
      submissionLocked: _readBool(map['submission_locked']),
      counts: normalizedCounts,
      totalAttendees: _readInt(
        map['total_attendees'],
        fallback: computedTotal,
      ),
      employeeNote: _readString(map['employee_note']),
      responseVersion: _readInt(map['response_version'], fallback: 1),
      source: _readString(map['source'], fallback: 'mobile_app'),
      rawData: Map<String, dynamic>.from(map),
    );
  }

  Map<String, dynamic> toMap({
    bool includeNulls = false,
  }) {
    final Map<String, int> normalizedCounts = _normalizeCounts(counts);
    final String normalizedStatus = _normalizeStatus(attendanceStatus);
    final int normalizedTotal = calculateTotalForStatus(
      counts: normalizedCounts,
      attendanceStatus: normalizedStatus,
    );

    final map = <String, dynamic>{
      'event_id': eventId.trim(),
      'user_uid': userUid.trim(),
      'employee_number': employeeNumber.trim(),
      'employee_name': employeeName.trim(),
      'department': department.trim(),
      'designation': designation.trim(),
      'attendance_status': normalizedStatus,
      'submission_locked': submissionLocked,
      'counts': normalizedCounts,
      'total_attendees': normalizedTotal,
      'employee_note': employeeNote.trim(),
      'response_version': responseVersion,
      'source': source.trim().isEmpty ? 'mobile_app' : source.trim(),
    };

    _writeTimestamp(
      map,
      'submitted_at',
      submittedAt,
      includeNulls: includeNulls,
    );
    _writeTimestamp(
      map,
      'updated_at',
      updatedAt,
      includeNulls: includeNulls,
    );

    return map;
  }

  EventAttendanceResponseModel copyWith({
    String? documentId,
    String? eventId,
    String? userUid,
    String? employeeNumber,
    String? employeeName,
    String? department,
    String? designation,
    String? attendanceStatus,
    Timestamp? submittedAt,
    Timestamp? updatedAt,
    bool? submissionLocked,
    Map<String, int>? counts,
    int? totalAttendees,
    String? employeeNote,
    int? responseVersion,
    String? source,
    Map<String, dynamic>? rawData,
  }) {
    return EventAttendanceResponseModel(
      documentId: documentId ?? this.documentId,
      eventId: eventId ?? this.eventId,
      userUid: userUid ?? this.userUid,
      employeeNumber: employeeNumber ?? this.employeeNumber,
      employeeName: employeeName ?? this.employeeName,
      department: department ?? this.department,
      designation: designation ?? this.designation,
      attendanceStatus: attendanceStatus ?? this.attendanceStatus,
      submittedAt: submittedAt ?? this.submittedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      submissionLocked: submissionLocked ?? this.submissionLocked,
      counts: counts ?? this.counts,
      totalAttendees: totalAttendees ?? this.totalAttendees,
      employeeNote: employeeNote ?? this.employeeNote,
      responseVersion: responseVersion ?? this.responseVersion,
      source: source ?? this.source,
      rawData: rawData ?? this.rawData,
    );
  }

  bool get isAttending => attendanceStatus == statusAttending;
  bool get isNotAttending => attendanceStatus == statusNotAttending;
  bool get isEditable => !submissionLocked;

  bool get isValid {
    if (!allowedStatuses.contains(attendanceStatus)) {
      return false;
    }

    final normalizedCounts = _normalizeCounts(counts);
    final computedTotal = calculateTotalForStatus(
      counts: normalizedCounts,
      attendanceStatus: attendanceStatus,
    );

    if (isNotAttending && computedTotal != 0) {
      return false;
    }

    if (isAttending && computedTotal <= 0) {
      return false;
    }

    return true;
  }

  static Map<String, int> _normalizeCounts(dynamic value) {
    final Map<String, int> normalized = <String, int>{
      for (final String key in categoryKeys) key: 0,
    };

    if (value is Map) {
      value.forEach((k, v) {
        final String key = k.toString().trim();
        if (categoryKeys.contains(key)) {
          final int parsed = _readInt(v);
          normalized[key] = parsed < 0 ? 0 : parsed;
        }
      });
    }

    return normalized;
  }

  static int calculateTotal(Map<String, int> counts) {
    int total = 0;
    final normalized = _normalizeCounts(counts);

    for (final String key in categoryKeys) {
      total += normalized[key] ?? 0;
    }

    return total;
  }

  static int calculateTotalForStatus({
    required Map<String, int> counts,
    required String attendanceStatus,
  }) {
    final normalizedStatus = _normalizeStatus(attendanceStatus);

    if (normalizedStatus == statusNotAttending) {
      return 0;
    }

    return calculateTotal(counts);
  }

  static String buildDocumentId({
    required String eventId,
    required String employeeNumber,
  }) {
    final String normalizedEventId = eventId.trim().toLowerCase();
    final String normalizedEmployeeNumber = employeeNumber.trim().toLowerCase();
    return '${normalizedEventId}_$normalizedEmployeeNumber';
  }

  static String _normalizeStatus(dynamic value) {
    final String normalized =
        value?.toString().trim().toLowerCase() ?? statusNotAttending;

    if (allowedStatuses.contains(normalized)) {
      return normalized;
    }

    return statusNotAttending;
  }

  static String _readString(dynamic value, {String fallback = ''}) {
    return (value?.toString() ?? fallback).trim();
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

    final String normalized = value.toString().trim().toLowerCase();
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

  @override
  String toString() {
    return 'EventAttendanceResponseModel('
        'employee: $employeeNumber, '
        'status: $attendanceStatus, '
        'total: $totalAttendees'
        ')';
  }
}
