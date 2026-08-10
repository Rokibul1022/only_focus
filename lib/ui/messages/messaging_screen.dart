import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import '../../providers/friends_provider.dart';

class MessagingScreen extends ConsumerStatefulWidget {
  final String friendId;
  final String friendName;
  final String? friendPhotoUrl;

  const MessagingScreen({
    super.key,
    required this.friendId,
    required this.friendName,
    this.friendPhotoUrl,
  });

  @override
  ConsumerState<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends ConsumerState<MessagingScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 500), () {
      _markMessagesAsRead();
    });
  }

  Future<void> _markMessagesAsRead() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    final chatId = _getChatId(user.uid, widget.friendId);
    
    try {
      final unreadMessages = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('receiverId', isEqualTo: user.uid)
          .where('read', isEqualTo: false)
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in unreadMessages.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _getChatId(String userId1, String userId2) {
    return userId1.compareTo(userId2) < 0 ? '${userId1}_$userId2' : '${userId2}_$userId1';
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    final chatId = _getChatId(user.uid, widget.friendId);
    final message = _messageController.text.trim();
    _messageController.clear();

    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .add({
        'senderId': user.uid,
        'receiverId': widget.friendId,
        'text': message,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });

      await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
        'participants': [user.uid, widget.friendId],
        'lastMessage': message,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderId': user.uid,
      }, SetOptions(merge: true));

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    if (user == null) return const Scaffold();

    final chatId = _getChatId(user.uid, widget.friendId);

    return FutureBuilder<bool>(
      future: ref.read(friendsServiceProvider).areFriends(user.uid, widget.friendId),
      builder: (context, friendSnapshot) {
        if (!friendSnapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!friendSnapshot.data!) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Message'),
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.block, size: 64, color: AppColors.warning),
                  const SizedBox(height: 16),
                  Text(
                    'You must be friends to message',
                    style: AppTextStyles.uiH3,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Send a friend request first',
                    style: AppTextStyles.uiBody.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primary.withOpacity(0.1),
              backgroundImage: widget.friendPhotoUrl != null
                  ? (widget.friendPhotoUrl!.startsWith('http')
                      ? NetworkImage(widget.friendPhotoUrl!)
                      : (File(widget.friendPhotoUrl!).existsSync()
                          ? FileImage(File(widget.friendPhotoUrl!))
                          : null)) as ImageProvider?
                  : null,
              child: widget.friendPhotoUrl == null ||
                     (!widget.friendPhotoUrl!.startsWith('http') && !File(widget.friendPhotoUrl!).existsSync())
                  ? Text(
                      widget.friendName[0].toUpperCase(),
                      style: AppTextStyles.uiCaption.copyWith(color: AppColors.primary),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Text(widget.friendName, style: AppTextStyles.uiH3),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(chatId)
                  .collection('messages')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  print('Stream error: ${snapshot.error}');
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: AppColors.warning),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading messages',
                          style: AppTextStyles.uiBody.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.error}',
                          style: AppTextStyles.uiCaption.copyWith(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: AppColors.textSecondary),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: AppTextStyles.uiBody.copyWith(
                            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Send a message to start chatting',
                          style: AppTextStyles.uiCaption.copyWith(
                            color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data!.docs;
                
                // Sort messages by timestamp
                messages.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTime = aData['createdAt'] as Timestamp?;
                  final bTime = bData['createdAt'] as Timestamp?;
                  if (aTime == null) return -1;
                  if (bTime == null) return 1;
                  return aTime.compareTo(bTime);
                });

                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index].data() as Map<String, dynamic>;
                    final senderId = message['senderId'] as String;
                    final text = message['text'] as String;
                    final timestamp = message['createdAt'] as Timestamp?;
                    final isMe = senderId == user.uid;
                    
                    String timeStr = '';
                    if (timestamp != null) {
                      final time = timestamp.toDate();
                      final now = DateTime.now();
                      if (time.day == now.day && time.month == now.month && time.year == now.year) {
                        timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                      } else {
                        timeStr = '${time.day}/${time.month} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.7,
                            ),
                            decoration: BoxDecoration(
                              color: isMe ? AppColors.primary : Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              text,
                              style: AppTextStyles.uiBody.copyWith(
                                color: isMe ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
                              ),
                            ),
                          ),
                          if (timeStr.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, left: 8, right: 8),
                              child: Text(
                                timeStr,
                                style: AppTextStyles.uiCaption.copyWith(
                                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.6),
                                  fontSize: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).scaffoldBackgroundColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send, color: Colors.white),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
      },
    );
  }
}
