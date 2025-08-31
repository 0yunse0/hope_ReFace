// lib/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;
  final FirebaseAuth _auth;

  /// 현재 로그인 유저 UID (없으면 null)
  String? get uid => _auth.currentUser?.uid;

  /// 로그인 후 이메일 인증 여부 반환
  Future<bool> signIn(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await cred.user?.reload();
    return cred.user?.emailVerified ?? false;
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordResetEmail(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  /// true면 아직 아무 계정도 사용하지 않은 이메일
  Future<bool> isEmailAvailable(String email) async {
    final methods = await _auth.fetchSignInMethodsForEmail(email);
    return methods.isEmpty;
  }

  /// 계정 생성 + 인증 메일 발송
  Future<void> createUserAndSendVerification({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (!(cred.user?.emailVerified ?? false)) {
      await cred.user?.sendEmailVerification();
    }
  }

  /// 유저 리로드 후 인증 여부 확인
  Future<bool> reloadAndCheckVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  /// 인증 완료 이후 후처리(필요 시 확장)
  Future<void> finalizeAfterVerified() async {
    return;
  }

  /// 계정 삭제 (이메일/비밀번호 계정 기준)
  /// home_page.dart 에서 입력받은 비밀번호로 재인증 후 삭제합니다.
  Future<void> deleteAccount(String password) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('로그인이 필요합니다.');
    }
    final email = user.email;
    if (email == null) {
      throw Exception('이메일/비밀번호 계정이 아닙니다.');
    }

    // 최근 로그인 필요 → 재인증
    final cred = EmailAuthProvider.credential(email: email, password: password);
    await user.reauthenticateWithCredential(cred);

    // 계정 삭제
    await user.delete();
  }
}
