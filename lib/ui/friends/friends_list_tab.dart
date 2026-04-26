import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../providers/friends_provider.dart';
import '../../providers/auth_provider.dart';
import '../messages/messaging_screen.dart';
import 'user_profile_preview_screen.dart';

class FriendsListTab extends ConsumerWidget {
  const FriendsListTab({super.key});

  Future<int> _getUnreadCount(WidgetRef ref, String friendId) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return 0;

    final chatId = user.uid.compareTo(friendId) < 0 
        ? '${user.uid}_$friendId' 
        : '${friendId}_${user.uid}';

    final snapshot = await FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('receiverId', isEqualTo: user.uid)
        .where('read', isEqualTo: false)
        .get();

    return snapshot.docs.length;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(friendsListProvider);

    return friends.when(
      data: (friendsList) {
        if (friendsList.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 80, color: AppColors.textSecondary),
                const SizedBox(height: 16),
                Text('No friends yet', style: AppTextStyles.uiH3),
                const SizedBox(height: 8),
                Text(
                  'Add friends to connect and share',
                  style: AppTextStyles.uiBody.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: friendsList.length,
          itemBuilder: (context, index) {
            final friend = friendsList[index];
            final isOnline = friend.isOnline;
            final lastActive = DateTime.now().difference(friend.lastActiveAt);
            String statusText = '';
            
            if (isOnline) {
              statusText = 'Online';
            } else if (lastActive.inMinutes < 60) {
              statusText = '${lastActive.inMinutes}m ago';
            } else if (lastActive.inHours < 24) {
              statusText = '${lastActive.inHours}h ago';
            } else {
              statusText = '${lastActive.inDays}d ago';
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      backgroundImage: friend.photoUrl != null ? NetworkImage(friend.photoUrl!) : null,
                      child: friend.photoUrl == null
                          ? Text(
                              friend.displayName[0].toUpperCase(),
                              style: AppTextStyles.uiH3.copyWith(color: AppColors.primary),
                            )
                          : null,
                    ),
                    if (isOnline)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                title: Text(friend.displayName, style: AppTextStyles.uiH3),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: AppTextStyles.uiCaption.copyWith(
                        color: isOnline ? Colors.green : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star, size: 12, color: AppColors.reward),
                        const SizedBox(width: 4),
                        Text(
                          '${friend.totalStars} stars',
                          style: AppTextStyles.uiCaption.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: PopupMenuButton(
                  icon: const Icon(Icons.more_vert),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      child: const Row(
                        children: [
                          Icon(Icons.person, size: 20),
                          SizedBox(width: 8),
                          Text('View Profile'),
                        ],
                      ),
                      onTap: () {
                        Future.delayed(Duration.zero, () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UserProfilePreviewScreen(userId: friend.uid),
                            ),
                          );
                        });
                      },
                    ),
                    PopupMenuItem(
                      child: Row(
                        children: [
                          const Icon(Icons.message, size: 20),
                          const SizedBox(width: 8),
                          const Text('Message'),
                          Consumer(
                            builder: (context, ref, child) {
                              return FutureBuilder<int>(
                                future: _getUnreadCount(ref, friend.uid),
                                builder: (context, snapshot) {
                                  final count = snapshot.data ?? 0;
                                  if (count == 0) return const SizedBox.shrink();
                                  return Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 18,
                                      minHeight: 18,
                                    ),
                                    child: Text(
                                      count.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                      onTap: () {
                        Future.delayed(Duration.zero, () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MessagingScreen(
                                friendId: friend.uid,
                                friendName: friend.displayName,
                                friendPhotoUrl: friend.photoUrl,
                              ),
                            ),
                          );
                        });
                      },
                    ),
                    PopupMenuItem(
                      child: const Row(
                        children: [
                          Icon(Icons.person_remove, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Remove Friend', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                      onTap: () async {
                        final currentUser = ref.read(authStateProvider).value;
                        if (currentUser != null) {
                          await ref.read(friendsServiceProvider).removeFriend(
                                currentUser.uid,
                                friend.uid,
                              );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Friend removed')),
                            );
                          }
                        }
                      },
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
