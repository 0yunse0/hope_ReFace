// ## 파일: lib/models/training_record.dart ##

import 'dart:convert';
import 'package:intl/intl.dart';
import 'expression_type.dart';

class TrainingRecord {
  final DateTime timestamp;
  final ExpressionType expressionType;
  final double score;
  // final String? imagePath; // TODO: 나중에 이미지 캡쳐 기능 추가 시 사용

  TrainingRecord({
    required this.timestamp,
    required this.expressionType,
    required this.score,
    // this.imagePath,
  });

  /// 'yyyy-MM-dd' 형식의 날짜 문자열을 반환 (차트에서 날짜별 그룹핑 등에 사용)
  String get dateKey => DateFormat('yyyy-MM-dd').format(timestamp);

  /// 객체를 JSON 맵으로 변환
  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'expressionType': expressionType.name,
    'score': score,
  };

  /// JSON 맵에서 객체로 변환
  factory TrainingRecord.fromJson(Map<String, dynamic> json) {
    return TrainingRecord(
      timestamp: DateTime.parse(json['timestamp']),
      expressionType: ExpressionType.values.firstWhere(
            (e) => e.name == json['expressionType'],
        orElse: () => ExpressionType.smile,
      ),
      score: (json['score'] as num).toDouble(),
    );
  }
}