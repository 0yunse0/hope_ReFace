import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class InitialExpressionsPage extends StatefulWidget {
  final String functionsBase; // e.g., "https://asia-northeast3-<project-id>.cloudfunctions.net"
  const InitialExpressionsPage({super.key, required this.functionsBase});

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

      final payload = {
        "expressions": {
          for (final entry in _forms.entries) entry.key: entry.value.toJson(),
        }
      };

      final url = Uri.parse('${widget.functionsBase}/expressions/initial');
      final resp = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode(payload),
      );

      if (resp.statusCode == 200) {
        setState(() => _result = '✅ 저장 성공!');
      } else {
        setState(() => _result = '❌ 실패: ${resp.statusCode} ${resp.body}');
      }
    } catch (e) {
      setState(() => _result = '❌ 에러: $e');
    } finally {
      setState(() => _loading = false);
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
    // 기본값(임시) 넣어둬서 바로 테스트 가능
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
