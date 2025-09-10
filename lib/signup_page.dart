import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/auth_service.dart';
import 'initial_expressions_page.dart';
import 'features/constants.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _loading = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _onSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await AuthService().createUserAndSendVerification(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );

      if (!mounted) return;
      setState(() => _sent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('인증 메일을 전송했습니다. 메일함을 확인하세요.')),
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? '회원가입 실패');
    } catch (e) {
      setState(() => _error = '에러: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onCompleteVerification() async {
    setState(() => _loading = true);
    try {
      final verified = await AuthService().reloadAndCheckVerified();
      if (!mounted) return;

      if (verified) {
        await AuthService().finalizeAfterVerified(); // 필요시 후처리
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const InitialExpressionsPage()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('아직 이메일 인증 전입니다. 메일함을 다시 확인해 주세요.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '에러: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: const Text('회원가입')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Card(
                    elevation: 0,
                    color: theme.colorScheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _name,
                              decoration: const InputDecoration(
                                labelText: '이름',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty) ? '이름을 입력하세요' : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: '이메일',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return '이메일을 입력하세요';
                                if (!v.contains('@')) return '이메일 형식이 올바르지 않습니다';
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _password,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: '비밀번호',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) =>
                                  (v == null || v.length < 6) ? '6자 이상 입력하세요' : null,
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 8),
                              Text(_error!, style: const TextStyle(color: AppColors.error)),
                            ],
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _onSignUp,
                                child: _loading
                                    ? const CircularProgressIndicator()
                                    : const Text('회원가입'),
                              ),
                            ),
                            if (_sent) ...[
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: OutlinedButton(
                                  onPressed: _loading ? null : _onCompleteVerification,
                                  child: const Text('인증 완료했어요'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}