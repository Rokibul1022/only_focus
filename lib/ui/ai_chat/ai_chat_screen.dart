import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/services/ocr_service.dart';
import '../../core/services/chat_history_service.dart';
import '../../core/services/tts_service.dart';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

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
  final Dio _dio = Dio();
  bool _isLoading = false;
  bool _isRecording = false;
  File? _selectedFile;
  String? _selectedFileName;
  String _currentChatId = const Uuid().v4();
  String _currentChatTitle = 'New Chat';
  String? _speakingMessageId;
  bool _isPaused = false;
  String? _recordingPath;

  @override
  void initState() {
    super.initState();
    _initServices();
    _messages.add(ChatMessage(
      text: 'Hello! I\'m your AI study assistant. Ask me anything about any topic - science, math, programming, history, or upload files/images for analysis!',
      isUser: false,
      timestamp: DateTime.now(),
    ));
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

    String messageText = text;
    
    // If file is selected, extract text from it
    if (_selectedFile != null) {
      if (_selectedFileName!.toLowerCase().endsWith('.jpg') ||
          _selectedFileName!.toLowerCase().endsWith('.jpeg') ||
          _selectedFileName!.toLowerCase().endsWith('.png')) {
        try {
          final extractedText = await _ocrService.extractTextFromImage(_selectedFile!.path);
          if (extractedText.isNotEmpty) {
            messageText = text.isEmpty 
                ? 'Analyze this image: $extractedText' 
                : '$text\n\nImage content: $extractedText';
          } else {
            messageText = text.isEmpty ? 'Describe what you see in this image' : text;
          }
        } catch (e) {
          print('OCR error: $e');
          messageText = text.isEmpty ? 'Describe this image' : text;
        }
      } else {
        messageText = text.isEmpty 
            ? 'Help me understand this file: $_selectedFileName' 
            : '$text\n\nRegarding file: $_selectedFileName';
      }
    }

    final userMessage = ChatMessage(
      text: messageText,
      isUser: true,
      timestamp: DateTime.now(),
      fileName: _selectedFileName,
    );

    setState(() {
      _messages.add(userMessage);
      _messageController.clear();
      _selectedFile = null;
      _selectedFileName = null;
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      print('Sending message to Groq API...');
      
      final response = await _dio.post(
        '${ApiEndpoints.groqApiBase}/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer ${ApiEndpoints.groqApiKey}',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status! < 500,
        ),
        data: {
          'model': 'llama-3.3-70b-versatile',
          'messages': [
            {
              'role': 'system',
              'content': 'You are a helpful AI study assistant for students. Provide clear, accurate, and educational responses. Break down complex topics into understandable explanations. Use examples when helpful.',
            },
            ..._messages.map((msg) => {
              'role': msg.isUser ? 'user' : 'assistant',
              'content': msg.text,
            }).toList(),
          ],
          'temperature': 0.7,
          'max_tokens': 2000,
        },
      );

      print('Response status: ${response.statusCode}');
      
      if (response.statusCode != 200) {
        throw Exception('API returned ${response.statusCode}: ${response.data}');
      }

      final aiResponse = response.data['choices'][0]['message']['content'] as String;

      setState(() {
        _messages.add(ChatMessage(
          text: aiResponse,
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });

      // Auto-generate title from first user message
      if (_messages.where((m) => m.isUser).length == 1) {
        _currentChatTitle = text.length > 30 ? '${text.substring(0, 30)}...' : text;
      }

      // Save chat history
      _saveCurrentChat();

      _scrollToBottom();
    } catch (e) {
      print('Error sending message: $e');
      setState(() {
        _messages.add(ChatMessage(
          text: 'Sorry, I encountered an error: ${e.toString()}. Please check your internet connection and try again.',
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
    }
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
        title: const Text('AI Study Assistant'),
        actions: [
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
                  onPressed: _isLoading ? null : _sendMessage,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? fileName;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.fileName,
  });
}
