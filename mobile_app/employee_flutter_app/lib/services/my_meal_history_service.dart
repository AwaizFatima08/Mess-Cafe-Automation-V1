import 'package:cloud_firestore/cloud_firestore.dart';

class MyMealHistoryService {
  MyMealHistoryService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _reservationsRef =>
      _firestore.collection('meal_reservations');

  DateTime normalizeDate(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  DateTime startOfMonth(DateTime value) {
    return DateTime(value.year, value.month, 1);
  }

  DateTime endOfMonth(DateTime value) {
    return DateTime(value.year, value.month + 1, 1);
  }

  String normalizeText(dynamic value) {
    return (value ?? '').toString().trim();
  }

  int readInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse((value ?? '0').toString()) ?? 0;
  }

  double readDouble(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return double.tryParse((value ?? '0').toString()) ?? 0.0;
  }

  Map<String, dynamic> asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String firstNonEmpty(List<String> values) {
    for (final value in values) {
      if (value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }

  String extractTargetKey(Map<String, dynamic> data) {
    final menuSnapshot = asMap(data['menu_snapshot']);

    return firstNonEmpty([
      normalizeText(data['feedback_target_key']),
      normalizeText(data['rate_target_key']),
      normalizeText(data['menu_item_id']),
      normalizeText(data['menu_option_key']),
      normalizeText(menuSnapshot['item_id']),
      normalizeText(menuSnapshot['option_key']),
    ]);
  }

  String extractMenuItemId(Map<String, dynamic> data) {
    return extractTargetKey(data);
  }

  String extractItemName(Map<String, dynamic> data) {
    final menuSnapshot = asMap(data['menu_snapshot']);

    return firstNonEmpty([
      normalizeText(data['item_name']),
      normalizeText(menuSnapshot['item_name']),
      normalizeText(data['option_label']),
      normalizeText(menuSnapshot['option_label']),
      extractTargetKey(data),
    ]);
  }

  String extractCategory(Map<String, dynamic> data) {
    final menuSnapshot = asMap(data['menu_snapshot']);

    return firstNonEmpty([
      normalizeText(data['category']),
      normalizeText(menuSnapshot['item_category']),
      normalizeText(data['meal_type']),
    ]);
  }

  DateTime? toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);

    if (value is Map<String, dynamic>) {
      final seconds = value['_seconds'] ?? value['seconds'];
      final nanoseconds = value['_nanoseconds'] ?? value['nanoseconds'];

      if (seconds is int) {
        final millis =
            (seconds * 1000) + ((nanoseconds is int) ? (nanoseconds ~/ 1000000) : 0);
        return DateTime.fromMillisecondsSinceEpoch(millis);
      }
    }

    return null;
  }

  double resolveAmount({
    required dynamic explicitAmount,
    required dynamic unitRate,
    required int quantity,
  }) {
    final amount = readDouble(explicitAmount);
    if (amount > 0) {
      return amount;
    }

    final rate = readDouble(unitRate);
    if (rate > 0 && quantity > 0) {
      return rate * quantity;
    }

    return 0.0;
  }

  Future<MyMealHistoryData> getMealHistory({
    required String employeeNumber,
    required DateTime fromDate,
    required DateTime toDateExclusive,
    bool includeCancelled = false,
  }) async {
    final normalizedEmployeeNumber = employeeNumber.trim();
    if (normalizedEmployeeNumber.isEmpty) {
      throw ArgumentError('employeeNumber is required.');
    }

    final snapshot = await _reservationsRef
        .where('employee_number', isEqualTo: normalizedEmployeeNumber)
        .where(
          'reservation_date',
          isGreaterThanOrEqualTo: Timestamp.fromDate(normalizeDate(fromDate)),
        )
        .where(
          'reservation_date',
          isLessThan: Timestamp.fromDate(normalizeDate(toDateExclusive)),
        )
        .get();

    final items = <MyMealHistoryEntry>[];

    int totalQuantity = 0;
    double totalAmount = 0.0;
    int activeCount = 0;
    int issuedCount = 0;
    int cancelledCount = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final status = normalizeText(data['status']).toLowerCase();
      final isIssued = data['is_issued'] == true || status == 'issued';
      final quantity = readInt(data['quantity']);
      final unitRate = readDouble(data['unit_rate']);
      final amount = resolveAmount(
        explicitAmount: data['amount'],
        unitRate: data['unit_rate'],
        quantity: quantity,
      );

      if (!includeCancelled && status == 'cancelled') {
        cancelledCount += 1;
        continue;
      }

      if (status == 'cancelled') {
        cancelledCount += 1;
      } else {
        activeCount += 1;
      }

      if (isIssued) {
        issuedCount += 1;
      }

      if (status != 'cancelled') {
        totalQuantity += quantity;
        totalAmount += amount;
      }

      items.add(
        MyMealHistoryEntry(
          id: doc.id,
          bookingGroupId: normalizeText(data['booking_group_id']),
          reservationDate: toDate(data['reservation_date']) ?? DateTime.now(),
          mealType: normalizeText(data['meal_type']).toLowerCase(),
          menuItemId: extractMenuItemId(data),
          feedbackTargetKey: extractTargetKey(data),
          itemName: extractItemName(data),
          category: extractCategory(data),
          diningMode: normalizeText(data['dining_mode']).toLowerCase(),
          quantity: quantity,
          unitRate: unitRate,
          amount: amount,
          status: status,
          isIssued: isIssued,
          notes: normalizeText(data['notes']),
        ),
      );
    }

    items.sort((a, b) {
      final byDate = b.reservationDate.compareTo(a.reservationDate);
      if (byDate != 0) return byDate;

      final mealCompare = _mealSortOrder(a.mealType).compareTo(
        _mealSortOrder(b.mealType),
      );
      if (mealCompare != 0) return mealCompare;

      return a.itemName.toLowerCase().compareTo(b.itemName.toLowerCase());
    });

    return MyMealHistoryData(
      entries: items,
      totalQuantity: totalQuantity,
      totalAmount: totalAmount,
      activeCount: activeCount,
      issuedCount: issuedCount,
      cancelledCount: cancelledCount,
    );
  }

  Future<MyMealHistoryData> getCurrentMonthHistory({
    required String employeeNumber,
  }) async {
    final now = DateTime.now();
    final from = startOfMonth(now);
    final to = endOfMonth(now);

    return getMealHistory(
      employeeNumber: employeeNumber,
      fromDate: from,
      toDateExclusive: to,
    );
  }

  int _mealSortOrder(String mealType) {
    switch (mealType.trim().toLowerCase()) {
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

class MyMealHistoryData {
  final List<MyMealHistoryEntry> entries;
  final int totalQuantity;
  final double totalAmount;
  final int activeCount;
  final int issuedCount;
  final int cancelledCount;

  const MyMealHistoryData({
    required this.entries,
    required this.totalQuantity,
    required this.totalAmount,
    required this.activeCount,
    required this.issuedCount,
    required this.cancelledCount,
  });
}

class MyMealHistoryEntry {
  final String id;
  final String bookingGroupId;
  final DateTime reservationDate;
  final String mealType;
  final String menuItemId;
  final String feedbackTargetKey;
  final String itemName;
  final String category;
  final String diningMode;
  final int quantity;
  final double unitRate;
  final double amount;
  final String status;
  final bool isIssued;
  final String notes;

  const MyMealHistoryEntry({
    required this.id,
    required this.bookingGroupId,
    required this.reservationDate,
    required this.mealType,
    required this.menuItemId,
    required this.feedbackTargetKey,
    required this.itemName,
    required this.category,
    required this.diningMode,
    required this.quantity,
    required this.unitRate,
    required this.amount,
    required this.status,
    required this.isIssued,
    required this.notes,
  });
}
