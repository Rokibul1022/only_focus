import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/cache_service.dart';
import '../../providers/feed_provider.dart';
import '../../providers/auth_provider.dart';
import '../../data/models/article.dart';
import '../shared/article_card.dart';
import '../reader/reader_screen.dart';
import '../shared/app_drawer.dart';
import '../shared/chatbot_widget.dart';
import '../feedback/feedback_form_dialog.dart';
import '../feedback/feedback_list_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  @override
  void initState() {
    super.initState();
    // Check and refresh feed if needed
    Future.microtask(() async {
      await _checkAndRefreshFeed();
      await _syncBookmarks();
    });
  }
  
  Future<void> _syncBookmarks() async {
    try {
      final user = ref.read(authStateProvider).value;
      if (user != null) {
        final cache = CacheService();
        await cache.syncBookmarksFromFirestore(user.uid);
      }
    } catch (e) {
      print('Error syncing bookmarks: $e');
    }
  }
  
  Future<void> _checkAndRefreshFeed() async {
    final prefs = await SharedPreferences.getInstance();
    final lastRefreshStr = prefs.getString('last_feed_refresh');
    final now = DateTime.now();
    
    bool shouldRefresh = false;
    
    if (lastRefreshStr == null) {
      // First time, always refresh
      shouldRefresh = true;
    } else {
      final lastRefresh = DateTime.parse(lastRefreshStr);
      final difference = now.difference(lastRefresh);
      
      // Refresh if more than 8 hours have passed
      if (difference.inHours >= 8) {
        shouldRefresh = true;
      }
    }
    
    if (shouldRefresh) {
      print('Auto-refreshing feed (last refresh: $lastRefreshStr)');
      await ref.read(feedProvider.notifier).refreshFeed();
      await prefs.setString('last_feed_refresh', now.toIso8601String());
    } else {
      // Load cached feed
      final currentState = ref.read(feedProvider);
      if (currentState is! AsyncData || (currentState as AsyncData).value.isEmpty) {
        await ref.read(feedProvider.notifier).loadCachedFeed();
      }
    }
  }
  
  Future<void> _refreshFeed() async {
    await ref.read(feedProvider.notifier).refreshFeed();
    // Update last refresh timestamp
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_feed_refresh', DateTime.now().toIso8601String());
  }
  
  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedProvider);
    final userProfile = ref.watch(userProfileProvider);
    
    return Scaffold(
      key: _scaffoldKey,
      drawer: const AppDrawer(),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: GestureDetector(
          onTap: () {
            _scaffoldKey.currentState?.openDrawer();
          },
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.asset(
              'assets/images/Sleek eye logo for Only Focus app.png',
              height: 32,
              width: 32,
            ),
          ),
        ),
        title: Text(
          'ONLY FOCUS',
          style: AppTextStyles.uiH3.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        actions: [
          // Feedback button
          IconButton(
            icon: const Icon(Icons.feedback_outlined, color: AppColors.primary),
            tooltip: 'Give Feedback',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const FeedbackFormDialog(),
              );
            },
          ),
          // View all feedback
          IconButton(
            icon: const Icon(Icons.list_alt, color: AppColors.primary),
            tooltip: 'View Feedback',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FeedbackListScreen(),
                ),
              );
            },
          ),
          // Stars display
          userProfile.when(
            data: (profile) {
              if (profile == null) return const SizedBox();
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: AppColors.reward, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      '${profile.totalStars}',
                      style: AppTextStyles.uiBody.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.reward,
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
        ],
      ),
      body: Stack(
        children: [
          feedState.when(
            data: (articles) => _buildFeedList(articles),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.warning),
                  const SizedBox(height: 16),
                  Text('Failed to load articles', style: AppTextStyles.uiBody),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _refreshFeed,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ChatbotWidget(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/friends');
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) async {
          if (index == 0 && _currentIndex == 0) {
            // Tapped home while on home - refresh with new content
            await ref.read(feedProvider.notifier).refreshFeed();
            return;
          }
          
          setState(() => _currentIndex = index);
          switch (index) {
            case 0:
              // Refresh home feed when coming back
              await ref.read(feedProvider.notifier).refreshFeed();
              break;
            case 1:
              Navigator.pushNamed(context, '/discover').then((_) {
                setState(() => _currentIndex = 0);
              });
              break;
            case 2:
              Navigator.pushNamed(context, '/ai-chat').then((_) {
                setState(() => _currentIndex = 0);
              });
              break;
            case 3:
              Navigator.pushNamed(context, '/friends').then((_) {
                setState(() => _currentIndex = 0);
              });
              break;
            case 4:
              Navigator.pushNamed(context, '/profile').then((_) {
                setState(() => _currentIndex = 0);
              });
              break;
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            activeIcon: Icon(Icons.explore),
            label: 'Discover',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Niko',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Friends',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
  
  Widget _buildFeedList(List<Article> articles) {
    if (articles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.article_outlined, size: 64, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text('No articles yet', style: AppTextStyles.uiH2),
            const SizedBox(height: 8),
            Text(
              'Pull down to refresh',
              style: AppTextStyles.uiBody.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _refreshFeed,
      child: ListView.builder(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
        itemCount: articles.length + 1,
        physics: const AlwaysScrollableScrollPhysics(),
        addAutomaticKeepAlives: true,
        addRepaintBoundaries: true,
        cacheExtent: 500,
        itemBuilder: (context, index) {
          if (index == articles.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: OutlinedButton(
                  onPressed: () => ref.read(feedProvider.notifier).loadMore(),
                  child: const Text('Load More'),
                ),
              ),
            );
          }
          
          final article = articles[index];
          return ArticleCard(
            article: article,
            onTap: () {
              ref.read(selectedArticleProvider.notifier).state = article;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReaderScreen(article: article),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
