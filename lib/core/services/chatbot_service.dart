import 'package:dio/dio.dart';
import '../constants/api_endpoints.dart';

enum Sentiment { positive, negative, neutral, excited, confused, frustrated }

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final Sentiment? sentiment;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.sentiment,
  });
}

class ChatbotService {
  final Dio _dio = Dio();
  final List<Map<String, String>> _conversationHistory = [];

  Future<ChatMessage> sendMessage(String userMessage) async {
    final sentiment = analyzeSentiment(userMessage);
    
    _conversationHistory.add({
      'role': 'user',
      'content': userMessage,
    });

    try {
      final response = await _dio.post(
        'https://api.groq.com/openai/v1/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer ${ApiEndpoints.groqApiKey}',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'model': 'llama-3.1-8b-instant',
          'messages': [
            {
              'role': 'system',
              'content': 'You are a helpful, friendly AI assistant for Only Focus, a reading and productivity app. Help users with article recommendations, reading tips, focus techniques, and general questions. Be concise and supportive. Adapt your tone based on user sentiment.'
            },
            ...(_conversationHistory.length > 10 
                ? _conversationHistory.sublist(_conversationHistory.length - 10)
                : _conversationHistory),
          ],
          'temperature': 0.7,
          'max_tokens': 500,
        },
      );

      final botReply = response.data['choices'][0]['message']['content'] as String;
      
      _conversationHistory.add({
        'role': 'assistant',
        'content': botReply,
      });

      return ChatMessage(
        text: botReply,
        isUser: false,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      return ChatMessage(
        text: 'Sorry, I encountered an error. Please try again.',
        isUser: false,
        timestamp: DateTime.now(),
      );
    }
  }

  Sentiment analyzeSentiment(String text) {
    final lower = text.toLowerCase();
    
    final excitedWords = ['amazing', 'awesome', 'great', 'love', 'excellent', 'fantastic', '!'];
    final positiveWords = ['good', 'nice', 'thanks', 'thank', 'helpful', 'appreciate'];
    final negativeWords = ['bad', 'hate', 'terrible', 'awful', 'worst', 'sucks'];
    final confusedWords = ['confused', 'don\'t understand', 'what', 'how', '?'];
    final frustratedWords = ['frustrated', 'annoying', 'stuck', 'can\'t', 'won\'t work'];

    if (excitedWords.any((word) => lower.contains(word))) return Sentiment.excited;
    if (frustratedWords.any((word) => lower.contains(word))) return Sentiment.frustrated;
    if (confusedWords.any((word) => lower.contains(word))) return Sentiment.confused;
    if (negativeWords.any((word) => lower.contains(word))) return Sentiment.negative;
    if (positiveWords.any((word) => lower.contains(word))) return Sentiment.positive;
    
    return Sentiment.neutral;
  }

  void clearHistory() {
    _conversationHistory.clear();
  }
}
