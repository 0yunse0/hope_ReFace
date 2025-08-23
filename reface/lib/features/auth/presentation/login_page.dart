import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _loading = true; _error = null; });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pw.text,
      );
      // 성공 시 authStateChanges()가 Home으로 자동 라우팅
    } on FirebaseAuthException catch (e) {
      setState(() { _error = e.message ?? 'Firebase 로그인 실패'; });
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _handleSignUp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() { _loading = true; _error = null; });
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _pw.text,
      );
    } on FirebaseAuthException catch (e) {
      setState(() { _error = e.message ?? '회원가입 실패'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _handleReset() async {
    final email = _email.text.trim();
    if (email.isEmpty) return setState(() { _error = '이메일을 입력하세요'; });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호 재설정 메일 발송')),
      );
    } on FirebaseAuthException catch (e) {
      setState(() { _error = e.message ?? '재설정 메일 실패'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? '이메일을 입력하세요'
                      : (!v.contains('@')) ? '이메일 형식이 아닙니다'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _pw,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? '비밀번호를 입력하세요'
                      : (v.length < 6) ? '6자 이상 입력하세요'
                      : null,
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _loading ? null : _handleLogin,
                        child: _loading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Login'),
                      ),
                    ),
                  ],
                ),
                TextButton(onPressed: _handleSignUp, child: const Text('Sign up')),
                TextButton(onPressed: _handleReset, child: const Text('Forgot password?')),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
