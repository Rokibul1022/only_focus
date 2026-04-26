import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;

class NikoChatResult {
  final String reply;
  final String model;
  final List<Map<String, String>> sources;
  final List<String> memoriesUsed;

  NikoChatResult({
    required this.reply,
    this.model = '',
    this.sources = const [],
    this.memoriesUsed = const [],
  });
}

class NikoStreamEvent {
  final String type; // token | done | error
  final String content;
  final String model;
  final List<Map<String, String>> sources;
  final List<String> memoriesUsed;

  NikoStreamEvent({
    required this.type,
    this.content = '',
    this.model = '',
    this.sources = const [],
    this.memoriesUsed = const [],
  });
}

class BackendApiService {
  // Override at build/run time: flutter run --dart-define=API_BASE_URL=http://<PC-IP>:8000
  // localhost only works for the emulator/desktop; physical devices need the PC's LAN IP.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );
  
  final Dio _dio = Dio();

  Future<List<String>> generateSummary(String articleText) async {
    try {
      final response = await _dio.post(
        '$baseUrl/api/ai/summary',
        data: {'text': articleText},
      );

      if (response.statusCode == 200 && response.data['success']) {
        return List<String>.from(response.data['summary']);
      }
      throw Exception('Failed to generate summary');
    } catch (e) {
      throw Exception('Backend error: $e');
    }
  }

  Future<String> chat(List<Map<String, String>> messages) async {
    try {
      final response = await _dio.post(
        '$baseUrl/api/ai/chat',
        data: {'messages': messages},
      );

      if (response.statusCode == 200 && response.data['success']) {
        return response.data['message'];
      }
      throw Exception('Failed to get chat response');
    } catch (e) {
      throw Exception('Backend error: $e');
    }
  }

  // ---------- Niko agent ----------

  Future<NikoChatResult> nikoChat({
    required List<Map<String, String>> messages,
    required String sessionId,
    String userId = 'default',
  }) async {
    final response = await _dio.post(
      '$baseUrl/api/niko/chat',
      data: {
        'session_id': sessionId,
        'user_id': userId,
        'messages': messages,
      },
    );

    if (response.statusCode == 200) {
      final data = response.data as Map<String, dynamic>;
      return NikoChatResult(
        reply: data['reply'] as String,
        model: data['model'] as String? ?? '',
        sources: (data['sources'] as List?)
                ?.map((s) => Map<String, String>.from(s as Map))
                .toList() ??
            const [],
        memoriesUsed: (data['memories_used'] as List?)
                ?.map((m) => m.toString())
                .toList() ??
            const [],
      );
    }
    throw Exception('Niko chat failed (${response.statusCode})');
  }

  Future<Map<String, dynamic>> nikoInfo() async {
    final response = await _dio.get('$baseUrl/api/niko/info');
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Streams Niko's reply token-by-token (SSE from /api/niko/chat/stream).
  Stream<NikoStreamEvent> nikoChatStream({
    required List<Map<String, String>> messages,
    required String sessionId,
    String userId = 'default',
  }) async* {
    final client = http.Client();
    try {
      final request = http.Request(
        'POST',
        Uri.parse('$baseUrl/api/niko/chat/stream'),
      )
        ..headers['Content-Type'] = 'application/json'
        ..headers['Accept'] = 'text/event-stream'
        ..body = jsonEncode({
          'session_id': sessionId,
          'user_id': userId,
          'messages': messages,
        });

      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw Exception('Niko stream failed (${response.statusCode})');
      }

      final lines = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in lines) {
        if (!line.startsWith('data: ')) continue;
        final data = line.substring(6).trim();
        if (data.isEmpty) continue;

        try {
          final event = jsonDecode(data) as Map<String, dynamic>;
          final type = event['type'] as String? ?? '';
          yield NikoStreamEvent(
            type: type,
            content: event['content'] as String? ?? event['message'] ?? '',
            model: event['model'] as String? ?? '',
            sources: (event['sources'] as List?)
                    ?.map((s) => Map<String, String>.from(s as Map))
                    .toList() ??
                const [],
            memoriesUsed: (event['memories_used'] as List?)
                    ?.map((m) => m.toString())
                    .toList() ??
                const [],
          );
        } catch (_) {
          // Ignore malformed lines.
        }
      }
    } finally {
      client.close();
    }
  }

  /// Uploads and indexes a document (PDF/TXT/DOCX/...) into Niko's knowledge base.
  Future<Map<String, dynamic>> nikoUploadFile({
    required String filePath,
    required String fileName,
    String title = '',
    String userId = 'default',
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
      'title': title,
      'user_id': userId,
    });
    final response = await _dio.post('$baseUrl/api/niko/upload', data: form);
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    throw Exception('Niko upload failed (${response.statusCode})');
  }

  /// Sends an image to Niko's vision endpoint for analysis/description.
  Future<Map<String, dynamic>> nikoVisionAnalysis({
    required String filePath,
    required String fileName,
    String message = '',
    String sessionId = 'default-session',
    String userId = 'default',
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
      'message': message,
      'session_id': sessionId,
      'user_id': userId,
    });
    final response = await _dio.post('$baseUrl/api/niko/vision', data: form);
    if (response.statusCode == 200) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    throw Exception('Niko vision failed (${response.statusCode})');
  }

  Future<void> nikoIndex({
    required String title,
    required String content,
    String source = 'user',
    String? docId,
    String userId = 'default',
  }) async {
    await _dio.post(
      '$baseUrl/api/niko/index',
      data: {
        'title': title,
        'content': content,
        'source': source,
        'doc_id': docId,
        'user_id': userId,
      },
    );
  }

  Future<List<Map<String, dynamic>>> nikoDocuments({String? userId}) async {
    final response = await _dio.get(
      '$baseUrl/api/niko/documents',
      queryParameters: {if (userId != null) 'user_id': userId},
    );
    return (response.data['documents'] as List)
        .map((d) => Map<String, dynamic>.from(d as Map))
        .toList();
  }

  Future<void> nikoDeleteDocument(String docId) async {
    await _dio.delete('$baseUrl/api/niko/documents/$docId');
  }

  Future<List<Map<String, dynamic>>> nikoMemories({String? userId}) async {
    final response = await _dio.get(
      '$baseUrl/api/niko/memory',
      queryParameters: {if (userId != null) 'user_id': userId},
    );
    return (response.data['memories'] as List)
        .map((m) => Map<String, dynamic>.from(m as Map))
        .toList();
  }

  Future<void> nikoDeleteMemory(String memoryId) async {
    await _dio.delete('$baseUrl/api/niko/memory/$memoryId');
  }
}
