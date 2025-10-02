import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 현재 로그인한 사용자의 UID (없으면 빈 문자열)
  String get uid => _auth.currentUser?.uid ?? '';

  /// 이메일/비밀번호 로그인 후 이메일 인증 여부를 반환
  Future<bool> signIn(String email, String password) async {
    // 웹 새로고침에서도 세션을 유지하도록 LOCAL 퍼시스턴스 보장
    try {
      await _auth.setPersistence(Persistence.LOCAL);
    } catch (_) {}
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = cred.user;
    await user?.reload();
    return user?.emailVerified ?? false;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  /// 해당 이메일로 가입 가능한지(= 기존 로그인 방법이 없는지)
  Future<bool> isEmailAvailable(String email) async {
    final methods = await _auth.fetchSignInMethodsForEmail(email);
    return methods.isEmpty;
  }

  /// 회원가입 후 인증 메일 발송
  Future<void> createUserAndSendVerification({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = cred.user;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  /// 현재 사용자 정보를 새로고침하고 인증 여부 반환
  Future<bool> reloadAndCheckVerified() async {
    final user = _auth.currentUser;
    await user?.reload();
    return user?.emailVerified ?? false;
  }

  /// 인증 후 마무리 작업 훅(필요 시 확장)
  Future<void> finalizeAfterVerified() async {
    final user = _auth.currentUser;
    if (user == null) return;
    // 필요시 displayName 업데이트 등 후처리 추가
  }

  /// 비밀번호로 재인증 후 계정 삭제
  Future<void> deleteAccount(String password) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final email = user.email;
    if (email != null) {
      final cred = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(cred);
    }
    await user.delete();
  }
}
