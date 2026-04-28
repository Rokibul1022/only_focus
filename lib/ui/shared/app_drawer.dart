import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../providers/theme_provider.dart';
import '../../providers/auth_provider.dart';
import '../wiki/wiki_search_screen.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  void _showThemeDialog(BuildContext context, WidgetRef ref, ThemeMode currentTheme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Choose Theme',
                    style: AppTextStyles.uiH2.copyWith(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select your preferred theme',
                    style: AppTextStyles.uiCaption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildThemeOption(
                    context,
                    ref,
                    icon: Icons.light_mode,
                    title: 'Light',
                    subtitle: 'Bright and clear',
                    themeMode: ThemeMode.light,
                    isSelected: currentTheme == ThemeMode.light,
                  ),
                  const SizedBox(height: 12),
                  _buildThemeOption(
                    context,
                    ref,
                    icon: Icons.dark_mode,
                    title: 'Dark',
                    subtitle: 'Easy on the eyes',
                    themeMode: ThemeMode.dark,
                    isSelected: currentTheme == ThemeMode.dark,
                  ),
                  const SizedBox(height: 12),
                  _buildThemeOption(
                    context,
                    ref,
                    icon: Icons.brightness_auto,
                    title: 'System',
                    subtitle: 'Follow device settings',
                    themeMode: ThemeMode.system,
                    isSelected: currentTheme == ThemeMode.system,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    WidgetRef ref, {
    required IconData icon,
    required String title,
    required String subtitle,
    required ThemeMode themeMode,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        ref.read(themeModeProvider.notifier).setThemeMode(themeMode);
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.primary.withOpacity(0.1) 
              : Colors.transparent,
          border: Border.all(
            color: isSelected 
                ? AppColors.primary 
                : Theme.of(context).dividerColor,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.uiBody.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.primary
                          : Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTextStyles.uiCaption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: AppColors.primary,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final userProfile = ref.watch(userProfileProvider);
    
    return Drawer(
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
          // Header with app name only
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
            ),
            child: Center(
              child: Text(
                'ONLY FOCUS',
                style: const TextStyle(
                  fontFamily: 'Times New Roman',
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 24,
                ),
              ),
            ),
          ),
          
          // User info
          userProfile.when(
            data: (profile) {
              if (profile == null) return const SizedBox();
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary,
                  backgroundImage: profile.photoUrl != null && profile.photoUrl!.isNotEmpty
                      ? FileImage(File(profile.photoUrl!))
                      : null,
                  child: profile.photoUrl == null || profile.photoUrl!.isEmpty
                      ? Text(
                          profile.displayName.isNotEmpty
                              ? profile.displayName[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(color: Colors.white),
                        )
                      : null,
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
          
          // Focus Timer
          ListTile(
            leading: const Icon(Icons.timer),
            title: const Text('Focus Timer'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/focus');
            },
          ),
          
          // Bookmarks
          ListTile(
            leading: const Icon(Icons.bookmark_outline),
            title: const Text('Bookmarks'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/bookmarks');
            },
          ),
          
          // Collections
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('Collections'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/collections');
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
          
          // Quiz History
          ListTile(
            leading: const Icon(Icons.quiz),
            title: const Text('Quiz History'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/quiz-history');
            },
          ),
          
          // Theme Selection
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
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              _showThemeDialog(context, ref, themeMode);
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
                children: [
                  const Text('A distraction-free reading app for tech news, science, and research papers.'),
                ],
              );
            },
          ),
          
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
          
          const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
