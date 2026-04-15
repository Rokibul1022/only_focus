import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/ocr_service.dart';
import '../../core/services/ai_service.dart';
import '../../core/services/cache_service.dart';
import '../../core/services/search_history_service.dart';
import '../../providers/feed_provider.dart';
import '../../data/models/article.dart';
import '../../data/sources/wikipedia_source.dart';
import '../../data/sources/web_search_source.dart';
import '../shared/article_card.dart';
import '../reader/reader_screen.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final TextEditingController _searchController = TextEditingController();
  final OcrService _ocrService = OcrService();
  final AIService _aiService = AIService();
  final ImagePicker _imagePicker = ImagePicker();
  final WikipediaSource _wikiSource = WikipediaSource();
  final CacheService _cache = CacheService();
  final SearchHistoryService _historyService = SearchHistoryService();
  String? _selectedCategory;
  bool _isProcessingImage = false;
  bool _isSearching = false;
  List<String> _searchHistory = [];
  bool _showHistory = false;
  
  final List<String> _categories = [
    'Technology',
    'Science',
    'Research Papers',
    'World',
    'Space',
    'Philosophy',
    'Medicine',
    'Economics',
    'Business',
    'Environment',
    'AI & Machine Learning',
    'Cybersecurity',
    'Energy',
    'Psychology',
    'History',
    'Education',
  ];
  
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
    final history = await _historyService.getDiscoverHistory();
    setState(() {
      _searchHistory = history;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _ocrService.dispose();
    // Clear discover search when leaving
    ref.read(discoverSearchProvider.notifier).state = [];
    super.dispose();
  }
  
  void _onCategorySelected(String category) async {
    setState(() {
      _selectedCategory = category == _selectedCategory ? null : category;
      _searchController.clear();
    });
    
    if (_selectedCategory != null) {
      setState(() => _isSearching = true);
      try {
        final articles = await _cache.getArticlesByCategory(_selectedCategory!);
        ref.read(discoverSearchProvider.notifier).state = articles;
      } catch (e) {
        print('Error loading category: $e');
        ref.read(discoverSearchProvider.notifier).state = [];
      } finally {
        setState(() => _isSearching = false);
      }
    } else {
      ref.read(discoverSearchProvider.notifier).state = [];
    }
  }
  
  void _onSearch(String query) async {
    if (query.isEmpty) {
      ref.read(discoverSearchProvider.notifier).state = [];
      return;
    }
    
    await _historyService.addDiscoverHistory(query);
    await _loadSearchHistory();
    
    setState(() {
      _selectedCategory = null;
      _isSearching = true;
      _showHistory = false;
    });
    
    try {
      final cleanQuery = query.trim();
      print('Discover: Starting search for: $cleanQuery');
      
      List<Article> allArticles = [];
      
      // Try Wikipedia search
      try {
        final wikiArticles = await _wikiSource.searchArticles(cleanQuery, limit: 10);
        if (wikiArticles.isNotEmpty) {
          print('Found ${wikiArticles.length} Wikipedia articles');
          allArticles.addAll(wikiArticles);
        }
      } catch (e) {
        print('Wikipedia search failed: $e');
      }
      
      // Try web search
      try {
        final webSearchSource = WebSearchSource();
        final webArticles = await webSearchSource.search(cleanQuery);
        if (webArticles.isNotEmpty) {
          print('Found ${webArticles.length} web articles');
          allArticles.addAll(webArticles);
        }
      } catch (e) {
        print('Web search failed: $e');
      }
      
      // Remove duplicates
      final uniqueArticles = <String, Article>{};
      for (final article in allArticles) {
        uniqueArticles[article.sourceUrl] = article;
      }
      final finalArticles = uniqueArticles.values.toList();
      
      print('Total unique articles: ${finalArticles.length}');
      
      if (finalArticles.isNotEmpty) {
        await _cache.cacheArticles(finalArticles, isSearchResult: true);
        ref.read(discoverSearchProvider.notifier).state = finalArticles;
      } else {
        ref.read(discoverSearchProvider.notifier).state = [];
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No results found. Try a different search term.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('Search error: $e');
      ref.read(discoverSearchProvider.notifier).state = [];
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed: ${e.toString()}'),
            backgroundColor: AppColors.warning,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }
  
  Future<void> _pickImageAndExtractText() async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image == null) return;
      
      setState(() => _isProcessingImage = true);
      
      final extractedText = await _ocrService.extractTextFromImage(image.path);
      
      if (extractedText.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No text found in image'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
        setState(() => _isProcessingImage = false);
        return;
      }
      
      final summary = await _aiService.generateSummary(extractedText);
      final summarizedText = summary.join(' ');
      
      setState(() => _isProcessingImage = false);
      
      if (mounted) {
        _showExtractedTextDialog(extractedText, summarizedText);
      }
    } catch (e) {
      setState(() => _isProcessingImage = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing image: $e'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    }
  }
  
  void _showExtractedTextDialog(String extractedText, String summary) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Extracted Text'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Summary:', style: AppTextStyles.uiH3),
              const SizedBox(height: 8),
              Text(summary, style: AppTextStyles.uiBody),
              const SizedBox(height: 16),
              Text('Full Text:', style: AppTextStyles.uiH3),
              const SizedBox(height: 8),
              Text(extractedText, style: AppTextStyles.uiBody.copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: extractedText));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Text copied to clipboard'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('Copy Text'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _searchController.text = summary;
              _onSearch(summary);
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(discoverSearchProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isProcessingImage)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.image),
              tooltip: 'Upload image for OCR',
              onPressed: _pickImageAndExtractText,
            ),
        ],
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
                    hintText: 'Search articles...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(discoverSearchProvider.notifier).state = [];
                              setState(() => _showHistory = true);
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
                  onSubmitted: (value) => _onSearch(value),
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
                                await _historyService.clearDiscoverHistory();
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
                                  await _historyService.removeDiscoverHistory(query);
                                  await _loadSearchHistory();
                                },
                              ),
                              onTap: () {
                                _searchController.text = query;
                                _onSearch(query);
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
          
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = category == _selectedCategory;
                
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (_) => _onCategorySelected(category),
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
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSearching ? null : () {
                  final query = _searchController.text.trim();
                  if (query.isNotEmpty) {
                    _onSearch(query);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter a search query'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                icon: _isSearching 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.search),
                label: Text(_isSearching ? 'Searching...' : 'Search Web'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          Expanded(
            child: _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _buildArticleList(searchResults),
          ),
        ],
      ),
    );
  }
  
  Widget _buildArticleList(List<Article> articles) {
    if (articles.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.explore, size: 64, color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                _searchController.text.isNotEmpty 
                    ? 'No Results Found' 
                    : 'Explore Topics',
                style: AppTextStyles.uiH2,
              ),
              const SizedBox(height: 8),
              Text(
                _searchController.text.isNotEmpty
                    ? 'Try a different search term or explore topics below'
                    : 'Try searching for:',
                style: AppTextStyles.uiBody.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _buildSuggestionChip('Artificial Intelligence'),
                  _buildSuggestionChip('Quantum Computing'),
                  _buildSuggestionChip('Space Exploration'),
                  _buildSuggestionChip('Climate Change'),
                  _buildSuggestionChip('Biotechnology'),
                  _buildSuggestionChip('Renewable Energy'),
                  _buildSuggestionChip('Machine Learning'),
                  _buildSuggestionChip('Cybersecurity'),
                ],
              ),
            ],
          ),
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
    );
  }
  
  Widget _buildSuggestionChip(String topic) {
    return ActionChip(
      label: Text(topic),
      onPressed: () {
        _searchController.text = topic;
        _onSearch(topic);
      },
      backgroundColor: AppColors.primary.withOpacity(0.1),
      labelStyle: AppTextStyles.uiBody.copyWith(
        color: AppColors.primary,
      ),
    );
  }
}
