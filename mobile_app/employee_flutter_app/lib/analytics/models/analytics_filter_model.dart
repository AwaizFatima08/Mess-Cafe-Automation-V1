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
      'startDate': normalizedStartDate.toIso8601String(),
      'endDate': normalizedEndDate.toIso8601String(),
      'mealTypes': normalizedMealTypes,
      'employeeNumber': normalizedEmployeeNumber,
      'includeGuests': includeGuests,
      'organizationId': normalizedOrganizationId,
    };
  }

  bool get hasMealTypeFilter =>
      normalizedMealTypes != null && normalizedMealTypes!.isNotEmpty;

  bool get hasEmployeeFilter =>
      normalizedEmployeeNumber != null &&
      normalizedEmployeeNumber!.trim().isNotEmpty;

  bool get hasOrganizationFilter =>
      normalizedOrganizationId != null &&
      normalizedOrganizationId!.trim().isNotEmpty;

  DateTime get normalizedStartDate =>
      DateTime(startDate.year, startDate.month, startDate.day);

  DateTime get normalizedEndDate =>
      DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);

  List<String>? get normalizedMealTypes {
    if (mealTypes == null) return null;

    final normalized = mealTypes!
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    return normalized;
  }

  String? get normalizedEmployeeNumber {
    final value = employeeNumber?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  String? get normalizedOrganizationId {
    final value = organizationId?.trim();
    return (value == null || value.isEmpty) ? null : value;
  }

  bool isWithinRange(DateTime date) {
    return !date.isBefore(normalizedStartDate) &&
        !date.isAfter(normalizedEndDate);
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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AnalyticsFilterModel &&
        other.normalizedStartDate == normalizedStartDate &&
        other.normalizedEndDate == normalizedEndDate &&
        _listEquals(other.normalizedMealTypes, normalizedMealTypes) &&
        other.normalizedEmployeeNumber == normalizedEmployeeNumber &&
        other.includeGuests == includeGuests &&
        other.normalizedOrganizationId == normalizedOrganizationId;
  }

  @override
  int get hashCode {
    return Object.hash(
      normalizedStartDate,
      normalizedEndDate,
      Object.hashAll(normalizedMealTypes ?? const <String>[]),
      normalizedEmployeeNumber,
      includeGuests,
      normalizedOrganizationId,
    );
  }

  static bool _listEquals(List<String>? a, List<String>? b) {
    if (identical(a, b)) return true;
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;

    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }

    return true;
  }
}
