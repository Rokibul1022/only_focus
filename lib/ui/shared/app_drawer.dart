import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../wiki/wiki_search_screen.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final userProfile = ref.watch(userProfileProvider);
    
    return Drawer(
      child: Column(
        children: [
          // Header with logo
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/Sleek eye logo for Only Focus app.png',
                  height: 80,
                  width: 80,
                ),
                const SizedBox(height: 12),
                Text(
                  'ONLY FOCUS',
                  style: AppTextStyles.uiH2.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          
          // User info
          userProfile.when(
            data: (profile) {
              if (profile == null) return const SizedBox();
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: Text(
                    profile.displayName.isNotEmpty 
                        ? profile.displayName[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(profile.displayName),
                subtitle: Text('${profile.totalStars} stars'),
              );
            },
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),
          
          const Divider(),
          
          // Wiki Search
          ListTile(
            leading: const Icon(Icons.search),
            title: const Text('Wikipedia Search'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WikiSearchScreen(),
                ),
              );
            },
          ),
          
          // Notes
          ListTile(
            leading: const Icon(Icons.note),
            title: const Text('My Notes'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/notes');
            },
          ),
          
          // Theme Toggle
          ListTile(
            leading: Icon(
              themeMode == ThemeMode.light 
                  ? Icons.light_mode 
                  : themeMode == ThemeMode.dark 
                      ? Icons.dark_mode 
                      : Icons.brightness_auto,
            ),
            title: const Text('Theme'),
            subtitle: Text(
              themeMode == ThemeMode.light 
                  ? 'Light' 
                  : themeMode == ThemeMode.dark 
                      ? 'Dark' 
                      : 'System',
            ),
            trailing: Switch(
              value: themeMode == ThemeMode.dark,
              onChanged: (value) {
                ref.read(themeModeProvider.notifier).toggleTheme();
              },
            ),
            onTap: () {
              ref.read(themeModeProvider.notifier).toggleTheme();
            },
          ),
          
          const Divider(),
          
          // About
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('About'),
            onTap: () {
              Navigator.pop(context);
              showAboutDialog(
                context: context,
                applicationName: 'Only Focus',
                applicationVersion: '1.0.0',
                applicationIcon: Image.asset(
                  'assets/images/Sleek eye logo for Only Focus app.png',
                  height: 48,
                  width: 48,
                ),
                children: [
                  const Text('A distraction-free reading app for tech news, science, and research papers.'),
                ],
              );
            },
          ),
          
          const Spacer(),
          
          // Logout
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.warning),
            title: const Text('Logout', style: TextStyle(color: AppColors.warning)),
            onTap: () async {
              await ref.read(authServiceProvider).signOut();
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
