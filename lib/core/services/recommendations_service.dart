import 'package:dio/dio.dart';
import '../constants/api_endpoints.dart';
import '../../data/models/article.dart';

class RecommendationsService {
  final Dio _dio = Dio();
  
  // Get AI-powered recommendations based on reading history
  Future<List<String>> getRecommendations({
    required List<Article> readArticles,
    required List<String> interests,
  }) async {
    try {
      final readTitles = readArticles.take(10).map((a) => a.title).join(', ');
      final interestsStr = interests.join(', ');
      
      final response = await _dio.post(
        '${ApiEndpoints.groqApiBase}/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer ${ApiEndpoints.groqApiKeys.first}',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'model': 'llama-3.3-70b-versatile',
          'messages': [
            {
              'role': 'system',
              'content': 'You are a smart content recommendation engine. Based on user reading history and interests, suggest 5 specific article topics they would enjoy. Return ONLY a comma-separated list of topics, nothing else.',
            },
            {
              'role': 'user',
              'content': 'Recently read: $readTitles. Interests: $interestsStr. Suggest 5 article topics.',
            },
          ],
          'temperature': 0.7,
          'max_tokens': 200,
        },
      );
      
      final content = response.data['choices'][0]['message']['content'] as String;
      return content.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    } catch (e) {
      print('Recommendations error: $e');
      return [];
    }
  }
  
  // Find similar articles based on content
  Future<List<Article>> findSimilarArticles({
    required Article article,
    required List<Article> allArticles,
  }) async {
    final similar = <Article>[];
    
    // Simple similarity: match by category and keywords
    for (final other in allArticles) {
      if (other.id == article.id) continue;
      
      int score = 0;
      
      // Same category
      if (other.category == article.category) score += 3;
      
      // Similar keywords in title
      final articleWords = article.title.toLowerCase().split(' ');
      final otherWords = other.title.toLowerCase().split(' ');
      for (final word in articleWords) {
        if (word.length > 4 && otherWords.contains(word)) {
          score += 1;
        }
      }
      
      if (score >= 2) {
        similar.add(other);
      }
    }
    
    // Sort by score and return top 5
    return similar.take(5).toList();
  }
  
  // Get trending topics based on user interests
  Future<List<String>> getTrendingTopics(List<String> interests) async {
    try {
      final interestsStr = interests.join(', ');
      
      final response = await _dio.post(
        '${ApiEndpoints.groqApiBase}/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer ${ApiEndpoints.groqApiKeys.first}',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'model': 'llama-3.3-70b-versatile',
          'messages': [
            {
              'role': 'system',
              'content': 'You are a tech and science trend analyst. List 5 currently trending topics in the given fields. Return ONLY a comma-separated list, nothing else.',
            },
            {
              'role': 'user',
              'content': 'What are trending topics in: $interestsStr',
            },
          ],
          'temperature': 0.8,
          'max_tokens': 150,
        },
      );
      
      final content = response.data['choices'][0]['message']['content'] as String;
      return content.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    } catch (e) {
      print('Trending topics error: $e');
      return [];
    }
  }
}
