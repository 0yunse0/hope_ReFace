import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../models/expression_type.dart';
import '../utils/constants.dart';
import 'training_screen.dart';
import '../services/training_api_service.dart';

class ExpressionSelectScreen extends StatefulWidget {
  final CameraDescription camera;

  const ExpressionSelectScreen({super.key, required this.camera});

  @override
  State<ExpressionSelectScreen> createState() => _ExpressionSelectScreenState();
}

class _ExpressionSelectScreenState extends State<ExpressionSelectScreen> {
  final _api = TrainingApiService();
  bool _loadingRecs = false;
  List<Map<String, dynamic>> _recommendations = const [];

  void _navigate(BuildContext context, ExpressionType type) {
    Get.to(() => TrainingScreen(camera: widget.camera, expressionType: type));
  }

  @override
  void initState() {
    super.initState();
    _loadRecommendations();
  }

  Future<void> _loadRecommendations() async {
    setState(() => _loadingRecs = true);
    try {
      final recs = await _api.fetchTrainingRecommendations(limit: 3);
      setState(() {
        _recommendations = recs;
        _loadingRecs = false;
      });
    } catch (_) {
      setState(() => _loadingRecs = false);
    }
  }

  String _exprLabel(String? expr) {
    if (expr == null) return '해당 표정';
    final e = expr.toLowerCase();
    switch (e) {
      case 'smile':
      case 'happy':
        return '웃는 표정';
      case 'angry':
        return '화난 표정';
      case 'sad':
        return '슬픈 표정';
      case 'neutral':
      case 'none':
        return '무표정';
      default:
        return expr;
    }
  }

  // 퍼센트 포맷팅은 현재 문구에 사용하지 않음 (단순화)

  String _formatRecommendation(Map<String, dynamic> m) {
    final expr = (m['expr'] ?? m['expression'] ?? m['type'])?.toString();
    // 과거 퍼센트 사용 로직은 제거 (요청 문구대로 고정 표현)
    if (expr != null) {
      final label = _exprLabel(expr);
      // 요청된 문구 포맷으로 표시 (퍼센트 여부와 무관하게)
      return '최근 $label의 훈련 진척도가 낮습니다. \n 오늘 $label 연습은 어떤가요? 🤗';
    }
    // 폴백: 기존 텍스트 키 사용
    final primary =
        m['title'] ??
        m['message'] ??
        m['tip'] ??
        m['text'] ??
        m['content'] ??
        expr ??
        '표정 훈련을 제안합니다';
    return primary.toString();
  }

  @override
  Widget build(BuildContext context) {
    final String todayLabel = DateFormat(
      'y년 M월 d일 (EEE)',
      'ko',
    ).format(DateTime.now());
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          '훈련모드',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: AppColors.surface,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    todayLabel,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: 0.55, // 화면 너비의 18% 길이
                child: Container(height: 3, color: AppColors.textPrimary),
              ),
            ),
            const SizedBox(height: AppSizes.md),
            Container(
              padding: const EdgeInsets.symmetric(
                vertical: AppSizes.md,
                horizontal: AppSizes.lg,
              ),
              decoration: BoxDecoration(
                color: const Color.fromARGB(
                  255,
                  211,
                  216,
                  228,
                ).withOpacity(0.25),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 7),
                  if (_loadingRecs)
                    const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (_recommendations.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _recommendations
                          .take(3)
                          .map(
                            (m) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(''),
                                  Expanded(
                                    child: Text(
                                      _formatRecommendation(m),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    )
                  else
                    const Text(
                      '추천 정보를 불러올 수 없습니다.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.xl),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: AppSizes.lg,
                mainAxisSpacing: AppSizes.lg,
                childAspectRatio: 0.7,
                children: [
                  _gridItem(
                    title: '웃는 표정',
                    emoji: '😊',
                    buttonColor: AppColors.primary,
                    onTrain: () => _navigate(context, ExpressionType.smile),
                  ),
                  _gridItem(
                    title: '화난 표정',
                    emoji: '😠',
                    buttonColor: AppColors.error,
                    onTrain: () => _navigate(context, ExpressionType.angry),
                  ),
                  _gridItem(
                    title: '슬픈 표정',
                    emoji: '😢',
                    buttonColor: AppColors.secondary,
                    onTrain: () => _navigate(context, ExpressionType.sad),
                  ),
                  _gridItem(
                    title: '무표정',
                    emoji: '😐',
                    buttonColor: AppColors.accent,
                    onTrain: () => _navigate(context, ExpressionType.neutral),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gridItem({
    required String title,
    required String emoji,
    required Color buttonColor,
    required VoidCallback onTrain,
  }) {
    return Column(
      children: [
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 6),
                  child: Text(emoji, style: const TextStyle(fontSize: 64)),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onTrain,
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              foregroundColor: AppColors.surface,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: const Text(
              '훈련하기',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
