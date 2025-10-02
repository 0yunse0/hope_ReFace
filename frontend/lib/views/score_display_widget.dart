import 'package:flutter/material.dart';
import 'dart:async';
import '../models/expression_type.dart';
import '../utils/constants.dart';

class ScoreDisplayWidget extends StatefulWidget {
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
  State<ScoreDisplayWidget> createState() => _ScoreDisplayWidgetState();
}

class _ScoreDisplayWidgetState extends State<ScoreDisplayWidget>
    with SingleTickerProviderStateMixin {
  late double _animatedValue;

  @override
  void initState() {
    super.initState();
    _animatedValue = widget.score.clamp(0.0, 1.0);
  }

  @override
  void didUpdateWidget(covariant ScoreDisplayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.score.clamp(0.0, 1.0);
    if ((next - _animatedValue).abs() > 0.001) {
      // 부드럽게 보간
      _animateTo(next);
    }
  }

  void _animateTo(double target) {
    // 200ms 동안 easeOutCubic 으로 보간
    final Duration d = const Duration(milliseconds: 200);
    final double start = _animatedValue;
    final int ticks = 12; // 약 60fps 기준 200ms ~= 12프레임
    int i = 0;
    Timer.periodic(d ~/ ticks, (t) {
      i++;
      final double tNorm = (i / ticks).clamp(0.0, 1.0);
      final double eased = Curves.easeOutCubic.transform(tNorm);
      setState(() {
        _animatedValue = start + (target - start) * eased;
      });
      if (tNorm >= 1.0) t.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final double value = _animatedValue.clamp(0.0, 1.0);
    final percentage = (value * 100).round();
    final color = _getScoreColor(value);
    final message = _getScoreMessage(value, widget.expressionType);

    return Column(
      children: [
        Text('진척도', style: TextStyle(fontSize: 13)),
        SizedBox(height: 5),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 90,
              height: 90,
              child: CircularProgressIndicator(
                value: value,
                strokeWidth: 8,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            Text('$percentage%', style: TextStyle(fontSize: 20, color: color)),
          ],
        ),
        SizedBox(height: 5),
        Text(message, style: TextStyle(fontSize: 15, color: color)),
      ],
    );
  }

  Color _getScoreColor(double score) {
    if (score >= AppConstants.highScoreThreshold) return AppColors.success;
    if (score >= AppConstants.mediumScoreThreshold) return AppColors.accent;
    return AppColors.error;
  }

  // ## 수정: 피드백 메시지를 점수대별로 세분화 ##
  String _getScoreMessage(double score, ExpressionType type) {
    final level = (score >= AppConstants.highScoreThreshold)
        ? 'high'
        : (score >= AppConstants.mediumScoreThreshold)
        ? 'medium'
        : 'low';

    switch (type) {
      case ExpressionType.smile:
        if (level == 'high') return '완벽한 미소예요! 😁';
        if (level == 'medium') return '좋아요! 조금 더 활짝! 😊';
        return '입꼬리를 올려보세요! 😐';
      case ExpressionType.sad:
        if (level == 'high') return '슬픔이 잘 표현됐어요 😢';
        if (level == 'medium') return '좋아요! 감정을 더 실어봐요';
        return '입꼬리를 더 내려보세요';
      case ExpressionType.angry:
        if (level == 'high') return '분노가 느껴져요! 😠';
        if (level == 'medium') return '좋아요! 눈썹에 힘을! 😡';
        return '미간을 찌푸려보세요';
      case ExpressionType.neutral:
        if (level == 'high') return '완벽한 무표정입니다 👍';
        if (level == 'medium') return '좋아요! 조금만 더 유지!';
        return '표정 변화 없이 유지하세요';
    }
  }
}
