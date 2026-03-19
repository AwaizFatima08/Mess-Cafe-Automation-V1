import 'package:cloud_firestore/cloud_firestore.dart';

class MealReservationService {
  MealReservationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _reservationsRef =>
      _firestore.collection('meal_reservations');

  Future<void> createReservation({
    required String employeeNumber,
    required String employeeName,
    required DateTime reservationDate,
    required String mealType,
    required String bookingType,
    required String diningMode,
    required int quantity,
    required String createdByUid,
    required String createdByRole,
    String? guestName,
    int guestCount = 0,
    bool isWalkIn = false,
    String? notes,
    String? overrideReason,
  }) async {
    final normalizedEmployeeNumber = employeeNumber.trim();
    final normalizedEmployeeName = employeeName.trim();
    final normalizedMealType = mealType.trim().toLowerCase();
    final normalizedBookingType = bookingType.trim().toLowerCase();
    final normalizedDiningMode = diningMode.trim().toLowerCase();
    final normalizedCreatedByUid = createdByUid.trim();
    final normalizedCreatedByRole = createdByRole.trim().toLowerCase();
    final normalizedGuestName = (guestName ?? '').trim();
    final normalizedNotes = (notes ?? '').trim();
    final normalizedOverrideReason = (overrideReason ?? '').trim();

    if (normalizedEmployeeNumber.isEmpty) {
      throw ArgumentError('employee_number is required.');
    }

    if (normalizedEmployeeName.isEmpty) {
      throw ArgumentError('employee_name is required.');
    }

    if (!_isValidMealType(normalizedMealType)) {
      throw ArgumentError('Invalid meal_type.');
    }

    if (!_isValidBookingType(normalizedBookingType)) {
      throw ArgumentError('Invalid booking_type.');
    }

    if (!_isValidDiningMode(normalizedDiningMode)) {
      throw ArgumentError('Invalid dining_mode.');
    }

    if (quantity <= 0) {
      throw ArgumentError('quantity must be greater than zero.');
    }

    if (normalizedCreatedByUid.isEmpty) {
      throw ArgumentError('created_by_uid is required.');
    }

    if (normalizedCreatedByRole.isEmpty) {
      throw ArgumentError('created_by_role is required.');
    }

    if (normalizedBookingType == 'guest' && guestCount <= 0) {
      throw ArgumentError('guest_count must be greater than zero for guest bookings.');
    }

    final normalizedDate = DateTime(
      reservationDate.year,
      reservationDate.month,
      reservationDate.day,
    );

    final doc = _reservationsRef.doc();

    await doc.set({
      'employee_number': normalizedEmployeeNumber,
      'employee_name': normalizedEmployeeName,
      'reservation_date': Timestamp.fromDate(normalizedDate),
      'meal_type': normalizedMealType,
      'booking_type': normalizedBookingType,
      'dining_mode': normalizedDiningMode,
      'quantity': quantity,
      'guest_count': guestCount,
      'guest_name': normalizedGuestName.isEmpty ? null : normalizedGuestName,
      'is_walk_in': isWalkIn,
      'is_issued': false,
      'created_at': FieldValue.serverTimestamp(),
      'created_by_uid': normalizedCreatedByUid,
      'created_by_role': normalizedCreatedByRole,
      'issued_at': null,
      'issued_by_uid': null,
      'status': 'booked',
      'notes': normalizedNotes.isEmpty ? null : normalizedNotes,
      'override_reason':
          normalizedOverrideReason.isEmpty ? null : normalizedOverrideReason,
    });
  }

  Future<void> markReservationIssued({
    required String reservationId,
    required String issuedByUid,
  }) async {
    final normalizedReservationId = reservationId.trim();
    final normalizedIssuedByUid = issuedByUid.trim();

    if (normalizedReservationId.isEmpty) {
      throw ArgumentError('reservationId is required.');
    }

    if (normalizedIssuedByUid.isEmpty) {
      throw ArgumentError('issuedByUid is required.');
    }

    await _reservationsRef.doc(normalizedReservationId).update({
      'is_issued': true,
      'issued_at': FieldValue.serverTimestamp(),
      'issued_by_uid': normalizedIssuedByUid,
      'status': 'issued',
    });
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getReservationsForDate({
    required DateTime reservationDate,
    String? mealType,
  }) async {
    final normalizedDate = DateTime(
      reservationDate.year,
      reservationDate.month,
      reservationDate.day,
    );

    final nextDate = normalizedDate.add(const Duration(days: 1));

    Query<Map<String, dynamic>> query = _reservationsRef
        .where(
          'reservation_date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(normalizedDate),
        )
        .where(
          'reservation_date',
          isLessThan: Timestamp.fromDate(nextDate),
        );

    final normalizedMealType = (mealType ?? '').trim().toLowerCase();
    if (normalizedMealType.isNotEmpty) {
      query = query.where('meal_type', isEqualTo: normalizedMealType);
    }

    return query.get();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getReservationsForEmployee({
    required String employeeNumber,
  }) async {
    final normalizedEmployeeNumber = employeeNumber.trim();

    if (normalizedEmployeeNumber.isEmpty) {
      throw ArgumentError('employeeNumber is required.');
    }

    return _reservationsRef
        .where('employee_number', isEqualTo: normalizedEmployeeNumber)
        .get();
  }

  Future<Map<String, int>> getMealCountsForDate(DateTime reservationDate) async {
    final snapshot = await getReservationsForDate(
      reservationDate: reservationDate,
    );

    int breakfast = 0;
    int lunch = 0;
    int dinner = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final mealType = (data['meal_type'] ?? '').toString().trim().toLowerCase();
      final quantity = (data['quantity'] ?? 0) is int
          ? data['quantity'] as int
          : int.tryParse((data['quantity'] ?? '0').toString()) ?? 0;

      switch (mealType) {
        case 'breakfast':
          breakfast += quantity;
          break;
        case 'lunch':
          lunch += quantity;
          break;
        case 'dinner':
          dinner += quantity;
          break;
      }
    }

    return {
      'breakfast': breakfast,
      'lunch': lunch,
      'dinner': dinner,
      'total': breakfast + lunch + dinner,
    };
  }

  Future<Map<String, int>> getIssuedMealCountsForDate(DateTime reservationDate) async {
    final snapshot = await getReservationsForDate(
      reservationDate: reservationDate,
    );

    int breakfast = 0;
    int lunch = 0;
    int dinner = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final isIssued = data['is_issued'] == true;
      if (!isIssued) {
        continue;
      }

      final mealType = (data['meal_type'] ?? '').toString().trim().toLowerCase();
      final quantity = (data['quantity'] ?? 0) is int
          ? data['quantity'] as int
          : int.tryParse((data['quantity'] ?? '0').toString()) ?? 0;

      switch (mealType) {
        case 'breakfast':
          breakfast += quantity;
          break;
        case 'lunch':
          lunch += quantity;
          break;
        case 'dinner':
          dinner += quantity;
          break;
      }
    }

    return {
      'breakfast': breakfast,
      'lunch': lunch,
      'dinner': dinner,
      'total': breakfast + lunch + dinner,
    };
  }

  bool _isValidMealType(String value) {
    return value == 'breakfast' || value == 'lunch' || value == 'dinner';
  }

  bool _isValidBookingType(String value) {
    return value == 'self' || value == 'admin' || value == 'guest';
  }

  bool _isValidDiningMode(String value) {
    return value == 'dine_in' || value == 'takeaway';
  }
}
