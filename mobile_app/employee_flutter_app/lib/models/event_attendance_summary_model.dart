import 'package:cloud_firestore/cloud_firestore.dart';

class EventAttendanceSummaryModel {
  static const String collectionName = 'event_attendance_summaries';

  // 🔒 MUST match response model exactly
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

  final Timestamp? lastAggregatedAt;

  final int householdsResponded;
  final int householdsPending;
  final int householdsAttending;
  final int householdsNotAttending;

  final Map<String, int> categoryTotals;
  final int grandTotal;

  final Map<String, dynamic> rawData;

  const EventAttendanceSummaryModel({
    required this.documentId,
    required this.eventId,
    required this.lastAggregatedAt,
    required this.householdsResponded,
    required this.householdsPending,
    required this.householdsAttending,
    required this.householdsNotAttending,
    required this.categoryTotals,
    required this.grandTotal,
    required this.rawData,
  });

  factory EventAttendanceSummaryModel.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? {};
    return EventAttendanceSummaryModel.fromMap(
      data,
      documentId: document.id,
    );
  }

  factory EventAttendanceSummaryModel.fromMap(
    Map<String, dynamic> map, {
    required String documentId,
  }) {
    return EventAttendanceSummaryModel(
      documentId: documentId.trim(),
      eventId: _readString(map['event_id']),
      lastAggregatedAt: _readTimestamp(map['last_aggregated_at']),
      householdsResponded:
          _readInt(map['households_responded'], fallback: 0),
      householdsPending:
          _readInt(map['households_pending'], fallback: 0),
      householdsAttending:
          _readInt(map['households_attending'], fallback: 0),
      householdsNotAttending:
          _readInt(map['households_not_attending'], fallback: 0),
      categoryTotals: _normalizeCategoryTotals(map['category_totals']),
      grandTotal: _readInt(map['grand_total'], fallback: 0),
      rawData: Map<String, dynamic>.from(map),
    );
  }

  Map<String, dynamic> toMap({bool includeNulls = false}) {
    final map = <String, dynamic>{
      'event_id': eventId,
      'households_responded': householdsResponded,
      'households_pending': householdsPending,
      'households_attending': householdsAttending,
      'households_not_attending': householdsNotAttending,
      'category_totals': categoryTotals,
      'grand_total': grandTotal,
    };

    _writeTimestamp(
      map,
      'last_aggregated_at',
      lastAggregatedAt,
      includeNulls,
    );

    return map;
  }

  // -----------------------------
  // BUSINESS LOGIC
  // -----------------------------

  bool get hasData => householdsResponded > 0;

  bool get isBalanced =>
      householdsResponded == (householdsAttending + householdsNotAttending);

  bool get isComplete => householdsPending == 0;

  int get calculatedGrandTotal {
    int total = 0;
    for (final key in categoryKeys) {
      total += categoryTotals[key] ?? 0;
    }
    return total;
  }

  bool get isGrandTotalValid => calculatedGrandTotal == grandTotal;

  // -----------------------------
  // UTILITIES
  // -----------------------------

  static Map<String, int> _normalizeCategoryTotals(dynamic value) {
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

  // -----------------------------
  // HELPERS
  // -----------------------------

  static String _readString(dynamic value, {String fallback = ''}) {
    return (value?.toString() ?? fallback).trim();
  }

  static int _readInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value == null) return fallback;
    return int.tryParse(value.toString()) ?? fallback;
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
    return 'EventAttendanceSummaryModel(eventId: $eventId, total: $grandTotal)';
  }
}
