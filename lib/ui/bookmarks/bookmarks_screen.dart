import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../data/repositories/bookmark_repository.dart';
import '../../data/models/article.dart';
import '../../providers/feed_provider.dart';
import '../shared/article_card.dart';
import '../reader/reader_screen.dart';

// Bookmark repository provider
final bookmarkRepositoryProvider = Provider<BookmarkRepository>((ref) {
  return BookmarkRepository();
});

// Bookmarked articles provider
final bookmarkedArticlesProvider = FutureProvider.autoDispose<List<Article>>((ref) async {
  return await ref.read(bookmarkRepositoryProvider).getBookmarkedArticles();
});

class BookmarksScreen extends ConsumerStatefulWidget {
  const BookmarksScreen({super.key});

  @override
  ConsumerState<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends ConsumerState<BookmarksScreen> {
  String _selectedFilter = 'All';
  
  final List<String> _filters = [
    'All',
    'Unread',
    'Research Papers',
    'Articles',
    'Highlights',
  ];
  
  @override
  void initState() {
    super.initState();
    // Refresh bookmarks when screen loads
    Future.microtask(() => ref.refresh(bookmarkedArticlesProvider));
  }

  @override
  Widget build(BuildContext context) {
    final bookmarksAsync = ref.watch(bookmarkedArticlesProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bookmarks'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Filter chips
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filters.length,
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = filter == _selectedFilter;
                
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() => _selectedFilter = filter);
                    },
                    backgroundColor: AppColors.surfaceLight,
                    selectedColor: AppColors.primary,
                    labelStyle: AppTextStyles.uiBody.copyWith(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Bookmarked articles list
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(bookmarkedArticlesProvider);
              },
              child: bookmarksAsync.when(
                data: (articles) => _buildBookmarksList(_filterArticles(articles)),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.warning),
                      const SizedBox(height: 16),
                      Text('Error loading bookmarks', style: AppTextStyles.uiBody),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(bookmarkedArticlesProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  List<Article> _filterArticles(List<Article> articles) {
    switch (_selectedFilter) {
      case 'Unread':
        return articles.where((a) => !a.isRead).toList();
      case 'Research Papers':
        return articles.where((a) => a.contentType == 'research_paper').toList();
      case 'Articles':
        return articles.where((a) => a.contentType != 'research_paper').toList();
      case 'Highlights':
        // TODO: Filter by articles with highlights
        return articles;
      default:
        return articles;
    }
  }
  
  Widget _buildBookmarksList(List<Article> articles) {
    if (articles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.bookmark_outline,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              _selectedFilter == 'All' 
                  ? 'No bookmarks yet'
                  : 'No $_selectedFilter bookmarks',
              style: AppTextStyles.uiH2,
            ),
            const SizedBox(height: 8),
            Text(
              'Save articles to read later',
              style: AppTextStyles.uiBody.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: articles.length,
      itemBuilder: (context, index) {
        final article = articles[index];
        return ArticleCard(
          article: article,
          onTap: () async {
            ref.read(selectedArticleProvider.notifier).state = article;
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReaderScreen(articleId: article.id),
              ),
            );
            // Refresh bookmarks when returning
            ref.invalidate(bookmarkedArticlesProvider);
          },
        );
      },
    );
  }
}
