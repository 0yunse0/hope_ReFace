import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'home_page.dart';
import 'features/constants.dart';
import 'env.dart';
import 'services/firestore_service.dart';

class InitialExpressionsPage extends StatefulWidget {
  const InitialExpressionsPage({super.key});
  @override
  State<InitialExpressionsPage> createState() => _InitialExpressionsPageState();
}

class _InitialExpressionsPageState extends State<InitialExpressionsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _fs = FirestoreService();

  final Map<String, TextEditingController> _controllers = {
    'smile': TextEditingController(),
    'angry': TextEditingController(),
    'sad': TextEditingController(),
    'neutral': TextEditingController(),
  };

  bool _saving = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _loadExisting();
  }

  @override
  void dispose() {
    _tab.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadExisting() async {
    try {
      final notes = await _fs.getInitialExpressions();
      for (final entry in _controllers.entries) {
        entry.value.text = notes[entry.key] ?? '';
      }
    } catch (e) {
      _error = '초기값 로드 오류: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _fs.ensureUserDoc();
      await _fs.setInitialExpressions(
        notes: {
          for (final e in _controllers.entries) e.key: e.value.text.trim(),
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('저장되었습니다')));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '저장 오류: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
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

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('초기 표정 등록')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('초기 표정 등록'),
        bottom: TabBar(controller: _tab, tabs: tabs),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _ExpressionForm(title: 'smile', controller: _controllers['smile']!),
          _ExpressionForm(title: 'angry', controller: _controllers['angry']!),
          _ExpressionForm(title: 'sad', controller: _controllers['sad']!),
          _ExpressionForm(title: 'neutral', controller: _controllers['neutral']!),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSizes.sm),
                  child: Text(_error!, style: const TextStyle(color: AppColors.error)),
                ),
              ),
            ],
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving ? const CircularProgressIndicator() : const Text('저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpressionForm extends StatelessWidget {
  final String title;
  final TextEditingController controller;
  const _ExpressionForm({required this.title, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSizes.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSizes.sm),
          TextFormField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: '설명/메모를 입력하세요',
              border: OutlineInputBorder(),
            ),
            maxLines: 4,
          ),
        ],
      ),
    );
  }
}