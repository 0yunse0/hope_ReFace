// ## 파일: lib/controllers/progress_controller.dart ##

import 'package:get/get.dart';
import 'package:collection/collection.dart';
import 'package:intl/intl.dart';

import '../models/expression_type.dart';
import '../models/training_record.dart';
import '../services/training_api_service.dart';

class ProgressController extends GetxController {
  final TrainingApiService _apiService = TrainingApiService();

  final RxDouble personalBestAverage = 0.0.obs;
  final RxMap<ExpressionType, double> personalBests = <ExpressionType, double>{}.obs;
  final RxMap<DateTime, double> dailyAverages = <DateTime, double>{}.obs;

  @override
  void onInit() {
    super.onInit();
    fetchAndUpdateProgress();
  }

  Future<void> fetchAndUpdateProgress() async {
    try {
      final results = await Future.wait([
        _apiService.fetchInitialScores(),
        _apiService.fetchSessions(pageSize: 1000),
      ]);

      final initialScoresData = results[0];
      final trainingSessionsData = results[1];

      final allRecords = _convertApiDataToRecords(trainingSessionsData['sessions'] as List<dynamic>);

      // --- 1. 표정별 "최고 기록" 계산 ---
      final calculatedBests = <ExpressionType, double>{};
      final initialScoresMap = initialScoresData['expressionScores'] as Map<String, dynamic>? ?? {};
      for (var type in ExpressionType.values) {
        final score = (initialScoresMap[type.name] as num?)?.toDouble() ?? 0.0;
        calculatedBests[type] = score / 100.0;
      }
      for (final record in allRecords) {
        final currentBest = calculatedBests[record.expressionType] ?? 0.0;
        if (record.score > currentBest) {
          calculatedBests[record.expressionType] = record.score;
        }
      }
      personalBests.value = calculatedBests;

      // --- 2. "최고 기록 평균" 계산 ---
      final validScores = calculatedBests.values.where((score) => score > 0);
      if (validScores.isNotEmpty) {
        final total = validScores.reduce((a, b) => a + b);
        personalBestAverage.value = (total / validScores.length) * 100.0;
      } else {
        personalBestAverage.value = 0.0;
      }

      // --- 3. Home 화면의 라인 그래프를 위한 "날짜별 평균" 계산 ---
      final recordsByDate = groupBy(allRecords, (TrainingRecord r) => r.dateKey);
      final newDailyAverages = <DateTime, double>{};
      recordsByDate.forEach((dateKey, recordsOnDate) {
        final date = DateFormat('yyyy-MM-dd').parse(dateKey);
        final List<double> trainedScores = [];
        for(var type in ExpressionType.values) {
          final bestScore = recordsOnDate
              .where((r) => r.expressionType == type)
              .map((r) => r.score)
              .maxOrNull;

          if (bestScore != null) {
            trainedScores.add(bestScore);
          }
        }
        if (trainedScores.isNotEmpty) {
          final averageScore = trainedScores.reduce((a, b) => a + b) / trainedScores.length;
          newDailyAverages[date] = averageScore * 100.0;
        }
      });
      dailyAverages.value = newDailyAverages;

    } catch (e) {
      print("Error fetching progress: $e");
      personalBestAverage.value = 0.0;
      personalBests.value = {};
      dailyAverages.value = {};
    }
  }

  List<TrainingRecord> _convertApiDataToRecords(List<dynamic> sessions) {
    final records = <TrainingRecord>[];
    for (final session in sessions) {
      if (session is! Map<String, dynamic>) continue;

      final exprString = session['expr'] as String?;
      var score = (session['finalScore'] as num?)?.toDouble();
      final timestampObject = session['completedAt'] ?? session['startedAt'];

      if (exprString == null || score == null || timestampObject == null) continue;

      if (score > 1.0) {
        score = score / 100.0;
      }

      DateTime? date;
      if (timestampObject is Map && timestampObject.containsKey('_seconds')) {
        date = DateTime.fromMillisecondsSinceEpoch(timestampObject['_seconds'] * 1000);
      } else if (timestampObject is String) {
        try {
          final format = DateFormat("yyyy년 MM월 dd일 a h시 m분 s초 'UTC'+9", 'ko');
          date = format.parse(timestampObject);
        } catch (e) {
          date = DateTime.tryParse(timestampObject)?.toLocal();
        }
      }

      final expressionType = ExpressionType.values.firstWhereOrNull((e) => e.name == exprString);

      if (date != null && expressionType != null) {
        records.add(TrainingRecord(
          timestamp: date,
          expressionType: expressionType,
          score: score, // 항상 0~1 범위의 점수
        ));
      }
    }
    return records;
  }
}