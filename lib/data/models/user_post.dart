import 'package:cloud_firestore/cloud_firestore.dart';

enum PostStatus { pending, approved, rejected }

class UserPost {
  final String id;
  final String userId;
  final String title;
  final String description;
  final List<String> imagePaths;
  final PostStatus status;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final int likesCount;
  final int commentsCount;
  final String? rejectionReason;

  UserPost({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.imagePaths,
    required this.status,
    required this.createdAt,
    this.reviewedAt,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.rejectionReason,
  });

  factory UserPost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Handle null createdAt (when document is just created)
    DateTime createdAt;
    if (data['createdAt'] != null) {
      createdAt = (data['createdAt'] as Timestamp).toDate();
    } else {
      createdAt = DateTime.now();
    }
    
    return UserPost(
      id: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      imagePaths: List<String>.from(data['imagePaths'] ?? []),
      status: PostStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => PostStatus.pending,
      ),
      createdAt: createdAt,
      reviewedAt: data['reviewedAt'] != null 
          ? (data['reviewedAt'] as Timestamp).toDate() 
          : null,
      likesCount: data['likesCount'] ?? 0,
      commentsCount: data['commentsCount'] ?? 0,
      rejectionReason: data['rejectionReason'],
    );
  }

  Map<String, dynamic> toFirestore() => {
    'userId': userId,
    'title': title,
    'description': description,
    'imagePaths': imagePaths,
    'status': status.name,
    'createdAt': Timestamp.fromDate(createdAt),
    'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
    'likesCount': likesCount,
    'commentsCount': commentsCount,
    'rejectionReason': rejectionReason,
  };
}
