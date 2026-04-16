import 'dart:io';
import 'package:dio/dio.dart';

class OcrService {
  final Dio _dio = Dio();
  static const String _apiKey = 'K84291758988957';
  static const String _apiUrl = 'https://api.ocr.space/parse/image';

  Future<String> extractTextFromImage(String imagePath) async {
    try {
      final file = File(imagePath);
      
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imagePath,
          filename: file.path.split('/').last,
        ),
        'apikey': _apiKey,
        'language': 'eng',
        'isOverlayRequired': false,
      });

      final response = await _dio.post(
        _apiUrl,
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['ParsedResults'] != null && data['ParsedResults'].isNotEmpty) {
          final text = data['ParsedResults'][0]['ParsedText'] as String;
          return text.trim();
        } else {
          throw Exception('No text found in image');
        }
      } else {
        throw Exception('OCR API error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to extract text: $e');
    }
  }

  void dispose() {
    // No cleanup needed
  }
}
