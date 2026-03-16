import 'package:cloud_firestore/cloud_firestore.dart';

import 'meal_option_selection.dart';

class MealReservation {
  final String? id;
  final DateTime reservationDate;
  final String mealType;
  final String reservationCategory;
  final String? forEmployeeNumber;
  final String? forEmployeeName;
  final String? hostEmployeeNumber;
  final String? hostDepartment;
  final String bookedByUserId;
  final String? bookedByEmployeeNumber;
  final String bookingSource;
  final String serviceMode;
  final int totalMealCount;
  final List<MealOptionSelection> selectedOptions;
  final String status;
  final bool overrideFlag;
  final String? overrideReason;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MealReservation({
    this.id,
    required this.reservationDate,
    required this.mealType,
    required this.reservationCategory,
    this.forEmployeeNumber,
    this.forEmployeeName,
    this.hostEmployeeNumber,
    this.hostDepartment,
    required this.bookedByUserId,
    this.bookedByEmployeeNumber,
    required this.bookingSource,
    required this.serviceMode,
    required this.totalMealCount,
    required this.selectedOptions,
    required this.status,
    required this.overrideFlag,
    this.overrideReason,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  MealReservation copyWith({
    String? id,
    DateTime? reservationDate,
    String? mealType,
    String? reservationCategory,
    String? forEmployeeNumber,
    String? forEmployeeName,
    String? hostEmployeeNumber,
    String? hostDepartment,
    String? bookedByUserId,
    String? bookedByEmployeeNumber,
    String? bookingSource,
    String? serviceMode,
    int? totalMealCount,
    List<MealOptionSelection>? selectedOptions,
    String? status,
    bool? overrideFlag,
    String? overrideReason,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MealReservation(
      id: id ?? this.id,
      reservationDate: reservationDate ?? this.reservationDate,
      mealType: mealType ?? this.mealType,
      reservationCategory: reservationCategory ?? this.reservationCategory,
      forEmployeeNumber: forEmployeeNumber ?? this.forEmployeeNumber,
      forEmployeeName: forEmployeeName ?? this.forEmployeeName,
      hostEmployeeNumber: hostEmployeeNumber ?? this.hostEmployeeNumber,
      hostDepartment: hostDepartment ?? this.hostDepartment,
      bookedByUserId: bookedByUserId ?? this.bookedByUserId,
      bookedByEmployeeNumber:
          bookedByEmployeeNumber ?? this.bookedByEmployeeNumber,
      bookingSource: bookingSource ?? this.bookingSource,
      serviceMode: serviceMode ?? this.serviceMode,
      totalMealCount: totalMealCount ?? this.totalMealCount,
      selectedOptions: selectedOptions ?? this.selectedOptions,
      status: status ?? this.status,
      overrideFlag: overrideFlag ?? this.overrideFlag,
      overrideReason: overrideReason ?? this.overrideReason,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reservation_date': Timestamp.fromDate(
        DateTime(
          reservationDate.year,
          reservationDate.month,
          reservationDate.day,
        ),
      ),
      'meal_type': mealType,
      'reservation_category': reservationCategory,
      'for_employee_number': forEmployeeNumber,
      'for_employee_name': forEmployeeName,
      'host_employee_number': hostEmployeeNumber,
      'host_department': hostDepartment,
      'booked_by_user_id': bookedByUserId,
      'booked_by_employee_number': bookedByEmployeeNumber,
      'booking_source': bookingSource,
      'service_mode': serviceMode,
      'total_meal_count': totalMealCount,
      'selected_options': selectedOptions.map((e) => e.toMap()).toList(),
      'status': status,
      'override_flag': overrideFlag,
      'override_reason': overrideReason,
      'notes': notes,
      'created_at': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updated_at': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory MealReservation.fromMap(Map<String, dynamic> map, {String? id}) {
    final selectedOptionsRaw =
        (map['selected_options'] as List<dynamic>?) ?? const [];

    return MealReservation(
      id: id,
      reservationDate: _readDate(map['reservation_date']),
      mealType: (map['meal_type'] ?? '').toString(),
      reservationCategory: (map['reservation_category'] ?? '').toString(),
      forEmployeeNumber: map['for_employee_number']?.toString(),
      forEmployeeName: map['for_employee_name']?.toString(),
      hostEmployeeNumber: map['host_employee_number']?.toString(),
      hostDepartment: map['host_department']?.toString(),
      bookedByUserId: (map['booked_by_user_id'] ?? '').toString(),
      bookedByEmployeeNumber: map['booked_by_employee_number']?.toString(),
      bookingSource: (map['booking_source'] ?? '').toString(),
      serviceMode: (map['service_mode'] ?? '').toString(),
      totalMealCount: (map['total_meal_count'] as num?)?.toInt() ?? 0,
      selectedOptions: selectedOptionsRaw
          .whereType<Map>()
          .map((e) => MealOptionSelection.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      status: (map['status'] ?? '').toString(),
      overrideFlag: map['override_flag'] as bool? ?? false,
      overrideReason: map['override_reason']?.toString(),
      notes: map['notes']?.toString(),
      createdAt: _readNullableDate(map['created_at']),
      updatedAt: _readNullableDate(map['updated_at']),
    );
  }

  static DateTime _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.now();
  }

  static DateTime? _readNullableDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  @override
  String toString() {
    return 'MealReservation(id: $id, reservationDate: $reservationDate, mealType: $mealType, reservationCategory: $reservationCategory, forEmployeeNumber: $forEmployeeNumber, forEmployeeName: $forEmployeeName, hostEmployeeNumber: $hostEmployeeNumber, hostDepartment: $hostDepartment, bookedByUserId: $bookedByUserId, bookedByEmployeeNumber: $bookedByEmployeeNumber, bookingSource: $bookingSource, serviceMode: $serviceMode, totalMealCount: $totalMealCount, selectedOptions: $selectedOptions, status: $status, overrideFlag: $overrideFlag, overrideReason: $overrideReason, notes: $notes, createdAt: $createdAt, updatedAt: $updatedAt)';
  }
}
