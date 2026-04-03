import 'package:cloud_firestore/cloud_firestore.dart';

class MealCostReportingService {
  MealCostReportingService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _reservationsRef =>
      _firestore.collection('meal_reservations');

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  Timestamp _startOfDay(DateTime date) {
    return Timestamp.fromDate(_normalizeDate(date));
  }

  Timestamp _startOfNextDay(DateTime date) {
    return Timestamp.fromDate(_normalizeDate(date).add(const Duration(days: 1)));
  }

  int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse((value ?? '0').toString()) ?? 0;
  }

  double _readDouble(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return double.tryParse((value ?? '0').toString()) ?? 0;
  }

  String _readText(dynamic value) {
    return (value ?? '').toString().trim();
  }

  String _extractItemName(Map<String, dynamic> data) {
    final menuSnapshot = _asMap(data['menu_snapshot']);
    return _firstNonEmpty([
      _readText(menuSnapshot['item_name']),
      _readText(data['option_label']),
      _readText(data['item_name']),
      _readText(data['menu_option_key']),
    ]);
  }

  String _extractMenuItemId(Map<String, dynamic> data) {
    final menuSnapshot = _asMap(data['menu_snapshot']);
    return _firstNonEmpty([
      _readText(menuSnapshot['item_id']),
      _readText(data['menu_item_id']),
      _readText(data['menu_option_key']),
      _readText(menuSnapshot['option_key']),
    ]);
  }

  String _extractCategory(Map<String, dynamic> data) {
    final menuSnapshot = _asMap(data['menu_snapshot']);
    return _firstNonEmpty([
      _readText(menuSnapshot['item_category']),
      _readText(data['category']),
      _readText(data['meal_type']),
    ]);
  }

  String _extractSubjectType(Map<String, dynamic> data) {
    final reservationCategory =
        _readText(data['reservation_category']).toLowerCase();
    final bookingSubjectType =
        _readText(data['booking_subject_type']).toLowerCase();

    if (reservationCategory == 'official_guest' ||
        bookingSubjectType == 'official_guest') {
      return 'guest';
    }
    return 'employee';
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _firstNonEmpty(List<String> values) {
    for (final value in values) {
      if (value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  Future<MealCostDashboardData> getDailyDashboard(DateTime date) async {
    final normalizedDate = _normalizeDate(date);

    final snapshot = await _reservationsRef
        .where(
          'reservation_date',
          isGreaterThanOrEqualTo: _startOfDay(normalizedDate),
        )
        .where(
          'reservation_date',
          isLessThan: _startOfNextDay(normalizedDate),
        )
        .get();

    final mealTypeSummary = <String, MealTypeCostSummaryBuilder>{
      'breakfast': MealTypeCostSummaryBuilder(mealType: 'breakfast'),
      'lunch': MealTypeCostSummaryBuilder(mealType: 'lunch'),
      'dinner': MealTypeCostSummaryBuilder(mealType: 'dinner'),
    };

    final subjectSummary = <String, SubjectCostSummaryBuilder>{
      'employee': SubjectCostSummaryBuilder(subjectType: 'employee'),
      'guest': SubjectCostSummaryBuilder(subjectType: 'guest'),
    };

    final itemSummaryMap = <String, ItemCostSummaryBuilder>{};

    int totalLines = 0;
    int activeLines = 0;
    int cancelledLines = 0;
    int totalQuantity = 0;
    double totalAmount = 0;
    int ratedLines = 0;
    int unratedLines = 0;

    for (final doc in snapshot.docs) {
      totalLines += 1;

      final data = doc.data();
      final status = _readText(data['status']).toLowerCase();
      final quantity = _readInt(data['quantity']);
      final unitRate = _readDouble(data['unit_rate']);
      final amount = _readDouble(data['amount']);
      final mealType = _readText(data['meal_type']).toLowerCase();
      final itemName = _extractItemName(data);
      final menuItemId = _extractMenuItemId(data);
      final category = _extractCategory(data);
      final subjectType = _extractSubjectType(data);

      if (status == 'cancelled') {
        cancelledLines += 1;
        continue;
      }

      activeLines += 1;
      totalQuantity += quantity;
      totalAmount += amount;

      final hasRate = unitRate > 0 || amount > 0;
      if (hasRate) {
        ratedLines += 1;
      } else {
        unratedLines += 1;
      }

      final mealBuilder = mealTypeSummary.putIfAbsent(
        mealType,
        () => MealTypeCostSummaryBuilder(mealType: mealType),
      );
      mealBuilder.lineCount += 1;
      mealBuilder.totalQuantity += quantity;
      mealBuilder.totalAmount += amount;

      final subjectBuilder = subjectSummary.putIfAbsent(
        subjectType,
        () => SubjectCostSummaryBuilder(subjectType: subjectType),
      );
      subjectBuilder.lineCount += 1;
      subjectBuilder.totalQuantity += quantity;
      subjectBuilder.totalAmount += amount;

      final itemKey = menuItemId.isNotEmpty
          ? menuItemId.toLowerCase()
          : itemName.toLowerCase();

      final itemBuilder = itemSummaryMap.putIfAbsent(
        itemKey,
        () => ItemCostSummaryBuilder(
          menuItemId: menuItemId,
          itemName: itemName,
          category: category,
        ),
      );
      itemBuilder.lineCount += 1;
      itemBuilder.totalQuantity += quantity;
      itemBuilder.totalAmount += amount;
      if (unitRate > 0) {
        itemBuilder.lastUnitRate = unitRate.toDouble();
      }
      itemBuilder.mealTypes.add(mealType);
    }

    final mealSummaries = mealTypeSummary.values
        .map((e) => e.build())
        .toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    final subjectSummaries = subjectSummary.values
        .map((e) => e.build())
        .toList()
      ..sort((a, b) => a.subjectType.compareTo(b.subjectType));

    final itemSummaries = itemSummaryMap.values
        .map((e) => e.build())
        .toList()
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

    final averageCostPerMeal =
        totalQuantity > 0 ? (totalAmount / totalQuantity) : 0.0;

    return MealCostDashboardData(
      date: normalizedDate,
      totalLines: totalLines,
      activeLines: activeLines,
      cancelledLines: cancelledLines,
      totalQuantity: totalQuantity,
      totalAmount: totalAmount,
      averageCostPerMeal: averageCostPerMeal,
      ratedLines: ratedLines,
      unratedLines: unratedLines,
      mealTypeSummaries: mealSummaries,
      subjectSummaries: subjectSummaries,
      itemSummaries: itemSummaries,
    );
  }
}

class MealCostDashboardData {
  final DateTime date;
  final int totalLines;
  final int activeLines;
  final int cancelledLines;
  final int totalQuantity;
  final double totalAmount;
  final double averageCostPerMeal;
  final int ratedLines;
  final int unratedLines;
  final List<MealTypeCostSummary> mealTypeSummaries;
  final List<SubjectCostSummary> subjectSummaries;
  final List<ItemCostSummary> itemSummaries;

  const MealCostDashboardData({
    required this.date,
    required this.totalLines,
    required this.activeLines,
    required this.cancelledLines,
    required this.totalQuantity,
    required this.totalAmount,
    required this.averageCostPerMeal,
    required this.ratedLines,
    required this.unratedLines,
    required this.mealTypeSummaries,
    required this.subjectSummaries,
    required this.itemSummaries,
  });
}

class MealTypeCostSummary {
  final String mealType;
  final int lineCount;
  final int totalQuantity;
  final double totalAmount;

  const MealTypeCostSummary({
    required this.mealType,
    required this.lineCount,
    required this.totalQuantity,
    required this.totalAmount,
  });

  double get averageCostPerUnit =>
      totalQuantity > 0 ? totalAmount / totalQuantity : 0.0;

  int get displayOrder {
    switch (mealType) {
      case 'breakfast':
        return 1;
      case 'lunch':
        return 2;
      case 'dinner':
        return 3;
      default:
        return 99;
    }
  }
}

class SubjectCostSummary {
  final String subjectType;
  final int lineCount;
  final int totalQuantity;
  final double totalAmount;

  const SubjectCostSummary({
    required this.subjectType,
    required this.lineCount,
    required this.totalQuantity,
    required this.totalAmount,
  });

  double get averageCostPerUnit =>
      totalQuantity > 0 ? totalAmount / totalQuantity : 0.0;
}

class ItemCostSummary {
  final String menuItemId;
  final String itemName;
  final String category;
  final int lineCount;
  final int totalQuantity;
  final double totalAmount;
  final double lastUnitRate;
  final List<String> mealTypes;

  const ItemCostSummary({
    required this.menuItemId,
    required this.itemName,
    required this.category,
    required this.lineCount,
    required this.totalQuantity,
    required this.totalAmount,
    required this.lastUnitRate,
    required this.mealTypes,
  });

  double get averageCostPerUnit =>
      totalQuantity > 0 ? totalAmount / totalQuantity : 0.0;
}

class MealTypeCostSummaryBuilder {
  final String mealType;
  int lineCount = 0;
  int totalQuantity = 0;
  double totalAmount = 0;

  MealTypeCostSummaryBuilder({required this.mealType});

  MealTypeCostSummary build() {
    return MealTypeCostSummary(
      mealType: mealType,
      lineCount: lineCount,
      totalQuantity: totalQuantity,
      totalAmount: totalAmount,
    );
  }
}

class SubjectCostSummaryBuilder {
  final String subjectType;
  int lineCount = 0;
  int totalQuantity = 0;
  double totalAmount = 0;

  SubjectCostSummaryBuilder({required this.subjectType});

  SubjectCostSummary build() {
    return SubjectCostSummary(
      subjectType: subjectType,
      lineCount: lineCount,
      totalQuantity: totalQuantity,
      totalAmount: totalAmount,
    );
  }
}

class ItemCostSummaryBuilder {
  final String menuItemId;
  final String itemName;
  final String category;

  int lineCount = 0;
  int totalQuantity = 0;
  double totalAmount = 0;
  double lastUnitRate = 0;
  final Set<String> mealTypes = <String>{};

  ItemCostSummaryBuilder({
    required this.menuItemId,
    required this.itemName,
    required this.category,
  });

  ItemCostSummary build() {
    final sortedMealTypes = mealTypes.toList()..sort();

    return ItemCostSummary(
      menuItemId: menuItemId,
      itemName: itemName,
      category: category,
      lineCount: lineCount,
      totalQuantity: totalQuantity,
      totalAmount: totalAmount,
      lastUnitRate: lastUnitRate,
      mealTypes: sortedMealTypes,
    );
  }
}
