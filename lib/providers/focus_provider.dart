import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/focus_service.dart';

// Focus service provider
final focusServiceProvider = Provider<FocusService>((ref) {
  final service = FocusService();
  ref.onDispose(() => service.dispose());
  return service;
});

// Focus state provider
final focusStateProvider = StateNotifierProvider<FocusNotifier, FocusState>((ref) {
  return FocusNotifier(ref.read(focusServiceProvider));
});

class FocusState {
  final int remainingSeconds;
  final SessionState sessionState;
  final SessionType sessionType;
  final int articlesReadInSession;
  final int? starsEarned;
  
  FocusState({
    required this.remainingSeconds,
    required this.sessionState,
    required this.sessionType,
    required this.articlesReadInSession,
    this.starsEarned,
  });
  
  FocusState copyWith({
    int? remainingSeconds,
    SessionState? sessionState,
    SessionType? sessionType,
    int? articlesReadInSession,
    int? starsEarned,
  }) {
    return FocusState(
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      sessionState: sessionState ?? this.sessionState,
      sessionType: sessionType ?? this.sessionType,
      articlesReadInSession: articlesReadInSession ?? this.articlesReadInSession,
      starsEarned: starsEarned ?? this.starsEarned,
    );
  }
}

class FocusNotifier extends StateNotifier<FocusState> {
  final FocusService _service;
  
  FocusNotifier(this._service) : super(FocusState(
    remainingSeconds: 0,
    sessionState: SessionState.idle,
    sessionType: SessionType.pomodoro,
    articlesReadInSession: 0,
  )) {
    _service.onTick = _onTick;
    _service.onStateChanged = _onStateChanged;
    _service.onSessionComplete = _onSessionComplete;
  }
  
  void _onTick(int seconds) {
    state = state.copyWith(remainingSeconds: seconds);
  }
  
  void _onStateChanged(SessionState newState) {
    state = state.copyWith(sessionState: newState);
  }
  
  void _onSessionComplete(int starsEarned) {
    state = state.copyWith(
      sessionState: SessionState.completed,
      starsEarned: starsEarned,
    );
  }
  
  void startPomodoro() {
    _service.startPomodoro();
    state = state.copyWith(
      sessionType: SessionType.pomodoro,
      sessionState: SessionState.running,
      starsEarned: null,
    );
  }
  
  void startDeepWork() {
    _service.startDeepWork();
    state = state.copyWith(
      sessionType: SessionType.deepWork,
      sessionState: SessionState.running,
      starsEarned: null,
    );
  }
  
  void startCustom(int minutes) {
    _service.startCustomSession(minutes);
    state = state.copyWith(
      sessionType: SessionType.pomodoro,
      sessionState: SessionState.running,
      starsEarned: null,
    );
  }
  
  void pause() {
    _service.pause();
  }
  
  void resume() {
    _service.resume();
  }
  
  void stop() {
    _service.stop();
    state = FocusState(
      remainingSeconds: 0,
      sessionState: SessionState.idle,
      sessionType: SessionType.pomodoro,
      articlesReadInSession: 0,
    );
  }
  
  void startBreak() {
    _service.startBreak();
  }
  
  void incrementArticlesRead() {
    _service.incrementArticlesRead();
    state = state.copyWith(
      articlesReadInSession: _service.articlesReadInSession,
    );
  }
  
  String formatTime() {
    return _service.formatTime(state.remainingSeconds);
  }
}
