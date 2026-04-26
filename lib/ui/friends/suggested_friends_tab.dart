import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../providers/friends_provider.dart';
import '../../providers/auth_provider.dart';
import 'user_profile_preview_screen.dart';

class SuggestedFriendsTab extends ConsumerWidget {
  const SuggestedFriendsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestedUsers = ref.watch(suggestedFriendsProvider);

    return suggestedUsers.when(
      data: (users) {
        if (users.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 80, color: AppColors.textSecondary),
                const SizedBox(height: 16),
                Text('No suggestions yet', style: AppTextStyles.uiH3),
                const SizedBox(height: 8),
                Text(
                  'Complete your profile to find friends',
                  style: AppTextStyles.uiBody.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                          child: user.photoUrl == null
                              ? Text(
                                  user.displayName[0].toUpperCase(),
                                  style: AppTextStyles.uiH2.copyWith(color: AppColors.primary),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.displayName, style: AppTextStyles.uiH3),
                              if (user.bio != null)
                                Text(
                                  user.bio!,
                                  style: AppTextStyles.uiCaption.copyWith(color: AppColors.textSecondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              Row(
                                children: [
                                  Icon(Icons.star, size: 14, color: AppColors.reward),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${user.totalStars} stars',
                                    style: AppTextStyles.uiCaption.copyWith(color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      user.currentRank,
                                      style: AppTextStyles.uiCaption.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${user.matchPercentage}%',
                            style: AppTextStyles.uiBody.copyWith(
                              color: AppColors.accent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: user.matchingCategories.take(3).map((category) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            category,
                            style: AppTextStyles.uiCaption.copyWith(color: AppColors.secondary),
                          ),
                        );
                      }).toList(),
                    ),
                    if (user.streakDays > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.local_fire_department, size: 16, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text(
                            '${user.streakDays} day streak',
                            style: AppTextStyles.uiCaption.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => UserProfilePreviewScreen(userId: user.uid),
                                ),
                              );
                            },
                            icon: const Icon(Icons.person),
                            label: const Text('View Profile'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: BorderSide(color: AppColors.primary),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final currentUser = ref.read(authStateProvider).value;
                              if (currentUser != null) {
                                await ref.read(friendsServiceProvider).sendFriendRequest(
                                      currentUser.uid,
                                      user.uid,
                                    );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Friend request sent!')),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.person_add),
                            label: const Text('Add Friend'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Error: $error', style: AppTextStyles.uiBody),
      ),
    );
  }
}
