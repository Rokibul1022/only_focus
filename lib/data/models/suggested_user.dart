class SuggestedUser {
  final String uid;
  final String displayName;
  final String? photoUrl;
  final String? bio;
  final List<String> categories;
  final int streakDays;
  final String currentRank;
  final int totalStars;
  final bool isOnline;
  final DateTime lastActiveAt;
  final double matchScore;
  final List<String> matchingCategories;

  SuggestedUser({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    this.bio,
    required this.categories,
    required this.streakDays,
    required this.currentRank,
    required this.totalStars,
    required this.isOnline,
    required this.lastActiveAt,
    required this.matchScore,
    required this.matchingCategories,
  });

  int get matchPercentage => (matchScore * 100).round();
}
