import 'dart:math';
import 'package:flutter/material.dart';
import 'package:reface/core/network/api_client.dart';
import 'package:reface/features/training/training_api.dart';

/// 훈련 파이프라인 데모 페이지
/// - baseline / reference: 48/54(입꼬리)를 서로 다른 좌표로 설정 (분모=0 방지)->평균 스코어 자꾸 100나오는거 오류해결
class TrainingFlowDemoPage extends StatefulWidget {
  const TrainingFlowDemoPage({super.key});

  @override
  State<TrainingFlowDemoPage> createState() => _TrainingFlowDemoPageState();
}

class _TrainingFlowDemoPageState extends State<TrainingFlowDemoPage> {
  final _api = TrainingApi(ApiClient()); // Env.baseUrl 쓰는 ApiClient 기본값

  // 사용할 랜드마크 키
  final landmarkKeys = const [
    '48','54','leftMouth','rightMouth','leftEye','rightEye','leftCheek','rightCheek','noseBase',
  ];


  String _expr = 'smile';
  String? _sid;
  bool _busy = false;
  int _sets = 3;
  double _jitter = 4; // 프레임 흔들림(픽셀)

  final _log = <String>[];

  // 48/54만 다르게 주는 맵 생성기
  Map<String, dynamic> _makeMouthAwareMap({
    required List<String> keys,
    required int x48, required int y48,
    required int x54, required int y54,
    required int xOther, required int yOther,
  }) {
    return {
      for (final k in keys)
        k: k == '48'
            ? {'x': x48, 'y': y48}
            : k == '54'
                ? {'x': x54, 'y': y54}
                : {'x': xOther, 'y': yOther},
    };
  }

  // reference 중심으로 소폭 요동하는 프레임들 생성
  List<Map<String, dynamic>> _framesAroundReference({
    required Map<String, dynamic> reference,
    required int count,
    required int seed,
    required double jitter,
    bool withImageOnLast = true,
  }) {
    final rnd = Random(seed);
    final frames = <Map<String, dynamic>>[];

    for (int t = 0; t < count; t++) {
      final curr = <String, dynamic>{};
      for (final k in landmarkKeys) {
        final rx = (reference[k]['x'] as num).toDouble();
        final ry = (reference[k]['y'] as num).toDouble();
        // -jitter ~ +jitter
        final dx = (rnd.nextDouble() * 2 - 1) * jitter;
        final dy = (rnd.nextDouble() * 2 - 1) * jitter;
        curr[k] = {'x': (rx + dx).round(), 'y': (ry + dy).round()};
      }
      final f = {'ts': t, 'current': curr};

      // 마지막 프레임에만 더미 이미지(서버가 업로드/URL 반환하는 경우)
      if (withImageOnLast && t == count - 1) {
        f['imageBase64'] = 'data:image/png;base64,iVBORw0KGgo='; // 더미
      }
      frames.add(f);
    }
    return frames;
  }

  Future<void> _run() async {
    setState(() => _busy = true);
    _log
      ..clear()
      ..add('세션 시작…');

    try {
      // 1) 세션 시작
      final sid = await _api.startSession(_expr);
      _sid = sid;
      setState(() {});
      _log.add('sid: $sid');

      // 2) baseline / reference 생성
      // - 48/54 거리를 서로 다르게 주어 분모 0 방지
      //   나머지 키는 중간값으로 통일
      final baseline = _makeMouthAwareMap(
        keys: landmarkKeys,
        x48: 110, y48: 460,
        x54: 150, y54: 462,
        xOther: 130, yOther: 461,
      );
      final reference = _makeMouthAwareMap(
        keys: landmarkKeys,
        x48: 105, y48: 450,
        x54: 155, y54: 452,
        xOther: 130, yOther: 451,
      );

      // 3) 세트 저장 (각 세트는 reference 주변으로 흔들리는 프레임들)
      for (int i = 1; i <= _sets; i++) {
        _log.add('세트 #$i 저장 중…');
        setState(() {});

        final frames = _framesAroundReference(
          reference: reference,
          count: 15,
          seed: i * 13,
          jitter: _jitter,
          withImageOnLast: true,
        );

        final res = await _api.saveSet(
          sid: sid,
          baseline: baseline,
          reference: reference,
          frames: frames,
        );

        _log.add(
          '세트 #$i 결과: score=${res['score']}, image=${res['lastFrameImage'] ?? '-'}',
        );
        setState(() {});
      }

      // 4) 세션 마무리
      _log.add('세션 완료 평균 계산…');
      setState(() {});
      final finalRes = await _api.finalizeSession(sid, summary: 'demo run');
      _log.add('완료: finalScore=${finalRes['finalScore']} (sets=${finalRes['setsCount']})');
    } catch (e) {
      _log.add('에러: $e');
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                const SizedBox(width: 16),
                const Text('세트 수'),
                const SizedBox(width: 8),
                DropdownButton<int>(
                  value: _sets,
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1')),
                    DropdownMenuItem(value: 2, child: Text('2')),
                    DropdownMenuItem(value: 3, child: Text('3')),
                    DropdownMenuItem(value: 4, child: Text('4')),
                  ],
                  onChanged: _busy ? null : (v) => setState(() => _sets = v!),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Row(
                    children: [
                      const Text('흔들림(px)'),
                      Expanded(
                        child: Slider(
                          value: _jitter,
                          min: 0,
                          max: 12,
                          divisions: 12,
                          label: _jitter.toStringAsFixed(0),
                          onChanged: _busy ? null : (v) => setState(() => _jitter = v),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _busy ? null : _run,
                  child: Text(_busy ? '진행 중…' : '실행'),
                ),
              ],
            ),
            const SizedBox(height: 8),
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
