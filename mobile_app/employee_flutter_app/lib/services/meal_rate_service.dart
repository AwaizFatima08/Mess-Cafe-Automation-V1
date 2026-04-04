import 'package:cloud_firestore/cloud_firestore.dart';

class MealRateService {
  MealRateService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _mealRatesRef =>
      _firestore.collection('meal_rates');

  CollectionReference<Map<String, dynamic>> get _mealReservationsRef =>
      _firestore.collection('meal_reservations');

  static const String statusActive = 'active';
  static const String statusCancelled = 'cancelled';

  DateTime normalizeDate(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  DateTime nextDate(DateTime value) {
    final normalized = normalizeDate(value);
    return normalized.add(const Duration(days: 1));
  }

  Timestamp normalizeTimestamp(DateTime value) {
    return Timestamp.fromDate(normalizeDate(value));
  }

  String buildDateKey(DateTime value) {
    final normalized = normalizeDate(value);
    final year = normalized.year.toString().padLeft(4, '0');
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '$year$month$day';
  }

  String buildRateDocumentId({
    required DateTime rateDate,
    required String menuItemId,
  }) {
    final dateKey = buildDateKey(rateDate);
    final normalizedMenuItemId = _sanitizeDocKeyComponent(menuItemId);
    return '${dateKey}__$normalizedMenuItemId';
  }

  Stream<List<MealRateEntry>> watchRatesForDate(DateTime rateDate) {
    final start = Timestamp.fromDate(normalizeDate(rateDate));
    final end = Timestamp.fromDate(nextDate(rateDate));

    return _mealRatesRef
        .where('rate_date', isGreaterThanOrEqualTo: start)
        .where('rate_date', isLessThan: end)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MealRateEntry.fromDocument(doc))
              .toList()
            ..sort(
              (a, b) => a.itemName.toLowerCase().compareTo(
                    b.itemName.toLowerCase(),
                  ),
            ),
        );
  }

  Future<List<MealRateEntry>> getRatesForDate(DateTime rateDate) async {
    final start = Timestamp.fromDate(normalizeDate(rateDate));
    final end = Timestamp.fromDate(nextDate(rateDate));

    final query = await _mealRatesRef
        .where('rate_date', isGreaterThanOrEqualTo: start)
        .where('rate_date', isLessThan: end)
        .get();

    final entries = query.docs
        .map((doc) => MealRateEntry.fromDocument(doc))
        .toList();

    entries.sort(
      (a, b) => a.itemName.toLowerCase().compareTo(
            b.itemName.toLowerCase(),
          ),
    );

    return entries;
  }

  Future<MealRateEntry?> getRateForDateAndMenuItem({
    required DateTime rateDate,
    required String menuItemId,
  }) async {
    final normalizedMenuItemId = menuItemId.trim();
    if (normalizedMenuItemId.isEmpty) {
      return null;
    }

    final docId = buildRateDocumentId(
      rateDate: rateDate,
      menuItemId: normalizedMenuItemId,
    );

    final doc = await _mealRatesRef.doc(docId).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }

    return MealRateEntry.fromDocument(doc);
  }

  Future<void> upsertRate({
    required DateTime rateDate,
    required String menuItemId,
    required String itemName,
    required num unitRate,
    String? category,
    bool isActive = true,
    String? enteredByUid,
    String? enteredByName,
  }) async {
    final normalizedMenuItemId = menuItemId.trim();
    final normalizedItemName = itemName.trim();
    final normalizedCategory = (category ?? '').trim();

    if (normalizedMenuItemId.isEmpty) {
      throw ArgumentError('menuItemId is required.');
    }
    if (normalizedItemName.isEmpty) {
      throw ArgumentError('itemName is required.');
    }

    final parsedRate = unitRate.toDouble();
    if (parsedRate < 0) {
      throw ArgumentError('unitRate cannot be negative.');
    }

    final normalizedRateDate = normalizeDate(rateDate);
    final docId = buildRateDocumentId(
      rateDate: normalizedRateDate,
      menuItemId: normalizedMenuItemId,
    );

    final docRef = _mealRatesRef.doc(docId);
    final existing = await docRef.get();
    final now = Timestamp.now();

    final payload = <String, dynamic>{
      'menu_item_id': normalizedMenuItemId,
      'item_name': normalizedItemName,
      'category': normalizedCategory,
      'rate_date': Timestamp.fromDate(normalizedRateDate),
      'unit_rate': parsedRate,
      'is_active': isActive,
      'entered_by_uid': (enteredByUid ?? '').trim(),
      'entered_by_name': (enteredByName ?? '').trim(),
      'updated_at': now,
    };

    if (!existing.exists) {
      payload['created_at'] = now;
    }

    await docRef.set(payload, SetOptions(merge: true));
  }

  Future<void> saveRatesBatch({
    required DateTime rateDate,
    required List<MealRateDraft> drafts,
    String? enteredByUid,
    String? enteredByName,
    bool skipZeroRates = false,
  }) async {
    if (drafts.isEmpty) return;

    final normalizedRateDate = normalizeDate(rateDate);
    final now = Timestamp.now();
    final batch = _firestore.batch();

    for (final draft in drafts) {
      final normalizedMenuItemId = draft.menuItemId.trim();
      final normalizedItemName = draft.itemName.trim();
      final normalizedCategory = draft.category.trim();

      if (normalizedMenuItemId.isEmpty || normalizedItemName.isEmpty) {
        continue;
      }

      final parsedRate = draft.unitRate;
      if (parsedRate < 0) {
        throw ArgumentError(
          'Negative rate is not allowed for ${draft.itemName}.',
        );
      }

      if (skipZeroRates && parsedRate == 0) {
        continue;
      }

      final docId = buildRateDocumentId(
        rateDate: normalizedRateDate,
        menuItemId: normalizedMenuItemId,
      );

      final docRef = _mealRatesRef.doc(docId);

      batch.set(
        docRef,
        <String, dynamic>{
          'menu_item_id': normalizedMenuItemId,
          'item_name': normalizedItemName,
          'category': normalizedCategory,
          'rate_date': Timestamp.fromDate(normalizedRateDate),
          'unit_rate': parsedRate,
          'is_active': draft.isActive,
          'entered_by_uid': (enteredByUid ?? '').trim(),
          'entered_by_name': (enteredByName ?? '').trim(),
          'updated_at': now,
          'created_at': now,
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  Future<List<ConsumedItemSummary>> getConsumedItemSummaryForDate(
    DateTime reservationDate,
  ) async {
    final normalizedDate = normalizeDate(reservationDate);
    final start = Timestamp.fromDate(normalizedDate);
    final end = Timestamp.fromDate(nextDate(normalizedDate));

    final query = await _mealReservationsRef
        .where('reservation_date', isGreaterThanOrEqualTo: start)
        .where('reservation_date', isLessThan: end)
        .get();

    final summaryByKey = <String, _ConsumedItemAccumulator>{};

    for (final doc in query.docs) {
      final data = doc.data();

      final status = (data['status'] ?? '').toString().trim().toLowerCase();
      if (status == statusCancelled) {
        continue;
      }

      final quantity = _asInt(data['quantity']);
      if (quantity <= 0) {
        continue;
      }

      final menuSnapshot = _asMap(data['menu_snapshot']);
      final mealType = _normalizeText(data['meal_type']);
      final optionKey = _firstNonEmpty([
        _normalizeText(menuSnapshot['item_id']),
        _normalizeText(data['menu_item_id']),
        _normalizeText(data['menu_option_key']),
        _normalizeText(menuSnapshot['option_key']),
      ]);

      final optionLabel = _firstNonEmpty([
        _normalizeText(menuSnapshot['item_name']),
        _normalizeText(data['item_name']),
        _normalizeText(data['option_label']),
        _normalizeText(menuSnapshot['option_label']),
      ]);

      final itemCategory = _firstNonEmpty([
        _normalizeText(menuSnapshot['item_category']),
        _normalizeText(data['category']),
        mealType,
      ]);

      if (optionKey.isEmpty) {
        continue;
      }

      final items = _asListOfMaps(menuSnapshot['items']);
      final bool treatAsComboSingleItem =
          items.isNotEmpty && !_looksLikeDirectManualItem(menuSnapshot);

      final effectiveMenuItemId = optionKey;
      final effectiveItemName = optionLabel.isNotEmpty ? optionLabel : optionKey;
      final effectiveCategory =
          itemCategory.isNotEmpty ? itemCategory : mealType;

      final lookupKey = effectiveMenuItemId.trim().toLowerCase();

      final accumulator = summaryByKey.putIfAbsent(
        lookupKey,
        () => _ConsumedItemAccumulator(
          menuItemId: effectiveMenuItemId,
          itemName: effectiveItemName,
          category: effectiveCategory,
          mealType: mealType,
          selectionType: treatAsComboSingleItem
              ? MealRateSelectionType.comboOption
              : MealRateSelectionType.manualItem,
        ),
      );

      accumulator.totalQuantity += quantity;
      accumulator.reservationLineCount += 1;
      accumulator.optionLabels.add(effectiveItemName);

      if (doc.id.isNotEmpty) {
        accumulator.sampleReservationIds.add(doc.id);
      }
    }

    final result = summaryByKey.values
        .map((item) => item.toSummary())
        .toList()
      ..sort(
        (a, b) => a.itemName.toLowerCase().compareTo(
              b.itemName.toLowerCase(),
            ),
      );

    return result;
  }

  Future<List<MealRateEntryRow>> getRateEntryRowsForDate(DateTime rateDate) async {
    final summaries = await getConsumedItemSummaryForDate(rateDate);
    final rates = await getRatesForDate(rateDate);

    final rateMap = <String, MealRateEntry>{
      for (final rate in rates) rate.menuItemId.trim().toLowerCase(): rate,
    };

    final rows = summaries
        .map(
          (summary) => MealRateEntryRow(
            summary: summary,
            existingRate: rateMap[summary.menuItemId.trim().toLowerCase()],
          ),
        )
        .toList();

    return rows;
  }

  Future<int> applyRatesToReservationsForDate(DateTime reservationDate) async {
    final normalizedDate = normalizeDate(reservationDate);
    final start = Timestamp.fromDate(normalizedDate);
    final end = Timestamp.fromDate(nextDate(normalizedDate));

    final rates = await getRatesForDate(normalizedDate);
    final rateMap = <String, MealRateEntry>{
      for (final rate in rates)
        rate.menuItemId.trim().toLowerCase(): rate,
    };

    final reservationQuery = await _mealReservationsRef
        .where('reservation_date', isGreaterThanOrEqualTo: start)
        .where('reservation_date', isLessThan: end)
        .get();

    if (reservationQuery.docs.isEmpty || rateMap.isEmpty) {
      return 0;
    }

    final batch = _firestore.batch();
    var updatedCount = 0;

    for (final doc in reservationQuery.docs) {
      final data = doc.data();
      final status = (data['status'] ?? '').toString().trim().toLowerCase();
      if (status == statusCancelled) {
        continue;
      }

      final quantity = _asInt(data['quantity']);
      if (quantity <= 0) {
        continue;
      }

      final menuItemId = _extractReservationMenuItemId(data);
      if (menuItemId.isEmpty) {
        continue;
      }

      final rate = rateMap[menuItemId.trim().toLowerCase()];
      if (rate == null || !rate.isActive) {
        continue;
      }

      final amount = rate.unitRate * quantity;

      batch.update(doc.reference, <String, dynamic>{
        'unit_rate': rate.unitRate,
        'amount': amount,
        'updated_at': Timestamp.now(),
      });

      updatedCount += 1;
    }

    if (updatedCount > 0) {
      await batch.commit();
    }

    return updatedCount;
  }

  String extractReservationMenuItemId(Map<String, dynamic> reservationData) {
    return _extractReservationMenuItemId(reservationData);
  }

  String extractReservationItemName(Map<String, dynamic> reservationData) {
    final menuSnapshot = _asMap(reservationData['menu_snapshot']);

    return _firstNonEmpty([
      _normalizeText(menuSnapshot['item_name']),
      _normalizeText(reservationData['item_name']),
      _normalizeText(reservationData['option_label']),
      _normalizeText(menuSnapshot['option_label']),
      _extractReservationMenuItemId(reservationData),
    ]);
  }

  String _extractReservationMenuItemId(Map<String, dynamic> reservationData) {
    final menuSnapshot = _asMap(reservationData['menu_snapshot']);

    return _firstNonEmpty([
      _normalizeText(menuSnapshot['item_id']),
      _normalizeText(reservationData['menu_item_id']),
      _normalizeText(reservationData['menu_option_key']),
      _normalizeText(menuSnapshot['option_key']),
    ]);
  }

  bool _looksLikeDirectManualItem(Map<String, dynamic> menuSnapshot) {
    final selectionType = _normalizeText(menuSnapshot['selection_type']);
    return selectionType == 'manual_item';
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _asListOfMaps(dynamic value) {
    if (value is! List) {
      return const <Map<String, dynamic>>[];
    }

    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse((value ?? '').toString()) ?? 0;
  }

  String _normalizeText(dynamic value) {
    return (value ?? '').toString().trim();
  }

  String _firstNonEmpty(List<String> values) {
    for (final value in values) {
      if (value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }

  String _sanitizeDocKeyComponent(String input) {
    final value = input.trim();
    if (value.isEmpty) return 'unknown_item';

    return value
        .replaceAll('/', '_')
        .replaceAll('\\', '_')
        .replaceAll(' ', '_')
        .replaceAll(':', '_')
        .replaceAll('#', '_');
  }
}

class MealRateEntry {
  final String documentId;
  final String menuItemId;
  final String itemName;
  final String category;
  final DateTime rateDate;
  final double unitRate;
  final bool isActive;
  final String enteredByUid;
  final String enteredByName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MealRateEntry({
    required this.documentId,
    required this.menuItemId,
    required this.itemName,
    required this.category,
    required this.rateDate,
    required this.unitRate,
    required this.isActive,
    required this.enteredByUid,
    required this.enteredByName,
    this.createdAt,
    this.updatedAt,
  });

  factory MealRateEntry.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};

    return MealRateEntry(
      documentId: doc.id,
      menuItemId: (data['menu_item_id'] ?? '').toString().trim(),
      itemName: (data['item_name'] ?? '').toString().trim(),
      category: (data['category'] ?? '').toString().trim(),
      rateDate: _toDate(data['rate_date']) ?? DateTime.now(),
      unitRate: _toDouble(data['unit_rate']),
      isActive: data['is_active'] != false,
      enteredByUid: (data['entered_by_uid'] ?? '').toString().trim(),
      enteredByName: (data['entered_by_name'] ?? '').toString().trim(),
      createdAt: _toDate(data['created_at']),
      updatedAt: _toDate(data['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'menu_item_id': menuItemId,
      'item_name': itemName,
      'category': category,
      'rate_date': Timestamp.fromDate(
        DateTime(rateDate.year, rateDate.month, rateDate.day),
      ),
      'unit_rate': unitRate,
      'is_active': isActive,
      'entered_by_uid': enteredByUid,
      'entered_by_name': enteredByName,
      'created_at': createdAt == null ? null : Timestamp.fromDate(createdAt!),
      'updated_at': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
    };
  }

  static DateTime? _toDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static double _toDouble(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return double.tryParse((value ?? '').toString()) ?? 0;
  }
}

class MealRateDraft {
  final String menuItemId;
  final String itemName;
  final String category;
  final double unitRate;
  final bool isActive;

  const MealRateDraft({
    required this.menuItemId,
    required this.itemName,
    required this.category,
    required this.unitRate,
    this.isActive = true,
  });

  MealRateDraft copyWith({
    String? menuItemId,
    String? itemName,
    String? category,
    double? unitRate,
    bool? isActive,
  }) {
    return MealRateDraft(
      menuItemId: menuItemId ?? this.menuItemId,
      itemName: itemName ?? this.itemName,
      category: category ?? this.category,
      unitRate: unitRate ?? this.unitRate,
      isActive: isActive ?? this.isActive,
    );
  }
}

class MealRateEntryRow {
  final ConsumedItemSummary summary;
  final MealRateEntry? existingRate;

  const MealRateEntryRow({
    required this.summary,
    this.existingRate,
  });

  double get initialRate => existingRate?.unitRate ?? 0;
  bool get hasSavedRate => existingRate != null;
}

class ConsumedItemSummary {
  final String menuItemId;
  final String itemName;
  final String category;
  final String mealType;
  final int totalQuantity;
  final int reservationLineCount;
  final MealRateSelectionType selectionType;
  final List<String> optionLabels;
  final List<String> sampleReservationIds;

  const ConsumedItemSummary({
    required this.menuItemId,
    required this.itemName,
    required this.category,
    required this.mealType,
    required this.totalQuantity,
    required this.reservationLineCount,
    required this.selectionType,
    required this.optionLabels,
    required this.sampleReservationIds,
  });
}

enum MealRateSelectionType {
  comboOption,
  manualItem,
}

class _ConsumedItemAccumulator {
  final String menuItemId;
  final String itemName;
  final String category;
  final String mealType;
  final MealRateSelectionType selectionType;

  int totalQuantity = 0;
  int reservationLineCount = 0;
  final Set<String> optionLabels = <String>{};
  final Set<String> sampleReservationIds = <String>{};

  _ConsumedItemAccumulator({
    required this.menuItemId,
    required this.itemName,
    required this.category,
    required this.mealType,
    required this.selectionType,
  });

  ConsumedItemSummary toSummary() {
    return ConsumedItemSummary(
      menuItemId: menuItemId,
      itemName: itemName,
      category: category,
      mealType: mealType,
      totalQuantity: totalQuantity,
      reservationLineCount: reservationLineCount,
      selectionType: selectionType,
      optionLabels: optionLabels.toList()..sort(),
      sampleReservationIds: sampleReservationIds.toList()..sort(),
    );
  }
}
