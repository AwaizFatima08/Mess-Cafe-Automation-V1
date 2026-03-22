import 'package:cloud_firestore/cloud_firestore.dart';

class MealReservationService {
  MealReservationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const Map<String, _MealCutoffTime> _defaultCutoffTimes = {
    'breakfast': _MealCutoffTime(hour: 4, minute: 0),
    'lunch': _MealCutoffTime(hour: 10, minute: 0),
    'dinner': _MealCutoffTime(hour: 16, minute: 0),
  };

  CollectionReference<Map<String, dynamic>> get _reservationsRef =>
      _firestore.collection('meal_reservations');

  Future<String> createReservationGroup({
    required String employeeNumber,
    required String employeeName,
    required DateTime reservationDate,
    required String mealType,
    required List<ReservationLineInput> lines,
    required String createdByUid,
    required String createdByRole,
    String? notes,
    String? bookingGroupId,
    bool skipValidation = false,
  }) async {
    final normalizedEmployeeNumber = employeeNumber.trim();
    final normalizedEmployeeName = employeeName.trim();
    final normalizedMealType = mealType.trim().toLowerCase();
    final normalizedCreatedByUid = createdByUid.trim();
    final normalizedCreatedByRole = createdByRole.trim().toLowerCase();
    final normalizedNotes = (notes ?? '').trim();
    final normalizedDate = _normalizeDate(reservationDate);
    final normalizedBookingGroupId = (bookingGroupId ?? '').trim();

    if (normalizedEmployeeNumber.isEmpty) {
      throw ArgumentError('employee_number is required.');
    }

    if (normalizedEmployeeName.isEmpty) {
      throw ArgumentError('employee_name is required.');
    }

    if (!_isValidMealType(normalizedMealType)) {
      throw ArgumentError('Invalid meal_type.');
    }

    if (normalizedCreatedByUid.isEmpty) {
      throw ArgumentError('created_by_uid is required.');
    }

    if (normalizedCreatedByRole.isEmpty) {
      throw ArgumentError('created_by_role is required.');
    }

    if (lines.isEmpty) {
      throw ArgumentError('At least one reservation line is required.');
    }

    if (!skipValidation) {
      final validation = validateReservationRequest(
        reservationDate: normalizedDate,
        mealType: normalizedMealType,
      );

      if (!validation.isAllowed) {
        throw StateError(validation.message);
      }
    }

    for (final line in lines) {
      final normalizedMenuOptionKey = line.menuOptionKey.trim();
      final normalizedOptionLabel = line.optionLabel.trim();
      final normalizedDiningMode = line.diningMode.trim().toLowerCase();

      if (normalizedMenuOptionKey.isEmpty) {
        throw ArgumentError('menu_option_key is required.');
      }

      if (normalizedOptionLabel.isEmpty) {
        throw ArgumentError('option_label is required.');
      }

      if (!_isValidDiningMode(normalizedDiningMode)) {
        throw ArgumentError('Invalid dining_mode.');
      }

      if (line.quantity <= 0) {
        throw ArgumentError('quantity must be greater than zero.');
      }
    }

    final effectiveBookingGroupId = normalizedBookingGroupId.isNotEmpty
        ? normalizedBookingGroupId
        : _reservationsRef.doc().id;

    final batch = _firestore.batch();

    for (final line in lines) {
      final docRef = _reservationsRef.doc();

      batch.set(docRef, {
        'booking_group_id': effectiveBookingGroupId,
        'employee_number': normalizedEmployeeNumber,
        'employee_name': normalizedEmployeeName,
        'reservation_date': Timestamp.fromDate(normalizedDate),
        'meal_type': normalizedMealType,
        'menu_option_key': line.menuOptionKey.trim(),
        'option_label': line.optionLabel.trim(),
        'dining_mode': line.diningMode.trim().toLowerCase(),
        'quantity': line.quantity,
        'status': 'active',
        'is_issued': false,
        'created_at': FieldValue.serverTimestamp(),
        'created_by_uid': normalizedCreatedByUid,
        'created_by_role': normalizedCreatedByRole,
        'issued_at': null,
        'issued_by_uid': null,
        'cancelled_at': null,
        'cancelled_by_uid': null,
        'unit_rate': null,
        'amount': null,
        'notes': normalizedNotes.isEmpty ? null : normalizedNotes,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    return effectiveBookingGroupId;
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
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelReservation({
    required String reservationId,
    required String cancelledByUid,
  }) async {
    final normalizedReservationId = reservationId.trim();
    final normalizedCancelledByUid = cancelledByUid.trim();

    if (normalizedReservationId.isEmpty) {
      throw ArgumentError('reservationId is required.');
    }

    if (normalizedCancelledByUid.isEmpty) {
      throw ArgumentError('cancelledByUid is required.');
    }

    await _reservationsRef.doc(normalizedReservationId).update({
      'status': 'cancelled',
      'cancelled_at': FieldValue.serverTimestamp(),
      'cancelled_by_uid': normalizedCancelledByUid,
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancelReservationGroup({
    required String bookingGroupId,
    required String cancelledByUid,
  }) async {
    final normalizedBookingGroupId = bookingGroupId.trim();
    final normalizedCancelledByUid = cancelledByUid.trim();

    if (normalizedBookingGroupId.isEmpty) {
      throw ArgumentError('bookingGroupId is required.');
    }

    if (normalizedCancelledByUid.isEmpty) {
      throw ArgumentError('cancelledByUid is required.');
    }

    final snapshot = await _reservationsRef
        .where('booking_group_id', isEqualTo: normalizedBookingGroupId)
        .get();

    if (snapshot.docs.isEmpty) {
      return;
    }

    final batch = _firestore.batch();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final status = (data['status'] ?? '').toString().trim().toLowerCase();

      if (status == 'cancelled') {
        continue;
      }

      batch.update(doc.reference, {
        'status': 'cancelled',
        'cancelled_at': FieldValue.serverTimestamp(),
        'cancelled_by_uid': normalizedCancelledByUid,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Future<void> cancelActiveReservationsForEmployeeDateMeal({
    required String employeeNumber,
    required DateTime reservationDate,
    required String mealType,
    required String cancelledByUid,
  }) async {
    final normalizedEmployeeNumber = employeeNumber.trim();
    final normalizedMealType = mealType.trim().toLowerCase();
    final normalizedCancelledByUid = cancelledByUid.trim();

    if (normalizedEmployeeNumber.isEmpty) {
      throw ArgumentError('employeeNumber is required.');
    }

    if (!_isValidMealType(normalizedMealType)) {
      throw ArgumentError('Invalid meal_type.');
    }

    if (normalizedCancelledByUid.isEmpty) {
      throw ArgumentError('cancelledByUid is required.');
    }

    final validation = validateCancellationRequest(
      reservationDate: reservationDate,
      mealType: normalizedMealType,
    );

    if (!validation.isAllowed) {
      throw StateError(validation.message);
    }

    final activeDocs = await getActiveReservationsForEmployeeDateMeal(
      employeeNumber: normalizedEmployeeNumber,
      reservationDate: reservationDate,
      mealType: normalizedMealType,
    );

    if (activeDocs.isEmpty) {
      return;
    }

    final batch = _firestore.batch();

    for (final doc in activeDocs) {
      batch.update(doc.reference, {
        'status': 'cancelled',
        'cancelled_at': FieldValue.serverTimestamp(),
        'cancelled_by_uid': normalizedCancelledByUid,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Future<String> replaceReservationGroupForEmployeeDateMeal({
    required String employeeNumber,
    required String employeeName,
    required DateTime reservationDate,
    required String mealType,
    required List<ReservationLineInput> lines,
    required String updatedByUid,
    required String updatedByRole,
    String? notes,
  }) async {
    final normalizedEmployeeNumber = employeeNumber.trim();
    final normalizedEmployeeName = employeeName.trim();
    final normalizedMealType = mealType.trim().toLowerCase();
    final normalizedUpdatedByUid = updatedByUid.trim();
    final normalizedUpdatedByRole = updatedByRole.trim().toLowerCase();
    final normalizedDate = _normalizeDate(reservationDate);
    final normalizedNotes = (notes ?? '').trim();

    if (normalizedEmployeeNumber.isEmpty) {
      throw ArgumentError('employeeNumber is required.');
    }

    if (normalizedEmployeeName.isEmpty) {
      throw ArgumentError('employeeName is required.');
    }

    if (!_isValidMealType(normalizedMealType)) {
      throw ArgumentError('Invalid meal_type.');
    }

    if (normalizedUpdatedByUid.isEmpty) {
      throw ArgumentError('updatedByUid is required.');
    }

    if (normalizedUpdatedByRole.isEmpty) {
      throw ArgumentError('updatedByRole is required.');
    }

    if (lines.isEmpty) {
      throw ArgumentError('At least one reservation line is required.');
    }

    final validation = validateReservationRequest(
      reservationDate: normalizedDate,
      mealType: normalizedMealType,
    );

    if (!validation.isAllowed) {
      throw StateError(validation.message);
    }

    final activeDocs = await getActiveReservationsForEmployeeDateMeal(
      employeeNumber: normalizedEmployeeNumber,
      reservationDate: normalizedDate,
      mealType: normalizedMealType,
    );

    String? existingBookingGroupId;
    for (final doc in activeDocs) {
      final groupId = (doc.data()['booking_group_id'] ?? '').toString().trim();
      if (groupId.isNotEmpty) {
        existingBookingGroupId = groupId;
        break;
      }
    }

    final batch = _firestore.batch();

    for (final doc in activeDocs) {
      batch.update(doc.reference, {
        'status': 'cancelled',
        'cancelled_at': FieldValue.serverTimestamp(),
        'cancelled_by_uid': normalizedUpdatedByUid,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }

    final effectiveBookingGroupId =
        (existingBookingGroupId != null && existingBookingGroupId.isNotEmpty)
            ? existingBookingGroupId
            : _reservationsRef.doc().id;

    for (final line in lines) {
      final normalizedMenuOptionKey = line.menuOptionKey.trim();
      final normalizedOptionLabel = line.optionLabel.trim();
      final normalizedDiningMode = line.diningMode.trim().toLowerCase();

      if (normalizedMenuOptionKey.isEmpty) {
        throw ArgumentError('menu_option_key is required.');
      }

      if (normalizedOptionLabel.isEmpty) {
        throw ArgumentError('option_label is required.');
      }

      if (!_isValidDiningMode(normalizedDiningMode)) {
        throw ArgumentError('Invalid dining_mode.');
      }

      if (line.quantity <= 0) {
        throw ArgumentError('quantity must be greater than zero.');
      }

      final docRef = _reservationsRef.doc();

      batch.set(docRef, {
        'booking_group_id': effectiveBookingGroupId,
        'employee_number': normalizedEmployeeNumber,
        'employee_name': normalizedEmployeeName,
        'reservation_date': Timestamp.fromDate(normalizedDate),
        'meal_type': normalizedMealType,
        'menu_option_key': normalizedMenuOptionKey,
        'option_label': normalizedOptionLabel,
        'dining_mode': normalizedDiningMode,
        'quantity': line.quantity,
        'status': 'active',
        'is_issued': false,
        'created_at': FieldValue.serverTimestamp(),
        'created_by_uid': normalizedUpdatedByUid,
        'created_by_role': normalizedUpdatedByRole,
        'issued_at': null,
        'issued_by_uid': null,
        'cancelled_at': null,
        'cancelled_by_uid': null,
        'unit_rate': null,
        'amount': null,
        'notes': normalizedNotes.isEmpty ? null : normalizedNotes,
        'updated_at': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
    return effectiveBookingGroupId;
  }

  ReservationValidationResult validateReservationRequest({
    required DateTime reservationDate,
    required String mealType,
    DateTime? now,
    String? overrideReason,
    bool isWalkIn = false,
  }) {
    final normalizedMealType = mealType.trim().toLowerCase();
    if (!_isValidMealType(normalizedMealType)) {
      return const ReservationValidationResult(
        isAllowed: false,
        message: 'Invalid meal type.',
      );
    }

    final normalizedDate = _normalizeDate(reservationDate);
    final current = now ?? DateTime.now();
    final today = _normalizeDate(current);
    final normalizedOverrideReason = (overrideReason ?? '').trim();

    if (normalizedDate.isBefore(today)) {
      if (normalizedOverrideReason.isNotEmpty || isWalkIn) {
        return const ReservationValidationResult(
          isAllowed: true,
          message: 'Past-date reservation allowed by override.',
        );
      }

      return const ReservationValidationResult(
        isAllowed: false,
        message: 'Past-date reservations are not allowed.',
      );
    }

    if (normalizedDate.isAfter(today)) {
      return const ReservationValidationResult(
        isAllowed: true,
        message: 'Future-date reservation allowed.',
      );
    }

    final cutoffDateTime = getMealCutoffDateTime(
      reservationDate: normalizedDate,
      mealType: normalizedMealType,
    );

    if (cutoffDateTime == null) {
      return const ReservationValidationResult(
        isAllowed: false,
        message: 'Cutoff configuration for meal could not be resolved.',
      );
    }

    if (current.isAfter(cutoffDateTime)) {
      if (normalizedOverrideReason.isNotEmpty || isWalkIn) {
        return ReservationValidationResult(
          isAllowed: true,
          message:
              '${_mealLabel(normalizedMealType)} cutoff has passed, but override is present.',
        );
      }

      return ReservationValidationResult(
        isAllowed: false,
        message:
            '${_mealLabel(normalizedMealType)} booking is closed for today. Cutoff time has passed.',
      );
    }

    return ReservationValidationResult(
      isAllowed: true,
      message: '${_mealLabel(normalizedMealType)} booking is open.',
    );
  }

  bool canBookMeal({
    required DateTime reservationDate,
    required String mealType,
    DateTime? now,
    String? overrideReason,
    bool isWalkIn = false,
  }) {
    return validateReservationRequest(
      reservationDate: reservationDate,
      mealType: mealType,
      now: now,
      overrideReason: overrideReason,
      isWalkIn: isWalkIn,
    ).isAllowed;
  }

  ReservationValidationResult validateCancellationRequest({
    required DateTime reservationDate,
    required String mealType,
    DateTime? now,
    String? overrideReason,
  }) {
    final normalizedMealType = mealType.trim().toLowerCase();
    if (!_isValidMealType(normalizedMealType)) {
      return const ReservationValidationResult(
        isAllowed: false,
        message: 'Invalid meal type.',
      );
    }

    final normalizedDate = _normalizeDate(reservationDate);
    final current = now ?? DateTime.now();
    final today = _normalizeDate(current);
    final normalizedOverrideReason = (overrideReason ?? '').trim();

    if (normalizedDate.isBefore(today)) {
      if (normalizedOverrideReason.isNotEmpty) {
        return const ReservationValidationResult(
          isAllowed: true,
          message: 'Past-date cancellation allowed by override.',
        );
      }

      return const ReservationValidationResult(
        isAllowed: false,
        message: 'Past-date reservation cannot be cancelled.',
      );
    }

    if (normalizedDate.isAfter(today)) {
      return const ReservationValidationResult(
        isAllowed: true,
        message: 'Future reservation can be cancelled.',
      );
    }

    final cutoffDateTime = getMealCutoffDateTime(
      reservationDate: normalizedDate,
      mealType: normalizedMealType,
    );

    if (cutoffDateTime == null) {
      return const ReservationValidationResult(
        isAllowed: false,
        message: 'Cutoff configuration for meal could not be resolved.',
      );
    }

    if (current.isAfter(cutoffDateTime)) {
      if (normalizedOverrideReason.isNotEmpty) {
        return ReservationValidationResult(
          isAllowed: true,
          message:
              '${_mealLabel(normalizedMealType)} cancellation allowed by override after cutoff.',
        );
      }

      return ReservationValidationResult(
        isAllowed: false,
        message:
            '${_mealLabel(normalizedMealType)} reservation can no longer be cancelled. Cutoff time has passed.',
      );
    }

    return ReservationValidationResult(
      isAllowed: true,
      message: '${_mealLabel(normalizedMealType)} reservation can be cancelled.',
    );
  }

  bool canCancelMeal({
    required DateTime reservationDate,
    required String mealType,
    DateTime? now,
    String? overrideReason,
  }) {
    return validateCancellationRequest(
      reservationDate: reservationDate,
      mealType: mealType,
      now: now,
      overrideReason: overrideReason,
    ).isAllowed;
  }

  DateTime? getMealCutoffDateTime({
    required DateTime reservationDate,
    required String mealType,
  }) {
    final normalizedMealType = mealType.trim().toLowerCase();
    final normalizedDate = _normalizeDate(reservationDate);
    final cutoff = _defaultCutoffTimes[normalizedMealType];

    if (cutoff == null) {
      return null;
    }

    return DateTime(
      normalizedDate.year,
      normalizedDate.month,
      normalizedDate.day,
      cutoff.hour,
      cutoff.minute,
    );
  }

  String getMealCutoffDisplay({
    required DateTime reservationDate,
    required String mealType,
  }) {
    final cutoff = getMealCutoffDateTime(
      reservationDate: reservationDate,
      mealType: mealType,
    );

    if (cutoff == null) {
      return 'N/A';
    }

    final hour = cutoff.hour.toString().padLeft(2, '0');
    final minute = cutoff.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getReservationsForDate({
    required DateTime reservationDate,
    String? mealType,
  }) async {
    final normalizedDate = _normalizeDate(reservationDate);
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

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      getPendingReservationsForDate({
    required DateTime reservationDate,
    String? mealType,
  }) async {
    final normalizedDate = _normalizeDate(reservationDate);
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

    final snapshot = await query.get();

    return snapshot.docs.where((doc) {
      final data = doc.data();
      final status = (data['status'] ?? '').toString().trim().toLowerCase();
      return status == 'active';
    }).toList();
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

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      getActiveReservationsForEmployeeDateMeal({
    required String employeeNumber,
    required DateTime reservationDate,
    required String mealType,
  }) async {
    final normalizedEmployeeNumber = employeeNumber.trim();
    final normalizedMealType = mealType.trim().toLowerCase();
    final normalizedDate = _normalizeDate(reservationDate);
    final nextDate = normalizedDate.add(const Duration(days: 1));

    if (normalizedEmployeeNumber.isEmpty) {
      throw ArgumentError('employeeNumber is required.');
    }

    if (!_isValidMealType(normalizedMealType)) {
      throw ArgumentError('Invalid meal_type.');
    }

    final snapshot = await _reservationsRef
        .where('employee_number', isEqualTo: normalizedEmployeeNumber)
        .where('meal_type', isEqualTo: normalizedMealType)
        .where(
          'reservation_date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(normalizedDate),
        )
        .where(
          'reservation_date',
          isLessThan: Timestamp.fromDate(nextDate),
        )
        .get();

    return snapshot.docs.where((doc) {
      final data = doc.data();
      final status = (data['status'] ?? '').toString().trim().toLowerCase();
      return status == 'active';
    }).toList();
  }

  Future<String?> getActiveBookingGroupIdForEmployeeDateMeal({
    required String employeeNumber,
    required DateTime reservationDate,
    required String mealType,
  }) async {
    final activeDocs = await getActiveReservationsForEmployeeDateMeal(
      employeeNumber: employeeNumber,
      reservationDate: reservationDate,
      mealType: mealType,
    );

    for (final doc in activeDocs) {
      final bookingGroupId =
          (doc.data()['booking_group_id'] ?? '').toString().trim();
      if (bookingGroupId.isNotEmpty) {
        return bookingGroupId;
      }
    }

    return null;
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
      final status = (data['status'] ?? '').toString().trim().toLowerCase();

      if (status == 'cancelled') {
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

  Future<Map<String, int>> getIssuedMealCountsForDate(
    DateTime reservationDate,
  ) async {
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

      final status = (data['status'] ?? '').toString().trim().toLowerCase();
      if (status == 'cancelled') {
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

  DateTime _normalizeDate(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  bool _isValidMealType(String value) {
    return value == 'breakfast' || value == 'lunch' || value == 'dinner';
  }

  bool _isValidDiningMode(String value) {
    return value == 'dine_in' || value == 'takeaway';
  }

  String _mealLabel(String value) {
    switch (value) {
      case 'breakfast':
        return 'Breakfast';
      case 'lunch':
        return 'Lunch';
      case 'dinner':
        return 'Dinner';
      default:
        return value;
    }
  }
}

class ReservationLineInput {
  final String menuOptionKey;
  final String optionLabel;
  final String diningMode;
  final int quantity;

  const ReservationLineInput({
    required this.menuOptionKey,
    required this.optionLabel,
    required this.diningMode,
    required this.quantity,
  });
}

class ReservationValidationResult {
  final bool isAllowed;
  final String message;

  const ReservationValidationResult({
    required this.isAllowed,
    required this.message,
  });
}

class _MealCutoffTime {
  final int hour;
  final int minute;

  const _MealCutoffTime({
    required this.hour,
    required this.minute,
  });
}
