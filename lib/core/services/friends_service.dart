import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/friend_request.dart';
import '../../data/models/suggested_user.dart';
import '../../data/models/user_profile.dart';

class FriendsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Calculate match score between two users
  double calculateMatchScore(
    UserProfile currentUser,
    UserProfile otherUser,
  ) {
    double score = 0.0;

    final currentCategories = currentUser.preferredCategories;
    final otherCategories = otherUser.preferredCategories;

    if (currentCategories.isEmpty || otherCategories.isEmpty) return 0.0;

    // +30 for same primary category
    if (currentCategories.first == otherCategories.first) {
      score += 0.30;
    }

    // +15 for each shared category (excluding primary)
    final sharedCategories = currentCategories
        .toSet()
        .intersection(otherCategories.toSet())
        .length;
    score += (sharedCategories - 1) * 0.15;

    // +10 if active recently (within 24 hours)
    final hoursSinceActive = DateTime.now().difference(otherUser.lastActiveAt).inHours;
    if (hoursSinceActive < 24) {
      score += 0.10;
    }

    // +10 if same country
    if (currentUser.country != null && 
        otherUser.country != null && 
        currentUser.country == otherUser.country) {
      score += 0.10;
    }

    return score.clamp(0.0, 1.0);
  }

  // Get suggested friends
  Stream<List<SuggestedUser>> getSuggestedFriends(String currentUserId) async* {
    final currentUserDoc = await _firestore.collection('users').doc(currentUserId).get();
    if (!currentUserDoc.exists) {
      yield [];
      return;
    }

    final currentUser = UserProfile.fromFirestore(currentUserDoc);

    // Get existing friends and pending requests
    final friendsSnapshot = await _firestore
        .collection('friends')
        .where('user1_id', isEqualTo: currentUserId)
        .get();
    
    final friendsSnapshot2 = await _firestore
        .collection('friends')
        .where('user2_id', isEqualTo: currentUserId)
        .get();

    final existingFriendIds = <String>{};
    for (var doc in friendsSnapshot.docs) {
      existingFriendIds.add(doc.data()['user2_id'] as String);
    }
    for (var doc in friendsSnapshot2.docs) {
      existingFriendIds.add(doc.data()['user1_id'] as String);
    }

    // Get pending requests
    final pendingRequests = await _firestore
        .collection('friend_requests')
        .where('senderId', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .get();

    for (var doc in pendingRequests.docs) {
      existingFriendIds.add(doc.data()['receiverId'] as String);
    }

    // Get all users except current user and existing friends
    yield* _firestore.collection('users').snapshots().map((snapshot) {
      final suggestions = <SuggestedUser>[];

      for (var doc in snapshot.docs) {
        if (doc.id == currentUserId || existingFriendIds.contains(doc.id)) {
          continue;
        }

        final otherUser = UserProfile.fromFirestore(doc);
        final matchScore = calculateMatchScore(currentUser, otherUser);

        if (matchScore > 0.1) {
          final matchingCategories = currentUser.preferredCategories
              .toSet()
              .intersection(otherUser.preferredCategories.toSet())
              .toList();

          suggestions.add(SuggestedUser(
            uid: otherUser.uid,
            displayName: otherUser.displayName,
            photoUrl: otherUser.photoUrl,
            bio: otherUser.bio,
            categories: otherUser.preferredCategories,
            streakDays: otherUser.streakDays,
            currentRank: otherUser.currentRank,
            totalStars: otherUser.totalStars,
            isOnline: otherUser.isOnline,
            lastActiveAt: otherUser.lastActiveAt,
            matchScore: matchScore,
            matchingCategories: matchingCategories,
          ));
        }
      }

      suggestions.sort((a, b) => b.matchScore.compareTo(a.matchScore));
      return suggestions;
    });
  }

  // Send friend request
  Future<void> sendFriendRequest(String senderId, String receiverId) async {
    await _firestore.collection('friend_requests').add({
      'senderId': senderId,
      'receiverId': receiverId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Accept friend request
  Future<void> acceptFriendRequest(String requestId, String user1Id, String user2Id) async {
    final batch = _firestore.batch();

    batch.update(_firestore.collection('friend_requests').doc(requestId), {
      'status': 'accepted',
      'respondedAt': FieldValue.serverTimestamp(),
    });

    batch.set(_firestore.collection('friends').doc(), {
      'user1_id': user1Id,
      'user2_id': user2Id,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // Reject friend request
  Future<void> rejectFriendRequest(String requestId) async {
    await _firestore.collection('friend_requests').doc(requestId).update({
      'status': 'rejected',
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  // Get incoming friend requests
  Stream<List<FriendRequest>> getIncomingRequests(String userId) {
    return _firestore
        .collection('friend_requests')
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FriendRequest.fromFirestore(doc))
            .toList());
  }

  // Get outgoing friend requests
  Stream<List<FriendRequest>> getOutgoingRequests(String userId) {
    return _firestore
        .collection('friend_requests')
        .where('senderId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FriendRequest.fromFirestore(doc))
            .toList());
  }

  // Get friends list
  Stream<List<UserProfile>> getFriends(String userId) async* {
    final friendsSnapshot1 = _firestore
        .collection('friends')
        .where('user1_id', isEqualTo: userId)
        .snapshots();

    final friendsSnapshot2 = _firestore
        .collection('friends')
        .where('user2_id', isEqualTo: userId)
        .snapshots();

    await for (var snapshot1 in friendsSnapshot1) {
      final friendIds = <String>[];
      
      for (var doc in snapshot1.docs) {
        friendIds.add(doc.data()['user2_id'] as String);
      }

      final snapshot2 = await _firestore
          .collection('friends')
          .where('user2_id', isEqualTo: userId)
          .get();

      for (var doc in snapshot2.docs) {
        friendIds.add(doc.data()['user1_id'] as String);
      }

      if (friendIds.isEmpty) {
        yield [];
        continue;
      }

      final friendsData = await Future.wait(
        friendIds.map((id) => _firestore.collection('users').doc(id).get()),
      );

      yield friendsData
          .where((doc) => doc.exists)
          .map((doc) => UserProfile.fromFirestore(doc))
          .toList();
    }
  }

  // Remove friend
  Future<void> removeFriend(String userId, String friendId) async {
    final friendsQuery1 = await _firestore
        .collection('friends')
        .where('user1_id', isEqualTo: userId)
        .where('user2_id', isEqualTo: friendId)
        .get();

    final friendsQuery2 = await _firestore
        .collection('friends')
        .where('user1_id', isEqualTo: friendId)
        .where('user2_id', isEqualTo: userId)
        .get();

    for (var doc in friendsQuery1.docs) {
      await doc.reference.delete();
    }

    for (var doc in friendsQuery2.docs) {
      await doc.reference.delete();
    }
  }

  // Check if users are friends
  Future<bool> areFriends(String userId1, String userId2) async {
    final query1 = await _firestore
        .collection('friends')
        .where('user1_id', isEqualTo: userId1)
        .where('user2_id', isEqualTo: userId2)
        .get();

    final query2 = await _firestore
        .collection('friends')
        .where('user1_id', isEqualTo: userId2)
        .where('user2_id', isEqualTo: userId1)
        .get();

    return query1.docs.isNotEmpty || query2.docs.isNotEmpty;
  }
}
