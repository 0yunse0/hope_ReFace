// score_display_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/expression_type.dart';
import '../utils/constants.dart';

class ScoreDisplayWidget extends StatelessWidget {
  final double score;
  final bool isTraining;
  final ExpressionType expressionType;

  const ScoreDisplayWidget({
    super.key,
    required this.score,
    required this.isTraining,
    required this.expressionType,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (score * 100).round();
    final color = _getScoreColor(score);
    final message = _getScoreMessage(score, expressionType);

    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: AppColors.textTertiary.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            '진척도',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSizes.md),
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 8,
                    backgroundColor: AppColors.textTertiary.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                SizedBox(
                  width: 120,
                  height: 120,
                  child: CircularProgressIndicator(
                    value: score,
                    strokeWidth: 8,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
                    .animate(target: isTraining ? 1 : 0)
                    .scale(duration: AppAnimations.normal, curve: Curves.easeInOut),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$percentage%',
                      style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      score.toStringAsFixed(2),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.md),
          Text(
            message,
            style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          )
              .animate(target: isTraining ? 1 : 0)
              .fadeIn(duration: AppAnimations.normal)
              .slideY(begin: 0.3, duration: AppAnimations.normal),
        ],
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 0.8) return AppColors.success;
    if (score >= 0.6) return AppColors.accent;
    if (score >= 0.4) return AppColors.warning;
    return AppColors.error;
  }

  String _getScoreMessage(double score, ExpressionType type) {
    if (type == ExpressionType.smile) {
      if (score >= 0.8) return '완벽한 미소! 🎉';
      if (score >= 0.6) return '좋은 미소예요! 😊';
      if (score >= 0.4) return '조금 더 웃어보세요! 😄';
      return '미소를 연습해보세요! 😌';
    } else if (type == ExpressionType.sad) {
      if (score >= 0.8) return '슬픔이 느껴져요 😢';
      if (score >= 0.6) return '감정이 전달돼요';
      if (score >= 0.4) return '입꼬리를 더 내려보세요';
      return '슬픈 표정을 지어보세요';
    } else { // angry
      if (score >= 0.8) return '분노가 느껴집니다! 😠';
      if (score >= 0.6) return '카리스마 있어요! 😡';
      if (score >= 0.4) return '미간을 더 찌푸려보세요';
      return '화난 표정을 지어보세요';
    }
  }
}