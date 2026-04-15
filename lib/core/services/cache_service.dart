import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../../data/models/article.dart';
import '../../data/models/note.dart';

class CacheService {
  static Isar? _isar;
  
  Future<Isar> get isar async {
    if (_isar != null) return _isar!;
    
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [ArticleSchema, NoteSchema],
      directory: dir.path,
    );
    
    return _isar!;
  }
  
  // Cache articles in batches for better performance
  Future<void> cacheArticles(List<Article> articles, {bool isSearchResult = false}) async {
    final db = await isar;
    
    // Get existing articles that need status preservation
    final existingArticles = await db.articles
        .filter()
        .anyOf(articles, (q, article) => q.idEqualTo(article.id))
        .findAll();
    
    final existingMap = {for (var a in existingArticles) a.id: a};
    
    // Prepare articles for batch insert
    final articlesToCache = <Article>[];
    
    for (final article in articles) {
      final existing = existingMap[article.id];
      if (existing != null) {
        // Preserve important fields
        article.isarId = existing.isarId;
        article.isBookmarked = existing.isBookmarked;
        article.isRead = existing.isRead;
        article.readingProgress = existing.readingProgress;
        article.readingDurationSec = existing.readingDurationSec;
        article.lastReadAt = existing.lastReadAt;
      }
      
      // Mark search results so they don't appear in home feed
      if (isSearchResult) {
        article.contentType = 'search_result';
      }
      
      articlesToCache.add(article);
    }
    
    // Batch write all articles at once
    await db.writeTxn(() async {
      await db.articles.putAll(articlesToCache);
    });
  }
  
  // Get all cached articles (exclude search results)
  Future<List<Article>> getCachedArticles({int limit = 500}) async {
    final db = await isar;
    return await db.articles
        .filter()
        .not()
        .contentTypeEqualTo('search_result')
        .sortByFetchedAtDesc()
        .limit(limit)
        .findAll();
  }
  
  // Get articles by category
  Future<List<Article>> getArticlesByCategory(String category) async {
    final db = await isar;
    return await db.articles
        .filter()
        .categoryEqualTo(category)
        .sortByPublishedAtDesc()
        .findAll();
  }
  
  // Get articles by content type
  Future<List<Article>> getArticlesByContentType(String contentType) async {
    final db = await isar;
    return await db.articles
        .filter()
        .contentTypeEqualTo(contentType)
        .sortByPublishedAtDesc()
        .findAll();
  }
  
  // Get bookmarked articles
  Future<List<Article>> getBookmarkedArticles() async {
    final db = await isar;
    return await db.articles
        .filter()
        .isBookmarkedEqualTo(true)
        .sortByFetchedAtDesc()
        .findAll();
  }
  
  // Get single article by ID
  Future<Article?> getArticleById(String id) async {
    final db = await isar;
    return await db.articles
        .filter()
        .idEqualTo(id)
        .findFirst();
  }
  
  // Update article
  Future<void> updateArticle(Article article) async {
    final db = await isar;
    await db.writeTxn(() async {
      await db.articles.put(article);
    });
  }
  
  // Toggle bookmark
  Future<void> toggleBookmark(String articleId) async {
    final db = await isar;
    final article = await getArticleById(articleId);
    if (article != null) {
      article.isBookmarked = !article.isBookmarked;
      await updateArticle(article);
    }
  }
  
  // Mark article as read
  Future<void> markAsRead(String articleId, {
    required double progress,
    required int durationSec,
  }) async {
    final db = await isar;
    final article = await getArticleById(articleId);
    if (article != null) {
      article.isRead = progress >= 0.6;
      article.readingProgress = progress;
      article.readingDurationSec = durationSec;
      article.lastReadAt = DateTime.now();
      await updateArticle(article);
    }
  }
  
  // Search articles (full-text search)
  Future<List<Article>> searchArticles(String query) async {
    final db = await isar;
    final lowerQuery = query.toLowerCase();
    
    return await db.articles
        .filter()
        .titleContains(lowerQuery, caseSensitive: false)
        .or()
        .summaryContains(lowerQuery, caseSensitive: false)
        .sortByFetchedAtDesc()
        .findAll();
  }
  
  // Clear old articles (keep last 500, but never delete bookmarked articles)
  Future<void> clearOldArticles() async {
    final db = await isar;
    final allArticles = await db.articles
        .where()
        .sortByFetchedAtDesc()
        .findAll();
    
    if (allArticles.length > 500) {
      // Get articles to delete (skip first 500 and exclude bookmarked)
      final toDelete = allArticles
          .skip(500)
          .where((a) => !a.isBookmarked)
          .map((a) => a.isarId)
          .toList();
      
      if (toDelete.isNotEmpty) {
        await db.writeTxn(() async {
          await db.articles.deleteAll(toDelete);
        });
      }
    }
  }
}
