import 'package:cloud_firestore/cloud_firestore.dart';

class EventAttendanceSummaryModel {
  static const String collectionName = 'event_attendance_summaries';

  // Must remain identical to EventAttendanceResponseModel.categoryKeys
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
    final data = document.data() ?? <String, dynamic>{};
    return EventAttendanceSummaryModel.fromMap(
      data,
      documentId: document.id,
    );
  }

  factory EventAttendanceSummaryModel.fromMap(
    Map<String, dynamic> map, {
    required String documentId,
  }) {
    final normalizedCategoryTotals =
        _normalizeCategoryTotals(map['category_totals']);

    final computedGrandTotal = calculateGrandTotal(normalizedCategoryTotals);

    return EventAttendanceSummaryModel(
      documentId: documentId.trim(),
      eventId: _readString(map['event_id'], fallback: documentId),
      lastAggregatedAt: _readTimestamp(map['last_aggregated_at']),
      householdsResponded:
          _readInt(map['households_responded'], fallback: 0),
      householdsPending:
          _readInt(map['households_pending'], fallback: 0),
      householdsAttending:
          _readInt(map['households_attending'], fallback: 0),
      householdsNotAttending:
          _readInt(map['households_not_attending'], fallback: 0),
      categoryTotals: normalizedCategoryTotals,
      grandTotal: _readInt(map['grand_total'], fallback: computedGrandTotal),
      rawData: Map<String, dynamic>.from(map),
    );
  }

  Map<String, dynamic> toMap({
    bool includeNulls = false,
  }) {
    final normalizedCategoryTotals = _normalizeCategoryTotals(categoryTotals);
    final normalizedGrandTotal = calculateGrandTotal(normalizedCategoryTotals);

    final map = <String, dynamic>{
      'event_id': eventId.trim(),
      'households_responded': householdsResponded,
      'households_pending': householdsPending,
      'households_attending': householdsAttending,
      'households_not_attending': householdsNotAttending,
      'category_totals': normalizedCategoryTotals,
      'grand_total': normalizedGrandTotal,
    };

    _writeTimestamp(
      map,
      'last_aggregated_at',
      lastAggregatedAt,
      includeNulls: includeNulls,
    );

    return map;
  }

  EventAttendanceSummaryModel copyWith({
    String? documentId,
    String? eventId,
    Timestamp? lastAggregatedAt,
    int? householdsResponded,
    int? householdsPending,
    int? householdsAttending,
    int? householdsNotAttending,
    Map<String, int>? categoryTotals,
    int? grandTotal,
    Map<String, dynamic>? rawData,
  }) {
    return EventAttendanceSummaryModel(
      documentId: documentId ?? this.documentId,
      eventId: eventId ?? this.eventId,
      lastAggregatedAt: lastAggregatedAt ?? this.lastAggregatedAt,
      householdsResponded: householdsResponded ?? this.householdsResponded,
      householdsPending: householdsPending ?? this.householdsPending,
      householdsAttending: householdsAttending ?? this.householdsAttending,
      householdsNotAttending:
          householdsNotAttending ?? this.householdsNotAttending,
      categoryTotals: categoryTotals ?? this.categoryTotals,
      grandTotal: grandTotal ?? this.grandTotal,
      rawData: rawData ?? this.rawData,
    );
  }

  bool get hasData => householdsResponded > 0;

  bool get isBalanced =>
      householdsResponded == (householdsAttending + householdsNotAttending);

  bool get isComplete => householdsPending == 0;

  int get calculatedGrandTotal => calculateGrandTotal(categoryTotals);

  bool get isGrandTotalValid => calculatedGrandTotal == grandTotal;

  static Map<String, int> _normalizeCategoryTotals(dynamic value) {
    final Map<String, int> normalized = <String, int>{
      for (final String key in categoryKeys) key: 0,
    };

    if (value is Map) {
      value.forEach((k, v) {
        final String key = k.toString().trim();
        if (categoryKeys.contains(key)) {
          final int parsed = _readInt(v, fallback: 0);
          normalized[key] = parsed < 0 ? 0 : parsed;
        }
      });
    }

    return normalized;
  }

  static int calculateGrandTotal(Map<String, int> categoryTotals) {
    int total = 0;
    final normalized = _normalizeCategoryTotals(categoryTotals);

    for (final String key in categoryKeys) {
      total += normalized[key] ?? 0;
    }

    return total;
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
    return 'EventAttendanceSummaryModel('
        'eventId: $eventId, '
        'householdsResponded: $householdsResponded, '
        'grandTotal: $grandTotal'
        ')';
  }
}
