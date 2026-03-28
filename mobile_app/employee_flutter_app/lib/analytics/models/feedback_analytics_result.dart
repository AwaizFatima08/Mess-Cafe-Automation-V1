class FeedbackAnalyticsResult {
  final int totalResponses;
  final double averageRating;

  final Map<int, int> ratingDistribution;
  final Map<String, int> dailyFeedbackTrend;
  final Map<String, int> mealWiseResponseCount;

  const FeedbackAnalyticsResult({
    required this.totalResponses,
    required this.averageRating,
    required this.ratingDistribution,
    required this.dailyFeedbackTrend,
    required this.mealWiseResponseCount,
  });

  factory FeedbackAnalyticsResult.empty() {
    return const FeedbackAnalyticsResult(
      totalResponses: 0,
      averageRating: 0,
      ratingDistribution: {
        1: 0,
        2: 0,
        3: 0,
        4: 0,
        5: 0,
      },
      dailyFeedbackTrend: {},
      mealWiseResponseCount: {
        'breakfast': 0,
        'lunch': 0,
        'dinner': 0,
      },
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalResponses': totalResponses,
      'averageRating': averageRating,
      'ratingDistribution': ratingDistribution,
      'dailyFeedbackTrend': dailyFeedbackTrend,
      'mealWiseResponseCount': mealWiseResponseCount,
    };
  }
}
