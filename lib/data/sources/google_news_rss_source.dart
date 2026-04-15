import 'package:dio/dio.dart';
import 'package:dart_rss/dart_rss.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/article.dart';
import '../../core/constants/api_endpoints.dart';

class GoogleNewsRssSource {
  final Dio _dio = Dio();
  
  Future<List<Article>> fetchTechNews({int limit = 20}) async {
    try {
      final response = await _dio.get(ApiEndpoints.googleNewsRss);
      final feed = RssFeed.parse(response.data);
      
      final articles = feed.items
          .take(limit)
          .map((item) => _parseRssItem(item))
          .where((article) => article != null)
          .cast<Article>()
          .toList();
      
      return articles;
    } catch (e) {
      throw Exception('Failed to fetch Google News RSS: $e');
    }
  }
  
  Article? _parseRssItem(RssItem item) {
    try {
      final url = item.link;
      if (url == null || url.isEmpty) return null;
      
      final title = item.title ?? 'Untitled';
      final description = item.description ?? '';
      final pubDate = item.pubDate ?? DateTime.now();
      
      final articleId = _generateArticleId(url);
      
      // Estimate reading time
      final wordCount = _stripHtml(description).split(' ').length * 5;
      final readingMinutes = (wordCount / 238).ceil().clamp(2, 20);
      
      final article = Article()
        ..id = articleId
        ..title = _stripHtml(title)
        ..sourceUrl = url
        ..sourceName = 'Google News'
        ..contentType = 'tech_news'
        ..category = 'Technology'
        ..publishedAt = pubDate is DateTime ? pubDate : DateTime.now()
        ..fetchedAt = DateTime.now()
        ..estimatedReadingMinutes = readingMinutes
        ..summary = _stripHtml(description)
        ..tags = ['news', 'technology', 'google-news'];
      
      return article;
    } catch (e) {
      return null;
    }
  }
  
  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }
  
  String _generateArticleId(String url) {
    final bytes = utf8.encode(url);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }
}
