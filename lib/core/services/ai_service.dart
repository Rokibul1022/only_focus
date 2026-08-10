import 'package:dio/dio.dart';
import '../constants/api_endpoints.dart';

class AIService {
  final Dio _dio = Dio();
  int _currentKeyIndex = 0;
  
  Future<List<String>> generateSummary(String articleText) async {
    final limitedText = articleText.length > 2000 
        ? articleText.substring(0, 2000) 
        : articleText;
    
    // Try each API key until one works
    for (int i = 0; i < ApiEndpoints.groqApiKeys.length; i++) {
      try {
        final keyIndex = (_currentKeyIndex + i) % ApiEndpoints.groqApiKeys.length;
        final apiKey = ApiEndpoints.groqApiKeys[keyIndex];
        
        final response = await _dio.post(
          'https://api.groq.com/openai/v1/chat/completions',
          options: Options(
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            validateStatus: (status) => status! < 500,
          ),
          data: {
            'model': 'llama-3.1-70b-versatile',
            'messages': [
              {
                'role': 'system',
                'content': 'You are a helpful assistant that summarizes articles. Provide exactly 3 clear, concise bullet points summarizing the key information. Start each point with a dash (-).'
              },
              {
                'role': 'user',
                'content': 'Summarize this article in 3 key points:\n\n$limitedText'
              }
            ],
            'temperature': 0.5,
            'max_tokens': 300,
          },
        );
        
        if (response.statusCode == 200) {
          _currentKeyIndex = keyIndex;
          final content = response.data['choices'][0]['message']['content'] as String;
          return _parseSummary(content, articleText);
        }
      } catch (e) {
        if (i == ApiEndpoints.groqApiKeys.length - 1) {
          throw Exception('All API keys failed: $e');
        }
        continue;
      }
    }
    
    throw Exception('Failed to generate summary with all API keys');
  }
  
  List<String> _parseSummary(String content, String articleText) {
    final lines = content.split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((line) => line.replaceAll(RegExp(r'^[\d\.\-\*\•]\s*'), '').trim())
        .where((line) => line.isNotEmpty && line.length > 10)
        .toList();
    
    if (lines.length >= 3) {
      return lines.take(3).toList();
    } else if (lines.isNotEmpty) {
      return lines;
    } else {
      return [
        'This article discusses important topics in ${_getTopicFromText(articleText)}.',
        'The content provides valuable insights and information.',
        'Reading this article will expand your knowledge on the subject.',
      ];
    }
  }
  
  String _getTopicFromText(String text) {
    if (text.toLowerCase().contains('technology') || text.toLowerCase().contains('tech')) {
      return 'technology';
    } else if (text.toLowerCase().contains('science')) {
      return 'science';
    } else if (text.toLowerCase().contains('research')) {
      return 'research';
    } else {
      return 'this field';
    }
  }
}
