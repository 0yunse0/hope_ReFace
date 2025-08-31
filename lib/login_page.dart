import 'package:flutter/material.dart';
import 'home_page.dart';
import 'auth_service.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final authService = AuthService();

  bool _loading = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _handleLogin() async {
    final email = emailController.text.trim();
    final pw = passwordController.text.trim();
    if (email.isEmpty || pw.isEmpty) {
      _showSnack('이메일과 비밀번호를 입력하세요.');
      return;
    }

    setState(() => _loading = true);
    try {
      final verified = await authService.signIn(email, pw);
      if (!verified) {
        _showSnack('이메일 인증이 필요합니다. 메일함을 확인하세요.');
        await authService.signOut();
        return;
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } on Exception catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleResetPw() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      _showSnack('비밀번호 재설정은 이메일을 먼저 입력하세요.');
      return;
    }

    setState(() => _loading = true);
    try {
      await authService.sendPasswordResetEmail(email);
      _showSnack('비밀번호 재설정 메일을 보냈습니다.');
    } on Exception catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final inputBorder = OutlineInputBorder(borderRadius: BorderRadius.circular(8));

    return Scaffold(
      appBar: AppBar(title: const Text('로그인')),
      body: AbsorbPointer(
        absorbing: _loading,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(children: [
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: inputBorder,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: inputBorder,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _handleLogin,
                    child: const Text('로그인'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignUpPage()),
                      );
                    },
                    child: const Text('회원가입'),
                  ),
                ),
                TextButton(
                  onPressed: _handleResetPw,
                  child: const Text('비밀번호 재설정'),
                ),
              ]),
            ),
            if (_loading) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
<<<<<<< HEAD
}
=======
}
>>>>>>> origin/main
