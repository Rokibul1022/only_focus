import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';

class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Create new user profile
  Future<void> createUserProfile(UserProfile profile) async {
    await _firestore
        .collection('users')
        .doc(profile.uid)
        .set({
      ...profile.toFirestore(),
      'hasCompletedOnboarding': false,
      'preferredCategories': [],
    });
  }
  
  // Get user profile
  Future<UserProfile?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromFirestore(doc);
  }
  
  // Stream user profile (real-time updates)
  Stream<UserProfile?> streamUserProfile(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? UserProfile.fromFirestore(doc) : null);
  }
  
  // Update last active timestamp
  Future<void> updateLastActive(String uid) async {
    await _firestore.collection('users').doc(uid).update({
      'lastActiveAt': FieldValue.serverTimestamp(),
    });
  }
  
  // Update FCM token
  Future<void> updateFcmToken(String uid, String token) async {
    await _firestore.collection('users').doc(uid).update({
      'fcmToken': token,
    });
  }
  
  // Get user's read history
  Stream<QuerySnapshot> streamReadHistory(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('readHistory')
        .orderBy('readAt', descending: true)
        .limit(100)
        .snapshots();
  }
  
  // Get user's rewards
  Stream<QuerySnapshot> streamRewards(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('rewards')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots();
  }
  
  // Get user's badges
  Stream<QuerySnapshot> streamBadges(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('badges')
        .orderBy('earnedAt', descending: true)
        .snapshots();
  }
  
  // Get leaderboard
  Future<List<Map<String, dynamic>>> getWeeklyLeaderboard({int limit = 50}) async {
    final snapshot = await _firestore
        .collection('leaderboard')
        .orderBy('weeklyStars', descending: true)
        .limit(limit)
        .get();
    
    return snapshot.docs.map((doc) => {
      'uid': doc.id,
      ...doc.data(),
    }).toList();
  }
  
  // Get user's leaderboard position
  Future<int> getUserLeaderboardPosition(String uid) async {
    final userDoc = await _firestore.collection('leaderboard').doc(uid).get();
    if (!userDoc.exists) return -1;
    
    final userStars = userDoc.data()?['weeklyStars'] ?? 0;
    
    final higherRanked = await _firestore
        .collection('leaderboard')
        .where('weeklyStars', isGreaterThan: userStars)
        .count()
        .get();
    
    return higherRanked.count! + 1;
  }
}
