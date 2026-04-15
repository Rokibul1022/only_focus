import 'package:dio/dio.dart';
import '../constants/api_endpoints.dart';

class AIService {
  final Dio _dio = Dio();
  
  Future<List<String>> generateSummary(String articleText) async {
    try {
      // Limit text length to avoid token limits
      final limitedText = articleText.length > 2000 
          ? articleText.substring(0, 2000) 
          : articleText;
      
      final response = await _dio.post(
        'https://api.groq.com/openai/v1/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer ${ApiEndpoints.groqApiKey}',
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => status! < 500,
        ),
        data: {
          'model': 'llama-3.1-8b-instant',
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
      
      if (response.statusCode != 200) {
        throw Exception('API returned ${response.statusCode}: ${response.data}');
      }
      
      final content = response.data['choices'][0]['message']['content'] as String;
      
      // Parse the response into 3 takeaways
      final lines = content.split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map((line) => line.replaceAll(RegExp(r'^[\d\.\-\*\•]\s*'), '').trim())
          .where((line) => line.isNotEmpty && line.length > 10)
          .toList();
      
      // Return first 3 or pad with generic messages
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
    } catch (e) {
      throw Exception('Failed to generate summary: $e');
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
