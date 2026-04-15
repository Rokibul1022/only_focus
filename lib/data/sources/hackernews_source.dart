import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/article.dart';
import '../../core/constants/api_endpoints.dart';

class HackerNewsSource {
  final Dio _dio = Dio();
  
  Future<List<Article>> fetchTopStories({int limit = 30}) async {
    try {
      // Fetch top story IDs
      final response = await _dio.get('${ApiEndpoints.hackerNewsBase}/topstories.json');
      final List<int> storyIds = List<int>.from(response.data.take(limit));
      
      // Fetch details for each story
      final List<Article> articles = [];
      for (final id in storyIds) {
        try {
          final article = await _fetchStoryDetails(id);
          if (article != null) {
            articles.add(article);
          }
        } catch (e) {
          // Skip failed stories
          continue;
        }
      }
      
      return articles;
    } catch (e) {
      throw Exception('Failed to fetch Hacker News stories: $e');
    }
  }
  
  Future<Article?> _fetchStoryDetails(int id) async {
    try {
      final response = await _dio.get('${ApiEndpoints.hackerNewsBase}/item/$id.json');
      final data = response.data;
      
      // Skip stories without URL (Ask HN, Show HN without links)
      if (data['url'] == null || data['url'].toString().isEmpty) {
        return null;
      }
      
      final url = data['url'].toString();
      final articleId = _generateArticleId(url);
      
      // Estimate reading time (assume 238 WPM)
      final wordCount = (data['title']?.toString().split(' ').length ?? 0) * 50; // Rough estimate
      final readingMinutes = (wordCount / 238).ceil().clamp(1, 60);
      
      final article = Article()
        ..id = articleId
        ..title = data['title'] ?? 'Untitled'
        ..sourceUrl = url
        ..sourceName = 'Hacker News'
        ..contentType = 'tech_news'
        ..category = 'Technology'
        ..publishedAt = DateTime.fromMillisecondsSinceEpoch((data['time'] ?? 0) * 1000)
        ..fetchedAt = DateTime.now()
        ..estimatedReadingMinutes = readingMinutes
        ..tags = ['tech', 'hacker-news'];
      
      return article;
    } catch (e) {
      return null;
    }
  }
  
  String _generateArticleId(String url) {
    final bytes = utf8.encode(url);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }
}
