import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_text_styles.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'ui/auth/login_screen.dart';
import 'ui/auth/signup_screen.dart';
import 'ui/home/home_screen.dart';
import 'ui/discover/discover_screen.dart';
import 'ui/reader/reader_screen.dart';
import 'ui/bookmarks/bookmarks_screen.dart';
import 'ui/focus/focus_screen.dart';
import 'ui/profile/profile_screen.dart';
import 'ui/splash/splash_screen.dart';
import 'ui/onboarding/category_preference_screen.dart';
import 'ui/notes/notes_screen.dart';

class OnlyFocusApp extends ConsumerWidget {
  const OnlyFocusApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final themeMode = ref.watch(themeModeProvider);
    
    return MaterialApp(
      title: 'Only Focus',
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      themeMode: themeMode,
      home: authState.when(
        data: (user) {
          if (user == null) return const LoginScreen();
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SplashScreen();
              }
              
              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const HomeScreen();
              }
              
              final data = snapshot.data!.data() as Map<String, dynamic>?;
              final hasCompletedOnboarding = data?['hasCompletedOnboarding'] ?? false;
              return hasCompletedOnboarding ? const HomeScreen() : const CategoryPreferenceScreen();
            },
          );
        },
        loading: () => const SplashScreen(),
        error: (_, __) => const LoginScreen(),
      ),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/home': (context) => const HomeScreen(),
        '/discover': (context) => const DiscoverScreen(),
        '/bookmarks': (context) => const BookmarksScreen(),
        '/focus': (context) => const FocusScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/category-preference': (context) => const CategoryPreferenceScreen(),
        '/notes': (context) => const NotesScreen(),
      },
    );
  }
  
  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surfaceLight,
        error: AppColors.warning,
      ),
      scaffoldBackgroundColor: AppColors.backgroundLight,
      textTheme: TextTheme(
        displayLarge: AppTextStyles.uiH1.copyWith(color: AppColors.textPrimary),
        displayMedium: AppTextStyles.uiH2.copyWith(color: AppColors.textPrimary),
        displaySmall: AppTextStyles.uiH3.copyWith(color: AppColors.textPrimary),
        bodyLarge: AppTextStyles.uiBody.copyWith(color: AppColors.textPrimary),
        bodyMedium: AppTextStyles.uiBody.copyWith(color: AppColors.textSecondary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.backgroundLight,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: AppTextStyles.uiH3.copyWith(color: AppColors.textPrimary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceLight,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: AppTextStyles.uiCaption,
        unselectedLabelStyle: AppTextStyles.uiCaption,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          textStyle: AppTextStyles.uiButton,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
  
  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surfaceDark,
        error: AppColors.warning,
      ),
      scaffoldBackgroundColor: AppColors.backgroundDark,
      textTheme: TextTheme(
        displayLarge: AppTextStyles.uiH1.copyWith(color: Colors.white),
        displayMedium: AppTextStyles.uiH2.copyWith(color: Colors.white),
        displaySmall: AppTextStyles.uiH3.copyWith(color: Colors.white),
        bodyLarge: AppTextStyles.uiBody.copyWith(color: Colors.white),
        bodyMedium: AppTextStyles.uiBody.copyWith(color: Colors.white70),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surfaceDark,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: AppTextStyles.uiH3.copyWith(color: Colors.white),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.white60,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: AppTextStyles.uiCaption,
        unselectedLabelStyle: AppTextStyles.uiCaption,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          textStyle: AppTextStyles.uiButton,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceDark,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
    );
  }
}
