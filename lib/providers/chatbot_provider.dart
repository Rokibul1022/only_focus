import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/chatbot_service.dart';

final chatbotServiceProvider = Provider((ref) => ChatbotService());

final chatMessagesProvider = StateNotifierProvider<ChatMessagesNotifier, List<ChatMessage>>((ref) {
  return ChatMessagesNotifier(ref.read(chatbotServiceProvider));
});

class ChatMessagesNotifier extends StateNotifier<List<ChatMessage>> {
  final ChatbotService _chatbotService;

  ChatMessagesNotifier(this._chatbotService) : super([]);

  Future<void> sendMessage(String text) async {
    final sentiment = _chatbotService.analyzeSentiment(text);
    final userMessage = ChatMessage(
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
      sentiment: sentiment,
    );

    state = [...state, userMessage];

    final botResponse = await _chatbotService.sendMessage(text);
    state = [...state, botResponse];
  }

  void clearChat() {
    _chatbotService.clearHistory();
    state = [];
  }
}
