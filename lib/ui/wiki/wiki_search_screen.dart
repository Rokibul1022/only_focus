import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/search_history_service.dart';
import '../../data/sources/wikipedia_source.dart';
import '../../data/models/article.dart';
import '../../providers/feed_provider.dart';
import '../shared/article_card.dart';
import '../reader/reader_screen.dart';

class WikiSearchScreen extends ConsumerStatefulWidget {
  const WikiSearchScreen({super.key});

  @override
  ConsumerState<WikiSearchScreen> createState() => _WikiSearchScreenState();
}

class _WikiSearchScreenState extends ConsumerState<WikiSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final WikipediaSource _wikiSource = WikipediaSource();
  final SearchHistoryService _historyService = SearchHistoryService();
  List<Article> _results = [];
  bool _isLoading = false;
  List<String> _searchHistory = [];
  bool _showHistory = false;
  
  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
    _searchController.addListener(() {
      setState(() {
        _showHistory = _searchController.text.isEmpty;
      });
    });
  }

  Future<void> _loadSearchHistory() async {
    final history = await _historyService.getWikiHistory();
    setState(() {
      _searchHistory = history;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    
    await _historyService.addWikiHistory(query);
    await _loadSearchHistory();
    
    setState(() {
      _isLoading = true;
      _showHistory = false;
    });
    
    try {
      final results = await _wikiSource.searchArticles(query, limit: 20);
      
      // Mark as search results and cache
      final cacheService = ref.read(feedRepositoryProvider);
      await cacheService.cacheArticles(results, isSearchResult: true);
      
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search failed: $e')),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wikipedia Search'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search Wikipedia...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _results = [];
                                _showHistory = true;
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Theme.of(context).dividerColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primary, width: 2),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                  ),
                  onSubmitted: (_) => _search(),
                ),
                if (_showHistory && _searchHistory.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Recent Searches',
                              style: AppTextStyles.uiCaption.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                await _historyService.clearWikiHistory();
                                await _loadSearchHistory();
                              },
                              child: Text(
                                'Clear All',
                                style: AppTextStyles.uiCaption.copyWith(
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ...List.generate(
                          _searchHistory.length > 5 ? 5 : _searchHistory.length,
                          (index) {
                            final query = _searchHistory[index];
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.history, size: 20),
                              title: Text(
                                query,
                                style: AppTextStyles.uiBody,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () async {
                                  await _historyService.removeWikiHistory(query);
                                  await _loadSearchHistory();
                                },
                              ),
                              onTap: () {
                                _searchController.text = query;
                                _search();
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _search,
                icon: const Icon(Icons.search),
                label: const Text('Search'),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search, size: 64, color: AppColors.textSecondary),
                            const SizedBox(height: 16),
                            Text('Search Wikipedia', style: AppTextStyles.uiH2),
                            const SizedBox(height: 8),
                            Text('Find articles on any topic', style: AppTextStyles.uiBody.copyWith(color: AppColors.textSecondary)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final article = _results[index];
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
          ),
        ],
      ),
    );
  }
}
