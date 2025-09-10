import 'package:flutter/material.dart';
import 'services/auth_service.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'signup_page.dart';
import 'home_page.dart';
import 'features/constants.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final ok = await AuthService().signIn(_email.text.trim(), _password.text.trim());
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
      } else {
        setState(() => _error = '이메일 인증이 필요합니다. 메일함을 확인해 주세요.');
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? '로그인 실패');
    } catch (e) {
      setState(() => _error = '에러: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goSignup() {
    Navigator.of(context).pushNamed('/signup');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('ReFace', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('로그인', style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary)),
                  const SizedBox(height: 24),
                  Card(
                    elevation: 0,
                    color: theme.colorScheme.surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
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
                              validator: (v) => (v == null || v.length < 6) ? '6자 이상 입력하세요' : null,
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 8),
                              Text(_error!, style: TextStyle(color: AppColors.error)),
                            ],
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _onLogin,
                                child: _loading ? const CircularProgressIndicator() : const Text('로그인'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(onPressed: _loading ? null : _goSignup, child: const Text('회원가입')),
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