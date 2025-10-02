// ## 파일: lib/views/training_log_screen.dart ##

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../models/expression_type.dart';
import '../utils/constants.dart';
import '../services/training_api_service.dart';

class TrainingLogScreen extends StatefulWidget {
  final ExpressionType expressionType;
  const TrainingLogScreen({super.key, required this.expressionType});

  @override
  State<TrainingLogScreen> createState() => _TrainingLogScreenState();
}

class _TrainingLogScreenState extends State<TrainingLogScreen> {
  final _api = TrainingApiService();

  List<_Point> _points = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await _api.fetchSessions(
        expr: widget.expressionType.name,
        pageSize: 100, // 더 많은 기록을 가져올 수 있도록 페이지 크기 조정
      );

      final sessions = (list['sessions'] as List?)?.whereType<Map>().toList() ?? const [];
      final result = <_Point>[];

      for (final raw in sessions) {
        final sid = (raw['sid'] ?? raw['id'])?.toString();
        final timestampObject = raw['completedAt'] ?? raw['startedAt'];

        if (sid == null || timestampObject == null) continue;

        //  ProgressController와 동일한, 최종 날짜 처리 로직
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

        if (date == null) continue;

        var score = (raw['finalScore'] as num?)?.toDouble();

        if (score == null) continue;

        // ProgressController와 동일한, 점수 정규화 로직
        if (score > 1.0) {
          score = score / 100.0;
        }

        result.add(_Point(
          date: date,
          score: (score * 100.0).clamp(0, 100), // 표시를 위해 0~100으로 변환
        ));
      }

      result.sort((a, b) => a.date.compareTo(b.date));
      setState(() => _points = result);
    } catch (e) {
      setState(() => _error = "데이터를 불러오는 데 실패했습니다: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _title() {
    switch (widget.expressionType) {
      case ExpressionType.smile: return '웃는 표정';
      case ExpressionType.sad: return '슬픈 표정';
      case ExpressionType.angry: return '화난 표정';
      case ExpressionType.neutral: return '무표정';
    }
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('M/d');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('세부 기록: ${_title()}',
            style: const TextStyle(color: AppColors.textPrimary)),
        backgroundColor: AppColors.surface,
        centerTitle: true,
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text('오류가 발생했습니다:\n$_error', textAlign: TextAlign.center),
      ))
          : Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
                child: _points.isEmpty
                    ? const Center(child: Text('표시할 훈련 기록이 없습니다.'))
                    : LineChart(_chartData(df))
            ),
          ],
        ),
      ),
    );
  }

  LineChartData _chartData(DateFormat df) {
    final spots = <FlSpot>[];
    for (var i = 0; i < _points.length; i++) {
      spots.add(FlSpot(i.toDouble(), _points[i].score));
    }

    return LineChartData(
      minY: 0,
      maxY: 100,
      gridData: const FlGridData(show: true, drawVerticalLine: false),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: true, reservedSize: 32, interval: 25),
        ),
        rightTitles:
        const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles:
        const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            interval: 1,
            getTitlesWidget: (value, meta) {
              final idx = value.toInt();
              if (idx < 0 || idx >= _points.length) {
                return const SizedBox.shrink();
              }
              // 데이터가 많을 때 라벨 겹침 방지
              if (_points.length > 8 && idx % 2 != 0 && idx != _points.length - 1) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(df.format(_points[idx].date),
                    style: const TextStyle(fontSize: 11)),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
      lineTouchData: LineTouchData(
        handleBuiltInTouches: true,
        touchTooltipData: LineTouchTooltipData(
          tooltipRoundedRadius: 10,
          fitInsideHorizontally: true,
          fitInsideVertically: true,
          getTooltipItems: (list) {
            return list.map((s) {
              final idx = s.x.toInt();
              if (idx < 0 || idx >= _points.length) return null;
              final p = _points[idx];
              return LineTooltipItem(
                '${df.format(p.date)}\n점수: ${p.score.toStringAsFixed(1)}%',
                const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              );
            }).whereType<LineTooltipItem>().toList();
          },
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: AppColors.primary,
          barWidth: 4,
          belowBarData: BarAreaData(
            show: true,
            color: AppColors.primary.withOpacity(0.18),
          ),
          dotData: const FlDotData(show: true),
        ),
      ],
    );
  }
}

class _Point {
  final DateTime date;
  final double score; // 0~100

  _Point({
    required this.date,
    required this.score,
  });
}