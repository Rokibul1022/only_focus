import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/services/focus_service.dart';
import '../../providers/focus_provider.dart';
import 'dart:math' as math;

class FocusScreen extends ConsumerWidget {
  const FocusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focusState = ref.watch(focusStateProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Focus'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Timer display
            _buildTimerDisplay(context, ref, focusState),
            
            const SizedBox(height: 48),
            
            // Control buttons
            _buildControlButtons(context, ref, focusState),
            
            const SizedBox(height: 48),
            
            // Session stats
            if (focusState.sessionState != SessionState.idle)
              _buildSessionStats(context, focusState),
            
            const SizedBox(height: 32),
            
            // Quick start buttons
            if (focusState.sessionState == SessionState.idle)
              _buildQuickStartButtons(ref),
            
            // Session complete card
            if (focusState.sessionState == SessionState.completed)
              _buildCompletionCard(focusState),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTimerDisplay(BuildContext context, WidgetRef ref, FocusState state) {
    final progress = state.sessionState == SessionState.running || 
                     state.sessionState == SessionState.paused
        ? 1.0 - (state.remainingSeconds / _getSessionDuration(state.sessionType))
        : 0.0;
    
    return SizedBox(
      width: 280,
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Progress ring
          CustomPaint(
            size: const Size(280, 280),
            painter: _TimerPainter(
              progress: progress,
              color: _getSessionColor(state.sessionType),
            ),
          ),
          
          // Time text
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                ref.read(focusStateProvider.notifier).formatTime(),
                style: AppTextStyles.uiH1.copyWith(
                  fontSize: 48,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _getSessionLabel(state.sessionType, state.sessionState),
                style: AppTextStyles.uiBody.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildControlButtons(BuildContext context, WidgetRef ref, FocusState state) {
    if (state.sessionState == SessionState.idle) {
      return const SizedBox.shrink();
    }
    
    if (state.sessionState == SessionState.completed) {
      return ElevatedButton(
        onPressed: () => ref.read(focusStateProvider.notifier).stop(),
        child: const Text('Start New Session'),
      );
    }
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Pause/Resume button
        ElevatedButton.icon(
          onPressed: () {
            if (state.sessionState == SessionState.running) {
              ref.read(focusStateProvider.notifier).pause();
            } else if (state.sessionState == SessionState.paused) {
              ref.read(focusStateProvider.notifier).resume();
            }
          },
          icon: Icon(
            state.sessionState == SessionState.running 
                ? Icons.pause 
                : Icons.play_arrow,
          ),
          label: Text(
            state.sessionState == SessionState.running ? 'Pause' : 'Resume',
          ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
        ),
        
        const SizedBox(width: 16),
        
        // Stop button
        OutlinedButton.icon(
          onPressed: () => ref.read(focusStateProvider.notifier).stop(),
          icon: const Icon(Icons.stop),
          label: const Text('Stop'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
        ),
      ],
    );
  }
  
  Widget _buildSessionStats(BuildContext context, FocusState state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            icon: Icons.article,
            value: '${state.articlesReadInSession}',
            label: 'Articles',
          ),
          _StatItem(
            icon: Icons.timer,
            value: _formatDuration(state.remainingSeconds),
            label: 'Remaining',
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuickStartButtons(WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Quick Start',
          style: AppTextStyles.uiH3,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        
        // Pomodoro button
        _SessionButton(
          title: 'Pomodoro',
          subtitle: '25 minutes focus',
          icon: Icons.timer,
          color: AppColors.primary,
          onTap: () => ref.read(focusStateProvider.notifier).startPomodoro(),
        ),
        
        const SizedBox(height: 12),
        
        // Deep Work button
        _SessionButton(
          title: 'Deep Work',
          subtitle: '90 minutes uninterrupted',
          icon: Icons.psychology,
          color: AppColors.accent,
          onTap: () => ref.read(focusStateProvider.notifier).startDeepWork(),
        ),
        
        const SizedBox(height: 12),
        
        // Custom button
        Builder(
          builder: (context) => _SessionButton(
            title: 'Custom',
            subtitle: 'Set your own duration',
            icon: Icons.tune,
            color: AppColors.textSecondary,
            onTap: () => _showCustomDurationDialog(context, ref),
          ),
        ),
      ],
    );
  }
  
  Widget _buildCompletionCard(FocusState state) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: Column(
        children: [
          const Icon(Icons.celebration, size: 48, color: AppColors.primary),
          const SizedBox(height: 16),
          Text(
            'Session Complete!',
            style: AppTextStyles.uiH2.copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: 8),
          if (state.starsEarned != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star, color: AppColors.reward, size: 24),
                const SizedBox(width: 8),
                Text(
                  '+${state.starsEarned} stars earned',
                  style: AppTextStyles.uiH3.copyWith(color: AppColors.reward),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Text(
            'Articles read: ${state.articlesReadInSession}',
            style: AppTextStyles.uiBody.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
  
  void _showCustomDurationDialog(BuildContext context, WidgetRef ref) {
    final TextEditingController controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Custom Duration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter duration in minutes',
              style: AppTextStyles.uiBody.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'e.g., 45',
                suffixText: 'minutes',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).cardColor,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final minutes = int.tryParse(controller.text);
              if (minutes != null && minutes > 0 && minutes <= 180) {
                Navigator.pop(context);
                ref.read(focusStateProvider.notifier).startCustom(minutes);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid duration (1-180 minutes)'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }
  
  int _getSessionDuration(SessionType type) {
    return type == SessionType.deepWork ? 90 * 60 : 25 * 60;
  }
  
  Color _getSessionColor(SessionType type) {
    return type == SessionType.deepWork ? AppColors.accent : AppColors.primary;
  }
  
  String _getSessionLabel(SessionType type, SessionState state) {
    if (state == SessionState.breakTime) return 'Break Time';
    if (state == SessionState.completed) return 'Completed';
    return type == SessionType.deepWork ? 'Deep Work' : 'Pomodoro';
  }
  
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    return '${minutes}m';
  }
}

class _TimerPainter extends CustomPainter {
  final double progress;
  final Color color;
  
  _TimerPainter({required this.progress, required this.color});
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    
    // Background circle
    final bgPaint = Paint()
      ..color = Colors.grey[300]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;
    
    canvas.drawCircle(center, radius, bgPaint);
    
    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }
  
  @override
  bool shouldRepaint(_TimerPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _SessionButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  
  const _SessionButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.uiH3),
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
            Icon(Icons.arrow_forward_ios, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  
  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary, size: 32),
        const SizedBox(height: 8),
        Text(value, style: AppTextStyles.uiH2),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.uiCaption.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
