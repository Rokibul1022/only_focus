import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import '../../providers/posts_provider.dart';
import '../../providers/friends_provider.dart';
import '../../data/models/user_post.dart';
import '../posts/post_detail_screen.dart';
import '../posts/post_upload_screen.dart';
import 'friends_list_tab.dart';
import 'friend_requests_tab.dart';
import 'suggested_friends_tab.dart';
import 'messages_tab.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: false,
          labelStyle: const TextStyle(fontSize: 11),
          tabs: const [
            Tab(text: 'Posts', icon: Icon(Icons.article, size: 20)),
            Tab(text: 'Friends', icon: Icon(Icons.people, size: 20)),
            Tab(text: 'Messages', icon: Icon(Icons.message, size: 20)),
            Tab(text: 'Suggested', icon: Icon(Icons.explore, size: 20)),
            Tab(text: 'Requests', icon: Icon(Icons.person_add, size: 20)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPostsTab(),
          const FriendsListTab(),
          const MessagesTab(),
          const SuggestedFriendsTab(),
          const FriendRequestsTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PostUploadScreen()),
                );
              },
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildPostsTab() {
    final friendsPosts = ref.watch(approvedPostsProvider);
    final friendsList = ref.watch(friendsListProvider);
    final currentUser = ref.watch(authStateProvider).value;

    return friendsPosts.when(
      data: (posts) {
        final friendIds = friendsList.when(
          data: (friends) => friends.map((f) => f.uid).toSet(),
          loading: () => <String>{},
          error: (_, __) => <String>{},
        );

        final friendsPostsList = currentUser != null
            ? posts.where((p) => friendIds.contains(p.userId) || p.userId == currentUser.uid).toList()
            : <UserPost>[];

        if (friendsPostsList.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.article_outlined,
                  size: 80,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No posts yet',
                  style: AppTextStyles.uiH2.copyWith(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Share your reading journey',
                  style: AppTextStyles.uiBody.copyWith(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: friendsPostsList.length,
          itemBuilder: (context, index) {
            final post = friendsPostsList[index];
            return _buildPostCard(post);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text('Error: $error', style: AppTextStyles.uiBody),
      ),
    );
  }

  Widget _buildPostCard(UserPost post) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(post.userId).get(),
      builder: (context, snapshot) {
        final userName = snapshot.hasData && snapshot.data!.data() != null
            ? ((snapshot.data!.data() as Map<String, dynamic>)['displayName'] as String?) ?? 'Friend'
            : 'Friend';

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PostDetailScreen(post: post),
                ),
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.imagePaths.isNotEmpty)
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.file(
                      File(post.imagePaths.first),
                      fit: BoxFit.cover,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person, size: 16, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            userName,
                            style: AppTextStyles.uiCaption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        post.title,
                        style: AppTextStyles.uiH3,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (post.description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          post.description,
                          style: AppTextStyles.uiBody.copyWith(color: AppColors.textSecondary),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.favorite_border, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text('${post.likesCount}', style: AppTextStyles.uiCaption),
                          const SizedBox(width: 16),
                          Icon(Icons.comment_outlined, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text('${post.commentsCount}', style: AppTextStyles.uiCaption),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
