import 'package:cloud_firestore/cloud_firestore.dart';

import 'meal_rate_service.dart';
import 'notification_service.dart';

class MealReservationService {
  MealReservationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final MealRateService _mealRateService = MealRateService();
  final NotificationService _notificationService = NotificationService();

  static const Map<String, _MealCutoffTime> _defaultCutoffTimes = {
    'breakfast': _MealCutoffTime(hour: 4, minute: 0),
    'lunch': _MealCutoffTime(hour: 10, minute: 0),
    'dinner': _MealCutoffTime(hour: 16, minute: 0),
  };

  static const String categoryEmployee = 'employee';
  static const String categoryOfficialGuest = 'official_guest';

  static const String bookingSourceEmployeeApp = 'employee_app';
  static const String bookingSourceSupervisorConsole = 'supervisor_console';
  static const String bookingSourceAdminConsole = 'admin_console';

  static const String subjectEmployeeSelf = 'employee_self';
  static const String subjectEmployeeProxy = 'employee_proxy';
  static const String subjectOfficialGuest = 'official_guest';

  static const String bookingModeSelf = 'self';
  static const String bookingModeProxy = 'proxy';
  static const String bookingModeGuest = 'guest';

  static const String selectionModeCycleCombo = 'cycle_combo';
  static const String selectionModeManualItem = 'manual_item';

  CollectionReference<Map<String, dynamic>> get _reservationsRef =>
      _firestore.collection('meal_reservations');

  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  Future<String> createReservationGroup({
    required String employeeNumber,
    required String employeeName,
    required DateTime reservationDate,
    required String mealType,
    required List<ReservationLineInput> lines,
    required String createdByUid,
    required String createdByRole,
    String? createdByEmployeeNumber,
    String? createdByName,
    String? notes,
    String? bookingGroupId,
    bool skipValidation = false,
    String bookingSource = bookingSourceEmployeeApp,
    String bookingSubjectType = subjectEmployeeSelf,
    String reservationCategory = categoryEmployee,
    String? overrideReason,
    Map<String, dynamic>? extraFields,
  }) async {
    final normalizedEmployeeNumber = employeeNumber.trim();
    final normalizedEmployeeName = employeeName.trim();
    final normalizedMealType = _normalizeMealType(mealType);
    final normalizedDate = _normalizeDate(reservationDate);
    final normalizedCreatedByUid = createdByUid.trim();
    final normalizedCreatedByRole = createdByRole.trim().toLowerCase();
    final normalizedOverrideReason = (overrideReason ?? '').trim();

    if (normalizedEmployeeNumber.isEmpty) {
      throw ArgumentError('employeeNumber is required.');
    }
    if (normalizedEmployeeName.isEmpty) {
      throw ArgumentError('employeeName is required.');
    }
    if (!_isValidMealType(normalizedMealType)) {
      throw ArgumentError('Unsupported meal type: $mealType');
    }
    if (normalizedCreatedByUid.isEmpty) {
      throw ArgumentError('createdByUid is required.');
    }
    if (normalizedCreatedByRole.isEmpty) {
      throw ArgumentError('createdByRole is required.');
    }

    final sanitizedLines = lines
        .where((line) => line.quantity > 0)
        .map((line) => line.normalized())
        .where(
          (line) =>
              line.optionKey.isNotEmpty &&
              line.optionLabel.isNotEmpty &&
              line.diningMode.isNotEmpty,
        )
        .toList();

    if (sanitizedLines.isEmpty) {
      throw ArgumentError('At least one valid reservation line is required.');
    }

    if (!skipValidation) {
      final validation = validateReservationRequest(
        reservationDate: normalizedDate,
        mealType: normalizedMealType,
        overrideReason:
            normalizedOverrideReason.isEmpty ? null : normalizedOverrideReason,
      );

      if (!validation.isAllowed) {
        throw StateError(validation.message);
      }
    }

    final now = Timestamp.now();
    final effectiveBookingGroupId =
        bookingGroupId?.trim().isNotEmpty == true
            ? bookingGroupId!.trim()
            : _reservationsRef.doc().id;

    final batch = _firestore.batch();

    for (final line in sanitizedLines) {
      final docRef = _reservationsRef.doc();

      final payload = <String, dynamic>{
        'booking_group_id': effectiveBookingGroupId,
        'reservation_category': reservationCategory,
        'booking_source': bookingSource,
        'booking_subject_type': bookingSubjectType,
        'employee_number': normalizedEmployeeNumber,
        'employee_name': normalizedEmployeeName,
        'guest_name': '',
        'host_employee_number': '',
        'host_employee_name': '',
        'reservation_date': Timestamp.fromDate(normalizedDate),
        'meal_type': normalizedMealType,
        'menu_option_key': line.optionKey,
        'option_label': line.optionLabel,
        'dining_mode': line.diningMode,
        'quantity': line.quantity,
        'menu_snapshot': line.menuSnapshot ?? <String, dynamic>{},
        'unit_rate': null,
        'amount': null,
        'notes': notes?.trim() ?? '',
        'created_at': now,
        'booking_time': now,
        'created_by_uid': normalizedCreatedByUid,
        'created_by_role': normalizedCreatedByRole,
        'created_by_employee_number': createdByEmployeeNumber?.trim() ?? '',
        'created_by_name': createdByName?.trim() ?? '',
        'status': 'active',
        'is_issued': false,
        'override_reason':
            normalizedOverrideReason.isEmpty ? '' : normalizedOverrideReason,
      };

      if (extraFields != null && extraFields.isNotEmpty) {
        payload.addAll(extraFields);
      }

      batch.set(docRef, payload);
    }

    await batch.commit();

    await _sendBookingConfirmedNotificationIfPossible(
      employeeNumber: normalizedEmployeeNumber,
      employeeName: normalizedEmployeeName,
      reservationDate: normalizedDate,
      mealType: normalizedMealType,
      reservationId: effectiveBookingGroupId,
      reservationCategory: reservationCategory,
    );

    return effectiveBookingGroupId;
  }

  Future<String> createProxyEmployeeReservationGroup({
    required String employeeNumber,
    required String employeeName,
    required DateTime reservationDate,
    required String mealType,
    required List<ReservationLineInput> lines,
    required String createdByUid,
    required String createdByRole,
    String? createdByEmployeeNumber,
    String? createdByName,
    String? notes,
    String? bookingGroupId,
    String? overrideReason,
    bool skipValidation = false,
    String? bookingSource,
    String selectionMode = selectionModeCycleCombo,
    String requestContext = 'proxy_request',
    bool isSpecialMeal = false,
    bool allowAnyMenuItem = false,
    Map<String, dynamic>? extraFields,
  }) async {
    final normalizedRole = createdByRole.trim().toLowerCase();
    final roleCanWaiveCutoff = canWaiveCutoffForRole(normalizedRole);
    final normalizedOverrideReason = (overrideReason ?? '').trim();
    final effectiveSkipValidation = skipValidation || roleCanWaiveCutoff;

    final effectiveExtraFields = <String, dynamic>{
      'booking_mode': bookingModeProxy,
      'selection_mode': selectionMode.trim().isEmpty
          ? selectionModeCycleCombo
          : selectionMode.trim().toLowerCase(),
      'request_context':
          requestContext.trim().isEmpty ? 'proxy_request' : requestContext.trim(),
      'is_special_meal': isSpecialMeal,
      'allow_any_menu_item': allowAnyMenuItem,
      'cutoff_waived': roleCanWaiveCutoff,
      'proxy_override_used':
          roleCanWaiveCutoff || normalizedOverrideReason.isNotEmpty,
    };

    if (extraFields != null && extraFields.isNotEmpty) {
      effectiveExtraFields.addAll(extraFields);
    }

    return createReservationGroup(
      employeeNumber: employeeNumber,
      employeeName: employeeName,
      reservationDate: reservationDate,
      mealType: mealType,
      lines: lines,
      createdByUid: createdByUid,
      createdByRole: normalizedRole,
      createdByEmployeeNumber: createdByEmployeeNumber,
      createdByName: createdByName,
      notes: notes,
      bookingGroupId: bookingGroupId,
      skipValidation: effectiveSkipValidation,
      bookingSource:
          bookingSource ??
          _resolveOperatorBookingSource(createdByRole: normalizedRole),
      bookingSubjectType: subjectEmployeeProxy,
      reservationCategory: categoryEmployee,
      overrideReason:
          normalizedOverrideReason.isEmpty ? null : normalizedOverrideReason,
      extraFields: effectiveExtraFields,
    );
  }

  Future<String> createGuestReservationGroup({
    required String guestName,
    required String hostEmployeeNumber,
    required DateTime reservationDate,
    required String mealType,
    required List<ReservationLineInput> lines,
    required String createdByUid,
    required String createdByRole,
    String? createdByEmployeeNumber,
    String? createdByName,
    String? hostEmployeeName,
    String? notes,
    String? bookingGroupId,
    String? overrideReason,
    bool skipValidation = false,
    String? bookingSource,
  }) async {
    final normalizedGuestName = guestName.trim();
    final normalizedHostEmployeeNumber = hostEmployeeNumber.trim();
    final normalizedMealType = _normalizeMealType(mealType);
    final normalizedDate = _normalizeDate(reservationDate);
    final normalizedCreatedByUid = createdByUid.trim();
    final normalizedCreatedByRole = createdByRole.trim().toLowerCase();
    final normalizedOverrideReason = (overrideReason ?? '').trim();

    if (normalizedGuestName.isEmpty) {
      throw ArgumentError('guestName is required.');
    }
    if (normalizedHostEmployeeNumber.isEmpty) {
      throw ArgumentError('hostEmployeeNumber is required.');
    }
    if (!_isValidMealType(normalizedMealType)) {
      throw ArgumentError('Unsupported meal type: $mealType');
    }
    if (normalizedCreatedByUid.isEmpty) {
      throw ArgumentError('createdByUid is required.');
    }
    if (normalizedCreatedByRole.isEmpty) {
      throw ArgumentError('createdByRole is required.');
    }

    final sanitizedLines = lines
        .where((line) => line.quantity > 0)
        .map((line) => line.normalized())
        .where(
          (line) =>
              line.optionKey.isNotEmpty &&
              line.optionLabel.isNotEmpty &&
              line.diningMode.isNotEmpty,
        )
        .toList();

    if (sanitizedLines.isEmpty) {
      throw ArgumentError('At least one valid reservation line is required.');
    }

    if (!skipValidation) {
      final validation = validateReservationRequest(
        reservationDate: normalizedDate,
        mealType: normalizedMealType,
        overrideReason:
            normalizedOverrideReason.isEmpty ? null : normalizedOverrideReason,
      );

      if (!validation.isAllowed) {
        throw StateError(validation.message);
      }
    }

    final now = Timestamp.now();
    final effectiveBookingGroupId =
        bookingGroupId?.trim().isNotEmpty == true
            ? bookingGroupId!.trim()
            : _reservationsRef.doc().id;

    final effectiveBookingSource =
        bookingSource ??
        _resolveOperatorBookingSource(createdByRole: normalizedCreatedByRole);

    final batch = _firestore.batch();

    for (final line in sanitizedLines) {
      final docRef = _reservationsRef.doc();

      batch.set(docRef, {
        'booking_group_id': effectiveBookingGroupId,
        'reservation_category': categoryOfficialGuest,
        'booking_source': effectiveBookingSource,
        'booking_subject_type': subjectOfficialGuest,
        'booking_mode': bookingModeGuest,
        'selection_mode': selectionModeCycleCombo,
        'employee_number': '',
        'employee_name': '',
        'guest_name': normalizedGuestName,
        'host_employee_number': normalizedHostEmployeeNumber,
        'host_employee_name': hostEmployeeName?.trim() ?? '',
        'reservation_date': Timestamp.fromDate(normalizedDate),
        'meal_type': normalizedMealType,
        'menu_option_key': line.optionKey,
        'option_label': line.optionLabel,
        'dining_mode': line.diningMode,
        'quantity': line.quantity,
        'menu_snapshot': line.menuSnapshot ?? <String, dynamic>{},
        'unit_rate': null,
        'amount': null,
        'notes': notes?.trim() ?? '',
        'created_at': now,
        'booking_time': now,
        'created_by_uid': normalizedCreatedByUid,
        'created_by_role': normalizedCreatedByRole,
        'created_by_employee_number': createdByEmployeeNumber?.trim() ?? '',
        'created_by_name': createdByName?.trim() ?? '',
        'status': 'active',
        'is_issued': false,
        'override_reason':
            normalizedOverrideReason.isEmpty ? '' : normalizedOverrideReason,
      });
    }

    await batch.commit();
    return effectiveBookingGroupId;
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getReservationsForDate({
    required DateTime reservationDate,
  }) async {
    final normalizedDate = _normalizeDate(reservationDate);
    final nextDate = normalizedDate.add(const Duration(days: 1));

    return _reservationsRef
        .where(
          'reservation_date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(normalizedDate),
        )
        .where(
          'reservation_date',
          isLessThan: Timestamp.fromDate(nextDate),
        )
        .get();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getPendingReservationsForDate({
    required DateTime reservationDate,
  }) async {
    final normalizedDate = _normalizeDate(reservationDate);
    final nextDate = normalizedDate.add(const Duration(days: 1));

    return _reservationsRef
        .where(
          'reservation_date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(normalizedDate),
        )
        .where(
          'reservation_date',
          isLessThan: Timestamp.fromDate(nextDate),
        )
        .where('status', isEqualTo: 'active')
        .where('is_issued', isEqualTo: false)
        .get();
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

  Future<QuerySnapshot<Map<String, dynamic>>> getReservationsForEmployeeDate({
    required String employeeNumber,
    required DateTime reservationDate,
  }) async {
    final normalizedEmployeeNumber = employeeNumber.trim();
    final normalizedDate = _normalizeDate(reservationDate);
    final nextDate = normalizedDate.add(const Duration(days: 1));

    if (normalizedEmployeeNumber.isEmpty) {
      throw ArgumentError('employeeNumber is required.');
    }

    return _reservationsRef
        .where('employee_number', isEqualTo: normalizedEmployeeNumber)
        .where(
          'reservation_date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(normalizedDate),
        )
        .where(
          'reservation_date',
          isLessThan: Timestamp.fromDate(nextDate),
        )
        .get();
  }

  Future<QuerySnapshot<Map<String, dynamic>>>
      getActiveReservationsForEmployeeDateMeal({
    required String employeeNumber,
    required DateTime reservationDate,
    required String mealType,
  }) async {
    final normalizedEmployeeNumber = employeeNumber.trim();
    final normalizedMealType = _normalizeMealType(mealType);
    final normalizedDate = _normalizeDate(reservationDate);
    final nextDate = normalizedDate.add(const Duration(days: 1));

    if (normalizedEmployeeNumber.isEmpty) {
      throw ArgumentError('employeeNumber is required.');
    }

    return _reservationsRef
        .where('employee_number', isEqualTo: normalizedEmployeeNumber)
        .where(
          'reservation_date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(normalizedDate),
        )
        .where(
          'reservation_date',
          isLessThan: Timestamp.fromDate(nextDate),
        )
        .where('meal_type', isEqualTo: normalizedMealType)
        .where('status', isEqualTo: 'active')
        .get();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> getReservationsForDateAndMealType({
    required DateTime reservationDate,
    required String mealType,
  }) async {
    final normalizedDate = _normalizeDate(reservationDate);
    final nextDate = normalizedDate.add(const Duration(days: 1));
    final normalizedMealType = _normalizeMealType(mealType);

    return _reservationsRef
        .where(
          'reservation_date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(normalizedDate),
        )
        .where(
          'reservation_date',
          isLessThan: Timestamp.fromDate(nextDate),
        )
        .where('meal_type', isEqualTo: normalizedMealType)
        .get();
  }

  Future<void> cancelReservation({
    required String reservationId,
    required String cancelledByUid,
    required String cancelledByRole,
    String? overrideReason,
  }) async {
    final docRef = _reservationsRef.doc(reservationId);
    final snapshot = await docRef.get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw Exception('Reservation not found.');
    }

    final data = snapshot.data()!;
    final status = (data['status'] ?? '').toString().trim().toLowerCase();
    final isIssued = data['is_issued'] == true;

    if (status == 'cancelled') {
      throw Exception('Reservation already cancelled.');
    }
    if (isIssued || status == 'issued') {
      throw Exception('Issued reservation cannot be cancelled.');
    }

    final employeeNumber = (data['employee_number'] ?? '').toString().trim();
    final employeeName = (data['employee_name'] ?? '').toString().trim();
    final mealType = _normalizeMealType((data['meal_type'] ?? '').toString());
    final reservationDate = _readReservationDate(data['reservation_date']);

    await docRef.update({
      'status': 'cancelled',
      'cancelled_at': Timestamp.now(),
      'cancelled_by_uid': cancelledByUid.trim(),
      'cancelled_by_role': cancelledByRole.trim().toLowerCase(),
      'override_reason': overrideReason?.trim() ?? '',
    });

    await _sendBookingCancelledNotificationIfPossible(
      employeeNumber: employeeNumber,
      employeeName: employeeName,
      reservationDate: reservationDate,
      mealType: mealType,
      reservationId: reservationId,
      reservationCategory:
          (data['reservation_category'] ?? '').toString().trim(),
    );
  }

  Future<void> cancelReservationGroup({
    required String bookingGroupId,
    required String cancelledByUid,
    required String cancelledByRole,
    String? overrideReason,
  }) async {
    final snapshot = await _reservationsRef
        .where('booking_group_id', isEqualTo: bookingGroupId.trim())
        .where('status', isEqualTo: 'active')
        .where('is_issued', isEqualTo: false)
        .get();

    if (snapshot.docs.isEmpty) {
      throw Exception('No active reservations found in booking group.');
    }

    final firstData = snapshot.docs.first.data();
    final employeeNumber =
        (firstData['employee_number'] ?? '').toString().trim();
    final employeeName = (firstData['employee_name'] ?? '').toString().trim();
    final mealType = _normalizeMealType((firstData['meal_type'] ?? '').toString());
    final reservationDate = _readReservationDate(firstData['reservation_date']);
    final reservationCategory =
        (firstData['reservation_category'] ?? '').toString().trim();

    final batch = _firestore.batch();
    final now = Timestamp.now();

    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'status': 'cancelled',
        'cancelled_at': now,
        'cancelled_by_uid': cancelledByUid.trim(),
        'cancelled_by_role': cancelledByRole.trim().toLowerCase(),
        'override_reason': overrideReason?.trim() ?? '',
      });
    }

    await batch.commit();

    await _sendBookingCancelledNotificationIfPossible(
      employeeNumber: employeeNumber,
      employeeName: employeeName,
      reservationDate: reservationDate,
      mealType: mealType,
      reservationId: bookingGroupId.trim(),
      reservationCategory: reservationCategory,
    );
  }

  Future<void> markReservationIssued({
    required String reservationId,
    required String issuedByUid,
    String issuedByRole = 'mess_dashboard_operator',
  }) async {
    final docRef = _reservationsRef.doc(reservationId);
    final snapshot = await docRef.get();

    if (!snapshot.exists || snapshot.data() == null) {
      throw Exception('Reservation not found.');
    }

    final data = snapshot.data()!;
    final status = (data['status'] ?? '').toString().trim().toLowerCase();
    final isIssued = data['is_issued'] == true;

    if (status == 'cancelled') {
      throw Exception('Cancelled reservation cannot be issued.');
    }
    if (isIssued || status == 'issued') {
      throw Exception('Reservation already issued.');
    }

    final employeeNumber = (data['employee_number'] ?? '').toString().trim();
    final employeeName = (data['employee_name'] ?? '').toString().trim();
    final mealType = _normalizeMealType((data['meal_type'] ?? '').toString());
    final reservationDate = _readReservationDate(data['reservation_date']);
    final reservationCategory =
        (data['reservation_category'] ?? '').toString().trim();

    await docRef.update({
      'is_issued': true,
      'status': 'issued',
      'issued_at': Timestamp.now(),
      'issued_by_uid': issuedByUid.trim(),
      'issued_by_role': issuedByRole.trim().toLowerCase(),
    });

    await _sendMealIssuedNotificationIfPossible(
      employeeNumber: employeeNumber,
      employeeName: employeeName,
      reservationDate: reservationDate,
      mealType: mealType,
      reservationId: reservationId,
      reservationCategory: reservationCategory,
    );
  }

  Future<Map<String, int>> getMealCountsForDate(DateTime reservationDate) async {
    final snapshot = await getReservationsForDate(
      reservationDate: reservationDate,
    );

    final counts = <String, int>{
      'breakfast': 0,
      'lunch': 0,
      'dinner': 0,
      'total': 0,
    };

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final status = (data['status'] ?? '').toString().trim().toLowerCase();
      final mealType = _normalizeMealType((data['meal_type'] ?? '').toString());
      final qty = _readInt(data['quantity']);

      if (status == 'cancelled' || qty <= 0) {
        continue;
      }

      if (counts.containsKey(mealType)) {
        counts[mealType] = (counts[mealType] ?? 0) + qty;
      }
      counts['total'] = (counts['total'] ?? 0) + qty;
    }

    return counts;
  }

  Future<Map<String, int>> getIssuedMealCountsForDate(
    DateTime reservationDate,
  ) async {
    final snapshot = await getReservationsForDate(
      reservationDate: reservationDate,
    );

    final counts = <String, int>{
      'breakfast': 0,
      'lunch': 0,
      'dinner': 0,
      'total': 0,
    };

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final status = (data['status'] ?? '').toString().trim().toLowerCase();
      final isIssued = data['is_issued'] == true || status == 'issued';
      final mealType = _normalizeMealType((data['meal_type'] ?? '').toString());
      final qty = _readInt(data['quantity']);

      if (!isIssued || qty <= 0) {
        continue;
      }

      if (counts.containsKey(mealType)) {
        counts[mealType] = (counts[mealType] ?? 0) + qty;
      }
      counts['total'] = (counts['total'] ?? 0) + qty;
    }

    return counts;
  }

  Future<int> applyRatesToReservationsForDate(DateTime date) async {
    return _mealRateService.applyRatesToReservationsForDate(date);
  }

  String extractMenuItemId(Map<String, dynamic> reservationData) {
    return _mealRateService.extractReservationMenuItemId(reservationData);
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

  BookingValidationResult validateBookingWindow({
    required String mealType,
    required DateTime reservationDate,
    DateTime? now,
  }) {
    final result = validateReservationRequest(
      reservationDate: reservationDate,
      mealType: mealType,
      now: now,
    );

    return BookingValidationResult(
      isAllowed: result.isAllowed,
      message: result.message,
    );
  }

  CancellationValidationResult validateCancellationWindow({
    required DateTime reservationDate,
    required bool isIssued,
    required String status,
  }) {
    final normalizedDate = _normalizeDate(reservationDate);
    final today = _normalizeDate(DateTime.now());
    final normalizedStatus = status.trim().toLowerCase();

    if (normalizedStatus == 'cancelled') {
      return const CancellationValidationResult(
        isAllowed: false,
        message: 'Reservation already cancelled.',
      );
    }

    if (isIssued || normalizedStatus == 'issued') {
      return const CancellationValidationResult(
        isAllowed: false,
        message: 'Issued reservation cannot be cancelled.',
      );
    }

    if (normalizedDate.isBefore(today)) {
      return const CancellationValidationResult(
        isAllowed: false,
        message: 'Past reservation cannot be cancelled.',
      );
    }

    return const CancellationValidationResult(
      isAllowed: true,
      message: 'Cancellation allowed.',
    );
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
      return '—';
    }

    final hour = cutoff.hour.toString().padLeft(2, '0');
    final minute = cutoff.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  bool canWaiveCutoffForRole(String role) {
    final normalizedRole = role.trim().toLowerCase();
    return normalizedRole == 'admin' ||
        normalizedRole == 'developer' ||
        normalizedRole == 'mess_manager' ||
        normalizedRole == 'mess_supervisor';
  }

  Future<void> _sendBookingConfirmedNotificationIfPossible({
    required String employeeNumber,
    required String employeeName,
    required DateTime reservationDate,
    required String mealType,
    required String reservationId,
    required String reservationCategory,
  }) async {
    if (reservationCategory.trim().toLowerCase() != categoryEmployee) {
      return;
    }

    final recipient = await _findRecipientByEmployeeNumber(employeeNumber);
    if (recipient == null) {
      return;
    }

    try {
      await _notificationService.createBookingConfirmedNotification(
        userUid: recipient.userUid,
        employeeNumber: employeeNumber,
        employeeName: employeeName,
        email: recipient.email,
        reservationId: reservationId,
        reservationDate: reservationDate,
        mealType: mealType,
      );
    } catch (_) {}
  }

  Future<void> _sendBookingCancelledNotificationIfPossible({
    required String employeeNumber,
    required String employeeName,
    required DateTime reservationDate,
    required String mealType,
    required String reservationId,
    required String reservationCategory,
  }) async {
    if (reservationCategory.trim().toLowerCase() != categoryEmployee) {
      return;
    }

    final recipient = await _findRecipientByEmployeeNumber(employeeNumber);
    if (recipient == null) {
      return;
    }

    try {
      await _notificationService.createBookingCancelledNotification(
        userUid: recipient.userUid,
        employeeNumber: employeeNumber,
        employeeName: employeeName,
        email: recipient.email,
        reservationId: reservationId,
        reservationDate: reservationDate,
        mealType: mealType,
      );
    } catch (_) {}
  }

  Future<void> _sendMealIssuedNotificationIfPossible({
    required String employeeNumber,
    required String employeeName,
    required DateTime reservationDate,
    required String mealType,
    required String reservationId,
    required String reservationCategory,
  }) async {
    if (reservationCategory.trim().toLowerCase() != categoryEmployee) {
      return;
    }

    final recipient = await _findRecipientByEmployeeNumber(employeeNumber);
    if (recipient == null) {
      return;
    }

    try {
      await _notificationService.createMealIssuedNotification(
        userUid: recipient.userUid,
        employeeNumber: employeeNumber,
        employeeName: employeeName,
        email: recipient.email,
        reservationId: reservationId,
        reservationDate: reservationDate,
        mealType: mealType,
      );
    } catch (_) {}
  }

  Future<_NotificationRecipient?> _findRecipientByEmployeeNumber(
    String employeeNumber,
  ) async {
    final normalizedEmployeeNumber = employeeNumber.trim();
    if (normalizedEmployeeNumber.isEmpty) {
      return null;
    }

    final query = await _usersRef
        .where('employee_number', isEqualTo: normalizedEmployeeNumber)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return null;
    }

    final data = query.docs.first.data();
    final userUid = (data['uid'] ?? '').toString().trim();
    if (userUid.isEmpty) {
      return null;
    }

    return _NotificationRecipient(
      userUid: userUid,
      email: (data['email'] ?? '').toString().trim(),
    );
  }

  String _resolveOperatorBookingSource({
    required String createdByRole,
  }) {
    final role = createdByRole.trim().toLowerCase();

    if (role == 'mess_supervisor') {
      return bookingSourceSupervisorConsole;
    }
    if (role == 'mess_manager' || role == 'admin' || role == 'developer') {
      return bookingSourceAdminConsole;
    }
    return bookingSourceEmployeeApp;
  }

  bool _isValidMealType(String mealType) {
    return mealType == 'breakfast' ||
        mealType == 'lunch' ||
        mealType == 'dinner';
  }

  String _normalizeMealType(String mealType) {
    return mealType.trim().toLowerCase();
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _readReservationDate(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      return _normalizeDate(date);
    }
    if (value is DateTime) {
      return _normalizeDate(value);
    }
    return _normalizeDate(DateTime.now());
  }

  int _readInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse((value ?? '0').toString()) ?? 0;
  }

  String _mealLabel(String mealType) {
    switch (mealType) {
      case 'breakfast':
        return 'Breakfast';
      case 'lunch':
        return 'Lunch';
      case 'dinner':
        return 'Dinner';
      default:
        return mealType;
    }
  }
}

class _MealCutoffTime {
  const _MealCutoffTime({
    required this.hour,
    required this.minute,
  });

  final int hour;
  final int minute;
}

class ReservationLineInput {
  ReservationLineInput({
    String? optionKey,
    String? menuOptionKey,
    String? optionLabel,
    required this.diningMode,
    this.quantity = 1,
    Map<String, dynamic>? menuSnapshot,
  })  : optionKey = (optionKey ?? menuOptionKey ?? '').trim(),
        optionLabel = (optionLabel ?? '').trim(),
        menuSnapshot = menuSnapshot == null
            ? null
            : Map<String, dynamic>.from(menuSnapshot) {
    if (this.optionKey.isEmpty) {
      throw ArgumentError('optionKey or menuOptionKey is required.');
    }
    if (this.optionLabel.isEmpty) {
      throw ArgumentError('optionLabel is required.');
    }
  }

  final String optionKey;
  final String optionLabel;
  final String diningMode;
  final int quantity;
  final Map<String, dynamic>? menuSnapshot;

  ReservationLineInput normalized() {
    return ReservationLineInput(
      optionKey: optionKey.trim(),
      optionLabel: optionLabel.trim(),
      diningMode: diningMode.trim().toLowerCase(),
      quantity: quantity,
      menuSnapshot: menuSnapshot == null
          ? null
          : Map<String, dynamic>.from(menuSnapshot!),
    );
  }

  factory ReservationLineInput.forCycleOption({
    String? menuOptionKey,
    String? optionKey,
    required String optionLabel,
    required String diningMode,
    int quantity = 1,
    Map<String, dynamic>? menuSnapshot,
  }) {
    return ReservationLineInput(
      optionKey: optionKey,
      menuOptionKey: menuOptionKey,
      optionLabel: optionLabel,
      diningMode: diningMode,
      quantity: quantity,
      menuSnapshot: menuSnapshot,
    );
  }

  factory ReservationLineInput.forManualItem({
    String? menuItemId,
    String? itemId,
    String? optionLabel,
    String? itemName,
    required String diningMode,
    int quantity = 1,
    String? mealType,
    String? itemCategory,
    Map<String, dynamic>? menuSnapshot,
    Map<String, dynamic>? extraSnapshot,
  }) {
    final resolvedItemId = (menuItemId ?? itemId ?? '').trim();
    final resolvedLabel = (optionLabel ?? itemName ?? '').trim();

    final snapshot = <String, dynamic>{
      if (menuSnapshot != null) ...menuSnapshot,
      if (extraSnapshot != null) ...extraSnapshot,
      if (mealType != null && mealType.trim().isNotEmpty)
        'meal_type': mealType.trim().toLowerCase(),
      if (itemCategory != null && itemCategory.trim().isNotEmpty)
        'item_category': itemCategory.trim().toLowerCase(),
    };

    return ReservationLineInput(
      optionKey: resolvedItemId,
      optionLabel: resolvedLabel,
      diningMode: diningMode,
      quantity: quantity,
      menuSnapshot: snapshot.isEmpty ? null : snapshot,
    );
  }
}

class ReservationValidationResult {
  const ReservationValidationResult({
    required this.isAllowed,
    required this.message,
  });

  final bool isAllowed;
  final String message;
}

class BookingValidationResult {
  const BookingValidationResult({
    required this.isAllowed,
    required this.message,
  });

  final bool isAllowed;
  final String message;
}

class CancellationValidationResult {
  const CancellationValidationResult({
    required this.isAllowed,
    required this.message,
  });

  final bool isAllowed;
  final String message;
}

class _NotificationRecipient {
  const _NotificationRecipient({
    required this.userUid,
    required this.email,
  });

  final String userUid;
  final String email;
}
