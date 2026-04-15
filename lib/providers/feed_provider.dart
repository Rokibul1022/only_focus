import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/article.dart';
import '../data/repositories/feed_repository.dart';
import '../data/sources/web_search_source.dart';

// Feed repository provider
final feedRepositoryProvider = Provider<FeedRepository>((ref) {
  return FeedRepository();
});

// Feed state provider
final feedProvider = StateNotifierProvider<FeedNotifier, AsyncValue<List<Article>>>((ref) {
  return FeedNotifier(ref.read(feedRepositoryProvider));
});

// Separate provider for discover search results
final discoverSearchProvider = StateProvider<List<Article>>((ref) => []);

// Feed notifier
class FeedNotifier extends StateNotifier<AsyncValue<List<Article>>> {
  final FeedRepository _repository;
  
  FeedNotifier(this._repository) : super(const AsyncValue.loading()) {
    // Don't auto-load on init
  }
  
  // Load cached feed (offline-first)
  Future<void> loadCachedFeed() async {
    try {
      final articles = await _repository.getCachedFeed();
      articles.shuffle();
      state = AsyncValue.data(articles);
      
      // If cache is empty, fetch fresh in background
      if (articles.isEmpty) {
        await refreshFeed();
      }
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
  
  // Refresh feed from network with randomization
  Future<void> refreshFeed() async {
    state = const AsyncValue.loading();
    try {
      // Get user preferences
      final userProfile = await _getUserProfile();
      final preferredCategories = userProfile?['preferredCategories'] as List<dynamic>?;
      final categories = preferredCategories?.map((e) => e.toString()).toList();
      
      final articles = await _repository.fetchFreshArticles(preferredCategories: categories);
      
      // Shuffle articles to show different content each time
      articles.shuffle();
      
      state = AsyncValue.data(articles);
      
      // Clear old articles after successful fetch
      await _repository.clearOldArticles();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      // Fallback to cached on error
      final cached = await _repository.getCachedFeed();
      if (cached.isNotEmpty) {
        cached.shuffle();
        state = AsyncValue.data(cached);
      }
    }
  }
  
  Future<Map<String, dynamic>?> _getUserProfile() async {
    try {
      final user = await Future.value(null); // Get from auth
      return null;
    } catch (e) {
      return null;
    }
  }
  
  // Load more articles
  Future<void> loadMore() async {
    final currentState = state;
    if (currentState is! AsyncData<List<Article>>) return;
    
    try {
      final currentArticles = currentState.value;
      final moreArticles = await _repository.getCachedFeed(limit: currentArticles.length + 50);
      state = AsyncValue.data(moreArticles);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
  
  // Filter by category
  Future<void> filterByCategory(String category) async {
    state = const AsyncValue.loading();
    try {
      final articles = await _repository.getArticlesByCategory(category);
      state = AsyncValue.data(articles);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
  
  // Search articles
  Future<void> searchArticles(String query) async {
    if (query.isEmpty) {
      await loadCachedFeed();
      return;
    }
    
    state = const AsyncValue.loading();
    try {
      final articles = await _repository.searchArticles(query);
      state = AsyncValue.data(articles);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
  
  // Search with Web Search
  Future<void> searchWithDuckDuckGo(String query) async {
    if (query.isEmpty) {
      await loadCachedFeed();
      return;
    }
    
    state = const AsyncValue.loading();
    try {
      print('Starting web search for: $query');
      final webSearch = WebSearchSource();
      final articles = await webSearch.search(query);
      
      print('Search returned ${articles.length} articles');
      
      if (articles.isEmpty) {
        print('No articles found, returning empty list');
        state = const AsyncValue.data([]);
        return;
      }
      
      // Cache the search results so they can be bookmarked and read
      print('Caching ${articles.length} articles');
      await _repository.cacheArticles(articles, isSearchResult: true);
      print('Articles cached successfully');
      
      state = AsyncValue.data(articles);
      print('Search completed successfully');
    } catch (e, stack) {
      print('Search error: $e');
      print('Stack trace: $stack');
      // Return empty list instead of error to prevent crash
      state = const AsyncValue.data([]);
    }
  }
  
  // Get web search results without changing state
  Future<List<Article>> getWebSearchResults(String query) async {
    try {
      final webSearch = WebSearchSource();
      final articles = await webSearch.search(query);
      return articles;
    } catch (e) {
      print('Web search error: $e');
      return [];
    }
  }
}

// Selected article provider
final selectedArticleProvider = StateProvider<Article?>((ref) => null);

// Category filter provider
final categoryFilterProvider = StateProvider<String?>((ref) => null);
