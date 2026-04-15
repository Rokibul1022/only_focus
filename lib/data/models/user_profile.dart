import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String displayName;
  final String email;
  final DateTime createdAt;
  final DateTime lastActiveAt;
  final int totalStars;
  final int weeklyStars;
  final String currentRank;
  final int rankIndex;
  final int streakDays;
  final int longestStreak;
  final String lastReadDate; // ISO date 'YYYY-MM-DD'
  final int totalArticlesRead;
  final int totalResearchPapersRead;
  final int totalReadingMinutes;
  final int totalFocusSessions;
  final String readingPersona;
  final String? fcmToken;
  final bool notificationsEnabled;
  
  UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.createdAt,
    required this.lastActiveAt,
    required this.totalStars,
    required this.weeklyStars,
    required this.currentRank,
    required this.rankIndex,
    required this.streakDays,
    required this.longestStreak,
    required this.lastReadDate,
    required this.totalArticlesRead,
    required this.totalResearchPapersRead,
    required this.totalReadingMinutes,
    required this.totalFocusSessions,
    required this.readingPersona,
    this.fcmToken,
    this.notificationsEnabled = true,
  });
  
  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      uid: doc.id,
      displayName: data['displayName'] ?? '',
      email: data['email'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastActiveAt: (data['lastActiveAt'] as Timestamp).toDate(),
      totalStars: data['totalStars'] ?? 0,
      weeklyStars: data['weeklyStars'] ?? 0,
      currentRank: data['currentRank'] ?? 'Novice',
      rankIndex: data['rankIndex'] ?? 0,
      streakDays: data['streakDays'] ?? 0,
      longestStreak: data['longestStreak'] ?? 0,
      lastReadDate: data['lastReadDate'] ?? '',
      totalArticlesRead: data['totalArticlesRead'] ?? 0,
      totalResearchPapersRead: data['totalResearchPapersRead'] ?? 0,
      totalReadingMinutes: data['totalReadingMinutes'] ?? 0,
      totalFocusSessions: data['totalFocusSessions'] ?? 0,
      readingPersona: data['readingPersona'] ?? 'The Explorer',
      fcmToken: data['fcmToken'],
      notificationsEnabled: data['notificationsEnabled'] ?? true,
    );
  }
  
  Map<String, dynamic> toFirestore() => {
    'uid': uid,
    'displayName': displayName,
    'email': email,
    'createdAt': Timestamp.fromDate(createdAt),
    'lastActiveAt': Timestamp.fromDate(lastActiveAt),
    'totalStars': totalStars,
    'weeklyStars': weeklyStars,
    'currentRank': currentRank,
    'rankIndex': rankIndex,
    'streakDays': streakDays,
    'longestStreak': longestStreak,
    'lastReadDate': lastReadDate,
    'totalArticlesRead': totalArticlesRead,
    'totalResearchPapersRead': totalResearchPapersRead,
    'totalReadingMinutes': totalReadingMinutes,
    'totalFocusSessions': totalFocusSessions,
    'readingPersona': readingPersona,
    'fcmToken': fcmToken,
    'notificationsEnabled': notificationsEnabled,
  };
  
  // Helper to create initial user profile
  factory UserProfile.initial({
    required String uid,
    required String displayName,
    required String email,
  }) {
    return UserProfile(
      uid: uid,
      displayName: displayName,
      email: email,
      createdAt: DateTime.now(),
      lastActiveAt: DateTime.now(),
      totalStars: 0,
      weeklyStars: 0,
      currentRank: 'Novice',
      rankIndex: 0,
      streakDays: 0,
      longestStreak: 0,
      lastReadDate: '',
      totalArticlesRead: 0,
      totalResearchPapersRead: 0,
      totalReadingMinutes: 0,
      totalFocusSessions: 0,
      readingPersona: 'The Explorer',
      notificationsEnabled: true,
    );
  }
}
