import 'resolved_meal_option.dart';

class DailyResolvedMenu {
  final String weekday;
  final String cycleName;
  final List<ResolvedMealOption> breakfastOptions;
  final List<ResolvedMealOption> lunchOptions;
  final List<ResolvedMealOption> dinnerOptions;

  const DailyResolvedMenu({
    required this.weekday,
    required this.cycleName,
    required this.breakfastOptions,
    required this.lunchOptions,
    required this.dinnerOptions,
  });

  DailyResolvedMenu copyWith({
    String? weekday,
    String? cycleName,
    List<ResolvedMealOption>? breakfastOptions,
    List<ResolvedMealOption>? lunchOptions,
    List<ResolvedMealOption>? dinnerOptions,
  }) {
    return DailyResolvedMenu(
      weekday: weekday ?? this.weekday,
      cycleName: cycleName ?? this.cycleName,
      breakfastOptions: breakfastOptions ?? this.breakfastOptions,
      lunchOptions: lunchOptions ?? this.lunchOptions,
      dinnerOptions: dinnerOptions ?? this.dinnerOptions,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'weekday': weekday,
      'cycle_name': cycleName,
      'breakfast_options': breakfastOptions.map((e) => e.toMap()).toList(),
      'lunch_options': lunchOptions.map((e) => e.toMap()).toList(),
      'dinner_options': dinnerOptions.map((e) => e.toMap()).toList(),
    };
  }

  factory DailyResolvedMenu.fromMap(Map<String, dynamic> map) {
    List<ResolvedMealOption> parseOptions(dynamic raw) {
      final list = (raw as List<dynamic>?) ?? const [];
      return list
          .whereType<Map>()
          .map((e) => ResolvedMealOption.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    }

    return DailyResolvedMenu(
      weekday: (map['weekday'] ?? '').toString(),
      cycleName: (map['cycle_name'] ?? '').toString(),
      breakfastOptions: parseOptions(map['breakfast_options']),
      lunchOptions: parseOptions(map['lunch_options']),
      dinnerOptions: parseOptions(map['dinner_options']),
    );
  }

  @override
  String toString() {
    return 'DailyResolvedMenu(weekday: $weekday, cycleName: $cycleName, breakfastOptions: $breakfastOptions, lunchOptions: $lunchOptions, dinnerOptions: $dinnerOptions)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is DailyResolvedMenu &&
        other.weekday == weekday &&
        other.cycleName == cycleName;
  }

  @override
  int get hashCode {
    return weekday.hashCode ^ cycleName.hashCode;
  }
}
