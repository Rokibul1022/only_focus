import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import 'dart:convert';
import '../models/article.dart';

class WebSearchSource {
  Future<List<Article>> search(String query) async {
    try {
      print('Searching for: $query');
      // Use DuckDuckGo HTML search (more reliable than Google)
      return await _duckDuckGoSearch(query);
    } catch (e) {
      print('Search error: $e');
      return [];
    }
  }
  
  Future<List<Article>> _duckDuckGoSearch(String query) async {
    try {
      // Clean the query
      final cleanQuery = query.trim();
      final encodedQuery = Uri.encodeComponent(cleanQuery);
      final url = 'https://html.duckduckgo.com/html/?q=$encodedQuery';
      
      print('DuckDuckGo search for: $cleanQuery');
      print('Fetching from: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      ).timeout(const Duration(seconds: 15));
      
      print('Response status: ${response.statusCode}');
      
      if (response.statusCode != 200) {
        print('Bad response status');
        return [];
      }
      
      final document = html_parser.parse(response.body);
      final results = document.querySelectorAll('.result');
      
      print('Found ${results.length} result elements');
      
      if (results.isEmpty) {
        // Try alternative selectors
        final altResults = document.querySelectorAll('.web-result');
        print('Alternative selector found ${altResults.length} results');
      }
      
      final articles = <Article>[];
      
      for (var result in results) {
        try {
          // Get title
          final titleElement = result.querySelector('.result__a');
          if (titleElement == null) {
            print('No title element found');
            continue;
          }
          final title = titleElement.text.trim();
          if (title.isEmpty) continue;
          
          // Get URL from href
          final href = titleElement.attributes['href'];
          if (href == null || href.isEmpty) {
            print('No href found');
            continue;
          }
          
          // Parse the URL - DuckDuckGo wraps URLs
          String sourceUrl = href;
          if (href.startsWith('//duckduckgo.com/l/?')) {
            final uri = Uri.parse('https:$href');
            sourceUrl = uri.queryParameters['uddg'] ?? href;
          }
          
          // Decode URL
          sourceUrl = Uri.decodeFull(sourceUrl);
          
          // Skip if not a valid HTTP URL
          if (!sourceUrl.startsWith('http')) {
            print('Invalid URL: $sourceUrl');
            continue;
          }
          
          // Get snippet
          final snippetElement = result.querySelector('.result__snippet');
          final snippet = snippetElement?.text.trim() ?? '';
          
          print('Found article: $title');
          print('URL: $sourceUrl');
          
          // Generate unique ID
          final articleId = base64.encode(utf8.encode(sourceUrl)).substring(0, 16);
          
          final article = Article()
            ..id = articleId
            ..title = title
            ..summary = snippet
            ..sourceUrl = sourceUrl
            ..sourceName = 'Web Search'
            ..category = 'Search'
            ..contentType = 'article'
            ..publishedAt = DateTime.now()
            ..fetchedAt = DateTime.now()
            ..estimatedReadingMinutes = 5
            ..tags = [cleanQuery];
          
          articles.add(article);
          
          if (articles.length >= 15) break;
        } catch (e) {
          print('Error parsing result: $e');
          continue;
        }
      }
      
      print('Returning ${articles.length} articles');
      return articles;
    } catch (e) {
      print('DuckDuckGo search error: $e');
      return [];
    }
  }
}
