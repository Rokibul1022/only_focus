import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/posts_service.dart';
import '../data/models/user_post.dart';

final postsServiceProvider = Provider((ref) => PostsService());

final approvedPostsProvider = StreamProvider.autoDispose<List<UserPost>>((ref) {
  final service = ref.watch(postsServiceProvider);
  return service.getApprovedPosts();
});

final userPostsProvider = StreamProvider.autoDispose.family<List<UserPost>, String>((ref, userId) {
  final service = ref.watch(postsServiceProvider);
  return service.getUserPosts(userId);
});
