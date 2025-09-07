// lib/features/training/training_flow_demo_page.dart
import 'package:flutter/material.dart';
import 'package:reface/core/network/api_client.dart';
import 'package:reface/features/training/training_api.dart';

class TrainingFlowDemoPage extends StatefulWidget {
  const TrainingFlowDemoPage({super.key});

  @override
  State<TrainingFlowDemoPage> createState() => _TrainingFlowDemoPageState();
}

class _TrainingFlowDemoPageState extends State<TrainingFlowDemoPage> {
  final _api = TrainingApi(ApiClient());
  String _expr = 'smile';
  String? _sid;
  final _log = <String>[];
  bool _busy = false;

  final landmarkKeys = const [
    '48','54', // 입꼬리
    'leftMouth','rightMouth','leftEye','rightEye','leftCheek','rightCheek','noseBase'
  ];

  // 대충 baseline/reference 더미(실제론 너희 초기표정/레퍼런스 불러와 채움)
  Map<String, dynamic> _dummyPoint(int x, int y) => {'x': x, 'y': y};
  Map<String, dynamic> _makeMap(List<String> keys, int x, int y) =>
      {for (final k in keys) k: _dummyPoint(x, y)};

  Future<void> _run() async {
    setState(() => _busy = true);
    _log.clear();
    try {
      _log.add('세션 시작...');
      final sid = await _api.startSession(_expr);
      _sid = sid;
      setState(() {});

      final baseline = _makeMap(landmarkKeys, 120, 460);
      final reference = _makeMap(landmarkKeys, 116, 446);

      for (int i = 1; i <= 3; i++) {
        _log.add('세트 #$i 저장 중...');
        final frames = _api.makeRandomFrames(
          landmarkKeys: landmarkKeys,
          seed: i * 7,
          withImageOnLast: true,
        );
        final setRes = await _api.saveSet(
          sid: sid, baseline: baseline, reference: reference, frames: frames,
        );
        _log.add('세트 #$i 결과: score=${setRes['score']}, image=${setRes['lastFrameImage'] ?? '-'}');
        setState(() {});
      }

      _log.add('세션 완료 평균 계산...');
      final finalRes = await _api.finalizeSession(sid, summary: 'demo run');
      _log.add('완료: finalScore=${finalRes['finalScore']} (sets=${finalRes['setsCount']})');

      setState(() {});
    } catch (e) {
      _log.add('에러: $e');
      setState(() {});
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('훈련 모드 데모')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButton<String>(
              value: _expr,
              items: const [
                DropdownMenuItem(value: 'neutral', child: Text('무표정')),
                DropdownMenuItem(value: 'smile', child: Text('웃음')),
                DropdownMenuItem(value: 'angry', child: Text('화남')),
                DropdownMenuItem(value: 'sad', child: Text('슬픔')),
              ],
              onChanged: _busy ? null : (v) => setState(() => _expr = v!),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _busy ? null : _run,
              child: Text(_busy ? '진행 중...' : '3세트 자동 진행'),
            ),
            const SizedBox(height: 12),
            if (_sid != null) Text('sid: $_sid'),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _log.length,
                itemBuilder: (_, i) => Text(_log[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
