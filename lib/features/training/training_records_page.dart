import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:reface/core/network/api_client.dart';
import 'package:reface/features/training/training_api.dart';

class TrainingRecordsPage extends StatefulWidget {
  const TrainingRecordsPage({super.key});

  @override
  State<TrainingRecordsPage> createState() => _TrainingRecordsPageState();
}

class _TrainingRecordsPageState extends State<TrainingRecordsPage> {
  final _api = TrainingApi(ApiClient());
  List<dynamic> _sessions = [];
  bool _busy = false;

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final s = await _api.listSessions();
      setState(() => _sessions = s);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('불러오기 실패: $e')));
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('훈련 기록')),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: _sessions.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (_, i) {
                final s = _sessions[i] as Map<String, dynamic>;
                return ListTile(
                  title: Text('${s['expr']}'),
                  subtitle: Text('finalScore: ${s['finalScore'] ?? '-'}  status: ${s['status']}'),
                  trailing: const Icon(Icons.chevron_right),
                );
              },
            ),
    );
  }
}
