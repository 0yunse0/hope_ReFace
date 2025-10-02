import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../utils/constants.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  bool _isObscure = true;
  bool _isValid = false;
  bool _loading = false;

  final _auth = AuthService();

  @override
  void initState() {
    super.initState();
    //_emailController.text = 'minsuh727@naver.com';
    //_passwordController.text = 'min123^^';
    _isValid = _validateNow();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    Get.snackbar('알림', msg, snackPosition: SnackPosition.BOTTOM);
  }

  Future<void> _onLoginPressed() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final pw = _passwordController.text;

    setState(() => _loading = true);
    try {
      await _auth.signIn(email, pw);
      Get.offAllNamed('/initial-expression');
    } catch (e) {
      _showSnack(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _onResetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnack('비밀번호 재설정은 이메일을 먼저 입력하세요.');
      return;
    }

    setState(() => _loading = true);
    try {
      await _auth.sendPasswordResetEmail(email);
      _showSnack('비밀번호 재설정 메일을 보냈습니다.');
    } catch (e) {
      _showSnack(_friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('user-not-found')) return '가입되지 않은 이메일입니다.';
    if (msg.contains('wrong-password')) return '비밀번호가 올바르지 않습니다.';
    if (msg.contains('invalid-email')) return '유효하지 않은 이메일 형식입니다.';
    if (msg.contains('user-disabled')) return '비활성화된 계정입니다.';
    if (msg.contains('too-many-requests')) return '잠시 후 다시 시도해주세요.';
    return msg.replaceFirst('Exception: ', '');
  }

  bool _validateNow() {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text;
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailRegex.hasMatch(email) && password.length >= 8;
  }

  void _updateValidity() {
    final bool next = _validateNow();
    if (next != _isValid) {
      setState(() => _isValid = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 48),
                        Text(
                          '이메일과 비밀번호를\n입력해주세요.',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                              ),
                        ),
                        const SizedBox(height: 36),
                        Text(
                          '이메일',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          focusNode: _emailFocusNode,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            hintText: 'sample@gmail.com',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          onChanged: (_) => _updateValidity(),
                          onFieldSubmitted: (_) =>
                              _passwordFocusNode.requestFocus(),
                          validator: (value) {
                            final String v = value?.trim() ?? '';
                            if (v.isEmpty) return '이메일을 입력해주세요.';
                            final emailRegex = RegExp(
                              r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                            );
                            if (!emailRegex.hasMatch(v))
                              return '유효한 이메일을 입력해주세요.';
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        Text(
                          '비밀번호',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          focusNode: _passwordFocusNode,
                          obscureText: _isObscure,
                          textInputAction: TextInputAction.done,
                          decoration: InputDecoration(
                            hintText: '영문, 숫자, 특수문자 포함 8자 이상',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                              ),
                            ),
                            suffixIcon: IconButton(
                              onPressed: () =>
                                  setState(() => _isObscure = !_isObscure),
                              icon: Icon(
                                _isObscure
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                            ),
                          ),
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          onChanged: (_) => _updateValidity(),
                          onFieldSubmitted: (_) {
                            if (_isValid && !_loading) _onLoginPressed();
                          },
                          validator: (value) {
                            final String v = value ?? '';
                            if (v.isEmpty) return '비밀번호를 입력해주세요.';
                            return null;
                          },
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: (_isValid && !_loading)
                                ? _onLoginPressed
                                : null,
                            child: Text(
                              _loading ? '로그인 중...' : '로그인',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 12,
                            children: [
                              TextButton(
                                onPressed: _loading
                                    ? null
                                    : () => Get.toNamed('/signup'),
                                child: const Text('회원가입'),
                              ),
                              const Text('|'),
                              TextButton(
                                onPressed: _loading ? null : _onResetPassword,
                                child: const Text('비밀번호 재설정'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_loading) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}
