import 'package:cloud_firestore/cloud_firestore.dart';

class MealFeedbackService {
  MealFeedbackService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _feedbackRef =>
      _firestore.collection('meal_feedback');

  CollectionReference<Map<String, dynamic>> get _reservationsRef =>
      _firestore.collection('meal_reservations');

  DateTime normalizeDate(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  Timestamp startOfDay(DateTime value) {
    return Timestamp.fromDate(normalizeDate(value));
  }

  Timestamp startOfNextDay(DateTime value) {
    return Timestamp.fromDate(
      normalizeDate(value).add(const Duration(days: 1)),
    );
  }

  String normalizeMealType(String mealType) {
    return mealType.trim().toLowerCase();
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

  String extractMenuItemId(Map<String, dynamic> reservationData) {
    final menuSnapshot = asMap(reservationData['menu_snapshot']);

    return firstNonEmpty([
      normalizeText(menuSnapshot['item_id']),
      normalizeText(reservationData['menu_item_id']),
      normalizeText(reservationData['menu_option_key']),
      normalizeText(menuSnapshot['option_key']),
    ]);
  }

  String extractItemName(Map<String, dynamic> reservationData) {
    final menuSnapshot = asMap(reservationData['menu_snapshot']);

    return firstNonEmpty([
      normalizeText(menuSnapshot['item_name']),
      normalizeText(reservationData['item_name']),
      normalizeText(reservationData['option_label']),
      normalizeText(menuSnapshot['option_label']),
      extractMenuItemId(reservationData),
    ]);
  }

  String extractCategory(Map<String, dynamic> reservationData) {
    final menuSnapshot = asMap(reservationData['menu_snapshot']);

    return firstNonEmpty([
      normalizeText(menuSnapshot['item_category']),
      normalizeText(reservationData['category']),
      normalizeText(reservationData['meal_type']),
    ]);
  }

  String buildFeedbackDocumentId({
    required String reservationId,
    required String submittedByUid,
  }) {
    final safeReservationId = reservationId.trim().replaceAll('/', '_');
    final safeUid = submittedByUid.trim().replaceAll('/', '_');
    return '${safeReservationId}__$safeUid';
  }

  Future<bool> hasFeedbackForReservation({
    required String reservationId,
    required String submittedByUid,
  }) async {
    final docId = buildFeedbackDocumentId(
      reservationId: reservationId,
      submittedByUid: submittedByUid,
    );

    final doc = await _feedbackRef.doc(docId).get();
    return doc.exists;
  }

  Future<void> submitFeedback({
    required String reservationId,
    required String submittedByUid,
    required String submittedByName,
    required String employeeNumber,
    required String employeeName,
    required DateTime reservationDate,
    required String mealType,
    required String menuItemId,
    required String itemName,
    required String category,
    required int rating,
    required String feedbackText,
    String issueType = '',
    bool isAnonymous = false,
    Map<String, dynamic>? extraFields,
  }) async {
    final normalizedReservationId = reservationId.trim();
    final normalizedSubmittedByUid = submittedByUid.trim();
    final normalizedSubmittedByName = submittedByName.trim();
    final normalizedEmployeeNumber = employeeNumber.trim();
    final normalizedEmployeeName = employeeName.trim();
    final normalizedMealType = normalizeMealType(mealType);
    final normalizedMenuItemId = menuItemId.trim();
    final normalizedItemName = itemName.trim();
    final normalizedCategory = category.trim();
    final normalizedFeedbackText = feedbackText.trim();
    final normalizedIssueType = issueType.trim().toLowerCase();
    final normalizedDate = normalizeDate(reservationDate);

    if (normalizedReservationId.isEmpty) {
      throw ArgumentError('reservationId is required.');
    }
    if (normalizedSubmittedByUid.isEmpty) {
      throw ArgumentError('submittedByUid is required.');
    }
    if (normalizedMealType.isEmpty) {
      throw ArgumentError('mealType is required.');
    }
    if (normalizedMenuItemId.isEmpty) {
      throw ArgumentError('menuItemId is required.');
    }
    if (normalizedItemName.isEmpty) {
      throw ArgumentError('itemName is required.');
    }
    if (rating < 1 || rating > 5) {
      throw ArgumentError('rating must be between 1 and 5.');
    }

    final docId = buildFeedbackDocumentId(
      reservationId: normalizedReservationId,
      submittedByUid: normalizedSubmittedByUid,
    );

    final existing = await _feedbackRef.doc(docId).get();
    if (existing.exists) {
      throw Exception('Feedback already submitted for this meal.');
    }

    final now = Timestamp.now();

    final payload = <String, dynamic>{
      'reservation_id': normalizedReservationId,
      'submitted_by_uid': normalizedSubmittedByUid,
      'submitted_by_name': isAnonymous ? '' : normalizedSubmittedByName,
      'employee_number': isAnonymous ? '' : normalizedEmployeeNumber,
      'employee_name': isAnonymous ? '' : normalizedEmployeeName,
      'is_anonymous': isAnonymous,
      'reservation_date': Timestamp.fromDate(normalizedDate),
      'meal_type': normalizedMealType,
      'menu_item_id': normalizedMenuItemId,
      'item_name': normalizedItemName,
      'category': normalizedCategory,
      'rating': rating,
      'feedback_text': normalizedFeedbackText,
      'issue_type': normalizedIssueType,
      'status': 'open',
      'submitted_at': now,
      'created_at': now,
      'updated_at': now,
    };

    if (extraFields != null && extraFields.isNotEmpty) {
      payload.addAll(extraFields);
    }

    await _feedbackRef.doc(docId).set(payload, SetOptions(merge: true));
  }

  Future<void> closeFeedback({
    required String feedbackId,
    required String closedByUid,
    required String closedByName,
    String resolutionNote = '',
  }) async {
    await _feedbackRef.doc(feedbackId).update({
      'status': 'closed',
      'closed_by_uid': closedByUid.trim(),
      'closed_by_name': closedByName.trim(),
      'resolution_note': resolutionNote.trim(),
      'closed_at': Timestamp.now(),
      'updated_at': Timestamp.now(),
    });
  }

  Future<List<MealFeedbackEntry>> getFeedbackForDate(DateTime date) async {
    final snapshot = await _feedbackRef
        .where('reservation_date', isGreaterThanOrEqualTo: startOfDay(date))
        .where('reservation_date', isLessThan: startOfNextDay(date))
        .get();

    final items = snapshot.docs
        .map((doc) => MealFeedbackEntry.fromDocument(doc))
        .toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

    return items;
  }

  Future<List<MealFeedbackEntry>> getOpenFeedback({DateTime? forDate}) async {
    Query<Map<String, dynamic>> query =
        _feedbackRef.where('status', isEqualTo: 'open');

    if (forDate != null) {
      query = query
          .where(
            'reservation_date',
            isGreaterThanOrEqualTo: startOfDay(forDate),
          )
          .where(
            'reservation_date',
            isLessThan: startOfNextDay(forDate),
          );
    }

    final snapshot = await query.get();

    final items = snapshot.docs
        .map((doc) => MealFeedbackEntry.fromDocument(doc))
        .toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

    return items;
  }

  Future<List<FeedbackEligibleReservation>> getFeedbackEligibleReservations({
    required String employeeNumber,
    required DateTime reservationDate,
    String? mealType,
    String? submittedByUid,
  }) async {
    final normalizedEmployeeNumber = employeeNumber.trim();
    if (normalizedEmployeeNumber.isEmpty) {
      throw ArgumentError('employeeNumber is required.');
    }

    Query<Map<String, dynamic>> query = _reservationsRef
        .where('employee_number', isEqualTo: normalizedEmployeeNumber)
        .where(
          'reservation_date',
          isGreaterThanOrEqualTo: startOfDay(reservationDate),
        )
        .where(
          'reservation_date',
          isLessThan: startOfNextDay(reservationDate),
        );

    if (mealType != null && mealType.trim().isNotEmpty) {
      query = query.where('meal_type', isEqualTo: normalizeMealType(mealType));
    }

    final reservationSnapshot = await query.get();

    if (reservationSnapshot.docs.isEmpty) {
      return <FeedbackEligibleReservation>[];
    }

    final result = <FeedbackEligibleReservation>[];

    for (final doc in reservationSnapshot.docs) {
      final data = doc.data();

      final status = normalizeText(data['status']).toLowerCase();
      final isIssued = data['is_issued'] == true || status == 'issued';

      if (status == 'cancelled') {
        continue;
      }

      final alreadySubmitted = submittedByUid == null || submittedByUid.trim().isEmpty
          ? false
          : await hasFeedbackForReservation(
              reservationId: doc.id,
              submittedByUid: submittedByUid.trim(),
            );

      result.add(
        FeedbackEligibleReservation(
          reservationId: doc.id,
          reservationDate: _toDate(data['reservation_date']) ?? reservationDate,
          mealType: normalizeMealType(data['meal_type']),
          menuItemId: extractMenuItemId(data),
          itemName: extractItemName(data),
          category: extractCategory(data),
          diningMode: normalizeText(data['dining_mode']),
          quantity: readInt(data['quantity']),
          status: status,
          isIssued: isIssued,
          alreadySubmitted: alreadySubmitted,
        ),
      );
    }

    result.sort((a, b) => a.itemName.toLowerCase().compareTo(
          b.itemName.toLowerCase(),
        ));

    return result;
  }

  Future<MealFeedbackSummary> getFeedbackSummaryForDate(DateTime date) async {
    final items = await getFeedbackForDate(date);

    if (items.isEmpty) {
      return MealFeedbackSummary.empty(date: normalizeDate(date));
    }

    int totalCount = 0;
    double ratingSum = 0.0;
    int openCount = 0;
    int closedCount = 0;

    final ratingBuckets = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    final itemSummaryMap = <String, FeedbackItemSummaryBuilder>{};

    for (final item in items) {
      totalCount += 1;
      ratingSum += item.rating;

      if (item.status == 'closed') {
        closedCount += 1;
      } else {
        openCount += 1;
      }

      ratingBuckets[item.rating] = (ratingBuckets[item.rating] ?? 0) + 1;

      final key = item.menuItemId.isNotEmpty
          ? item.menuItemId.toLowerCase()
          : item.itemName.toLowerCase();

      final builder = itemSummaryMap.putIfAbsent(
        key,
        () => FeedbackItemSummaryBuilder(
          menuItemId: item.menuItemId,
          itemName: item.itemName,
          category: item.category,
        ),
      );

      builder.totalCount += 1;
      builder.ratingSum += item.rating.toDouble();
      builder.issueTypes.add(item.issueType);
    }

    final itemSummaries = itemSummaryMap.values
        .map((e) => e.build())
        .toList()
      ..sort((a, b) => a.averageRating.compareTo(b.averageRating));

    return MealFeedbackSummary(
      date: normalizeDate(date),
      totalCount: totalCount,
      averageRating: totalCount > 0 ? ratingSum / totalCount : 0.0,
      openCount: openCount,
      closedCount: closedCount,
      ratingBuckets: ratingBuckets,
      itemSummaries: itemSummaries,
    );
  }

  DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

class MealFeedbackEntry {
  final String id;
  final String reservationId;
  final String submittedByUid;
  final String submittedByName;
  final String employeeNumber;
  final String employeeName;
  final bool isAnonymous;
  final DateTime reservationDate;
  final String mealType;
  final String menuItemId;
  final String itemName;
  final String category;
  final int rating;
  final String feedbackText;
  final String issueType;
  final String status;
  final DateTime submittedAt;
  final DateTime? closedAt;
  final String closedByUid;
  final String closedByName;
  final String resolutionNote;

  const MealFeedbackEntry({
    required this.id,
    required this.reservationId,
    required this.submittedByUid,
    required this.submittedByName,
    required this.employeeNumber,
    required this.employeeName,
    required this.isAnonymous,
    required this.reservationDate,
    required this.mealType,
    required this.menuItemId,
    required this.itemName,
    required this.category,
    required this.rating,
    required this.feedbackText,
    required this.issueType,
    required this.status,
    required this.submittedAt,
    this.closedAt,
    required this.closedByUid,
    required this.closedByName,
    required this.resolutionNote,
  });

  factory MealFeedbackEntry.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};

    return MealFeedbackEntry(
      id: doc.id,
      reservationId: (data['reservation_id'] ?? '').toString().trim(),
      submittedByUid: (data['submitted_by_uid'] ?? '').toString().trim(),
      submittedByName: (data['submitted_by_name'] ?? '').toString().trim(),
      employeeNumber: (data['employee_number'] ?? '').toString().trim(),
      employeeName: (data['employee_name'] ?? '').toString().trim(),
      isAnonymous: data['is_anonymous'] == true,
      reservationDate: _toDate(data['reservation_date']) ?? DateTime.now(),
      mealType: (data['meal_type'] ?? '').toString().trim().toLowerCase(),
      menuItemId: (data['menu_item_id'] ?? '').toString().trim(),
      itemName: (data['item_name'] ?? '').toString().trim(),
      category: (data['category'] ?? '').toString().trim(),
      rating: _toInt(data['rating']),
      feedbackText: (data['feedback_text'] ?? '').toString().trim(),
      issueType: (data['issue_type'] ?? '').toString().trim(),
      status: (data['status'] ?? 'open').toString().trim().toLowerCase(),
      submittedAt: _toDate(data['submitted_at']) ?? DateTime.now(),
      closedAt: _toDate(data['closed_at']),
      closedByUid: (data['closed_by_uid'] ?? '').toString().trim(),
      closedByName: (data['closed_by_name'] ?? '').toString().trim(),
      resolutionNote: (data['resolution_note'] ?? '').toString().trim(),
    );
  }

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse((value ?? '0').toString()) ?? 0;
  }
}

class FeedbackEligibleReservation {
  final String reservationId;
  final DateTime reservationDate;
  final String mealType;
  final String menuItemId;
  final String itemName;
  final String category;
  final String diningMode;
  final int quantity;
  final String status;
  final bool isIssued;
  final bool alreadySubmitted;

  const FeedbackEligibleReservation({
    required this.reservationId,
    required this.reservationDate,
    required this.mealType,
    required this.menuItemId,
    required this.itemName,
    required this.category,
    required this.diningMode,
    required this.quantity,
    required this.status,
    required this.isIssued,
    required this.alreadySubmitted,
  });
}

class MealFeedbackSummary {
  final DateTime date;
  final int totalCount;
  final double averageRating;
  final int openCount;
  final int closedCount;
  final Map<int, int> ratingBuckets;
  final List<FeedbackItemSummary> itemSummaries;

  const MealFeedbackSummary({
    required this.date,
    required this.totalCount,
    required this.averageRating,
    required this.openCount,
    required this.closedCount,
    required this.ratingBuckets,
    required this.itemSummaries,
  });

  factory MealFeedbackSummary.empty({required DateTime date}) {
    return MealFeedbackSummary(
      date: date,
      totalCount: 0,
      averageRating: 0.0,
      openCount: 0,
      closedCount: 0,
      ratingBuckets: const {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
      itemSummaries: const [],
    );
  }
}

class FeedbackItemSummary {
  final String menuItemId;
  final String itemName;
  final String category;
  final int totalCount;
  final double averageRating;
  final List<String> issueTypes;

  const FeedbackItemSummary({
    required this.menuItemId,
    required this.itemName,
    required this.category,
    required this.totalCount,
    required this.averageRating,
    required this.issueTypes,
  });
}

class FeedbackItemSummaryBuilder {
  final String menuItemId;
  final String itemName;
  final String category;

  int totalCount = 0;
  double ratingSum = 0.0;
  final Set<String> issueTypes = <String>{};

  FeedbackItemSummaryBuilder({
    required this.menuItemId,
    required this.itemName,
    required this.category,
  });

  FeedbackItemSummary build() {
    final cleanedIssues = issueTypes
        .where((e) => e.trim().isNotEmpty)
        .toList()
      ..sort();

    return FeedbackItemSummary(
      menuItemId: menuItemId,
      itemName: itemName,
      category: category,
      totalCount: totalCount,
      averageRating: totalCount > 0 ? ratingSum / totalCount : 0.0,
      issueTypes: cleanedIssues,
    );
  }
}
