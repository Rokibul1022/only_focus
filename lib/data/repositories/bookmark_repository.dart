import '../models/article.dart';
import '../../core/services/cache_service.dart';

class BookmarkRepository {
  final CacheService _cache = CacheService();
  
  // Get all bookmarked articles
  Future<List<Article>> getBookmarkedArticles() async {
    return await _cache.getBookmarkedArticles();
  }
  
  // Toggle bookmark status
  Future<void> toggleBookmark(String articleId) async {
    await _cache.toggleBookmark(articleId);
  }
  
  // Check if article is bookmarked
  Future<bool> isBookmarked(String articleId) async {
    final article = await _cache.getArticleById(articleId);
    return article?.isBookmarked ?? false;
  }
  
  // Get bookmarked articles by category
  Future<List<Article>> getBookmarkedByCategory(String category) async {
    final allBookmarks = await getBookmarkedArticles();
    return allBookmarks.where((a) => a.category == category).toList();
  }
  
  // Get bookmarked articles by content type
  Future<List<Article>> getBookmarkedByContentType(String contentType) async {
    final allBookmarks = await getBookmarkedArticles();
    return allBookmarks.where((a) => a.contentType == contentType).toList();
  }
  
  // Get unread bookmarked articles
  Future<List<Article>> getUnreadBookmarks() async {
    final allBookmarks = await getBookmarkedArticles();
    return allBookmarks.where((a) => !a.isRead).toList();
  }
  
  // Get bookmarked articles with highlights
  Future<List<Article>> getBookmarksWithHighlights() async {
    final allBookmarks = await getBookmarkedArticles();
    // TODO: Filter by articles that have highlights in Firestore
    return allBookmarks;
  }
  
  // Search bookmarked articles
  Future<List<Article>> searchBookmarks(String query) async {
    final allBookmarks = await getBookmarkedArticles();
    final lowerQuery = query.toLowerCase();
    
    return allBookmarks.where((article) {
      return article.title.toLowerCase().contains(lowerQuery) ||
             (article.summary?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }
}
