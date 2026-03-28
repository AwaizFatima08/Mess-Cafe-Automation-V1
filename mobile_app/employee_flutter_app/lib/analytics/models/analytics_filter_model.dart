class AnalyticsFilterModel {
  final DateTime startDate;
  final DateTime endDate;

  final List<String>? mealTypes;
  final String? employeeNumber;
  final bool includeGuests;
  final String? organizationId;

  const AnalyticsFilterModel({
    required this.startDate,
    required this.endDate,
    this.mealTypes,
    this.employeeNumber,
    this.includeGuests = true,
    this.organizationId,
  });

  AnalyticsFilterModel copyWith({
    DateTime? startDate,
    DateTime? endDate,
    List<String>? mealTypes,
    String? employeeNumber,
    bool? includeGuests,
    String? organizationId,
  }) {
    return AnalyticsFilterModel(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      mealTypes: mealTypes ?? this.mealTypes,
      employeeNumber: employeeNumber ?? this.employeeNumber,
      includeGuests: includeGuests ?? this.includeGuests,
      organizationId: organizationId ?? this.organizationId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'mealTypes': mealTypes,
      'employeeNumber': employeeNumber,
      'includeGuests': includeGuests,
      'organizationId': organizationId,
    };
  }

  bool get hasMealTypeFilter => mealTypes != null && mealTypes!.isNotEmpty;

  bool get hasEmployeeFilter =>
      employeeNumber != null && employeeNumber!.trim().isNotEmpty;

  bool get hasOrganizationFilter =>
      organizationId != null && organizationId!.trim().isNotEmpty;

  DateTime get normalizedStartDate =>
      DateTime(startDate.year, startDate.month, startDate.day);

  DateTime get normalizedEndDate =>
      DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);

  bool isWithinRange(DateTime date) {
    final target = date;
    return !target.isBefore(normalizedStartDate) &&
        !target.isAfter(normalizedEndDate);
  }

  @override
  String toString() {
    return 'AnalyticsFilterModel('
        'startDate: $startDate, '
        'endDate: $endDate, '
        'mealTypes: $mealTypes, '
        'employeeNumber: $employeeNumber, '
        'includeGuests: $includeGuests, '
        'organizationId: $organizationId'
        ')';
  }
}
