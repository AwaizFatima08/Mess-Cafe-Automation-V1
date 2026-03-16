import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/daily_resolved_menu.dart';
import '../../models/resolved_meal_option.dart';

class MenuResolverService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> getMenuForDate(DateTime date) async {
    final cycleQuery = await _firestore
        .collection('menu_cycles')
        .where('active', isEqualTo: true)
        .limit(1)
        .get();

    if (cycleQuery.docs.isEmpty) {
      return null;
    }

    final cycleDoc = cycleQuery.docs.first;
    final cycleData = cycleDoc.data();

    final DateTime? startDate = _toDateTime(cycleData['start_date']);
    final DateTime? endDate = _toDateTime(cycleData['end_date']);

    if (startDate != null && date.isBefore(_startOfDay(startDate))) {
      return null;
    }

    if (endDate != null && date.isAfter(_endOfDay(endDate))) {
      return null;
    }

    final String weekday = _weekdayKey(date.weekday);

    final breakfast = await _resolveTemplateItems(
      cycleData['breakfast_template_id'],
      weekday,
    );

    final lunchCombo1 = await _resolveTemplateItems(
      cycleData['lunch_combo_1_template_id'] ??
          cycleData['lunch_combo1_template_id'],
      weekday,
    );

    final lunchCombo2 = await _resolveTemplateItems(
      cycleData['lunch_combo_2_template_id'] ??
          cycleData['lunch_combo2_template_id'],
      weekday,
    );

    final dinnerCombo1 = await _resolveTemplateItems(
      cycleData['dinner_combo_1_template_id'] ??
          cycleData['dinner_combo1_template_id'],
      weekday,
    );

    final dinnerCombo2 = await _resolveTemplateItems(
      cycleData['dinner_combo_2_template_id'] ??
          cycleData['dinner_combo2_template_id'],
      weekday,
    );

    return {
      'date': date.toIso8601String(),
      'weekday': weekday,
      'cycle_id': cycleDoc.id,
      'cycle_name': cycleData['cycle_name'] ?? '',
      'breakfast': breakfast,
      'lunch_combo_1': lunchCombo1,
      'lunch_combo_2': lunchCombo2,
      'dinner_combo_1': dinnerCombo1,
      'dinner_combo_2': dinnerCombo2,
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
    final lunchCombo1Items = _castItemList(rawMenu['lunch_combo_1']);
    final lunchCombo2Items = _castItemList(rawMenu['lunch_combo_2']);
    final dinnerCombo1Items = _castItemList(rawMenu['dinner_combo_1']);
    final dinnerCombo2Items = _castItemList(rawMenu['dinner_combo_2']);

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
    if (lunchCombo1Items.isNotEmpty) {
      lunchOptions.add(
        _buildOption(
          optionKey: 'lunch_combo_1',
          optionLabel: 'Lunch Combo 1',
          items: lunchCombo1Items,
        ),
      );
    }
    if (lunchCombo2Items.isNotEmpty) {
      lunchOptions.add(
        _buildOption(
          optionKey: 'lunch_combo_2',
          optionLabel: 'Lunch Combo 2',
          items: lunchCombo2Items,
        ),
      );
    }

    final dinnerOptions = <ResolvedMealOption>[];
    if (dinnerCombo1Items.isNotEmpty) {
      dinnerOptions.add(
        _buildOption(
          optionKey: 'dinner_combo_1',
          optionLabel: 'Dinner Combo 1',
          items: dinnerCombo1Items,
        ),
      );
    }
    if (dinnerCombo2Items.isNotEmpty) {
      dinnerOptions.add(
        _buildOption(
          optionKey: 'dinner_combo_2',
          optionLabel: 'Dinner Combo 2',
          items: dinnerCombo2Items,
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
    return ((raw as List?) ?? const []).whereType<Map>().map(
          (e) => Map<String, dynamic>.from(e),
        ).toList();
  }

  Future<List<Map<String, dynamic>>> _resolveTemplateItems(
    dynamic templateId,
    String weekday,
  ) async {
    if (templateId == null || templateId.toString().trim().isEmpty) {
      return [];
    }

    final templateDoc = await _firestore
        .collection('weekly_menu_templates')
        .doc(templateId.toString())
        .get();

    if (!templateDoc.exists) {
      return [];
    }

    final templateData = templateDoc.data();
    if (templateData == null) {
      return [];
    }

    final dynamic rawDayEntries = templateData[weekday];
    final List<Map<String, dynamic>> normalizedEntries =
        _normalizeDayEntries(rawDayEntries);

    if (normalizedEntries.isEmpty) {
      return [];
    }

    final List<String> itemIds = normalizedEntries
        .map((e) => (e['item_id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (itemIds.isEmpty) {
      return [];
    }

    final menuItemsSnapshot = await _firestore
        .collection('menu_items')
        .where(FieldPath.documentId, whereIn: itemIds)
        .get();

    final Map<String, Map<String, dynamic>> itemMap = {
      for (final doc in menuItemsSnapshot.docs)
        doc.id: {
          'item_id': doc.id,
          ...doc.data(),
        }
    };

    final List<Map<String, dynamic>> resolved = [];

    for (final entry in normalizedEntries) {
      final String itemId = (entry['item_id'] ?? '').toString();
      final String itemMode = (entry['item_mode'] ?? 'inclusive').toString();

      if (itemId.isEmpty) continue;

      final itemData = itemMap[itemId];
      if (itemData == null) continue;

      resolved.add({
        ...itemData,
        'item_mode': itemMode,
      });
    }

    return resolved;
  }

  List<Map<String, dynamic>> _normalizeDayEntries(dynamic rawDayEntries) {
    if (rawDayEntries == null || rawDayEntries is! List) {
      return [];
    }

    final List<Map<String, dynamic>> normalized = [];

    for (final entry in rawDayEntries) {
      if (entry is String) {
        if (entry.trim().isEmpty) continue;
        normalized.add({
          'item_id': entry.trim(),
          'item_mode': 'inclusive',
        });
      } else if (entry is Map) {
        final String itemId = (entry['item_id'] ?? '').toString().trim();
        final String itemMode =
            (entry['item_mode'] ?? 'inclusive').toString().trim();

        if (itemId.isEmpty) continue;

        normalized.add({
          'item_id': itemId,
          'item_mode': itemMode.isEmpty ? 'inclusive' : itemMode,
        });
      }
    }

    return normalized;
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

  DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  DateTime _startOfDay(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day);
  }

  DateTime _endOfDay(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day, 23, 59, 59, 999);
  }
}
