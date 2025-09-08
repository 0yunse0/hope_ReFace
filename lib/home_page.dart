import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/auth_service.dart';
import 'login_page.dart';
import 'services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ▼ 추가: 훈련 데모/기록 페이지 임포트
import 'features/training/training_flow_demo_page.dart';
import 'features/training/training_records_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _auth = AuthService();
  final _fs = FirestoreService();

  @override
  void initState() {
    super.initState();
    _fs.ensureUserDoc(); // 최초 입장 시 사용자 문서 보장
  }

  Future<void> _addSample() async {
    // 점수 예시로 50~100 랜덤 저장 (기존 FirestoreService 샘플)
    final score = 50 + (DateTime.now().millisecond % 51);
    await _fs.addSampleSession(score: score);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('세션 저장됨')));
    }
  }

  Future<void> _signOut() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Future<void> _deleteAccountFlow() async {
    final controller = TextEditingController();
    final key = GlobalKey<FormState>();
    bool loading = false;
    String? err;

    await showDialog(
      context: context,
      barrierDismissible: !loading,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('회원 탈퇴'),
          content: Form(
            key: key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('비밀번호를 재입력하세요. 모든 데이터가 삭제됩니다.'),
                const SizedBox(height: 12),
                TextFormField(
                  controller: controller,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: '비밀번호',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? '비밀번호를 입력하세요' : null,
                ),
                if (err != null) ...[
                  const SizedBox(height: 8),
                  Text(err!, style: const TextStyle(color: Colors.red)),
                ]
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: loading ? null : () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton.icon(
              icon: loading
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.delete_forever),
              label: const Text('탈퇴'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: loading
                  ? null
                  : () async {
                      if (!key.currentState!.validate()) return;
                      setLocal(() => loading = true);
                      try {
                        final uid = FirebaseAuth.instance.currentUser!.uid;
                        // 1) Firestore 데이터 삭제
                        await _fs.deleteAllUserData(uid);
                        // 2) Auth 계정 삭제(재인증)
                        await _auth.deleteAccount(controller.text.trim());
                        if (!mounted) return;
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                          (route) => false,
                        );
                      } catch (e) {
                        setLocal(() {
                          loading = false;
                          err = e.toString();
                        });
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  void _openTrainingDemo() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TrainingFlowDemoPage()),
    );
  }

  void _openTrainingRecords() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TrainingRecordsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            tooltip: '세션 저장(샘플)',
            icon: const Icon(Icons.save),
            onPressed: _addSample,
          ),
          IconButton(
            tooltip: '로그아웃',
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
          IconButton(
            tooltip: '회원 탈퇴',
            icon: const Icon(Icons.delete_forever),
            onPressed: _deleteAccountFlow,
          ),
        ],
      ),
      body: uid.isEmpty
          ? const Center(child: Text('로그인 정보 없음'))
          : Column(
              children: [
                // ▼ 상단: 훈련모드/훈련기록 진입 버튼 2개
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _openTrainingDemo,
                          icon: const Icon(Icons.play_circle_fill),
                          label: const Text('훈련 모드(데모)'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _openTrainingRecords,
                          icon: const Icon(Icons.library_books),
                          label: const Text('훈련 기록 보기'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),

                // ▼ 하단: 기존 Firestore 샘플 스트림(원하면 유지/삭제 선택)
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _fs.sessionsStream(),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snap.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return const Center(
                          child: Text('세션이 없습니다. 상단의 "훈련 모드(데모)"를 눌러 테스트해보세요.'),
                        );
                      }
                      return ListView.separated(
                        itemCount: docs.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final d = docs[i].data();
                          final score = d['score'];
                          final ts = d['createdAt'];
                          final when = ts is Timestamp ? ts.toDate() : null;
                          return ListTile(
                            leading: const Icon(Icons.insert_chart_outlined),
                            title: Text('score: $score'),
                            subtitle: Text(when?.toString() ?? ''),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
