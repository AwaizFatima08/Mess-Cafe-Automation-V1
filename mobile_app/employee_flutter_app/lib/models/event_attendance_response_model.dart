import 'package:cloud_firestore/cloud_firestore.dart';

class EventAttendanceResponseModel {
  static const String collectionName = 'event_attendance_responses';

  static const String statusAttending = 'attending';
  static const String statusNotAttending = 'not_attending';

  static const List<String> allowedStatuses = [
    statusAttending,
    statusNotAttending,
  ];

  // 🔒 Locked category keys
  static const List<String> categoryKeys = [
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
    final data = document.data() ?? {};
    return EventAttendanceResponseModel.fromMap(
      data,
      documentId: document.id,
    );
  }

  factory EventAttendanceResponseModel.fromMap(
    Map<String, dynamic> map, {
    required String documentId,
  }) {
    final countsMap = _normalizeCounts(map['counts']);

    return EventAttendanceResponseModel(
      documentId: documentId.trim(),
      eventId: _readString(map['event_id']),
      userUid: _readString(map['user_uid']),
      employeeNumber: _readString(map['employee_number']),
      employeeName: _readString(map['employee_name']),
      department: _readString(map['department']),
      designation: _readString(map['designation']),
      attendanceStatus: _normalizeStatus(map['attendance_status']),
      submittedAt: _readTimestamp(map['submitted_at']),
      updatedAt: _readTimestamp(map['updated_at']),
      submissionLocked: _readBool(map['submission_locked']),
      counts: countsMap,
      totalAttendees: _readInt(map['total_attendees']),
      employeeNote: _readString(map['employee_note']),
      responseVersion: _readInt(map['response_version'], fallback: 1),
      source: _readString(map['source'], fallback: 'mobile_app'),
      rawData: Map<String, dynamic>.from(map),
    );
  }

  Map<String, dynamic> toMap({bool includeNulls = false}) {
    final map = <String, dynamic>{
      'event_id': eventId,
      'user_uid': userUid,
      'employee_number': employeeNumber,
      'employee_name': employeeName,
      'department': department,
      'designation': designation,
      'attendance_status': attendanceStatus,
      'submission_locked': submissionLocked,
      'counts': counts,
      'total_attendees': totalAttendees,
      'employee_note': employeeNote.trim(),
      'response_version': responseVersion,
      'source': source,
    };

    _writeTimestamp(map, 'submitted_at', submittedAt, includeNulls);
    _writeTimestamp(map, 'updated_at', updatedAt, includeNulls);

    return map;
  }

  // -----------------------------
  // BUSINESS LOGIC
  // -----------------------------

  bool get isAttending => attendanceStatus == statusAttending;

  bool get isNotAttending => attendanceStatus == statusNotAttending;

  bool get isEditable => !submissionLocked;

  bool get isValid {
    if (!allowedStatuses.contains(attendanceStatus)) return false;

    if (isNotAttending && totalAttendees != 0) return false;

    if (isAttending && totalAttendees <= 0) return false;

    return true;
  }

  // -----------------------------
  // UTILITIES
  // -----------------------------

  static Map<String, int> _normalizeCounts(dynamic value) {
    final Map<String, int> normalized = {};

    for (final key in categoryKeys) {
      normalized[key] = 0;
    }

    if (value is Map) {
      value.forEach((k, v) {
        final key = k.toString();
        if (categoryKeys.contains(key)) {
          normalized[key] = _readInt(v);
        }
      });
    }

    return normalized;
  }

  static int calculateTotal(Map<String, int> counts) {
    int total = 0;
    for (final key in categoryKeys) {
      total += counts[key] ?? 0;
    }
    return total;
  }

  static String buildDocumentId({
    required String eventId,
    required String employeeNumber,
  }) {
    return '${eventId}_$employeeNumber'.toLowerCase();
  }

  // -----------------------------
  // HELPERS
  // -----------------------------

  static String _normalizeStatus(dynamic value) {
    final v = value?.toString().trim().toLowerCase() ?? statusNotAttending;
    return allowedStatuses.contains(v) ? v : statusNotAttending;
  }

  static String _readString(dynamic value, {String fallback = ''}) {
    return (value?.toString() ?? fallback).trim();
  }

  static int _readInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value == null) return fallback;
    return int.tryParse(value.toString()) ?? fallback;
  }

  static bool _readBool(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    if (value == null) return fallback;
    final v = value.toString().toLowerCase();
    return v == 'true';
  }

  static Timestamp? _readTimestamp(dynamic value) {
    if (value is Timestamp) return value;
    return null;
  }

  static void _writeTimestamp(
    Map<String, dynamic> target,
    String key,
    Timestamp? value,
    bool includeNulls,
  ) {
    if (value != null || includeNulls) {
      target[key] = value;
    }
  }

  @override
  String toString() {
    return 'EventAttendanceResponseModel(employee: $employeeNumber, total: $totalAttendees)';
  }
}
