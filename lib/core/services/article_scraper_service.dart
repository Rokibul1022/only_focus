import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';

class ArticleScraperService {
  final Dio _dio = Dio();
  
  Future<String> scrapeArticle(String url) async {
    try {
      final result = await fetchArticleContent(url);
      return result['content'] ?? '';
    } catch (e) {
      throw Exception('Failed to scrape article: $e');
    }
  }
  
  Future<Map<String, dynamic>> fetchArticleContent(String url) async {
    try {
      final response = await _dio.get(
        url,
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
          followRedirects: true,
          validateStatus: (status) => status! < 500,
        ),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch article');
      }
      
      final document = html_parser.parse(response.data);
      
      // Extract main content
      final content = _extractContent(document);
      
      // Extract image if not already present
      final image = _extractMainImage(document);
      
      return {
        'content': content,
        'image': image,
      };
    } catch (e) {
      throw Exception('Failed to scrape article: $e');
    }
  }
  
  String _extractContent(Document document) {
    // Remove unwanted elements
    document.querySelectorAll('script, style, nav, header, footer, aside, .ad, .advertisement, .social-share').forEach((el) => el.remove());
    
    // Try common article content selectors
    final selectors = [
      'article',
      '[role="main"]',
      '.article-content',
      '.post-content',
      '.entry-content',
      '.article-body',
      '.post-body',
      '.content-body',
      'main',
      '#content',
      '.content',
    ];
    
    for (final selector in selectors) {
      final element = document.querySelector(selector);
      if (element != null) {
        // Get all paragraphs
        final paragraphs = element.querySelectorAll('p');
        if (paragraphs.isNotEmpty) {
          final content = paragraphs
              .map((p) => p.text.trim())
              .where((text) => text.isNotEmpty && text.length > 30)
              .join('\n\n');
          
          if (content.length > 200) {
            return content;
          }
        }
      }
    }
    
    // Fallback: get all paragraphs from body
    final allParagraphs = document.querySelectorAll('p');
    final content = allParagraphs
        .map((p) => p.text.trim())
        .where((text) => text.isNotEmpty && text.length > 30)
        .take(20)
        .join('\n\n');
    
    if (content.isNotEmpty) {
      return content;
    }
    
    // Last resort: get all text from body
    final body = document.querySelector('body');
    if (body != null) {
      return body.text.trim();
    }
    
    return '';
  }
  
  String? _extractMainImage(Document document) {
    // Try Open Graph image
    final ogImage = document.querySelector('meta[property="og:image"]');
    if (ogImage != null) {
      final content = ogImage.attributes['content'];
      if (content != null && content.isNotEmpty) {
        return content;
      }
    }
    
    // Try Twitter card image
    final twitterImage = document.querySelector('meta[name="twitter:image"]');
    if (twitterImage != null) {
      final content = twitterImage.attributes['content'];
      if (content != null && content.isNotEmpty) {
        return content;
      }
    }
    
    // Try first article image
    final articleImage = document.querySelector('article img, main img');
    if (articleImage != null) {
      final src = articleImage.attributes['src'];
      if (src != null && src.isNotEmpty && !src.contains('logo') && !src.contains('icon')) {
        return src;
      }
    }
    
    return null;
  }
}
