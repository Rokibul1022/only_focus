import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

enum SessionType { pomodoro, deepWork }
enum SessionState { idle, running, paused, breakTime, completed }

class FocusService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
  Timer? _timer;
  int _remainingSeconds = 0;
  SessionState _state = SessionState.idle;
  SessionType _sessionType = SessionType.pomodoro;
  DateTime? _sessionStartTime;
  int _articlesReadInSession = 0;
  
  // Callbacks
  Function(int)? onTick;
  Function(SessionState)? onStateChanged;
  Function(int)? onSessionComplete;
  
  // Getters
  int get remainingSeconds => _remainingSeconds;
  SessionState get state => _state;
  SessionType get sessionType => _sessionType;
  int get articlesReadInSession => _articlesReadInSession;
  
  // Start Pomodoro session (25 min)
  void startPomodoro() {
    _sessionType = SessionType.pomodoro;
    _startSession(25 * 60); // 25 minutes
  }
  
  // Start Deep Work session (90 min)
  void startDeepWork() {
    _sessionType = SessionType.deepWork;
    _startSession(90 * 60); // 90 minutes
  }
  
  // Start custom duration session
  void startCustomSession(int minutes) {
    _sessionType = SessionType.pomodoro;
    _startSession(minutes * 60);
  }
  
  void _startSession(int durationSeconds) {
    _remainingSeconds = durationSeconds;
    _state = SessionState.running;
    _sessionStartTime = DateTime.now();
    _articlesReadInSession = 0;
    
    onStateChanged?.call(_state);
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        onTick?.call(_remainingSeconds);
      } else {
        _completeSession();
      }
    });
  }
  
  void pause() {
    if (_state == SessionState.running) {
      _timer?.cancel();
      _state = SessionState.paused;
      onStateChanged?.call(_state);
    }
  }
  
  void resume() {
    if (_state == SessionState.paused) {
      _state = SessionState.running;
      onStateChanged?.call(_state);
      
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
          onTick?.call(_remainingSeconds);
        } else {
          _completeSession();
        }
      });
    }
  }
  
  void stop() {
    _timer?.cancel();
    _state = SessionState.idle;
    _remainingSeconds = 0;
    onStateChanged?.call(_state);
  }
  
  void incrementArticlesRead() {
    _articlesReadInSession++;
  }
  
  Future<void> _completeSession() async {
    _timer?.cancel();
    _state = SessionState.completed;
    onStateChanged?.call(_state);
    
    if (_sessionStartTime != null) {
      final durationMinutes = DateTime.now().difference(_sessionStartTime!).inMinutes;
      
      try {
        // Call Cloud Function to award stars
        final result = await _functions.httpsCallable('onFocusSessionComplete').call({
          'sessionType': _sessionType == SessionType.deepWork ? 'deep_work' : 'pomodoro',
          'durationMinutes': durationMinutes,
          'articlesRead': _articlesReadInSession,
          'goalMet': true,
        });
        
        final starsEarned = result.data['starsEarned'] as int? ?? 0;
        onSessionComplete?.call(starsEarned);
      } catch (e) {
        print('Error completing focus session: $e');
        onSessionComplete?.call(0);
      }
    }
    
    // Reset for next session
    _state = SessionState.idle;
    _remainingSeconds = 0;
    _articlesReadInSession = 0;
  }
  
  // Start break (5 min for Pomodoro)
  void startBreak() {
    _state = SessionState.breakTime;
    _remainingSeconds = 5 * 60; // 5 minutes
    onStateChanged?.call(_state);
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        _remainingSeconds--;
        onTick?.call(_remainingSeconds);
      } else {
        _timer?.cancel();
        _state = SessionState.idle;
        onStateChanged?.call(_state);
      }
    });
  }
  
  String formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
  
  void dispose() {
    _timer?.cancel();
  }
}
