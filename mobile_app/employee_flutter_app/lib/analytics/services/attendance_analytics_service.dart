import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/analytics_filter_model.dart';
import '../models/attendance_analytics_result.dart';

class AttendanceAnalyticsService {
  AttendanceAnalyticsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<AttendanceAnalyticsResult> fetchAttendanceAnalytics(
    AnalyticsFilterModel filter,
  ) async {
    try {
      final startDate = filter.normalizedStartDate;
      final endDate = filter.normalizedEndDate;

      final snapshot = await _firestore
          .collection('meal_reservations')
          .where(
            'reservation_date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          )
          .where(
            'reservation_date',
            isLessThan: Timestamp.fromDate(
              endDate.add(const Duration(days: 1)),
            ),
          )
          .get();

      if (snapshot.docs.isEmpty) {
        return AttendanceAnalyticsResult.empty();
      }

      final List<String> allowedMealTypes = (filter.mealTypes ?? <String>[])
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toList();

      final String? employeeNumber =
          filter.hasEmployeeFilter ? filter.employeeNumber!.trim() : null;

      int totalAttendance = 0;
      int totalEmployees = 0;
      int totalGuests = 0;

      final Map<String, int> mealWiseAttendance = <String, int>{
        'breakfast': 0,
        'lunch': 0,
        'dinner': 0,
      };

      final Map<String, int> dailyTrend = <String, int>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final String status = _readText(data['status']).toLowerCase();
        final bool isIssued = data['is_issued'] == true || status == 'issued';

        if (!isIssued || status == 'cancelled') {
          continue;
        }

        final DateTime? reservationDate =
            _parseFirestoreDate(data['reservation_date']);
        if (reservationDate == null) {
          continue;
        }

        if (!_isWithinFilterRange(reservationDate, filter)) {
          continue;
        }

        final String mealType =
            _readText(data['meal_type']).trim().toLowerCase();

        if (allowedMealTypes.isNotEmpty &&
            !allowedMealTypes.contains(mealType)) {
          continue;
        }

        final String docEmployeeNumber =
            _readText(data['employee_number']).trim();

        if (employeeNumber != null && docEmployeeNumber != employeeNumber) {
          continue;
        }

        final String reservationCategory =
            _readText(data['reservation_category']).trim().toLowerCase();
        final String bookingSubjectType =
            _readText(data['booking_subject_type']).trim().toLowerCase();

        final bool isGuest = reservationCategory == 'official_guest' ||
            bookingSubjectType == 'official_guest';

        if (!filter.includeGuests && isGuest) {
          continue;
        }

        final int quantity = _readQuantity(data['quantity']);
        if (quantity <= 0) {
          continue;
        }

        final String dateKey = _formatDateKey(reservationDate);

        totalAttendance += quantity;

        if (isGuest) {
          totalGuests += quantity;
        } else {
          totalEmployees += quantity;
        }

        if (mealType.isNotEmpty) {
          mealWiseAttendance[mealType] =
              (mealWiseAttendance[mealType] ?? 0) + quantity;
        }

        dailyTrend[dateKey] = (dailyTrend[dateKey] ?? 0) + quantity;
      }

      return AttendanceAnalyticsResult(
        totalAttendance: totalAttendance,
        totalEmployees: totalEmployees,
        totalGuests: totalGuests,
        mealWiseAttendance: _sortMealWiseAttendance(mealWiseAttendance),
        dailyTrend: _sortDailyTrend(dailyTrend),
      );
    } catch (e) {
      throw Exception('Failed to fetch attendance analytics: $e');
    }
  }

  DateTime? _parseFirestoreDate(dynamic rawDate) {
    if (rawDate == null) return null;

    if (rawDate is Timestamp) {
      return rawDate.toDate();
    }

    if (rawDate is DateTime) {
      return rawDate;
    }

    if (rawDate is String) {
      return DateTime.tryParse(rawDate);
    }

    if (rawDate is Map<String, dynamic>) {
      final seconds = rawDate['_seconds'] ?? rawDate['seconds'];
      final nanoseconds = rawDate['_nanoseconds'] ?? rawDate['nanoseconds'];

      if (seconds is int) {
        final int millis = (seconds * 1000) +
            ((nanoseconds is int) ? (nanoseconds ~/ 1000000) : 0);
        return DateTime.fromMillisecondsSinceEpoch(millis);
      }
    }

    return null;
  }

  bool _isWithinFilterRange(DateTime date, AnalyticsFilterModel filter) {
    return !date.isBefore(filter.normalizedStartDate) &&
        !date.isAfter(filter.normalizedEndDate);
  }

  int _readQuantity(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value.trim()) ?? 1;
    return 1;
  }

  String _readText(dynamic value) {
    return (value ?? '').toString().trim();
  }

  String _formatDateKey(DateTime date) {
    final String year = date.year.toString().padLeft(4, '0');
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Map<String, int> _sortDailyTrend(Map<String, int> source) {
    final entries = source.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return <String, int>{
      for (final entry in entries) entry.key: entry.value,
    };
  }

  Map<String, int> _sortMealWiseAttendance(Map<String, int> source) {
    final List<String> preferredKeys = <String>[
      'breakfast',
      'lunch',
      'dinner',
    ];

    final Map<String, int> result = <String, int>{};

    for (final key in preferredKeys) {
      result[key] = source[key] ?? 0;
    }

    final extraEntries = source.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    for (final entry in extraEntries) {
      if (!result.containsKey(entry.key)) {
        result[entry.key] = entry.value;
      }
    }

    return result;
  }
}
