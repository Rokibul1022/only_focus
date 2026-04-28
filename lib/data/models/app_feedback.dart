import 'package:cloud_firestore/cloud_firestore.dart';

class AppFeedback {
  final String id;
  final String userId;
  final String userName;
  final String userPhotoUrl;
  final double rating;
  final String experience;
  final String review;
  final String problems;
  final String improvements;
  final DateTime submittedAt;
  
  AppFeedback({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhotoUrl,
    required this.rating,
    required this.experience,
    required this.review,
    required this.problems,
    required this.improvements,
    required this.submittedAt,
  });
  
  factory AppFeedback.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppFeedback(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Anonymous',
      userPhotoUrl: data['userPhotoUrl'] ?? '',
      rating: (data['rating'] ?? 0).toDouble(),
      experience: data['experience'] ?? '',
      review: data['review'] ?? '',
      problems: data['problems'] ?? '',
      improvements: data['improvements'] ?? '',
      submittedAt: (data['submittedAt'] as Timestamp).toDate(),
    );
  }
  
  Map<String, dynamic> toFirestore() => {
    'userId': userId,
    'userName': userName,
    'userPhotoUrl': userPhotoUrl,
    'rating': rating,
    'experience': experience,
    'review': review,
    'problems': problems,
    'improvements': improvements,
    'submittedAt': Timestamp.fromDate(submittedAt),
  };
}
