// ## 파일: lib/services/training_record_service.dart ##

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/training_record.dart';
import '../models/expression_type.dart';

class TrainingRecordService {
  // 1. 모든 훈련 시도를 기록하는 키
  static const _historyKey = 'training_records_v2';
  // 2. 최고 점수만 기록하는 키
  static const _personalBestKey = 'personal_best_scores';

  // --- 훈련 이력 (History) 관련 함수들 ---

  /// 새로운 훈련 기록을 무조건 이력에 추가
  Future<void> _addRecordToHistory(TrainingRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final rawJsonList = prefs.getStringList(_historyKey) ?? [];
    List<TrainingRecord> allRecords;
    try {
      allRecords = rawJsonList
          .map((jsonString) => TrainingRecord.fromJson(jsonDecode(jsonString)))
          .toList();
    } catch (e) {
      allRecords = [];
    }
    allRecords.add(record);
    final jsonStringList = allRecords.map((r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList(_historyKey, jsonStringList);
  }

  /// 모든 훈련 이력 불러오기 (home_screen의 전체 평균 그래프용)
  Future<List<TrainingRecord>> getAllHistoryRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final rawJsonList = prefs.getStringList(_historyKey) ?? [];
    try {
      return rawJsonList
          .map((jsonString) => TrainingRecord.fromJson(jsonDecode(jsonString)))
          .toList();
    } catch (e) {
      await clearAllHistory();
      return [];
    }
  }

  /// 특정 표정의 모든 훈련 이력 불러오기 (training_log_screen용)
  Future<List<TrainingRecord>> getRecordsForType(ExpressionType type) async {
    final prefs = await SharedPreferences.getInstance();
    final rawJsonList = prefs.getStringList(_historyKey) ?? [];
    try {
      final allRecords = rawJsonList
          .map((jsonString) => TrainingRecord.fromJson(jsonDecode(jsonString)))
          .toList();
      return allRecords.where((record) => record.expressionType == type).toList();
    } catch (e) {
      await clearAllHistory();
      return [];
    }
  }

  /// 모든 훈련 이력 삭제
  Future<void> clearAllHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  // --- 최고 점수 (Personal Best) 관련 함수들 ---

  /// 현재 저장된 최고 점수들을 불러오기
  Future<Map<ExpressionType, double>> getPersonalBestScores() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_personalBestKey);
    if (jsonString == null) {
      return { for (var type in ExpressionType.values) type: 0.0 };
    }
    final Map<String, dynamic> decodedMap = jsonDecode(jsonString);
    final scores = <ExpressionType, double>{};
    for(var type in ExpressionType.values) {
      scores[type] = (decodedMap[type.name] as num?)?.toDouble() ?? 0.0;
    }
    return scores;
  }

  /// 초기 측정 점수를 최고 점수로 저장
  Future<void> saveInitialPersonalBestScores(Map<ExpressionType, double> initialScores) async {
    final prefs = await SharedPreferences.getInstance();
    final stringMap = initialScores.map((key, value) => MapEntry(key.name, value));
    await prefs.setString(_personalBestKey, jsonEncode(stringMap));

    for (var entry in initialScores.entries) {
      final record = TrainingRecord(
        timestamp: DateTime.now(),
        expressionType: entry.key,
        score: entry.value,
      );
      await _addRecordToHistory(record);
    }
  }

  /// 새 기록을 이력에 추가하고, 최고 점수일 경우에만 업데이트
  Future<void> updateScoreAndAddRecord(TrainingRecord newRecord) async {
    await _addRecordToHistory(newRecord);
    final currentBestScores = await getPersonalBestScores();
    final currentBestScore = currentBestScores[newRecord.expressionType] ?? 0.0;

    if (newRecord.score > currentBestScore) {
      final prefs = await SharedPreferences.getInstance();
      currentBestScores[newRecord.expressionType] = newRecord.score;
      final stringMap = currentBestScores.map((key, value) => MapEntry(key.name, value));
      await prefs.setString(_personalBestKey, jsonEncode(stringMap));
    }
  }

  /// 모든 진행 기록을 초기화하는 함수
  Future<void> resetAllProgress() async {
    final prefs = await SharedPreferences.getInstance();
    // 1. 전체 훈련 이력 삭제
    await prefs.remove(_historyKey);
    // 2. 최고 점수 기록 삭제
    await prefs.remove(_personalBestKey);
  }
}