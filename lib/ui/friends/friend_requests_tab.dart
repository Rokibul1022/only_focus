import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../providers/friends_provider.dart';
import '../../providers/auth_provider.dart';
import '../../data/models/user_profile.dart';

class FriendRequestsTab extends ConsumerWidget {
  const FriendRequestsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incomingRequests = ref.watch(incomingRequestsProvider);
    final outgoingRequests = ref.watch(outgoingRequestsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Incoming Requests', style: AppTextStyles.uiH3),
          const SizedBox(height: 12),
          incomingRequests.when(
            data: (requests) {
              if (requests.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No incoming requests',
                        style: AppTextStyles.uiBody.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children: requests.map((request) {
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(request.senderId)
                        .get(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const SizedBox.shrink();
                      }

                      final sender = UserProfile.fromFirestore(snapshot.data!);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: AppColors.primary.withOpacity(0.1),
                                backgroundImage: sender.photoUrl != null
                                    ? (sender.photoUrl!.startsWith('http')
                                        ? NetworkImage(sender.photoUrl!)
                                        : (File(sender.photoUrl!).existsSync()
                                            ? FileImage(File(sender.photoUrl!))
                                            : null)) as ImageProvider?
                                    : null,
                                child: sender.photoUrl == null ||
                                       (!sender.photoUrl!.startsWith('http') && !File(sender.photoUrl!).existsSync())
                                    ? Text(
                                        sender.displayName[0].toUpperCase(),
                                        style: AppTextStyles.uiH3.copyWith(color: AppColors.primary),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(sender.displayName, style: AppTextStyles.uiBody),
                                    Text(
                                      sender.currentRank,
                                      style: AppTextStyles.uiCaption.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () async {
                                  final currentUser = ref.read(authStateProvider).value;
                                  if (currentUser != null) {
                                    await ref.read(friendsServiceProvider).acceptFriendRequest(
                                          request.id,
                                          request.senderId,
                                          currentUser.uid,
                                        );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Friend request accepted!')),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.check_circle, color: Colors.green),
                              ),
                              IconButton(
                                onPressed: () async {
                                  await ref.read(friendsServiceProvider).rejectFriendRequest(request.id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Friend request rejected')),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.cancel, color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Text('Error: $error'),
          ),
          const SizedBox(height: 24),
          Text('Outgoing Requests', style: AppTextStyles.uiH3),
          const SizedBox(height: 12),
          outgoingRequests.when(
            data: (requests) {
              if (requests.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No outgoing requests',
                        style: AppTextStyles.uiBody.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children: requests.map((request) {
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(request.receiverId)
                        .get(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const SizedBox.shrink();
                      }

                      final receiver = UserProfile.fromFirestore(snapshot.data!);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            backgroundImage: receiver.photoUrl != null
                                ? (receiver.photoUrl!.startsWith('http')
                                    ? NetworkImage(receiver.photoUrl!)
                                    : (File(receiver.photoUrl!).existsSync()
                                        ? FileImage(File(receiver.photoUrl!))
                                        : null)) as ImageProvider?
                                : null,
                            child: receiver.photoUrl == null ||
                                   (!receiver.photoUrl!.startsWith('http') && !File(receiver.photoUrl!).existsSync())
                                ? Text(
                                    receiver.displayName[0].toUpperCase(),
                                    style: AppTextStyles.uiBody.copyWith(color: AppColors.primary),
                                  )
                                : null,
                          ),
                          title: Text(receiver.displayName, style: AppTextStyles.uiBody),
                          subtitle: Text(
                            'Pending',
                            style: AppTextStyles.uiCaption.copyWith(color: Colors.orange),
                          ),
                          trailing: const Icon(Icons.schedule, color: Colors.orange),
                        ),
                      );
                    },
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Text('Error: $error'),
          ),
        ],
      ),
    );
  }
}
