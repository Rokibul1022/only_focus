import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../providers/auth_provider.dart';

class CategoryPreferenceScreen extends ConsumerStatefulWidget {
  const CategoryPreferenceScreen({super.key});

  @override
  ConsumerState<CategoryPreferenceScreen> createState() => _CategoryPreferenceScreenState();
}

class _CategoryPreferenceScreenState extends ConsumerState<CategoryPreferenceScreen> {
  final Set<String> _selectedCategories = {};
  bool _isSaving = false;
  
  final List<Map<String, dynamic>> _categories = [
    {'name': 'Technology', 'icon': Icons.computer, 'color': AppColors.primary},
    {'name': 'Science', 'icon': Icons.science, 'color': AppColors.accent},
    {'name': 'Research Papers', 'icon': Icons.article, 'color': AppColors.secondary},
    {'name': 'Space', 'icon': Icons.rocket_launch, 'color': AppColors.reward},
    {'name': 'Medicine', 'icon': Icons.medical_services, 'color': Colors.red},
    {'name': 'World', 'icon': Icons.public, 'color': Colors.blue},
    {'name': 'Economics', 'icon': Icons.trending_up, 'color': Colors.green},
    {'name': 'Philosophy', 'icon': Icons.psychology, 'color': Colors.purple},
    {'name': 'Business', 'icon': Icons.business, 'color': Colors.orange},
    {'name': 'Environment', 'icon': Icons.eco, 'color': Colors.lightGreen},
    {'name': 'AI & Machine Learning', 'icon': Icons.smart_toy, 'color': Colors.deepPurple},
    {'name': 'Cybersecurity', 'icon': Icons.security, 'color': Colors.indigo},
    {'name': 'Energy', 'icon': Icons.bolt, 'color': Colors.amber},
    {'name': 'Psychology', 'icon': Icons.psychology_alt, 'color': Colors.pink},
    {'name': 'History', 'icon': Icons.history_edu, 'color': Colors.brown},
    {'name': 'Education', 'icon': Icons.school, 'color': Colors.cyan},
  ];
  
  Future<void> _savePreferences() async {
    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one category'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    
    setState(() => _isSaving = true);
    
    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) return;
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'preferredCategories': _selectedCategories.toList(),
        'hasCompletedOnboarding': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving preferences: $e'),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Image.asset(
                    'assets/images/Sleek eye logo for Only Focus app.png',
                    height: 80,
                    width: 80,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Choose Your Interests',
                    style: AppTextStyles.uiH1,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select categories you want to focus on.\nWe\'ll prioritize content based on your preferences.',
                    style: AppTextStyles.uiBody.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.2,
                ),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = _selectedCategories.contains(category['name']);
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedCategories.remove(category['name']);
                        } else {
                          _selectedCategories.add(category['name']);
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? category['color'].withOpacity(0.1)
                            : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected 
                              ? category['color']
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            category['icon'],
                            size: 48,
                            color: isSelected 
                                ? category['color']
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            category['name'],
                            style: AppTextStyles.uiBody.copyWith(
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: isSelected 
                                  ? category['color']
                                  : AppColors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (isSelected)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Icon(
                                Icons.check_circle,
                                color: category['color'],
                                size: 20,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    '${_selectedCategories.length} ${_selectedCategories.length == 1 ? 'category' : 'categories'} selected',
                    style: AppTextStyles.uiCaption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _savePreferences,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              'Continue',
                              style: AppTextStyles.uiH3.copyWith(color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
