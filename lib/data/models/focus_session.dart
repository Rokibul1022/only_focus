import 'package:cloud_firestore/cloud_firestore.dart';

class FocusSession {
  final String sessionId;
  final DateTime startTime;
  final DateTime endTime;
  final int durationMinutes;
  final int articlesReadDuringSession;
  final int starsEarned;
  final bool goalMet;
  final String sessionType; // 'pomodoro' | 'deep_work'
  final int streakDay;
  
  FocusSession({
    required this.sessionId,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.articlesReadDuringSession,
    required this.starsEarned,
    required this.goalMet,
    required this.sessionType,
    required this.streakDay,
  });
  
  factory FocusSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FocusSession(
      sessionId: doc.id,
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      durationMinutes: data['durationMinutes'] ?? 0,
      articlesReadDuringSession: data['articlesReadDuringSession'] ?? 0,
      starsEarned: data['starsEarned'] ?? 0,
      goalMet: data['goalMet'] ?? false,
      sessionType: data['sessionType'] ?? 'pomodoro',
      streakDay: data['streakDay'] ?? 0,
    );
  }
  
  Map<String, dynamic> toFirestore() => {
    'startTime': Timestamp.fromDate(startTime),
    'endTime': Timestamp.fromDate(endTime),
    'durationMinutes': durationMinutes,
    'articlesReadDuringSession': articlesReadDuringSession,
    'starsEarned': starsEarned,
    'goalMet': goalMet,
    'sessionType': sessionType,
    'streakDay': streakDay,
  };
}
