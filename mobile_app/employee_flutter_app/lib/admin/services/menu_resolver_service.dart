import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/daily_resolved_menu.dart';
import '../../models/resolved_meal_option.dart';

class MenuResolverService {
  MenuResolverService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  final Map<String, Map<String, dynamic>?> _rawMenuCacheByDate = {};
  final Map<String, DailyResolvedMenu?> _bookingMenuCacheByDate = {};
  final Map<String, Map<String, dynamic>?> _templateCacheById = {};
  final Map<String, Map<String, dynamic>?> _menuItemCacheById = {};

  Future<Map<String, dynamic>?> getMenuForDate(
    DateTime date, {
    bool forceRefresh = false,
  }) async {
    final cacheKey = _dateCacheKey(date);

    if (!forceRefresh && _rawMenuCacheByDate.containsKey(cacheKey)) {
      return _rawMenuCacheByDate[cacheKey];
    }

    final QuerySnapshot<Map<String, dynamic>> cycleQuery = await _firestore
        .collection('menu_cycles')
        .where('is_active', isEqualTo: true)
        .limit(20)
        .get();

    if (cycleQuery.docs.isEmpty) {
      _rawMenuCacheByDate[cacheKey] = null;
      return null;
    }

    final DateTime targetDate = _startOfDay(date);
    final QueryDocumentSnapshot<Map<String, dynamic>>? matchedCycle =
        _pickBestMatchingCycle(
      docs: cycleQuery.docs,
      targetDate: targetDate,
    );

    if (matchedCycle == null) {
      _rawMenuCacheByDate[cacheKey] = null;
      return null;
    }

    final Map<String, dynamic> cycleData = matchedCycle.data();
    final String weekday = _weekdayKey(targetDate.weekday);

    final String breakfastTemplateId =
        _readTemplateId(cycleData, const <String>[
      'breakfast_template_id',
      'breakfast_template',
    ]);

    final String lunchTemplate1Id =
        _readTemplateId(cycleData, const <String>[
      'lunch_template_1_id',
      'lunch_template_1',
    ]);

    final String lunchTemplate2Id =
        _readTemplateId(cycleData, const <String>[
      'lunch_template_2_id',
      'lunch_template_2',
    ]);

    final String dinnerTemplate1Id =
        _readTemplateId(cycleData, const <String>[
      'dinner_template_1_id',
      'dinner_template_1',
    ]);

    final String dinnerTemplate2Id =
        _readTemplateId(cycleData, const <String>[
      'dinner_template_2_id',
      'dinner_template_2',
    ]);

    final List<List<Map<String, dynamic>>> futures =
        await Future.wait<List<Map<String, dynamic>>>(<Future<List<Map<String, dynamic>>>>[
      _resolveTemplateItems(
        templateId: breakfastTemplateId,
        weekday: weekday,
        expectedMealType: 'breakfast',
        forceRefresh: forceRefresh,
      ),
      _resolveTemplateItems(
        templateId: lunchTemplate1Id,
        weekday: weekday,
        expectedMealType: 'lunch',
        forceRefresh: forceRefresh,
      ),
      _resolveTemplateItems(
        templateId: lunchTemplate2Id,
        weekday: weekday,
        expectedMealType: 'lunch',
        forceRefresh: forceRefresh,
      ),
      _resolveTemplateItems(
        templateId: dinnerTemplate1Id,
        weekday: weekday,
        expectedMealType: 'dinner',
        forceRefresh: forceRefresh,
      ),
      _resolveTemplateItems(
        templateId: dinnerTemplate2Id,
        weekday: weekday,
        expectedMealType: 'dinner',
        forceRefresh: forceRefresh,
      ),
    ]);

    final Map<String, dynamic> rawMenu = <String, dynamic>{
      'date': targetDate.toIso8601String(),
      'weekday': weekday,
      'cycle_id': matchedCycle.id,
      'cycle_name': (cycleData['cycle_name'] ?? cycleData['name'] ?? '')
          .toString()
          .trim(),
      'breakfast': futures[0],
      'lunch_template_1': futures[1],
      'lunch_template_2': futures[2],
      'dinner_template_1': futures[3],
      'dinner_template_2': futures[4],
    };

    _rawMenuCacheByDate[cacheKey] = rawMenu;
    return rawMenu;
  }

  Future<DailyResolvedMenu?> getBookingMenuForDate(
    DateTime date, {
    bool forceRefresh = false,
  }) async {
    final String cacheKey = _dateCacheKey(date);

    if (!forceRefresh && _bookingMenuCacheByDate.containsKey(cacheKey)) {
      return _bookingMenuCacheByDate[cacheKey];
    }

    final Map<String, dynamic>? rawMenu = await getMenuForDate(
      date,
      forceRefresh: forceRefresh,
    );

    if (rawMenu == null) {
      _bookingMenuCacheByDate[cacheKey] = null;
      return null;
    }

    final String weekday = (rawMenu['weekday'] ?? '').toString().trim();
    final String cycleName = (rawMenu['cycle_name'] ?? '').toString().trim();

    final List<Map<String, dynamic>> breakfastItems =
        _castItemList(rawMenu['breakfast']);
    final List<Map<String, dynamic>> lunchTemplate1Items =
        _castItemList(rawMenu['lunch_template_1']);
    final List<Map<String, dynamic>> lunchTemplate2Items =
        _castItemList(rawMenu['lunch_template_2']);
    final List<Map<String, dynamic>> dinnerTemplate1Items =
        _castItemList(rawMenu['dinner_template_1']);
    final List<Map<String, dynamic>> dinnerTemplate2Items =
        _castItemList(rawMenu['dinner_template_2']);

    final List<ResolvedMealOption> breakfastOptions = <ResolvedMealOption>[];
    if (breakfastItems.isNotEmpty) {
      breakfastOptions.add(
        _buildOption(
          optionKey: 'breakfast_option_1',
          optionLabel: 'Breakfast',
          items: breakfastItems,
        ),
      );
    }

    final List<ResolvedMealOption> lunchOptions = <ResolvedMealOption>[];
    if (lunchTemplate1Items.isNotEmpty) {
      lunchOptions.add(
        _buildOption(
          optionKey: 'lunch_template_1',
          optionLabel: 'Lunch Option 1',
          items: lunchTemplate1Items,
        ),
      );
    }
    if (lunchTemplate2Items.isNotEmpty) {
      lunchOptions.add(
        _buildOption(
          optionKey: 'lunch_template_2',
          optionLabel: 'Lunch Option 2',
          items: lunchTemplate2Items,
        ),
      );
    }

    final List<ResolvedMealOption> dinnerOptions = <ResolvedMealOption>[];
    if (dinnerTemplate1Items.isNotEmpty) {
      dinnerOptions.add(
        _buildOption(
          optionKey: 'dinner_template_1',
          optionLabel: 'Dinner Option 1',
          items: dinnerTemplate1Items,
        ),
      );
    }
    if (dinnerTemplate2Items.isNotEmpty) {
      dinnerOptions.add(
        _buildOption(
          optionKey: 'dinner_template_2',
          optionLabel: 'Dinner Option 2',
          items: dinnerTemplate2Items,
        ),
      );
    }

    final DailyResolvedMenu resolvedMenu = DailyResolvedMenu(
      weekday: weekday,
      cycleName: cycleName,
      breakfastOptions: breakfastOptions,
      lunchOptions: lunchOptions,
      dinnerOptions: dinnerOptions,
    );

    _bookingMenuCacheByDate[cacheKey] = resolvedMenu;
    return resolvedMenu;
  }

  void clearAllCaches() {
    _rawMenuCacheByDate.clear();
    _bookingMenuCacheByDate.clear();
    _templateCacheById.clear();
    _menuItemCacheById.clear();
  }

  void clearDateCache(DateTime date) {
    final String key = _dateCacheKey(date);
    _rawMenuCacheByDate.remove(key);
    _bookingMenuCacheByDate.remove(key);
  }

  ResolvedMealOption _buildOption({
    required String optionKey,
    required String optionLabel,
    required List<Map<String, dynamic>> items,
  }) {
    return ResolvedMealOption(
      optionKey: optionKey,
      optionLabel: optionLabel,
      items: items,
    );
  }

  List<Map<String, dynamic>> _castItemList(dynamic raw) {
    return ((raw as List?) ?? const <dynamic>[])
        .whereType<Map>()
        .map((Map<dynamic, dynamic> e) => Map<String, dynamic>.from(e))
        .toList();
  }

  QueryDocumentSnapshot<Map<String, dynamic>>? _pickBestMatchingCycle({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required DateTime targetDate,
  }) {
    QueryDocumentSnapshot<Map<String, dynamic>>? bestDoc;
    DateTime? bestStartDate;

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in docs) {
      final Map<String, dynamic> data = doc.data();

      final DateTime? startDate = _toDateTime(data['start_date']);
      final DateTime? endDate = _toDateTime(data['end_date']);

      if (startDate != null && targetDate.isBefore(_startOfDay(startDate))) {
        continue;
      }

      if (endDate != null && targetDate.isAfter(_endOfDay(endDate))) {
        continue;
      }

      if (bestDoc == null) {
        bestDoc = doc;
        bestStartDate = startDate;
        continue;
      }

      if (bestStartDate == null && startDate != null) {
        bestDoc = doc;
        bestStartDate = startDate;
        continue;
      }

      if (startDate != null &&
          bestStartDate != null &&
          _startOfDay(startDate).isAfter(_startOfDay(bestStartDate))) {
        bestDoc = doc;
        bestStartDate = startDate;
      }
    }

    return bestDoc;
  }

  String _readTemplateId(
    Map<String, dynamic> source,
    List<String> candidateKeys,
  ) {
    for (final String key in candidateKeys) {
      final String value = (source[key] ?? '').toString().trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  Future<List<Map<String, dynamic>>> _resolveTemplateItems({
    required String templateId,
    required String weekday,
    required String expectedMealType,
    required bool forceRefresh,
  }) async {
    if (templateId.trim().isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final String trimmedTemplateId = templateId.trim();

    Map<String, dynamic>? templateData;
    if (!forceRefresh && _templateCacheById.containsKey(trimmedTemplateId)) {
      templateData = _templateCacheById[trimmedTemplateId];
    } else {
      final DocumentSnapshot<Map<String, dynamic>> templateDoc = await _firestore
          .collection('weekly_menu_templates')
          .doc(trimmedTemplateId)
          .get();

      if (!templateDoc.exists || templateDoc.data() == null) {
        _templateCacheById[trimmedTemplateId] = null;
        return <Map<String, dynamic>>[];
      }

      templateData = Map<String, dynamic>.from(templateDoc.data()!);
      _templateCacheById[trimmedTemplateId] = templateData;
    }

    if (templateData == null) {
      return <Map<String, dynamic>>[];
    }

    final List<String> itemIds = _extractTemplateItemIds(
      templateData: templateData,
      weekday: weekday,
    );

    if (itemIds.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final List<Map<String, dynamic>> resolvedItems = <Map<String, dynamic>>[];

    for (final String itemId in itemIds) {
      Map<String, dynamic>? itemData;

      if (!forceRefresh && _menuItemCacheById.containsKey(itemId)) {
        itemData = _menuItemCacheById[itemId];
      } else {
        final DocumentSnapshot<Map<String, dynamic>> itemDoc =
            await _firestore.collection('menu_items').doc(itemId).get();

        if (!itemDoc.exists || itemDoc.data() == null) {
          _menuItemCacheById[itemId] = null;
          continue;
        }

        itemData = Map<String, dynamic>.from(itemDoc.data()!);
        _menuItemCacheById[itemId] = itemData;
      }

      if (itemData == null) {
        continue;
      }

      if (!_isMenuItemActive(itemData)) {
        continue;
      }

      final Map<String, dynamic> normalizedItem = _normalizeMenuItem(
        itemId: itemId,
        itemData: itemData,
        expectedMealType: expectedMealType,
      );

      final String resolvedMealType =
          (normalizedItem['meal_type'] ?? '').toString().trim().toLowerCase();

      if (resolvedMealType.isNotEmpty &&
          resolvedMealType != expectedMealType.toLowerCase()) {
        continue;
      }

      resolvedItems.add(normalizedItem);
    }

    return resolvedItems;
  }

  List<String> _extractTemplateItemIds({
    required Map<String, dynamic> templateData,
    required String weekday,
  }) {
    final dynamic directWeekdayValue = templateData[weekday];
    final List<String> directIds = _stringListFromDynamic(directWeekdayValue);
    if (directIds.isNotEmpty) {
      return directIds;
    }

    final dynamic weekdayMenus = templateData['weekday_menus'];
    if (weekdayMenus is Map) {
      final List<String> nestedIds =
          _stringListFromDynamic(weekdayMenus[weekday]);
      if (nestedIds.isNotEmpty) {
        return nestedIds;
      }
    }

    final dynamic days = templateData['days'];
    if (days is Map) {
      final List<String> nestedIds =
          _stringListFromDynamic(days[weekday]);
      if (nestedIds.isNotEmpty) {
        return nestedIds;
      }
    }

    return <String>[];
  }

  List<String> _stringListFromDynamic(dynamic raw) {
    if (raw is! List) {
      return <String>[];
    }

    return raw
        .map((dynamic e) => e.toString().trim())
        .where((String e) => e.isNotEmpty)
        .toList();
  }

  bool _isMenuItemActive(Map<String, dynamic> itemData) {
    final bool activeFlag = itemData['is_active'] == true;
    final String status =
        (itemData['status'] ?? '').toString().trim().toLowerCase();

    return activeFlag || status == 'active';
  }

  Map<String, dynamic> _normalizeMenuItem({
    required String itemId,
    required Map<String, dynamic> itemData,
    required String expectedMealType,
  }) {
    final String itemName = _readFirstNonEmptyString(itemData, const <String>[
      'item_name',
      'name',
      'title',
    ], fallback: itemId);

    final String mealType = _readFirstNonEmptyString(itemData, const <String>[
      'meal_type',
      'mealType',
      'category',
    ], fallback: expectedMealType).toLowerCase();

    final String foodType = _readFirstNonEmptyString(itemData, const <String>[
      'food_type',
      'foodType',
      'type',
    ], fallback: '');

    return <String, dynamic>{
      'item_id': itemId,
      'item_name': itemName,
      'meal_type': mealType,
      'food_type': foodType,
      'estimated_price': _readNumeric(itemData['estimated_price']),
    };
  }

  String _readFirstNonEmptyString(
    Map<String, dynamic> source,
    List<String> candidateKeys, {
    required String fallback,
  }) {
    for (final String key in candidateKeys) {
      final String value = (source[key] ?? '').toString().trim();
      if (value.isNotEmpty) {
        return value;
      }
    }
    return fallback;
  }

  num _readNumeric(dynamic value) {
    if (value is num) {
      return value;
    }

    if (value is String) {
      final num? parsed = num.tryParse(value.trim());
      if (parsed != null) {
        return parsed;
      }
    }

    return 0;
  }

  DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  DateTime _startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
  }

  String _weekdayKey(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'monday';
      case DateTime.tuesday:
        return 'tuesday';
      case DateTime.wednesday:
        return 'wednesday';
      case DateTime.thursday:
        return 'thursday';
      case DateTime.friday:
        return 'friday';
      case DateTime.saturday:
        return 'saturday';
      case DateTime.sunday:
        return 'sunday';
      default:
        return 'monday';
    }
  }

  String _dateCacheKey(DateTime date) {
    final DateTime normalized = _startOfDay(date);
    return '${normalized.year.toString().padLeft(4, '0')}-'
        '${normalized.month.toString().padLeft(2, '0')}-'
        '${normalized.day.toString().padLeft(2, '0')}';
  }
}
