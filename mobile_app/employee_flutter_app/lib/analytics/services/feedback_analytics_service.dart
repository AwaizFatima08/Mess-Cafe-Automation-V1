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
      Query<Map<String, dynamic>> query = _firestore.collection('meal_feedback');

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
          );

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
        return FeedbackAnalyticsResult.empty();
      }

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

        final int rating = _readRating(data['rating']);
        if (rating < 1 || rating > 5) {
          continue;
        }

        final String mealType =
            ((data['meal_type'] as String?) ?? '').trim().toLowerCase();

        final Timestamp? reservationTimestamp =
            data['reservation_date'] as Timestamp?;
        if (reservationTimestamp == null) {
          continue;
        }

        final DateTime reservationDate = reservationTimestamp.toDate();
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
