import 'package:flutter/material.dart';
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
    if (!isTraining) return const SizedBox.shrink();
    if (!isFaceDetected) return const Text('얼굴이 감지되지 않았습니다.');

    return Text(
      _getFeedbackMessage(score, expressionType),
      style: TextStyle(color: _getFeedbackColor(score)),
    );
  }

  Color _getFeedbackColor(double score) {
    if (score >= AppConstants.highScoreThreshold) return AppColors.success;
    if (score >= AppConstants.mediumScoreThreshold) return AppColors.accent;
    return AppColors.error;
  }

  // ## 수정: 피드백 메시지를 점수대별로 세분화 ##
  String _getFeedbackMessage(double score, ExpressionType type) {
    final level = (score >= AppConstants.highScoreThreshold)
        ? 'high'
        : (score >= AppConstants.mediumScoreThreshold)
        ? 'medium'
        : 'low';

    switch (type) {
      case ExpressionType.smile:
        if (level == 'high') return '최고예요! 지금 표정을 기억하세요.';
        if (level == 'medium') return '거의 다 왔어요! 입꼬리를 살짝만 더!';
        return '더 활짝 웃어보세요!';
      case ExpressionType.sad:
        if (level == 'high') return '감정 전달이 잘 되고 있어요.';
        if (level == 'medium') return '눈썹을 조금 더 내려볼까요?';
        return '조금 더 슬픈 표정을 지어보세요.';
      case ExpressionType.angry:
        if (level == 'high') return '카리스마 넘치는 표정이에요!';
        if (level == 'medium') return '좋아요! 눈에 더 힘을 주세요.';
        return '눈썹을 모으고 입을 굳게 다물어보세요.';
      case ExpressionType.neutral:
        if (level == 'high') return '아주 평온한 상태입니다.';
        if (level == 'medium') return '잘하고 있어요, 조금만 더!';
        return '표정의 모든 근육을 이완시켜 보세요.';
    }
  }
}