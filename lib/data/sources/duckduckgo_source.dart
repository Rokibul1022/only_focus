import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../models/article.dart';
import 'dart:convert';

class DuckDuckGoSource {
  Future<List<Article>> search(String query) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final url = 'https://html.duckduckgo.com/html/?q=$encodedQuery';
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      );
      if (response.statusCode != 200) return [];
      
      final document = html_parser.parse(response.body);
      final results = document.querySelectorAll('.result');
      
      final articles = <Article>[];
      for (var result in results.take(15)) {
        try {
          final titleElement = result.querySelector('.result__a');
          final snippetElement = result.querySelector('.result__snippet');
          final linkElement = result.querySelector('.result__a');
          
          if (titleElement == null || linkElement == null) continue;
          
          final title = titleElement.text.trim();
          final snippet = snippetElement?.text.trim() ?? '';
          
          // Extract actual URL from href
          var sourceUrl = linkElement.attributes['href'] ?? '';
          
          // DuckDuckGo wraps URLs, extract the actual URL
          if (sourceUrl.contains('uddg=')) {
            final uri = Uri.parse('https://duckduckgo.com$sourceUrl');
            sourceUrl = uri.queryParameters['uddg'] ?? sourceUrl;
          }
          
          // Decode URL
          sourceUrl = Uri.decodeFull(sourceUrl);
          
          if (title.isEmpty || sourceUrl.isEmpty || !sourceUrl.startsWith('http')) continue;
          
          final article = Article()
            ..id = base64.encode(utf8.encode(sourceUrl))
            ..title = title
            ..summary = snippet
            ..sourceUrl = sourceUrl
            ..sourceName = 'Web Search'
            ..category = 'Search'
            ..contentType = 'article'
            ..publishedAt = DateTime.now()
            ..fetchedAt = DateTime.now()
            ..estimatedReadingMinutes = 5
            ..tags = [query];
          
          articles.add(article);
        } catch (e) {
          continue;
        }
      }
      
      return articles;
    } catch (e) {
      return [];
    }
  }
}
