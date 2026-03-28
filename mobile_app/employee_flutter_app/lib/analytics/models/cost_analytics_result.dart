class CostAnalyticsResult {
  final double totalCost;
  final double employeeCost;
  final double guestCost;
  final double averageCostPerHead;

  final Map<String, double> mealWiseCost;
  final Map<String, double> dailyCostTrend;

  const CostAnalyticsResult({
    required this.totalCost,
    required this.employeeCost,
    required this.guestCost,
    required this.averageCostPerHead,
    required this.mealWiseCost,
    required this.dailyCostTrend,
  });

  factory CostAnalyticsResult.empty() {
    return const CostAnalyticsResult(
      totalCost: 0,
      employeeCost: 0,
      guestCost: 0,
      averageCostPerHead: 0,
      mealWiseCost: {
        'breakfast': 0,
        'lunch': 0,
        'dinner': 0,
      },
      dailyCostTrend: {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalCost': totalCost,
      'employeeCost': employeeCost,
      'guestCost': guestCost,
      'averageCostPerHead': averageCostPerHead,
      'mealWiseCost': mealWiseCost,
      'dailyCostTrend': dailyCostTrend,
    };
  }
}
