import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../../data/models/user_post.dart';

class PostsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Save images to local storage and return paths
  Future<List<String>> _saveImagesToLocal(List<File> images, String userId) async {
    final directory = await getApplicationDocumentsDirectory();
    final userPostsDir = Directory('${directory.path}/posts/$userId');
    
    if (!await userPostsDir.exists()) {
      await userPostsDir.create(recursive: true);
    }

    final imagePaths = <String>[];
    for (int i = 0; i < images.length; i++) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${timestamp}_$i.jpg';
      final savedPath = '${userPostsDir.path}/$fileName';
      
      await images[i].copy(savedPath);
      imagePaths.add(savedPath);
    }

    return imagePaths;
  }

  // Create a new post
  Future<String> createPost({
    required String userId,
    required String title,
    required String description,
    required List<File> images,
  }) async {
    // Save images to local storage
    final imagePaths = await _saveImagesToLocal(images, userId);

    // Create post document
    final docRef = await _firestore.collection('posts').add({
      'userId': userId,
      'title': title,
      'description': description,
      'imagePaths': imagePaths,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
      'likesCount': 0,
      'commentsCount': 0,
    });

    // Trigger auto-review
    _autoReviewPost(docRef.id);

    return docRef.id;
  }

  // Auto-review post (simplified - in production use ML/AI)
  Future<void> _autoReviewPost(String postId) async {
    await Future.delayed(const Duration(seconds: 2));
    
    // Simple content check (in production, use Google Cloud Vision API or similar)
    final postDoc = await _firestore.collection('posts').doc(postId).get();
    final data = postDoc.data();
    
    if (data == null) return;

    final title = data['title'] as String;
    final description = data['description'] as String;

    // Basic profanity/spam check
    final bannedWords = ['spam', 'scam', 'fake'];
    bool hasIssue = false;

    for (var word in bannedWords) {
      if (title.toLowerCase().contains(word) || 
          description.toLowerCase().contains(word)) {
        hasIssue = true;
        break;
      }
    }

    if (hasIssue) {
      await _firestore.collection('posts').doc(postId).update({
        'status': 'rejected',
        'reviewedAt': FieldValue.serverTimestamp(),
        'rejectionReason': 'Content violates community guidelines',
      });
    } else {
      await _firestore.collection('posts').doc(postId).update({
        'status': 'approved',
        'reviewedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // Get approved posts for feed
  Stream<List<UserPost>> getApprovedPosts({int limit = 20}) {
    return _firestore
        .collection('posts')
        .where('status', isEqualTo: 'approved')
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserPost.fromFirestore(doc))
            .toList());
  }

  // Get user's posts
  Stream<List<UserPost>> getUserPosts(String userId) {
    return _firestore
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserPost.fromFirestore(doc))
            .toList());
  }

  // Like a post
  Future<void> likePost(String postId, String userId) async {
    final batch = _firestore.batch();

    batch.update(_firestore.collection('posts').doc(postId), {
      'likesCount': FieldValue.increment(1),
    });

    batch.set(_firestore.collection('posts').doc(postId).collection('likes').doc(userId), {
      'userId': userId,
      'likedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  // Unlike a post
  Future<void> unlikePost(String postId, String userId) async {
    final batch = _firestore.batch();

    batch.update(_firestore.collection('posts').doc(postId), {
      'likesCount': FieldValue.increment(-1),
    });

    batch.delete(_firestore.collection('posts').doc(postId).collection('likes').doc(userId));

    await batch.commit();
  }

  // Check if user liked a post
  Future<bool> hasLikedPost(String postId, String userId) async {
    final doc = await _firestore
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(userId)
        .get();
    return doc.exists;
  }

  // Delete post
  Future<void> deletePost(String postId) async {
    final postDoc = await _firestore.collection('posts').doc(postId).get();
    final data = postDoc.data();
    
    if (data != null) {
      final imagePaths = List<String>.from(data['imagePaths'] ?? []);
      
      // Delete images from local storage
      for (var path in imagePaths) {
        try {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (e) {
          // Ignore errors
        }
      }
    }

    await _firestore.collection('posts').doc(postId).delete();
  }
  
  // Add comment to post
  Future<void> addComment(String postId, String userId, String text) async {
    final batch = _firestore.batch();

    batch.update(_firestore.collection('posts').doc(postId), {
      'commentsCount': FieldValue.increment(1),
    });

    batch.set(_firestore.collection('posts').doc(postId).collection('comments').doc(), {
      'userId': userId,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }
}
