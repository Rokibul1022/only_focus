import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();
  
  final FlutterTts _flutterTts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;
  bool _isPaused = false;
  String? _currentText;
  Function? _onComplete;
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    
    _flutterTts.setStartHandler(() {
      _isSpeaking = true;
      _isPaused = false;
    });
    
    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
      _isPaused = false;
      _onComplete?.call();
    });
    
    _flutterTts.setCancelHandler(() {
      _isSpeaking = false;
      _isPaused = false;
    });
    
    _flutterTts.setPauseHandler(() {
      _isPaused = true;
    });
    
    _flutterTts.setContinueHandler(() {
      _isPaused = false;
    });
    
    _isInitialized = true;
  }
  
  Future<void> speak(String text) async {
    await initialize();
    await stop();
    _currentText = text;
    await _flutterTts.speak(text);
  }
  
  Future<void> pause() async {
    await _flutterTts.pause();
  }
  
  Future<void> resume() async {
    if (_isPaused && _currentText != null) {
      await _flutterTts.speak(_currentText!);
    }
  }
  
  Future<void> stop() async {
    await _flutterTts.stop();
    _isSpeaking = false;
    _isPaused = false;
    _currentText = null;
  }
  
  Future<void> setSpeechRate(double rate) async {
    await _flutterTts.setSpeechRate(rate);
  }
  
  Future<void> setPitch(double pitch) async {
    await _flutterTts.setPitch(pitch);
  }
  
  bool get isSpeaking => _isSpeaking;
  bool get isPaused => _isPaused;
  
  Future<List<String>> getLanguages() async {
    final languages = await _flutterTts.getLanguages;
    return List<String>.from(languages);
  }
  
  Future<void> setLanguage(String language) async {
    await _flutterTts.setLanguage(language);
  }
  
  void setCompletionHandler(Function handler) {
    _onComplete = handler;
  }
}
