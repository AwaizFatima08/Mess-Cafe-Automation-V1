import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/daily_resolved_menu.dart';
import '../../models/resolved_meal_option.dart';

class MenuResolverService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> getMenuForDate(DateTime date) async {
    final cycleQuery = await _firestore
        .collection('menu_cycles')
        .where('is_active', isEqualTo: true)
        .limit(20)
        .get();

    if (cycleQuery.docs.isEmpty) {
      return null;
    }

    final targetDate = _startOfDay(date);

    QueryDocumentSnapshot<Map<String, dynamic>>? matchedCycle;

    for (final doc in cycleQuery.docs) {
      final data = doc.data();

      final startDate = _toDateTime(data['start_date']);
      final endDate = _toDateTime(data['end_date']);

      if (startDate != null && targetDate.isBefore(_startOfDay(startDate))) {
        continue;
      }

      if (endDate != null && targetDate.isAfter(_endOfDay(endDate))) {
        continue;
      }

      matchedCycle = doc;
      break;
    }

    if (matchedCycle == null) {
      return null;
    }

    final cycleData = matchedCycle.data();
    final weekday = _weekdayKey(date.weekday);

    final breakfastTemplateId =
        (cycleData['breakfast_template_id'] ?? '').toString().trim();

    final lunchTemplate1Id =
        (cycleData['lunch_template_1_id'] ?? '').toString().trim();

    final lunchTemplate2Id =
        (cycleData['lunch_template_2_id'] ?? '').toString().trim();

    final dinnerTemplate1Id =
        (cycleData['dinner_template_1_id'] ?? '').toString().trim();

    final dinnerTemplate2Id =
        (cycleData['dinner_template_2_id'] ?? '').toString().trim();

    final breakfast = await _resolveTemplateItems(breakfastTemplateId, weekday);
    final lunch1 = await _resolveTemplateItems(lunchTemplate1Id, weekday);
    final lunch2 = await _resolveTemplateItems(lunchTemplate2Id, weekday);
    final dinner1 = await _resolveTemplateItems(dinnerTemplate1Id, weekday);
    final dinner2 = await _resolveTemplateItems(dinnerTemplate2Id, weekday);

    return {
      'date': date.toIso8601String(),
      'weekday': weekday,
      'cycle_id': matchedCycle.id,
      'cycle_name': (cycleData['cycle_name'] ?? '').toString(),
      'breakfast': breakfast,
      'lunch_template_1': lunch1,
      'lunch_template_2': lunch2,
      'dinner_template_1': dinner1,
      'dinner_template_2': dinner2,
    };
  }

  Future<DailyResolvedMenu?> getBookingMenuForDate(DateTime date) async {
    final rawMenu = await getMenuForDate(date);

    if (rawMenu == null) {
      return null;
    }

    final weekday = (rawMenu['weekday'] ?? '').toString();
    final cycleName = (rawMenu['cycle_name'] ?? '').toString();

    final breakfastItems = _castItemList(rawMenu['breakfast']);
    final lunchTemplate1Items = _castItemList(rawMenu['lunch_template_1']);
    final lunchTemplate2Items = _castItemList(rawMenu['lunch_template_2']);
    final dinnerTemplate1Items = _castItemList(rawMenu['dinner_template_1']);
    final dinnerTemplate2Items = _castItemList(rawMenu['dinner_template_2']);

    final breakfastOptions = <ResolvedMealOption>[];
    if (breakfastItems.isNotEmpty) {
      breakfastOptions.add(
        _buildOption(
          optionKey: 'breakfast_option_1',
          optionLabel: 'Breakfast',
          items: breakfastItems,
        ),
      );
    }

    final lunchOptions = <ResolvedMealOption>[];
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

    final dinnerOptions = <ResolvedMealOption>[];
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

    return DailyResolvedMenu(
      weekday: weekday,
      cycleName: cycleName,
      breakfastOptions: breakfastOptions,
      lunchOptions: lunchOptions,
      dinnerOptions: dinnerOptions,
    );
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
    return ((raw as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> _resolveTemplateItems(
    String? templateId,
    String weekday,
  ) async {
    if (templateId == null || templateId.trim().isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final templateDoc = await _firestore
        .collection('weekly_menu_templates')
        .doc(templateId.trim())
        .get();

    if (!templateDoc.exists || templateDoc.data() == null) {
      return <Map<String, dynamic>>[];
    }

    final templateData = templateDoc.data()!;
    final rawItemIds = templateData[weekday];

    if (rawItemIds is! List || rawItemIds.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final itemIds = rawItemIds
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final resolvedItems = <Map<String, dynamic>>[];

    for (final itemId in itemIds) {
      final itemDoc =
          await _firestore.collection('menu_items').doc(itemId).get();

      if (!itemDoc.exists || itemDoc.data() == null) {
        continue;
      }

      final itemData = itemDoc.data()!;
      final isActive = itemData['is_active'] == true ||
          (itemData['status'] ?? '').toString().trim().toLowerCase() == 'active';

      if (!isActive) {
        continue;
      }

      resolvedItems.add({
        'item_id': itemDoc.id,
        'item_name': (itemData['item_name'] ?? itemDoc.id).toString(),
        'category': (itemData['category'] ?? 'other').toString(),
        'estimated_price': itemData['estimated_price'] ?? 0,
      });
    }

    return resolvedItems;
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
}
