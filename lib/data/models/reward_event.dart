import 'package:cloud_firestore/cloud_firestore.dart';

class RewardEvent {
  final String rewardId;
  final int starsEarned;
  final int baseStars;
  final double multiplier;
  final bool bonusApplied;
  final String reason;
  final String contentType;
  final DateTime timestamp;
  final int dayNumber;
  final String? articleId;
  
  RewardEvent({
    required this.rewardId,
    required this.starsEarned,
    required this.baseStars,
    required this.multiplier,
    required this.bonusApplied,
    required this.reason,
    required this.contentType,
    required this.timestamp,
    required this.dayNumber,
    this.articleId,
  });
  
  factory RewardEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RewardEvent(
      rewardId: doc.id,
      starsEarned: data['starsEarned'] ?? 0,
      baseStars: data['baseStars'] ?? 0,
      multiplier: (data['multiplier'] ?? 1.0).toDouble(),
      bonusApplied: data['bonusApplied'] ?? false,
      reason: data['reason'] ?? '',
      contentType: data['contentType'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      dayNumber: data['dayNumber'] ?? 0,
      articleId: data['articleId'],
    );
  }
  
  Map<String, dynamic> toFirestore() => {
    'starsEarned': starsEarned,
    'baseStars': baseStars,
    'multiplier': multiplier,
    'bonusApplied': bonusApplied,
    'reason': reason,
    'contentType': contentType,
    'timestamp': Timestamp.fromDate(timestamp),
    'dayNumber': dayNumber,
    if (articleId != null) 'articleId': articleId,
  };
}
