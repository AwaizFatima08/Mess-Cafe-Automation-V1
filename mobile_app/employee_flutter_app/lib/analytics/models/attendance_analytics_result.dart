class AttendanceAnalyticsResult {
  final int totalAttendance;
  final int totalEmployees;
  final int totalGuests;

  final Map<String, int> mealWiseAttendance;
  final Map<String, int> dailyTrend;

  const AttendanceAnalyticsResult({
    required this.totalAttendance,
    required this.totalEmployees,
    required this.totalGuests,
    required this.mealWiseAttendance,
    required this.dailyTrend,
  });

  factory AttendanceAnalyticsResult.empty() {
    return const AttendanceAnalyticsResult(
      totalAttendance: 0,
      totalEmployees: 0,
      totalGuests: 0,
      mealWiseAttendance: {
        'breakfast': 0,
        'lunch': 0,
        'dinner': 0,
      },
      dailyTrend: {},
    );
  }

  double get guestPercentage {
    if (totalAttendance == 0) return 0;
    return (totalGuests / totalAttendance) * 100;
  }

  double get employeePercentage {
    if (totalAttendance == 0) return 0;
    return (totalEmployees / totalAttendance) * 100;
  }

  Map<String, dynamic> toMap() {
    return {
      'totalAttendance': totalAttendance,
      'totalEmployees': totalEmployees,
      'totalGuests': totalGuests,
      'mealWiseAttendance': mealWiseAttendance,
      'dailyTrend': dailyTrend,
    };
  }
}
