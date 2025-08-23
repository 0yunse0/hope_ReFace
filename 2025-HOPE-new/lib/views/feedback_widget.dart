import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../utils/constants.dart';

class FeedbackWidget extends StatelessWidget {
  final bool isFaceDetected;
  final double smileScore;
  final bool isTraining;

  const FeedbackWidget({
    super.key,
    required this.isFaceDetected,
    required this.smileScore,
    required this.isTraining,
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
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ).animate().shake(duration: AppAnimations.normal, hz: 4);
    }

    return Container(
          padding: const EdgeInsets.all(AppSizes.md),
          decoration: BoxDecoration(
            color: _getFeedbackColor(smileScore).withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: _getFeedbackColor(smileScore).withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _getFeedbackIcon(smileScore),
                color: _getFeedbackColor(smileScore),
                size: 20,
              ),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: Text(
                  _getFeedbackMessage(smileScore),
                  style: TextStyle(
                    color: _getFeedbackColor(smileScore),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
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
    if (score >= 0.9) {
      return AppColors.success;
    } else if (score >= 0.8) {
      return Color(0xFF22C55E); // 밝은 초록
    } else if (score >= 0.7) {
      return AppColors.success;
    } else if (score >= 0.6) {
      return AppColors.accent;
    } else if (score >= 0.5) {
      return Color(0xFFF97316); // 주황
    } else if (score >= 0.4) {
      return AppColors.warning;
    } else if (score >= 0.2) {
      return Color(0xFFDC2626); // 빨강
    } else {
      return AppColors.error;
    }
  }

  IconData _getFeedbackIcon(double score) {
    if (score >= 0.9) {
      return Icons.celebration;
    } else if (score >= 0.8) {
      return Icons.star;
    } else if (score >= 0.7) {
      return Icons.thumb_up;
    } else if (score >= 0.6) {
      return Icons.favorite;
    } else if (score >= 0.5) {
      return Icons.emoji_emotions;
    } else if (score >= 0.4) {
      return Icons.sentiment_satisfied;
    } else if (score >= 0.2) {
      return Icons.sentiment_neutral;
    } else {
      return Icons.sentiment_dissatisfied;
    }
  }

  String _getFeedbackMessage(double score) {
    if (score >= 0.9) {
      return '완벽한 미소! 최고예요! 🎉';
    } else if (score >= 0.8) {
      return '거의 완벽해요! 조금만 더! 🌟';
    } else if (score >= 0.7) {
      return '훌륭한 미소! 계속 유지하세요! ✨';
    } else if (score >= 0.6) {
      return '좋은 미소입니다! 더 밝게! 😊';
    } else if (score >= 0.5) {
      return '괜찮아요! 조금 더 웃어보세요! 🙂';
    } else if (score >= 0.4) {
      return '조금 더 밝은 표정을 지어보세요! 😄';
    } else if (score >= 0.2) {
      return '입꼬리를 올려서 웃어보세요! 😃';
    } else {
      return '미소 연습을 시작해보세요! 😌';
    }
  }
}
