import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import '../reader/reader_screen.dart';
import '../../data/models/article.dart';

class QuizHistoryScreen extends ConsumerWidget {
  const QuizHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quiz History')),
        body: const Center(child: Text('Please log in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz History'),
        backgroundColor: AppColors.background,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('quiz_results')
            .where('userId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.quiz_outlined, size: 64, color: AppColors.textSecondary),
                  const SizedBox(height: 16),
                  Text('No quiz history yet', style: AppTextStyles.uiH3),
                  const SizedBox(height: 8),
                  Text(
                    'Complete quizzes to track your progress',
                    style: AppTextStyles.uiBody.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }

          final results = snapshot.data!.docs;
          results.sort((a, b) {
            final aTime = (a.data() as Map<String, dynamic>)['completedAt'] as Timestamp?;
            final bTime = (b.data() as Map<String, dynamic>)['completedAt'] as Timestamp?;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatCard(
                          'Total Quizzes',
                          results.length.toString(),
                          Icons.quiz,
                          Colors.blue,
                        ),
                        _buildStatCard(
                          'Avg Score',
                          '${_calculateAverageScore(results).toStringAsFixed(0)}%',
                          Icons.trending_up,
                          Colors.green,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Quiz History', style: AppTextStyles.uiH2),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(
                      AppColors.primary.withOpacity(0.1),
                    ),
                    columns: const [
                      DataColumn(label: Text('Article', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Score', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('Percentage', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: results.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final articleTitle = data['articleTitle'] ?? 'Unknown';
                      final articleId = data['articleId'] ?? '';
                      final articleUrl = data['articleUrl'] ?? '';
                      final completedAt = data['completedAt'] as Timestamp?;
                      final totalQuestions = data['totalQuestions'] ?? 0;
                      final correctAnswers = data['correctAnswers'] ?? 0;
                      final percentage = totalQuestions > 0
                          ? ((correctAnswers / totalQuestions) * 100).toInt()
                          : 0;

                      String dateStr = 'N/A';
                      if (completedAt != null) {
                        final date = completedAt.toDate();
                        dateStr = '${date.day}/${date.month}/${date.year}';
                      }

                      return DataRow(
                        cells: [
                          DataCell(
                            InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ReaderScreen(
                                      article: Article()
                                        ..id = articleId
                                        ..title = articleTitle
                                        ..sourceUrl = articleUrl
                                        ..sourceName = ''
                                        ..imageUrl = ''
                                        ..contentType = 'tech_news'
                                        ..category = 'Technology'
                                        ..publishedAt = DateTime.now()
                                        ..fetchedAt = DateTime.now()
                                        ..estimatedReadingMinutes = 5,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                constraints: const BoxConstraints(maxWidth: 200),
                                child: Text(
                                  articleTitle,
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    decoration: TextDecoration.underline,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                          DataCell(Text(dateStr)),
                          DataCell(Text('$correctAnswers/$totalQuestions')),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getScoreColor(percentage).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$percentage%',
                                style: TextStyle(
                                  color: _getScoreColor(percentage),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(value, style: AppTextStyles.uiH2.copyWith(color: color)),
        Text(label, style: AppTextStyles.uiCaption),
      ],
    );
  }

  double _calculateAverageScore(List<QueryDocumentSnapshot> results) {
    if (results.isEmpty) return 0;
    
    int totalScore = 0;
    int totalQuestions = 0;
    
    for (var doc in results) {
      final data = doc.data() as Map<String, dynamic>;
      totalScore += (data['correctAnswers'] ?? 0) as int;
      totalQuestions += (data['totalQuestions'] ?? 0) as int;
    }
    
    return totalQuestions > 0 ? (totalScore / totalQuestions) * 100 : 0;
  }

  Color _getScoreColor(int percentage) {
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.orange;
    return Colors.red;
  }
}
