import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/analytics_filter_model.dart';
import '../models/cost_analytics_result.dart';

class CostAnalyticsService {
  CostAnalyticsService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<CostAnalyticsResult> fetchCostAnalytics(
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
        return CostAnalyticsResult.empty();
      }

      double totalCost = 0.0;
      double employeeCost = 0.0;
      double guestCost = 0.0;
      int totalHeads = 0;

      final Map<String, double> mealWiseCost = <String, double>{
        'breakfast': 0.0,
        'lunch': 0.0,
        'dinner': 0.0,
      };

      final Map<String, double> dailyCostTrend = <String, double>{};

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

        final double unitRate = _readAmount(data['unit_rate']);
        final double amount = _resolveAmount(
          explicitAmount: data['amount'],
          unitRate: unitRate,
          quantity: quantity,
        );

        final DateTime reservationDate = reservationTimestamp.toDate();
        final String dateKey = _formatDateKey(reservationDate);

        totalCost += amount;
        totalHeads += quantity;

        if (isGuest) {
          guestCost += amount;
        } else {
          employeeCost += amount;
        }

        if (mealType.isNotEmpty) {
          mealWiseCost[mealType] = (mealWiseCost[mealType] ?? 0.0) + amount;
        }

        dailyCostTrend[dateKey] = (dailyCostTrend[dateKey] ?? 0.0) + amount;
      }

      final double averageCostPerHead =
          totalHeads > 0 ? totalCost / totalHeads : 0.0;

      return CostAnalyticsResult(
        totalCost: _round2(totalCost),
        employeeCost: _round2(employeeCost),
        guestCost: _round2(guestCost),
        averageCostPerHead: _round2(averageCostPerHead),
        mealWiseCost: _sortMealWiseCost(mealWiseCost),
        dailyCostTrend: _sortDailyTrend(dailyCostTrend),
      );
    } catch (e) {
      throw Exception('Failed to fetch cost analytics: $e');
    }
  }

  int _readQuantity(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 1;
    return 1;
  }

  double _readAmount(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    if (value is String) return double.tryParse(value.trim()) ?? 0.0;
    return 0.0;
  }

  double _resolveAmount({
    required dynamic explicitAmount,
    required double unitRate,
    required int quantity,
  }) {
    final double parsedExplicitAmount = _readAmount(explicitAmount);
    if (parsedExplicitAmount > 0) {
      return parsedExplicitAmount;
    }
    return unitRate * quantity;
  }

  String _formatDateKey(DateTime date) {
    final String year = date.year.toString().padLeft(4, '0');
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Map<String, double> _sortDailyTrend(Map<String, double> source) {
    final entries = source.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return <String, double>{
      for (final entry in entries) entry.key: _round2(entry.value),
    };
  }

  Map<String, double> _sortMealWiseCost(Map<String, double> source) {
    final List<String> preferredKeys = <String>[
      'breakfast',
      'lunch',
      'dinner',
    ];

    final Map<String, double> result = <String, double>{};

    for (final key in preferredKeys) {
      result[key] = _round2(source[key] ?? 0.0);
    }

    final extraEntries = source.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    for (final entry in extraEntries) {
      if (!result.containsKey(entry.key)) {
        result[entry.key] = _round2(entry.value);
      }
    }

    return result;
  }

  double _round2(double value) {
    return double.parse(value.toStringAsFixed(2));
  }
}
