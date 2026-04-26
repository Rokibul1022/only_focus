import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../providers/friends_provider.dart';
import 'suggested_friends_tab.dart';
import 'friends_list_tab.dart';
import 'friend_requests_tab.dart';
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
    _tabController = TabController(length: 4, vsync: this);
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
        title: Text('Friends', style: AppTextStyles.uiH2),
        backgroundColor: AppColors.background,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: AppTextStyles.uiBody.copyWith(fontWeight: FontWeight.w600),
          isScrollable: true,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Suggested'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Friends'),
                ],
              ),
            ),
            const Tab(text: 'Messages'),
            Tab(
              child: Consumer(
                builder: (context, ref, child) {
                  final incomingRequests = ref.watch(incomingRequestsProvider);
                  final count = incomingRequests.when(
                    data: (requests) => requests.length,
                    loading: () => 0,
                    error: (_, __) => 0,
                  );
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Requests'),
                      if (count > 0) const SizedBox(width: 4),
                      if (count > 0)
                        Container(
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
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          SuggestedFriendsTab(),
          FriendsListTab(),
          MessagesTab(),
          FriendRequestsTab(),
        ],
      ),
    );
  }
}
