import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/cache_service.dart';
import '../../core/services/ai_service.dart';
import '../../core/services/article_scraper_service.dart';
import '../../core/services/tts_service.dart';
import '../../core/services/enhanced_ai_service.dart';
import '../../core/services/collections_service.dart';
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
  final EnhancedAIService _enhancedAI = EnhancedAIService();
  Article? _article;
  bool _isLoading = true;
  final bool _isLoadingContent = false;
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
    });
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
          onPageFinished: (url) {},
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
      const durationSec = 60; // Default 1 minute for opening
      await _cache.markAsRead(_article!.id, progress: 0.5, durationSec: durationSec);
      await _updateUserStats(durationSec, stars: 5);
      _hasUpdatedStats = true;
    }
  }

  Future<void> _extractArticleContent() async {
    if (_article == null) return;
    
    if (_article!.sourceUrl.contains('wikipedia.org')) {
      try {
        final content = await _extractWikipediaContent(_article!.sourceUrl);
        if (mounted && content.isNotEmpty) {
          setState(() => _articleContent = content);
          return;
        }
      } catch (e) {}
    }
    
    try {
      final content = await _scraper.scrapeArticle(_article!.sourceUrl);
      if (mounted) {
        setState(() {
          _articleContent = content.isNotEmpty ? content : '${_article!.title}. ${_article!.summary ?? ''}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _articleContent = '${_article!.title}. ${_article!.summary ?? ''}';
        });
      }
    }
  }
  
  Future<String> _extractWikipediaContent(String url) async {
    try {
      final uri = Uri.parse(url);
      final title = uri.pathSegments.last;
      final apiUrl = 'https://${uri.host}/w/api.php?action=query&format=json&prop=extracts&exintro=false&explaintext=true&titles=$title';
      
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final pages = data['query']['pages'] as Map<String, dynamic>;
        final page = pages.values.first;
        final extract = page['extract'] as String?;
        
        if (extract != null && extract.isNotEmpty) {
          return extract;
        }
      }
    } catch (e) {}
    
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
      
      String text = result.toString();
      text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
      
      if (text.isNotEmpty && text.length > 50) {
        print('Extracted ${text.length} characters from WebView');
        return text;
      }
        } catch (e) {
      print('WebView text extraction error: $e');
    }
    
    return '';
  }
  
  void _updateReadingProgress(double progress) {
    setState(() => _readingProgress = progress);
    
    if (progress >= 0.6 && _article != null) {
      final wasAlreadyRead = _article!.isRead;
      final durationSec = DateTime.now().difference(_startTime!).inSeconds;
      _cache.markAsRead(_article!.id, progress: progress, durationSec: durationSec);
      _article!.isRead = true;
      
      // Only update stats if article wasn't already read
      if (!wasAlreadyRead) {
        _updateUserStats(durationSec);
      }
    }
  }
  
  Future<void> _updateUserStats(int durationSec, {int stars = 1}) async {
    if (_article == null) return;
    
    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) return;
      
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'totalArticlesRead': FieldValue.increment(1),
        'totalReadingMinutes': FieldValue.increment((durationSec / 60).ceil()),
        'totalResearchPapersRead': _article!.contentType == 'research_paper' ? FieldValue.increment(1) : FieldValue.increment(0),
        'totalStars': FieldValue.increment(stars),
        'weeklyStars': FieldValue.increment(stars),
        'lastActiveAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {}
  }
  
  Future<void> _toggleTts() async {
    if (_articleContent == null || _articleContent!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading article content...'), duration: Duration(seconds: 2)),
      );
      return;
    }
    
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
      setState(() {
        _isTtsPlaying = true;
        _isTtsPaused = false;
      });
      _ttsService.speak(_articleContent!);
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
      setState(() {
        _isTtsSummaryPlaying = true;
        _isTtsSummaryPaused = false;
      });
      _ttsService.speak(summaryText);
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
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
                      icon: const Icon(Icons.folder_outlined),
                      onPressed: _showCollectionsDialog,
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
          color: Theme.of(context).cardColor,
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
                  Text('Share Article', style: AppTextStyles.uiH2.copyWith(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  )),
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
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Summary Options',
                    style: AppTextStyles.uiH2.copyWith(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose summary type',
                    style: AppTextStyles.uiCaption.copyWith(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _buildSummaryOption(
                    context,
                    icon: Icons.flash_on,
                    title: 'Quick Summary',
                    subtitle: '3-5 key points',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.pop(context);
                      _generateQuickSummary();
                    },
                  ),
                  _buildSummaryOption(
                    context,
                    icon: Icons.article,
                    title: 'Detailed Summary',
                    subtitle: 'Comprehensive overview',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(context);
                      _generateDetailedSummary();
                    },
                  ),
                  _buildSummaryOption(
                    context,
                    icon: Icons.lightbulb,
                    title: 'Key Points',
                    subtitle: 'Main takeaways',
                    color: Colors.amber,
                    onTap: () {
                      Navigator.pop(context);
                      _generateKeyPoints();
                    },
                  ),
                  _buildSummaryOption(
                    context,
                    icon: Icons.school,
                    title: 'Study Notes',
                    subtitle: 'Structured notes',
                    color: Colors.green,
                    onTap: () {
                      Navigator.pop(context);
                      _generateStudyNotes();
                    },
                  ),
                  _buildSummaryOption(
                    context,
                    icon: Icons.quiz,
                    title: 'Generate Quiz',
                    subtitle: 'Test your knowledge',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.pop(context);
                      _generateQuiz();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSummaryOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: AppTextStyles.uiBody.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: AppTextStyles.uiCaption.copyWith(
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
  
  Future<void> _generateQuickSummary() async {
    if (_articleContent == null || _articleContent!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading article content...'), duration: Duration(seconds: 2)),
      );
      return;
    }
    
    setState(() => _isLoadingSummary = true);
    try {
      final summary = await _enhancedAI.generateQuickSummary(_articleContent!);
      if (mounted) {
        setState(() {
          _summary = summary;
          _isLoadingSummary = false;
        });
        _showSummaryBottomSheet();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSummary = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), duration: const Duration(seconds: 3)),
        );
      }
    }
  }
  
  Future<void> _generateDetailedSummary() async {
    if (_articleContent == null || _articleContent!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading article content...'), duration: Duration(seconds: 2)),
      );
      return;
    }
    
    setState(() => _isLoadingSummary = true);
    try {
      final summary = await _enhancedAI.generateDetailedSummary(_articleContent!);
      if (mounted) {
        setState(() {
          _summary = [summary];
          _isLoadingSummary = false;
        });
        _showSummaryBottomSheet();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSummary = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), duration: const Duration(seconds: 3)),
        );
      }
    }
  }
  
  Future<void> _generateKeyPoints() async {
    if (_articleContent == null || _articleContent!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading article content...'), duration: Duration(seconds: 2)),
      );
      return;
    }
    
    setState(() => _isLoadingSummary = true);
    try {
      final points = await _enhancedAI.extractKeyPoints(_articleContent!);
      if (mounted) {
        setState(() {
          _summary = points;
          _isLoadingSummary = false;
        });
        _showSummaryBottomSheet();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSummary = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), duration: const Duration(seconds: 3)),
        );
      }
    }
  }
  
  Future<void> _generateStudyNotes() async {
    if (_articleContent == null || _articleContent!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading article content...'), duration: Duration(seconds: 2)),
      );
      return;
    }
    
    setState(() => _isLoadingSummary = true);
    try {
      final notes = await _enhancedAI.generateStudyNotes(_articleContent!);
      if (mounted) {
        setState(() {
          _summary = [notes];
          _isLoadingSummary = false;
        });
        _showSummaryBottomSheet();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSummary = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), duration: const Duration(seconds: 3)),
        );
      }
    }
  }
  
  Future<void> _generateQuiz() async {
    if (_articleContent == null || _articleContent!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading article content...'), duration: Duration(seconds: 2)),
      );
      return;
    }
    
    setState(() => _isLoadingSummary = true);
    try {
      final quiz = await _enhancedAI.generateQuiz(_articleContent!);
      if (mounted) {
        setState(() => _isLoadingSummary = false);
        if (quiz.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to generate quiz. Please try again.'), duration: Duration(seconds: 3)),
          );
        } else {
          _showQuizDialog(quiz);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingSummary = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate quiz: ${e.toString()}'), duration: const Duration(seconds: 3)),
        );
      }
    }
  }
  
  void _showQuizDialog(List<QuizQuestion> questions) {
    showDialog(
      context: context,
      builder: (context) => _QuizDialog(
        questions: questions,
        article: _article!,
      ),
    );
  }
  
  void _showCollectionsDialog() async {
    final cache = CacheService();
    final isar = await cache.getIsar();
    final collectionsService = CollectionsService(isar);
    final collections = await collectionsService.getAllCollections();
    
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
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
                  Text('Add to Collection', style: AppTextStyles.uiH2.copyWith(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  )),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: collections.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_outlined, size: 64, color: AppColors.textSecondary),
                          const SizedBox(height: 16),
                          Text(
                            'No collections yet',
                            style: AppTextStyles.uiBody.copyWith(
                              color: Theme.of(context).textTheme.bodyMedium?.color,
                            ),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              Navigator.pushNamed(context, '/collections');
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Create Collection'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: collections.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return ListTile(
                            leading: const Icon(Icons.add_circle, color: AppColors.primary),
                            title: const Text('Create New Collection'),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pushNamed(context, '/collections');
                            },
                          );
                        }
                        
                        final collection = collections[index - 1];
                        final isAdded = collection.articleIds.contains(_article!.id);
                        
                        return ListTile(
                          leading: Icon(
                            Icons.folder,
                            color: isAdded ? AppColors.primary : AppColors.textSecondary,
                          ),
                          title: Text(collection.name),
                          subtitle: Text('${collection.articleCount} articles'),
                          trailing: isAdded
                              ? const Icon(Icons.check_circle, color: AppColors.primary)
                              : null,
                          onTap: () async {
                            if (isAdded) {
                              await collectionsService.removeArticleFromCollection(
                                collection.collectionId,
                                _article!.id,
                              );
                            } else {
                              await collectionsService.addArticleToCollection(
                                collection.collectionId,
                                _article!.id,
                              );
                            }
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(isAdded ? 'Removed from collection' : 'Added to collection'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
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
            color: Theme.of(context).cardColor,
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
                          Text('AI Summary', style: AppTextStyles.uiH2.copyWith(
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          )),
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
                  color: AppColors.primary.withOpacity(0.1),
                  border: Border(top: BorderSide(color: AppColors.primary.withOpacity(0.3), width: 1)),
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


class _QuizDialog extends StatefulWidget {
  final List<QuizQuestion> questions;
  final Article article;
  
  const _QuizDialog({required this.questions, required this.article});
  
  @override
  State<_QuizDialog> createState() => _QuizDialogState();
}

class _QuizDialogState extends State<_QuizDialog> {
  int _currentQuestion = 0;
  String? _selectedAnswer;
  int _score = 0;
  bool _showResult = false;
  
  Future<void> _saveQuizResult() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      await FirebaseFirestore.instance.collection('quiz_results').add({
        'userId': user.uid,
        'articleId': widget.article.id,
        'articleTitle': widget.article.title,
        'articleUrl': widget.article.sourceUrl,
        'totalQuestions': widget.questions.length,
        'correctAnswers': _score,
        'completedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving quiz result: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_showResult) {
      return AlertDialog(
        title: const Text('Quiz Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events, size: 64, color: _score >= widget.questions.length * 0.7 ? Colors.amber : AppColors.primary),
            const SizedBox(height: 16),
            Text('Your Score: $_score/${widget.questions.length}', style: AppTextStyles.uiH2),
            const SizedBox(height: 8),
            Text('${((_score / widget.questions.length) * 100).toInt()}%', style: AppTextStyles.uiBody),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      );
    }
    
    final question = widget.questions[_currentQuestion];
    
    return AlertDialog(
      title: Text('Question ${_currentQuestion + 1}/${widget.questions.length}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(question.question, style: AppTextStyles.uiBody.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            ...['A', 'B', 'C', 'D'].asMap().entries.map((entry) {
              final letter = entry.key;
              final option = question.options[letter];
              final optionLetter = String.fromCharCode(65 + letter);
              
              return RadioListTile<String>(
                title: Text('$optionLetter) $option'),
                value: optionLetter,
                groupValue: _selectedAnswer,
                onChanged: (value) => setState(() => _selectedAnswer = value),
              );
            }).toList(),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _selectedAnswer == null ? null : () {
            if (_selectedAnswer == question.correctAnswer) {
              _score++;
            }
            
            if (_currentQuestion < widget.questions.length - 1) {
              setState(() {
                _currentQuestion++;
                _selectedAnswer = null;
              });
            } else {
              setState(() => _showResult = true);
              _saveQuizResult();
            }
          },
          child: Text(_currentQuestion < widget.questions.length - 1 ? 'Next' : 'Finish'),
        ),
      ],
    );
  }
}
