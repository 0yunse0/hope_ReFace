import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:reface/core/network/api_client.dart';
import 'package:reface/features/training/training_api.dart';

/// 훈련 파이프라인 데모 페이지
/// - baseline / reference: 48/54(입꼬리)를 서로 다른 좌표로 설정 (분모=0 방지)->평균 스코어 100 고정 방지
class TrainingFlowDemoPage extends StatefulWidget {
  /// 추천 화면 등에서 시작 모드를 넘겨줄 때 사용(없으면 'smile')
  final String? initialExpr;
  const TrainingFlowDemoPage({super.key, this.initialExpr});

  @override
  State<TrainingFlowDemoPage> createState() => _TrainingFlowDemoPageState();
}

class _TrainingFlowDemoPageState extends State<TrainingFlowDemoPage> {
  final _api = TrainingApi(ApiClient());      // 기존 API 래퍼
  final _raw = ApiClient();                   // 추천 API는 여기서 직접 GET 호출

  // 사용할 랜드마크 키
  final landmarkKeys = const [
    '48','54','leftMouth','rightMouth','leftEye','rightEye','leftCheek','rightCheek','noseBase',
  ];

  String _expr = 'smile';
  String? _sid;
  bool _busy = false;

  // ▼ 추천 관련 상태
  bool _recBusy = false;
  String? _recExpr;                 // recommendedExpr
  String? _recReason;               // reason
  List<Map<String, dynamic>> _recCandidates = []; // [{expr, avgScore, ...}, ...]

  int _sets = 3;
  double _jitter = 4; // 프레임 흔들림(픽셀)

  final _log = <String>[];

  @override
  void initState() {
    super.initState();
    _expr = widget.initialExpr ?? 'smile'; // 추천에서 전달한 모드로 초기화(없으면 기본값)
  }

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

  /// 추천 불러오기 (/training/recommendations?limit=3)
  Future<void> _fetchRecommendation({int limit = 3}) async {
    setState(() => _recBusy = true);
    try {
      final res = await _raw.get('/training/recommendations?limit=$limit');
      if (res.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('추천 불러오기 실패: ${res.statusCode} ${res.body}')),
        );
        return;
      }
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final candidates = (j['candidates'] as List<dynamic>? ?? [])
          .cast<Map>()
          .map((e) => e.map((k, v) => MapEntry(k.toString(), v)))
          .toList();

      setState(() {
        _recExpr = j['recommendedExpr']?.toString();
        _recReason = j['reason']?.toString();
        _recCandidates = candidates.cast<Map<String, dynamic>>();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('추천 불러오기 에러: $e')),
      );
    } finally {
      if (mounted) setState(() => _recBusy = false);
    }
  }

  /// 추천 적용(드롭다운 값 변경)
  void _applyRecommendation() {
    if (_recExpr == null) return;
    setState(() => _expr = _recExpr!);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('추천 훈련 모드 적용: $_recExpr')),
    );
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

      // 3) 세트 저장
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
            // ── 추천 영역 ────────────────────────────────────────────────
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _recBusy ? null : () => _fetchRecommendation(limit: 3),
                  icon: _recBusy
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.auto_awesome),
                  label: const Text('추천 불러오기'),
                ),
                const SizedBox(width: 12),
                if (_recExpr != null)
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(
                          label: Text('추천: $_recExpr'),
                          avatar: const Icon(Icons.thumb_up_alt_outlined, size: 18),
                        ),
                        if (_recReason != null && _recReason!.isNotEmpty)
                          Text(
                            _recReason!,
                            style: const TextStyle(fontSize: 12, color: Colors.black54),
                            overflow: TextOverflow.ellipsis,
                          ),
                        TextButton(
                          onPressed: _applyRecommendation,
                          child: const Text('추천 적용'),
                        ),
                        if (_recCandidates.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                builder: (_) => SafeArea(
                                  child: ListView.separated(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: _recCandidates.length,
                                    separatorBuilder: (_, __) => const Divider(),
                                    itemBuilder: (_, i) {
                                      final c = _recCandidates[i];
                                      final expr = c['expr']?.toString() ?? '-';
                                      final avg  = (c['avgScore'] ?? '').toString();
                                      final count= c['sessionsCount']?.toString() ?? '-';
                                      return ListTile(
                                        leading: CircleAvatar(child: Text('${i+1}')),
                                        title: Text(expr),
                                        subtitle: Text('평균 진척도: $avg / 세션 수: $count'),
                                        trailing: TextButton(
                                          onPressed: () {
                                            setState(() => _expr = expr);
                                            Navigator.pop(context);
                                          },
                                          child: const Text('적용'),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                            child: const Text('후보 보기'),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // ── 기존 컨트롤 영역 ────────────────────────────────────────
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
