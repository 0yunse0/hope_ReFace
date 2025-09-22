import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'home_page.dart';
import 'env.dart';

class InitialExpressionsPage extends StatefulWidget {
  const InitialExpressionsPage({super.key});

  @override
  State<InitialExpressionsPage> createState() => _InitialExpressionsPageState();
}

class _InitialExpressionsPageState extends State<InitialExpressionsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  final _forms = {
    'smile': _ExpressionFormState(),
    'angry': _ExpressionFormState(),
    'sad': _ExpressionFormState(),
    'neutral': _ExpressionFormState(),
  };

  bool _loading = false;
  String? _result;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    for (final f in _forms.values) {
      f.dispose();
    }
    super.dispose();
  }

  // TODO: 점수 계산 로직을 네 실제 알고리즘으로 교체
  num _calculateScore(Map<String, dynamic> landmarks) {
    // 예시: 키 개수를 점수로(임시). 실제 계산식으로 바꿔라!
    return landmarks.length;
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _result = null;
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _result = '로그인이 필요합니다.');
        return;
      }
      final idToken = await user.getIdToken();

      // 🔸 점수만 보내는 payload (좌표 전송 X)
      final payload = {
        'expressionScores': {
          for (final entry in _forms.entries)
            entry.key: _calculateScore(entry.value.toJson()),
        }
      };

      final url = Uri.parse('${Env.baseUrl}/expressions/initial');
      // 디버그: 최종 요청 확인
      // (모바일이면 Env.baseUrl이 반드시 https://asia-northeast3-<PROJECT>.cloudfunctions.net/api 여야 함)
      // 웹(Hosting)이라면 https://<project>.web.app/api 로도 OK
      debugPrint('[API] POST $url');
      debugPrint('[API] body = ${jsonEncode(payload)}');

      final resp = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode(payload),
      );

      if (!mounted) return;

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        final ok = body is Map && body['ok'] == true;

        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('저장 성공!')),
          );
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomePage()),
            (_) => false,
          );
        } else {
          setState(() => _result = '실패: 서버 응답에 ok=false');
        }
      } else {
        setState(() => _result = '실패: ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _result = '에러: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = const [
      Tab(text: 'smile'),
      Tab(text: 'angry'),
      Tab(text: 'sad'),
      Tab(text: 'neutral'),
    ];
    final views = [
      _ExpressionForm(title: 'smile', state: _forms['smile']!),
      _ExpressionForm(title: 'angry', state: _forms['angry']!),
      _ExpressionForm(title: 'sad', state: _forms['sad']!),
      _ExpressionForm(title: 'neutral', state: _forms['neutral']!),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Initial Expressions (테스트)'),
        bottom: TabBar(controller: _tab, tabs: tabs, isScrollable: true),
      ),
      body: TabBarView(controller: _tab, children: views),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_result != null)
                Text(_result!, style: const TextStyle(fontSize: 14)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('모든 표정 저장하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpressionFormState {
  final Map<String, TextEditingController> x = {};
  final Map<String, TextEditingController> y = {};
  final _keys = const [
    'bottomMouth','rightMouth','leftMouth',
    'leftEye','rightEye','rightCheek','leftCheek','noseBase'
  ];

  _ExpressionFormState() {
    for (final k in _keys) {
      x[k] = TextEditingController();
      y[k] = TextEditingController();
    }
    // 예시 기본값(원하면 삭제 가능)
    x['bottomMouth']!.text = '209'; y['bottomMouth']!.text = '518';
    x['rightMouth']!.text  = '248'; y['rightMouth']!.text  = '508';
    x['leftMouth']!.text   = '182'; y['leftMouth']!.text   = '507';
    x['leftEye']!.text     = '214'; y['leftEye']!.text     = '389';
    x['rightEye']!.text    = '268'; y['rightEye']!.text    = '402';
    x['rightCheek']!.text  = '282'; y['rightCheek']!.text  = '406';
    x['leftCheek']!.text   = '159'; y['leftCheek']!.text   = '465';
    x['noseBase']!.text    = '208'; y['noseBase']!.text    = '439';
  }

  Map<String, dynamic> toJson() {
    double parse(String s) => double.parse(s.trim());
    final map = <String, dynamic>{};
    for (final k in x.keys) {
      map[k] = {'x': parse(x[k]!.text), 'y': parse(y[k]!.text)};
    }
    return map;
  }

  void dispose() {
    for (final c in x.values) { c.dispose(); }
    for (final c in y.values) { c.dispose(); }
  }
}

class _ExpressionForm extends StatelessWidget {
  final String title;
  final _ExpressionFormState state;
  const _ExpressionForm({required this.title, required this.state});

  @override
  Widget build(BuildContext context) {
    final keys = state.x.keys.toList();
    return Padding(
      padding: const EdgeInsets.all(12),
      child: ListView.separated(
        itemCount: keys.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final k = keys[i];
          return Row(
            children: [
              SizedBox(
                width: 120,
                child: Text(k, style: const TextStyle(fontSize: 14)),
              ),
              Expanded(
                child: TextField(
                  controller: state.x[k],
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'x'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: state.y[k],
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'y'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
