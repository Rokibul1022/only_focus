import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_provider.dart';

final unreadMessagesCountProvider = StreamProvider.autoDispose<int>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(0);

  return FirebaseFirestore.instance
      .collection('chats')
      .where('participants', arrayContains: user.uid)
      .snapshots()
      .asyncMap((snapshot) async {
    int totalUnread = 0;

    for (var chatDoc in snapshot.docs) {
      final chatData = chatDoc.data();
      final lastSenderId = chatData['lastSenderId'] as String?;
      
      // Only count if the last message was not sent by current user
      if (lastSenderId != null && lastSenderId != user.uid) {
        final messagesSnapshot = await chatDoc.reference
            .collection('messages')
            .where('receiverId', isEqualTo: user.uid)
            .where('read', isEqualTo: false)
            .get();
        
        totalUnread += messagesSnapshot.docs.length;
      }
    }

    return totalUnread;
  });
});
