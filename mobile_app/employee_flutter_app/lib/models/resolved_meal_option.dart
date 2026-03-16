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
    return {
      'option_key': optionKey,
      'option_label': optionLabel,
      'items': items,
    };
  }

  factory ResolvedMealOption.fromMap(Map<String, dynamic> map) {
    final rawItems = (map['items'] as List<dynamic>?) ?? const [];

    return ResolvedMealOption(
      optionKey: (map['option_key'] ?? '').toString(),
      optionLabel: (map['option_label'] ?? '').toString(),
      items: rawItems
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(),
    );
  }

  @override
  String toString() {
    return 'ResolvedMealOption(optionKey: $optionKey, optionLabel: $optionLabel, items: $items)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ResolvedMealOption &&
        other.optionKey == optionKey &&
        other.optionLabel == optionLabel;
  }

  @override
  int get hashCode {
    return optionKey.hashCode ^ optionLabel.hashCode;
  }
}
