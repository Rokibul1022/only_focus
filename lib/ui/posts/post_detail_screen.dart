import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../data/models/user_post.dart';
import '../../data/models/user_profile.dart';
import '../../providers/posts_provider.dart';
import '../../providers/auth_provider.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  final UserPost post;

  const PostDetailScreen({super.key, required this.post});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  final _commentController = TextEditingController();
  bool _isLiked = false;
  int _likesCount = 0;
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _likesCount = widget.post.likesCount;
    _checkIfLiked();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _checkIfLiked() async {
    final user = ref.read(authStateProvider).value;
    if (user != null) {
      final liked = await ref.read(postsServiceProvider).hasLikedPost(widget.post.id, user.uid);
      setState(() => _isLiked = liked);
    }
  }

  Future<void> _toggleLike() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    setState(() {
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
    });

    try {
      if (_isLiked) {
        await ref.read(postsServiceProvider).likePost(widget.post.id, user.uid);
      } else {
        await ref.read(postsServiceProvider).unlikePost(widget.post.id, user.uid);
      }
    } catch (e) {
      setState(() {
        _isLiked = !_isLiked;
        _likesCount += _isLiked ? 1 : -1;
      });
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    try {
      await ref.read(postsServiceProvider).addComment(
            widget.post.id,
            user.uid,
            _commentController.text.trim(),
          );
      _commentController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment added!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
        backgroundColor: AppColors.background,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Author info
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(widget.post.userId)
                        .get(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox.shrink();

                      final author = UserProfile.fromFirestore(snapshot.data!);
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: AppColors.primary.withOpacity(0.1),
                              backgroundImage: author.photoUrl != null
                                  ? (author.photoUrl!.startsWith('http')
                                      ? NetworkImage(author.photoUrl!)
                                      : (File(author.photoUrl!).existsSync()
                                          ? FileImage(File(author.photoUrl!))
                                          : null)) as ImageProvider?
                                  : null,
                              child: author.photoUrl == null ||
                                     (!author.photoUrl!.startsWith('http') && !File(author.photoUrl!).existsSync())
                                  ? Text(
                                      author.displayName[0].toUpperCase(),
                                      style: AppTextStyles.uiH3.copyWith(color: AppColors.primary),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(author.displayName, style: AppTextStyles.uiH3),
                                  Text(
                                    author.currentRank,
                                    style: AppTextStyles.uiCaption.copyWith(
                                      color: AppColors.textSecondary,
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

                  // Images
                  SizedBox(
                    height: 400,
                    child: widget.post.imagePaths.isEmpty
                        ? _buildNoImagesPlaceholder()
                        : Stack(
                            children: [
                              PageView.builder(
                                itemCount: widget.post.imagePaths.length,
                                onPageChanged: (index) {
                                  setState(() => _currentImageIndex = index);
                                },
                                itemBuilder: (context, index) {
                                  final imagePath = widget.post.imagePaths[index];
                                  final imageFile = File(imagePath);
                                  
                                  return FutureBuilder<bool>(
                                    future: imageFile.exists(),
                                    builder: (context, snapshot) {
                                      if (snapshot.data == true) {
                                        return Image.file(
                                          imageFile,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return _buildImagePlaceholder();
                                          },
                                        );
                                      }
                                      return _buildImagePlaceholder();
                                    },
                                  );
                                },
                              ),
                        if (widget.post.imagePaths.length > 1)
                          Positioned(
                            bottom: 16,
                            right: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                '${_currentImageIndex + 1}/${widget.post.imagePaths.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Like and comment buttons
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _toggleLike,
                          icon: Icon(
                            _isLiked ? Icons.favorite : Icons.favorite_border,
                            color: _isLiked ? Colors.red : AppColors.textSecondary,
                          ),
                        ),
                        Text('$_likesCount', style: AppTextStyles.uiBody),
                        const SizedBox(width: 24),
                        Icon(Icons.comment_outlined, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Text('${widget.post.commentsCount}', style: AppTextStyles.uiBody),
                      ],
                    ),
                  ),

                  // Title and description
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.post.title, style: AppTextStyles.uiH2.copyWith(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        )),
                        const SizedBox(height: 8),
                        Text(
                          widget.post.description,
                          style: AppTextStyles.uiBody.copyWith(
                            color: Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Comments section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Comments', style: AppTextStyles.uiH3.copyWith(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    )),
                  ),
                  const SizedBox(height: 12),

                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('posts')
                        .doc(widget.post.id)
                        .collection('comments')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final comments = snapshot.data!.docs;

                      if (comments.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'No comments yet',
                              style: AppTextStyles.uiBody.copyWith(
                                color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                              ),
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: comments.length,
                        itemBuilder: (context, index) {
                          final comment = comments[index].data() as Map<String, dynamic>;
                          final userId = comment['userId'] as String;
                          final text = comment['text'] as String;

                          return FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('users')
                                .doc(userId)
                                .get(),
                            builder: (context, userSnapshot) {
                              if (!userSnapshot.hasData) return const SizedBox.shrink();

                              final user = UserProfile.fromFirestore(userSnapshot.data!);

                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: AppColors.primary.withOpacity(0.1),
                                      backgroundImage: user.photoUrl != null
                                          ? (user.photoUrl!.startsWith('http')
                                              ? NetworkImage(user.photoUrl!)
                                              : (File(user.photoUrl!).existsSync()
                                                  ? FileImage(File(user.photoUrl!))
                                                  : null)) as ImageProvider?
                                          : null,
                                      child: user.photoUrl == null ||
                                             (!user.photoUrl!.startsWith('http') && !File(user.photoUrl!).existsSync())
                                          ? Text(
                                              user.displayName[0].toUpperCase(),
                                              style: AppTextStyles.uiCaption.copyWith(
                                                color: AppColors.primary,
                                              ),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            user.displayName,
                                            style: AppTextStyles.uiBody.copyWith(
                                              color: Theme.of(context).textTheme.bodyLarge?.color,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            text,
                                            style: AppTextStyles.uiBody.copyWith(
                                              color: Theme.of(context).textTheme.bodyMedium?.color,
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
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Comment input
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
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).scaffoldBackgroundColor,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _addComment,
                  icon: const Icon(Icons.send, color: AppColors.primary),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: Theme.of(context).cardColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              size: 64,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Image not available',
              style: AppTextStyles.uiBody.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoImagesPlaceholder() {
    return Container(
      color: Theme.of(context).cardColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No images in this post',
              style: AppTextStyles.uiBody.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
