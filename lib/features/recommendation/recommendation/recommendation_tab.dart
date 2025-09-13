import 'package:flutter/material.dart';
import 'package:reface/core/network/api_client.dart';
import 'package:reface/features/training/training_api.dart';
import 'package:reface/features/recommendation/recommender_service.dart';
import 'package:reface/features/training/training_flow_demo_page.dart'; // 훈련 페이지

const _exprLabels = {
  'neutral': '무표정',
  'smile': '웃음',
  'angry': '화남',
  'sad': '슬픔',
};
const _exprEmoji = {
  'neutral': '😐',
  'smile': '😊',
  'angry': '😡',
  'sad': '😢',
};

class RecommendationTab extends StatefulWidget {
  const RecommendationTab({super.key});

  @override
  State<RecommendationTab> createState() => _RecommendationTabState();
}

class _RecommendationTabState extends State<RecommendationTab> {
  late final RecommenderService _svc;
  bool _loading = true;
  String? _err;
  Recommendation? _rec;

  @override
  void initState() {
    super.initState();
    final api = TrainingApi(ApiClient()); // Env.baseUrl + auth 사용
    _svc = RecommenderService(api);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
      _rec = null;
    });
    try {
      final r = await _svc.recommendLowestAvg();
      setState(() => _rec = r);
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const Center(child: Padding(
        padding: EdgeInsets.all(24.0),
        child: CircularProgressIndicator(),
      ));
    } else if (_err != null) {
      body = Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('추천을 불러오지 못했습니다.', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 8),
            Text(_err!, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 시도'),
            ),
          ],
        ),
      );
    } else if (_rec == null) {
      body = Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('최근 30일에 완료된 세션이 없어 추천할 데이터가 없어요.'),
            SizedBox(height: 8),
            Text('먼저 아무 표정 모드로 1회 훈련을 완료해 주세요.'),
          ],
        ),
      );
    } else {
      final expr = _rec!.expr;
      final label = _exprLabels[expr] ?? expr;
      final emoji = _exprEmoji[expr] ?? '🙂';
      final avg = _rec!.avgScore.toStringAsFixed(1);

      body = Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 2,
          clipBehavior: Clip.hardEdge,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                color: Theme.of(context).colorScheme.surfaceVariant,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: const Text(
                  '진척도에 따른 표정 훈련 제안',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                child: Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 36)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '현재 평균 점수가 가장 낮은 모드: $label',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '최근 30일 평균 점수: $avg (표본 ${_rec!.samples}개)',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                TrainingFlowDemoPage(initialExpr: expr), // 추천 모드로 진입
                          ),
                        );
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: Text('$label 훈련 시작'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('새로고침'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(child: body);
  }
}
