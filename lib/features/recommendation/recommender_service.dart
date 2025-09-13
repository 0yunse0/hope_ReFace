import 'dart:math';
import 'package:reface/features/training/training_api.dart';

class Recommendation {
  final String expr;         // 추천 표정키: 'smile' | 'angry' | 'sad' | 'neutral'
  final double avgScore;     // 해당 표정의 평균 점수
  final int samples;         // 표본 개수
  Recommendation(this.expr, this.avgScore, this.samples);
}

class RecommenderService {
  final TrainingApi _api;
  RecommenderService(this._api);

  // lookback 기간 내 완료 세션만 집계해서 표정별 평균 구하고, 최저 평균을 추천
  Future<Recommendation?> recommendLowestAvg({
    Duration lookback = const Duration(days: 30),
  }) async {
    final now = DateTime.now().toUtc();
    final from = now.subtract(lookback);

    final sessions = await _api.listSessionsFiltered(
      status: 'completed',
      from: from,
      to: now,
      pageSize: 100,
    );

    if (sessions.isEmpty) return null;

    // expr -> (sum, cnt)
    final sums = <String, double>{};
    final counts = <String, int>{};

    for (final raw in sessions) {
      final m = (raw as Map).cast<String, dynamic>();
      final expr = (m['expr'] ?? '').toString();
      final score = (m['finalScore'] is num)
          ? (m['finalScore'] as num).toDouble()
          : null;
      if (expr.isEmpty || score == null) continue;

      sums[expr] = (sums[expr] ?? 0) + score;
      counts[expr] = (counts[expr] ?? 0) + 1;
    }

    if (counts.isEmpty) return null;

    String bestExpr = '';
    double bestAvg = double.infinity;
    int bestCnt = 0;

    sums.forEach((expr, sum) {
      final cnt = counts[expr]!;
      final avg = sum / max(cnt, 1);
      if (avg < bestAvg) {
        bestAvg = avg;
        bestExpr = expr;
        bestCnt = cnt;
      }
    });

    return Recommendation(bestExpr, bestAvg, bestCnt);
  }
}
