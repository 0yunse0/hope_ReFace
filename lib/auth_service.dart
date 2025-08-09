// auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 회원가입 후 인증 메일 전송
  Future<void> signUp(String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    // 새 계정은 기본적으로 미인증 상태 → 인증 메일 발송
    if (cred.user != null && !(cred.user!.emailVerified)) {
      await cred.user!.sendEmailVerification();
    }
  }

  /// 로그인: 성공 시 이메일 인증 여부를 반환
  /// - true  : 로그인 성공 + 이메일 인증됨
  /// - false : 로그인 성공했지만 이메일 미인증
  Future<bool> signIn(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return cred.user?.emailVerified ?? false;
  }

  /// 로그아웃
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// 현재 로그인한 유저에게 인증 메일 재전송
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  /// 비밀번호 재설정 메일 전송
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// 계정 삭제 (이메일/비번 재인증 후)
  Future<void> deleteAccount(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: '현재 로그인된 사용자가 없습니다.',
      );
    }
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
    await user.delete();
  }

  /// 현재 유저
  User? get currentUser => _auth.currentUser;

  /// 인증 상태 스트림 (로그인/로그아웃/인증 변화 감지)
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
