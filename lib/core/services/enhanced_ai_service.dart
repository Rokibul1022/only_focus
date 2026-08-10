import 'package:dio/dio.dart';
import '../constants/api_endpoints.dart';

class EnhancedAIService {
  final Dio _dio = Dio();
  int _currentKeyIndex = 0;
  
  Future<String> _makeRequest(String systemPrompt, String userPrompt, int maxTokens) async {
    for (int i = 0; i < ApiEndpoints.groqApiKeys.length; i++) {
      try {
        final keyIndex = (_currentKeyIndex + i) % ApiEndpoints.groqApiKeys.length;
        final apiKey = ApiEndpoints.groqApiKeys[keyIndex];
        
        final response = await _dio.post(
          '${ApiEndpoints.groqApiBase}/chat/completions',
          options: Options(
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            validateStatus: (status) => status! < 500,
          ),
          data: {
            'model': 'llama-3.3-70b-versatile',
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': userPrompt},
            ],
            'temperature': 0.5,
            'max_tokens': maxTokens,
          },
        );
        
        if (response.statusCode == 200) {
          _currentKeyIndex = keyIndex;
          return response.data['choices'][0]['message']['content'] as String;
        }
      } catch (e) {
        if (i == ApiEndpoints.groqApiKeys.length - 1) rethrow;
        continue;
      }
    }
    throw Exception('All API keys failed');
  }
  
  // Generate quick summary (3-5 bullet points)
  Future<List<String>> generateQuickSummary(String articleText) async {
    try {
      final content = await _makeRequest(
        'You are a summarization expert. Create a quick 3-5 bullet point summary. Each point should be one clear sentence. Return ONLY the bullet points, one per line, starting with "-".',
        'Summarize this article:\n\n${articleText.substring(0, articleText.length > 3000 ? 3000 : articleText.length)}',
        300,
      );
      
      return content
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map((line) => line.replaceFirst(RegExp(r'^[-•*]\s*'), '').trim())
          .where((line) => line.isNotEmpty)
          .toList();
    } catch (e) {
      print('Quick summary error: $e');
      return ['Failed to generate summary'];
    }
  }
  
  // Generate detailed summary (comprehensive)
  Future<String> generateDetailedSummary(String articleText) async {
    try {
      return await _makeRequest(
        'You are a comprehensive summarization expert. Create a detailed summary covering all key points, arguments, and conclusions. Use paragraphs.',
        'Provide a detailed summary:\n\n${articleText.substring(0, articleText.length > 4000 ? 4000 : articleText.length)}',
        800,
      );
    } catch (e) {
      print('Detailed summary error: $e');
      return 'Failed to generate detailed summary';
    }
  }
  
  // Extract key points
  Future<List<String>> extractKeyPoints(String articleText) async {
    try {
      final content = await _makeRequest(
        'Extract 5-7 key takeaways from the article. Each should be a clear, actionable insight. Return ONLY the points, one per line, starting with "-".',
        'Extract key points:\n\n${articleText.substring(0, articleText.length > 3000 ? 3000 : articleText.length)}',
        400,
      );
      
      return content
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .map((line) => line.replaceFirst(RegExp(r'^[-•*]\s*'), '').trim())
          .where((line) => line.isNotEmpty)
          .toList();
    } catch (e) {
      print('Key points error: $e');
      return ['Failed to extract key points'];
    }
  }
  
  // Generate study notes
  Future<String> generateStudyNotes(String articleText) async {
    try {
      return await _makeRequest(
        'You are a study notes expert. Create structured study notes with: Main Topic, Key Concepts, Important Details, and Conclusion. Use clear formatting.',
        'Create study notes:\n\n${articleText.substring(0, articleText.length > 3500 ? 3500 : articleText.length)}',
        700,
      );
    } catch (e) {
      print('Study notes error: $e');
      return 'Failed to generate study notes';
    }
  }
  
  // Generate quiz questions
  Future<List<QuizQuestion>> generateQuiz(String articleText) async {
    try {
      final content = await _makeRequest(
        'Generate 5 multiple choice questions from the article. Format: Q: [question]\nA) [option]\nB) [option]\nC) [option]\nD) [option]\nCorrect: [A/B/C/D]',
        'Generate quiz:\n\n${articleText.substring(0, articleText.length > 3000 ? 3000 : articleText.length)}',
        1000,
      );
      
      return _parseQuizQuestions(content);
    } catch (e) {
      print('Quiz generation error: $e');
      return [];
    }
  }
  
  List<QuizQuestion> _parseQuizQuestions(String content) {
    final questions = <QuizQuestion>[];
    final blocks = content.split('Q:').where((b) => b.trim().isNotEmpty).toList();
    
    for (final block in blocks) {
      try {
        final lines = block.split('\n').where((l) => l.trim().isNotEmpty).toList();
        if (lines.isEmpty) continue;
        
        final question = lines[0].trim();
        final options = <String>[];
        String? correctAnswer;
        
        for (final line in lines.skip(1)) {
          if (line.startsWith(RegExp(r'[A-D]\)'))) {
            options.add(line.substring(2).trim());
          } else if (line.toLowerCase().startsWith('correct:')) {
            correctAnswer = line.split(':')[1].trim().toUpperCase();
          }
        }
        
        if (question.isNotEmpty && options.length == 4 && correctAnswer != null) {
          questions.add(QuizQuestion(
            question: question,
            options: options,
            correctAnswer: correctAnswer,
          ));
        }
      } catch (e) {
        continue;
      }
    }
    
    return questions;
  }
}

class QuizQuestion {
  final String question;
  final List<String> options;
  final String correctAnswer;
  
  QuizQuestion({
    required this.question,
    required this.options,
    required this.correctAnswer,
  });
}
