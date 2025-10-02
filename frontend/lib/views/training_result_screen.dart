// ## 파일: lib/views/training_result_screen.dart ##

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/expression_type.dart';
import '../models/training_record.dart';
import '../services/training_record_service.dart';
import '../utils/constants.dart';
import 'training_log_screen.dart';
import '../controllers/progress_controller.dart';

class TrainingResultScreen extends StatefulWidget {
  final ExpressionType expressionType;
  final double finalScore;

  const TrainingResultScreen({
    super.key,
    required this.expressionType,
    required this.finalScore,
  });

  @override
  State<TrainingResultScreen> createState() => _TrainingResultScreenState();
}

class _TrainingResultScreenState extends State<TrainingResultScreen> {
  final TrainingRecordService _recordService = TrainingRecordService();
  final ProgressController _progressController = Get.find(); // ✅ 컨트롤러 인스턴스 찾기

  @override
  void initState() {
    super.initState();
    _updateAndSaveRecord();
  }

  Future<void> _updateAndSaveRecord() async {
    final newRecord = TrainingRecord(
      timestamp: DateTime.now(),
      expressionType: widget.expressionType,
      score: widget.finalScore,
    );
    await _recordService.updateScoreAndAddRecord(newRecord);

    // 전역 ProgressController에게 데이터 새로고침 요청
    await _progressController.fetchAndUpdateProgress();
  }

  String _getTitle() {
    switch (widget.expressionType) {
      case ExpressionType.smile: return '웃는 표정 결과';
      case ExpressionType.sad: return '슬픈 표정 결과';
      case ExpressionType.angry: return '화난 표정 결과';
      case ExpressionType.neutral: return '무표정 결과';
    }
  }

  @override
  Widget build(BuildContext context) {
    final percentage = (widget.finalScore * 100).round();
    final color = widget.finalScore >= 0.8 ? AppColors.success : (widget.finalScore >= 0.6 ? AppColors.accent : AppColors.error);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_getTitle(), style: const TextStyle(color: AppColors.textPrimary)),
        backgroundColor: AppColors.surface,
        centerTitle: true,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            const Text('오늘의 훈련 결과', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSizes.lg),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: CircularProgressIndicator(
                    value: widget.finalScore,
                    strokeWidth: 10,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                Text('$percentage%', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
              ],
            ),
            const SizedBox(height: AppSizes.xl),
            const Text(
              '수고하셨습니다!\n결과가 기록에 저장되었어요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                Get.to(() => TrainingLogScreen(expressionType: widget.expressionType));
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppSizes.lg),
              ),
              child: const Text('기록 페이지로 이동', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: AppSizes.sm),
            TextButton(
              onPressed: () {
                Get.offAllNamed('/home');
              },
              child: const Text('홈으로 돌아가기'),
            ),
            const SizedBox(height: AppSizes.lg),
          ],
        ),
      ),
    );
  }
}