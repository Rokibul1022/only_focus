import '../models/article.dart';
import '../sources/hackernews_source.dart';
import '../sources/arxiv_source.dart';
import '../sources/newsapi_source.dart';
import '../sources/google_news_rss_source.dart';
import '../sources/wikipedia_source.dart';
import '../sources/category_rss_source.dart';
import '../../core/services/cache_service.dart';
import 'dart:math';

class FeedRepository {
  final HackerNewsSource _hackerNews = HackerNewsSource();
  final ArxivSource _arxiv = ArxivSource();
  final NewsApiSource _newsApi = NewsApiSource();
  final GoogleNewsRssSource _googleNews = GoogleNewsRssSource();
  final WikipediaSource _wikipedia = WikipediaSource();
  final CategoryRssSource _categoryRss = CategoryRssSource();
  final CacheService _cache = CacheService();
  final Random _random = Random();
  
  // Fetch fresh articles from all sources with category prioritization
  Future<List<Article>> fetchFreshArticles({List<String>? preferredCategories}) async {
    final List<Article> allArticles = [];
    
    try {
      final wikiTopics = ['Artificial Intelligence', 'Quantum Computing', 'Space Exploration', 'Biotechnology', 'Climate Change', 'Renewable Energy'];
      final randomTopic = wikiTopics[_random.nextInt(wikiTopics.length)];
      
      // Fetch from all sources in PARALLEL with timeout
      final futures = <Future<List<Article>>>[
        _hackerNews.fetchTopStories(limit: 30).timeout(const Duration(seconds: 5), onTimeout: () => []),
        _arxiv.fetchLatestPapers(limit: 30).timeout(const Duration(seconds: 5), onTimeout: () => []),
        _newsApi.fetchTopHeadlines(category: 'technology', limit: 30).timeout(const Duration(seconds: 5), onTimeout: () => []),
        _newsApi.fetchTopHeadlines(category: 'science', limit: 30).timeout(const Duration(seconds: 5), onTimeout: () => []),
        _googleNews.fetchTechNews(limit: 30).timeout(const Duration(seconds: 5), onTimeout: () => []),
        _wikipedia.searchArticles(randomTopic, limit: 20).timeout(const Duration(seconds: 5), onTimeout: () => []),
      ];
      
      // Add all category-specific feeds with timeouts
      final categories = [
        'Technology', 'Science', 'Space', 'Medicine', 'World', 'Economics', 
        'Philosophy', 'Business', 'Environment', 'AI & Machine Learning', 
        'Cybersecurity', 'Energy', 'Psychology', 'History', 'Education'
      ];
      
      for (final category in categories) {
        final isPreferred = preferredCategories?.contains(category) ?? false;
        final limit = isPreferred ? 50 : 30;
        futures.add(_categoryRss.fetchByCategory(category, limit: limit).timeout(
          const Duration(seconds: 8),
          onTimeout: () => [],
        ));
      }
      
      // Wait for all with error handling - don't let one failure stop others
      final results = await Future.wait(futures, eagerError: false);
      
      for (final articles in results) {
        allArticles.addAll(articles);
      }
      
      print('Total articles fetched: ${allArticles.length}');
      
      // Deduplicate by ID in parallel
      final uniqueArticles = await _deduplicateArticlesAsync(allArticles);
      
      print('Unique articles after deduplication: ${uniqueArticles.length}');
      
      // Shuffle to mix sources
      uniqueArticles.shuffle(_random);
      
      print('Final articles to cache: ${uniqueArticles.length}');
      
      // Cache articles asynchronously without waiting
      _cache.cacheArticles(uniqueArticles);
      
      return uniqueArticles;
    } catch (e) {
      print('Error fetching articles: $e');
      return await _cache.getCachedArticles();
    }
  }

  // Async deduplication for better performance
  Future<List<Article>> _deduplicateArticlesAsync(List<Article> articles) async {
    return Future(() {
      final Map<String, Article> uniqueMap = {};
      final Set<String> seenTitles = {};
      
      for (final article in articles) {
        if (!uniqueMap.containsKey(article.id)) {
          final titleKey = article.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
          if (!seenTitles.contains(titleKey)) {
            uniqueMap[article.id] = article;
            seenTitles.add(titleKey);
          }
        }
      }
      
      return uniqueMap.values.toList();
    });
  }
  
  // Get cached articles (offline-first)
  Future<List<Article>> getCachedFeed({int limit = 50}) async {
    return await _cache.getCachedArticles(limit: limit);
  }
  
  // Get articles by category
  Future<List<Article>> getArticlesByCategory(String category) async {
    return await _cache.getArticlesByCategory(category);
  }
  
  // Search articles
  Future<List<Article>> searchArticles(String query) async {
    return await _cache.searchArticles(query);
  }
  
  // Clear old articles
  Future<void> clearOldArticles() async {
    await _cache.clearOldArticles();
  }
  
  // Cache articles directly
  Future<void> cacheArticles(List<Article> articles, {bool isSearchResult = false}) async {
    await _cache.cacheArticles(articles, isSearchResult: isSearchResult);
  }
  
  // Deduplicate articles by ID and title similarity
  List<Article> _deduplicateArticles(List<Article> articles) {
    final Map<String, Article> uniqueMap = {};
    
    for (final article in articles) {
      // Check if we already have this article by ID
      if (!uniqueMap.containsKey(article.id)) {
        // Check for title similarity (simple approach)
        bool isDuplicate = false;
        for (final existing in uniqueMap.values) {
          if (_areTitlesSimilar(article.title, existing.title)) {
            isDuplicate = true;
            break;
          }
        }
        
        if (!isDuplicate) {
          uniqueMap[article.id] = article;
        }
      }
    }
    
    return uniqueMap.values.toList();
  }
  
  // Simple title similarity check
  bool _areTitlesSimilar(String title1, String title2) {
    final words1 = title1.toLowerCase().split(' ').toSet();
    final words2 = title2.toLowerCase().split(' ').toSet();
    final intersection = words1.intersection(words2);
    final union = words1.union(words2);
    
    // Jaccard similarity > 0.7 means likely duplicate
    return union.isNotEmpty && (intersection.length / union.length) > 0.7;
  }
  

}
