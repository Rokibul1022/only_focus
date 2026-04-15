import 'package:cloud_firestore/cloud_firestore.dart';

class ReadingGoal {
  final String goalId;
  final int targetArticles;
  final int targetMinutes;
  final DateTime weekStartDate;
  final int progress;
  final bool completed;
  
  ReadingGoal({
    required this.goalId,
    required this.targetArticles,
    required this.targetMinutes,
    required this.weekStartDate,
    required this.progress,
    required this.completed,
  });
  
  factory ReadingGoal.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReadingGoal(
      goalId: doc.id,
      targetArticles: data['targetArticles'] ?? 0,
      targetMinutes: data['targetMinutes'] ?? 0,
      weekStartDate: (data['weekStartDate'] as Timestamp).toDate(),
      progress: data['progress'] ?? 0,
      completed: data['completed'] ?? false,
    );
  }
  
  Map<String, dynamic> toFirestore() => {
    'targetArticles': targetArticles,
    'targetMinutes': targetMinutes,
    'weekStartDate': Timestamp.fromDate(weekStartDate),
    'progress': progress,
    'completed': completed,
  };
}
