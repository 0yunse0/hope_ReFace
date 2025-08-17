import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'initial_expressions_page.dart';

const String FUNCTIONS_BASE = '';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});
  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();

  bool _sending = false;
  bool _verificationMailSent = false; // 인증 메일 발송 여부(회원가입 버튼 활성화 기준)

  bool get _emailValid =>
      RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(_email.text.trim());
  bool get _pwValid =>
      RegExp(r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,}$')
          .hasMatch(_pw.text);
  bool get _pwMatch => _pw.text == _pw2.text;

  Future<void> _checkDuplicateAndSendVerification() async {
    final email = _email.text.trim();
    if (!_emailValid) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('이메일 형식을 확인해 주세요.')));
      return;
    }
    if (!_pwValid || !_pwMatch) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('비밀번호 규칙/재확인을 확인해 주세요. (영문/숫자/특수문자 포함 8자 이상)')));
      return;
    }

    setState(() => _sending = true);
    try {
      final ok = await AuthService().isEmailAvailable(email);
      if (!ok) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('이미 사용 중인 이메일입니다.')));
        return;
      }

      // 계정 생성 + 인증 메일 발송 (화면 유지)
      await AuthService().createUserAndSendVerification(
        email: email,
        password: _pw.text,
      );
      setState(() => _verificationMailSent = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('인증 메일을 보냈습니다. 메일함에서 인증을 완료해 주세요.')));

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('중복 확인/인증메일 발송 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _completeSignUp() async {
    // 회원가입 버튼: 인증 완료되었는지 확인
    setState(() => _sending = true);
    try {
      final verified = await AuthService().reloadAndCheckVerified();
      if (!verified) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('아직 이메일 인증 전입니다. 인증 후 다시 눌러 주세요.')));
        return;
      }

      // 인증 완료되면 초기표정 화면으로 이동
      await AuthService().finalizeAfterVerified();

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => InitialExpressionsPage(functionsBase: FUNCTIONS_BASE)),
        (_) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('회원가입 완료 처리 실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSendVerify = !_sending; // 중복확인은 즉시 가능(내부에서 유효성 체크)
    final canFinishSignUp =
        _verificationMailSent && !_sending; // 메일 발송 후에만 활성화

    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 8),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: '이메일'),
              onChanged: (_) => setState((){}),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton(
                  onPressed: canSendVerify ? _checkDuplicateAndSendVerification : null,
                  child: _sending
                      ? const SizedBox(
                          height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('중복 확인(인증메일 발송)'),
                ),
                const SizedBox(width: 8),
                if (_verificationMailSent)
                  const Text('인증 메일 발송됨', style: TextStyle(color: Colors.green)),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pw,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '비밀번호 (영문/숫자/특수문자 8자 이상)',
              ),
              onChanged: (_) => setState((){}),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _pw2,
              obscureText: true,
              decoration: const InputDecoration(labelText: '비밀번호 재확인'),
              onChanged: (_) => setState((){}),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: canFinishSignUp ? _completeSignUp : null,
                child: const Text('회원가입'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}