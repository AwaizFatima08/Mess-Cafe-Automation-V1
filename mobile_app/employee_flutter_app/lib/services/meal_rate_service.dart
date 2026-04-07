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
  static const int _maxBatchOperations = 450;

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
    final normalizedTargetKey = menuItemId.trim();
    if (normalizedTargetKey.isEmpty) {
      return null;
    }

    final docId = buildRateDocumentId(
      rateDate: rateDate,
      menuItemId: normalizedTargetKey,
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
    final normalizedTargetKey = menuItemId.trim();
    final normalizedItemName = itemName.trim();
    final normalizedCategory = (category ?? '').trim();

    if (normalizedTargetKey.isEmpty) {
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
      menuItemId: normalizedTargetKey,
    );

    final docRef = _mealRatesRef.doc(docId);
    final existing = await docRef.get();
    final now = Timestamp.now();

    final payload = <String, dynamic>{
      'menu_item_id': normalizedTargetKey,
      'rate_target_key': normalizedTargetKey,
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

    var batch = _firestore.batch();
    var operations = 0;

    for (final draft in drafts) {
      final normalizedTargetKey = draft.menuItemId.trim();
      final normalizedItemName = draft.itemName.trim();
      final normalizedCategory = draft.category.trim();

      if (normalizedTargetKey.isEmpty || normalizedItemName.isEmpty) {
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
        menuItemId: normalizedTargetKey,
      );

      final docRef = _mealRatesRef.doc(docId);

      batch.set(
        docRef,
        <String, dynamic>{
          'menu_item_id': normalizedTargetKey,
          'rate_target_key': normalizedTargetKey,
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

      operations += 1;
      if (operations >= _maxBatchOperations) {
        await batch.commit();
        batch = _firestore.batch();
        operations = 0;
      }
    }

    if (operations > 0) {
      await batch.commit();
    }
  }

  Future<MealRateSaveApplyResult> saveRatesBatchAndApplyToReservationsForDate({
    required DateTime rateDate,
    required List<MealRateDraft> drafts,
    String? enteredByUid,
    String? enteredByName,
    bool skipZeroRates = false,
  }) async {
    if (drafts.isEmpty) {
      return const MealRateSaveApplyResult(
        savedRateCount: 0,
        updatedReservationCount: 0,
      );
    }

    final normalizedRateDate = normalizeDate(rateDate);
    final now = Timestamp.now();

    final normalizedDrafts = <MealRateDraft>[];
    final changedRateMap = <String, _ResolvedRate>{};

    for (final draft in drafts) {
      final normalizedTargetKey = draft.menuItemId.trim();
      final normalizedItemName = draft.itemName.trim();
      final normalizedCategory = draft.category.trim();
      final parsedRate = draft.unitRate;

      if (normalizedTargetKey.isEmpty || normalizedItemName.isEmpty) {
        continue;
      }

      if (parsedRate < 0) {
        throw ArgumentError(
          'Negative rate is not allowed for ${draft.itemName}.',
        );
      }

      if (skipZeroRates && parsedRate == 0) {
        continue;
      }

      final normalized = MealRateDraft(
        menuItemId: normalizedTargetKey,
        itemName: normalizedItemName,
        category: normalizedCategory,
        unitRate: parsedRate,
        isActive: draft.isActive,
      );

      normalizedDrafts.add(normalized);
      changedRateMap[normalizedTargetKey.toLowerCase()] = _ResolvedRate(
        targetKey: normalizedTargetKey,
        unitRate: parsedRate,
        isActive: normalized.isActive,
      );
    }

    if (normalizedDrafts.isEmpty) {
      return const MealRateSaveApplyResult(
        savedRateCount: 0,
        updatedReservationCount: 0,
      );
    }

    var rateBatch = _firestore.batch();
    var rateOps = 0;

    for (final draft in normalizedDrafts) {
      final docId = buildRateDocumentId(
        rateDate: normalizedRateDate,
        menuItemId: draft.menuItemId,
      );

      final docRef = _mealRatesRef.doc(docId);

      rateBatch.set(
        docRef,
        <String, dynamic>{
          'menu_item_id': draft.menuItemId,
          'rate_target_key': draft.menuItemId,
          'item_name': draft.itemName,
          'category': draft.category,
          'rate_date': Timestamp.fromDate(normalizedRateDate),
          'unit_rate': draft.unitRate,
          'is_active': draft.isActive,
          'entered_by_uid': (enteredByUid ?? '').trim(),
          'entered_by_name': (enteredByName ?? '').trim(),
          'updated_at': now,
          'created_at': now,
        },
        SetOptions(merge: true),
      );

      rateOps += 1;
      if (rateOps >= _maxBatchOperations) {
        await rateBatch.commit();
        rateBatch = _firestore.batch();
        rateOps = 0;
      }
    }

    if (rateOps > 0) {
      await rateBatch.commit();
    }

    final updatedReservationCount =
        await applyRatesToReservationsForDateUsingRateMap(
      reservationDate: normalizedRateDate,
      rateMap: changedRateMap,
    );

    return MealRateSaveApplyResult(
      savedRateCount: normalizedDrafts.length,
      updatedReservationCount: updatedReservationCount,
    );
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
      final effectiveTargetKey = _extractReservationRateTargetKey(data);

      if (effectiveTargetKey.isEmpty) {
        continue;
      }

      final optionLabel = _firstNonEmpty([
        _normalizeText(data['item_name']),
        _normalizeText(menuSnapshot['item_name']),
        _normalizeText(data['option_label']),
        _normalizeText(menuSnapshot['option_label']),
        effectiveTargetKey,
      ]);

      final itemCategory = _firstNonEmpty([
        _normalizeText(data['category']),
        _normalizeText(menuSnapshot['item_category']),
        mealType,
      ]);

      final items = _asListOfMaps(menuSnapshot['items']);
      final selectionMode = _normalizeText(data['selection_mode']).toLowerCase();
      final bool treatAsComboSingleItem =
          selectionMode == 'cycle_combo' ||
          (items.isNotEmpty && !_looksLikeDirectManualItem(menuSnapshot));

      final lookupKey = effectiveTargetKey.trim().toLowerCase();

      final accumulator = summaryByKey.putIfAbsent(
        lookupKey,
        () => _ConsumedItemAccumulator(
          menuItemId: effectiveTargetKey,
          itemName: optionLabel,
          category: itemCategory,
          mealType: mealType,
          selectionType: treatAsComboSingleItem
              ? MealRateSelectionType.comboOption
              : MealRateSelectionType.manualItem,
        ),
      );

      accumulator.totalQuantity += quantity;
      accumulator.reservationLineCount += 1;
      accumulator.optionLabels.add(optionLabel);

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
      for (final rate in rates)
        (rate.rateTargetKey.isNotEmpty
                ? rate.rateTargetKey
                : rate.menuItemId)
            .trim()
            .toLowerCase(): rate,
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
    final rates = await getRatesForDate(normalizeDate(reservationDate));
    final rateMap = <String, _ResolvedRate>{
      for (final rate in rates)
        (rate.rateTargetKey.isNotEmpty ? rate.rateTargetKey : rate.menuItemId)
            .trim()
            .toLowerCase(): _ResolvedRate(
          targetKey:
              (rate.rateTargetKey.isNotEmpty ? rate.rateTargetKey : rate.menuItemId)
                  .trim(),
          unitRate: rate.unitRate,
          isActive: rate.isActive,
        ),
    };

    return applyRatesToReservationsForDateUsingRateMap(
      reservationDate: reservationDate,
      rateMap: rateMap,
    );
  }

  Future<int> applyRatesToReservationsForDateUsingRateMap({
    required DateTime reservationDate,
    required Map<String, _ResolvedRate> rateMap,
  }) async {
    final normalizedDate = normalizeDate(reservationDate);
    final start = Timestamp.fromDate(normalizedDate);
    final end = Timestamp.fromDate(nextDate(normalizedDate));

    final reservationQuery = await _mealReservationsRef
        .where('reservation_date', isGreaterThanOrEqualTo: start)
        .where('reservation_date', isLessThan: end)
        .get();

    if (reservationQuery.docs.isEmpty || rateMap.isEmpty) {
      return 0;
    }

    var batch = _firestore.batch();
    var updatedCount = 0;
    var batchOps = 0;
    final now = Timestamp.now();

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

      final targetKey = _extractReservationRateTargetKey(data);
      if (targetKey.isEmpty) {
        continue;
      }

      final rate = rateMap[targetKey.trim().toLowerCase()];
      if (rate == null || !rate.isActive) {
        continue;
      }

      final amount = rate.unitRate * quantity;
      final currentUnitRate = _asDouble(data['unit_rate']);
      final currentAmount = _asDouble(data['amount']);
      final currentStoredTarget = _normalizeText(data['rate_target_key']);

      final noChange = currentStoredTarget == rate.targetKey &&
          currentUnitRate == rate.unitRate &&
          currentAmount == amount;

      if (noChange) {
        continue;
      }

      batch.update(doc.reference, <String, dynamic>{
        'rate_target_key': rate.targetKey,
        'unit_rate': rate.unitRate,
        'amount': amount,
        'updated_at': now,
      });

      updatedCount += 1;
      batchOps += 1;

      if (batchOps >= _maxBatchOperations) {
        await batch.commit();
        batch = _firestore.batch();
        batchOps = 0;
      }
    }

    if (batchOps > 0) {
      await batch.commit();
    }

    return updatedCount;
  }

  String extractReservationMenuItemId(Map<String, dynamic> reservationData) {
    return _extractReservationRateTargetKey(reservationData);
  }

  String extractReservationItemName(Map<String, dynamic> reservationData) {
    final menuSnapshot = _asMap(reservationData['menu_snapshot']);

    return _firstNonEmpty([
      _normalizeText(reservationData['item_name']),
      _normalizeText(menuSnapshot['item_name']),
      _normalizeText(reservationData['option_label']),
      _normalizeText(menuSnapshot['option_label']),
      _extractReservationRateTargetKey(reservationData),
    ]);
  }

  String _extractReservationRateTargetKey(Map<String, dynamic> reservationData) {
    final menuSnapshot = _asMap(reservationData['menu_snapshot']);

    return _firstNonEmpty([
      _normalizeText(reservationData['rate_target_key']),
      _normalizeText(reservationData['menu_item_id']),
      _normalizeText(reservationData['menu_option_key']),
      _normalizeText(menuSnapshot['item_id']),
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

  double _asDouble(dynamic value) {
    if (value is int) return value.toDouble();
    if (value is double) return value;
    return double.tryParse((value ?? '').toString()) ?? 0.0;
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

class MealRateSaveApplyResult {
  final int savedRateCount;
  final int updatedReservationCount;

  const MealRateSaveApplyResult({
    required this.savedRateCount,
    required this.updatedReservationCount,
  });
}

class MealRateEntry {
  final String documentId;
  final String menuItemId;
  final String rateTargetKey;
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
    required this.rateTargetKey,
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

    final parsedMenuItemId = (data['menu_item_id'] ?? '').toString().trim();
    final parsedRateTargetKey =
        (data['rate_target_key'] ?? parsedMenuItemId).toString().trim();

    return MealRateEntry(
      documentId: doc.id,
      menuItemId: parsedMenuItemId,
      rateTargetKey: parsedRateTargetKey,
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
      'rate_target_key': rateTargetKey,
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

class _ResolvedRate {
  final String targetKey;
  final double unitRate;
  final bool isActive;

  const _ResolvedRate({
    required this.targetKey,
    required this.unitRate,
    required this.isActive,
  });
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
