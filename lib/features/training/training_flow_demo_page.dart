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
      final res = await _raw.get('/training/recommendations');
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






////////////////진척도 기반 추천 테스트용///////////////훈련페이지 들어가면 추천만 뜨게
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:reface/core/network/api_client.dart';

// /// 추천 API 확인 전용 페이지
// /// - 페이지 진입 즉시 추천을 요청해서 결과(expr, progress)만 보여줌
// /// - 캐시 방지를 위해 매 요청마다 ts 파라미터를 붙임
// class TrainingFlowDemoPage extends StatefulWidget {
//   const TrainingFlowDemoPage({super.key});

//   @override
//   State<TrainingFlowDemoPage> createState() => _TrainingFlowDemoPageState();
// }

// class _TrainingFlowDemoPageState extends State<TrainingFlowDemoPage> {
//   final _api = ApiClient();

//   bool _loading = false;
//   String? _expr;        // 추천된 표정 (neutral/smile/angry/sad)
//   num? _progress;       // 추천 표정의 최근 평균 진척도(0~100)
//   String? _errorText;   // 에러 메시지(있으면 화면에 표시)

//   @override
//   void initState() {
//     super.initState();
//     _fetchRecommendation(); // 들어오자마자 호출
//   }

//   Future<void> _fetchRecommendation() async {
//     setState(() {
//       _loading = true;
//       _errorText = null;
//     });

//     try {
//       final ts = DateTime.now().millisecondsSinceEpoch;
//       // 1차: 정식 경로
//       var res = await _api.get('/training/recommendations?ts=$ts');

//       // 404면: 별칭 경로 폴백
//       if (res.statusCode == 404) {
//         res = await _api.get('/recommendations?ts=$ts');
//       }

//       if (res.statusCode != 200) {
//         setState(() {
//           _errorText = 'HTTP ${res.statusCode} - ${res.body}';
//         });
//         return;
//       }

//       final json = jsonDecode(res.body) as Map<String, dynamic>;
//       setState(() {
//         _expr     = json['expr']?.toString();
//         _progress = (json['progress'] is num) ? json['progress'] as num : null;
//       });
//     } catch (e) {
//       setState(() {
//         _errorText = e.toString();
//       });
//     } finally {
//       if (mounted) {
//         setState(() => _loading = false);
//       }
//     }
//   }

//   String _exprLabel(String? e) {
//     switch (e) {
//       case 'neutral': return '무표정 (neutral)';
//       case 'smile':   return '웃음 (smile)';
//       case 'angry':   return '화남 (angry)';
//       case 'sad':     return '슬픔 (sad)';
//       default:        return e ?? '-';
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('추천 테스트(간소화)'),
//         actions: [
//           IconButton(
//             onPressed: _loading ? null : _fetchRecommendation,
//             tooltip: '다시 불러오기',
//             icon: _loading
//                 ? const SizedBox(
//                     width: 18, height: 18,
//                     child: CircularProgressIndicator(strokeWidth: 2),
//                   )
//                 : const Icon(Icons.refresh),
//           ),
//         ],
//       ),
//       body: Center(
//         child: ConstrainedBox(
//           constraints: const BoxConstraints(maxWidth: 520),
//           child: Padding(
//             padding: const EdgeInsets.all(20),
//             child: _buildBody(theme),
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildBody(ThemeData theme) {
//     if (_loading) {
//       return const Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           CircularProgressIndicator(),
//           SizedBox(height: 12),
//           Text('추천 불러오는 중…'),
//         ],
//       );
//     }

//     if (_errorText != null) {
//       return Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Icon(Icons.error_outline, color: theme.colorScheme.error, size: 28),
//           const SizedBox(height: 8),
//           Text(
//             '추천 요청 실패',
//             style: theme.textTheme.titleMedium?.copyWith(
//               color: theme.colorScheme.error,
//               fontWeight: FontWeight.w600,
//             ),
//           ),
//           const SizedBox(height: 6),
//           Text(
//             _errorText!,
//             textAlign: TextAlign.center,
//             style: theme.textTheme.bodySmall,
//           ),
//           const SizedBox(height: 12),
//           FilledButton.icon(
//             onPressed: _fetchRecommendation,
//             icon: const Icon(Icons.refresh),
//             label: const Text('다시 시도'),
//           ),
//         ],
//       );
//     }

//     if (_expr == null) {
//       return Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           const Icon(Icons.info_outline, size: 28),
//           const SizedBox(height: 8),
//           const Text('추천 결과가 없습니다.'),
//           const SizedBox(height: 12),
//           FilledButton.icon(
//             onPressed: _fetchRecommendation,
//             icon: const Icon(Icons.refresh),
//             label: const Text('다시 불러오기'),
//           ),
//         ],
//       );
//     }

//     // 정상 결과 표시
//     return Card(
//       elevation: 0.5,
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
//       child: Padding(
//         padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('추천 훈련 모드', style: theme.textTheme.titleMedium),
//             const SizedBox(height: 8),
//             Row(
//               children: [
//                 const Icon(Icons.auto_awesome),
//                 const SizedBox(width: 8),
//                 Text(
//                   _exprLabel(_expr),
//                   style: theme.textTheme.headlineSmall?.copyWith(
//                     fontWeight: FontWeight.w700,
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 8),
//             Text(
//               '최근 평균 진척도: '
//               '${_progress == null ? '-' : _progress!.toStringAsFixed(1)}',
//               style: theme.textTheme.bodyMedium,
//             ),
//             const SizedBox(height: 14),
//             Row(
//               children: [
//                 FilledButton.icon(
//                   onPressed: _fetchRecommendation,
//                   icon: const Icon(Icons.refresh),
//                   label: const Text('다시 불러오기'),
//                 ),
//                 const SizedBox(width: 8),
//                 Text(
//                   '페이지 진입 시 자동으로 불러옵니다.',
//                   style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
//                 ),
//               ],
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }





