import 'meal_option_selection.dart';

class MealBookingRequest {
  final DateTime reservationDate;
  final String mealType;
  final String serviceMode;
  final List<MealOptionSelection> selectedOptions;
  final String? notes;

  const MealBookingRequest({
    required this.reservationDate,
    required this.mealType,
    required this.serviceMode,
    required this.selectedOptions,
    this.notes,
  });

  int get totalMealCount => selectedOptions.fold<int>(
        0,
        (total, option) => total + option.quantity,
      );

  MealBookingRequest copyWith({
    DateTime? reservationDate,
    String? mealType,
    String? serviceMode,
    List<MealOptionSelection>? selectedOptions,
    String? notes,
  }) {
    return MealBookingRequest(
      reservationDate: reservationDate ?? this.reservationDate,
      mealType: mealType ?? this.mealType,
      serviceMode: serviceMode ?? this.serviceMode,
      selectedOptions: selectedOptions ?? this.selectedOptions,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reservation_date': reservationDate.toIso8601String(),
      'meal_type': mealType,
      'service_mode': serviceMode,
      'selected_options': selectedOptions.map((e) => e.toMap()).toList(),
      'total_meal_count': totalMealCount,
      'notes': notes,
    };
  }

  factory MealBookingRequest.fromMap(Map<String, dynamic> map) {
    final rawOptions = (map['selected_options'] as List<dynamic>?) ?? const [];

    return MealBookingRequest(
      reservationDate: DateTime.tryParse(
            (map['reservation_date'] ?? '').toString(),
          ) ??
          DateTime.now(),
      mealType: (map['meal_type'] ?? '').toString(),
      serviceMode: (map['service_mode'] ?? '').toString(),
      selectedOptions: rawOptions
          .whereType<Map>()
          .map((e) => MealOptionSelection.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      notes: map['notes']?.toString(),
    );
  }

  @override
  String toString() {
    return 'MealBookingRequest(reservationDate: $reservationDate, mealType: $mealType, serviceMode: $serviceMode, selectedOptions: $selectedOptions, totalMealCount: $totalMealCount, notes: $notes)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MealBookingRequest &&
        other.reservationDate == reservationDate &&
        other.mealType == mealType &&
        other.serviceMode == serviceMode &&
        other.notes == notes;
  }

  @override
  int get hashCode {
    return reservationDate.hashCode ^
        mealType.hashCode ^
        serviceMode.hashCode ^
        notes.hashCode;
  }
}
