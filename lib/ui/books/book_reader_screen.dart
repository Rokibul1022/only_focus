import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/tts_service.dart';
import '../../core/services/enhanced_ai_service.dart';
import '../../data/models/book.dart';
import '../notes/note_editor_screen.dart';

class BookReaderScreen extends ConsumerStatefulWidget {
  final Book book;
  
  const BookReaderScreen({super.key, required this.book});

  @override
  ConsumerState<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends ConsumerState<BookReaderScreen> {
  final TtsService _ttsService = TtsService();
  final EnhancedAIService _enhancedAI = EnhancedAIService();
  late WebViewController _webViewController;
  bool _isLoadingSummary = false;
  List<String>? _summary;
  bool _isTtsPlaying = false;
  bool _isTtsPaused = false;
  bool _isTtsSummaryPlaying = false;
  bool _isTtsSummaryPaused = false;
  String? _bookContent;
  
  @override
  void initState() {
    super.initState();
    _initWebView();
    _ttsService.initialize();
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
            _extractBookContent();
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
    
    _loadBook();
  }
  
  Future<void> _loadBook() async {
    final bookUrl = 'https://openlibrary.org/works/${widget.book.id}';
    await _webViewController.loadRequest(Uri.parse(bookUrl));
  }
  
  Future<void> _extractBookContent() async {
    try {
      final content = await _webViewController.runJavaScriptReturningResult(
        'document.body.innerText',
      );
      if (mounted && content != null) {
        setState(() {
          _bookContent = content.toString().replaceAll('"', '');
        });
      }
    } catch (e) {
      print('Error extracting content: $e');
    }
  }
  
  Future<void> _toggleTts() async {
    if (_bookContent == null || _bookContent!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading book content...'), duration: Duration(seconds: 2)),
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
      _ttsService.speak(_bookContent!);
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
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.note_add),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => NoteEditorScreen(
                              articleId: widget.book.id,
                              articleTitle: widget.book.title,
                              articleUrl: 'https://openlibrary.org/works/${widget.book.id}',
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
                      icon: const Icon(Icons.share),
                      onPressed: _showShareDialog,
                    ),
                    IconButton(
                      icon: const Icon(Icons.open_in_browser),
                      onPressed: () async {
                        final url = 'https://openlibrary.org/works/${widget.book.id}';
                        if (await canLaunchUrl(Uri.parse(url))) {
                          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
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
                  Text('Share Book', style: AppTextStyles.uiH2),
                  const SizedBox(height: 20),
                  ListTile(
                    leading: const Icon(Icons.copy, color: AppColors.primary),
                    title: const Text('Copy Link'),
                    onTap: () {
                      final url = 'https://openlibrary.org/works/${widget.book.id}';
                      Clipboard.setData(ClipboardData(text: url));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Link copied'), duration: Duration(seconds: 2)),
                      );
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
  
  Future<void> _showAISummary() async {
    if (_bookContent == null || _bookContent!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading book content...'), duration: Duration(seconds: 2)),
      );
      return;
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.4,
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
              child: Text('AI Summary Options', style: AppTextStyles.uiH2),
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
        title: Text(title, style: AppTextStyles.uiBody.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: AppTextStyles.uiCaption),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
  
  Future<void> _generateQuickSummary() async {
    setState(() => _isLoadingSummary = true);
    try {
      final summary = await _enhancedAI.generateQuickSummary(_bookContent!);
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
    setState(() => _isLoadingSummary = true);
    try {
      final summary = await _enhancedAI.generateDetailedSummary(_bookContent!);
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
    setState(() => _isLoadingSummary = true);
    try {
      final points = await _enhancedAI.extractKeyPoints(_bookContent!);
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
                          Text('AI Summary', style: AppTextStyles.uiH2),
                          Text('Key takeaways', style: AppTextStyles.uiCaption.copyWith(color: AppColors.textSecondary)),
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
                              style: AppTextStyles.uiBody.copyWith(height: 1.5),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
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
