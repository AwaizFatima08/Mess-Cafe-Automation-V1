import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/analytics_filter_model.dart';
import '../models/feedback_analytics_result.dart';

class FeedbackAnalyticsService {
  FeedbackAnalyticsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<FeedbackAnalyticsResult> fetchFeedbackAnalytics(
    AnalyticsFilterModel filter,
  ) async {
    try {
      final startDate = filter.normalizedStartDate;
      final endDate = filter.normalizedEndDate;

      final snapshot = await _firestore
          .collection('meal_feedback')
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
        return FeedbackAnalyticsResult.empty();
      }

      final List<String> allowedMealTypes = (filter.mealTypes ?? <String>[])
          .map((e) => e.trim().toLowerCase())
          .where((e) => e.isNotEmpty)
          .toList();

      final String? employeeNumber =
          filter.hasEmployeeFilter ? filter.employeeNumber!.trim() : null;

      int totalResponses = 0;
      int totalRatingPoints = 0;

      final Map<int, int> ratingDistribution = <int, int>{
        1: 0,
        2: 0,
        3: 0,
        4: 0,
        5: 0,
      };

      final Map<String, int> dailyFeedbackTrend = <String, int>{};

      final Map<String, int> mealWiseResponseCount = <String, int>{
        'breakfast': 0,
        'lunch': 0,
        'dinner': 0,
      };

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final DateTime? reservationDate =
            _parseFirestoreDate(data['reservation_date']);
        if (reservationDate == null) {
          continue;
        }

        if (!_isWithinFilterRange(reservationDate, filter)) {
          continue;
        }

        final String mealType =
            ((data['meal_type'] as String?) ?? '').trim().toLowerCase();

        if (allowedMealTypes.isNotEmpty &&
            !allowedMealTypes.contains(mealType)) {
          continue;
        }

        final String docEmployeeNumber =
            ((data['employee_number'] as String?) ?? '').trim();

        if (employeeNumber != null && docEmployeeNumber != employeeNumber) {
          continue;
        }

        final int rating = _readRating(data['rating']);
        if (rating < 1 || rating > 5) {
          continue;
        }

        final String dateKey = _formatDateKey(reservationDate);

        totalResponses += 1;
        totalRatingPoints += rating;

        ratingDistribution[rating] = (ratingDistribution[rating] ?? 0) + 1;
        dailyFeedbackTrend[dateKey] = (dailyFeedbackTrend[dateKey] ?? 0) + 1;

        if (mealType.isNotEmpty) {
          mealWiseResponseCount[mealType] =
              (mealWiseResponseCount[mealType] ?? 0) + 1;
        }
      }

      final double averageRating =
          totalResponses > 0 ? totalRatingPoints / totalResponses : 0.0;

      return FeedbackAnalyticsResult(
        totalResponses: totalResponses,
        averageRating: _round2(averageRating),
        ratingDistribution: _sortRatingDistribution(ratingDistribution),
        dailyFeedbackTrend: _sortDailyTrend(dailyFeedbackTrend),
        mealWiseResponseCount:
            _sortMealWiseResponseCount(mealWiseResponseCount),
      );
    } catch (e) {
      throw Exception('Failed to fetch feedback analytics: $e');
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

  int _readRating(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }

  String _formatDateKey(DateTime date) {
    final String year = date.year.toString().padLeft(4, '0');
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Map<int, int> _sortRatingDistribution(Map<int, int> source) {
    final List<int> keys = source.keys.toList()..sort();

    return <int, int>{
      for (final key in keys) key: source[key] ?? 0,
    };
  }

  Map<String, int> _sortDailyTrend(Map<String, int> source) {
    final entries = source.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return <String, int>{
      for (final entry in entries) entry.key: entry.value,
    };
  }

  Map<String, int> _sortMealWiseResponseCount(Map<String, int> source) {
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

  double _round2(double value) {
    return double.parse(value.toStringAsFixed(2));
  }
}
