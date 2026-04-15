import 'package:dio/dio.dart';
import 'package:xml/xml.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../models/article.dart';
import '../../core/constants/api_endpoints.dart';

class ArxivSource {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'User-Agent': 'OnlyFocus/1.0 (https://github.com/onlyfocus; contact@onlyfocus.app)',
    },
  ));
  
  Future<List<Article>> fetchLatestPapers({
    String category = 'cs.AI', // Computer Science - AI by default
    int limit = 20,
  }) async {
    try {
      // arXiv API best practices: use HTTPS and proper rate limiting
      final query = Uri.encodeComponent('cat:$category');
      final url = '${ApiEndpoints.arxivBase}?search_query=$query&sortBy=submittedDate&sortOrder=descending&max_results=$limit';
      
      // Rate limiting: wait between requests
      await Future.delayed(const Duration(milliseconds: 500));
      
      final response = await _dio.get(url);
      final document = XmlDocument.parse(response.data);
      
      final entries = document.findAllElements('entry');
      final List<Article> articles = [];
      
      for (final entry in entries) {
        try {
          final article = _parseArxivEntry(entry);
          articles.add(article);
        } catch (e) {
          continue;
        }
      }
      
      return articles;
    } catch (e) {
      throw Exception('Failed to fetch arXiv papers: $e');
    }
  }
  
  Article _parseArxivEntry(XmlElement entry) {
    final title = entry.findElements('title').first.innerText.trim().replaceAll('\n', ' ');
    final summary = entry.findElements('summary').first.innerText.trim();
    var link = entry.findElements('id').first.innerText;
    final published = entry.findElements('published').first.innerText;
    
    // Convert HTTP to HTTPS for arXiv URLs
    if (link.startsWith('http://')) {
      link = link.replaceFirst('http://', 'https://');
    }
    
    // Extract categories
    final categories = entry.findAllElements('category')
        .map((e) => e.getAttribute('term') ?? '')
        .where((c) => c.isNotEmpty)
        .toList();
    
    final articleId = _generateArticleId(link);
    
    // Estimate reading time based on abstract length
    final wordCount = summary.split(' ').length * 10; // Papers are longer
    final readingMinutes = (wordCount / 238).ceil().clamp(10, 120);
    
    final article = Article()
      ..id = articleId
      ..title = title
      ..sourceUrl = link
      ..sourceName = 'arXiv'
      ..contentType = 'research_paper'
      ..category = _mapCategoryToReadable(categories.isNotEmpty ? categories.first : 'cs')
      ..publishedAt = DateTime.parse(published)
      ..fetchedAt = DateTime.now()
      ..estimatedReadingMinutes = readingMinutes
      ..summary = '$summary\n\nThank you to arXiv for use of its open access interoperability.'
      ..tags = ['research', 'arxiv', ...categories.take(3)];
    
    return article;
  }
  
  String _mapCategoryToReadable(String category) {
    if (category.startsWith('cs')) return 'Computer Science';
    if (category.startsWith('physics')) return 'Physics';
    if (category.startsWith('math')) return 'Mathematics';
    if (category.startsWith('q-bio')) return 'Biology';
    if (category.startsWith('astro-ph')) return 'Astronomy';
    return 'Science';
  }
  
  String _generateArticleId(String url) {
    final bytes = utf8.encode(url);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }
}
