import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../data/models/article.dart';

class ArticleCard extends StatelessWidget {
  final Article article;
  final VoidCallback onTap;
  
  const ArticleCard({
    super.key,
    required this.article,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Article image if available
            if (article.imageUrl != null && article.imageUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.network(
                  article.imageUrl!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const SizedBox(),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 180,
                      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                ),
              ),
            
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // Source badge and content type
              Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getContentTypeColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        article.sourceName,
                        style: AppTextStyles.uiCaption.copyWith(
                          color: _getContentTypeColor(),
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.textSecondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _getContentTypeLabel(),
                      style: AppTextStyles.uiCaption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Reading time
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.access_time, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        '${article.estimatedReadingMinutes} min',
                        style: AppTextStyles.uiCaption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Title
              Text(
                article.title,
                style: AppTextStyles.uiH3.copyWith(
                  height: 1.3,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              
              // Summary if available
              if (article.summary != null && article.summary!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  article.summary!,
                  style: AppTextStyles.uiBody.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              
              const SizedBox(height: 12),
              
              // Bottom row - category and bookmark
              Row(
                children: [
                  Icon(
                    _getCategoryIcon(),
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      article.category,
                      style: AppTextStyles.uiCaption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (article.isBookmarked)
                    const Icon(
                      Icons.bookmark,
                      size: 20,
                      color: AppColors.primary,
                    ),
                ],
              ),
            ],
          ),
        ),
          ],
        ),
      ),
    );
  }
  
  Color _getContentTypeColor() {
    switch (article.contentType) {
      case 'research_paper':
        return AppColors.accent;
      case 'science':
        return AppColors.primary;
      case 'world':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }
  
  String _getContentTypeLabel() {
    switch (article.contentType) {
      case 'research_paper':
        return 'Research';
      case 'science':
        return 'Science';
      case 'world':
        return 'World';
      default:
        return 'Tech';
    }
  }
  
  IconData _getCategoryIcon() {
    switch (article.category.toLowerCase()) {
      case 'technology':
      case 'computer science':
        return Icons.computer;
      case 'science':
      case 'physics':
      case 'biology':
        return Icons.science;
      case 'mathematics':
        return Icons.calculate;
      case 'astronomy':
        return Icons.star;
      default:
        return Icons.article;
    }
  }
}
