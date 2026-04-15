class StarCalculator {
  // Get day multiplier based on streak
  static double getDayMultiplier(int streakDays) {
    if (streakDays <= 2) return 1.0;
    if (streakDays <= 6) return 1.2;
    if (streakDays <= 13) return 1.5;
    if (streakDays <= 29) return 1.7;
    return 2.0; // 30+ days
  }
  
  // Calculate stars for article read (client-side preview only)
  static int calculateArticleStars({
    required String contentType,
    required int streakDays,
    required bool streakActiveToday,
  }) {
    // Base stars
    int baseStars = (contentType == 'research_paper' || contentType == 'science') ? 10 : 5;
    
    // Apply multiplier
    double multiplier = getDayMultiplier(streakDays);
    
    // Streak bonus
    int streakBonus = streakActiveToday ? 3 : 0;
    
    // Final calculation
    int finalStars = (baseStars * multiplier).floor() + streakBonus;
    
    return finalStars;
  }
  
  // Calculate stars for focus session
  static int calculateFocusSessionStars({
    required String sessionType,
    required int streakDays,
  }) {
    int baseStars = sessionType == 'deep_work' ? 8 : 5;
    double multiplier = getDayMultiplier(streakDays);
    return (baseStars * multiplier).floor();
  }
  
  // Get rank from total stars
  static String getRankFromStars(int totalStars) {
    if (totalStars >= 10000) return 'Legend';
    if (totalStars >= 4000) return 'Master';
    if (totalStars >= 1500) return 'Expert';
    if (totalStars >= 500) return 'Scholar';
    if (totalStars >= 100) return 'Reader';
    return 'Novice';
  }
  
  // Get rank index
  static int getRankIndex(String rank) {
    switch (rank) {
      case 'Legend': return 5;
      case 'Master': return 4;
      case 'Expert': return 3;
      case 'Scholar': return 2;
      case 'Reader': return 1;
      default: return 0; // Novice
    }
  }
  
  // Get stars needed for next rank
  static int getStarsForNextRank(int currentStars) {
    if (currentStars < 100) return 100 - currentStars;
    if (currentStars < 500) return 500 - currentStars;
    if (currentStars < 1500) return 1500 - currentStars;
    if (currentStars < 4000) return 4000 - currentStars;
    if (currentStars < 10000) return 10000 - currentStars;
    return 0; // Already at max rank
  }
  
  // Calculate progress to next rank (0.0 to 1.0)
  static double getProgressToNextRank(int currentStars) {
    if (currentStars < 100) return currentStars / 100;
    if (currentStars < 500) return (currentStars - 100) / 400;
    if (currentStars < 1500) return (currentStars - 500) / 1000;
    if (currentStars < 4000) return (currentStars - 1500) / 2500;
    if (currentStars < 10000) return (currentStars - 4000) / 6000;
    return 1.0; // Max rank
  }
}
