class MealOptionSelection {
  final String optionKey;
  final String optionLabel;
  final int quantity;

  const MealOptionSelection({
    required this.optionKey,
    required this.optionLabel,
    required this.quantity,
  });

  MealOptionSelection copyWith({
    String? optionKey,
    String? optionLabel,
    int? quantity,
  }) {
    return MealOptionSelection(
      optionKey: optionKey ?? this.optionKey,
      optionLabel: optionLabel ?? this.optionLabel,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'option_key': optionKey,
      'option_label': optionLabel,
      'quantity': quantity,
    };
  }

  factory MealOptionSelection.fromMap(Map<String, dynamic> map) {
    return MealOptionSelection(
      optionKey: (map['option_key'] ?? '').toString(),
      optionLabel: (map['option_label'] ?? '').toString(),
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  String toString() {
    return 'MealOptionSelection(optionKey: $optionKey, optionLabel: $optionLabel, quantity: $quantity)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MealOptionSelection &&
        other.optionKey == optionKey &&
        other.optionLabel == optionLabel &&
        other.quantity == quantity;
  }

  @override
  int get hashCode {
    return optionKey.hashCode ^ optionLabel.hashCode ^ quantity.hashCode;
  }
}
