import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../data/models/user_profile.dart';
import '../../providers/posts_provider.dart';
import '../../providers/friends_provider.dart';
import '../../providers/auth_provider.dart';
import '../posts/post_detail_screen.dart';
import '../messages/messaging_screen.dart';
import 'dart:io';

class UserProfilePreviewScreen extends ConsumerWidget {
  final String userId;

  const UserProfilePreviewScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final currentUser = authState.value;
    
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in')),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppColors.background,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = UserProfile.fromFirestore(snapshot.data!);
          final userPosts = ref.watch(userPostsProvider(userId));

          return SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.accent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: Colors.white,
                        backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                        child: user.photoUrl == null
                            ? Text(
                                user.displayName[0].toUpperCase(),
                                style: AppTextStyles.uiH1.copyWith(color: AppColors.primary),
                              )
                            : null,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user.displayName,
                        style: AppTextStyles.uiH1.copyWith(color: Colors.white),
                      ),
                      if (user.bio != null) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            user.bio!,
                            style: AppTextStyles.uiBody.copyWith(color: Colors.white70),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatCard('Stars', user.totalStars.toString(), Icons.star),
                          _buildStatCard('Rank', user.currentRank, Icons.emoji_events),
                          _buildStatCard('Streak', '${user.streakDays}d', Icons.local_fire_department),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: FutureBuilder<bool>(
                              future: ref.read(friendsServiceProvider).areFriends(currentUser.uid, userId),
                              builder: (context, friendSnapshot) {
                                final areFriends = friendSnapshot.data ?? false;
                                
                                return ElevatedButton.icon(
                                  onPressed: areFriends ? null : () async {
                                    await ref
                                        .read(friendsServiceProvider)
                                        .sendFriendRequest(currentUser.uid, userId);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Friend request sent!')),
                                      );
                                    }
                                  },
                                  icon: Icon(areFriends ? Icons.check : Icons.person_add),
                                  label: Text(areFriends ? 'Friends' : 'Add Friend'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: areFriends ? Colors.grey : AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => MessagingScreen(
                                      friendId: user.uid,
                                      friendName: user.displayName,
                                      friendPhotoUrl: user.photoUrl,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.message),
                              label: const Text('Message'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: BorderSide(color: AppColors.primary),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text('Interests', style: AppTextStyles.uiH3),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: user.preferredCategories.map((category) {
                          return Chip(
                            label: Text(category),
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            labelStyle: AppTextStyles.uiCaption.copyWith(color: AppColors.primary),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      Text('Recent Posts', style: AppTextStyles.uiH3),
                      const SizedBox(height: 12),
                      userPosts.when(
                        data: (posts) {
                          if (posts.isEmpty) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text('No posts yet'),
                              ),
                            );
                          }

                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: posts.length,
                            itemBuilder: (context, index) {
                              final post = posts[index];
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PostDetailScreen(post: post),
                                    ),
                                  );
                                },
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        File(post.imagePaths.first),
                                        fit: BoxFit.cover,
                                        width: double.infinity,
                                        height: double.infinity,
                                      ),
                                    ),
                                    if (post.status.name == 'pending')
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.orange.withOpacity(0.7),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Center(
                                            child: Icon(Icons.schedule, color: Colors.white, size: 20),
                                          ),
                                        ),
                                      ),
                                    if (post.status.name == 'rejected')
                                      Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.red.withOpacity(0.7),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Center(
                                            child: Icon(Icons.block, color: Colors.white, size: 20),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (error, stack) => Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text('Error loading posts: $error'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.uiH2.copyWith(color: Colors.white),
          ),
          Text(
            label,
            style: AppTextStyles.uiCaption.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
