import 'package:http/http.dart' as http;
import 'package:dart_rss/dart_rss.dart';
import 'dart:convert';
import '../models/article.dart';

class CategoryRssSource {
  // Reuse HTTP client for connection pooling
  static final http.Client _httpClient = http.Client();
  
  // RSS feeds for each category
  final Map<String, List<String>> _categoryFeeds = {
    'Technology': [
      'https://www.wired.com/feed/rss',
      'https://techcrunch.com/feed/',
      'https://www.theverge.com/rss/index.xml',
      'https://arstechnica.com/feed/',
      'https://www.engadget.com/rss.xml',
    ],
    'Science': [
      'https://www.sciencedaily.com/rss/all.xml',
      'https://www.nature.com/nature.rss',
      'https://www.newscientist.com/feed/home',
      'https://phys.org/rss-feed/',
      'https://www.sciencemag.org/rss/news_current.xml',
    ],
    'Space': [
      'https://www.space.com/feeds/all',
      'https://www.nasa.gov/rss/dyn/breaking_news.rss',
      'https://www.universetoday.com/feed/',
      'https://spaceflightnow.com/feed/',
    ],
    'Medicine': [
      'https://www.sciencedaily.com/rss/health_medicine.xml',
      'https://www.medicalnewstoday.com/rss/news.xml',
      'https://www.medscape.com/rss/news',
      'https://www.nih.gov/news-events/news-releases/rss',
    ],
    'World': [
      'https://feeds.bbci.co.uk/news/world/rss.xml',
      'https://www.aljazeera.com/xml/rss/all.xml',
      'https://www.reuters.com/rssFeed/worldNews',
      'https://rss.nytimes.com/services/xml/rss/nyt/World.xml',
    ],
    'Economics': [
      'https://www.economist.com/finance-and-economics/rss.xml',
      'https://www.ft.com/rss/home',
      'https://www.bloomberg.com/feed/podcast/etf-report.xml',
      'https://www.wsj.com/xml/rss/3_7085.xml',
    ],
    'Philosophy': [
      'https://philosophynow.org/rss/articles.xml',
      'https://dailynous.com/feed/',
    ],
    'Business': [
      'https://feeds.fortune.com/fortune/headlines',
      'https://www.forbes.com/business/feed/',
      'https://www.businessinsider.com/rss',
      'https://hbr.org/feed',
    ],
    'Environment': [
      'https://www.theguardian.com/environment/rss',
      'https://www.nationalgeographic.com/environment/rss',
      'https://www.ecowatch.com/feed',
    ],
    'AI & Machine Learning': [
      'https://www.technologyreview.com/feed/',
      'https://venturebeat.com/category/ai/feed/',
      'https://www.artificialintelligence-news.com/feed/',
    ],
    'Cybersecurity': [
      'https://www.wired.com/feed/category/security/latest/rss',
      'https://www.darkreading.com/rss.xml',
      'https://www.bleepingcomputer.com/feed/',
    ],
    'Energy': [
      'https://www.energy.gov/articles/rss.xml',
      'https://www.power-eng.com/rss/',
    ],
    'Psychology': [
      'https://www.sciencedaily.com/rss/mind_brain.xml',
      'https://www.psychologytoday.com/intl/feed/blog/all',
    ],
    'History': [
      'https://www.smithsonianmag.com/rss/history/',
      'https://www.historytoday.com/feed',
    ],
    'Education': [
      'https://www.insidehighered.com/rss/all',
      'https://hechingerreport.org/feed/',
    ],
  };
  
  Future<List<Article>> fetchByCategory(String category, {int limit = 30}) async {
    final feeds = _categoryFeeds[category];
    if (feeds == null || feeds.isEmpty) {
      print('No feeds found for category: $category');
      return [];
    }
    
    print('Fetching articles for category: $category from ${feeds.length} feeds');
    final allArticles = <Article>[];
    
    // Try each feed and collect articles
    for (final feedUrl in feeds) {
      try {
        final articles = await _fetchFromRss(feedUrl, category);
        print('Got ${articles.length} articles from $feedUrl');
        allArticles.addAll(articles);
      } catch (e) {
        print('Error with feed $feedUrl: $e');
        continue;
      }
    }
    
    print('Total articles for $category: ${allArticles.length}');
    return allArticles.take(limit).toList();
  }
  
  Future<List<Article>> _fetchFromRss(String feedUrl, String category) async {
    try {
      print('Fetching RSS from: $feedUrl');
      final response = await _httpClient.get(
        Uri.parse(feedUrl),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      ).timeout(const Duration(seconds: 8));
      
      print('Response status for $feedUrl: ${response.statusCode}');
      
      if (response.statusCode != 200) {
        print('Failed to fetch $feedUrl: ${response.statusCode}');
        return [];
      }
      
      final feed = RssFeed.parse(response.body);
      final articles = <Article>[];
      
      print('Found ${feed.items.length} items in feed');
      
      for (final item in feed.items.take(20)) {
        try {
          final title = item.title ?? '';
          final link = item.link ?? '';
          final description = item.description ?? '';
          final pubDate = item.pubDate ?? DateTime.now();
          
          if (title.isEmpty || link.isEmpty) continue;
          
          // Extract image from content or media
          String? imageUrl;
          if (item.enclosure?.url != null) {
            imageUrl = item.enclosure!.url;
          } else if (item.content?.images.isNotEmpty ?? false) {
            imageUrl = item.content!.images.first;
          }
          
          final article = Article()
            ..id = base64.encode(utf8.encode(link))
            ..title = _cleanText(title)
            ..summary = _cleanText(description)
            ..sourceUrl = link
            ..sourceName = feed.title ?? 'RSS Feed'
            ..imageUrl = imageUrl
            ..category = category
            ..contentType = 'article'
            ..publishedAt = pubDate is DateTime ? pubDate : DateTime.now()
            ..fetchedAt = DateTime.now()
            ..estimatedReadingMinutes = _estimateReadingTime(description)
            ..tags = [category];
          
          articles.add(article);
        } catch (e) {
          print('Error parsing item: $e');
          continue;
        }
      }
      
      print('Successfully parsed ${articles.length} articles from $feedUrl');
      return articles;
    } catch (e) {
      print('Error fetching RSS from $feedUrl: $e');
      return [];
    }
  }
  
  String _cleanText(String text) {
    return text
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
  
  int _estimateReadingTime(String text) {
    final wordCount = text.split(RegExp(r'\s+')).length;
    return (wordCount / 200).ceil().clamp(1, 30);
  }
}
