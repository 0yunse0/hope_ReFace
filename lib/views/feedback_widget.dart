// feedback_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/expression_type.dart';
import '../utils/constants.dart';

class FeedbackWidget extends StatelessWidget {
  final bool isFaceDetected;
  final double score;
  final bool isTraining;
  final ExpressionType expressionType;

  const FeedbackWidget({
    super.key,
    required this.isFaceDetected,
    required this.score,
    required this.isTraining,
    required this.expressionType,
  });

  @override
  Widget build(BuildContext context) {
    if (!isTraining) {
      return Container(
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.textTertiary.withOpacity(0.2)),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.textSecondary, size: 20),
            SizedBox(width: AppSizes.sm),
            Expanded(
              child: Text(
                '훈련을 시작하면 실시간 피드백을 받을 수 있습니다',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }

    if (!isFaceDetected) {
      return Container(
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.error.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.face_retouching_off, color: AppColors.error, size: 20),
            const SizedBox(width: AppSizes.sm),
            const Expanded(
              child: Text(
                '카메라 앞으로 이동해주세요',
                style: TextStyle(color: AppColors.error, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ).animate().shake(duration: AppAnimations.normal, hz: 4);
    }

    final color = _getFeedbackColor(score);
    final icon = _getFeedbackIcon(score, expressionType);
    final message = _getFeedbackMessage(score, expressionType);

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    )
        .animate(target: isTraining ? 1 : 0)
        .fadeIn(duration: AppAnimations.normal)
        .slideX(begin: 0.3, duration: AppAnimations.normal);
  }

  Color _getFeedbackColor(double score) {
    if (score >= 0.8) return AppColors.success;
    if (score >= 0.6) return AppColors.accent;
    if (score >= 0.4) return AppColors.warning;
    return AppColors.error;
  }

  IconData _getFeedbackIcon(double score, ExpressionType type) {
    if (score < 0.4) return Icons.sentiment_dissatisfied;
    if (score < 0.6) return Icons.sentiment_neutral;
    if (score < 0.8) return Icons.sentiment_satisfied;

    switch (type) {
      case ExpressionType.smile:
        return Icons.celebration;
      case ExpressionType.sad:
        return Icons.mood_bad;
      case ExpressionType.angry:
        return Icons.whatshot;
    }
  }

  String _getFeedbackMessage(double score, ExpressionType type) {
    if (type == ExpressionType.smile) {
      if (score >= 0.8) return '완벽한 미소! 최고예요! 🎉';
      if (score >= 0.6) return '좋은 미소입니다! 더 밝게! 😊';
      if (score >= 0.4) return '괜찮아요! 조금 더 웃어보세요! 🙂';
      return '입꼬리를 올려서 웃어보세요! 😃';
    } else if (type == ExpressionType.sad) {
      if (score >= 0.8) return '감정 표현이 아주 좋아요.';
      if (score >= 0.6) return '슬픔이 잘 전달되고 있어요.';
      if (score >= 0.4) return '좋아요, 입꼬리를 조금 더 내려보세요.';
      return '눈썹과 입에 슬픈 감정을 담아보세요.';
    } else { // angry
      if (score >= 0.8) return '분노 표현이 완벽해요! 😠';
      if (score >= 0.6) return '눈썹에 힘을 더 주세요!';
      if (score >= 0.4) return '미간을 좀 더 찌푸려보세요.';
      return '눈썹을 내리고 미간을 찌푸려보세요.';
    }
  }
}