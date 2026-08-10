import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/ocr_service.dart';
import '../../core/services/chat_history_service.dart';
import '../../core/services/tts_service.dart';
import '../../core/services/backend_api_service.dart';
import '../../core/services/niko_sync_service.dart';
import 'dart:io';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AIChatScreen extends ConsumerStatefulWidget {
  const AIChatScreen({super.key});

  @override
  ConsumerState<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends ConsumerState<AIChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final ImagePicker _imagePicker = ImagePicker();
  final OcrService _ocrService = OcrService();
  final ChatHistoryService _historyService = ChatHistoryService();
  final TtsService _ttsService = TtsService();
  final FlutterSoundRecorder _audioRecorder = FlutterSoundRecorder();
  final BackendApiService _backend = BackendApiService();
  final NikoSyncService _nikoSync = NikoSyncService();
  final String _userId = FirebaseAuth.instance.currentUser?.uid ?? 'default';
  bool _isLoading = false;
  bool _isRecording = false;
  File? _selectedFile;
  String? _selectedFileName;
  String _currentChatId = const Uuid().v4();
  String _currentChatTitle = 'New Chat';
  String? _speakingMessageId;
  bool _isPaused = false;
  bool _isStreaming = false;
  String? _recordingPath;
  List<Map<String, dynamic>> _documents = [];
  List<Map<String, dynamic>> _memories = [];
  bool _docsLoading = false;

  @override
  void initState() {
    super.initState();
    _initServices();
    _syncNikoKnowledge();
    _loadNikoData();
    _messages.add(ChatMessage(
      text: 'Hi, I\'m Niko - your AI learning companion. I remember our conversations, and I can search your saved articles and files. Ask me anything, or upload a document for me to learn from!',
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  Future<void> _loadNikoData() async {
    await _loadDocuments();
    await _loadMemories();
  }

  Future<void> _loadDocuments() async {
    if (_docsLoading) return;
    setState(() => _docsLoading = true);
    try {
      final docs = await _backend.nikoDocuments(userId: _userId);
      if (mounted) setState(() => _documents = docs);
    } catch (e) {
      print('Niko docs load failed: $e');
    } finally {
      if (mounted) setState(() => _docsLoading = false);
    }
  }

  Future<void> _loadMemories() async {
    try {
      final mems = await _backend.nikoMemories(userId: _userId);
      if (mounted) setState(() => _memories = mems);
    } catch (e) {
      print('Niko memory load failed: $e');
    }
  }

  Future<void> _deleteDocument(Map<String, dynamic> doc) async {
    try {
      await _backend.nikoDeleteDocument(doc['doc_id'] as String);
      await _loadDocuments();
    } catch (e) {
      print('Niko doc delete failed: $e');
    }
  }

  Future<void> _deleteMemory(String memoryId) async {
    try {
      await _backend.nikoDeleteMemory(memoryId);
      await _loadMemories();
    } catch (e) {
      print('Niko memory delete failed: $e');
    }
  }

  void _askAboutDocument(Map<String, dynamic> doc) {
    _messageController.text = 'Summarize the document "${doc['title']}" for me.';
    _sendMessage();
  }

  void _showMemorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
                ),
                child: Row(
                  children: [
                    const Text('Niko\'s Long-Term Memory', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _loadMemories,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _memories.isEmpty
                    ? const Center(child: Text('No memories yet. Chat with Niko and it will start remembering you.'))
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _memories.length,
                        itemBuilder: (context, index) {
                          final mem = _memories[index];
                          return ListTile(
                            leading: Icon(
                              mem['kind'] == 'preference'
                                  ? Icons.favorite_outline
                                  : mem['kind'] == 'goal'
                                      ? Icons.flag_outlined
                                      : Icons.lightbulb_outline,
                              color: AppColors.primary,
                            ),
                            title: Text(mem['text'] as String? ?? ''),
                            subtitle: Text('${mem['kind']}  \u00b7  importance ${mem['importance']}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () => _deleteMemory(mem['id'] as String),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _syncNikoKnowledge() async {
    try {
      final count = await _nikoSync.syncBookmarks();
      print('Niko synced $count saved article(s) for user $_userId');
    } catch (e) {
      print('Niko knowledge sync failed: $e');
    }
  }

  Future<void> _initServices() async {
    await _historyService.init();
    await _audioRecorder.openRecorder();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _ocrService.dispose();
    _audioRecorder.closeRecorder();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _selectedFile == null) return;
    if (_isStreaming) return;

    String messageText = text;
    bool uploading = false;
    bool visionImage = false;
    String? pickedPath;
    String? pickedName;
    String? visionOcrFallback;
    String? imageData;
    
    // If file is selected, extract text from it
    if (_selectedFile != null) {
      pickedPath = _selectedFile!.path;
      pickedName = _selectedFileName;
      final name = (_selectedFileName ?? '').toLowerCase();
      if (name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.png')) {
        // Image: let Niko see it via the vision endpoint. Pre-extract OCR text
        // as a fallback in case the vision model is unavailable.
        visionImage = true;
        messageText = text;
        try {
          final bytes = await _selectedFile!.readAsBytes();
          if (bytes.isNotEmpty) {
            imageData = base64Encode(bytes);
          }
        } catch (e) {
          print('Image bytes error: $e');
        }
        try {
          visionOcrFallback = await _ocrService.extractTextFromImage(_selectedFile!.path);
        } catch (e) {
          print('OCR pre-extract error: $e');
        }
      } else {
        // Document (PDF/TXT/DOCX/...): upload and index into Niko's knowledge base
        uploading = true;
        messageText = text.isEmpty
            ? 'I just uploaded a document ($pickedName). What does it cover?'
            : text;
      }
    }

    final userMessage = ChatMessage(
      text: messageText,
      isUser: true,
      timestamp: DateTime.now(),
      fileName: pickedName,
      imageData: imageData,
    );

    setState(() {
      _messages.add(userMessage);
      _messageController.clear();
      _selectedFile = null;
      _selectedFileName = null;
      _isLoading = true;
    });

    _scrollToBottom();

    // Upload + index the document before chatting about it
    if (uploading && pickedPath != null && pickedName != null) {
      try {
        await _backend.nikoUploadFile(
          filePath: pickedPath,
          fileName: pickedName,
          title: pickedName,
          userId: _userId,
        );
        await _loadDocuments();
      } catch (e) {
        print('Niko upload error: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not index the file: $e')),
        );
      }
    }

    // Image: send it to Niko's vision endpoint (OCR fallback if it fails).
    if (visionImage && pickedPath != null && pickedName != null) {
      await _analyzeImage(pickedPath, pickedName, text, visionOcrFallback);
      _saveCurrentChat();
      _scrollToBottom();
      return;
    }

    try {
      await _streamResponse();
      if (_messages.where((m) => m.isUser).length == 1) {
        _currentChatTitle = text.length > 30 ? '${text.substring(0, 30)}...' : text;
      }
      _saveCurrentChat();
      _scrollToBottom();
    } catch (e) {
      // Fallback to the non-streaming endpoint, then give up.
      print('Niko stream failed, falling back: $e');
      await _sendNonStreaming();
    }
  }

  Future<void> _analyzeImage(
    String path,
    String name,
    String prompt,
    String? ocrFallback,
  ) async {
    try {
      final result = await _backend.nikoVisionAnalysis(
        filePath: path,
        fileName: name,
        message: prompt,
        sessionId: _currentChatId,
        userId: _userId,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
          text: result['reply'] as String,
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
      return;
    } catch (e) {
      print('Niko vision failed, OCR fallback: $e');
    }

    // Fallback: inject OCR text and use the normal chat pipeline.
    final ocr = ocrFallback?.trim() ?? '';
    final fallbackText = ocr.isNotEmpty
        ? (prompt.isEmpty ? 'Analyze this image: $ocr' : '$prompt\n\nImage content: $ocr')
        : (prompt.isEmpty ? 'Describe what you see in this image' : prompt);

    if (mounted && _messages.isNotEmpty && _messages.last.isUser) {
      setState(() => _messages.last.text = fallbackText);
    }
    try {
      await _streamResponse();
    } catch (e) {
      print('Niko OCR fallback stream failed: $e');
      await _sendNonStreaming();
    }
  }

  Future<void> _streamResponse() async {
    setState(() {
      _isStreaming = true;
      _isLoading = false;
    });

    String buffer = '';
    ChatMessage? streamingMsg;
    List<String> citedSources = [];
    try {
      final payload = _messages.map((msg) => {
        'role': msg.isUser ? 'user' : 'assistant',
        'content': msg.text,
      }).toList();

      await for (final event in _backend.nikoChatStream(
        messages: payload,
        sessionId: _currentChatId,
        userId: _userId,
      )) {
        if (event.type == 'token') {
          buffer += event.content;
          if (buffer.isEmpty) continue;
          setState(() {
            if (streamingMsg == null || !_messages.contains(streamingMsg)) {
              streamingMsg = ChatMessage(
                text: buffer,
                isUser: false,
                timestamp: DateTime.now(),
              );
              _messages.add(streamingMsg!);
            } else {
              streamingMsg!.text = buffer;
            }
          });
          _scrollToBottom();
        } else if (event.type == 'done') {
          citedSources = event.sources.map((s) => s['title'] ?? '').where((t) => t.isNotEmpty).toList();
        } else if (event.type == 'error') {
          throw Exception(event.content.isNotEmpty ? event.content : 'Stream error');
        }
      }

      if (buffer.isEmpty) {
        throw Exception('No response from Niko');
      }
      if (streamingMsg != null && citedSources.isNotEmpty) {
        setState(() => streamingMsg!.sources = citedSources);
      }
    } finally {
      if (mounted) setState(() => _isStreaming = false);
    }
  }

  Future<void> _sendNonStreaming() async {
    for (int retry = 0; retry < 3; retry++) {
      try {
        final payload = _messages.map((msg) => {
          'role': msg.isUser ? 'user' : 'assistant',
          'content': msg.text,
        }).toList();

        final result = await _backend.nikoChat(
          messages: payload,
          sessionId: _currentChatId,
          userId: _userId,
        );

        setState(() {
          _messages.add(ChatMessage(
            text: result.reply,
            isUser: false,
            timestamp: DateTime.now(),
            sources: result.sources.map((s) => s['title'] ?? '').where((t) => t.isNotEmpty).toList(),
          ));
          _isLoading = false;
        });

        _saveCurrentChat();
        _scrollToBottom();
        return;
      } catch (e) {
        print('Niko chat error: $e');
      }

      if (retry < 2) {
        await Future.delayed(Duration(seconds: (retry + 1) * 2));
      }
    }

    setState(() {
      if (_messages.isEmpty || !_messages.last.isUser) {
        _messages.add(ChatMessage(
          text: 'Niko is not reachable right now. Make sure the backend is running (${BackendApiService.baseUrl}) and try again.',
          isUser: false,
          timestamp: DateTime.now(),
        ));
      }
      _isLoading = false;
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickImage() async {
    final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedFile = File(image.path);
        _selectedFileName = image.name;
      });
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _selectedFileName = result.files.single.name;
        });
      }
    } catch (e) {
      print('File picker error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
    }
  }

  void _clearChat() {
    setState(() {
      _messages.clear();
      _messages.add(ChatMessage(
        text: 'Chat cleared. How can I help you?',
        isUser: false,
        timestamp: DateTime.now(),
      ));
      _currentChatId = const Uuid().v4();
      _currentChatTitle = 'New Chat';
    });
  }

  void _saveCurrentChat() {
    final session = ChatSession(
      id: _currentChatId,
      title: _currentChatTitle,
      lastUpdated: DateTime.now(),
      messages: _messages.map((m) => {
        'text': m.text,
        'isUser': m.isUser,
        'timestamp': m.timestamp.toIso8601String(),
        'fileName': m.fileName,
        'imageData': m.imageData,
        'sources': m.sources,
      }).toList(),
    );
    _historyService.saveChat(session);
  }

  void _loadChat(ChatSession session) {
    setState(() {
      _currentChatId = session.id;
      _currentChatTitle = session.title;
      _messages.clear();
      _messages.addAll(session.messages.map((m) => ChatMessage(
        text: m['text'] as String,
        isUser: m['isUser'] as bool,
        timestamp: DateTime.parse(m['timestamp'] as String),
        fileName: m['fileName'] as String?,
        imageData: m['imageData'] as String?,
        sources: (m['sources'] as List?)?.map((s) => s.toString()).toList() ?? const [],
      )));
    });
    Navigator.pop(context);
    _scrollToBottom();
  }

  void _deleteChat(String id) {
    _historyService.deleteChat(id);
    if (id == _currentChatId) {
      _clearChat();
    }
    setState(() {});
  }

  void _showHistoryDrawer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
                ),
                child: Row(
                  children: [
                    const Text('Chat History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _historyService.getAllChats().length,
                  itemBuilder: (context, index) {
                    final chat = _historyService.getAllChats()[index];
                    final isActive = chat.id == _currentChatId;
                    return ListTile(
                      leading: Icon(
                        Icons.chat_bubble_outline,
                        color: isActive ? AppColors.primary : null,
                      ),
                      title: Text(
                        chat.title,
                        style: TextStyle(
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          color: isActive ? AppColors.primary : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        _formatDate(chat.lastUpdated),
                        style: AppTextStyles.uiCaption,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () {
                          _deleteChat(chat.id);
                          Navigator.pop(context);
                          _showHistoryDrawer();
                        },
                      ),
                      onTap: () => _loadChat(chat),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  void _copyText(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 1)),
    );
  }

  Future<void> _startRecording() async {
    try {
      final status = await Permission.microphone.request();
      if (status.isGranted) {
        _recordingPath = '${Directory.systemTemp.path}/audio_${DateTime.now().millisecondsSinceEpoch}.wav';
        await _audioRecorder.startRecorder(
          toFile: _recordingPath,
          codec: Codec.pcm16WAV,
        );
        setState(() => _isRecording = true);
      }
    } catch (e) {
      print('Recording error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recording error: $e')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _audioRecorder.stopRecorder();
      setState(() => _isRecording = false);
      
      if (_recordingPath != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Audio recorded. Speech-to-text not available.'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Stop recording error: $e');
      setState(() {
        _isRecording = false;
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _speakText(String text, String messageId) async {
    if (_speakingMessageId == messageId) {
      if (_isPaused) {
        await _ttsService.resume();
        setState(() => _isPaused = false);
      } else {
        await _ttsService.pause();
        setState(() => _isPaused = true);
      }
    } else {
      await _ttsService.stop();
      setState(() {
        _speakingMessageId = messageId;
        _isPaused = false;
      });
      
      _ttsService.speak(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Niko'),
        actions: [
          IconButton(
            icon: const Icon(Icons.psychology_outlined),
            tooltip: 'Niko\'s memory',
            onPressed: _showMemorySheet,
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'Chat history',
            onPressed: _showHistoryDrawer,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New chat',
            onPressed: _clearChat,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_documents.isNotEmpty)
            _buildDocsSlider(),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isLoading) {
                  return _buildTypingIndicator();
                }
                return _buildMessageBubble(_messages[index]);
              },
            ),
          ),
          if (_selectedFileName != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.primary.withOpacity(0.1),
              child: Row(
                children: [
                  const Icon(Icons.attach_file, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedFileName!,
                      style: AppTextStyles.uiCaption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () {
                      setState(() {
                        _selectedFile = null;
                        _selectedFileName = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                  onPressed: _isRecording ? _stopRecording : _startRecording,
                  tooltip: _isRecording ? 'Stop recording' : 'Record audio',
                  color: _isRecording ? Colors.red : null,
                ),
                IconButton(
                  icon: const Icon(Icons.image_outlined),
                  onPressed: _pickImage,
                  tooltip: 'Upload image',
                ),
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  onPressed: _pickFile,
                  tooltip: 'Upload file',
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Ask me anything...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Theme.of(context).dividerColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Theme.of(context).dividerColor),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).scaffoldBackgroundColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: (_isLoading || _isStreaming) ? null : _sendMessage,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocsSlider() {
    return Container(
      height: 74,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _documents.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text(
                  'My docs',
                  style: AppTextStyles.uiCaption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }
          final doc = _documents[index - 1];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _askAboutDocument(doc),
              onLongPress: () => _confirmDeleteDocument(doc),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.description_outlined, size: 18, color: AppColors.primary),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(
                        doc['title'] as String? ?? 'Document',
                        style: AppTextStyles.uiCaption,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${doc['chunks']}',
                      style: AppTextStyles.uiCaption.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteDocument(Map<String, dynamic> doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete document?'),
        content: Text('Remove "${doc['title']}" from Niko\'s knowledge base?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _deleteDocument(doc);
    }
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final messageId = '${message.timestamp.millisecondsSinceEpoch}';
    final isSpeaking = _speakingMessageId == messageId;
    final isCurrentlyPaused = isSpeaking && _isPaused;

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: message.isUser 
              ? AppColors.primary 
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message.imageData != null && message.imageData!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    base64Decode(message.imageData!),
                    width: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            if (message.fileName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.attach_file,
                      size: 16,
                      color: message.isUser ? Colors.white70 : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        message.fileName!,
                        style: AppTextStyles.uiCaption.copyWith(
                          color: message.isUser ? Colors.white70 : AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              message.text,
              style: AppTextStyles.uiBody.copyWith(
                color: message.isUser ? Colors.white : null,
              ),
            ),
            if (!message.isUser && message.sources.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: message.sources.take(4).map((source) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.menu_book, size: 12, color: AppColors.primary),
                        const SizedBox(width: 4),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 140),
                          child: Text(
                            source,
                            style: AppTextStyles.uiCaption.copyWith(color: AppColors.primary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              ),
            if (!message.isUser)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () => _copyText(message.text),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.copy,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _speakText(message.text, messageId),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          isCurrentlyPaused ? Icons.play_arrow : (isSpeaking ? Icons.pause : Icons.volume_up),
                          size: 16,
                          color: isSpeaking ? AppColors.primary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    if (isSpeaking) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () async {
                          await _ttsService.stop();
                          setState(() {
                            _speakingMessageId = null;
                            _isPaused = false;
                          });
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.stop,
                            size: 16,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(0),
            const SizedBox(width: 4),
            _buildDot(1),
            const SizedBox(width: 4),
            _buildDot(2),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        return Opacity(
          opacity: (value + index * 0.3) % 1.0,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.textSecondary,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

class ChatMessage {
  String text;
  final bool isUser;
  final DateTime timestamp;
  final String? fileName;
  String? imageData;
  List<String> sources;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.fileName,
    this.imageData,
    this.sources = const [],
  });
}
