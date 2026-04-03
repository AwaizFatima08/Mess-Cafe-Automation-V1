import 'package:cloud_firestore/cloud_firestore.dart';

class MealRate {
  final String? id;
  final String menuItemId;
  final DateTime rateDate;
  final String mealType;
  final double unitRate;

  MealRate({
    this.id,
    required this.menuItemId,
    required this.rateDate,
    required this.mealType,
    required this.unitRate,
  });

  Map<String, dynamic> toMap() {
    return {
      'menu_item_id': menuItemId,
      'rate_date': Timestamp.fromDate(rateDate),
      'meal_type': mealType.toLowerCase(),
      'unit_rate': unitRate,
      'updated_at': FieldValue.serverTimestamp(),
    };
  }
}
