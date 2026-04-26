import 'package:firebase_auth/firebase_auth.dart';
import 'backend_api_service.dart';
import 'cache_service.dart';

/// Keeps Niko's knowledge base in sync with the user's saved (bookmarked)
/// articles. Runs on the backend against the Chroma `documents` collection,
/// scoped per Firebase user.
class NikoSyncService {
  final BackendApiService _backend = BackendApiService();
  final CacheService _cache = CacheService();

  String get _userId => FirebaseAuth.instance.currentUser?.uid ?? 'default';

  Future<int> syncBookmarks() async {
    final articles = await _cache.getBookmarkedArticles();
    if (articles.isEmpty) return 0;

    // Skip docs already indexed for this user to avoid re-embedding them.
    final existing = await _backend.nikoDocuments(userId: _userId);
    final existingIds = existing.map((d) => d['doc_id'] as String).toSet();

    int indexed = 0;
    for (final article in articles) {
      final docId = 'article-$_userId-${article.id}';
      if (existingIds.contains(docId)) continue;

      final content = (article.parsedContent != null &&
              article.parsedContent!.trim().isNotEmpty)
          ? article.parsedContent!
          : (article.summary?.trim().isNotEmpty ?? false
              ? article.summary!
              : article.title);
      if (content.trim().isEmpty) continue;

      try {
        await _backend.nikoIndex(
          title: article.title,
          content: content,
          source: article.sourceName.isNotEmpty ? article.sourceName : 'bookmark',
          docId: docId,
          userId: _userId,
        );
        indexed++;
      } catch (e) {
        // Keep syncing the rest even if one article fails.
      }
    }
    return indexed;
  }
}
