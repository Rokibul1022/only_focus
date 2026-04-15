import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/article.dart';
import '../../core/constants/api_endpoints.dart';

class NewsApiSource {
  final Dio _dio = Dio();
  
  Future<List<Article>> fetchTopHeadlines({
    String category = 'technology',
    String country = 'us',
    int limit = 20,
  }) async {
    try {
      final response = await _dio.get(
        '${ApiEndpoints.newsApiBase}/top-headlines',
        queryParameters: {
          'apiKey': ApiEndpoints.newsApiKey,
          'category': category,
          'country': country,
          'pageSize': limit,
        },
      );
      
      final articles = (response.data['articles'] as List)
          .map((json) => _parseNewsApiArticle(json, category))
          .where((article) => article != null)
          .cast<Article>()
          .toList();
      
      return articles;
    } catch (e) {
      throw Exception('Failed to fetch NewsAPI articles: $e');
    }
  }
  
  Article? _parseNewsApiArticle(Map<String, dynamic> json, String category) {
    try {
      final url = json['url']?.toString();
      if (url == null || url.isEmpty) return null;
      
      final title = json['title']?.toString() ?? 'Untitled';
      final description = json['description']?.toString() ?? '';
      final content = json['content']?.toString() ?? description;
      final imageUrl = json['urlToImage']?.toString();
      final publishedAt = json['publishedAt']?.toString();
      final source = json['source']?['name']?.toString() ?? 'NewsAPI';
      
      final articleId = _generateArticleId(url);
      
      // Estimate reading time
      final wordCount = (content.isNotEmpty ? content : description).split(' ').length;
      final readingMinutes = (wordCount / 238).ceil().clamp(2, 30);
      
      // Map category
      final mappedCategory = category == 'science' ? 'Science' : 'Technology';
      final contentType = category == 'science' ? 'science' : 'tech_news';
      
      final article = Article()
        ..id = articleId
        ..title = title
        ..sourceUrl = url
        ..sourceName = source
        ..imageUrl = imageUrl
        ..contentType = contentType
        ..category = mappedCategory
        ..publishedAt = publishedAt != null ? DateTime.parse(publishedAt) : DateTime.now()
        ..fetchedAt = DateTime.now()
        ..estimatedReadingMinutes = readingMinutes
        ..summary = description
        ..parsedContent = content
        ..tags = ['news', category];
      
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
