import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/star_calculator.dart';
import '../../core/utils/image_helper.dart';
import '../../providers/auth_provider.dart';
import '../../providers/posts_provider.dart';
import '../../data/models/user_post.dart';
import '../posts/post_detail_screen.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  
  Future<void> _pickAndUploadPhoto() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      
      if (image == null) return;
      
      final user = ref.read(authStateProvider).value;
      if (user == null) return;
      
      // Save to local storage
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'profile_${user.uid}.jpg';
      final savedImage = await File(image.path).copy('${appDir.path}/$fileName');
      
      // Update Firestore with local path
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'photoUrl': savedImage.path,
        'hasCustomPhoto': true,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated'), duration: Duration(seconds: 2)),
        );
        ref.invalidate(userProfileProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), duration: const Duration(seconds: 2)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(userProfileProvider);
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text('My Profile', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.warning),
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
            child: Column(
              children: [
                // Professional Header with gradient
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                    child: Column(
                      children: [
                        // Profile Photo with edit button
                        Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 4),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 60,
                                backgroundColor: Theme.of(context).cardColor,
                                backgroundImage: ImageHelper.getImageProvider(profile.photoUrl),
                                child: ImageHelper.getImageProvider(profile.photoUrl) == null
                                    ? Text(
                                        profile.displayName.isNotEmpty
                                            ? profile.displayName[0].toUpperCase()
                                            : 'U',
                                        style: TextStyle(
                                          fontSize: 48,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppColors.primary,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _pickAndUploadPhoto,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: AppColors.primary,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Name
                        Text(
                          profile.displayName,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        // Rank Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.emoji_events, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                profile.currentRank,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Reading Persona
                        Text(
                          profile.readingPersona,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Dashboard Stats Section
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stars Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.reward.withOpacity(0.1),
                              AppColors.reward.withOpacity(0.05),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.reward.withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.star, color: AppColors.reward, size: 40),
                                const SizedBox(width: 12),
                                Text(
                                  '${profile.totalStars}',
                                  style: const TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.reward,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Total Stars Earned',
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 20),
                            
                            // Progress to next rank
                            Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Next Rank Progress',
                                      style: AppTextStyles.uiCaption.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      '${(StarCalculator.getProgressToNextRank(profile.totalStars) * 100).toInt()}%',
                                      style: AppTextStyles.uiCaption.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: LinearProgressIndicator(
                                    value: StarCalculator.getProgressToNextRank(profile.totalStars),
                                    backgroundColor: Colors.grey[300],
                                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                                    minHeight: 8,
                                  ),
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
                      
                      // Statistics Dashboard Title
                      Text(
                        'Statistics',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Stats Grid - 2x2
                      Row(
                        children: [
                          Expanded(
                            child: _DashboardStatCard(
                              icon: Icons.article_outlined,
                              value: '${profile.totalArticlesRead}',
                              label: 'Articles Read',
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _DashboardStatCard(
                              icon: Icons.local_fire_department,
                              value: '${profile.streakDays}',
                              label: 'Day Streak',
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _DashboardStatCard(
                              icon: Icons.timer_outlined,
                              value: '${profile.totalReadingMinutes}',
                              label: 'Minutes',
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _DashboardStatCard(
                              icon: Icons.star_outline,
                              value: '${profile.weeklyStars}',
                              label: 'Weekly Stars',
                              color: Colors.purple,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // User Posts Section
                      _buildPostsSection(context, profile.uid),
                    ],
                  ),
                ),
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
  
  Widget _buildPostsSection(BuildContext context, String userId) {
    final userPosts = ref.watch(userPostsProvider(userId));
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'My Posts',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 16),
        userPosts.when(
          data: (posts) {
            if (posts.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.post_add, size: 48, color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6)),
                      const SizedBox(height: 8),
                      Text(
                        'No posts yet',
                        style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6)),
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
                        child: post.imagePaths.isNotEmpty && File(post.imagePaths.first).existsSync()
                            ? Image.file(
                                File(post.imagePaths.first),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Theme.of(context).cardColor,
                                    child: const Icon(Icons.image_not_supported),
                                  );
                                },
                              )
                            : Container(
                                color: Theme.of(context).cardColor,
                                child: const Icon(Icons.image_not_supported),
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

class _DashboardStatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  
  const _DashboardStatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
