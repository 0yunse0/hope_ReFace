import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../utils/constants.dart';
import '../services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordCheckController =
      TextEditingController();

  bool _isObscure1 = true;
  bool _isObscure2 = true;
  bool _isValid = false; // 필드 유효성
  bool _isLoading = false; // 전체 로딩(버튼 비활성화용)

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordCheckController.dispose();
    super.dispose();
  }

  void _updateValidity() {
    final email = _emailController.text.trim();
    final pw = _passwordController.text;
    final pw2 = _passwordCheckController.text;
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    final next = emailRegex.hasMatch(email) && pw.length >= 8 && pw == pw2;
    if (next != _isValid) setState(() => _isValid = next);
  }

  void _toast(String msg) {
    Get.snackbar('알림', msg, snackPosition: SnackPosition.BOTTOM);
  }

  /// 회원가입 처리
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final auth = AuthService();
      await auth.createUserAndSendVerification(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // 가입 직후 바로 다음 화면으로 이동
      Get.offAllNamed('/initial-expression');
    } catch (e) {
      _toast('회원가입 실패: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canSignUp = _isValid && !_isLoading; // 회원가입 버튼 활성화 조건

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        InkWell(
                          onTap: () => Get.back(),
                          borderRadius: BorderRadius.circular(8),
                          child: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text(
                              '<',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '회원가입',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                    Text('이메일', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
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
                              ),
                            ),
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            onChanged: (_) => _updateValidity(),
                            validator: (v) {
                              final value = v?.trim() ?? '';
                              if (value.isEmpty) return '이메일을 입력해주세요.';
                              final emailRegex = RegExp(
                                r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                              );
                              if (!emailRegex.hasMatch(value)) {
                                return '유효한 이메일을 입력해주세요.';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    Text('비밀번호', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _isObscure1,
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
                              setState(() => _isObscure1 = !_isObscure1),
                          icon: Icon(
                            _isObscure1
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                      ),
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      onChanged: (_) => _updateValidity(),
                      validator: (v) {
                        final value = v ?? '';
                        if (value.isEmpty) return '비밀번호를 입력해주세요.';
                        if (value.length < 8) return '비밀번호는 8자 이상이어야 합니다.';
                        return null;
                      },
                    ),

                    const SizedBox(height: 24),
                    Text('비밀번호 재확인', style: theme.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordCheckController,
                      obscureText: _isObscure2,
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
                              setState(() => _isObscure2 = !_isObscure2),
                          icon: Icon(
                            _isObscure2
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                      ),
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      onChanged: (_) => _updateValidity(),
                      validator: (v) {
                        final value = v ?? '';
                        if (value.isEmpty) return '비밀번호를 다시 입력해주세요.';
                        if (value != _passwordController.text) {
                          return '비밀번호가 일치하지 않습니다.';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: canSignUp ? _submit : null,
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                '회원가입',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
