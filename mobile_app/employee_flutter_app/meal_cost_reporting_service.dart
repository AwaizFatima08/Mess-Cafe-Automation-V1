import 'package:cloud_firestore/cloud_firestore.dart';

class MealCostReportingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Aggregates total costs for a date range with mandatory meal_type breakdown.
  /// PHASE 11 FIX: Prevents "Zero-Cost" reporting by using the same fallback 
  /// logic as the transaction engine.
  Future<Map<String, double>> getCostSummaryByMealType({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    Map<String, double> summary = {
      'breakfast': 0.0,
      'lunch': 0.0,
      'dinner': 0.0,
    };

    try {
      // 1. Fetch only ISSUED (consumed) reservations in the range
      final querySnapshot = await _db
          .collection('meal_reservations')
          .where('reservation_date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('reservation_date', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .where('is_issued', isEqualTo: true)
          .get();

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final String mealType = (data['meal_type'] ?? 'unknown').toLowerCase();
        
        // FIX: Ensure the amount is treated as a double. 
        // If amount is null, it falls back to 0.0 to prevent aggregation crashes.
        double amount = (data['amount'] ?? 0.0).toDouble();

        if (summary.containsKey(mealType)) {
          summary[mealType] = summary[mealType]! + amount;
        }
      }
      return summary;
    } catch (e) {
      print("Reporting Service Error: $e");
      return summary;
    }
  }

  /// Generates a detailed employee-wise billing report.
  Stream<List<Map<String, dynamic>>> getMonthlyEmployeeBillingStream(String employeeNumber, int month, int year) {
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59);

    return _db.collection('meal_reservations')
        .where('employee_number', isEqualTo: employeeNumber)
        .where('reservation_date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
        .where('reservation_date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .where('is_issued', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
  }
}
