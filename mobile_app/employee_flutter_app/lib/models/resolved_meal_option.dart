import 'package:flutter/foundation.dart';

class ResolvedMealOption {
  final String optionKey;
  final String optionLabel;
  final List<Map<String, dynamic>> items;

  const ResolvedMealOption({
    required this.optionKey,
    required this.optionLabel,
    required this.items,
  });

  ResolvedMealOption copyWith({
    String? optionKey,
    String? optionLabel,
    List<Map<String, dynamic>>? items,
  }) {
    return ResolvedMealOption(
      optionKey: optionKey ?? this.optionKey,
      optionLabel: optionLabel ?? this.optionLabel,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'option_key': optionKey,
      'option_label': optionLabel,
      'items': items.map((item) => Map<String, dynamic>.from(item)).toList(),
    };
  }

  factory ResolvedMealOption.fromMap(Map<String, dynamic> map) {
    final List<dynamic> rawItems = (map['items'] as List<dynamic>?) ?? const <dynamic>[];

    return ResolvedMealOption(
      optionKey: (map['option_key'] ?? '').toString().trim(),
      optionLabel: (map['option_label'] ?? '').toString().trim(),
      items: rawItems
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(),
    );
  }

  @override
  String toString() {
    return 'ResolvedMealOption('
        'optionKey: $optionKey, '
        'optionLabel: $optionLabel, '
        'items: $items'
        ')';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ResolvedMealOption &&
        other.optionKey == optionKey &&
        other.optionLabel == optionLabel &&
        listEquals(other.items, items);
  }

  @override
  int get hashCode {
    return Object.hash(
      optionKey,
      optionLabel,
      Object.hashAll(items),
    );
  }
}
