import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:reface/auth_service.dart';
import 'send_capture_from_log.dart';
import 'package:reface/env.dart';


const String kDefaultApiBase = apiBase;


class ManualCapturePage extends StatefulWidget {
  const ManualCapturePage({super.key});

  @override
  State<ManualCapturePage> createState() => _ManualCapturePageState();
}

class _ManualCapturePageState extends State<ManualCapturePage> {
  final _sessionIdCtrl = TextEditingController(text: 'SESSION_YYYYMMDD_01');
  final _baseUrlCtrl = TextEditingController(text: kDefaultApiBase);
  final _logCtrl = TextEditingController();

  bool _sending = false;

  @override
  void dispose() {
    _sessionIdCtrl.dispose();
    _baseUrlCtrl.dispose();
    _logCtrl.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final txt = data?.text ?? '';
    if (txt.isNotEmpty) {
      setState(() {
        _logCtrl.text = txt;
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('클립보드에 텍스트가 없습니다.')),
        );
      }
    }
  }

  Future<void> _send() async {
    final uid = AuthService().uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다.')),
      );
      return;
    }

    final sessionId = _sessionIdCtrl.text.trim();
    final baseUrl = _baseUrlCtrl.text.trim();
    final logText = _logCtrl.text;

    if (sessionId.isEmpty || baseUrl.isEmpty || logText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('세션ID / API주소 / 로그를 모두 입력하세요.')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await sendCaptureFromLog(
        uid: uid,
        sessionId: sessionId,
        logText: logText,
        baseUrl: baseUrl,
        authToken: null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('전송 완료!')),
      );
      _logCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('전송 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('수동 좌표 캡처 전송')),
      body: AbsorbPointer(
        absorbing: _sending,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _sessionIdCtrl,
                decoration: InputDecoration(
                  labelText: '세션 ID',
                  border: inputBorder,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _baseUrlCtrl,
                decoration: InputDecoration(
                  labelText: 'API Base URL (ex: https://hope-reface.web.app/api)',
                  border: inputBorder,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: _logCtrl,
                  maxLines: null,
                  expands: true,
                  decoration: InputDecoration(
                    labelText: '로그 텍스트 붙여넣기',
                    alignLabelWithHint: true,
                    border: inputBorder,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pasteFromClipboard,
                    icon: const Icon(Icons.paste),
                    label: const Text('붙여넣기'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    label: const Text('전송'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
