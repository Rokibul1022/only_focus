import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';

// Reward service provider
final rewardServiceProvider = Provider<RewardService>((ref) {
  return RewardService();
});

class RewardService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
  // Award stars for reading an article
  Future<ArticleReadResult> awardStarsForArticleRead({
    required String articleId,
    required String contentType,
    required int durationSec,
    required double completionPercent,
    required String title,
    required String source,
  }) async {
    try {
      final result = await _functions.httpsCallable('onArticleRead').call({
        'articleId': articleId,
        'contentType': contentType,
        'durationSec': durationSec,
        'completionPercent': completionPercent,
        'title': title,
        'source': source,
      });
      
      final data = result.data as Map<String, dynamic>;
      
      return ArticleReadResult(
        awarded: data['awarded'] as bool? ?? false,
        starsEarned: data['starsEarned'] as int? ?? 0,
        newTotal: data['newTotal'] as int? ?? 0,
        rankChanged: data['rankChanged'] as bool? ?? false,
        newRank: data['newRank'] as String?,
        streakDays: data['streakDays'] as int? ?? 0,
        reason: data['reason'] as String?,
      );
    } catch (e) {
      print('Error awarding stars: $e');
      return ArticleReadResult(
        awarded: false,
        starsEarned: 0,
        newTotal: 0,
        rankChanged: false,
        reason: 'error',
      );
    }
  }
  
  // Generate AI summary
  Future<AISummaryResult> generateAISummary({
    required String articleId,
    required String articleText,
  }) async {
    try {
      final result = await _functions.httpsCallable('generateAISummary').call({
        'articleId': articleId,
        'articleText': articleText,
      });
      
      final data = result.data as Map<String, dynamic>;
      final summaryList = data['summary'] as List<dynamic>;
      final summary = summaryList
          .map((item) => (item as Map<String, dynamic>)['point'] as String)
          .toList();
      
      return AISummaryResult(
        success: true,
        summary: summary,
        cached: data['cached'] as bool? ?? false,
      );
    } catch (e) {
      print('Error generating summary: $e');
      return AISummaryResult(
        success: false,
        summary: [],
        cached: false,
        error: e.toString(),
      );
    }
  }
}

class ArticleReadResult {
  final bool awarded;
  final int starsEarned;
  final int newTotal;
  final bool rankChanged;
  final String? newRank;
  final int streakDays;
  final String? reason;
  
  ArticleReadResult({
    required this.awarded,
    required this.starsEarned,
    required this.newTotal,
    required this.rankChanged,
    this.newRank,
    this.streakDays = 0,
    this.reason,
  });
}

class AISummaryResult {
  final bool success;
  final List<String> summary;
  final bool cached;
  final String? error;
  
  AISummaryResult({
    required this.success,
    required this.summary,
    required this.cached,
    this.error,
  });
}
