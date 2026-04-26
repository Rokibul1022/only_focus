import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import '../messages/messaging_screen.dart';

class MessagesTab extends ConsumerWidget {
  const MessagesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) {
      return const Center(child: Text('Please log in'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('friends')
          .where('user1_id', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, friendsSnapshot1) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('friends')
              .where('user2_id', isEqualTo: user.uid)
              .snapshots(),
          builder: (context, friendsSnapshot2) {
            if (friendsSnapshot1.connectionState == ConnectionState.waiting ||
                friendsSnapshot2.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final friends1 = friendsSnapshot1.data?.docs ?? [];
            final friends2 = friendsSnapshot2.data?.docs ?? [];
            
            final friendIds = <String>{};
            for (var doc in friends1) {
              final data = doc.data() as Map<String, dynamic>;
              friendIds.add(data['user2_id'] as String);
            }
            for (var doc in friends2) {
              final data = doc.data() as Map<String, dynamic>;
              friendIds.add(data['user1_id'] as String);
            }

            if (friendIds.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 64, color: AppColors.textSecondary),
                    const SizedBox(height: 16),
                    Text(
                      'No messages yet',
                      style: AppTextStyles.uiH3,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add friends to start chatting',
                      style: AppTextStyles.uiBody.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              );
            }

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .where('participants', arrayContains: user.uid)
                  .snapshots(),
              builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final chats = snapshot.data?.docs ?? [];
        final chatFriendIds = <String>{};
        
        for (var chat in chats) {
          final data = chat.data() as Map<String, dynamic>;
          final participants = List<String>.from(data['participants'] ?? []);
          final friendId = participants.firstWhere((id) => id != user.uid, orElse: () => '');
          if (friendId.isNotEmpty) {
            chatFriendIds.add(friendId);
          }
        }
        
        // Add friends without chats
        final allFriendIds = [...chatFriendIds, ...friendIds.where((id) => !chatFriendIds.contains(id))];

        if (allFriendIds.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 64, color: AppColors.textSecondary),
                const SizedBox(height: 16),
                Text(
                  'No friends yet',
                  style: AppTextStyles.uiH3,
                ),
                const SizedBox(height: 8),
                Text(
                  'Add friends to start chatting',
                  style: AppTextStyles.uiBody.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: allFriendIds.length,
          itemBuilder: (context, index) {
            final friendId = allFriendIds[index];
            
            DocumentSnapshot? chatDoc;
            try {
              chatDoc = chats.firstWhere(
                (doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final participants = List<String>.from(data['participants'] ?? []);
                  return participants.contains(friendId);
                },
              );
            } catch (e) {
              chatDoc = null;
            }
            
            final hasChat = chatDoc != null;
            final chat = hasChat ? (chatDoc.data() as Map<String, dynamic>) : <String, dynamic>{};

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(friendId).get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return const SizedBox();
                }

                final friendData = userSnapshot.data!.data() as Map<String, dynamic>?;
                if (friendData == null) return const SizedBox();

                final friendName = friendData['displayName'] ?? 'Friend';
                final friendPhotoUrl = friendData['photoUrl'] as String?;
                final lastMessage = chat['lastMessage'] as String? ?? '';
                final lastMessageTime = chat['lastMessageTime'] as Timestamp?;
                final lastSenderId = chat['lastSenderId'] as String?;
                final isMe = lastSenderId == user.uid;

                String timeStr = '';
                if (lastMessageTime != null) {
                  final time = lastMessageTime.toDate();
                  final now = DateTime.now();
                  final diff = now.difference(time);
                  
                  if (diff.inMinutes < 1) {
                    timeStr = 'Just now';
                  } else if (diff.inHours < 1) {
                    timeStr = '${diff.inMinutes}m ago';
                  } else if (diff.inDays < 1) {
                    timeStr = '${diff.inHours}h ago';
                  } else if (diff.inDays < 7) {
                    timeStr = '${diff.inDays}d ago';
                  } else {
                    timeStr = '${time.day}/${time.month}/${time.year}';
                  }
                }

                return StreamBuilder<QuerySnapshot?>(
                  stream: hasChat && chatDoc != null
                      ? FirebaseFirestore.instance
                          .collection('chats')
                          .doc(chatDoc.id)
                          .collection('messages')
                          .where('receiverId', isEqualTo: user.uid)
                          .where('read', isEqualTo: false)
                          .snapshots()
                      : Stream<QuerySnapshot?>.value(null),
                  builder: (context, unreadSnapshot) {
                    final unreadCount = unreadSnapshot.hasData && unreadSnapshot.data != null
                        ? unreadSnapshot.data!.docs.length
                        : 0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: AppColors.primary.withOpacity(0.1),
                              backgroundImage: friendPhotoUrl != null ? NetworkImage(friendPhotoUrl) : null,
                              child: friendPhotoUrl == null
                                  ? Text(
                                      friendName[0].toUpperCase(),
                                      style: AppTextStyles.uiH3.copyWith(color: AppColors.primary),
                                    )
                                  : null,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: (friendData['isOnline'] ?? false) ? Colors.green : Colors.grey,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                        title: Text(
                          friendName,
                          style: AppTextStyles.uiBody.copyWith(
                            fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: hasChat && lastMessage.isNotEmpty
                            ? Text(
                                isMe ? 'You: $lastMessage' : lastMessage,
                                style: AppTextStyles.uiCaption.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : Text(
                                'Tap to start chatting',
                                style: AppTextStyles.uiCaption.copyWith(color: AppColors.textSecondary),
                              ),
                        trailing: hasChat && timeStr.isNotEmpty
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    timeStr,
                                    style: AppTextStyles.uiCaption.copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                  if (unreadCount > 0) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        unreadCount.toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              )
                            : (unreadCount > 0
                                ? Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      unreadCount.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                : null),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MessagingScreen(
                                friendId: friendId,
                                friendName: friendName,
                                friendPhotoUrl: friendPhotoUrl,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
          },
        );
      },
    );
  }
}
