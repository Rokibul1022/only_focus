import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/star_calculator.dart';
import '../../providers/auth_provider.dart';
import '../../providers/posts_provider.dart';
import '../../data/models/user_post.dart';
import '../posts/post_detail_screen.dart';
import 'dart:io';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfile = ref.watch(userProfileProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authServiceProvider).signOut();
            },
          ),
        ],
      ),
      body: userProfile.when(
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('No profile data'));
          }
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Logo and Avatar
                Stack(
                  alignment: Alignment.center,
                  children: [
                    // Background logo (faded)
                    Opacity(
                      opacity: 0.1,
                      child: Image.asset(
                        'assets/images/Sleek eye logo for Only Focus app.png',
                        height: 150,
                        width: 150,
                      ),
                    ),
                    // Avatar
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: AppColors.primary,
                      child: Text(
                        profile.displayName.isNotEmpty 
                            ? profile.displayName[0].toUpperCase()
                            : 'U',
                        style: AppTextStyles.uiH1.copyWith(
                          color: Colors.white,
                          fontSize: 36,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Display name
                Text(
                  profile.displayName,
                  style: AppTextStyles.uiH2,
                ),
                const SizedBox(height: 4),
                
                // Reading persona
                Text(
                  profile.readingPersona,
                  style: AppTextStyles.uiBody.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Stars and rank
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.star, color: AppColors.reward, size: 32),
                          const SizedBox(width: 8),
                          Text(
                            '${profile.totalStars}',
                            style: AppTextStyles.uiH1.copyWith(
                              color: AppColors.reward,
                              fontSize: 36,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Total Stars',
                        style: AppTextStyles.uiBody.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Rank badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _getRankColor(profile.currentRank),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          profile.currentRank,
                          style: AppTextStyles.uiH3.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Progress to next rank
                      Column(
                        children: [
                          LinearProgressIndicator(
                            value: StarCalculator.getProgressToNextRank(profile.totalStars),
                            backgroundColor: Colors.grey[300],
                            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${StarCalculator.getStarsForNextRank(profile.totalStars)} stars to next rank',
                            style: AppTextStyles.uiCaption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Stats grid
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.article,
                        value: '${profile.totalArticlesRead}',
                        label: 'Articles',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.local_fire_department,
                        value: '${profile.streakDays}',
                        label: 'Day Streak',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.timer,
                        value: '${profile.totalReadingMinutes}',
                        label: 'Minutes',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.star,
                        value: '${profile.weeklyStars}',
                        label: 'Weekly Stars',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // User Posts Section
                _buildPostsSection(context, ref, profile.uid),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Error loading profile: $error'),
        ),
      ),
    );
  }
  
  Color _getRankColor(String rank) {
    switch (rank) {
      case 'Legend':
        return AppColors.rankLegend;
      case 'Master':
        return AppColors.rankMaster;
      case 'Expert':
        return AppColors.rankExpert;
      case 'Scholar':
        return AppColors.rankScholar;
      case 'Reader':
        return AppColors.rankReader;
      default:
        return AppColors.rankNovice;
    }
  }
  
  Widget _buildPostsSection(BuildContext context, WidgetRef ref, String userId) {
    final userPosts = ref.watch(userPostsProvider(userId));
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('My Posts', style: AppTextStyles.uiH3),
        const SizedBox(height: 12),
        userPosts.when(
          data: (posts) {
            if (posts.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.post_add, size: 48, color: AppColors.textSecondary),
                      const SizedBox(height: 8),
                      Text(
                        'No posts yet',
                        style: AppTextStyles.uiBody.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
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
                      if (post.status == PostStatus.pending)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Icon(Icons.schedule, color: Colors.white),
                            ),
                          ),
                        ),
                      if (post.status == PostStatus.rejected)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Icon(Icons.block, color: Colors.white),
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
          error: (error, stack) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTextStyles.uiH2,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.uiCaption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
