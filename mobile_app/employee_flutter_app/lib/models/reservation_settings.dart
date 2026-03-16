class ReservationSettings {
  final String breakfastCutoffTime;
  final String lunchCutoffTime;
  final String dinnerCutoffTime;
  final int maxMealCountPerBooking;
  final bool allowTakeaway;
  final bool supervisorOverrideEnabled;
  final int defaultBookingWindowDays;

  const ReservationSettings({
    required this.breakfastCutoffTime,
    required this.lunchCutoffTime,
    required this.dinnerCutoffTime,
    required this.maxMealCountPerBooking,
    required this.allowTakeaway,
    required this.supervisorOverrideEnabled,
    required this.defaultBookingWindowDays,
  });

  factory ReservationSettings.defaults() {
    return const ReservationSettings(
      breakfastCutoffTime: '08:00',
      lunchCutoffTime: '13:00',
      dinnerCutoffTime: '20:00',
      maxMealCountPerBooking: 10,
      allowTakeaway: true,
      supervisorOverrideEnabled: true,
      defaultBookingWindowDays: 1,
    );
  }

  ReservationSettings copyWith({
    String? breakfastCutoffTime,
    String? lunchCutoffTime,
    String? dinnerCutoffTime,
    int? maxMealCountPerBooking,
    bool? allowTakeaway,
    bool? supervisorOverrideEnabled,
    int? defaultBookingWindowDays,
  }) {
    return ReservationSettings(
      breakfastCutoffTime: breakfastCutoffTime ?? this.breakfastCutoffTime,
      lunchCutoffTime: lunchCutoffTime ?? this.lunchCutoffTime,
      dinnerCutoffTime: dinnerCutoffTime ?? this.dinnerCutoffTime,
      maxMealCountPerBooking:
          maxMealCountPerBooking ?? this.maxMealCountPerBooking,
      allowTakeaway: allowTakeaway ?? this.allowTakeaway,
      supervisorOverrideEnabled:
          supervisorOverrideEnabled ?? this.supervisorOverrideEnabled,
      defaultBookingWindowDays:
          defaultBookingWindowDays ?? this.defaultBookingWindowDays,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'breakfast_cutoff_time': breakfastCutoffTime,
      'lunch_cutoff_time': lunchCutoffTime,
      'dinner_cutoff_time': dinnerCutoffTime,
      'max_meal_count_per_booking': maxMealCountPerBooking,
      'allow_takeaway': allowTakeaway,
      'supervisor_override_enabled': supervisorOverrideEnabled,
      'default_booking_window_days': defaultBookingWindowDays,
    };
  }

  factory ReservationSettings.fromMap(Map<String, dynamic> map) {
    return ReservationSettings(
      breakfastCutoffTime: (map['breakfast_cutoff_time'] ?? '08:00').toString(),
      lunchCutoffTime: (map['lunch_cutoff_time'] ?? '13:00').toString(),
      dinnerCutoffTime: (map['dinner_cutoff_time'] ?? '20:00').toString(),
      maxMealCountPerBooking:
          (map['max_meal_count_per_booking'] as num?)?.toInt() ?? 10,
      allowTakeaway: map['allow_takeaway'] as bool? ?? true,
      supervisorOverrideEnabled:
          map['supervisor_override_enabled'] as bool? ?? true,
      defaultBookingWindowDays:
          (map['default_booking_window_days'] as num?)?.toInt() ?? 1,
    );
  }

  @override
  String toString() {
    return 'ReservationSettings(breakfastCutoffTime: $breakfastCutoffTime, lunchCutoffTime: $lunchCutoffTime, dinnerCutoffTime: $dinnerCutoffTime, maxMealCountPerBooking: $maxMealCountPerBooking, allowTakeaway: $allowTakeaway, supervisorOverrideEnabled: $supervisorOverrideEnabled, defaultBookingWindowDays: $defaultBookingWindowDays)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ReservationSettings &&
        other.breakfastCutoffTime == breakfastCutoffTime &&
        other.lunchCutoffTime == lunchCutoffTime &&
        other.dinnerCutoffTime == dinnerCutoffTime &&
        other.maxMealCountPerBooking == maxMealCountPerBooking &&
        other.allowTakeaway == allowTakeaway &&
        other.supervisorOverrideEnabled == supervisorOverrideEnabled &&
        other.defaultBookingWindowDays == defaultBookingWindowDays;
  }

  @override
  int get hashCode {
    return breakfastCutoffTime.hashCode ^
        lunchCutoffTime.hashCode ^
        dinnerCutoffTime.hashCode ^
        maxMealCountPerBooking.hashCode ^
        allowTakeaway.hashCode ^
        supervisorOverrideEnabled.hashCode ^
        defaultBookingWindowDays.hashCode;
  }
}
