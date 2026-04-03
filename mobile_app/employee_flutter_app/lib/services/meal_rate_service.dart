import 'package:cloud_firestore/cloud_firestore.dart';

class MealRateService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<double> getResolvedRate({required String menuItemId, required DateTime date, required String mealType}) async {
    final start = DateTime(date.year, date.month, date.day);
    final snap = await _db.collection('meal_rates')
        .where('menu_item_id', isEqualTo: menuItemId)
        .where('meal_type', isEqualTo: mealType.toLowerCase())
        .where('rate_date', isEqualTo: Timestamp.fromDate(start))
        .limit(1).get();

    if (snap.docs.isNotEmpty) return (snap.docs.first.data()['unit_rate'] ?? 0.0).toDouble();

    final item = await _db.collection('menu_items').doc(menuItemId).get();
    return (item.data()?['base_price'] ?? 0.0).toDouble();
  }

  Future<void> updateMealRate({required String menuItemId, required DateTime date, required String mealType, required double newRate}) async {
    final start = DateTime(date.year, date.month, date.day);
    final id = "${menuItemId}_${start.millisecondsSinceEpoch}_${mealType.toLowerCase()}";
    await _db.collection('meal_rates').doc(id).set({
      'menu_item_id': menuItemId,
      'rate_date': Timestamp.fromDate(start),
      'meal_type': mealType.toLowerCase(),
      'unit_rate': newRate,
    }, SetOptions(merge: true));
  }
}
