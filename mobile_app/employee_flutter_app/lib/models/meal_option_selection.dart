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
    return <String, dynamic>{
      'option_key': optionKey,
      'option_label': optionLabel,
      'quantity': quantity,
    };
  }

  factory MealOptionSelection.fromMap(Map<String, dynamic> map) {
    final dynamic rawQuantity = map['quantity'];

    int parsedQuantity = 0;
    if (rawQuantity is num) {
      parsedQuantity = rawQuantity.toInt();
    } else if (rawQuantity is String) {
      parsedQuantity = int.tryParse(rawQuantity.trim()) ?? 0;
    }

    return MealOptionSelection(
      optionKey: (map['option_key'] ?? '').toString().trim(),
      optionLabel: (map['option_label'] ?? '').toString().trim(),
      quantity: parsedQuantity < 0 ? 0 : parsedQuantity,
    );
  }

  @override
  String toString() {
    return 'MealOptionSelection('
        'optionKey: $optionKey, '
        'optionLabel: $optionLabel, '
        'quantity: $quantity'
        ')';
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
    return Object.hash(optionKey, optionLabel, quantity);
  }
}
