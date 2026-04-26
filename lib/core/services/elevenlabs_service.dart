import 'package:dio/dio.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';
import '../constants/api_endpoints.dart';

class ElevenLabsService {
  final Dio _dio = Dio();
  final AudioPlayer _audioPlayer = AudioPlayer();

  /// Convert text to speech using ElevenLabs API
  Future<String?> textToSpeech(String text) async {
    try {
      final response = await _dio.post(
        '${ApiEndpoints.elevenLabsApiBase}/text-to-speech/${ApiEndpoints.elevenLabsVoiceId}',
        options: Options(
          headers: {
            'xi-api-key': ApiEndpoints.elevenLabsApiKey,
            'Content-Type': 'application/json',
          },
          responseType: ResponseType.bytes,
        ),
        data: {
          'text': text,
          'model_id': 'eleven_multilingual_v2',
          'voice_settings': {
            'stability': 0.5,
            'similarity_boost': 0.75,
          },
        },
      );

      if (response.statusCode == 200) {
        // Save audio to temp file
        final tempDir = Directory.systemTemp;
        final audioFile = File('${tempDir.path}/elevenlabs_${DateTime.now().millisecondsSinceEpoch}.mp3');
        await audioFile.writeAsBytes(response.data);
        return audioFile.path;
      }
      return null;
    } catch (e) {
      print('ElevenLabs TTS error: $e');
      return null;
    }
  }

  /// Play audio from file path
  Future<void> playAudio(String filePath) async {
    try {
      await _audioPlayer.play(DeviceFileSource(filePath));
    } catch (e) {
      print('Audio playback error: $e');
    }
  }

  /// Stop audio playback
  Future<void> stopAudio() async {
    await _audioPlayer.stop();
  }

  /// Convert speech to text using ElevenLabs API
  Future<String?> speechToText(String audioFilePath) async {
    try {
      final audioFile = File(audioFilePath);
      
      // ElevenLabs uses a different endpoint structure
      final formData = FormData.fromMap({
        'audio': await MultipartFile.fromFile(
          audioFile.path,
          filename: 'audio.wav',
        ),
      });

      print('Sending audio to ElevenLabs STT...');
      
      final response = await _dio.post(
        '${ApiEndpoints.elevenLabsApiBase}/speech-to-text',
        options: Options(
          headers: {
            'xi-api-key': ApiEndpoints.elevenLabsApiKey,
          },
          validateStatus: (status) => status! < 500,
        ),
        data: formData,
      );

      print('STT Response status: ${response.statusCode}');
      print('STT Response data: ${response.data}');

      if (response.statusCode == 200) {
        // ElevenLabs returns {"text": "transcribed text"}
        if (response.data is Map && response.data.containsKey('text')) {
          return response.data['text'] as String?;
        }
        // Or it might return the text directly
        return response.data.toString();
      }
      
      print('STT failed with status ${response.statusCode}: ${response.data}');
      return null;
    } catch (e) {
      print('ElevenLabs STT error: $e');
      return null;
    }
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}
