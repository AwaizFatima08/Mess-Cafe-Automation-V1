import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/reservation_constants.dart';
import '../models/meal_booking_request.dart';
import '../models/meal_reservation.dart';
import '../models/reservation_settings.dart';

class MealReservationService {
  MealReservationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _reservationsRef =>
      _firestore.collection(ReservationConstants.mealReservationsCollection);

  CollectionReference<Map<String, dynamic>> get _settingsRef =>
      _firestore.collection(ReservationConstants.reservationSettingsCollection);

  String buildDateKey(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final y = normalized.year.toString().padLeft(4, '0');
    final m = normalized.month.toString().padLeft(2, '0');
    final d = normalized.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  DateTime normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  String? validateBookingRequest(MealBookingRequest request) {
    if (!ReservationConstants.mealTypes.contains(request.mealType)) {
      return 'Invalid meal type selected.';
    }

    if (!ReservationConstants.serviceModes.contains(request.serviceMode)) {
      return 'Invalid service mode selected.';
    }

    if (request.selectedOptions.isEmpty) {
      return 'Please select at least one menu option.';
    }

    final hasNegativeQuantity =
        request.selectedOptions.any((option) => option.quantity < 0);
    if (hasNegativeQuantity) {
      return 'Quantity cannot be negative.';
    }

    final hasPositiveSelection =
        request.selectedOptions.any((option) => option.quantity > 0);
    if (!hasPositiveSelection) {
      return 'Please select quantity greater than zero.';
    }

    if (request.totalMealCount <= 0) {
      return 'Total meal count must be greater than zero.';
    }

    return null;
  }

  MealReservation buildEmployeeReservationFromRequest({
    required MealBookingRequest request,
    required String employeeNumber,
    required String employeeName,
    required String bookedByUserId,
    String? bookedByEmployeeNumber,
    String bookingSource = ReservationConstants.employeeApp,
    bool overrideFlag = false,
    String? overrideReason,
  }) {
    return MealReservation(
      reservationDate: normalizeDate(request.reservationDate),
      mealType: request.mealType,
      reservationCategory: ReservationConstants.employee,
      forEmployeeNumber: employeeNumber.trim(),
      forEmployeeName: employeeName.trim(),
      bookedByUserId: bookedByUserId.trim(),
      bookedByEmployeeNumber:
          (bookedByEmployeeNumber ?? employeeNumber).trim(),
      bookingSource: bookingSource,
      serviceMode: request.serviceMode,
      totalMealCount: request.totalMealCount,
      selectedOptions: request.selectedOptions,
      status: ReservationConstants.active,
      overrideFlag: overrideFlag,
      overrideReason: overrideReason,
      notes: request.notes,
    );
  }

  MealReservation buildOfficialGuestReservationFromRequest({
    required MealBookingRequest request,
    required String bookedByUserId,
    String? bookedByEmployeeNumber,
    String bookingSource = ReservationConstants.supervisorConsole,
    String? hostEmployeeNumber,
    String? hostDepartment,
    bool overrideFlag = false,
    String? overrideReason,
  }) {
    return MealReservation(
      reservationDate: normalizeDate(request.reservationDate),
      mealType: request.mealType,
      reservationCategory: ReservationConstants.officialGuest,
      hostEmployeeNumber: hostEmployeeNumber?.trim(),
      hostDepartment: hostDepartment?.trim(),
      bookedByUserId: bookedByUserId.trim(),
      bookedByEmployeeNumber: bookedByEmployeeNumber?.trim(),
      bookingSource: bookingSource,
      serviceMode: request.serviceMode,
      totalMealCount: request.totalMealCount,
      selectedOptions: request.selectedOptions,
      status: ReservationConstants.active,
      overrideFlag: overrideFlag,
      overrideReason: overrideReason,
      notes: request.notes,
    );
  }

  int calculateSelectedOptionTotal(MealReservation reservation) {
    return reservation.selectedOptions.fold<int>(
      0,
      (total, option) => total + option.quantity,
    );
  }

  bool isSelectionTotalValid(MealReservation reservation) {
    return calculateSelectedOptionTotal(reservation) ==
        reservation.totalMealCount;
  }

  Future<ReservationSettings> getReservationSettings() async {
    final snapshot = await _settingsRef.doc('default').get();

    if (!snapshot.exists) {
      return ReservationSettings.defaults();
    }

    final data = snapshot.data();
    if (data == null) {
      return ReservationSettings.defaults();
    }

    return ReservationSettings.fromMap(data);
  }

  Future<void> saveDefaultReservationSettingsIfMissing() async {
    final docRef = _settingsRef.doc('default');
    final snapshot = await docRef.get();

    if (!snapshot.exists) {
      await docRef.set(ReservationSettings.defaults().toMap());
    }
  }

  Future<MealReservation?> getReservationById(String id) async {
    final snapshot = await _reservationsRef.doc(id).get();

    if (!snapshot.exists) {
      return null;
    }

    final data = snapshot.data();
    if (data == null) {
      return null;
    }

    return MealReservation.fromMap(data, id: snapshot.id);
  }

  Future<String> createOrUpdateEmployeeReservation(
    MealReservation reservation,
  ) async {
    if (reservation.reservationCategory != ReservationConstants.employee) {
      throw ArgumentError(
        'createOrUpdateEmployeeReservation only supports employee reservations.',
      );
    }

    if ((reservation.forEmployeeNumber ?? '').trim().isEmpty) {
      throw ArgumentError('forEmployeeNumber is required for employee booking.');
    }

    if (reservation.bookedByUserId.trim().isEmpty) {
      throw ArgumentError('bookedByUserId is required.');
    }

    if (!ReservationConstants.mealTypes.contains(reservation.mealType)) {
      throw ArgumentError('Invalid meal type: ${reservation.mealType}');
    }

    if (!ReservationConstants.serviceModes.contains(reservation.serviceMode)) {
      throw ArgumentError('Invalid service mode: ${reservation.serviceMode}');
    }

    if (reservation.totalMealCount <= 0) {
      throw ArgumentError('totalMealCount must be greater than zero.');
    }

    if (reservation.selectedOptions.isEmpty) {
      throw ArgumentError('At least one selected option is required.');
    }

    if (!isSelectionTotalValid(reservation)) {
      throw ArgumentError(
        'Selected option total must match totalMealCount.',
      );
    }

    final normalizedDate = normalizeDate(reservation.reservationDate);

    final existingQuery = await _reservationsRef
        .where(
          'reservation_category',
          isEqualTo: ReservationConstants.employee,
        )
        .where(
          'for_employee_number',
          isEqualTo: reservation.forEmployeeNumber?.trim(),
        )
        .where('meal_type', isEqualTo: reservation.mealType)
        .where(
          'reservation_date',
          isEqualTo: Timestamp.fromDate(normalizedDate),
        )
        .where('status', isEqualTo: ReservationConstants.active)
        .limit(1)
        .get();

    final payload = reservation.copyWith(
      reservationDate: normalizedDate,
      updatedAt: DateTime.now(),
    );

    if (existingQuery.docs.isNotEmpty) {
      final doc = existingQuery.docs.first;

      final updateData = payload.toMap()..remove('created_at');

      await _reservationsRef.doc(doc.id).update(updateData);
      return doc.id;
    }

    final createData = payload.copyWith(
      createdAt: DateTime.now(),
    ).toMap();

    final docRef = await _reservationsRef.add(createData);
    return docRef.id;
  }

  Future<String> createOfficialGuestReservation(
    MealReservation reservation,
  ) async {
    if (reservation.reservationCategory !=
        ReservationConstants.officialGuest) {
      throw ArgumentError(
        'createOfficialGuestReservation only supports official guest reservations.',
      );
    }

    if (reservation.bookedByUserId.trim().isEmpty) {
      throw ArgumentError('bookedByUserId is required.');
    }

    if (!ReservationConstants.mealTypes.contains(reservation.mealType)) {
      throw ArgumentError('Invalid meal type: ${reservation.mealType}');
    }

    if (!ReservationConstants.serviceModes.contains(reservation.serviceMode)) {
      throw ArgumentError('Invalid service mode: ${reservation.serviceMode}');
    }

    if (reservation.totalMealCount <= 0) {
      throw ArgumentError('totalMealCount must be greater than zero.');
    }

    if (reservation.selectedOptions.isEmpty) {
      throw ArgumentError('At least one selected option is required.');
    }

    if (!isSelectionTotalValid(reservation)) {
      throw ArgumentError(
        'Selected option total must match totalMealCount.',
      );
    }

    final hasHostEmployee =
        (reservation.hostEmployeeNumber ?? '').trim().isNotEmpty;
    final hasHostDepartment =
        (reservation.hostDepartment ?? '').trim().isNotEmpty;
    final hasNotes = (reservation.notes ?? '').trim().isNotEmpty;

    if (!hasHostEmployee && !hasHostDepartment && !hasNotes) {
      throw ArgumentError(
        'Official guest booking must include host employee number, host department, or notes.',
      );
    }

    final normalizedDate = normalizeDate(reservation.reservationDate);

    final payload = reservation.copyWith(
      reservationDate: normalizedDate,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final docRef = await _reservationsRef.add(payload.toMap());
    return docRef.id;
  }

  Future<MealReservation?> getEmployeeReservationForMeal({
    required String employeeNumber,
    required DateTime reservationDate,
    required String mealType,
  }) async {
    final normalizedDate = normalizeDate(reservationDate);

    final query = await _reservationsRef
        .where(
          'reservation_category',
          isEqualTo: ReservationConstants.employee,
        )
        .where(
          'for_employee_number',
          isEqualTo: employeeNumber.trim(),
        )
        .where('meal_type', isEqualTo: mealType)
        .where(
          'reservation_date',
          isEqualTo: Timestamp.fromDate(normalizedDate),
        )
        .where('status', isEqualTo: ReservationConstants.active)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      return null;
    }

    final doc = query.docs.first;
    return MealReservation.fromMap(doc.data(), id: doc.id);
  }

  Future<List<MealReservation>> getReservationsForDate(
    DateTime reservationDate,
  ) async {
    final normalizedDate = normalizeDate(reservationDate);

    final query = await _reservationsRef
        .where(
          'reservation_date',
          isEqualTo: Timestamp.fromDate(normalizedDate),
        )
        .where('status', isEqualTo: ReservationConstants.active)
        .get();

    return query.docs
        .map((doc) => MealReservation.fromMap(doc.data(), id: doc.id))
        .toList();
  }

  Future<List<MealReservation>> getReservationsForDateAndMealType({
    required DateTime reservationDate,
    required String mealType,
  }) async {
    final normalizedDate = normalizeDate(reservationDate);

    final query = await _reservationsRef
        .where(
          'reservation_date',
          isEqualTo: Timestamp.fromDate(normalizedDate),
        )
        .where('meal_type', isEqualTo: mealType)
        .where('status', isEqualTo: ReservationConstants.active)
        .get();

    return query.docs
        .map((doc) => MealReservation.fromMap(doc.data(), id: doc.id))
        .toList();
  }

  Future<int> getTotalHeadCountForDate(DateTime reservationDate) async {
    final reservations = await getReservationsForDate(reservationDate);
    return reservations.fold<int>(
      0,
      (total, reservation) => total + reservation.totalMealCount,
    );
  }

  Future<int> getTotalHeadCountForDateAndMealType({
    required DateTime reservationDate,
    required String mealType,
  }) async {
    final reservations = await getReservationsForDateAndMealType(
      reservationDate: reservationDate,
      mealType: mealType,
    );

    return reservations.fold<int>(
      0,
      (total, reservation) => total + reservation.totalMealCount,
    );
  }

  Future<int> getEmployeeHeadCountForDateAndMealType({
    required DateTime reservationDate,
    required String mealType,
  }) async {
    final reservations = await getReservationsForDateAndMealType(
      reservationDate: reservationDate,
      mealType: mealType,
    );

    return reservations
        .where(
          (reservation) =>
              reservation.reservationCategory == ReservationConstants.employee,
        )
        .fold<int>(
          0,
          (total, reservation) => total + reservation.totalMealCount,
        );
  }

  Future<int> getOfficialGuestHeadCountForDateAndMealType({
    required DateTime reservationDate,
    required String mealType,
  }) async {
    final reservations = await getReservationsForDateAndMealType(
      reservationDate: reservationDate,
      mealType: mealType,
    );

    return reservations
        .where(
          (reservation) => reservation.reservationCategory ==
              ReservationConstants.officialGuest,
        )
        .fold<int>(
          0,
          (total, reservation) => total + reservation.totalMealCount,
        );
  }

  Future<int> getDineInHeadCountForDateAndMealType({
    required DateTime reservationDate,
    required String mealType,
  }) async {
    final reservations = await getReservationsForDateAndMealType(
      reservationDate: reservationDate,
      mealType: mealType,
    );

    return reservations
        .where(
          (reservation) =>
              reservation.serviceMode == ReservationConstants.dineIn,
        )
        .fold<int>(
          0,
          (total, reservation) => total + reservation.totalMealCount,
        );
  }

  Future<int> getTakeawayHeadCountForDateAndMealType({
    required DateTime reservationDate,
    required String mealType,
  }) async {
    final reservations = await getReservationsForDateAndMealType(
      reservationDate: reservationDate,
      mealType: mealType,
    );

    return reservations
        .where(
          (reservation) =>
              reservation.serviceMode == ReservationConstants.takeaway,
        )
        .fold<int>(
          0,
          (total, reservation) => total + reservation.totalMealCount,
        );
  }

  Future<void> cancelReservation(String reservationId) async {
    await _reservationsRef.doc(reservationId).update({
      'status': ReservationConstants.cancelled,
      'updated_at': Timestamp.fromDate(DateTime.now()),
    });
  }
}
