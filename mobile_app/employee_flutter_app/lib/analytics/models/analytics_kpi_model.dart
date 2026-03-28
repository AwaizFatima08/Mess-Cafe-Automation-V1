class AnalyticsKpiModel {
  final String title;
  final String value;
  final String? subtitle;
  final String? trendLabel;
  final bool isPositiveTrend;

  const AnalyticsKpiModel({
    required this.title,
    required this.value,
    this.subtitle,
    this.trendLabel,
    this.isPositiveTrend = true,
  });

  AnalyticsKpiModel copyWith({
    String? title,
    String? value,
    String? subtitle,
    String? trendLabel,
    bool? isPositiveTrend,
  }) {
    return AnalyticsKpiModel(
      title: title ?? this.title,
      value: value ?? this.value,
      subtitle: subtitle ?? this.subtitle,
      trendLabel: trendLabel ?? this.trendLabel,
      isPositiveTrend: isPositiveTrend ?? this.isPositiveTrend,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'value': value,
      'subtitle': subtitle,
      'trendLabel': trendLabel,
      'isPositiveTrend': isPositiveTrend,
    };
  }

  factory AnalyticsKpiModel.fromMap(Map<String, dynamic> map) {
    return AnalyticsKpiModel(
      title: (map['title'] ?? '').toString(),
      value: (map['value'] ?? '').toString(),
      subtitle: map['subtitle']?.toString(),
      trendLabel: map['trendLabel']?.toString(),
      isPositiveTrend: map['isPositiveTrend'] as bool? ?? true,
    );
  }

  @override
  String toString() {
    return 'AnalyticsKpiModel('
        'title: $title, '
        'value: $value, '
        'subtitle: $subtitle, '
        'trendLabel: $trendLabel, '
        'isPositiveTrend: $isPositiveTrend'
        ')';
  }
}
