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
      Query<Map<String, dynamic>> query =
          _firestore.collection('meal_reservations');

      query = query
          .where(
            'reservation_date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(
              filter.normalizedStartDate,
            ),
          )
          .where(
            'reservation_date',
            isLessThanOrEqualTo: Timestamp.fromDate(
              filter.normalizedEndDate,
            ),
          )
          .where('is_issued', isEqualTo: true);

      if (filter.hasMealTypeFilter) {
        query = query.where('meal_type', whereIn: filter.mealTypes);
      }

      if (filter.hasEmployeeFilter) {
        query = query.where(
          'employee_number',
          isEqualTo: filter.employeeNumber!.trim(),
        );
      }

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        return AttendanceAnalyticsResult.empty();
      }

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

        final String reservationCategory =
            ((data['reservation_category'] as String?) ?? '')
                .trim()
                .toLowerCase();

        final bool isGuest = reservationCategory != 'employee';

        if (!filter.includeGuests && isGuest) {
          continue;
        }

        final int quantity = _readQuantity(data['quantity']);
        final String mealType =
            ((data['meal_type'] as String?) ?? '').trim().toLowerCase();

        final Timestamp? reservationTimestamp =
            data['reservation_date'] as Timestamp?;

        if (reservationTimestamp == null) {
          continue;
        }

        final DateTime reservationDate = reservationTimestamp.toDate();
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

  int _readQuantity(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 1;
    return 1;
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
