import 'package:cloud_firestore/cloud_firestore.dart';
import 'meal_rate_service.dart';

class MealReservationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final MealRateService _rateService = MealRateService();

  static const String categoryEmployee = 'employee';
  static const String categoryOfficialGuest = 'official_guest';
  static const String subjectEmployeeSelf = 'self';
  static const String subjectEmployeeProxy = 'proxy';
  static const String subjectOfficialGuest = 'guest';
  static const String bookingSourceEmployeeApp = 'employee_app';
  static const String bookingSourceSupervisorConsole = 'supervisor_console';
  static const String bookingSourceAdminConsole = 'admin_console';
  static const String selectionModeCycleCombo = 'cycle_combo';
  static const String selectionModeManualItem = 'manual_item';

  Stream<List<Map<String, dynamic>>> getFilteredReservations({
    required DateTime date,
    required String mealType,
    String? employeeNumber,
  }) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    Query query = _db.collection('meal_reservations')
        .where('reservation_date', isEqualTo: Timestamp.fromDate(startOfDay))
        .where('meal_type', isEqualTo: mealType.toLowerCase());

    if (employeeNumber != null) {
      query = query.where('employee_number', isEqualTo: employeeNumber);
    }

    return query.snapshots().map((snap) => snap.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {...data, 'id': doc.id, 'unit_rate': (data['unit_rate'] ?? 0.0).toDouble()};
    }).toList());
  }

  Future<QuerySnapshot> getReservationsForDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    return _db.collection('meal_reservations')
        .where('reservation_date', isEqualTo: Timestamp.fromDate(start)).get();
  }

  Future<void> markReservationIssued(String id) async {
    final doc = await _db.collection('meal_reservations').doc(id).get();
    if (!doc.exists) return;
    final data = doc.data()!;
    double rate = await _rateService.getResolvedRate(
      menuItemId: data['menu_item_id'], 
      date: (data['reservation_date'] as Timestamp).toDate(), 
      mealType: data['meal_type']
    );
    await _db.collection('meal_reservations').doc(id).update({
      'is_issued': true,
      'unit_rate': rate,
      'amount': rate,
      'status': 'consumed',
    });
  }

  bool validateReservationRequest({required String mealType, required DateTime date}) => true;

  Future<void> saveReservation(Map<String, dynamic> data) async {
    data['created_at'] = FieldValue.serverTimestamp();
    data['is_issued'] = false;
    await _db.collection('meal_reservations').add(data);
  }
}
