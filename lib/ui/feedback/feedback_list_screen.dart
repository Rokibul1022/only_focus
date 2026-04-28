import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../data/models/app_feedback.dart';

class FeedbackListScreen extends ConsumerWidget {
  const FeedbackListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Feedback'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('app_feedback')
            .orderBy('submittedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.feedback_outlined, size: 64, color: AppColors.textSecondary),
                  const SizedBox(height: 16),
                  Text('No feedback yet', style: AppTextStyles.uiH2),
                  const SizedBox(height: 8),
                  Text(
                    'Be the first to share your thoughts!',
                    style: AppTextStyles.uiBody.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }

          final feedbacks = snapshot.data!.docs
              .map((doc) => AppFeedback.fromFirestore(doc))
              .toList();

          // Calculate average rating
          final avgRating = feedbacks.isEmpty
              ? 0.0
              : feedbacks.map((f) => f.rating).reduce((a, b) => a + b) / feedbacks.length;

          return Column(
            children: [
              // Stats section with total users
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('users').snapshots(),
                builder: (context, userSnapshot) {
                  final totalUsers = userSnapshot.hasData ? userSnapshot.data!.docs.length : 0;
                  
                  return Container(
                    padding: const EdgeInsets.all(20),
                    color: AppColors.primary.withOpacity(0.1),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatCard(
                              'Total Users',
                              totalUsers.toString(),
                              Icons.people,
                              Colors.purple,
                            ),
                            _buildStatCard(
                              'Feedback',
                              feedbacks.length.toString(),
                              Icons.feedback,
                              Colors.blue,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatCard(
                              'Avg Rating',
                              avgRating.toStringAsFixed(1),
                              Icons.star,
                              Colors.amber,
                            ),
                            _buildStatCard(
                              'Response Rate',
                              totalUsers > 0 ? '${((feedbacks.length / totalUsers) * 100).toStringAsFixed(0)}%' : '0%',
                              Icons.analytics,
                              Colors.green,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: feedbacks.length,
                  itemBuilder: (context, index) {
                    final feedback = feedbacks[index];
                    return _buildFeedbackCard(context, feedback);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTextStyles.uiCaption.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackCard(BuildContext context, AppFeedback feedback) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.1),
          backgroundImage: feedback.userPhotoUrl.isNotEmpty
              ? FileImage(File(feedback.userPhotoUrl))
              : null,
          child: feedback.userPhotoUrl.isEmpty
              ? Text(
                  feedback.userName[0].toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                feedback.userName,
                style: AppTextStyles.uiBody.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.star, color: Colors.amber, size: 16),
                const SizedBox(width: 4),
                Text(
                  feedback.rating.toStringAsFixed(1),
                  style: AppTextStyles.uiBody.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
              ],
            ),
          ],
        ),
        subtitle: Text(
          _formatDate(feedback.submittedAt),
          style: AppTextStyles.uiCaption.copyWith(color: AppColors.textSecondary),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (feedback.experience.isNotEmpty) ...[
                  _buildFeedbackSection(
                    'Experience',
                    feedback.experience,
                    Icons.emoji_emotions,
                    Colors.blue,
                  ),
                  const SizedBox(height: 12),
                ],
                if (feedback.review.isNotEmpty) ...[
                  _buildFeedbackSection(
                    'What They Like',
                    feedback.review,
                    Icons.thumb_up,
                    Colors.green,
                  ),
                  const SizedBox(height: 12),
                ],
                if (feedback.problems.isNotEmpty) ...[
                  _buildFeedbackSection(
                    'Problems Found',
                    feedback.problems,
                    Icons.bug_report,
                    Colors.red,
                  ),
                  const SizedBox(height: 12),
                ],
                if (feedback.improvements.isNotEmpty) ...[
                  _buildFeedbackSection(
                    'Suggestions',
                    feedback.improvements,
                    Icons.lightbulb,
                    Colors.orange,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackSection(String title, String content, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTextStyles.uiBody.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: AppTextStyles.uiBody,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return '${diff.inMinutes}m ago';
      }
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
