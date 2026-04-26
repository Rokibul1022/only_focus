import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/friends_service.dart';
import '../data/models/suggested_user.dart';
import '../data/models/friend_request.dart';
import '../data/models/user_profile.dart';
import 'auth_provider.dart';

final friendsServiceProvider = Provider((ref) => FriendsService());

final suggestedFriendsProvider = StreamProvider.autoDispose<List<SuggestedUser>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);
  
  final service = ref.watch(friendsServiceProvider);
  return service.getSuggestedFriends(user.uid);
});

final friendsListProvider = StreamProvider.autoDispose<List<UserProfile>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);
  
  final service = ref.watch(friendsServiceProvider);
  return service.getFriends(user.uid);
});

final incomingRequestsProvider = StreamProvider.autoDispose<List<FriendRequest>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);
  
  final service = ref.watch(friendsServiceProvider);
  return service.getIncomingRequests(user.uid);
});

final outgoingRequestsProvider = StreamProvider.autoDispose<List<FriendRequest>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value([]);
  
  final service = ref.watch(friendsServiceProvider);
  return service.getOutgoingRequests(user.uid);
});
