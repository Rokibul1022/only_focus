import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/article.dart';

class WikipediaSource {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'User-Agent': 'OnlyFocus/1.0',
      },
    ),
  );
  
  Future<List<Article>> searchArticles(String query, {int limit = 10}) async {
    try {
      // Clean and encode the query properly
      final cleanQuery = query.trim();
      
      if (cleanQuery.isEmpty) {
        print('Wikipedia: Empty query');
        return [];
      }
      
      print('Wikipedia search for: "$cleanQuery"');
      
      final response = await _dio.get(
        'https://en.wikipedia.org/w/api.php',
        queryParameters: {
          'action': 'query',
          'format': 'json',
          'list': 'search',
          'srsearch': cleanQuery,
          'srlimit': limit,
          'srprop': 'snippet|timestamp',
          'utf8': '1',
        },
      );
      
      print('Wikipedia API response status: ${response.statusCode}');
      
      if (response.statusCode != 200) {
        print('Wikipedia: Bad status code ${response.statusCode}');
        return [];
      }
      
      if (response.data == null) {
        print('Wikipedia: No data in response');
        return [];
      }
      
      final data = response.data as Map<String, dynamic>;
      
      if (!data.containsKey('query')) {
        print('Wikipedia: No query key in response');
        return [];
      }
      
      final queryData = data['query'] as Map<String, dynamic>;
      
      if (!queryData.containsKey('search')) {
        print('Wikipedia: No search key in query data');
        return [];
      }
      
      final searchResults = queryData['search'] as List;
      print('Wikipedia found ${searchResults.length} results');
      
      if (searchResults.isEmpty) {
        return [];
      }
      
      final articles = <Article>[];
      
      for (final result in searchResults) {
        try {
          final article = await _fetchArticleDetails(result);
          if (article != null) {
            articles.add(article);
            print('Added article: ${article.title}');
          }
        } catch (e) {
          print('Error fetching article details: $e');
          continue;
        }
      }
      
      print('Wikipedia returning ${articles.length} articles');
      return articles;
    } catch (e, stack) {
      print('Wikipedia search error: $e');
      print('Stack trace: $stack');
      return [];
    }
  }
  
  Future<Article?> _fetchArticleDetails(Map<String, dynamic> searchResult) async {
    try {
      final pageId = searchResult['pageid'];
      final title = searchResult['title'] as String;
      
      if (pageId == null || title.isEmpty) {
        print('Invalid search result: missing pageId or title');
        return null;
      }
      
      print('Fetching details for: $title (ID: $pageId)');
      
      // Get page details including image
      final response = await _dio.get(
        'https://en.wikipedia.org/w/api.php',
        queryParameters: {
          'action': 'query',
          'format': 'json',
          'pageids': pageId.toString(),
          'prop': 'extracts|pageimages|info',
          'exintro': 'true',
          'explaintext': 'true',
          'piprop': 'thumbnail',
          'pithumbsize': 500,
          'inprop': 'url',
          'utf8': '1',
        },
      );
      
      if (response.statusCode != 200 || response.data == null) {
        print('Failed to fetch article details');
        return null;
      }
      
      final data = response.data as Map<String, dynamic>;
      final pages = data['query']?['pages'] as Map<String, dynamic>?;
      
      if (pages == null || pages.isEmpty) {
        print('No pages in response');
        return null;
      }
      
      final page = pages[pageId.toString()] as Map<String, dynamic>?;
      
      if (page == null) {
        print('Page not found in response');
        return null;
      }
      
      final extract = page['extract'] as String? ?? '';
      final imageUrl = page['thumbnail']?['source'] as String?;
      final url = page['fullurl'] as String? ?? 'https://en.wikipedia.org/wiki/${Uri.encodeComponent(title)}';
      
      final articleId = _generateArticleId(url);
      final wordCount = extract.split(' ').length;
      final readingMinutes = (wordCount / 238).ceil().clamp(3, 30);
      
      final article = Article()
        ..id = articleId
        ..title = title
        ..sourceUrl = url
        ..sourceName = 'Wikipedia'
        ..imageUrl = imageUrl
        ..contentType = 'science'
        ..category = 'Knowledge'
        ..publishedAt = DateTime.now()
        ..fetchedAt = DateTime.now()
        ..estimatedReadingMinutes = readingMinutes
        ..summary = extract.length > 300 ? '${extract.substring(0, 300)}...' : extract
        ..parsedContent = extract
        ..tags = ['wikipedia', 'knowledge'];
      
      return article;
    } catch (e, stack) {
      print('Error fetching article details: $e');
      print('Stack trace: $stack');
      return null;
    }
  }
  
  String _generateArticleId(String url) {
    final bytes = utf8.encode(url);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }
}
