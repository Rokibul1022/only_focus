import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/cache_service.dart';
import '../../core/services/ai_service.dart';
import '../../core/services/article_scraper_service.dart';
import '../../core/services/tts_service.dart';
import '../../providers/auth_provider.dart';
import '../../data/models/article.dart';
import '../notes/note_editor_screen.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  final String? articleId;
  final Article? article;
  
  const ReaderScreen({
    super.key,
    this.articleId,
    this.article,
  });

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final CacheService _cache = CacheService();
  final AIService _aiService = AIService();
  final ArticleScraperService _scraper = ArticleScraperService();
  final TtsService _ttsService = TtsService();
  Article? _article;
  bool _isLoading = true;
  bool _isLoadingContent = false;
  double _readingProgress = 0.0;
  DateTime? _startTime;
  late WebViewController _webViewController;
  bool _isLoadingSummary = false;
  List<String>? _summary;
  bool _isTtsPlaying = false;
  bool _isTtsPaused = false;
  String? _articleContent;
  bool _isTtsSummaryPlaying = false;
  bool _isTtsSummaryPaused = false;
  bool _hasUpdatedStats = false;
  
  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _initWebView();
    _ttsService.initialize();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadArticle();
      _updateStatsOnOpen();
      _prepareArticleContentForTts();
    });
  }

  Future<void> _prepareArticleContentForTts() async {
    if (_article == null && widget.article != null) {
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    if (_article != null) {
      // Prepare content immediately using available data
      String content = _article!.title;
      
      if (_article!.summary != null && _article!.summary!.isNotEmpty) {
        content += '. ${_article!.summary}';
      }
      
      setState(() {
        _articleContent = content;
      });
      
      // Try to get more detailed content in background
      _extractArticleContent();
    }
  }
  
  @override
  void dispose() {
    _ttsService.stop();
    super.dispose();
  }
  
  void _initWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            print('Page loaded: $url');
            // Extract content after page loads
            _extractContentFromLoadedPage();
          },
        ),
      );
    
    _ttsService.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isTtsPlaying = false;
          _isTtsPaused = false;
          _isTtsSummaryPlaying = false;
          _isTtsSummaryPaused = false;
        });
      }
    });
  }

  Future<void> _extractContentFromLoadedPage() async {
    try {
      await Future.delayed(const Duration(seconds: 2)); // Wait for page to fully render
      
      final result = await _webViewController.runJavaScriptReturningResult(
        '''
        (function() {
          // Remove unwanted elements
          var toRemove = document.querySelectorAll('script, style, nav, header, footer, aside, iframe, .ad, .advertisement, .social-share, .comments, .related-articles');
          toRemove.forEach(function(el) { if(el.parentNode) el.parentNode.removeChild(el); });
          
          // Try to find main content
          var selectors = [
            'article',
            '[role="main"]',
            'main',
            '.article-content',
            '.post-content',
            '.entry-content',
            '.article-body',
            '.story-body',
            '#article-body',
            '.content'
          ];
          
          var content = '';
          for (var i = 0; i < selectors.length; i++) {
            var element = document.querySelector(selectors[i]);
            if (element) {
              var paragraphs = element.querySelectorAll('p');
              if (paragraphs.length > 0) {
                var texts = [];
                paragraphs.forEach(function(p) {
                  var text = p.innerText || p.textContent;
                  if (text && text.trim().length > 50) {
                    texts.push(text.trim());
                  }
                });
                content = texts.join(' ');
                if (content.length > 500) {
                  return content;
                }
              }
            }
          }
          
          // Fallback: get all paragraphs
          if (!content || content.length < 500) {
            var allP = document.querySelectorAll('p');
            var texts = [];
            allP.forEach(function(p) {
              var text = p.innerText || p.textContent;
              if (text && text.trim().length > 50) {
                texts.push(text.trim());
              }
            });
            content = texts.join(' ');
          }
          
          return content || '';
        })();
        '''
      );
      
      if (result != null) {
        String extractedText = result.toString();
        // Clean up the text
        extractedText = extractedText
            .replaceAll(RegExp(r'\s+'), ' ')
            .replaceAll(RegExp(r'[\n\r]+'), ' ')
            .trim();
        
        if (extractedText.isNotEmpty && extractedText.length > 100) {
          setState(() {
            _articleContent = extractedText;
          });
          print('Extracted ${extractedText.length} characters from page');
        } else {
          print('Extracted text too short: ${extractedText.length} characters');
        }
      }
    } catch (e) {
      print('Error extracting content from page: $e');
    }
  }
  
  Future<void> _loadArticle() async {
    try {
      if (widget.article != null) {
        await _cache.cacheArticles([widget.article!]);
        if (mounted) {
          setState(() {
            _article = widget.article;
            _isLoading = false;
          });
        }
        await _webViewController.loadRequest(Uri.parse(_article!.sourceUrl));
        _extractArticleContent();
        return;
      }
      
      if (widget.articleId != null) {
        final article = await _cache.getArticleById(widget.articleId!);
        if (article != null) {
          if (mounted) {
            setState(() {
              _article = article;
              _isLoading = false;
            });
          }
          await _webViewController.loadRequest(Uri.parse(_article!.sourceUrl));
          _extractArticleContent();
          return;
        }
      }
      
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _updateStatsOnOpen() async {
    if (_article == null && widget.article != null) {
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    if (_article != null && !_hasUpdatedStats) {
      final durationSec = 60; // Default 1 minute for opening
      await _cache.markAsRead(_article!.id, progress: 0.5, durationSec: durationSec);
      await _updateUserStats(durationSec, stars: 5);
      _hasUpdatedStats = true;
    }
  }

  Future<void> _extractArticleContent() async {
    if (_article == null) return;
    
    // Only try to get enhanced content for Wikipedia
    if (_article!.sourceUrl.contains('wikipedia.org')) {
      try {
        final content = await _extractWikipediaContent(_article!.sourceUrl);
        if (mounted && content.isNotEmpty && content.length > 100) {
          setState(() => _articleContent = content);
        }
      } catch (e) {
        print('Wikipedia extraction failed: $e');
      }
    }
  }
  
  Future<String> _extractWikipediaContent(String url) async {
    try {
      final uri = Uri.parse(url);
      final title = uri.pathSegments.last;
      final decodedTitle = Uri.decodeComponent(title);
      final apiUrl = 'https://${uri.host}/w/api.php?action=query&format=json&prop=extracts&exintro=false&explaintext=true&titles=${Uri.encodeComponent(decodedTitle)}';
      
      print('Fetching Wikipedia content from: $apiUrl');
      
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final pages = data['query']['pages'] as Map<String, dynamic>;
        final page = pages.values.first;
        final extract = page['extract'] as String?;
        
        if (extract != null && extract.isNotEmpty) {
          print('Wikipedia content extracted: ${extract.length} characters');
          return extract;
        }
      }
    } catch (e) {
      print('Wikipedia extraction error: $e');
    }
    
    return '';
  }

  Future<String> _extractTextFromWebView() async {
    try {
      final result = await _webViewController.runJavaScriptReturningResult(
        '''
        (function() {
          var unwanted = document.querySelectorAll('script, style, nav, header, footer, aside, .ad, .advertisement, .social-share, button, .menu, .navigation');
          unwanted.forEach(function(el) { el.remove(); });
          
          var content = '';
          var selectors = ['article', '[role="main"]', 'main', '.article-content', '.post-content', '.entry-content', '#content', '.content'];
          
          for (var i = 0; i < selectors.length; i++) {
            var element = document.querySelector(selectors[i]);
            if (element) {
              content = element.innerText || element.textContent;
              if (content.length > 200) {
                return content.trim();
              }
            }
          }
          
          var body = document.querySelector('body');
          if (body) {
            content = body.innerText || body.textContent;
            return content.trim();
          }
          
          return '';
        })();
        '''
      );
      
      if (result != null) {
        String text = result.toString();
        text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
        
        if (text.isNotEmpty && text.length > 50) {
          print('Extracted ${text.length} characters from WebView');
          return text;
        }
      }
    } catch (e) {
      print('WebView text extraction error: $e');
    }
    
    return '';
  }
  
  void _updateReadingProgress(double progress) {
    setState(() => _readingProgress = progress);
  }
  
  Future<void> _updateUserStats(int durationSec, {required int stars}) async {
    if (_article == null) return;
    
    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) return;
      
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'totalArticlesRead': FieldValue.increment(1),
        'totalReadingMinutes': FieldValue.increment((durationSec / 60).ceil()),
        'totalStars': FieldValue.increment(stars),
        'weeklyStars': FieldValue.increment(stars),
        'lastActiveAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {}
  }
  
  Future<void> _toggleTts() async {
    if (_isTtsSummaryPlaying) {
      await _ttsService.stop();
      setState(() {
        _isTtsSummaryPlaying = false;
        _isTtsSummaryPaused = false;
      });
    }
    
    if (_isTtsPlaying) {
      if (_isTtsPaused) {
        await _ttsService.resume();
        setState(() => _isTtsPaused = false);
      } else {
        await _ttsService.pause();
        setState(() => _isTtsPaused = true);
      }
    } else {
      // Check if we have extracted content
      if (_articleContent == null || _articleContent!.isEmpty || _articleContent!.length < 100) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Extracting article content, please wait...'),
            duration: Duration(seconds: 2),
          ),
        );
        
        // Try to extract again
        await _extractContentFromLoadedPage();
        
        // Wait a bit for extraction
        await Future.delayed(const Duration(seconds: 1));
        
        if (_articleContent == null || _articleContent!.isEmpty || _articleContent!.length < 100) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not extract article content. The page may not be fully loaded.'),
              duration: Duration(seconds: 3),
            ),
          );
          return;
        }
      }
      
      print('TTS: Reading ${_articleContent!.length} characters');
      await _ttsService.speak(_articleContent!);
      setState(() {
        _isTtsPlaying = true;
        _isTtsPaused = false;
      });
    }
  }
  
  Future<void> _toggleTtsSummary() async {
    if (_summary == null || _summary!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generate summary first'), duration: Duration(seconds: 2)),
      );
      return;
    }
    
    if (_isTtsSummaryPlaying) {
      if (_isTtsSummaryPaused) {
        await _ttsService.resume();
        setState(() => _isTtsSummaryPaused = false);
      } else {
        await _ttsService.pause();
        setState(() => _isTtsSummaryPaused = true);
      }
    } else {
      if (_isTtsPlaying) {
        await _ttsService.stop();
        setState(() {
          _isTtsPlaying = false;
          _isTtsPaused = false;
        });
      }
      
      final summaryText = _summary!.asMap().entries.map((e) => '${e.key + 1}. ${e.value}').join('. ');
      await _ttsService.speak(summaryText);
      setState(() {
        _isTtsSummaryPlaying = true;
        _isTtsSummaryPaused = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    if (_article == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
          title: const Text('Article Not Found'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.warning),
              const SizedBox(height: 16),
              const Text('Article not found'),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Go Back')),
            ],
          ),
        ),
      );
    }
    
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(
              value: _readingProgress,
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
            
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.note_add),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NoteEditorScreen(
                            articleId: _article!.id,
                            articleTitle: _article!.title,
                            articleUrl: _article!.sourceUrl,
                          ),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(_isTtsPlaying ? (_isTtsPaused ? Icons.play_arrow : Icons.pause) : Icons.volume_up),
                    onPressed: _toggleTts,
                  ),
                  IconButton(
                    icon: const Icon(Icons.summarize),
                    onPressed: _isLoadingSummary ? null : _showAISummary,
                  ),
                  IconButton(
                    icon: Icon(
                      _article!.isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
                      color: _article!.isBookmarked ? AppColors.primary : null,
                    ),
                    onPressed: () async {
                      await _cache.toggleBookmark(_article!.id);
                      final updated = await _cache.getArticleById(_article!.id);
                      if (updated != null && mounted) {
                        setState(() => _article = updated);
                      }
                    },
                  ),
                  IconButton(icon: const Icon(Icons.share), onPressed: _showShareDialog),
                ],
              ),
            ),
            
            Expanded(
              child: WebViewWidget(controller: _webViewController),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showShareDialog() {
    if (_article == null) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Share Article', style: AppTextStyles.uiH2),
                  const SizedBox(height: 20),
                  ListTile(
                    leading: const Icon(Icons.copy, color: AppColors.primary),
                    title: const Text('Copy Link'),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: _article!.sourceUrl));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Link copied to clipboard'), duration: Duration(seconds: 2)),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.open_in_browser, color: AppColors.primary),
                    title: const Text('Open in Browser'),
                    onTap: () async {
                      Navigator.pop(context);
                      if (await canLaunchUrl(Uri.parse(_article!.sourceUrl))) {
                        await launchUrl(Uri.parse(_article!.sourceUrl), mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _showAISummary() async {
    if (_article == null) return;
    
    setState(() => _isLoadingSummary = true);
    
    try {
      final articleText = '${_article!.title}. ${_article!.summary ?? ''}';
      final summary = await _aiService.generateSummary(articleText);
      
      if (mounted) {
        setState(() {
          _summary = summary;
          _isLoadingSummary = false;
        });
        _showSummaryBottomSheet();
      }
    } catch (e) {
      setState(() => _isLoadingSummary = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate summary: ${e.toString()}'), backgroundColor: AppColors.warning),
        );
      }
    }
  }
  
  void _showSummaryBottomSheet() {
    if (_summary == null || _summary!.isEmpty) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.auto_awesome, color: AppColors.accent, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('AI Summary', style: AppTextStyles.uiH2),
                          Text(
                            'Key takeaways from this article',
                            style: AppTextStyles.uiCaption.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isTtsSummaryPlaying ? (_isTtsSummaryPaused ? Icons.play_arrow : Icons.pause) : Icons.volume_up,
                        color: _isTtsSummaryPlaying ? AppColors.primary : null,
                      ),
                      onPressed: () async {
                        await _toggleTtsSummary();
                        setModalState(() {});
                        setState(() {});
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        if (_isTtsSummaryPlaying) {
                          _ttsService.stop();
                          setState(() {
                            _isTtsSummaryPlaying = false;
                            _isTtsSummaryPaused = false;
                          });
                        }
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _summary!.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${index + 1}',
                                style: AppTextStyles.uiBody.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _summary![index],
                              style: AppTextStyles.uiBody.copyWith(
                                height: 1.5,
                                color: Theme.of(context).textTheme.bodyLarge?.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  border: Border(top: BorderSide(color: Theme.of(context).dividerColor, width: 1)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'AI-powered summary',
                      style: AppTextStyles.uiCaption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      if (_isTtsSummaryPlaying) {
        _ttsService.stop();
        setState(() {
          _isTtsSummaryPlaying = false;
          _isTtsSummaryPaused = false;
        });
      }
    });
  }
}
