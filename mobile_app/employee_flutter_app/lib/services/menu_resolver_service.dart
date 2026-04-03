import 'package:cloud_firestore/cloud_firestore.dart';

class MenuResolverService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // The {String? mealType} makes it a named parameter.
  Future<Map<String, dynamic>?> getMenuForDate(DateTime date, {String? mealType}) async {
    final String dateId = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    
    try {
      final doc = await _db.collection('daily_menus').doc(dateId).get();
      
      if (!doc.exists) return null;

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      
      if (mealType != null) {
        String key = mealType.toLowerCase();
        // Return only the requested meal section (breakfast/lunch/dinner)
        return {key: data[key] ?? []};
      }
      return data;
    } catch (e) {
      return null;
    }
  }
}
